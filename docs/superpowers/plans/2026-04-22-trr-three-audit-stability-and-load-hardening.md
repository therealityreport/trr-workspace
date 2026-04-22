# TRR Three-Audit Stability And Load Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the highest-risk stability, pooling, migration, auth, and page-load regressions surfaced across the three TRR audits without changing the public admin feature set.

**Architecture:** Fix the work in three layers. First, eliminate correctness and coordination bugs in backend lock handling, app retry behavior, runtime failover, and migration authority. Second, raise and align the actual concurrency budgets across TRR-Backend and TRR-APP so social/admin traffic stops saturating at the current 1-2 connection defaults. Third, reshape the worst admin/social cold paths so they fetch batched or cached summaries instead of fan-out reads and write-on-read side effects.

**Tech Stack:** Python/FastAPI/psycopg2, Next.js/TypeScript/pg, Supabase migrations, Vitest, Pytest

---

## File Structure

| Area | Files |
| --- | --- |
| Backend lock + pool correctness | `TRR-Backend/trr_backend/db/pg.py`, `TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py`, `TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py`, `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/db/test_pg_pool.py`, `TRR-Backend/tests/repositories/test_social_sync_orchestrator.py`, `TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py` |
| App retry + fallback + auth | `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-APP/apps/web/tests/social-admin-proxy.test.ts`, `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`, `TRR-APP/apps/web/tests/server-auth-adapter.test.ts`, `TRR-APP/apps/web/tests/social-sync-sessions-routes.test.ts` |
| Runtime config + docs | `profiles/default.env`, `profiles/social-debug.env`, `scripts/dev-workspace.sh`, `TRR-APP/apps/web/.env.example`, `TRR-APP/apps/web/POSTGRES_SETUP.md`, `TRR-Backend/.env.example`, `TRR-Backend/README.md`, `TRR-Backend/docs/api/run.md`, `TRR-Backend/docs/runbooks/supabase_migration_history_repair.md`, `docs/workspace/env-contract-inventory.md` |
| Migrations + hot-path queries | `TRR-APP/apps/web/scripts/run-migrations.mjs`, `TRR-Backend/scripts/dev/reconcile_runtime_db.py`, `TRR-Backend/supabase/migrations/20260422170000_social_profile_account_order_indexes.sql`, `TRR-Backend/api/routers/admin_cast.py`, `TRR-Backend/api/routers/admin_person_profile.py`, `TRR-Backend/api/routers/socials.py` |
| App hot-path pages | `TRR-APP/apps/web/src/app/api/admin/social/landing/route.ts`, `TRR-APP/apps/web/src/lib/admin/social-landing.ts`, `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`, `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/summary/route.ts`, `TRR-APP/apps/web/src/components/admin/PersonPageClient.tsx`, `TRR-APP/apps/web/tests/social-landing-repository.test.ts`, `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`, `TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts`, `TRR-APP/apps/web/tests/social-account-summary-route.test.ts`, `TRR-APP/apps/web/tests/people-page-tabs-runtime.test.tsx` |

### Task 1: Fix Session-Scoped Advisory Lock Lifetime And Lock-Held Re-Entrancy

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py`
- Modify: `TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/db/test_pg_pool.py`
- Test: `TRR-Backend/tests/repositories/test_social_sync_orchestrator.py`
- Test: `TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add failing backend pool/lock tests**

```python
def test_advisory_lock_context_uses_one_connection_for_lock_and_unlock() -> None:
    fake_pool = _FakePool()
    with pg.advisory_session_lock(123, pool_name="db_read", label="test-lock"):
        pass
    assert fake_pool.getconn_calls == 1
    assert fake_pool.putconn_calls == 1
    assert fake_pool.connection.executed_sql == [
        "select pg_try_advisory_lock(%s)",
        "select pg_advisory_unlock(%s)",
    ]
```

```python
def test_finalize_run_status_reuses_lock_connection_for_unlock(monkeypatch) -> None:
    unlock_calls: list[object] = []
    monkeypatch.setattr(legacy.pg, "fetch_one", _fail_if_used_for_unlock)
    monkeypatch.setattr(legacy.pg, "db_read_connection", fake_lock_connection)
    _finalize_run_status("run-1")
    assert unlock_calls == ["same-connection"]
```

- [ ] **Step 2: Run the targeted backend tests and confirm they fail on current code**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/db/test_pg_pool.py tests/repositories/test_social_sync_orchestrator.py tests/repositories/test_social_run_lifecycle_repository.py tests/repositories/test_social_season_analytics.py
```

Expected: failures showing lock acquisition/unlock still happens through `pg.fetch_one(...)` and that lock-held flows still re-enter pooled helpers without `conn=lock_conn`.

- [ ] **Step 3: Add one explicit connection-scoped advisory-lock helper and route the audited paths through it**

```python
@contextmanager
def advisory_session_lock(lock_key: int, *, label: str, pool_name: str | None = None):
    with db_read_connection(label=label, pool_name=pool_name) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("select pg_try_advisory_lock(%s) as locked", [lock_key])
            row = cursor.fetchone() or {}
            if not bool(row.get("locked")):
                raise AdvisoryLockUnavailable(lock_key)
        try:
            yield conn
        finally:
            with conn.cursor() as cursor:
                cursor.execute("select pg_advisory_unlock(%s)", [lock_key])
```

```python
with pg.advisory_session_lock(lock_key, label="sync-session-lock") as lock_conn:
    row = _fetch_sync_session_row(sync_session_id, conn=lock_conn)
    ...
```

```python
with legacy.pg.advisory_session_lock(lock_key, label="run-finalize-lock") as lock_conn:
    current = legacy.pg.fetch_one("select status, config from social.scrape_runs where id = %s", [run_id], conn=lock_conn)
```

- [ ] **Step 4: Thread `conn` through the remaining lock-held social catalog supersession path**

```python
lock_conn = ...
cancel_social_account_catalog_run(
    run_id,
    cancelled_by="runtime_supersession",
    reason="superseded_by_newer_run",
    conn=lock_conn,
)
```

```python
def cancel_social_account_catalog_run(..., conn=None):
    run_row = pg.fetch_one("select ...", [run_id], conn=conn)
    pg.execute("update social.scrape_runs ...", [...], conn=conn)
```

- [ ] **Step 5: Re-run the targeted backend tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/db/test_pg_pool.py tests/repositories/test_social_sync_orchestrator.py tests/repositories/test_social_run_lifecycle_repository.py tests/repositories/test_social_season_analytics.py
```

Expected: PASS; lock helpers prove single-connection lifetime and lock-held flows no longer consume an extra pooled checkout.

Commit:

```bash
git add TRR-Backend/trr_backend/db/pg.py TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/db/test_pg_pool.py TRR-Backend/tests/repositories/test_social_sync_orchestrator.py TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: hold advisory locks on one pooled session"
```

### Task 2: Stop Replaying Mutating Admin POSTs

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/active-jobs/cancel/route.ts`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/stuck-jobs/cancel/route.ts`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/sync-sessions/[syncSessionId]/cancel/route.ts`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/sync-sessions/[syncSessionId]/retry/route.ts`
- Test: `TRR-APP/apps/web/tests/social-admin-proxy.test.ts`
- Test: `TRR-APP/apps/web/tests/social-sync-sessions-routes.test.ts`

- [ ] **Step 1: Add failing app tests that assert POST retries are disabled**

```ts
it("does not retry mutating POST requests after a timeout", async () => {
  vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("timed out")));
  await expect(
    fetchSocialBackendJson("/admin/social/cancel", {
      method: "POST",
      retries: 2,
      body: JSON.stringify({ id: "job-1" }),
    }),
  ).rejects.toThrow();
  expect(fetch).toHaveBeenCalledTimes(1);
});
```

```ts
it("still retries GET requests on retryable upstream failures", async () => {
  // existing retry behavior remains for reads
});
```

- [ ] **Step 2: Run the app tests and confirm current POST replay behavior fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-admin-proxy.test.ts tests/social-sync-sessions-routes.test.ts
```

Expected: failure showing mutating `POST` requests still attempt a second network call.

- [ ] **Step 3: Gate automatic retries to safe reads only**

```ts
function isAutoRetryEligible(method: string | undefined): boolean {
  const normalized = String(method ?? "GET").toUpperCase();
  return normalized === "GET" || normalized === "HEAD";
}

const allowRetry = isAutoRetryEligible(options.method);
if (!allowRetry && attempt >= 1) {
  throw proxyError;
}
```

```ts
return fetchSeasonBackendJson(showId, seasonNumber, "/sync-sessions/retry", {
  method: "POST",
  retries: 0,
  timeoutMs: ADMIN_WRITE_PROXY_TIMEOUT_MS,
  body: JSON.stringify(payload),
});
```

- [ ] **Step 4: Re-run the app tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-admin-proxy.test.ts tests/social-sync-sessions-routes.test.ts
```

Expected: PASS; `GET` keeps retry coverage, mutating routes execute once.

Commit:

```bash
git add TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/active-jobs/cancel/route.ts TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/stuck-jobs/cancel/route.ts TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/sync-sessions/[syncSessionId]/cancel/route.ts TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/sync-sessions/[syncSessionId]/retry/route.ts TRR-APP/apps/web/tests/social-admin-proxy.test.ts TRR-APP/apps/web/tests/social-sync-sessions-routes.test.ts
git commit -m "fix: disable mutating admin proxy retries"
```

### Task 3: Raise Real Local Pool Budgets And Remove Implicit App Failover

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py`
- Modify: `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Modify: `profiles/default.env`
- Modify: `profiles/social-debug.env`
- Modify: `scripts/dev-workspace.sh`
- Modify: `TRR-APP/apps/web/.env.example`
- Modify: `TRR-APP/apps/web/POSTGRES_SETUP.md`
- Test: `TRR-Backend/tests/db/test_pg_pool.py`
- Test: `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`

- [ ] **Step 1: Add failing tests for larger local defaults and no implicit lane flip**

```python
def test_resolve_pool_sizing_uses_larger_local_session_defaults() -> None:
    sizing = pg._resolve_pool_sizing(...)
    assert sizing == {"minconn": 2, "maxconn": 8}
```

```ts
it("does not switch to TRR_DB_FALLBACK_URL automatically on transient runtime errors", async () => {
  const error = new Error("connection terminated unexpectedly");
  await expect(withPoolRetry(() => Promise.reject(error))).rejects.toThrow(error);
  expect(emittedFallbackEvents).toEqual([]);
});
```

- [ ] **Step 2: Run the targeted pool/fallback tests and confirm failures**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/db/test_pg_pool.py
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
```

Expected: failures because the repo still ships 1/2 session defaults and app runtime still flips `activeCandidateIndex` on transient errors.

- [ ] **Step 3: Raise checked-in local budgets together across backend and app**

```python
DEFAULT_SESSION_POOLER_MINCONN = 2
DEFAULT_SESSION_POOLER_MAXCONN = 8

if is_local_or_modal_session_pooler():
    minconn = max(minconn, DEFAULT_SESSION_POOLER_MINCONN)
    maxconn = max(maxconn, DEFAULT_SESSION_POOLER_MAXCONN)
```

```ts
return {
  maxConcurrentOperations:
    parsePositiveInt(env.POSTGRES_MAX_CONCURRENT_OPERATIONS) ?? (isSessionPooler ? (isDevelopment ? 8 : 4) : 12),
  poolMax:
    parsePositiveInt(env.POSTGRES_POOL_MAX) ?? (isSessionPooler ? (isDevelopment ? 8 : 6) : 10),
};
```

```dotenv
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=2
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=8
TRR_DB_POOL_MINCONN=2
TRR_DB_POOL_MAXCONN=8
WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=8
WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=8
```

- [ ] **Step 4: Remove implicit failover from request-time pool retry and keep fallback explicit**

```ts
async function withPoolRetry<T>(operation: (pool: Pool) => Promise<T>): Promise<T> {
  const maxAttempts = parsePositiveInt(process.env.POSTGRES_TRANSIENT_RETRY_ATTEMPTS) ?? 3;
  let lastError: unknown;
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    try {
      return await operation(getPool());
    } catch (error) {
      lastError = error;
      if (!isTransientPostgresError(error) || attempt + 1 >= maxAttempts) throw error;
      await closePoolState();
      await sleep(150 * 2 ** attempt);
    }
  }
  throw lastError;
}
```

```md
`TRR_DB_FALLBACK_URL` remains operator-controlled break-glass only. Runtime request handling does not automatically switch lanes on transient query failures.
```

- [ ] **Step 5: Re-run tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/db/test_pg_pool.py
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
```

Expected: PASS; defaults reflect larger local budgets and fallback is no longer a hidden retry lane.

Commit:

```bash
git add TRR-Backend/trr_backend/db/pg.py TRR-APP/apps/web/src/lib/server/postgres.ts profiles/default.env profiles/social-debug.env scripts/dev-workspace.sh TRR-APP/apps/web/.env.example TRR-APP/apps/web/POSTGRES_SETUP.md TRR-Backend/tests/db/test_pg_pool.py TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts
git commit -m "fix: stabilize local pool budgets and explicit fallback"
```

### Task 4: Collapse Shared-Schema Migration Authority And Make The App Runner Atomic

**Files:**
- Modify: `TRR-APP/apps/web/scripts/run-migrations.mjs`
- Modify: `TRR-Backend/scripts/dev/reconcile_runtime_db.py`
- Modify: `TRR-APP/apps/web/POSTGRES_SETUP.md`
- Modify: `TRR-Backend/docs/runbooks/supabase_migration_history_repair.md`
- Modify: `docs/workspace/env-deprecations.md`
- Test: `TRR-Backend/tests/migrations/test_show_source_metadata_migrations.py`

- [ ] **Step 1: Add failing runner behavior coverage for per-file transaction boundaries**

```js
it("wraps each app-local migration file in one transaction", async () => {
  const queries: string[] = [];
  fakeClient.query = async (sql) => void queries.push(sql);
  await applyMigration("001_app_local_only.sql");
  expect(queries).toEqual(["BEGIN", expect.stringContaining("create table"), "INSERT INTO __migrations", "COMMIT"]);
});
```

- [ ] **Step 2: Run the migration tests and confirm the current runner applies SQL outside a transaction**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/migrations/test_show_source_metadata_migrations.py
```

Expected: new app-runner test fails because `pool.query(sql)` and `recordMigration(...)` are not atomic.

- [ ] **Step 3: Keep shared schema backend-owned only, and make app-local writes atomic**

```js
async function applyMigration(fileName) {
  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    await client.query(sql);
    await client.query("INSERT INTO __migrations (name) VALUES ($1)", [fileName]);
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
```

```py
if include_transitional_shared_schema:
    raise RuntimeError("Shared schema migrations must run from TRR-Backend/supabase/migrations only")
```

```md
Shared schema writer: `TRR-Backend/supabase/migrations` only.
App runner scope: app-local tables/views only.
```

- [ ] **Step 4: Re-run tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/migrations/test_show_source_metadata_migrations.py
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
```

Expected: PASS; app runner is atomic and operator docs now reflect single-writer shared schema authority.

Commit:

```bash
git add TRR-APP/apps/web/scripts/run-migrations.mjs TRR-Backend/scripts/dev/reconcile_runtime_db.py TRR-APP/apps/web/POSTGRES_SETUP.md TRR-Backend/docs/runbooks/supabase_migration_history_repair.md docs/workspace/env-deprecations.md
git commit -m "fix: make app migrations atomic and backend-owned for shared schema"
```

### Task 5: Harden Admin Auth Timeouts, Context Propagation, And Compatibility Flags

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/auth.ts`
- Modify: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`
- Modify: `TRR-Backend/api/auth.py`
- Modify: `TRR-Backend/.env.example`
- Modify: `TRR-Backend/README.md`
- Modify: `TRR-Backend/docs/api/run.md`
- Modify: `docs/workspace/env-contract-inventory.md`
- Test: `TRR-APP/apps/web/tests/server-auth-adapter.test.ts`
- Test: `TRR-APP/apps/web/tests/internal-admin-auth.test.ts`
- Test: `TRR-Backend/tests/api/test_auth.py`

- [ ] **Step 1: Add failing auth timeout / flag-hardening tests**

```ts
it("aborts identity toolkit fallback after a bounded timeout", async () => {
  vi.stubGlobal("fetch", neverResolvingFetch);
  await expect(verifyIdTokenWithoutAdmin("token")).resolves.toBeNull();
  expect(abortWasTriggered).toBe(true);
});
```

```python
def test_internal_admin_service_role_bypass_disabled_by_default(settings) -> None:
    settings.TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE = False
    response = client.get("/...", headers={"authorization": "Bearer service-role"})
    assert response.status_code == 401
```

- [ ] **Step 2: Run targeted auth tests and confirm failures**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/server-auth-adapter.test.ts tests/internal-admin-auth.test.ts
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/api/test_auth.py
```

Expected: current code still allows the external fetch to run without an abort budget and compatibility flags remain soft.

- [ ] **Step 3: Add a hard timeout, fail closed, and make internal-admin context reusable**

```ts
const abortController = new AbortController();
const timeout = setTimeout(() => abortController.abort(), 3_000);
const res = await fetch(identityToolkitUrl, { ..., signal: abortController.signal });
```

```ts
export function buildInternalAdminHeaders(context: VerifiedAdminContext): HeadersInit {
  return {
    Authorization: `Bearer ${mintInternalAdminToken(context)}`,
    "x-trr-admin-uid": context.uid,
  };
}
```

```python
TRR_ADMIN_ALLOW_SERVICE_ROLE = False
TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE = False
TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK = False
```

- [ ] **Step 4: Re-run auth tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/server-auth-adapter.test.ts tests/internal-admin-auth.test.ts
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/api/test_auth.py
```

Expected: PASS; admin fallback has a bounded timeout and backend bypass flags are disabled by default in committed contracts.

Commit:

```bash
git add TRR-APP/apps/web/src/lib/server/auth.ts TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts TRR-Backend/api/auth.py TRR-Backend/.env.example TRR-Backend/README.md TRR-Backend/docs/api/run.md docs/workspace/env-contract-inventory.md TRR-APP/apps/web/tests/server-auth-adapter.test.ts TRR-APP/apps/web/tests/internal-admin-auth.test.ts TRR-Backend/tests/api/test_auth.py
git commit -m "fix: harden admin auth timeouts and bypass defaults"
```

### Task 6: Replace Social Landing Cast Fan-Out With One Batch Summary Path

**Files:**
- Modify: `TRR-Backend/api/routers/admin_cast.py`
- Modify: `TRR-APP/apps/web/src/lib/admin/social-landing.ts`
- Modify: `TRR-APP/apps/web/src/app/api/admin/social/landing/route.ts`
- Test: `TRR-APP/apps/web/tests/social-landing-repository.test.ts`

- [ ] **Step 1: Add a failing landing test that asserts no per-show cast fan-out**

```ts
it("loads one backend cast summary payload for social landing", async () => {
  await getSocialLandingPayload();
  expect(fetchMock).toHaveBeenCalledWith(expect.stringContaining("/cast-summary"), expect.anything());
  expect(perShowCastFetchMock).not.toHaveBeenCalled();
});
```

- [ ] **Step 2: Run the landing test and confirm the current N+1 behavior**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-landing-repository.test.ts
```

Expected: failure because `getSocialLandingPayload(...)` still loops `safeLoadShowCast(...)` over each covered show.

- [ ] **Step 3: Add one backend summary endpoint and consume it in the landing repository**

```python
@router.post("/shows/cast-summary")
def get_cast_summary_for_show_ids(payload: CastSummaryRequest):
    return {"shows": fetch_cast_summary_rows(payload.show_ids)}
```

```ts
const castSummary = await fetchAdminBackendJson("/admin/trr-api/shows/cast-summary", {
  method: "POST",
  body: JSON.stringify({ showIds }),
});
```

- [ ] **Step 4: Re-run the landing test and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-landing-repository.test.ts
```

Expected: PASS; one summary payload replaces the per-show cast loop.

Commit:

```bash
git add TRR-Backend/api/routers/admin_cast.py TRR-APP/apps/web/src/lib/admin/social-landing.ts TRR-APP/apps/web/src/app/api/admin/social/landing/route.ts TRR-APP/apps/web/tests/social-landing-repository.test.ts
git commit -m "perf: batch social landing cast summary"
```

### Task 7: Remove Social Profile Double Bootstrap And Add The Right Account Indexes

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/summary/route.ts`
- Create: `TRR-Backend/supabase/migrations/20260422170000_social_profile_account_order_indexes.sql`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
- Test: `TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts`
- Test: `TRR-APP/apps/web/tests/social-account-summary-route.test.ts`

- [ ] **Step 1: Add failing profile bootstrap tests**

```tsx
it("does not start snapshot and summary bootstrap in parallel on first paint", async () => {
  render(<SocialAccountProfilePage platform="instagram" handle="thetraitorsus" activeTab="stats" />);
  expect(fetchSummaryMock).toHaveBeenCalledTimes(1);
  expect(fetchSnapshotMock).not.toHaveBeenCalled();
});
```

```ts
it("keeps snapshot route from re-entering summary for the first paint bootstrap", async () => {
  await GET(request);
  expect(summaryProxyMock).not.toHaveBeenCalled();
});
```

- [ ] **Step 2: Run the profile tests and confirm duplicate bootstrap work**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/social-account-profile-snapshot-route.test.ts tests/social-account-summary-route.test.ts
```

Expected: failure because `fetchProfileSnapshot()` and `refreshSummary({ detail: "lite" })` still start together.

- [ ] **Step 3: Make summary the only first-paint bootstrap and add account-ordered indexes**

```tsx
useEffect(() => {
  void refreshSummary({ detail: "lite", bootstrap: true });
}, [platform, handle]);
```

```tsx
async function fetchProfileSnapshot({ eager = false } = {}) {
  if (!eager) return null;
  ...
}
```

```sql
create index concurrently if not exists instagram_posts_source_account_lower_posted_at_id_idx
  on social.instagram_posts (lower(source_account), posted_at desc, id desc);
```

- [ ] **Step 4: Re-run profile tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/social-account-profile-snapshot-route.test.ts tests/social-account-summary-route.test.ts
```

Expected: PASS; first paint uses one summary path and the migration exists for account-scoped ordered reads.

Commit:

```bash
git add TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/summary/route.ts TRR-Backend/supabase/migrations/20260422170000_social_profile_account_order_indexes.sql TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts TRR-APP/apps/web/tests/social-account-summary-route.test.ts
git commit -m "perf: remove social profile double bootstrap"
```

### Task 8: Remove Write-On-Read People Page Work And Normalize Slow Read Helpers

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/PersonPageClient.tsx`
- Modify: `TRR-Backend/api/routers/admin_person_profile.py`
- Test: `TRR-APP/apps/web/tests/people-page-tabs-runtime.test.tsx`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_profile.py`

- [ ] **Step 1: Add failing people-page tests that forbid sync-on-read**

```tsx
it("reads persisted videos and news without triggering sync side effects on tab load", async () => {
  render(<PersonPageClient personId="person-1" />);
  await openVideosTab();
  expect(syncBravoVideoThumbnailsMock).not.toHaveBeenCalled();
  await openNewsTab();
  expect(syncGoogleNewsMock).not.toHaveBeenCalled();
});
```

```python
def test_person_profile_refresh_uses_direct_pg_reads(monkeypatch) -> None:
    assert not used_supabase_table_select
```

- [ ] **Step 2: Run the tests and confirm the current write-on-read path**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/people-page-tabs-runtime.test.tsx
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/api/routers/test_admin_person_profile.py
```

Expected: failure because the UI still calls sync helpers during read paths and backend refresh still mixes Supabase table wrappers.

- [ ] **Step 3: Make reads fetch-only and move syncs behind explicit actions**

```tsx
const loadBravoVideos = () => fetchJson("/admin/trr-api/people/123/videos");
const refreshBravoVideos = () => postJson("/admin/trr-api/people/123/videos/refresh");
```

```python
person_row = pg.fetch_one("select ... from core.people where id = %s", [person_id])
approved_links = pg.fetch_all("select ... from core.person_links where ...", [person_id])
```

- [ ] **Step 4: Re-run tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/people-page-tabs-runtime.test.tsx
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/api/routers/test_admin_person_profile.py
```

Expected: PASS; tabs stop mutating state during normal reads, and backend refresh uses direct pg consistently.

Commit:

```bash
git add TRR-APP/apps/web/src/components/admin/PersonPageClient.tsx TRR-Backend/api/routers/admin_person_profile.py TRR-APP/apps/web/tests/people-page-tabs-runtime.test.tsx TRR-Backend/tests/api/routers/test_admin_person_profile.py
git commit -m "perf: remove people admin write-on-read flows"
```

## Self-Review

- Spec coverage:
  - P0 advisory-lock misuse: Task 1.
  - Mutating POST retries: Task 2.
  - Automatic DB fallback lane switching: Task 3.
  - Tiny backend/app pool budgets: Task 3.
  - Split migration authority + non-atomic app runner: Task 4.
  - Admin auth timeout + compatibility bypasses: Task 5.
  - Social landing cast N+1: Task 6.
  - Social profile first-paint duplication + account-profile indexes: Task 7.
  - People page write-on-read + slower backend wrapper reads: Task 8.
- Placeholder scan: no `TODO`, `TBD`, or “write tests later” placeholders remain.
- Type consistency:
  - The plan consistently uses `conn` threading for backend helpers.
  - The app-side retry change consistently treats only `GET`/`HEAD` as auto-retry-eligible.
  - The migration lane keeps shared schema in `TRR-Backend/supabase/migrations` and app-local migrations in the app runner.

Plan complete and saved to `docs/superpowers/plans/2026-04-22-trr-three-audit-stability-and-load-hardening.md`. Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
