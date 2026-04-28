# Revised Plan: Supavisor Session Pool Stabilization

## Goal

Stop TRR admin routes from failing with `EMAXCONNSESSION` / `MaxClientsInSessionMode` by reducing default session holders, capturing real Supavisor holder evidence, separating local and production capacity models, and moving social landing direct SQL behind backend-owned APIs.

Primary symptom: `http://127.0.0.1:3000/api/admin/social/landing` intermittently fails or retries because the session-mode pool reaches `pool_size: 15`.

## Non-Goals

- Do not migrate runtime traffic to Supavisor transaction mode in this plan.
- Do not remove `TRR_DB_URL`; keep it as a compatibility alias while new lane names are added.
- Do not widen local pools as the durable fix.
- Do not treat a per-process pool max as a production-wide connection cap.
- Do not expose detailed DB pool topology through public unauthenticated health endpoints.
- Do not rewrite the whole social landing payload in one backend endpoint.
- Do not put DB pressure into `/health/live`.

## Local vs Production Capacity

Local holder budget and production capacity budget are different models.

Local `make dev` budget is a single-workspace process budget. Production rollout requires multiplying pool maxima by the number of app instances, backend replicas, workers, scripts, and Screenalytics processes that can exist at the same time.

Production formula:

```text
total_possible_sessions =
  app_instances * app_pool_max
+ backend_replicas * (
    default_pool_max
  + social_profile_pool_max
  + social_control_pool_max
  + health_pool_max
  )
+ screenalytics_instances * screenalytics_pool_max
+ other scripts/workers
+ Supabase internal/services
```

For Vercel or serverless-style deployments, `poolMax=2` is not "2 connections" globally. If 20 instances can exist, that lane can demand 40 session-mode connections.

## Execution Model

This is multi-repo work, but execution must happen from the current checkout only.

Do not create or switch branches. Do not create additional git worktrees. Do not use `git switch`, `git checkout -b`, `git worktree add`, or parallel branch-based merge flows for this implementation.

The orchestrator owns the single working tree and integrates every change in order. Subagents may help implement quickly, but they must work inside this single-checkout coordination model:

- The orchestrator assigns each subagent a disjoint write set.
- A subagent may edit only files in its assigned write set.
- If a subagent runs in an isolated or forked execution environment, it must return a patch/diff plus validation notes; the orchestrator applies the patch in the current checkout.
- No subagent stages, commits, rebases, switches branches, creates worktrees, or reverts unrelated files.
- The orchestrator runs cross-surface validation after each integration checkpoint.

Treat each nested repo as its own command and staging boundary, not as a separate branch or worktree.

| Area | CWD for commands and integration checkpoints | Notes |
| --- | --- | --- |
| Workspace launcher, profiles, generated docs | `/Users/thomashulihan/Projects/TRR` | Parent workspace repo. Do not stage nested repo changes here. |
| App | `/Users/thomashulihan/Projects/TRR/TRR-APP` or `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web` for commands | `TRR-APP` is its own repo. |
| Backend | `/Users/thomashulihan/Projects/TRR/TRR-Backend` | `TRR-Backend` is a nested repo and ignored by the parent. |
| Screenalytics | `/Users/thomashulihan/Projects/TRR/screenalytics` | Confirm whether it is nested git before staging. |

Before editing, run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
git -C TRR-APP status --short
git -C TRR-Backend status --short
git -C screenalytics status --short || true
```

Do not overwrite unrelated dirty files. If a target file is already dirty, inspect it and preserve user changes.

## Subagent Orchestration Plan

Use `superpowers:subagent-driven-development` for implementation, with the main session acting as orchestrator.

### Orchestrator Responsibilities

- Keep the single checkout on the current branch.
- Read current dirty state before assigning work.
- Assign disjoint write sets and clear validation commands.
- Integrate subagent patches serially.
- Resolve cross-repo contract drift.
- Run shared validation after each integration checkpoint.
- Stop and re-plan if two workers need the same file or if a worker discovers a route/env contract that invalidates the plan.

### Worker Lanes

| Worker | Phase focus | Write set | Can run in parallel with |
| --- | --- | --- | --- |
| Evidence worker | Phase 0 and Phase 1 | docs/runbook updates only, unless explicitly promoted by orchestrator | Discovery worker, workspace worker |
| Discovery worker | Phase 2 | read-only inventory and notes unless asked to update docs | Evidence worker |
| Workspace worker | Phase 3 workspace defaults | `profiles/*`, `scripts/*`, generated env contract docs | App pool worker, Screenalytics worker |
| App pool worker | Phase 3 app pool and Phase 4 app pressure | `TRR-APP/apps/web/src/lib/server/postgres.ts`, app postgres tests, app health diagnostics | Workspace worker, backend pressure worker |
| Backend pressure worker | Phase 4 backend pressure and application names | `TRR-Backend/trr_backend/db/*`, backend health routes/tests | App pool worker, Screenalytics worker |
| Screenalytics worker | Phase 3 Screenalytics DB gate | `screenalytics/apps/api/*`, Screenalytics tests | Workspace worker, backend pressure worker |
| Landing backend worker | Phase 6 backend landing summary | discovered backend social router/repository/tests | Landing app worker only after route contract is locked |
| Landing app worker | Phase 5 and Phase 6 app consumer | social landing route/repository/tests | Backend worker after contract table is locked |
| Direct-SQL removal worker | Phase 7 | landing SocialBlade/cast backend endpoint plus app import removal | Cache/polling worker only after Phase 7 contract is settled |
| Cache/polling worker | Phase 9 | cache helpers, route cache tests, polling hooks/tests | Direct-SQL removal worker only if write sets do not overlap |

### Parallelism Rules

- Phase 0 evidence, Phase 1 production capacity, and Phase 2 discovery can start first, mostly read-only.
- Phase 3 workspace, app pool, backend pressure, and Screenalytics work can run in parallel if their write sets stay disjoint.
- Phase 6 backend route and app consumer work must wait until the contract table is locked.
- Phase 7 direct-SQL removal must wait until Phase 6 is validated.
- Phase 9 caching and polling must wait until the endpoint inventory matrix exists.

### Integration Checkpoints

After each worker returns:

1. Orchestrator reviews the diff for assigned write-set compliance.
2. Orchestrator applies or keeps the changes in the current checkout.
3. Orchestrator runs that worker's targeted validation.
4. Orchestrator runs any cross-surface command listed for the phase.
5. Orchestrator records any changed assumptions before assigning the next dependent worker.

## Pre-Implementation Change Review

| ID | Decision | When | How it is implemented in this plan |
| --- | --- | --- | --- |
| P0.1 Production capacity math | Required | Before any production rollout | Phase 1 adds a production capacity task with instance, replica, worker, Supavisor, and Postgres limits. |
| P0.2 Supavisor holder evidence | Required | Before raising pool size or trusting local pool telemetry | Phase 0 requires `pg_stat_activity`, Dashboard/Grafana, active user/database/mode list, and rollback target. |
| P0.3 `application_name` | Required | Before relying on `pg_stat_activity` | Phase 4 makes application names mandatory for every app/backend/screenalytics/script pool. |
| P0.4 Backend endpoint path | Required | Before backend endpoint work | Phase 6 picks `fetchSocialBackendJson("/landing-summary")` -> `GET /admin/socials/landing-summary`. |
| P0.5 Remaining app direct SQL | Required | After first backend slice | Phase 7 adds Task 5B and requires removing the app postgres import from the landing repository. |
| P0.6 Protected pressure details | Required | With backend/app pressure endpoints | Phase 4 splits public status-only health from internal/admin detailed pressure output. |
| P1.1 Stale/partial semantics | Required for landing changes | Before stale-on-error rollout | Phase 5 adds `AdminDataEnvelope<T>` and explicit omitted-section rules. |
| P1.2 Cache poisoning | Required for cache work | Before broader caching | Phase 9 forbids caching 500/503 as fresh and separates last-good data from live errors. |
| P1.3 App pressure visibility | Required | With app pool cap | Phase 4 adds mandatory app pressure logs and an admin-only app DB pressure endpoint. |
| P1.4 Idle/lifetime controls | Required | With pool cap changes | Phase 3 requires node-postgres timeout/lifetime settings and documents backend minconn tradeoffs. |
| P1.5 CI holder guard | Required | With workspace contract changes | Phase 3 adds `WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1` for CI/contract failure. |
| P1.6 Auth-valid validation | Required | Every manual route check | Release validation requires admin bypass, cookie/header, browser-authenticated request, or diagnostic endpoint. |
| P1.7 Real route timings | Required | Before fan-out migration | Phase 5 expands timing buckets to match actual landing work. |
| P1.8 Frontend polling throttles | Required after endpoint inventory | With broader caching/page simplification | Phase 9 adds poller throttles, hidden-tab behavior, aborts, backoff, and hook tests. |
| P2.1 Endpoint inventory earlier | Required | Before cache implementation | Phase 2 moves inventory before implementation tasks are finalized. |
| P2.2 Feature flags | Required | Before risky route behavior | Feature flag section adds rollback flags. |
| P2.3 Pool-size increase guard | Required | Before production pool-size change | Phase 0 and Phase 1 require snapshots, owner, rollback time, and internal-service review. |

## Feature Flags

Use flags for risky behavior so rollout can be reversed without reverting code.

```text
TRR_ADMIN_SOCIAL_LANDING_BACKEND_SUMMARY_ENABLED=1
TRR_ADMIN_SOCIAL_STALE_ON_ERROR_ENABLED=1
TRR_ADMIN_SOCIAL_ROUTE_TIMINGS_ENABLED=1
TRR_APP_DB_POOL_CAP_STRICT=1
TRR_EXPOSE_DB_PRESSURE_HEALTH=0
```

Rules:

- Route timings can default on locally; production should keep volume low or sampled if logs are noisy.
- Detailed DB pressure output must require internal/admin authorization unless an explicit local-only exposure flag is set.
- Backend-summary feature flag must be removable after the route is stable.

## Phase 0: Evidence And Immediate Local Relief

Objective: release stuck sessions, confirm the fresh failure mode, and capture real holder evidence before changing Supavisor capacity.

### Local Relief Actions

1. Stop local managed processes:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   make stop
   ```

2. Confirm stale local processes are gone:

   ```bash
   ps -axo pid,ppid,command | rg "(next dev|uvicorn|screenalytics|trr_backend|TRR-APP|TRR-Backend)" || true
   ```

3. Restart with explicit low-pressure overrides before code changes:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0 \
   WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1 \
   WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1 \
   TRR_DB_POOL_MAXCONN=2 \
   make dev
   ```

4. Re-test the route using an auth-valid request. If raw curl returns `401` or `403`, use the browser session cookie/header, local admin bypass, or a browser-authenticated request. Do not count an auth failure as DB stability proof.

   ```bash
   curl -sS -o /tmp/trr-social-landing.json -w '%{http_code} %{time_total}\n' \
     http://127.0.0.1:3000/api/admin/social/landing
   ```

5. Capture fresh app logs after the restart timestamp:

   ```bash
   rg -n "EMAXCONNSESSION|MaxClientsInSessionMode|max clients reached|postgres_pool_init|postgres_pool_queue_depth" \
     /Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log
   ```

### Required Supavisor Holder Evidence

Before raising Supavisor pool size or declaring the problem local-only, capture a live connection snapshot grouped by application name, role, client, and state.

```sql
SELECT
  application_name,
  usename,
  client_addr,
  state,
  count(*) AS connections,
  max(now() - backend_start) AS oldest_connection_age,
  max(now() - state_change) AS oldest_state_age
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY application_name, usename, client_addr, state
ORDER BY connections DESC, oldest_connection_age DESC;
```

Also record:

- Supabase Dashboard or Grafana connection snapshot,
- active user + database + pool mode combinations,
- current Supavisor session pool size,
- current Postgres `max_connections`,
- Supabase/internal-service usage or reserved headroom if visible,
- rollback target and rollback time if a pool-size change is made,
- owner responsible for restoring the old pool size.

Write this evidence in `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md` or a new runbook under `/Users/thomashulihan/Projects/TRR/docs/workspace/`.

### Supavisor Pool-Size Rule

Raising production Supavisor pool size to 25 or 30 is an emergency operator action, not the durable fix.

Do not raise production pool size until:

- `pg_stat_activity` snapshot is captured,
- Postgres `max_connections` is known,
- Supabase internal service usage has been reviewed,
- deployment-level instance/replica capacity is known or capped,
- rollback time is recorded,
- owner is assigned.

### Stop Conditions

- Stop before changing Supavisor pool settings if active sessions, internal headroom, or rollback target are unknown.
- Stop if the route still fails under explicit low-pressure overrides; inspect active processes and app/backend logs before editing defaults.

## Phase 1: Production Capacity Budget And Deployment Caps

Objective: make the production part of the plan real before any production rollout.

This phase can run in parallel with local implementation, but it blocks production deployment and production Supavisor pool-size changes.

### Data To Record

- Current Supavisor session pool size.
- Current Postgres `max_connections`.
- App deployment max instances and concurrency.
- Backend worker count, replica count, and worker model.
- Screenalytics instance count and DB pool size if enabled.
- Every process, cron, script, worker, or job that can use `TRR_DB_SESSION_URL`.
- Any process that still uses legacy `TRR_DB_URL` as a session URL.
- Supabase internal/service connection usage or reserved headroom.

### Capacity Calculation

Compute both worst-case and expected-case demand using:

```text
total_possible_sessions =
  app_instances * app_pool_max
+ backend_replicas * (
    default_pool_max
  + social_profile_pool_max
  + social_control_pool_max
  + health_pool_max
  )
+ screenalytics_instances * screenalytics_pool_max
+ other scripts/workers
+ Supabase internal/services
```

### Actions

1. Add or update a production capacity section in `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`.
2. Set deployment-level max instance or concurrency caps if the worst-case demand can exceed available session capacity.
3. Document any temporary production Supavisor pool-size change separately from code changes.
4. Add a rollback owner and date/time for reverting emergency pool-size increases.

### Acceptance Criteria

- Worst-case and expected-case production session demand are written down.
- Vercel/serverless instance multiplication is accounted for.
- Backend replica multiplication is accounted for.
- Production rollout has an explicit capacity pass/fail decision.

## Phase 2: Discovery Locks And Endpoint Inventory

Objective: remove "or current helper" ambiguity and inventory high-fan-out endpoints before implementation tasks are finalized.

### Required Discovery Commands

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "trr_runtime_db_resolve_local_app_url|runtime.*db|TRR_DB_SESSION_URL|TRR_DB_URL" scripts TRR-APP/apps/web/src TRR-Backend
rg -n "APIRouter|include_router|admin.*social|socials" TRR-Backend/api TRR-Backend/trr_backend
rg -n "SCREENALYTICS_DB_ENABLED|TRR_DB_URL|TRR_DB_FALLBACK_URL|load_dotenv|dotenv" screenalytics
rg -n "getCoveredShows|listRedditCommunities|getSocialLandingPayloadResult|safeLoadCastSocialBladeRows|pipeline.socialblade_growth_data|route-response-cache" TRR-APP/apps/web/src
rg -n "freshness|gap|catalog|photo|dashboard|summary|progress" \
  TRR-APP/apps/web/src/app/api/admin \
  TRR-APP/apps/web/src/lib/server/trr-api \
  TRR-Backend/api
```

### Required Decisions To Record

Add a short implementation note in the executing session or commit message with:

- the actual runtime DB env helper file,
- the actual backend router file for admin social endpoints,
- the exact social proxy helper prefix behavior,
- whether `screenalytics` is a nested git repo,
- whether the app landing route currently has tests for in-flight dedupe and stale-on-error behavior,
- the endpoint inventory matrix for freshness, gap, catalog, photo, dashboard, summary, and progress reads.

Do not proceed to Phase 6, Phase 7, or Phase 9 until these names and endpoint classes are concrete.

## Phase 3: Local Dev Safety

Objective: make default local dev safe without hiding query or fan-out problems.

### Workspace Holder Budget

Target default budget for `PROFILE=default make dev`:

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
WORKSPACE_SCREENALYTICS_DB_ENABLED=0
```

Expected holder budget:

```text
app=1, backend=2, social_profile=4, social_control=2, health=1, total=10
```

### Workspace Files

- `/Users/thomashulihan/Projects/TRR/profiles/default.env`
- `/Users/thomashulihan/Projects/TRR/profiles/local-cloud.env`
- `/Users/thomashulihan/Projects/TRR/profiles/social-debug.env`
- `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- `/Users/thomashulihan/Projects/TRR/scripts/workspace-env-contract.sh`
- `/Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh`
- `/Users/thomashulihan/Projects/TRR/scripts/test_workspace_app_env_projection.py`
- generated `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`

### Workspace Actions

1. Update default and local-cloud profiles with app pool `1`, app operation concurrency `1`, backend general max `2`, remote social workers disabled, and Screenalytics DB disabled.
2. Keep named social pools unchanged unless Phase 0 evidence shows they are the saturation driver.
3. Update workspace budget fallback logic to match the target budget.
4. Add `WORKSPACE_SUPAVISOR_SESSION_POOL_SIZE`, default `15`.
5. Add `WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1` support:
   - interactive `make dev`: warn when holder budget exceeds `pool_size - 5`,
   - CI and contract checks: fail when holder budget exceeds `pool_size - 5`.
6. Regenerate env docs through the existing generator.

### App Pool Actions

Files:

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/postgres.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/POSTGRES_SETUP.md`

Target defaults:

```text
Development session pooler: poolMax=1, maxConcurrentOperations=1
Production session pooler: poolMax=2, maxConcurrentOperations=1
Preview session pooler: poolMax=1, maxConcurrentOperations=1 unless overridden
Direct/local Postgres development: unchanged
```

Also confirm and set, where supported by the installed `pg` version:

```text
idleTimeoutMillis
connectionTimeoutMillis
maxLifetimeSeconds
```

If `maxLifetimeSeconds` is not supported by the installed `pg` version, document that in `POSTGRES_SETUP.md` and keep the validation focused on idle and connection timeout behavior.

### Backend Pool Tradeoff

The backend named pools currently use `minconn=1`. That means backend startup can hold at least one session per named pool even when idle. Keep this as an intentional initial tradeoff for predictable readiness unless current code supports safe lazy initialization or `minconn=0` with tests.

Do not switch backend named pools to `minconn=0` without:

- tests for first-use lazy initialization,
- tests for health pool behavior,
- evidence that startup no longer holds idle sessions,
- manual validation under one normal admin route and one social admin route.

### Screenalytics Actions

Files:

- `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/main.py`
- `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/services/runtime_startup.py`

Rules:

- `WORKSPACE_SCREENALYTICS_DB_ENABLED=0` maps to `SCREENALYTICS_DB_ENABLED=0`.
- When disabled, do not load `.env` keys for `TRR_DB_URL` or `TRR_DB_FALLBACK_URL`.
- Preserve explicitly exported environment variables; do not delete a value the operator set before process startup.
- Keep explicit opt-in:

  ```bash
  WORKSPACE_SCREENALYTICS_DB_ENABLED=1 make dev
  ```

### Validation

```bash
cd /Users/thomashulihan/Projects/TRR
WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 python3 -m pytest -q scripts/test_workspace_app_env_projection.py
WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 bash scripts/check-workspace-contract.sh
make env-contract

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
pnpm exec tsc --noEmit

cd /Users/thomashulihan/Projects/TRR/screenalytics
python -m pytest -q tests/api/test_runtime_startup*.py
```

Manual:

```bash
cd /Users/thomashulihan/Projects/TRR
make stop
make dev
```

Expected ready summary:

```text
Local DB holders: app=1, backend=2, social_profile=4, social_control=2, health=1, total=10
```

Before committing this phase, hit one normal admin backend route and one social admin route after restart. If the default backend pool max `2` produces new `PoolError` under normal admin use, keep app pool `1` but raise only the backend general pool to the lowest value that passes, then update the budget and docs.

## Phase 4: Observability And Protected Pressure Diagnostics

Objective: make local process pressure, app pressure, and global Supavisor holders diagnosable without leaking topology publicly.

### Required `application_name` Values

Every DB pool must set `application_name` in the DSN or connection options.

Use stable values:

```text
trr-app:web
trr-backend:default
trr-backend:social_profile
trr-backend:social_control
trr-backend:health
screenalytics:api
trr-script:<script-name>
```

Tests must verify `application_name` is present and does not contain secrets.

### Backend Pressure Endpoints

Files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/pg.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py` or the current health/admin router if discovery finds one
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_pg_pool.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/test_health.py`

Public endpoint:

```text
GET /health/db-pressure
```

Unauthenticated response must be status-only:

```json
{
  "status": "ok|degraded",
  "reason": "ok|pool_near_capacity|pool_exhausted|pool_uninitialized"
}
```

Detailed endpoint:

```text
GET /admin/health/db-pressure
```

This endpoint must require internal/admin authorization. It may return local-process pool details:

```json
{
  "status": "ok|degraded",
  "scope": "local_process_pool",
  "reason": "ok|pool_near_capacity|pool_exhausted|pool_uninitialized",
  "pools": {}
}
```

If the repo already has a different internal admin health route, use that route and update this contract table before editing. Do not expose pool names, configured maxima, DSN source labels, or topology on unauthenticated health.

Keep `/health/live` DB-free.

### App Pressure Diagnostics

Files:

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/postgres.ts`
- app admin health route under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/health/` or the discovered equivalent
- focused app tests

Add mandatory structured app pressure logging:

```text
route_name
pool_max
pool_total_count
pool_idle_count
pool_waiting_count
active_permit_count
queued_operation_count
application_name
```

Add an admin-only local debugging endpoint:

```text
GET /api/admin/health/app-db-pressure
```

It must require existing admin auth and must not expose DSNs or secrets.

### Supavisor Holder Snapshot Script Or Runbook

Add a script or runbook section that captures the Phase 0 `pg_stat_activity` query. The output should be grouped by:

```text
application_name
usename
client_addr
state
```

This is the source of truth for global holder attribution. Backend and app pressure endpoints are process-local diagnostics only.

### Validation

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m ruff check trr_backend/db/pg.py api/main.py tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m ruff format --check trr_backend/db/pg.py api/main.py tests/db/test_pg_pool.py tests/api/test_health.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts tests/*health*.test.ts
pnpm exec tsc --noEmit
```

Manual:

```bash
curl -sS http://127.0.0.1:8000/health/live
curl -sS http://127.0.0.1:8000/health/db-pressure
curl -sS http://127.0.0.1:8000/admin/health/db-pressure
curl -sS http://127.0.0.1:3000/api/admin/health/app-db-pressure
```

Expected:

- liveness stays DB-light,
- unauthenticated backend pressure response is status-only,
- detailed backend/app pressure requires auth,
- no DSN or password appears in responses or logs,
- `pg_stat_activity` groups connections by useful `application_name` values.

## Phase 5: Social Landing App Hardening

Objective: make the current route measurable and safe before moving direct SQL into backend APIs.

### Files

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/social/landing/route.ts`
- focused tests under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/`

### Timing Buckets

Add low-volume timing logs for real landing fan-out:

```text
auth_ms
cache_ms
covered_shows_ms
show_external_ids_ms
cast_summary_ms
person_external_ids_ms
effective_social_handles_ms
socialblade_rows_ms
shared_sources_ms
shared_runs_ms
shared_review_items_ms
reddit_summary_ms
total_ms
stale_payload_used
```

Gate these logs with `TRR_ADMIN_SOCIAL_ROUTE_TIMINGS_ENABLED`.

### Stale And Partial Payload Contract

Define an admin data envelope for routes that can return stale or partial data:

```ts
type AdminDataEnvelope<T> = {
  data: T;
  freshness: {
    status: "fresh" | "stale" | "partial" | "missing";
    generated_at: string | null;
    age_ms: number | null;
    source: "live" | "route_cache" | "backend_cache" | "materialized";
  };
  omitted_sections?: Array<{
    section: string;
    reason: string;
    retryable: boolean;
  }>;
};
```

Rules for social landing:

- Covered shows failure: do not silently zero. Return stale if available; otherwise return `503`.
- Reddit summary failure: zero counts only when `omitted_sections` includes `reddit_dashboard`.
- Shared source failure: return stale or degraded data; do not silently hide the failure.
- Stale-on-error behavior must be gated with `TRR_ADMIN_SOCIAL_STALE_ON_ERROR_ENABLED`.

### Actions

1. Ensure existing route cache and in-flight dedupe wrap all direct and backend work.
2. Add stale last-good payload storage separate from live error payloads.
3. Do not cache a failed live response as fresh.
4. Update tests so concurrent GETs share one in-flight payload.
5. Update tests so optional reddit failure is explicitly marked partial, not silently correct-looking.

### Validation

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-landing*.test.ts tests/postgres-connection-string-resolution.test.ts
pnpm exec tsc --noEmit
```

Expected: concurrent GETs share one in-flight payload, optional reddit SQL failure is marked partial, covered shows failure is stale-or-503, and response fields remain compatible with the UI.

## Phase 6: Move First Slice Of Social Landing Direct SQL Into TRR-Backend

Objective: move covered shows and Reddit summary reads into the backend while keeping the contract narrow.

### Backend Route Contract

Use the existing social proxy pattern:

| Consumer call | Final backend URL | Owner |
| --- | --- | --- |
| `fetchSocialBackendJson("/landing-summary", ...)` | `${TRR_BACKEND_BASE_URL}/admin/socials/landing-summary` | `TRR-Backend` |

This task's backend route is exactly `GET /admin/socials/landing-summary`. If Phase 2 discovery proves the existing social proxy pattern cannot resolve that path, stop and update this contract table before implementation.

Backend endpoint:

```text
GET /admin/socials/landing-summary
```

Initial response:

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

### Backend Actions

1. Implement the endpoint in the discovered admin-social router.
2. Use backend DB helpers and existing repository patterns.
3. Use the default pool for generic show reads unless current code evidence proves `social_control` is the correct pool.
4. Set `application_name` for the pool that serves this route.
5. Add a short in-process cache, default `TRR_ADMIN_SOCIAL_LANDING_SUMMARY_CACHE_TTL_MS=30000`.
6. Return `503` with `reason=session_pool_capacity` for local pool exhaustion.
7. Add backend tests for auth, response shape, cache hit behavior, and saturation failure shape.

### App Actions

1. Replace landing route direct calls to `getCoveredShows()` and `listRedditCommunities()` with `fetchSocialBackendJson("/landing-summary", ...)`.
2. Preserve the stale/partial payload contract from Phase 5.
3. Gate consumer use with `TRR_ADMIN_SOCIAL_LANDING_BACKEND_SUMMARY_ENABLED`.
4. Add tests proving the app route no longer invokes those direct SQL repositories for covered shows or Reddit summary.
5. Update `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` with producer, consumer, final backend URL, payload, and verification commands.

### Validation

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api/routers/test_admin_social_landing.py
.venv/bin/python -m ruff check api trr_backend tests/api/routers/test_admin_social_landing.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-landing*.test.ts
pnpm exec tsc --noEmit
```

Auth-valid manual route check:

```bash
cd /Users/thomashulihan/Projects/TRR
curl -sS -o /tmp/trr-social-landing.json -w '%{http_code} %{time_total}\n' \
  http://127.0.0.1:3000/api/admin/social/landing
```

Expected: route returns `200` with admin auth, app logs show fewer app direct SQL acquisitions, and backend owns the covered-shows/Reddit summary contract.

## Phase 7: Task 5B, Remove Remaining Social Landing Direct SQL From TRR-APP

Objective: finish the landing-route DB ownership shift by moving SocialBlade/cast social landing reads out of `TRR-APP`.

### Files

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/` discovered social/admin router
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/` discovered repository/service layer
- focused backend and app tests
- `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md`

### Actions

1. Move `safeLoadCastSocialBladeRows()` behavior behind a backend endpoint or extend the narrow landing summary endpoint only if that keeps the payload coherent.
2. Move reads from `pipeline.socialblade_growth_data` into backend-owned repository/service code.
3. Preserve the same stale/partial payload semantics.
4. Remove app import of `@/lib/server/postgres` from `social-landing-repository.ts`.
5. Add a test that the initial social landing payload no longer opens an app-side DB connection.
6. Add a static or unit test that `social-landing-repository.ts` no longer imports `@/lib/server/postgres`.

### Acceptance Criteria

```text
apps/web/src/lib/server/admin/social-landing-repository.ts no longer imports "@/lib/server/postgres".
```

The social landing initial payload should use backend APIs for database-backed covered shows, Reddit summary, SocialBlade, and cast social reads.

## Phase 8: Name Runtime DB Lanes

Objective: add explicit env names without changing traffic to unsupported lanes.

### New Names

```text
TRR_DB_SESSION_URL
TRR_DB_TRANSACTION_URL
TRR_DB_DIRECT_URL
```

### Resolution Rules

1. `TRR_DB_SESSION_URL` is the normal long-lived runtime lane.
2. `TRR_DB_DIRECT_URL` is only for migrations, observer scripts, direct admin probes, and rollout tooling.
3. `TRR_DB_TRANSACTION_URL` is configured but not selected for app/backend runtime until prepared-statement compatibility is proven.
4. `TRR_DB_URL` remains a backwards-compatible alias for `TRR_DB_SESSION_URL`.
5. `TRR_DB_FALLBACK_URL` remains an operator-engaged fallback.

### Files

Use Phase 2 discovery to identify the actual runtime DB helper file. Expected areas:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/connection.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_connection_resolution.py`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/postgres.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- workspace runtime DB helper under `/Users/thomashulihan/Projects/TRR/scripts/`
- generated env docs

### Actions

1. Add resolver support for new names while preserving `TRR_DB_URL`.
2. Warn when only legacy `TRR_DB_URL` is present.
3. Reject deployed app runtime if it selects a direct URL.
4. Classify transaction URLs but do not route unsupported code paths to them.
5. Ensure `application_name` is applied regardless of whether the selected source is new lane env or legacy alias.
6. Add tests for source priority, direct URL rejection in app runtime, transaction URL classification, application-name injection, no secret leakage, and legacy compatibility.

### Validation

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_connection_resolution.py tests/db/test_pg_pool.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts
pnpm exec tsc --noEmit
```

## Phase 9: Endpoint Caching, Polling Throttles, And Page Simplification

Objective: reduce duplicate admin polling and read load after endpoint inventory and landing-route ownership are stable.

Do not start this phase until the Phase 2 endpoint inventory matrix exists.

### Classification

```text
safe_ttl_30s: read-only operational summaries
safe_ttl_5s: progress/freshness endpoints where UI polls
no_cache: mutations, launch/finalize endpoints, auth-sensitive data
```

### Cache Rules

1. Implement only `safe_ttl_30s` and `safe_ttl_5s`.
2. Use existing app route-response cache and in-flight dedupe where possible.
3. Add backend cache only where app cache cannot prevent load from multiple clients or processes.
4. Add invalidation on mutations that change social account source, run, photo, or catalog state.
5. Never cache `500` or `503` backend saturation responses as successful payloads.
6. Cache last-good data separately from live error payloads and mark it stale or partial.
7. For progress endpoints:
   - cache active progress for 2 to 5 seconds,
   - cache terminal state longer,
   - never stale-lock an active run as terminal.

### Frontend Polling Rules

Add tests and refactor only as much as needed to enforce:

- one active poller per profile/run,
- no polling while the tab is hidden,
- no diagnostics polling until the diagnostics panel is open,
- exponential backoff on `429`, `503`, and `504`,
- stop polling after terminal states,
- cancel in-flight requests on route or tab change.

If the current `SocialAccountProfilePage` keeps this logic inline, extract the polling behavior into tab-specific hooks with tests rather than expanding the giant page component.

### Validation

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/*cache*.test.ts tests/social-*.test.ts tests/*poll*.test.ts

cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api/routers tests/repositories -k "cache or freshness or gap or catalog or photo"
```

Expected:

- repeated read requests hit cache/in-flight dedupe,
- mutations invalidate affected caches,
- saturation responses are not cached as fresh,
- polling stops or backs off under hidden, terminal, and overloaded conditions.

## Release Validation

Run targeted checks first. Run broad sweeps only after targeted checks pass.

### Workspace

```bash
cd /Users/thomashulihan/Projects/TRR
WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 python3 -m pytest -q scripts/test_workspace_app_env_projection.py scripts/test_preflight_env_contract_policy.py scripts/test_runtime_db_env.py
WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 bash scripts/check-workspace-contract.sh
make env-contract
```

### Backend

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_connection_resolution.py tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m pytest -q tests/api/routers/test_admin_social_landing.py
.venv/bin/python -m ruff check api trr_backend tests
```

### App

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts tests/social-landing*.test.ts tests/*cache*.test.ts tests/*poll*.test.ts
pnpm exec tsc --noEmit
```

### Screenalytics

```bash
cd /Users/thomashulihan/Projects/TRR/screenalytics
python -m pytest -q tests/api/test_runtime_startup*.py
```

### Manual End-to-End

Use an auth-valid admin request. If raw curl returns `401` or `403`, validate through browser-authenticated request or pass the required local admin cookie/header.

```bash
cd /Users/thomashulihan/Projects/TRR
make stop
make dev
curl -sS -o /tmp/trr-social-landing.json -w '%{http_code} %{time_total}\n' \
  http://127.0.0.1:3000/api/admin/social/landing
curl -sS http://127.0.0.1:8000/health/live
curl -sS http://127.0.0.1:8000/health/db-pressure
curl -sS http://127.0.0.1:8000/admin/health/db-pressure
curl -sS http://127.0.0.1:3000/api/admin/health/app-db-pressure
rg -n "postgres_pool_init|postgres_pool_queue_depth|EMAXCONNSESSION|MaxClientsInSessionMode" \
  /Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log
```

Expected:

- social landing returns `200` with admin auth,
- no fresh `EMAXCONNSESSION` after restart,
- ready summary shows holder budget around 10,
- app pool init shows local `pool_max=1`,
- `/health/live` remains OK and DB-light,
- public `/health/db-pressure` is status-only,
- detailed pressure endpoints require auth,
- `pg_stat_activity` reports useful `application_name` values,
- `social-landing-repository.ts` no longer imports `@/lib/server/postgres` after Phase 7,
- Screenalytics DB startup is disabled by default.

## Production Rollout Gate

Do not deploy production-facing pool/default changes until Phase 1 passes.

Required release note:

- current Supavisor pool size,
- current Postgres `max_connections`,
- worst-case session demand,
- expected-case session demand,
- app instance/concurrency caps,
- backend replica/worker caps,
- Screenalytics DB enabled/disabled state,
- scripts/workers that can use `TRR_DB_SESSION_URL`,
- internal-service headroom review,
- rollback owner and rollback time.

## Rollback

| Change | Rollback |
| --- | --- |
| Local app pool cap | `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=4 WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=4 make dev` |
| Backend general pool cap | `TRR_DB_POOL_MAXCONN=4 make dev` |
| Remote social workers disabled | `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 make dev` |
| Screenalytics DB disabled | `WORKSPACE_SCREENALYTICS_DB_ENABLED=1 make dev` |
| Supavisor pool increase | Restore previous pool size in Supabase settings at recorded rollback time. |
| Backend landing summary consumer | `TRR_ADMIN_SOCIAL_LANDING_BACKEND_SUMMARY_ENABLED=0` while reverting app consumer later. |
| Stale-on-error behavior | `TRR_ADMIN_SOCIAL_STALE_ON_ERROR_ENABLED=0` while preserving normal live responses. |
| Route timing logs | `TRR_ADMIN_SOCIAL_ROUTE_TIMINGS_ENABLED=0`. |
| Strict app pool cap | `TRR_APP_DB_POOL_CAP_STRICT=0` only during incident rollback. |
| Detailed pressure exposure | Keep `TRR_EXPOSE_DB_PRESSURE_HEALTH=0` unless using local-only diagnostics. |
| New DB lane names | Keep `TRR_DB_URL` as selected alias and revert only new-name resolver changes. |

## Success Metrics

- Local default holder budget is at least five slots below Supavisor session pool size 15.
- Production capacity budget has worst-case and expected-case session math before rollout.
- `pg_stat_activity` groups active holders by useful `application_name` values.
- `/api/admin/social/landing` returns `200` after restart without fresh max-client errors.
- App logs show pool count keys, route names where available, and local `pool_max=1`.
- Public health pressure output does not expose topology; detailed pressure requires auth.
- App landing no longer performs direct SQL reads for covered shows, Reddit summary, SocialBlade, or cast social data after Phase 7.
- `apps/web/src/lib/server/admin/social-landing-repository.ts` no longer imports `@/lib/server/postgres` after Phase 7.
- Cache and stale data paths never mark 500/503 saturation responses as fresh.
- Screenalytics does not load production Supabase DB values by default in workspace dev.

## Execution Handoff

Saved path:

```text
/Users/thomashulihan/Projects/TRR/.plan-grader/supavisor-session-pool-stabilization-20260426-095557/REVISED_PLAN.md
```

Recommended execution: **subagent-driven**, because this plan spans disjoint ownership surfaces and has parallelizable discovery, workspace, app, backend, Screenalytics, and cache/polling work.

Required execution skill: `superpowers:subagent-driven-development`.

Execution constraint: use the current checkout only. Do not create or switch branches. Do not create additional git worktrees. The main session must orchestrate workers, assign disjoint write sets, integrate changes serially, and run cross-surface validation after each integration checkpoint.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
