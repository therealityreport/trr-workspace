# Local Dev Supabase Connection Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make local `make dev` and direct backend/app launches use the intended Supabase session-pooler connection budget, with guardrails that prevent oversized local pools from silently returning.

**Architecture:** Keep the current canonical runtime lane: `TRR_DB_URL` first, optional `TRR_DB_FALLBACK_URL` second, and session-mode Supavisor on `:5432` or local Postgres only. Fix the drift at the small number of shared connection surfaces: backend pool sizing, app pool sizing, workspace startup projection, generated env docs, and capacity-budget documentation.

**Tech Stack:** Bash workspace launcher, Python/FastAPI/psycopg2 backend, TypeScript/Next.js/node-postgres app, Supabase Postgres 17, Supavisor session-pooler mode.

---

## Review Summary

Current verified facts:

- Supabase MCP SQL was unavailable in this Codex session due MCP permissions, so live DB verification used the repo's configured `TRR_DB_URL` without printing credentials.
- Live Postgres settings: `max_connections=60`, `statement_timeout=120000ms`, `idle_in_transaction_session_timeout=0`. Backend code still applies app-level `statement_timeout=30000ms` and `idle_in_transaction_session_timeout=60000ms`.
- Live `pg_stat_activity` snapshot during review showed 20 total connections: 9 Supavisor client-facing rows, 3 Supabase service rows, 6 internal/local rows, and the review query itself.
- `TRR-APP/apps/web/.env.local` and `TRR-Backend/.env` both point `TRR_DB_URL` at Supavisor session mode on `aws-1-us-east-1.pooler.supabase.com:5432`.
- Checked-in local profiles now set `TRR_DB_POOL_MINCONN=1`, `TRR_DB_POOL_MAXCONN=4`, `TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1`, `TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4`, and `TRR_HEALTH_DB_POOL_MAXCONN=1`.
- Local `TRR-Backend/.env` still contains `TRR_DB_POOL_MINCONN=4` and `TRR_DB_POOL_MAXCONN=16`. `PROFILE=default make dev` currently exports profile values first, but direct `TRR-Backend/start-api.sh` launches can still consume the oversized `.env` values.
- `TRR-APP/apps/web/src/lib/server/postgres.ts` currently defaults deployed session-pooler runtime to `POSTGRES_POOL_MAX=6` and `POSTGRES_MAX_CONCURRENT_OPERATIONS=6`, while `docs/workspace/supabase-capacity-budget.md` budgets production app holders at `POSTGRES_POOL_MAX=4` and `POSTGRES_MAX_CONCURRENT_OPERATIONS=2`.
- Backend tests around Modal clamping are misleading: they pass under pytest's local-test marker rather than proving `_is_modal_container_runtime()` actually clamps oversized session-pooler overrides.
- Plan Grader follow-up incorporated on 2026-04-24: isolate pytest's `PYTEST_CURRENT_TEST` marker in the `TRR_LOCAL_DEV` regression, add a dirty-worktree protocol, and add rollback monitoring for the deployed app pool default change.

## File Structure

- Modify `TRR-Backend/trr_backend/db/pg.py`: backend pool sizing policy, local-dev marker detection, Modal session-pooler clamp, and non-secret pool sizing diagnostics.
- Modify `TRR-Backend/tests/db/test_pg_pool.py`: focused regression tests for direct local backend launches and Modal session-pooler clamping.
- Modify `TRR-APP/apps/web/src/lib/server/postgres.ts`: app session-pooler default sizing constants.
- Modify `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`: app pool sizing expectations and env override coverage.
- Modify `scripts/dev-workspace.sh`: startup summary for effective local DB holder budget.
- Modify `scripts/test_workspace_app_env_projection.py`: workspace-launcher regression coverage for the app pool projection and new budget summary.
- Modify `scripts/check-workspace-contract.sh`: keep default profile and generated env docs locked to the local session-pooler budget.
- Modify `scripts/workspace-env-contract.sh`: source text for generated env docs.
- Modify `profiles/default.env`, `profiles/social-debug.env`, `profiles/local-cloud.env`: local profile pool values if they are not already at the target values.
- Regenerate `docs/workspace/env-contract.md`: generated env contract.
- Modify `docs/workspace/supabase-capacity-budget.md`: manual capacity math and local-workspace explanation.

## Target Connection Contract

The implementation must preserve these values:

```text
Default local backend pool:        TRR_DB_POOL_MINCONN=1, TRR_DB_POOL_MAXCONN=4
Default local social-profile pool: TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1, TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4
Default local health pool:         TRR_HEALTH_DB_POOL_MINCONN=1, TRR_HEALTH_DB_POOL_MAXCONN=1
Default local app session pool:    POSTGRES_POOL_MAX=4, POSTGRES_MAX_CONCURRENT_OPERATIONS=4
Social-debug app session pool:     POSTGRES_POOL_MAX=2, POSTGRES_MAX_CONCURRENT_OPERATIONS=2
Deployed app session pool:         POSTGRES_POOL_MAX=4, POSTGRES_MAX_CONCURRENT_OPERATIONS=2
Local session-pooler hard ceiling: 8 per backend pool, only for explicit local/debug overrides
```

The local workspace connection holder maximum under `PROFILE=default make dev` is:

```text
TRR-APP pool                 4
TRR-Backend default pool     4
TRR-Backend social_profile   4
TRR-Backend health           1
Total                       13
```

The lower-pressure social debug lane is:

```text
TRR-APP pool                 2
TRR-Backend default pool     4
TRR-Backend social_profile   4
TRR-Backend health           1
Total                       11
```

## Execution Safety Protocol

Run this before Task 1 in any implementation session.

- [ ] **Step 0.1: Inspect the existing dirty worktree**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
git diff -- docs/workspace/env-contract.md docs/workspace/supabase-capacity-budget.md profiles/default.env profiles/local-cloud.env profiles/social-debug.env scripts/check-workspace-contract.sh docs/superpowers/plans/2026-04-24-local-dev-supabase-connection-stability.md
```

Expected: either no unrelated changes, or existing local connection-budget/profile changes already match this plan.

- [ ] **Step 0.2: Stop if target-file changes do not match this plan**

If the diff includes unrelated edits in the target files, stop and ask the owner whether to preserve, split, or commit them separately before staging. Do not run broad `git add .`; every commit below stages only named files.

### Task 1: Backend Local Marker And Modal Clamp

**Files:**
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
- Modify: `TRR-Backend/trr_backend/db/pg.py`

- [ ] **Step 1: Add failing backend pool sizing tests**

Add these tests after `test_resolve_pool_sizing_keeps_production_session_defaults_conservative` in `TRR-Backend/tests/db/test_pg_pool.py`:

```python
def test_resolve_pool_sizing_treats_trr_local_dev_as_local_runtime(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("ENV", raising=False)
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    monkeypatch.delenv("TRR_ENV", raising=False)
    monkeypatch.delenv("TRR_ENVIRONMENT", raising=False)
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    monkeypatch.setenv("TRR_LOCAL_DEV", "1")
    monkeypatch.setenv("TRR_DB_POOL_MINCONN", "4")
    monkeypatch.setenv("TRR_DB_POOL_MAXCONN", "16")

    sizing = pg._resolve_pool_sizing(
        "postgresql://postgres.ref:pw@aws-1-us-east-1.pooler.supabase.com:5432/postgres"
    )

    assert sizing["requested_minconn"] == 4
    assert sizing["requested_maxconn"] == 16
    assert sizing["minconn"] == 4
    assert sizing["maxconn"] == 8
    assert sizing["session_pooler_override_clamped"] is True
    assert sizing["modal_session_pooler_override_clamped"] is False
    assert sizing["maxconn_source"] == "clamped:local_session_pooler_ceiling"


def test_resolve_pool_sizing_clamps_modal_session_pooler_overrides_without_pytest_marker(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("ENV", raising=False)
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    monkeypatch.delenv("TRR_ENV", raising=False)
    monkeypatch.delenv("TRR_ENVIRONMENT", raising=False)
    monkeypatch.delenv("TRR_LOCAL_DEV", raising=False)
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    monkeypatch.setenv("MODAL_TASK_ID", "ta-123")
    monkeypatch.setenv("TRR_DB_POOL_MINCONN", "4")
    monkeypatch.setenv("TRR_DB_POOL_MAXCONN", "16")

    sizing = pg._resolve_pool_sizing(
        "postgresql://postgres.ref:pw@aws-1-us-east-1.pooler.supabase.com:5432/postgres"
    )

    assert sizing["requested_minconn"] == 4
    assert sizing["requested_maxconn"] == 16
    assert sizing["minconn"] == 4
    assert sizing["maxconn"] == 8
    assert sizing["session_pooler_override_clamped"] is False
    assert sizing["modal_session_pooler_override_clamped"] is True
    assert sizing["maxconn_source"] == "clamped:modal_session_pooler_ceiling"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
TRR-Backend/.venv/bin/python -m pytest -q TRR-Backend/tests/db/test_pg_pool.py -k 'trr_local_dev_as_local_runtime or modal_session_pooler_overrides_without_pytest_marker'
```

Expected: both new tests fail. The first fails because `PYTEST_CURRENT_TEST` is removed and `TRR_LOCAL_DEV=1` is not part of `_is_local_or_dev_runtime()`. The second fails because `modal_session_pooler_override_clamped` is never set to `True`.

- [ ] **Step 3: Implement local marker and Modal clamp**

In `TRR-Backend/trr_backend/db/pg.py`, replace `_is_local_or_dev_runtime()` and the clamp block in `_resolve_pool_sizing()` with this code:

```python
def _env_truthy(name: str) -> bool:
    return (os.getenv(name) or "").strip().lower() in {"1", "true", "yes", "on"}


def _is_local_or_dev_runtime() -> bool:
    runtime_markers = [
        os.getenv("APP_ENV"),
        os.getenv("ENV"),
        os.getenv("ENVIRONMENT"),
        os.getenv("TRR_ENV"),
        os.getenv("TRR_ENVIRONMENT"),
    ]
    normalized = {str(value or "").strip().lower() for value in runtime_markers if str(value or "").strip()}
    if normalized & {"prod", "production"}:
        return False
    if normalized & {"local", "dev", "development", "test"}:
        return True
    if _env_truthy("TRR_LOCAL_DEV"):
        return True
    return bool(os.getenv("PYTEST_CURRENT_TEST"))
```

Then replace the existing session-pooler clamp block:

```python
if session_pooler and _is_local_or_dev_runtime() and maxconn > LOCAL_SESSION_POOLER_MAX_CEILING:
    maxconn = LOCAL_SESSION_POOLER_MAX_CEILING
    maxconn_source = "clamped:local_session_pooler_ceiling"
    session_pooler_override_clamped = True
if minconn > maxconn:
    minconn = maxconn
    if session_pooler and _is_local_or_dev_runtime():
        minconn_source = "clamped:local_session_pooler_ceiling"
        session_pooler_override_clamped = True
```

with:

```python
if session_pooler and _is_modal_container_runtime() and maxconn > DEFAULT_MODAL_SESSION_POOLER_MAXCONN:
    maxconn = DEFAULT_MODAL_SESSION_POOLER_MAXCONN
    maxconn_source = "clamped:modal_session_pooler_ceiling"
    modal_session_pooler_override_clamped = True
elif session_pooler and _is_local_or_dev_runtime() and maxconn > LOCAL_SESSION_POOLER_MAX_CEILING:
    maxconn = LOCAL_SESSION_POOLER_MAX_CEILING
    maxconn_source = "clamped:local_session_pooler_ceiling"
    session_pooler_override_clamped = True
if minconn > maxconn:
    minconn = maxconn
    if session_pooler and _is_modal_container_runtime():
        minconn_source = "clamped:modal_session_pooler_ceiling"
        modal_session_pooler_override_clamped = True
    elif session_pooler and _is_local_or_dev_runtime():
        minconn_source = "clamped:local_session_pooler_ceiling"
        session_pooler_override_clamped = True
```

- [ ] **Step 4: Run backend DB tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
TRR-Backend/.venv/bin/python -m pytest -q TRR-Backend/tests/db/test_pg_pool.py TRR-Backend/tests/db/test_pg_timeout_settings.py
```

Expected: all tests pass.

- [ ] **Step 5: Commit backend clamp fix**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/db/pg.py TRR-Backend/tests/db/test_pg_pool.py
git commit -m "fix: enforce local supabase pool ceilings"
```

### Task 2: App Session-Pooler Defaults Match Budget

**Files:**
- Modify: `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- Modify: `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Modify: `docs/workspace/supabase-capacity-budget.md`

- [ ] **Step 1: Update failing app pool sizing tests**

In `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`, replace the `resolvePostgresPoolSizing` describe block with:

```ts
describe("resolvePostgresPoolSizing", () => {
  it("keeps session defaults bounded in local development", () => {
    const sizing = resolvePostgresPoolSizing(
      "postgresql://postgres.ref:secret@aws-1-us-east-1.pooler.supabase.com:5432/postgres",
      { NODE_ENV: "development" },
    );

    expect(sizing).toEqual({
      maxConcurrentOperations: 4,
      poolMax: 4,
    });
  });

  it("keeps deployed session defaults inside the Supabase capacity budget", () => {
    const sizing = resolvePostgresPoolSizing(
      "postgresql://postgres.ref:secret@aws-1-us-east-1.pooler.supabase.com:5432/postgres",
      { NODE_ENV: "production" },
    );

    expect(sizing).toEqual({
      maxConcurrentOperations: 2,
      poolMax: 4,
    });
  });

  it("honors explicit local debug pool overrides", () => {
    const sizing = resolvePostgresPoolSizing(
      "postgresql://postgres.ref:secret@aws-1-us-east-1.pooler.supabase.com:5432/postgres",
      {
        NODE_ENV: "development",
        POSTGRES_POOL_MAX: "2",
        POSTGRES_MAX_CONCURRENT_OPERATIONS: "2",
      },
    );

    expect(sizing).toEqual({
      maxConcurrentOperations: 2,
      poolMax: 2,
    });
  });
});
```

- [ ] **Step 2: Run test to verify production default fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
pnpm -C TRR-APP/apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts
```

Expected: the deployed session default test fails because the current code returns `{ maxConcurrentOperations: 6, poolMax: 6 }`.

- [ ] **Step 3: Implement explicit app defaults**

In `TRR-APP/apps/web/src/lib/server/postgres.ts`, add constants after `DEFAULT_TRANSACTION_SEARCH_PATH`:

```ts
const DEFAULT_SESSION_POOL_MAX = 4;
const DEFAULT_SESSION_POOL_MAX_CONCURRENT_OPERATIONS_LOCAL = 4;
const DEFAULT_SESSION_POOL_MAX_CONCURRENT_OPERATIONS_DEPLOYED = 2;
```

Then replace `resolvePostgresPoolSizing()` with:

```ts
export const resolvePostgresPoolSizing = (
  connectionString: string,
  env: EnvLike = process.env,
): PostgresPoolSizing => {
  const isDevelopment = env.NODE_ENV === "development";
  const isSessionPooler = isSupavisorSessionPoolerConnectionString(connectionString);
  const defaultSessionMaxConcurrentOperations = isDevelopment
    ? DEFAULT_SESSION_POOL_MAX_CONCURRENT_OPERATIONS_LOCAL
    : DEFAULT_SESSION_POOL_MAX_CONCURRENT_OPERATIONS_DEPLOYED;
  return {
    maxConcurrentOperations:
      parsePositiveInt(env.POSTGRES_MAX_CONCURRENT_OPERATIONS) ??
      (isSessionPooler ? defaultSessionMaxConcurrentOperations : isDevelopment ? 8 : 12),
    poolMax:
      parsePositiveInt(env.POSTGRES_POOL_MAX) ??
      (isSessionPooler ? DEFAULT_SESSION_POOL_MAX : isDevelopment ? 8 : 10),
  };
};
```

- [ ] **Step 4: Run app DB tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
pnpm -C TRR-APP/apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts
```

Expected: all tests pass.

- [ ] **Step 5: Record deployed rollback guard**

In `docs/workspace/supabase-capacity-budget.md`, add this paragraph after the Vercel sizing table:

```markdown
Deployment rollback guard: after lowering deployed session-pooler defaults to `POSTGRES_POOL_MAX=4` and `POSTGRES_MAX_CONCURRENT_OPERATIONS=2`, watch `event=postgres_pool_queue_depth`, admin route p95 latency, and Vercel function error rate for the first production deploy. If steady-state queue depth becomes non-zero or admin route p95 regresses, set environment overrides `POSTGRES_POOL_MAX=6` and `POSTGRES_MAX_CONCURRENT_OPERATIONS=6` for the affected environment before changing code again.
```

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "Deployment rollback guard|postgres_pool_queue_depth|POSTGRES_POOL_MAX=6" docs/workspace/supabase-capacity-budget.md
```

Expected:

```text
... Deployment rollback guard ...
```

- [ ] **Step 6: Commit app sizing fix**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-APP/apps/web/src/lib/server/postgres.ts TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts docs/workspace/supabase-capacity-budget.md
git commit -m "fix: align app postgres pool defaults"
```

### Task 3: Workspace Startup Shows Effective Local DB Budget

**Files:**
- Modify: `scripts/dev-workspace.sh`
- Modify: `scripts/test_workspace_app_env_projection.py`

- [ ] **Step 1: Add failing workspace summary test**

In `scripts/test_workspace_app_env_projection.py`, add `DEFAULT_PROFILE = ROOT / "profiles" / "default.env"` after the existing path constants:

```python
DEFAULT_PROFILE = ROOT / "profiles" / "default.env"
```

Then add these tests inside `WorkspaceAppEnvProjectionTests`:

```python
    def test_default_profile_keeps_backend_pool_budget_at_four(self) -> None:
        text = DEFAULT_PROFILE.read_text(encoding="utf-8")
        self.assertIn("TRR_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_DB_POOL_MAXCONN=4", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)

    def test_dev_workspace_prints_effective_db_holder_budget(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("workspace_effective_db_holder_budget()", text)
        self.assertIn("Local DB holders:", text)
        self.assertIn("app=", text)
        self.assertIn("backend=", text)
        self.assertIn("social_profile=", text)
        self.assertIn("health=", text)
        self.assertIn("total=", text)
```

- [ ] **Step 2: Run workspace test to verify summary test fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 -m pytest -q scripts/test_workspace_app_env_projection.py
```

Expected: `test_dev_workspace_prints_effective_db_holder_budget` fails because the workspace ready summary does not print the local DB holder budget yet.

- [ ] **Step 3: Implement non-secret budget summary**

In `scripts/dev-workspace.sh`, add this helper after `workspace_startup_runtime_summary()`:

```bash
workspace_positive_int_or_default() {
  local value="$1"
  local default_value="$2"
  if [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$value"
    return 0
  fi
  echo "$default_value"
}

workspace_effective_db_holder_budget() {
  local app_pool
  local backend_pool
  local social_profile_pool
  local health_pool
  local total

  app_pool="$(workspace_positive_int_or_default "${WORKSPACE_TRR_APP_POSTGRES_POOL_MAX:-${POSTGRES_POOL_MAX:-}}" "4")"
  backend_pool="$(workspace_positive_int_or_default "${TRR_DB_POOL_MAXCONN:-}" "4")"
  social_profile_pool="$(workspace_positive_int_or_default "${TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN:-}" "4")"
  health_pool="$(workspace_positive_int_or_default "${TRR_HEALTH_DB_POOL_MAXCONN:-}" "1")"
  total=$(( app_pool + backend_pool + social_profile_pool + health_pool ))

  printf 'app=%s, backend=%s, social_profile=%s, health=%s, total=%s' \
    "$app_pool" \
    "$backend_pool" \
    "$social_profile_pool" \
    "$health_pool" \
    "$total"
}
```

Then add this line to `print_workspace_ready_summary()` after the `Summary:` line:

```bash
  echo "  Local DB holders: $(workspace_effective_db_holder_budget)"
```

- [ ] **Step 4: Run workspace projection tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 -m pytest -q scripts/test_workspace_app_env_projection.py
```

Expected: all tests pass.

- [ ] **Step 5: Commit workspace summary fix**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git add scripts/dev-workspace.sh scripts/test_workspace_app_env_projection.py
git commit -m "chore: show local db holder budget"
```

### Task 4: Profile And Contract Guardrails

**Files:**
- Modify: `profiles/default.env`
- Modify: `profiles/social-debug.env`
- Modify: `profiles/local-cloud.env`
- Modify: `scripts/check-workspace-contract.sh`
- Modify: `scripts/workspace-env-contract.sh`
- Regenerate: `docs/workspace/env-contract.md`
- Modify: `docs/workspace/supabase-capacity-budget.md`

- [ ] **Step 1: Verify profile targets before editing**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
for f in profiles/default.env profiles/social-debug.env profiles/local-cloud.env; do
  echo "$f"
  rg -n '^(TRR_DB_POOL_MINCONN|TRR_DB_POOL_MAXCONN|TRR_SOCIAL_PROFILE_DB_POOL_MINCONN|TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN|TRR_HEALTH_DB_POOL_MINCONN|TRR_HEALTH_DB_POOL_MAXCONN|WORKSPACE_TRR_APP_POSTGRES_POOL_MAX|WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS)=' "$f"
done
```

Expected:

```text
profiles/default.env
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4
TRR_HEALTH_DB_POOL_MINCONN=1
TRR_HEALTH_DB_POOL_MAXCONN=1
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=4
profiles/social-debug.env
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=4
WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=2
WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=2
profiles/local-cloud.env
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=4
```

- [ ] **Step 2: Fix profile files if any value differs**

If the verification output differs, set the profile entries to exactly:

```dotenv
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4
TRR_HEALTH_DB_POOL_MINCONN=1
TRR_HEALTH_DB_POOL_MAXCONN=1
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=4
```

For `profiles/social-debug.env`, also set:

```dotenv
WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=2
WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=2
```

- [ ] **Step 3: Ensure workspace contract checker locks the target values**

In `scripts/check-workspace-contract.sh`, keep these assertions:

```bash
assert_equals "profiles/default.env social profile db pool min" "1" "$social_profile_pool_min_profile_default"
assert_equals "profiles/default.env social profile db pool max" "4" "$social_profile_pool_max_profile_default"
assert_equals "profiles/default.env db pool min" "1" "$db_pool_min_profile_default"
assert_equals "profiles/default.env db pool max" "4" "$db_pool_max_profile_default"
assert_equals "docs/workspace/env-contract.md social profile db pool min" "1" "$social_profile_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md social profile db pool max" "4" "$social_profile_pool_max_doc_default"
assert_equals "docs/workspace/env-contract.md db pool min" "1" "$db_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md db pool max" "4" "$db_pool_max_doc_default"
```

Also keep these app projection assertions:

```bash
assert_equals "profiles/default.env app postgres pool max remains unset" "" "$default_app_pool_max"
assert_equals "profiles/default.env app postgres max concurrent operations remains unset" "" "$default_app_max_ops"
assert_equals "profiles/social-debug.env app postgres pool max" "2" "$social_debug_app_pool_max"
assert_equals "profiles/social-debug.env app postgres max concurrent operations" "2" "$social_debug_app_max_ops"
assert_equals "docs/workspace/env-contract.md app postgres pool max default" "" "$doc_app_pool_max_default"
assert_equals "docs/workspace/env-contract.md app postgres max concurrent operations default" "" "$doc_app_max_ops_default"
```

- [ ] **Step 4: Keep generated env text in source generator**

In `scripts/workspace-env-contract.sh`, keep `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX` and `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS` descriptions as optional debug-profile overrides:

```bash
WORKSPACE_TRR_APP_POSTGRES_POOL_MAX)
  echo "Optional TRR-APP child-process override for \`POSTGRES_POOL_MAX\`. Leave unset in the default profile; set it in targeted debug profiles such as \`social-debug\`."
  ;;
WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS)
  echo "Optional TRR-APP child-process override for \`POSTGRES_MAX_CONCURRENT_OPERATIONS\`. Leave unset in the default profile; set it in targeted debug profiles such as \`social-debug\`."
  ;;
```

- [ ] **Step 5: Regenerate and check env docs**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
./scripts/workspace-env-contract.sh --generate
./scripts/workspace-env-contract.sh --check
bash ./scripts/check-workspace-contract.sh
```

Expected:

```text
[env-contract] OK
[workspace-contract] OK
```

- [ ] **Step 6: Update capacity budget math**

In `docs/workspace/supabase-capacity-budget.md`, make these values true:

```markdown
| Production (session pooler) | 4 | 2 |
| Development (session pooler) | 4 | 4 |
| Development (direct/local Postgres) | 8 | 8 |
```

Keep the Render line at:

```markdown
| Default `TRR_DB_POOL_MAXCONN` (session pooler) | 4 | `pg.py:40` |
```

Keep the local-workspace note at:

```markdown
workspace can add up to `13` more session-mode connections (`TRR-APP` local
pool `4` + `TRR-Backend` default pool `4` + dedicated `social_profile` pool
`4` + health pool `1`).
```

Keep the deployment rollback guard paragraph added in Task 2; do not remove it when refreshing capacity math.

- [ ] **Step 7: Commit profile and contract guardrails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git add profiles/default.env profiles/social-debug.env profiles/local-cloud.env scripts/check-workspace-contract.sh scripts/workspace-env-contract.sh docs/workspace/env-contract.md docs/workspace/supabase-capacity-budget.md
git commit -m "docs: lock local supabase connection budget"
```

### Task 5: Runtime Verification

**Files:**
- No source files changed in this task.

- [ ] **Step 1: Verify live DB contract without printing credentials**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
TRR-Backend/.venv/bin/python - <<'PY'
from pathlib import Path
import os
import psycopg2

def load_env(path: str) -> dict[str, str]:
    vals: dict[str, str] = {}
    for line in Path(path).read_text().splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        key, value = s.split("=", 1)
        vals[key.strip()] = value.strip().strip('"').strip("'")
    return vals

vals = load_env("TRR-Backend/.env")
dsn = os.environ.get("TRR_DB_URL") or vals.get("TRR_DB_URL")
if not dsn:
    raise SystemExit("missing TRR_DB_URL")

conn = psycopg2.connect(dsn=dsn, connect_timeout=10, application_name="trr-local-dev-connection-verification")
conn.autocommit = True
with conn.cursor() as cur:
    cur.execute(
        """
        select name, setting, coalesce(unit, '')
        from pg_settings
        where name in (
          'max_connections',
          'superuser_reserved_connections',
          'reserved_connections',
          'statement_timeout',
          'idle_in_transaction_session_timeout'
        )
        order by name
        """
    )
    print("settings")
    for row in cur.fetchall():
        print("\t".join(map(str, row)))
    cur.execute(
        """
        select coalesce(application_name, ''), coalesce(state, ''), count(*)::int
        from pg_stat_activity
        group by 1, 2
        order by count(*) desc, 1, 2
        limit 25
        """
    )
    print("activity")
    for row in cur.fetchall():
        print("\t".join(map(str, row)))
conn.close()
PY
```

Expected:

```text
settings
idle_in_transaction_session_timeout	0	ms
max_connections	60
reserved_connections	0
statement_timeout	120000	ms
superuser_reserved_connections	3
activity
...
```

Connection counts may vary, but total live activity should stay well below 60 before starting local load tests.

- [ ] **Step 2: Verify runtime migration reconcile is clean**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
TRR-Backend/.venv/bin/python TRR-Backend/scripts/dev/reconcile_runtime_db.py --json
```

Expected JSON fields:

```json
{
  "state": "ok",
  "pending_local": [],
  "remote_only": [],
  "applied_versions": []
}
```

- [ ] **Step 3: Run all focused connection tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
TRR-Backend/.venv/bin/python -m pytest -q TRR-Backend/tests/db/test_pg_pool.py TRR-Backend/tests/db/test_pg_timeout_settings.py
pnpm -C TRR-APP/apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts
python3 -m pytest -q scripts/test_workspace_app_env_projection.py scripts/test_preflight_env_contract_policy.py scripts/test_runtime_db_env.py
```

Expected:

```text
45 passed
1 passed test file for postgres-connection-string-resolution.test.ts
10 passed
```

- [ ] **Step 4: Verify production rollback guard is documented**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "Deployment rollback guard|postgres_pool_queue_depth|POSTGRES_POOL_MAX=6|POSTGRES_MAX_CONCURRENT_OPERATIONS=6" docs/workspace/supabase-capacity-budget.md
```

Expected: the rollback guard paragraph is present and names both env overrides.

- [ ] **Step 5: Start local dev and verify the visible DB budget**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
PROFILE=default make dev
```

Expected workspace ready summary includes:

```text
Local DB holders: app=4, backend=4, social_profile=4, health=1, total=13
```

Stop the workspace with `Ctrl+C` after the ready summary is confirmed.

- [ ] **Step 6: Verify social-debug budget**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
PROFILE=social-debug make dev
```

Expected workspace ready summary includes:

```text
Local DB holders: app=2, backend=4, social_profile=4, health=1, total=11
```

Stop the workspace with `Ctrl+C` after the ready summary is confirmed.

- [ ] **Step 7: Commit verification note if needed**

If verification uncovers documentation-only output drift, update `docs/workspace/supabase-capacity-budget.md` with the observed non-secret counts and run:

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/workspace/supabase-capacity-budget.md
git commit -m "docs: refresh supabase capacity snapshot"
```

If no documentation changes are needed, do not create an empty commit.

## Self-Review

Spec coverage:

- Reviewed local Supabase connection surfaces across workspace profiles, app runtime, backend runtime, startup scripts, generated docs, capacity docs, tests, and live DB settings.
- The plan fixes observed issues: direct backend launches missing the local marker, fake Modal clamp coverage, app default sizing drift, local startup budget opacity, and profile/docs guardrail drift.
- The plan improves efficiency and stability by keeping session-pooler pools bounded, making debug lanes explicit, and showing local holder totals before saturation becomes a UI timeout.
- Plan Grader follow-up is covered by the execution safety protocol, the corrected pytest isolation test, and the deployment rollback guard.

Placeholder scan:

- No placeholder steps are included.
- Every code-changing task includes exact file paths, concrete code, commands, and expected outputs.

Type consistency:

- Backend function names match existing `pg.py` names.
- App test names and imported functions match `postgres.ts`.
- Workspace helper names are defined before they are used in `print_workspace_ready_summary()`.
