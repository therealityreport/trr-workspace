# TRR Whole-App Supabase Setup And Connection Capacity Hardening Plan

Date: 2026-04-27
Status: ready for approval
Recommended executor after approval: `orchestrate-plan-execution`

## summary

Stabilize the entire TRR Supabase setup without jumping straight to a paid Supabase compute upgrade. This is not a Twitter-only or social-page-only fix. The plan covers every Supabase-facing surface: Postgres runtime connections, Supavisor session/transaction lanes, app direct SQL, backend pools, workers, Vercel/serverless behavior, Supabase admin/service-role clients, Auth/JWT validation, Storage/API envs, migrations/tooling, RLS/grants review, high-fanout admin routes, live-status polling load, slow query amplification, and brittle page-level error boundaries.

The target outcome is that TRR has one coherent Supabase runtime contract across local dev and production: normal `make dev` admin browsing stays below the observed local Supavisor `pool_size: 15`, production keeps serverless/direct-SQL connection growth bounded, Supabase secrets are clearly owned and server-only, and operator pages degrade with partial/stale data rather than blanking when one backend/Supabase dependency is slow.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-27-supabase-connection-capacity-hardening-plan.md`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Repos/surfaces:
  - `TRR-Backend` owns DB schema, runtime DB helpers, `/api/v1`, backend pool sizing, Supabase JWT validation, migrations/tooling, social/admin aggregation contracts, and backend-owned read/write APIs.
  - `TRR-APP` owns admin UI, app API compatibility routes, Vercel/runtime direct-SQL callers, Supabase admin/service-role client usage, admin snapshot cache, route fallbacks, and browser-safe public env boundaries.
  - Workspace scripts/profiles own `make dev`, local profile projection, env contract validation, Vercel/Supabase inventory, and operator diagnostics.
  - Modal/remote workers and any local worker profile share the same Supabase project capacity unless explicitly routed to a separate project or pool budget.
- Current documented local holder budget in `docs/workspace/supabase-capacity-budget.md` is app `1`, backend default `2`, social profile `4`, social control `2`, health `1`, screenalytics `0`, for projected local holder budget `10`.
- Current known drift risk: local ignored env files can still override safer checked-in profile values, for example `TRR-Backend/.env` can carry unsafe `TRR_DB_POOL_MAXCONN=16` while profiles document `2`.
- Current whole-app Supabase contract is split across `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, Vercel integration-managed `POSTGRES_*` / `SUPABASE_*` values, local Supabase emulator keys, and tooling-only legacy names. The plan must reconcile these as one setup, not tune one route.
- Supabase official docs confirm:
  - Session pooler uses port `5432`; transaction pooler uses port `6543`.
  - Transaction mode is intended for transient/serverless-style connections and does not support prepared statements.
  - Supavisor pool size should be budgeted against total database connections and Supabase internal services, not treated as free unlimited application capacity.
- Recent local evidence:
  - `/admin/social` surfaced `TRR-Backend request timed out`.
  - App logs showed `/api/admin/social/landing` timeout and nearby `EMAXCONNSESSION max clients reached in session mode - max clients are limited to pool_size: 15`.
  - A narrow fallback patch was already added for the authenticated social landing summary timeout path, but the underlying whole-app Supabase setup and capacity pattern remain.
- Additional 2026-04-27 audit evidence accepted into this plan:
  - `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts:186-252` executes runtime DDL/index creation during request-time code paths. This is a high-priority anti-pattern and must be moved to backend-owned migrations.
  - `docs/workspace/app-direct-sql-inventory.md` currently reports `108` app direct-SQL call sites, `14` high-fanout production-risk call sites, and `22` call sites needing owner labels.
  - `TRR-Backend/supabase/config.toml` exposes `public`, `graphql_public`, `core`, and `admin` locally through PostgREST; this requires explicit keep/remove decision plus RLS/grants evidence.
  - `TRR-APP/apps/web/.env.local` and `TRR-Backend/.env` contain legacy alias drift and local pool/name drift that can invalidate holder-budget math.
  - Production/Vercel still retains integration-managed legacy env shapes that runtime ignores; these must be stripped or explicitly reclassified to reduce blast radius.
  - Supabase advisor access was permission-blocked, so security/performance advisor evidence is not yet captured.

## assumptions

1. Cost should stay low: no Supabase compute upgrade unless evidence shows the effective workload genuinely exceeds a right-sized low-cost pool strategy.
2. Normal local development should prioritize admin browsing stability over maximum worker/backfill throughput.
3. Long-running migrations, backups, `pg_dump`, advisory-lock operations, and any session-state-dependent task may continue using direct or session-mode connections.
4. Read-only, single-statement, schema-qualified app/backend reads are candidates for transaction-mode testing, but each caller must be verified for prepared statements, session state, temp tables, advisory locks, `LISTEN/NOTIFY`, or session-level `SET`.
5. Backend-first sequencing applies for new aggregate endpoints and read-model contracts.
6. Production Vercel changes must be guarded by project identity checks and should not mutate env without a dry-run/review artifact.
7. Supabase service-role/admin clients are server-only; browser/public envs must remain separate from admin/runtime secrets.

## goals

1. Keep normal local holder demand under the observed session-pool headroom target.
2. Produce a whole-app Supabase ownership matrix: DB, Auth/JWT, Storage/API, service-role clients, public clients, migrations/tooling, workers, Vercel integration values.
3. Fail or warn early when ignored local env files override safe profile limits.
4. Move compatible read traffic off pinned session-mode connections where safe.
5. Replace the worst frontend/admin fanout paths across the app with backend-owned aggregate endpoints and short TTL/stale caches.
6. Make live status and polling surfaces cheap enough that observing the system does not materially load Supabase.
7. Separate normal local browsing from heavy worker/backfill capacity.
8. Use query-plan evidence to shorten hot-path DB hold time across social, reddit, survey, brand/media, and admin repository paths.
9. Add stale/partial fallbacks to remaining high-value admin routes.
10. Keep production serverless connection multiplication bounded and observable.

## non_goals

- No immediate Supabase compute upgrade.
- No broad schema redesign or materialized read model until query-plan evidence proves it is necessary.
- No destructive migration or data reset.
- No removal of session-mode/direct connection support for migrations, maintenance, or session-dependent tasks.
- No silent Vercel production env mutation.
- No route-specific tunnel vision: Twitter/social-profile fixes are only one subset of the whole Supabase setup.

## additional_audit_review

Verdict: accept the audit as a high-quality delta against the existing plan, with one framing correction. The audit is not just about "connections"; it identifies whole-app boundary drift. The plan must therefore prioritize schema/migration discipline and env ownership before more pool tuning.

Accepted high-priority changes:

- E1/I4: remove app runtime DDL from `shows-repository.ts` and migrate it through backend-owned schema migrations.
- E2/E3/E4/E5: enforce local env contract in ignored env files, especially legacy aliases, pool max/concurrent ops, and `application_name`.
- E8/I1/I2/S1: capture RLS/grants, Supabase advisors, and production capacity evidence before claiming best-practice compliance.
- I3/I5/I7: migrate high-fanout app direct-SQL call sites to backend APIs and backfill ownership/ledger docs.
- I6/S7: consolidate app/backend migration ownership and fix duplicate/ambiguous migration naming.
- E6/E7: prevent accidental Vercel env mutation in the nested stale project and reduce retained unused production env blast radius.
- I8-I12/S5: decide local PostgREST schema exposure and verify production auth/storage/SMTP/config posture against dev config.
- S3/S4/S6: improve observability through live holder snapshots, per-route application names, and a controlled transaction-mode flight test.

## audit_traceability

| Audit item | Priority | Plan location |
|---|---:|---|
| E1, I4 runtime DDL in `shows-repository.ts` | High | Phase 1 and Phase 8B |
| E2, E3, E4 app local env drift | High | Phase 1 |
| E5 backend legacy alias drift | Medium | Phase 1 |
| E6 nested stale Vercel project | Medium | Phase 9 |
| E7 retained production legacy envs | Medium | Phase 9 |
| E8 Supabase advisors blocked | Medium | Phase 0 and Phase 10 |
| I1 RLS/grants snapshot | High | Phase 0 and Phase 2 |
| I2 production capacity table | High | Phase 0 and Phase 10 |
| I3 14 high-fanout app direct-SQL sites | High | Phase 5 |
| I5 22 unowned direct-SQL labels | Medium | Phase 2 and Phase 5 |
| I6 app migration ownership consolidation | Medium | Phase 8B |
| I7 API migration ledger backfill | Medium | Phase 5 and Phase 8B |
| I8 local PostgREST `admin`/`core` exposure | Medium | Phase 2 |
| I9 generated Supabase TypeScript types | Medium | Phase 2 |
| I10 production auth policy check | Low | Phase 9 |
| I11 storage bucket policy check | Low | Phase 9 |
| I12 production SMTP check | Low | Phase 9 |
| S1 reproducible RLS snapshot make target | Medium | Phase 0 |
| S2 CI hard-fail holder budget | Medium | Phase 1 |
| S3 live `pg_stat_activity` in health | Medium | Phase 6 |
| S4 per-route `application_name` suffixes | Low | Phase 5 and Phase 7 |
| S5 Supabase config drift test | Low | Phase 2 and Phase 9 |
| S6 transaction-mode flight test | Low | Phase 3 |
| S7 duplicate migration prefix cleanup | Low | Phase 8B |

## phased_implementation

### Priority Waves

Wave A - Stop the bleeding this week:

- Fix local env drift: remove legacy runtime aliases from local app/backend envs, enforce app pool `1/1`, and normalize `POSTGRES_APPLICATION_NAME=trr-app:web`.
- Quarantine request-time DDL in `shows-repository.ts` by moving schema changes to backend migrations and adding a DDL blocker test.
- Capture RLS/grants, Supabase advisor status, and `pg_stat_activity` holder snapshot; fill the production capacity table as live evidence or explicit blocked rows.

Wave B - Reduce serverless DB pressure next sprint:

- Move the `14` high-fanout app direct-SQL call sites to backend APIs in risk order: reddit sources, social posts, reddit discovery cache, cast photo tags.
- Backfill `api-migration-ledger.md` for every route migration.
- Resolve nested Vercel project risk and production retained-env blast radius.

Wave C - Consolidate ownership this milestone:

- Classify the `22` unowned app direct-SQL call sites.
- Port shared-schema app migrations into backend migrations and quarantine app copies.
- Decide local PostgREST `admin`/`core` exposure and document RLS/grants.

Wave D - Production posture before the next traffic spike:

- Complete capacity decision evidence before any Supavisor pool-size change.
- Verify production Auth, Storage, SMTP, and Supabase config drift against documented production posture.
- Run a transaction-mode flight test for one eligible route before any broad `:6543` migration.

Wave E - Continuous:

- CI hard-fails env/holder/migration drift.
- Protected DB pressure includes current holder snapshots.
- Highest-fanout backend endpoints use route-identifying `application_name` suffixes where useful.

### Phase 0 - Whole-App Supabase Baseline And Evidence Capture

Concrete changes:

- Add or update a repeatable baseline script/report that records:
  - effective local profile values
  - ignored local env overrides
  - current `WORKSPACE_SUPAVISOR_SESSION_POOL_SIZE`
  - app/backend pool caps
  - active local PIDs
  - recent `EMAXCONNSESSION`, `UPSTREAM_TIMEOUT`, `DATABASE_SERVICE_UNAVAILABLE`, and `postgres_pool_queue_depth` log events
- Add a whole-app Supabase surface inventory that records every runtime/tooling use of:
  - `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, proposed `TRR_DB_SESSION_URL`, proposed `TRR_DB_TRANSACTION_URL`
  - `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
  - `NEXT_PUBLIC_SUPABASE_*`
  - `SUPABASE_JWT_SECRET`
  - Vercel integration-managed `POSTGRES_*` and `SUPABASE_*`
  - tooling-only `DATABASE_URL` / `SUPABASE_DB_URL`
- Add a DB-side SQL inventory script for `pg_stat_activity` grouped by `application_name`, role, state, and client address.
- Add a Supabase API/Auth/Storage inventory section that classifies each use as browser public, server admin, backend auth validation, migration/tooling, or dead/legacy.
- Add a reproducible RLS/grants snapshot command, preferably `make supabase:rls-snapshot`, wrapping `TRR-Backend/scripts/db/rls_grants_inventory.sql` and writing redacted output to `docs/workspace/supabase-rls-grants-review.md`.
- Add a Supabase advisor capture target/runbook for security and performance advisors. If MCP remains permission-blocked, record the blocker, owner, and manual Dashboard fallback path under a dated `docs/workspace/supabase-advisor-snapshot-YYYY-MM-DD.md`.
- Fill the production capacity table skeleton with either live values or explicit `blocked/pending` rows for:
  - `SHOW max_connections`
  - Supavisor pool size
  - Vercel app instance/concurrency assumptions
  - backend replica/worker count
  - Modal/remote worker concurrency
  - Supabase internal/service connection baseline
- Store the baseline template under `docs/workspace/supabase-capacity-budget.md` or a sibling runtime snapshot doc, with redacted values only.

Affected files/surfaces:

- `docs/workspace/supabase-capacity-budget.md`
- `scripts/status-workspace.sh`
- `scripts/dev-workspace.sh`
- `scripts/redact-env-inventory.py`
- `scripts/env_contract_report.py`
- `TRR-Backend/scripts/db/`
- `docs/workspace/production-supabase-connection-inventory.md`
- `docs/workspace/vercel-env-review.md`
- `docs/workspace/supabase-rls-grants-review.md`
- optional `docs/workspace/supabase-advisor-snapshot-YYYY-MM-DD.md`
- `Makefile`

Validation:

- `python3 scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md --check`
- `bash scripts/status-workspace.sh --json`
- `make supabase:rls-snapshot` or equivalent script target.
- Run the `pg_stat_activity` query from `docs/workspace/supabase-capacity-budget.md` against the local/dev Supabase target.

Acceptance criteria:

- A coding agent can see the current local holder budget, actual active DB holders, Supabase API/Auth/Storage env ownership, and every production/local Supabase runtime source before changing pool values or envs.
- RLS/grants and advisor gaps are evidence-backed, not placeholders.
- No secret DB URLs or credentials are written to docs.

Commit boundary:

- One workspace commit for diagnostics/reporting only.

### Phase 1 - Stop-The-Bleeding Drift Guardrails

Problems fixed:

- Local `.env` can override safe profile limits.
- App runtime code currently performs DDL/index creation in a request-time repository.
- CI/predeploy can still let holder-budget drift remain a warning rather than a hard fail.

Concrete changes:

- Extend `scripts/dev-workspace.sh` to compare resolved local runtime values against checked-in profile limits before starting backend/app.
- Add strict mode that fails when session-mode local values exceed:
  - `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1`
  - `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1`
  - `TRR_DB_POOL_MAXCONN=2`
  - `TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4`
  - `TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2`
  - `TRR_HEALTH_DB_POOL_MAXCONN=1`
- Keep non-strict mode as warning by default if needed, but make `WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1` fail.
- Make the warning name the exact source file/key that caused drift, for example `TRR-Backend/.env:TRR_DB_POOL_MAXCONN=16`.
- Add explicit local-env contract checks for:
  - no runtime `DATABASE_URL` in `TRR-APP/apps/web/.env.local`
  - no runtime `SUPABASE_DB_URL` in `TRR-APP/apps/web/.env.local`
  - `POSTGRES_POOL_MAX=1` for normal local profile
  - `POSTGRES_MAX_CONCURRENT_OPERATIONS=1` for normal local profile
  - `POSTGRES_APPLICATION_NAME=trr-app:web`
  - no backend runtime reliance on `SUPABASE_DB_URL`
- Move `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts:186-252` DDL into backend-owned migration files:
  - `survey_shows.trr_show_id`
  - `survey_shows.fonts`
  - `idx_survey_shows_trr_show_id_unique`
  - `idx_survey_shows_trr_show_id`
  - `set_updated_at_timestamp()`
  - `survey_show_palette_library`
  - `idx_survey_show_palette_library_name_scope`
  - `idx_survey_show_palette_library_show`
  - `idx_survey_show_palette_library_show_season`
  - `trg_survey_show_palette_library_updated_at`
- Replace runtime DDL helper calls with either:
  - no-op assumptions after migration parity is proven, or
  - a read-only startup/preflight assertion that the required columns/tables/indexes exist.
- Add a test/static check that app request-time code cannot execute DDL (`ALTER TABLE`, `CREATE TABLE`, `CREATE INDEX`, `CREATE OR REPLACE FUNCTION`, `CREATE TRIGGER`) through app repositories.
- Add CI/predeploy command guidance: `WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 make preflight`.
- Update tests and env docs so profile/default/env-contract/checker agree.

Affected files/surfaces:

- `scripts/dev-workspace.sh`
- `scripts/check-workspace-contract.sh`
- `scripts/test_workspace_app_env_projection.py`
- `docs/workspace/env-contract.md`
- `docs/workspace/supabase-capacity-budget.md`
- `profiles/default.env`
- `profiles/social-debug.env`
- `profiles/local-cloud.env`
- `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`
- `TRR-APP/apps/web/tests/**`
- `TRR-Backend/supabase/migrations/**`
- `docs/workspace/api-migration-ledger.md`

Dependencies:

- Phase 0 baseline should exist first so warnings can be audited.

Validation:

- `bash scripts/check-workspace-contract.sh`
- `python3 -m pytest scripts/test_workspace_app_env_projection.py`
- App static/unit test proving request-time DDL is blocked.
- Backend migration validation/dry-run for the moved DDL.
- Manual negative check: temporarily supply an unsafe value in a disposable env fixture and confirm strict mode fails with a clear message.

Expected result:

- Normal `make dev` cannot quietly start with local session-mode holder demand that consumes the whole observed pool.
- App request handlers stop doing schema mutation work.

Acceptance criteria:

- Unsafe ignored env overrides are surfaced before Next/Uvicorn start.
- Strict mode exits non-zero and prints exact offender keys.
- The DDL currently in `shows-repository.ts` is represented in backend migration provenance.
- App tests fail if new request-time DDL appears.

Commit boundary:

- Commit 1: env guardrails and CI/predeploy hard-fail wiring.
- Commit 2: runtime DDL migration and app request-time DDL blocker test.

### Phase 2 - Whole-App Supabase Ownership Contract

Problems fixed:

- The app setup has multiple Supabase env families and runtime clients without one enforced ownership map.
- Service-role/admin Supabase usage, browser-safe public usage, backend Auth/JWT validation, storage/API usage, and Postgres runtime access can be confused when viewed as only a connection-pool problem.

Concrete changes:

- Create a canonical Supabase ownership matrix with one row per env/client/surface:
  - owner repo
  - runtime context: browser, Next server, backend API, worker, migration/tooling, Vercel integration
  - privilege level: public anon, authenticated user, internal admin, service role, postgres role
  - allowed environments: local, preview, production
  - connection/API type: Postgres session, Postgres transaction, direct, Supabase REST/Auth/Storage, JWT validation only
  - expected retry/timeout/cache behavior
  - deprecation status
- Normalize docs around active env names:
  - Postgres runtime: `TRR_DB_*`
  - App server Supabase admin: `TRR_CORE_SUPABASE_*`
  - Backend auth validation: `SUPABASE_JWT_SECRET` and expected issuer/project-ref helpers
  - Public/browser values: only explicit `NEXT_PUBLIC_*` values if a browser feature truly requires them
  - Tooling-only compatibility: `DATABASE_URL` and `SUPABASE_DB_URL`
- Add or strengthen validation that service-role keys are never required by browser/client code and never appear in `NEXT_PUBLIC_*`.
- Add an inventory for Supabase Storage/API calls and bucket assumptions, even when Supabase MCP is permission-blocked.
- Decide local PostgREST schema exposure in `TRR-Backend/supabase/config.toml`:
  - option A: keep `admin` and `core` exposed locally, then document required RLS/grants and why local PostgREST needs them;
  - option B: remove `admin` from local exposed schemas and require backend-service connections for admin-only tables.
- Verify generated Supabase TypeScript types:
  - if a current `types/supabase.ts` or equivalent exists, document its source/date;
  - if missing or stale, add a generated type artifact or a clear script target for generating it;
  - use `createClient<Database>` in intentional Supabase client construction where applicable.
- Add a `supabase config drift` validation that compares `TRR-Backend/supabase/config.toml` dev-only settings against a production-known-good snapshot or documented production deviations.
- Update `docs/workspace/shared-env-manifest.json`, `docs/workspace/env-contract.md`, and `docs/workspace/env-deprecations.md` so the contract is readable without spelunking app/backend code.

Affected files/surfaces:

- `docs/workspace/shared-env-manifest.json`
- `docs/workspace/env-contract.md`
- `docs/workspace/env-deprecations.md`
- `docs/workspace/production-supabase-connection-inventory.md`
- `docs/workspace/vercel-env-review.md`
- `docs/workspace/supabase-rls-grants-review.md`
- `scripts/env_contract_report.py`
- `scripts/workspace-env-contract.sh`
- `TRR-APP/apps/web/src/lib/server/**`
- `TRR-Backend/api/main.py`
- `TRR-Backend/trr_backend/db/**`
- `TRR-Backend/api/auth.py`
- `TRR-Backend/supabase/config.toml`
- Supabase generated types location, if added

Dependencies:

- Phase 0 inventory should land first.

Validation:

- `python3 scripts/env_contract_report.py validate`
- `bash scripts/workspace-env-contract.sh --check`
- `python3 scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md --check`
- `rg -n "NEXT_PUBLIC_.*SERVICE|SERVICE_ROLE|SUPABASE_SERVICE_ROLE_KEY" TRR-APP/apps/web/src` returns no browser-leak findings after classification.
- Supabase config drift test passes or produces an explicit reviewed-difference artifact.
- Generated Supabase types are present/current or documented as intentionally not used.

Expected result:

- The team can answer “which Supabase credential/client does this surface use, and why?” for the whole app.

Acceptance criteria:

- Every active Supabase env family has a single owner and allowed runtime context.
- Deprecated/local-only aliases are documented as such and cannot silently become runtime primary sources.
- Local PostgREST `admin`/`core` exposure has an explicit keep/remove decision.

Commit boundary:

- One workspace/app/backend contract commit.

### Phase 3 - Transaction-Mode Eligibility And Dual-Lane Runtime DB URLs

Problems fixed:

- Supavisor session mode pins connections.
- Production serverless connections can multiply pinned clients.

Concrete changes:

- Introduce explicit DB URL lanes:
  - `TRR_DB_SESSION_URL` for session-mode or direct-compatible work.
  - `TRR_DB_TRANSACTION_URL` for transaction-mode reads on port `6543`.
  - Keep `TRR_DB_URL` as the current compatibility/canonical fallback during migration.
- Add resolver logic that chooses transaction mode only for eligible read pools/routes, with structured logging showing `connection_class=session|transaction`.
- Add a transaction-mode eligibility inventory:
  - App direct SQL callers in `TRR-APP/apps/web/src/lib/server/postgres.ts` and repository modules.
  - Backend read helpers in `TRR-Backend/trr_backend/db/pg.py` and named pool call sites.
  - Tooling/migration scripts that must stay session/direct.
- Disable or avoid prepared statements on transaction-mode clients.
- Verify session-state usage:
  - No named prepared statements.
  - No temp tables.
  - No session-scoped advisory locks.
  - No long-lived cursors.
  - No session-level `SET` requirements. Use `SET LOCAL` inside explicit transactions where needed.
- Start with one low-risk read-only lane:
  - TRR-APP admin health/app DB pressure reads or other single-statement direct SQL.
  - Then backend read-only summary endpoints.
- Document a transaction-mode flight-test recipe:
  - one route at a time;
  - explicit feature flag;
  - transaction-mode URL on port `6543`;
  - prepared statements disabled or proven absent;
  - one-hour observation window;
  - rollback by removing the flag/env override;
  - expected logs include `connection_class=transaction`.
- Keep writes, migrations, backups, long admin jobs, and maintenance scripts on session/direct lane until proven safe.

Affected files/surfaces:

- `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- `TRR-Backend/trr_backend/db/connection.py`
- `TRR-Backend/trr_backend/db/pg.py`
- `TRR-Backend/tests/db/test_connection_resolution.py`
- `TRR-Backend/tests/db/test_pg_pool.py`
- `scripts/lib/runtime-db-env.sh`
- `docs/workspace/env-contract.md`
- `docs/workspace/production-supabase-connection-inventory.md`

Dependencies:

- Phase 1 should be merged first so local session-mode fallback stays bounded while transaction-mode is tested.

Validation:

- `pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/postgres-connection-string-resolution.test.ts --reporter=dot`
- `pytest TRR-Backend/tests/db/test_connection_resolution.py TRR-Backend/tests/db/test_pg_pool.py`
- Manual transaction URL smoke:
  - Connect using a redacted transaction-mode URL.
  - Run representative eligible read routes.
  - Confirm no prepared statement or session-state errors.
- Flight test one low-risk read route and record success/failure in `docs/workspace/production-supabase-connection-inventory.md`.

Expected result:

- Eligible short-lived reads no longer pin session-mode holders.
- Session-dependent tasks remain explicitly routed to session/direct.

Acceptance criteria:

- Every runtime DB URL decision is logged and test-covered.
- Transaction-mode adoption is opt-in per lane until verified.
- Rollback is a single env switch back to session mode.
- Flight-test runbook exists before any broad transaction-mode migration.

Commit boundary:

- One backend/app/shared-env commit if done sequentially; otherwise split backend resolver and app resolver into separate commits with shared docs in the final commit.

### Phase 4 - Hard Local Holder Budget And Worker Profiles

Problems fixed:

- Too many local holders.
- Local and remote workers share the same DB capacity.

Concrete changes:

- Preserve default normal browsing profile:
  - app `1`
  - backend default `2`
  - social profile `3-4`
  - social control `1-2`
  - health `1`
  - screenalytics `0`
  - local heavy workers off
- Add or refine explicit worker/backfill profiles:
  - `PROFILE=worker-debug`
  - `PROFILE=social-backfill`
  - each must print a capacity warning and require explicit opt-in.
- Make heavy local worker profile mutually visible with `WORKSPACE_ENFORCE_DB_HOLDER_BUDGET`.
- For remote Modal workers, add capacity notes:
  - remote job concurrency is not free if it shares the same Supabase project.
  - document remote worker DB pool caps and app/backend local caps together.
- Add status output that differentiates:
  - local app/backend holder budget
  - remote worker configured concurrency
  - actual DB-side holders from `pg_stat_activity`

Affected files/surfaces:

- `profiles/default.env`
- `profiles/social-debug.env`
- optional new `profiles/worker-debug.env`
- `scripts/dev-workspace.sh`
- `scripts/status-workspace.sh`
- `docs/workspace/dev-commands.md`
- `docs/workspace/supabase-capacity-budget.md`

Dependencies:

- Phase 1 guardrails.

Validation:

- `make preflight`
- `bash scripts/status-workspace.sh`
- `PROFILE=worker-debug bash scripts/dev-workspace.sh --dry-run` or equivalent dry-run path.

Expected result:

- Normal admin browsing is stable by default.
- Heavy worker capacity must be consciously selected.

Acceptance criteria:

- Default profile stays below headroom target.
- Worker profiles are documented and do not silently affect default `make dev`.

Commit boundary:

- One workspace commit for profiles and status/docs.

### Phase 5 - Backend Aggregate Endpoints For High-Fanout Admin Pages Across The App

Problems fixed:

- Admin pages fan out too much.
- One slow subrequest can consume multiple holders and fail a whole page.

Concrete changes:

- Inventory the worst fanout routes:
  - `/api/admin/social/landing`
  - season social analytics snapshot
  - week social snapshot
  - social account profile snapshot
  - cast SocialBlade comparison snapshot
  - reddit sources/reddit window admin screens that still use app direct SQL
  - survey/editor admin routes using app-side transactions
  - brand/media/gallery routes with backend proxy fanout
  - global admin/dev-dashboard routes that parallelize many repo/backend checks
- Prioritize the `14` high-fanout production-risk direct-SQL call sites from `docs/workspace/app-direct-sql-inventory.md`:
  - `TRR-APP/apps/web/src/lib/server/admin/reddit-sources-repository.ts` eight `withAuthTransaction`/query sites -> backend `/api/v1/admin/reddit/sources/*` routes.
  - `TRR-APP/apps/web/src/lib/server/admin/social-posts-repository.ts` four sites -> backend social posts routes.
  - `TRR-APP/apps/web/src/lib/server/admin/reddit-discovery-cache-repository.ts` one cache read -> backend read with stale-if-error envelope.
  - `TRR-APP/apps/web/src/lib/server/admin/cast-photo-tags-repository.ts` one read -> backend read with stale-if-error envelope.
- For each high-value route, define a backend aggregate endpoint that owns composition and DB access:
  - `GET /api/v1/admin/socials/landing-dashboard`
  - `GET /api/v1/admin/socials/seasons/{season_id}/analytics-dashboard`
  - `GET /api/v1/admin/socials/seasons/{season_id}/weeks/{week_index}/dashboard`
  - extend existing profile dashboard contract only if gaps remain.
- Move DB-heavy aggregation out of TRR-APP route handlers where possible.
- Add short TTL and stale-if-error behavior at the backend aggregate layer.
- Preserve app compatibility routes as thin proxy/normalization layers.
- Backfill `docs/workspace/api-migration-ledger.md` for every app direct-SQL caller moved behind backend APIs, including app caller, backend route, auth context, cacheability, error contract, and validation command.
- Classify any direct-SQL caller touched in this phase with an owner label: `app-local`, `admin-read-model`, or `backend-shared-schema`.
- Consider per-route `application_name` suffixes for the highest-fanout backend endpoints, for example `trr-backend:social_profile:landing-summary`, so `pg_stat_activity` can identify route-level spikes.
- Update `TRR Workspace Brain/api-contract.md` for each backend producer/app consumer contract.

Affected files/surfaces:

- `TRR-Backend/api/routers/socials.py`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/socials/profile_dashboard.py`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/**/snapshot/route.ts`
- `TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/reddit-sources-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/reddit-discovery-cache-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/cast-photo-tags-repository.ts`
- `TRR-APP/apps/web/src/lib/server/surveys/normalized-survey-admin-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/brand-profile-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/admin-snapshot-cache.ts`
- `docs/workspace/app-direct-sql-inventory.md`
- `docs/workspace/api-migration-ledger.md`
- `TRR Workspace Brain/api-contract.md`

Dependencies:

- Phase 0 evidence identifies which page fanout is most expensive.
- Backend routes should land before app follow-through.

Validation:

- Backend:
  - `pytest TRR-Backend/tests/api/test_admin_socials_landing_summary.py`
  - `pytest TRR-Backend/tests/socials/test_profile_dashboard.py`
  - add new route tests for aggregate endpoints.
- App:
  - `pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/social-landing-repository.test.ts --reporter=dot`
  - add or update snapshot route tests.
- Inventory:
  - `python3 scripts/app-direct-sql-inventory.py --check`
  - `python3 scripts/migration-ownership-lint.py`
- Manual:
  - Open `http://admin.localhost:3000/admin/social`.
  - Open one season social analytics page and one week social page.
  - Confirm fewer app-to-backend subrequests and no full-page timeout on one stale subcomponent.

Expected result:

- App compatibility routes stop initiating several parallel backend reads for the same admin screen.
- Backend aggregate contracts can cache and degrade centrally.

Acceptance criteria:

- The top two admin pages by timeout frequency use backend aggregate endpoints.
- The `14` high-fanout production-risk app direct-SQL call sites are either migrated or each has a tracked remaining-risk exception with owner/date.
- App route code remains thin and has stale/error envelope tests.

Commit boundary:

- One backend commit per aggregate endpoint family.
- One app commit per compatibility route migration.
- One shared contract docs commit.

### Phase 6 - Cheap Live Status, Polling, And SSE De-Pressure

Problem fixed:

- Live status/SSE polling can hold pressure.

Concrete changes:

- Make backend `/api/v1/admin/socials/live-status` read from an in-memory or persisted cheap snapshot with a short refresh interval.
- Apply the same pattern to other polling/status surfaces that touch Supabase, including system health, job progress, queue status, and admin dashboard cards.
- Ensure `/live-status/stream` does not recompute DB-heavy status for every subscriber tick.
- Wire a protected live holder snapshot into `/health/db-pressure` / `/admin/health/db-pressure` using `pg_stat_activity` data where credentials/permissions permit:
  - public endpoint remains summary-only;
  - protected endpoint may include grouped `application_name`, lane, state, and count;
  - no query text or secrets in public output.
- Add a single producer loop or debounced cache refresh:
  - TTL target: 2-5 seconds for admin live status.
  - stale target: 15-30 seconds with visible `stale` metadata.
- App route `/api/admin/trr-api/social/ingest/live-status` should retain `getOrCreateAdminSnapshot` but delegate real freshness to backend snapshot metadata.
- Add a low-cost heartbeat endpoint separate from detailed queue/job status.

Affected files/surfaces:

- `TRR-Backend/api/routers/socials.py`
- backend social ingest/queue repositories used by `_build_live_status_payload`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/live-status/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/live-status/stream/route.ts`
- `TRR-APP/apps/web/src/lib/admin/shared-live-resource.ts`
- `TRR-Backend/api/main.py`
- `TRR-Backend/trr_backend/db/pg.py`

Dependencies:

- Can run in parallel with Phase 5 if write ownership is separated.

Validation:

- Backend unit tests for cache refresh and stale metadata.
- App tests for shared live resource polling and stale display.
- Manual:
  - Open admin page with live status.
  - Watch `.logs/workspace/trr-backend.log` and Supabase holders.
  - Confirm additional browser tabs do not multiply DB work linearly.

Expected result:

- Observing live status stops being a material DB load source.

Acceptance criteria:

- One live-status subscriber and multiple subscribers produce roughly the same backend DB query cadence.
- Stale metadata appears rather than a hard timeout when refresh fails.
- Protected DB pressure includes current grouped holder data or an explicit unsupported/permission-blocked reason.

Commit boundary:

- One backend commit, one app commit.

### Phase 7 - Query Plan And Index Pass For Whole-App Hot Paths

Problem fixed:

- Expensive queries amplify connection pressure.

Concrete changes:

- Add explain scripts for hot routes:
  - social landing summary
  - social profile dashboard
  - season analytics overview
  - week live health
  - shared ingest runs/review queue
  - cast SocialBlade landing/comparison
  - reddit sources and reddit window/admin reads
  - normalized survey admin reads/writes
  - brand profile and media/gallery admin reads
  - global search/show lookup/admin recent-show reads
- Use `EXPLAIN (ANALYZE, BUFFERS)` only where safe and bounded; otherwise use plain `EXPLAIN` plus sampled timing logs.
- Add indexes only from evidence:
  - missing composite indexes for filtering/sorting
  - partial indexes for active/open status rows
  - covering indexes where repeated hot paths need them
- Add migration ownership records to `docs/workspace/api-migration-ledger.md`.
- Ensure RLS/grants impact is checked for every schema/index migration.

Affected files/surfaces:

- `TRR-Backend/scripts/db/`
- `TRR-Backend/migrations` or equivalent migration location
- `TRR-Backend/trr_backend/repositories/**`
- `docs/workspace/api-migration-ledger.md`
- `docs/workspace/supabase-rls-grants-review.md`

Dependencies:

- Phase 0 baseline.
- Phase 5 endpoint contracts help target real route-level queries.

Validation:

- `python3 scripts/migration-ownership-lint.py`
- backend migration tests or SQL dry-run path.
- Before/after explain artifacts stored under docs or logs with redacted values.
- Backend route tests continue passing.

Expected result:

- Hot reads return connections faster.

Acceptance criteria:

- Every new index has a named route/query justification.
- No speculative index migration without explain evidence.

Commit boundary:

- One commit per migration/index group, with matching tests/docs.

### Phase 8 - Partial/Stale Fallback Boundaries Across Admin Read Surfaces

Problem fixed:

- One timeout kills a page.

Concrete changes:

- Extend the `/admin/social` fallback pattern to remaining high-value admin routes:
  - social account profile snapshot
  - season social analytics snapshot
  - week social snapshot
  - cast SocialBlade comparison snapshot
  - reddit source/window admin pages
  - survey/editor admin pages
  - brand/media/gallery admin pages
  - admin dashboard/system health cards
- Use `Promise.allSettled` or backend aggregate partial envelopes where independent subparts can degrade.
- Standardize error envelope fields:
  - `error`
  - `code`
  - `retryable`
  - `trace_id`
  - `stale`
  - `partial_failures`
  - `generated_at`
- Ensure UI shows stale/partial status without a full-page crash.
- Avoid hiding write failures or destructive operation failures behind stale fallback.

Affected files/surfaces:

- `TRR-APP/apps/web/src/app/api/admin/trr-api/**/snapshot/route.ts`
- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`
- `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
- backend aggregate endpoint envelopes from Phase 5

Dependencies:

- Phase 5 aggregate endpoints simplify this phase, but some route-local fallback work can happen earlier.

Validation:

- Vitest route tests for timeout/stale fallback cases.
- Component tests for stale/partial labels.
- Manual with simulated backend timeout:
  - Page remains usable.
  - Stale/partial reason is visible.
  - Console/log has trace ID.

Expected result:

- Operator pages remain usable under transient DB/backend pressure.

Acceptance criteria:

- No read-only admin dashboard route blanks because one independent subsection timed out.
- Mutations still fail loudly.

Commit boundary:

- One app commit per route/page family.

### Phase 8B - Migration Ownership And Schema Hygiene

Problems fixed:

- Shared schema changes are split between backend Supabase migrations and app-owned `run-migrations.mjs` migrations.
- Runtime DDL and duplicate/ambiguous migration prefixes make provenance hard to audit.

Concrete changes:

- Port shared-schema app migrations into backend-owned Supabase migrations, starting with:
  - app migrations `010-014`
  - app migration `020`
  - app migration `022b`
  - app migration `030`
  - any new migration replacing `shows-repository.ts` runtime DDL
- Quarantine app copies after backend parity is proven:
  - keep historical app files only if tests/tooling require them;
  - mark them as retired or app-local only;
  - prevent double-application in local/prod setup.
- Consolidate or rename duplicate migration prefix files such as `0022_create_admin_season_cast_survey_roles.sql` and `0022_link_brand_shows_to_trr.sql` so ordering is explicit.
- Backfill `docs/workspace/api-migration-ledger.md` with all app-to-backend ownership moves already documented in `TRR Workspace Brain/api-contract.md`.
- Add migration provenance tests:
  - app request-time code cannot execute DDL;
  - shared-schema migrations are owned by backend;
  - app migration allowlist contains only app-local/editor-owned schema.

Affected files/surfaces:

- `TRR-Backend/supabase/migrations/**`
- `TRR-APP/apps/web/db/migrations/**`
- `TRR-APP/apps/web/scripts/run-migrations.mjs`
- `TRR-APP/apps/web/POSTGRES_SETUP.md`
- `docs/workspace/api-migration-ledger.md`
- `docs/workspace/app-migration-ownership-allowlist.txt`
- `scripts/migration-ownership-lint.py`
- `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`

Dependencies:

- Phase 1 runtime DDL quarantine.
- Phase 2 ownership matrix.

Validation:

- `python3 scripts/migration-ownership-lint.py`
- Backend migration dry-run or Supabase CLI migration validation against a disposable/branch database.
- App tests for any affected admin/survey/show routes.
- Static DDL blocker test for app request-time code.

Expected result:

- Shared schema changes have one backend-owned provenance path.
- App migration tooling remains only for explicitly app-local schema until fully retired.

Acceptance criteria:

- The listed shared-schema app migrations have backend equivalents or documented non-shared exceptions.
- Duplicate migration prefixes are resolved or explicitly documented with ordering guarantees.
- App request-time DDL no longer exists.

Commit boundary:

- One commit per migration ownership slice.
- One follow-up commit for app migration quarantine/docs/tests.

### Phase 9 - Production Vercel And Serverless Supabase Guardrails

Problem fixed:

- Production serverless connections can multiply pinned clients.

Concrete changes:

- Keep `scripts/vercel-project-guard.py` as the required preflight for env/deploy checks.
- Add a production DB runtime review that records:
  - `TRR_DB_URL` connection class
  - transaction/session/direct lane use
  - Vercel project ID
  - function max duration/concurrency assumptions
  - `attachDatabasePool` status
  - app direct SQL callers still present
- Add a production Supabase API/Auth/Storage review that records:
  - active app server Supabase envs
  - browser-exposed Supabase envs, if any
  - service-role usage and server-only enforcement
  - Supabase integration-managed envs retained but not runtime-primary
  - storage bucket assumptions and permission gaps
- Resolve the nested Vercel project risk:
  - either unlink `TRR-APP/apps/web/.vercel/project.json` from the stale `web` project;
  - or formally document it as preview/sandbox-only and make production env commands fail when run from `TRR-APP/apps/web`.
- Strip or reclassify retained legacy production envs:
  - remove unused `DATABASE_URL`, `POSTGRES_*`, `SUPABASE_*`, and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` if Vercel/Supabase integration allows;
  - if integration-managed values cannot be removed, document them as retained-but-unused and add a guard proving runtime does not read them.
- Verify production Supabase Auth policy against dev config:
  - production confirmations enabled where required;
  - password length at least `8`;
  - SMTP provider configured through managed secrets if Supabase Auth email is used.
- Verify Storage production posture:
  - bucket list and policies captured;
  - allowed MIME types and max file size documented for any bucket TRR uses;
  - commented-out local config is either intentional or replaced with production-safe config docs.
- Prefer transaction-mode or Vercel-attached pooled behavior for serverless read paths.
- Keep app-side direct SQL minimal and documented in `docs/workspace/app-direct-sql-inventory.md`.
- Fail deploy/preflight if app runtime regresses to legacy `DATABASE_URL` or `SUPABASE_DB_URL` as primary source.

Affected files/surfaces:

- `scripts/vercel-project-guard.py`
- `docs/workspace/production-supabase-connection-inventory.md`
- `docs/workspace/vercel-env-review.md`
- `docs/workspace/app-direct-sql-inventory.md`
- `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `TRR-APP/apps/web/tests/admin-app-db-pressure-route.test.ts`
- `TRR-APP/apps/web/.vercel/project.json`
- `TRR-Backend/supabase/config.toml`
- Supabase Dashboard Auth/Storage settings snapshot docs

Dependencies:

- Phase 3 URL lane semantics.

Validation:

- `python3 scripts/vercel-project-guard.py --project-dir TRR-APP`
- `python3 scripts/vercel-project-guard.py --project-dir TRR-APP/apps/web` must fail unless explicitly classified as sandbox-only.
- `python3 scripts/app-direct-sql-inventory.py --check`
- `pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/admin-app-db-pressure-route.test.ts tests/postgres-connection-string-resolution.test.ts --reporter=dot`
- `vercel env ls production` review artifact confirms canonical env posture or retained integration-managed exceptions.

Expected result:

- Production does not multiply session-mode DB holders via warm serverless instances without visibility.

Acceptance criteria:

- Production connection class and pool behavior are documented before deploy.
- App direct-SQL inventory stays current.
- Nested Vercel project commands cannot accidentally mutate production.
- Production Auth/Storage/SMTP posture is either verified or has explicit blocked/pending owner notes.

Commit boundary:

- One app/workspace docs/tooling commit.

### Phase 10 - Low-Cost Capacity Valve With Evidence Gate

Problem fixed:

- Some pressure may remain after cheap architectural fixes.

Concrete changes:

- Add an explicit decision gate for raising Supavisor pool size from `15` to `25` or `30`.
- Require evidence before any change:
  - `SHOW max_connections`
  - Supabase dashboard/Grafana connection snapshot
  - `pg_stat_activity` grouped by application
  - expected/worst-case app/backend/worker holders
  - rollback value and owner
- Keep pool-size changes separate from code changes.
- Document that a compute upgrade comes after:
  - env drift fixed
  - holder budget enforced
  - high-fanout routes consolidated
  - live status cached
  - query-plan pass complete

Affected files/surfaces:

- `docs/workspace/supabase-capacity-budget.md`
- operations runbook or `docs/workspace/dev-commands.md`

Dependencies:

- Phases 0-9, including Phase 8B, should run first unless the system is operationally blocked.

Validation:

- Evidence table fully populated.
- Rollback instructions tested in a non-production setting where possible.

Expected result:

- If pool size is raised, it is a measured operational change, not guesswork.

Acceptance criteria:

- No pool-size change without owner, rollback target, and evidence snapshot.

Commit boundary:

- Docs-only operations commit unless a separate operational change is made outside git.

## architecture_impact

- Backend becomes the owner of more admin read aggregation. This reduces app route fanout and centralizes caching/error envelopes.
- TRR-APP compatibility routes become thinner and safer under partial failure.
- Runtime DB configuration gains explicit session and transaction lanes, reducing ambiguity around `TRR_DB_URL`.
- Workspace scripts become the source of truth for local holder-budget enforcement.
- Production serverless DB behavior becomes documented and guarded rather than inferred from env names.

## data_or_api_impact

- Potential additive backend API contracts:
  - social landing dashboard aggregate
  - season social analytics dashboard aggregate
  - week social dashboard aggregate
  - live-status cached snapshot metadata
- Potential env contract additions:
  - `TRR_DB_SESSION_URL`
  - `TRR_DB_TRANSACTION_URL`
  - optional `TRR_DB_URL_MODE` or resolver metadata if needed
- Potential schema/index migrations only after query-plan evidence.
- No destructive data changes planned.
- Any new backend producer/app consumer contract must be recorded in `TRR Workspace Brain/api-contract.md`.

## ux_admin_ops_considerations

- Admin pages should show stale/partial state clearly, not generic timeout banners.
- Operator-facing diagnostics should name:
  - current app/backend pool caps
  - active holder budget
  - connection class
  - stale cache age
  - trace ID
- Normal `make dev` should be boring and stable. Heavy worker/backfill mode should be explicit and visibly different.
- Production rollout should be staged:
  1. local validation
  2. preview validation
  3. production env review
  4. production deploy
  5. connection monitoring

## validation_plan

Automated workspace validation:

```bash
make preflight
bash scripts/check-workspace-contract.sh
python3 scripts/env_contract_report.py validate
python3 scripts/migration-ownership-lint.py
python3 scripts/app-direct-sql-inventory.py --check
python3 scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md --check
python3 scripts/vercel-project-guard.py --project-dir TRR-APP
```

Backend validation:

```bash
cd TRR-Backend
pytest tests/db/test_connection_resolution.py tests/db/test_pg_pool.py
pytest tests/api/test_health.py tests/api/test_admin_socials_landing_summary.py
pytest tests/socials/test_profile_dashboard.py
```

App validation:

```bash
pnpm -C TRR-APP/apps/web run typecheck
pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.ts \
  tests/postgres-connection-string-resolution.test.ts \
  tests/admin-app-db-pressure-route.test.ts \
  tests/social-landing-repository.test.ts \
  tests/shared-live-resource-polling.test.tsx \
  --reporter=dot
```

Manual validation:

1. Start default local stack with normal browsing profile.
2. Visit `http://admin.localhost:3000/admin/social`.
3. Visit a social account profile page.
4. Visit a season social analytics page and a week social page.
5. Visit one non-social Supabase-backed admin surface, such as reddit sources, survey admin, brand/media, or global admin dashboard.
6. Watch `.logs/workspace/trr-app.log`, `.logs/workspace/trr-backend.log`, and DB holder snapshots.
6. Confirm:
   - no repeated `EMAXCONNSESSION`
   - no full-page timeout on read-only dashboards
   - stale/partial UI appears when backend reads are forced to fail
   - holder budget is below the configured headroom target

Production/preview validation:

1. Run Vercel project guard.
2. Capture production/preview connection inventory.
3. Confirm app runtime connection class and pool behavior.
4. Confirm no legacy runtime fallback to `DATABASE_URL` or `SUPABASE_DB_URL`.
5. Monitor Supabase connections after deploy.

## acceptance_criteria

- Default `make dev` cannot silently start with unsafe session-mode pool overrides.
- Normal local admin browsing stays under the observed Supavisor headroom target.
- At least the most visible failing route, `/admin/social`, one social dashboard route, and one non-social Supabase-backed admin route have backend-owned aggregation or robust partial fallback.
- Live status does not recompute DB-heavy status per subscriber tick.
- Eligible read-only paths have a tested transaction-mode lane, or are explicitly documented as session-only.
- Hot-path query/index changes are backed by explain evidence.
- Production connection behavior is inventoried and guarded before deploy.
- Supabase pool-size increase remains optional and evidence-gated.

## risks_edge_cases_open_questions

- Transaction mode does not support prepared statements; each Node/Python client must be checked before migration.
- Session-level settings do not persist in transaction mode. Any path relying on session state must stay session/direct or use transaction-local settings.
- Supavisor session and transaction modes may still share underlying project/database capacity; moving to transaction mode reduces pinned holders but does not remove all capacity limits.
- Remote Modal workers may still compete with local/admin usage against the same Supabase project.
- Some admin fanout reflects real product needs; aggregate endpoints must preserve freshness and partial data semantics.
- Index migrations can improve hold time but may add write overhead. Add only with query-plan evidence.
- Existing dirty worktree changes must be preserved; implementation agents must avoid reverting unrelated local edits.

## follow_up_improvements

- Add materialized/read-model phases for social profile, season analytics, reddit/survey admin, or brand/media only after live aggregate contracts stabilize and query evidence justifies it.
- Add dashboard charts for holder budget over time.
- Add a recurring production capacity review tied to deploys that change DB access.
- Consider paid dedicated pooler or compute upgrade only after low-cost phases and evidence gate.

## recommended_next_step_after_approval

Use `orchestrate-plan-execution` for sequential execution. Start with Phases 0-2 because whole-app inventory, ownership, env drift, and visibility are prerequisites for every other fix. Use independent subagent workstreams only after the guardrails land, especially for Phase 5 backend aggregates, Phase 6 live-status/polling caching, and Phase 7 query-plan/index work.

## ready_for_execution

Yes. The plan is execution-ready, with the first safe implementation target being Phase 0 plus Phase 1 and Phase 2 in the workspace scripts/docs/tests.
