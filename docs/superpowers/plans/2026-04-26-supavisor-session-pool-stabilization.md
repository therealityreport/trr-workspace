# Supavisor Session Pool Stabilization Plan

## Goal

Stop TRR local and production admin surfaces from failing with `EMAXCONNSESSION` / `MaxClientsInSessionMode` by restoring session-pool headroom immediately, adding clear pressure diagnostics, and moving high-fan-out app direct SQL behind backend-owned APIs.

The plan covers the current failure on `http://127.0.0.1:3000/api/admin/social/landing` and the related workspace connection posture.

## Architecture Summary

TRR currently uses Supavisor session mode for local runtime DB access. In session mode, each client can hold a backend connection for the life of the session. The current default local holder budget can reach the observed Supavisor `pool_size: 15` exactly:

```text
TRR-APP pool                 4
TRR-Backend default pool     4
TRR-Backend social_profile   4
TRR-Backend social_control   2
TRR-Backend health           1
Total                       15
```

This plan changes the system in four layers:

1. **Emergency relief:** restart local runtimes, optionally raise Supavisor pool size temporarily, and capture holder evidence.
2. **Default headroom:** lower local app direct-SQL concurrency, lower the backend general pool, and disable local default remote social dispatch so normal `make dev` no longer budgets the whole session pool.
3. **Guardrails and visibility:** make startup warn or fail when holder budget is unsafe; log app/backend pool state with route labels and app names; add a DB pressure readiness endpoint that does not make liveness restart-happy.
4. **Durable fan-out reduction:** move the social landing direct-SQL reads from `TRR-APP` into backend APIs and add short TTL caching around freshness/gap/catalog/photo-heavy admin reads.

## Tech Stack

- Workspace: Bash launcher and contract scripts under `/Users/thomashulihan/Projects/TRR/scripts/`
- App: Next.js / TypeScript / node-postgres under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/`
- Backend: FastAPI / Python 3.11 / psycopg2 under `/Users/thomashulihan/Projects/TRR/TRR-Backend/`
- Screenalytics: FastAPI / Python under `/Users/thomashulihan/Projects/TRR/screenalytics/`
- Database: Supabase Postgres 17 / Supavisor session pooler

## Repo Evidence

| Source | Evidence | Plan Decision |
|---|---|---|
| `/Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log` | `/api/admin/social/landing` emitted repeated `(EMAXCONNSESSION) max clients reached in session mode - max clients are limited to pool_size: 15`, then later returned `200` after about 8 seconds. | Treat this as transient session-pool saturation, not a broken route contract. |
| `/Users/thomashulihan/Projects/TRR/profiles/default.env` | Default local profile sets `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1`, `WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=6`, `WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=12`, `TRR_DB_POOL_MAXCONN=4`, `TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4`, `TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2`, `TRR_HEALTH_DB_POOL_MAXCONN=1`. | Default `make dev` needs lower DB holder budget and remote social workers off unless explicitly requested. |
| `/Users/thomashulihan/Projects/TRR/profiles/social-debug.env` | Social debug already disables remote social workers and projects app pool/concurrency to `2`. | Use this as the existing low-pressure pattern, but make default local dev safer than it is now. |
| `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` | `workspace_effective_db_holder_budget()` falls back to app 4, backend 4, social_profile 4, social_control 2, health 1 and only prints the budget. | Convert the budget into an actionable guardrail with an explicit Supavisor pool-size input. |
| `/Users/thomashulihan/Projects/TRR/scripts/test_workspace_app_env_projection.py` | Tests already assert the default holder budget string is `total=15`. | Update tests to lock the new safe default budget. |
| `/Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh` | Contract checker asserts profile/env-doc values and app pool projection behavior. | Update this checker with the new headroom contract. |
| `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md` | Generated env contract documents current pool defaults and remote social worker defaults. | Regenerate after profile/script changes; do not edit generated docs by hand. |
| `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md` | Capacity doc says the local workspace uses session mode and that each session-mode app client holds a dedicated backend connection. Last live snapshot is historical and must be re-verified before production scale changes. | Update with a current local session-pool headroom section and keep production pool-size increase as a manual, time-boxed operator action. |
| `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/postgres.ts` | App defaults: session pool max 4, local session concurrent operations 4, deployed session concurrent operations 2. It already logs `postgres_pool_init`, `postgres_pool_queue_depth`, and transient retries. | Lower session defaults and extend logs with `total_count`, `idle_count`, `waiting_count`, and optional route labels. |
| `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts` | Tests assert local session defaults of `{ poolMax: 4, maxConcurrentOperations: 4 }` and production `{ poolMax: 4, maxConcurrentOperations: 2 }`. | Update expected local/deployed session caps and keep explicit override coverage. |
| `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/social/landing/route.ts` | The route uses route cache/in-flight dedupe and calls `getSocialLandingPayloadResult(...)`. | Preserve cache/dedupe but reduce direct-SQL reads behind the payload. |
| `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts` | Initial payload does direct app SQL through `getCoveredShows()` and `listRedditCommunities()`, then calls multiple backend endpoints. | Migrate direct SQL reads to a backend-owned landing summary endpoint. |
| `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts` | Existing route cache supports TTL, namespace, and in-flight dedupe. | Reuse it for admin read caching; do not add a second app cache framework. |
| `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/pg.py` | Backend has named pools `default`, `social_profile`, `social_control`, and `health`; logs acquire failures and pool counts; clamps oversized local session-pool overrides at 8. | Lower default general local pool, keep named pools, and add a safe snapshot helper for readiness/diagnostics. |
| `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_pg_pool.py` | Existing tests cover named pool sizing, local/session clamps, and `social_control`/`health` pool use. | Add tests for default general pool target and pool state snapshot output. |
| `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py` | `/health/live` exists and `/health` uses `pool_name="health"`. | Add DB pressure readiness without putting DB pressure into liveness. |
| `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/social_control_plane_pressure_snapshot.py` | Existing pressure snapshot script is the closest operator diagnostic for control-plane pool state. | Extend or mirror this pattern for session-pool holder evidence instead of inventing a separate CLI style. |
| `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/main.py` | Screenalytics loads `.env` for `TRR_DB_URL` / `TRR_DB_FALLBACK_URL` before imports. | Screenalytics can connect to the same Supabase project by default if `.env` contains production `TRR_DB_URL`; plan a default-off guard for local workspace startup. |
| `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/services/runtime_startup.py` | Startup logs Screenalytics DB winner source/host class/connection class and validates runtime lane if DB details exist. | Add a workspace env switch to disable Screenalytics DB startup validation/connection by default when it is not needed. |
| Supabase docs: `https://supabase.com/docs/guides/database/connection-management` | Supabase documents that Supavisor pool size can be adjusted in Database Settings and warns to leave room for internal services. | Pool-size increase is allowed as a manual temporary step, not as the primary code fix. |
| Supabase docs: `https://supabase.com/docs/guides/troubleshooting/supavisor-faq-YyP5tI` | Session mode assigns a direct connection for a client until voluntarily released; pool size limits session-mode clients. | Confirm architecture: the durable fix is fewer session clients and less fan-out, not retry loops alone. |
| Supabase docs: `https://supabase.com/docs/guides/database/connecting-to-postgres/serverless-drivers` | Session mode is recommended as a direct-connection alternative for IPv4; transaction mode is ideal for serverless/transient connections but does not support prepared statements. | Introduce explicit session/transaction/direct URL names, but migrate lane usage only after client library compatibility is verified. |

## Requirements Coverage Matrix

| Requirement | Task(s) | Validation |
|---|---|---|
| Restart dev/backend/app processes to release stuck sessions. | Task 0 | `make stop && make dev`, then `curl /api/admin/social/landing` returns `200` without `EMAXCONNSESSION` in fresh logs. |
| Temporarily increase Supavisor pool size to 25 or 30 if allowed. | Task 0 | Manual Supabase dashboard/Grafana confirmation recorded in `docs/workspace/supabase-capacity-budget.md`. |
| Set TRR-Backend general pool to minconn=1 maxconn=2. | Task 1 | Workspace contract tests and backend pool tests assert `TRR_DB_POOL_MAXCONN=2` for local profiles. |
| Set TRR-APP node-postgres pool to max=1 locally and max=1-2 in production. | Task 1 and Task 3 | App postgres sizing tests assert local session `1/1`; production defaults assert `poolMax=2`, `maxConcurrentOperations=1` unless explicitly overridden. |
| Stop Screenalytics from connecting to production Supabase by default. | Task 6 | Screenalytics startup tests verify DB is skipped unless explicitly enabled in workspace profile. |
| Reduce dashboard polling and duplicate route fan-out. | Task 4 and Task 5 | Route tests prove landing uses one backend payload path and cache/in-flight dedupe still works. |
| Create `TRR_DB_SESSION_URL`, `TRR_DB_TRANSACTION_URL`, `TRR_DB_DIRECT_URL`. | Task 7 | Connection-resolution tests cover source priority and lane validation. |
| Use session mode only for long-lived backend workloads that need it. | Task 7 and Task 8 | App direct SQL is either capped or moved; transaction/direct lanes are explicit and not inferred. |
| Move most TRR-APP direct SQL reads into TRR-Backend APIs. | Task 5 | App landing repository no longer imports direct SQL repositories for covered shows/reddit summary. |
| Add endpoint caching for admin freshness/gap/catalog/photo reads. | Task 4 and Task 5 | Backend/app tests cover cache TTL and invalidation for targeted endpoints. |
| Add connection usage logging: app name, pool max, active/idle counts. | Task 2 and Task 3 | Unit tests or log-capture tests assert structured payload keys. |
| Add readiness check that fails clearly when DB pool pressure is high. | Task 2 | `/health/live` remains DB-light; readiness/runtime endpoint returns pressure state and reason. |

## Implementation Tasks

### Task 0: Emergency Relief and Baseline Evidence

**Commit boundary:** Documentation/runbook only if captured in repo; otherwise operator action.

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`
- Optionally add `/Users/thomashulihan/Projects/TRR/docs/workspace/session-pool-pressure-runbook.md`

**Steps**

- [ ] Stop local managed processes:

  ```bash
  cd /Users/thomashulihan/Projects/TRR
  make stop
  ```

- [ ] Confirm no stale local TRR app/backend/screenalytics processes are still holding sessions:

  ```bash
  ps -axo pid,ppid,command | rg "(next dev|uvicorn|screenalytics|trr_backend|TRR-APP|TRR-Backend)"
  ```

  Expected: no old `next dev` or `uvicorn api.main:app` process from this workspace remains after `make stop`.

- [ ] Restart with the low-pressure lane before any code changes:

  ```bash
  cd /Users/thomashulihan/Projects/TRR
  WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0 \
  WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1 \
  WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1 \
  TRR_DB_POOL_MAXCONN=2 \
  make dev
  ```

- [ ] Reproduce the current route:

  ```bash
  curl -sS -o /tmp/trr-social-landing.json -w '%{http_code} %{time_total}\n' \
    http://127.0.0.1:3000/api/admin/social/landing
  ```

  Expected: `200` and no fresh `EMAXCONNSESSION` lines in `/Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log`.

- [ ] If the route still fails with `pool_size: 15`, use Supabase Dashboard -> Database Settings -> Connection pooling and temporarily raise pool size to `25`. Use `30` only if `pg_stat_activity` and Supabase connection graphs show enough reserved/internal headroom.

- [ ] Record the manual setting, timestamp, and rollback target in `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`.

**Rollback**

- Restore Supavisor pool size to `15` after Tasks 1-4 are deployed and verified, unless live production traffic needs the higher setting.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "EMAXCONNSESSION|MaxClientsInSessionMode|max clients reached" .logs/workspace/trr-app.log
```

Expected: no new lines after the restart timestamp.

### Task 1: Make Default Local Workspace Leave Supavisor Headroom

**Commit boundary:** `fix: leave local supavisor session headroom`

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/profiles/default.env`
- Modify `/Users/thomashulihan/Projects/TRR/profiles/local-cloud.env`
- Modify `/Users/thomashulihan/Projects/TRR/profiles/social-debug.env`
- Modify `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- Modify `/Users/thomashulihan/Projects/TRR/scripts/workspace-env-contract.sh`
- Modify `/Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh`
- Modify `/Users/thomashulihan/Projects/TRR/scripts/test_workspace_app_env_projection.py`
- Regenerate `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`
- Update `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`

**Target Defaults**

For `PROFILE=default make dev`:

```text
WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1
WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=2
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4
TRR_SOCIAL_CONTROL_DB_POOL_MINCONN=1
TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2
TRR_HEALTH_DB_POOL_MINCONN=1
TRR_HEALTH_DB_POOL_MAXCONN=1
WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0
```

This produces:

```text
app=1, backend=2, social_profile=4, social_control=2, health=1, total=10
```

**Steps**

- [ ] In `profiles/default.env`, add explicit `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1` and `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1`.
- [ ] In `profiles/default.env`, change `TRR_DB_POOL_MAXCONN=4` to `TRR_DB_POOL_MAXCONN=2`.
- [ ] In `profiles/default.env`, change `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1` to `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0`.
- [ ] In `profiles/local-cloud.env`, mirror the same local headroom defaults.
- [ ] In `profiles/social-debug.env`, lower the app pool/concurrency from `2` to `1`; keep remote social workers disabled.
- [ ] In `scripts/dev-workspace.sh`, update `workspace_effective_db_holder_budget()` fallbacks so app fallback is `1` and backend fallback is `2`.
- [ ] Add `WORKSPACE_SUPAVISOR_SESSION_POOL_SIZE="${WORKSPACE_SUPAVISOR_SESSION_POOL_SIZE:-15}"` near other workspace defaults in `scripts/dev-workspace.sh`.
- [ ] Add a helper `workspace_warn_if_db_holder_budget_exhausts_session_pool()` that compares holder total against `WORKSPACE_SUPAVISOR_SESSION_POOL_SIZE`.
- [ ] In `print_workspace_ready_summary()`, print a warning when total is within two slots of the configured Supavisor pool size. Do not fail startup yet.
- [ ] Update `scripts/test_workspace_app_env_projection.py` expectations from total `15` to total `10`.
- [ ] Update `scripts/check-workspace-contract.sh` default expectation from `app=4, backend=4, social_profile=4, social_control=2, health=1, total=15` to `app=1, backend=2, social_profile=4, social_control=2, health=1, total=10`.
- [ ] Regenerate env contract:

  ```bash
  cd /Users/thomashulihan/Projects/TRR
  make env-contract
  ```

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR
python3 -m pytest -q scripts/test_workspace_app_env_projection.py
bash scripts/check-workspace-contract.sh
make env-contract
git diff -- docs/workspace/env-contract.md profiles/default.env profiles/local-cloud.env profiles/social-debug.env scripts/dev-workspace.sh scripts/check-workspace-contract.sh scripts/test_workspace_app_env_projection.py docs/workspace/supabase-capacity-budget.md
```

Expected:

- Projection tests pass.
- Contract check passes.
- Generated env contract reflects app pool `1`, backend general pool `2`, and remote social workers disabled by default.

**Rollback**

- Revert this commit or set explicit env overrides:

  ```bash
  WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=4 \
  WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=4 \
  TRR_DB_POOL_MAXCONN=4 \
  WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
  make dev
  ```

### Task 2: Backend Pool Pressure Snapshot and Readiness

**Commit boundary:** `feat: expose backend db pressure readiness`

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/pg.py`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_pg_pool.py`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/test_health.py`
- Optionally modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/social_control_plane_pressure_snapshot.py`

**New Backend Interface**

Add a non-secret pool snapshot helper:

```python
def pool_pressure_snapshot() -> dict[str, dict[str, int | str | None]]:
    ...
```

Required keys per pool:

```text
pool_name
configured_min
configured_max
in_use
available
checked_out
active_dsn_source
pressure_state
reason
```

`active_dsn_source` must be a source label, not a raw DSN.

Add an API endpoint:

```text
GET /health/db-pressure
```

Response shape:

```json
{
  "status": "ok|degraded",
  "reason": "ok|pool_near_capacity|pool_exhausted|pool_uninitialized",
  "pools": {
    "default": {},
    "social_profile": {},
    "social_control": {},
    "health": {}
  }
}
```

Do not change `/health/live` to depend on DB pressure. `/health/live` must remain DB-light.

**Steps**

- [ ] Add `pool_pressure_snapshot()` in `pg.py` using existing `_pool_counts()`, `_active_pool_ref()`, `_pool_size_env_names()`, and `_resolve_pool_sizing()`.
- [ ] Add `pressure_state` logic:
  - `ok` when available slots exist and checked out is below configured max.
  - `near_capacity` when available is `0` or checked out is within one slot of configured max.
  - `exhausted` when `PoolError` was recently observed or checked out is at configured max with no available slots.
  - `uninitialized` when pool has not been created.
- [ ] Reuse existing logging keys where possible: `pool_name`, `in_use`, `available`, and `reason`.
- [ ] Add `/health/db-pressure` in `api/main.py`.
- [ ] Add tests that prove `/health/live` does not call DB and `/health/db-pressure` does.
- [ ] Add tests that no raw DSN/password appears in the response.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m ruff check trr_backend/db/pg.py api/main.py tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m ruff format --check trr_backend/db/pg.py api/main.py tests/db/test_pg_pool.py tests/api/test_health.py
```

Expected: tests pass, lint/format pass, no secret URLs in test output.

**Rollback**

- Remove `/health/db-pressure` route and helper. `/health/live` behavior remains unchanged.

### Task 3: App Pool Defaults and Connection Usage Logging

**Commit boundary:** `feat: cap app session pool and log pressure`

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/postgres.ts`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- Add or modify focused tests under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/`
- Update `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/POSTGRES_SETUP.md`
- Update `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`

**Target Defaults**

```text
Development session pooler: poolMax=1, maxConcurrentOperations=1
Production session pooler: poolMax=2, maxConcurrentOperations=1
Preview session pooler: poolMax=1, maxConcurrentOperations=1 unless POSTGRES_POOL_MAX overrides it
Direct/local Postgres development: unchanged at poolMax=8, maxConcurrentOperations=8
```

**Steps**

- [ ] Change `DEFAULT_SESSION_POOL_MAX` to a deployed default helper instead of one shared constant if needed.
- [ ] Set local session-pooler default to `poolMax=1`, `maxConcurrentOperations=1`.
- [ ] Set production session-pooler default to `poolMax=2`, `maxConcurrentOperations=1`.
- [ ] Set preview session-pooler default to `poolMax=1`, `maxConcurrentOperations=1` using existing `VERCEL_ENV` detection.
- [ ] Preserve explicit env override behavior for `POSTGRES_POOL_MAX` and `POSTGRES_MAX_CONCURRENT_OPERATIONS`.
- [ ] Extend `postgres_pool_init` payload with:
  - `pool_total_count`
  - `pool_idle_count`
  - `pool_waiting_count`
- [ ] Extend `postgres_pool_queue_depth` payload with:
  - `pool_total_count`
  - `pool_idle_count`
  - `pool_waiting_count`
  - `application_name`
- [ ] Add helper:

  ```ts
  const readPoolCounts = (pool: Pool) => ({
    pool_total_count: pool.totalCount,
    pool_idle_count: pool.idleCount,
    pool_waiting_count: pool.waitingCount,
  });
  ```

- [ ] Update tests in `postgres-connection-string-resolution.test.ts`.
- [ ] Add a log-shape test if existing test helpers make console capture straightforward; otherwise document manual log verification in the plan execution notes.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
pnpm exec tsc --noEmit
```

Expected:

- Session-pooler sizing tests assert the new defaults.
- Direct/local Postgres defaults remain unchanged.
- TypeScript passes.

**Manual Check**

After restart:

```bash
cd /Users/thomashulihan/Projects/TRR
make stop
make dev
rg -n "postgres_pool_init|postgres_pool_queue_depth" .logs/workspace/trr-app.log
```

Expected: `postgres_pool_init` includes `pool_max:1` in local default startup and includes pool count keys.

**Rollback**

- Set env overrides to the old values while investigating:

  ```bash
  POSTGRES_POOL_MAX=4 POSTGRES_MAX_CONCURRENT_OPERATIONS=4 make dev
  ```

### Task 4: Reduce Social Landing Fan-Out Without Changing UI Contract

**Commit boundary:** `fix: collapse social landing sql fanout`

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/social/landing/route.ts` only if cache headers or route timings need exposure
- Add or update tests under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/`

**Steps**

- [ ] Add lightweight route timing logs around `getSocialLandingPayloadResult(...)`:

  ```text
  auth_ms
  cache_ms
  covered_shows_ms
  reddit_summary_ms
  backend_shared_sources_ms
  backend_runs_ms
  total_ms
  ```

- [ ] Keep logs behind a dev-safe or low-volume path; do not log payloads or secrets.
- [ ] Change `safeLoadRedditDashboardSummary()` so failure remains non-fatal but does not trigger repeated direct SQL retries inside the same route render.
- [ ] Ensure existing route cache/in-flight dedupe wraps all direct and backend fetch work.
- [ ] Add a stale-on-error fallback for the last successful landing payload if direct SQL fails due to session-pool pressure.
- [ ] Add tests that two concurrent GET calls share one in-flight payload promise.
- [ ] Add tests that a reddit direct-SQL failure returns a cacheable payload with zeroed reddit counts instead of route-level `500`.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-landing*.test.ts tests/postgres-connection-string-resolution.test.ts
pnpm exec tsc --noEmit
```

Expected: route behavior remains compatible, and failure of optional reddit summary no longer fails the route.

**Rollback**

- Revert this commit. Task 1 and Task 3 still provide connection headroom.

### Task 5: Move Social Landing Direct SQL Into TRR-Backend

**Commit boundary:** two commits:

1. `feat: add backend social landing summary api`
2. `refactor: use backend social landing summary`

**Backend Files**

- Add or modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_social_landing.py` or the existing closest admin social router
- Modify router registration under `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py` if needed
- Add repository/service code under `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/`
- Add tests under `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/`

**App Files**

- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/trr-api/` if a typed backend client helper is needed
- Add tests under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/`
- Update `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md`

**Backend Endpoint**

Add:

```text
GET /api/v1/admin/socials/landing-summary
```

Initial response shape:

```ts
type SocialLandingSummary = {
  covered_shows: Array<{
    trr_show_id: string;
    show_name: string;
    season_count?: number;
    network?: string | null;
  }>;
  reddit_dashboard: {
    active_community_count: number;
    archived_community_count: number;
    show_count: number;
  };
};
```

Keep this endpoint narrow. Do not move the entire social landing payload in one commit.

**Steps**

- [ ] Backend: implement `landing-summary` using backend DB helpers, with read labels and the appropriate pool. Use the default pool for generic show reads unless evidence says `social_control` is safer.
- [ ] Backend: add a short TTL in-process cache, default `TRR_ADMIN_SOCIAL_LANDING_SUMMARY_CACHE_TTL_MS=30000`.
- [ ] Backend: return `503` with `reason=session_pool_capacity` when DB pressure prevents reads; match existing saturation semantics.
- [ ] Backend tests: response shape, auth requirement, cache hit behavior, DB pressure failure shape.
- [ ] App: replace `getCoveredShows()` and `listRedditCommunities()` direct SQL calls in landing load with `fetchAdminBackendJson("/admin/socials/landing-summary", ...)`.
- [ ] App: preserve fallback behavior for optional reddit counts.
- [ ] App tests: route still produces the same payload fields; direct SQL repositories are no longer invoked for landing summary.
- [ ] Update `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` with producer, consumer, changed contract, and verification commands.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api/routers/test_admin_social_landing.py
.venv/bin/python -m ruff check api trr_backend tests/api/routers/test_admin_social_landing.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-landing*.test.ts
pnpm exec tsc --noEmit

cd /Users/thomashulihan/Projects/TRR
curl -sS -o /tmp/trr-social-landing.json -w '%{http_code} %{time_total}\n' \
  http://127.0.0.1:3000/api/admin/social/landing
```

Expected:

- Backend tests pass.
- App tests pass.
- Manual route returns `200`.
- App logs show fewer direct app SQL acquisitions for the landing route.

**Rollback**

- Revert app commit first to restore direct SQL path.
- Revert backend endpoint only after app no longer calls it.

### Task 6: Stop Screenalytics Production Supabase Connections by Default in Workspace Dev

**Commit boundary:** `fix: gate screenalytics db in workspace dev`

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- Modify `/Users/thomashulihan/Projects/TRR/profiles/default.env`
- Modify `/Users/thomashulihan/Projects/TRR/profiles/local-cloud.env`
- Modify `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md` through generator
- Modify `/Users/thomashulihan/Projects/TRR/scripts/workspace-env-contract.sh`
- Modify `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/main.py`
- Modify `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/services/runtime_startup.py`
- Add or update Screenalytics tests under `/Users/thomashulihan/Projects/TRR/screenalytics/tests/`

**New Env**

```text
WORKSPACE_SCREENALYTICS_DB_ENABLED=0
SCREENALYTICS_DB_ENABLED=0
```

Default: disabled for workspace `make dev` unless screenalytics flow requires DB.

**Steps**

- [ ] Add `WORKSPACE_SCREENALYTICS_DB_ENABLED=0` to `profiles/default.env` and `profiles/local-cloud.env`.
- [ ] In `scripts/dev-workspace.sh`, pass `SCREENALYTICS_DB_ENABLED="$WORKSPACE_SCREENALYTICS_DB_ENABLED"` into Screenalytics startup commands.
- [ ] In `screenalytics/apps/api/main.py`, when `SCREENALYTICS_DB_ENABLED=0`, do not load `.env` values for `TRR_DB_URL` / `TRR_DB_FALLBACK_URL` into process env.
- [ ] In `runtime_startup.validate_startup_config(...)`, if `SCREENALYTICS_DB_ENABLED=0`, log that DB-backed metadata is disabled and skip DB URL validation.
- [ ] Keep explicit override:

  ```bash
  WORKSPACE_SCREENALYTICS_DB_ENABLED=1 make dev
  ```

- [ ] Add tests for DB disabled and DB enabled behavior.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/screenalytics
python -m pytest -q tests/api/test_runtime_startup*.py

cd /Users/thomashulihan/Projects/TRR
python3 -m pytest -q scripts/test_workspace_app_env_projection.py
bash scripts/check-workspace-contract.sh
```

Expected: default workspace no longer starts Screenalytics with a production Supabase DB connection unless explicitly enabled.

**Rollback**

- Set `WORKSPACE_SCREENALYTICS_DB_ENABLED=1` during `make dev`.

### Task 7: Introduce Explicit DB Lane Env Names

**Commit boundary:** `feat: name postgres runtime lanes`

**Files**

- Modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/connection.py`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_connection_resolution.py`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/postgres.ts`
- Modify `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- Modify `/Users/thomashulihan/Projects/TRR/scripts/runtime-db-env.sh` or the current runtime DB env helper if this repo has a different file name
- Modify `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md` through generator
- Update `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`

**New Names**

```text
TRR_DB_SESSION_URL
TRR_DB_TRANSACTION_URL
TRR_DB_DIRECT_URL
```

**Resolution Rules**

Backend:

1. `TRR_DB_SESSION_URL` for normal long-lived backend/session-compatible runtime.
2. `TRR_DB_DIRECT_URL` only for migrations, observer scripts, direct admin probes, and rollout tooling.
3. `TRR_DB_TRANSACTION_URL` only after code paths explicitly disable prepared statements and transaction-mode compatibility is tested.
4. `TRR_DB_URL` remains backwards-compatible alias for `TRR_DB_SESSION_URL` during this phase.
5. `TRR_DB_FALLBACK_URL` remains operator-engaged fallback only.

App:

1. `TRR_DB_SESSION_URL` is allowed but capped by Task 3.
2. `TRR_DB_TRANSACTION_URL` is not used until node-postgres prepared statement behavior is verified and tests prove compatibility.
3. `TRR_DB_DIRECT_URL` is prohibited in deployed app runtime unless explicitly allowlisted for an operator script, not a server route.
4. `TRR_DB_URL` remains alias during transition.

**Steps**

- [ ] Add resolver support for new env names without deleting existing `TRR_DB_URL`.
- [ ] Add warnings when legacy `TRR_DB_URL` is used and new lane envs are absent.
- [ ] Add lane validation errors for deployed app runtime using direct URL.
- [ ] Add tests covering:
  - session URL selected before legacy alias.
  - transaction URL is classified as transaction and rejected where unsupported.
  - direct URL is rejected in app deployed runtime.
  - legacy `TRR_DB_URL` still works.
- [ ] Update docs and env contract.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_connection_resolution.py tests/db/test_pg_pool.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
pnpm exec tsc --noEmit
```

Expected: all existing runtime lanes continue working; new names are available and tested.

**Rollback**

- Keep `TRR_DB_URL` unchanged in all runtime environments; revert only the new-name resolver changes if they cause drift.

### Task 8: Cache High-Fan-Out Admin Reads

**Commit boundary:** `feat: cache admin social read endpoints`

**Files**

- Backend route/repository files for freshness, gap, catalog, and photo reads under `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/` and `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/`
- App proxy/cache helpers under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/trr-api/`
- Existing app route cache under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts` if app-side proxy caching is needed
- Focused backend and app tests

**Target Endpoint Classes**

- Freshness diagnostics
- Gap analysis
- Catalog run progress summaries
- Photo/card summary reads
- Social profile dashboard tabs that are not first paint

**Steps**

- [ ] Inventory exact endpoints from current app routes before editing:

  ```bash
  cd /Users/thomashulihan/Projects/TRR
  rg -n "freshness|gap|catalog|photo|dashboard|summary" TRR-APP/apps/web/src/app/api/admin TRR-APP/apps/web/src/lib/server/trr-api TRR-Backend/api
  ```

- [ ] For each endpoint, classify cache safety:
  - `safe_ttl_30s`: read-only operational summaries.
  - `safe_ttl_5s`: progress/freshness where UI polls.
  - `no_cache`: mutation responses, launch/finalize endpoints, auth-sensitive data.
- [ ] Implement only `safe_ttl_30s` and `safe_ttl_5s` in this task.
- [ ] Use existing route-response cache/in-flight dedupe in app routes where the backend endpoint is not already cached.
- [ ] Add backend cache only where app cache cannot prevent load from multiple clients/processes.
- [ ] Add cache invalidation on mutation routes that affect social account source, run, photo, or catalog state.

**Validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/*cache*.test.ts tests/social-*.test.ts

cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api/routers tests/repositories -k "cache or freshness or gap or catalog or photo"
```

Expected:

- Repeated read requests hit cache/in-flight dedupe.
- Mutations invalidate affected caches.
- Progress endpoints keep short TTL and do not stale-lock terminal state.

**Rollback**

- Disable cache with env flags or revert this commit. Keep Task 1-3 pressure safeguards.

## Validation Plan

### Automated Validation

Run from workspace root unless otherwise stated:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 -m pytest -q scripts/test_workspace_app_env_projection.py scripts/test_preflight_env_contract_policy.py scripts/test_runtime_db_env.py
bash scripts/check-workspace-contract.sh
make env-contract
```

Backend:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_connection_resolution.py tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m pytest -q tests/api/routers/test_admin_social_landing.py
.venv/bin/python -m ruff check api trr_backend tests
```

App:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts tests/social-landing*.test.ts
pnpm exec tsc --noEmit
```

Screenalytics:

```bash
cd /Users/thomashulihan/Projects/TRR/screenalytics
python -m pytest -q tests/api/test_runtime_startup*.py
```

### Manual Validation

1. Restart with new default profile:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   make stop
   make dev
   ```

   Expected ready summary:

   ```text
   Local DB holders: app=1, backend=2, social_profile=4, social_control=2, health=1, total=10
   ```

2. Verify social landing:

   ```bash
   curl -sS -o /tmp/trr-social-landing.json -w '%{http_code} %{time_total}\n' \
     http://127.0.0.1:3000/api/admin/social/landing
   ```

   Expected: `200`, ideally under 3 seconds warm and without fresh `EMAXCONNSESSION`.

3. Verify logs:

   ```bash
   rg -n "postgres_pool_init|postgres_pool_queue_depth|EMAXCONNSESSION|MaxClientsInSessionMode" \
     /Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log
   ```

   Expected: pool init shows local `pool_max=1`; no fresh max-client failures after startup.

4. Verify backend pressure endpoint:

   ```bash
   curl -sS http://127.0.0.1:8000/health/live
   curl -sS http://127.0.0.1:8000/health/db-pressure
   ```

   Expected: liveness stays OK; DB pressure endpoint reports `ok` or `degraded` with clear reason.

5. Verify Screenalytics DB disabled by default:

   ```bash
   rg -n "startup-config.*TRR_DB|SCREENALYTICS_DB_ENABLED" \
     /Users/thomashulihan/Projects/TRR/screenalytics/.logs/uvicorn.log \
     /Users/thomashulihan/Projects/TRR/.logs/workspace/*.log
   ```

   Expected: startup says DB-backed metadata is disabled unless explicitly enabled.

## Risk and Rollback

| Risk | Mitigation | Rollback |
|---|---|---|
| App pool max `1` makes admin pages slower. | Move high-fan-out reads to backend and cache them; allow explicit env override for temporary debugging. | `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=4 WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=4 make dev`. |
| Backend general pool max `2` starves generic backend reads. | Keep `social_profile`, `social_control`, and `health` named pools; observe `/health/db-pressure`. | Set `TRR_DB_POOL_MAXCONN=4` while keeping app pool capped. |
| Disabling remote social workers in default local dev hides background job issues. | Keep explicit opt-in documented for backfill/debug sessions. | `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 make dev`. |
| Raising Supavisor pool size masks bad fan-out. | Time-box manual raise, record it, and lower it after tasks land. | Restore pool size to `15` in Supabase settings. |
| Moving app direct SQL to backend changes response shape. | Add backend contract tests and update `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` in same session. | Revert app consumer commit first. |
| Transaction-mode URL is introduced too early. | Add env names first, but do not route app/backend runtime to transaction mode until prepared statement compatibility is proven. | Keep `TRR_DB_URL`/`TRR_DB_SESSION_URL` as selected lane. |
| Screenalytics workflows that need DB stop working in default dev. | Provide explicit `WORKSPACE_SCREENALYTICS_DB_ENABLED=1`. | Set the env override or revert Task 6. |

## Assumptions

- The observed `pool_size: 15` is the current Supavisor session-mode pool limit for the TRR Supabase project. This must be re-verified before production pool-size changes.
- The local target budget should be at least five slots below the Supavisor session pool size. With pool size `15`, the target is `10` or lower.
- App direct SQL should be treated as a transitional path. Backend APIs own durable app/backend data contracts.
- Session mode remains the normal backend lane until transaction-mode prepared-statement compatibility is proven.
- `TRR_DB_URL` cannot be removed in this plan; it remains compatibility alias while new lane-specific names are introduced.
- Generated docs must be regenerated, not hand-edited, where the repo already owns a generator.

## Execution Handoff

Saved path:

```text
/Users/thomashulihan/Projects/TRR/docs/superpowers/plans/2026-04-26-supavisor-session-pool-stabilization.md
```

Recommended execution: **subagent-driven**, because this plan spans disjoint ownership surfaces: workspace launcher/contracts, TRR-APP Postgres and route fan-out, TRR-Backend health/API contracts, and Screenalytics startup behavior.

Execution should use `superpowers:subagent-driven-development` with separate workers for:

1. Workspace profile/contract headroom.
2. TRR-APP pool logging and social landing fan-out.
3. TRR-Backend pressure endpoint and landing summary API.
4. Screenalytics DB startup gating.

