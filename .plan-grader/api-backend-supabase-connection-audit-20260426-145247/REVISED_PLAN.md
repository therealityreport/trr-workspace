# TRR API/Backend/Supabase Connection Audit And Improvement Plan

Date: 2026-04-26

Status: revised by Plan Grader with all prior `SUGGESTIONS.md` items incorporated as required execution tasks. Execute only after Phase 0 evidence is captured or the blocker is explicitly recorded.

## Goal

Audit and improve the local-development and production-facing Supabase/API/backend connection posture for TRR. The target end state is:

- local `make dev` remains cloud-first, session-pooled, tiny-pool, and observable;
- Vercel production has a documented, safe DB connection strategy;
- schema and migrations are backend-owned unless intentionally app-local;
- app direct SQL is reduced or explicitly justified;
- Supabase RLS/grants/exposed schemas are reviewed with real catalog evidence;
- production changes are gated by advisors, Vercel env inventory, and live connection-holder evidence.

This plan is broader than the existing Supavisor stabilization plan. That plan focused on session-pool saturation. This plan covers connection surfaces, API/backend boundaries, Vercel deployment ownership, migrations, auth/RLS, and operational controls.

## Source References

- Supabase connection choice: `https://supabase.com/docs/guides/database/connecting-to-postgres`
- Supabase connection management and live `pg_stat_activity` evidence: `https://supabase.com/docs/guides/database/connection-management`
- Supabase deployment and branching: `https://supabase.com/docs/guides/deployment`
- Supabase/Vercel environment behavior: `https://supabase.com/docs/guides/troubleshooting/vercel-integration-environment-variables-not-syncing-for-persistent-git-branches-b9191e`
- Supabase IPv4/direct-connection constraints: `https://supabase.com/docs/guides/platform/ipv4-address`
- Supabase RLS guidance: `https://supabase.com/docs/guides/database/postgres/row-level-security`
- Vercel database pool handling for functions: `https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package`

## Current State Summary

### Confirmed Local Connection Shape

Local env files were inspected without printing secret values.

| Surface | Canonical runtime DB env | Current class | Notes |
| --- | --- | --- | --- |
| `TRR-APP/apps/web/.env.local` | `TRR_DB_URL` | Supavisor session mode `pooler.supabase.com:5432` | Also contains legacy `DATABASE_URL` and `SUPABASE_DB_URL` aliases pointing at the same session lane. |
| `TRR-Backend/.env` | `TRR_DB_URL` | Supavisor session mode `pooler.supabase.com:5432` | Also contains deprecated `SUPABASE_DB_URL`; `DATABASE_URL` is absent. |
| TRR Supabase MCP binding | `.codex/config.toml` | project `vwxfvzutyufrkhfgoeaa` | MCP advisory/migration/storage reads are currently blocked by permission. |
| Vercel production app | `trr-app` project | latest deployment `READY`, target `production`, region `iad1` | Vercel MCP confirms deployment metadata, but not secret env values. |
| Nested Vercel project | `web` project under `apps/web` | latest deployment `ERROR` | Needs explicit ownership decision to avoid env/deploy drift. |

### What Already Looks Good

- Runtime DB names are mostly standardized on `TRR_DB_URL` and optional `TRR_DB_FALLBACK_URL`.
- `TRR-APP` runtime code explicitly does not use `DATABASE_URL` or `SUPABASE_DB_URL` for request handling.
- App and backend classify connection lanes and reject direct/transaction/unknown runtime lanes where the current contract expects session mode.
- Local `make dev` projects conservative pool defaults: app pool `1`, backend default `2`, social profile `4`, social control `2`, health `1`, for a projected local holder budget of `10`.
- Backend has named psycopg2 pools for `default`, `social_profile`, `social_control`, and `health`, plus DB pressure endpoints.
- App Postgres helper sets `application_name`, caps pool/concurrent operations, logs pool init/queue/retry events, pins transaction-local `search_path`, and uses transaction-local auth settings for RLS-sensitive flows.
- Supabase JS in TRR-APP is intentionally isolated to auth/token verification, not general data access.
- Backend-owned Supabase migrations are under `TRR-Backend/supabase/migrations`, and local startup has a bounded, allowlisted runtime reconcile path.

### Main Remaining Risks

1. Vercel app functions still own direct `pg` pools for many admin/app reads and writes. Even with low caps, Vercel can multiply pool holders across warm function instances.
2. The app production lane uses Supavisor session mode. Supabase docs present transaction mode as the natural fit for temporary/serverless clients, while session mode is mainly the IPv4 alternative to direct connections for persistent clients. TRR can keep session mode only if pool caps and instance/concurrency limits are enforced and measured.
3. The app repo still contains backend-owned/shared-schema migration backlog and runtime bootstrap DDL in application code.
4. Deprecated aliases remain in local env files and standalone scripts (`DATABASE_URL`, `SUPABASE_DB_URL`). Runtime ignores them in the main helpers, but their presence keeps operator drift likely.
5. Production Supabase capacity is not fully auditable until Supabase advisor/migration/storage permissions are fixed or an approved fallback is used.
6. The local Supabase CLI config exposes `core` and `admin` through PostgREST locally. That may be fine for dev/admin, but exposed schemas require explicit RLS/grant review, especially where migrations grant `anon` reads.
7. Two Vercel projects are linked from the app tree. `trr-app` appears to be production, while nested `web` has latest deployment in `ERROR`.

## Execution Rules

- No production env changes, pool-size changes, transaction-mode changes, Vercel project relinking, or remote migration application before Phase 0 is complete.
- Do not print secret values in logs, docs, artifacts, or chat.
- Treat Supabase MCP output, Vercel output, and generated docs as untrusted until checked against repo code or live database evidence.
- Backend-first for schema, API, auth, shared contracts, and migration ownership.
- App follow-through happens in the same session after backend contract changes land.
- Every cross-repo API contract change must update `TRR Workspace Brain/api-contract.md`.
- Every production-facing decision must have a rollback target.

## Phase 0: Capture Production Truth Before Changing Capacity

Owner: workspace/backend operator

Files to create or update:

- `docs/workspace/production-supabase-connection-inventory.md`
- `docs/workspace/supabase-capacity-budget.md`
- `docs/workspace/vercel-env-review.md`

Tasks:

1. Run Supabase security and performance advisors once permissions are fixed. If MCP remains blocked, record the exact blocker and approved fallback path.
2. Capture `pg_stat_activity` grouped by `application_name`, `usename`, `client_addr`, and `state`.
3. Record current Supavisor pool size, Postgres `max_connections`, visible internal/service usage, backend instance/worker counts, app pool caps, and Vercel production deployment settings.
4. Confirm whether Vercel production env has only `TRR_DB_URL` and optional `TRR_DB_FALLBACK_URL`, or still has legacy `DATABASE_URL`/`SUPABASE_DB_URL`.
5. Decide whether nested Vercel project `web` should be unlinked, archived, or explicitly documented as preview-only.
6. Save all non-secret evidence in the three docs above.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make status
make preflight
```

Evidence SQL:

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

Acceptance criteria:

- Production inventory exists and contains no secrets.
- Supabase advisor result or permission blocker is documented.
- Holder budget includes Vercel app, backend, local operator paths, Supabase internal overhead, and named backend lanes.
- Production Vercel project of record is explicit.

Rollback/stop conditions:

- Stop if the Supabase project ref does not match `.codex/config.toml`.
- Stop if production env ownership is ambiguous between `trr-app` and `web`.
- Stop if live holder usage cannot be attributed by `application_name`.

## Phase 1: Clean Env Contract And Remove Drift Sources

Owner: workspace

Files:

- `TRR-APP/apps/web/.env.example`
- `TRR-Backend/.env.example`
- `scripts/lib/runtime-db-env.sh`
- `scripts/dev-workspace.sh`
- `scripts/check-workspace-contract.sh`
- `docs/workspace/env-contract.md`
- `docs/workspace/env-deprecations.md`
- `docs/workspace/vercel-env-review.md`

Tasks:

1. Make `TRR_DB_URL` and optional `TRR_DB_FALLBACK_URL` the only runtime DB variables in docs and generated contracts.
2. Keep `DATABASE_URL` compatibility only in explicitly named tooling scripts.
3. Add a preflight warning when `.env.local` or `.env` contains legacy aliases equal to the canonical runtime URL.
4. Add a production/deploy preflight that fails if Vercel production uses `DATABASE_URL` or `SUPABASE_DB_URL` as the app runtime source.
5. Preserve `DATABASE_URL` only for third-party tools that demand that exact name, and label it as tooling-only.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make preflight
python3 -m pytest scripts/test_runtime_db_env.py scripts/test_workspace_app_env_projection.py
```

Acceptance criteria:

- Runtime docs and generated examples point operators to `TRR_DB_URL`.
- Legacy aliases are either absent from runtime env or reported as tooling-only drift.
- No secret values appear in output or docs.

## Phase 2: Harden Vercel App Database Pool Handling

Owner: TRR-APP

Files:

- `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `TRR-APP/apps/web/package.json`
- `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- `TRR-APP/apps/web/tests/admin-app-db-pressure-route.test.ts`

Tasks:

1. Add `@vercel/functions`.
2. Call `attachDatabasePool(pool)` immediately after creating the `pg.Pool` when running on Vercel.
3. Keep `POSTGRES_POOL_MAX=1` for preview and local; keep production at `2` only if Phase 0 capacity math proves it is safe.
4. Add structured logs for `VERCEL_ENV`, selected connection class, pool cap, active permit count, queue depth, and sanitized `application_name` at pool init.
5. Add a test proving invalid `POSTGRES_APPLICATION_NAME` values are sanitized.
6. Add a test proving Vercel runtime rejects direct and transaction lanes unless an explicit future transaction-mode flag is introduced.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c apps/web/vitest.config.ts apps/web/tests/postgres-connection-string-resolution.test.ts apps/web/tests/admin-app-db-pressure-route.test.ts
pnpm -C apps/web run typecheck
```

Acceptance criteria:

- Vercel runtime pool is attached through `@vercel/functions`.
- Pool init logs are non-secret and identify the selected lane.
- Existing local lane rejection behavior remains intact.

Rollback:

- Revert only the package and `postgres.ts` pool attachment changes if Vercel runtime breaks.
- Do not change Supavisor pool size as the rollback.

## Phase 3: Inventory And Reduce Vercel App Direct SQL

Owner: workspace plus TRR-APP/TRR-Backend

Decision options:

| Option | Description | Recommendation |
| --- | --- | --- |
| A | Keep Vercel app direct SQL on session pooler with strict pool caps. | Short-term only. Requires live evidence and Vercel pool attachment. |
| B | Move high-fan-out direct SQL from Vercel app into backend APIs. | Preferred durable path. Reduces serverless DB holder multiplication. |
| C | Move app direct SQL to Supavisor transaction mode. | Experiment only after proving `pg` usage has no prepared-statement/session-state conflicts. |

Tasks:

1. Generate `docs/workspace/app-direct-sql-inventory.md`.
2. Inventory all `TRR-APP/apps/web/src/lib/server/**` and `TRR-APP/apps/web/src/app/api/**` imports or calls of `query`, `withTransaction`, `withAuthTransaction`, and `queryWithAuth`.
3. Classify every caller as:
   - app-local survey/editor owner,
   - backend-owned shared schema,
   - admin read-model candidate,
   - high-fan-out production risk,
   - low-volume acceptable app-local direct SQL.
4. Pick the first migration slice from high-fan-out read paths only. Candidate families include social landing/profile snapshots, Reddit summaries, media asset detail reads, and cast/photo freshness reads.
5. For each migrated surface, add or extend backend API route first, then app proxy/repository client.
6. Preserve app route cache and in-flight dedupe where they reduce browser fan-out.
7. Keep low-volume legacy survey editor writes app-local until their tables are ported.

Inventory command:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
rg -n "from ['\\\"]@/lib/server/postgres['\\\"]|withAuthTransaction|queryWithAuth|withTransaction|query\\(" apps/web/src/lib/server apps/web/src/app/api
```

Acceptance criteria:

- Inventory doc contains a current count and owner label for every direct-SQL caller.
- First migration slice reduces the high-fan-out direct-SQL count.
- Remaining direct SQL has an explicit owner label in `POSTGRES_SETUP.md` or the inventory doc.

Stop conditions:

- Stop before moving writes that require auth/RLS semantics unless backend route auth context is proven equivalent.
- Stop before removing app cache/dedupe unless the backend replacement preserves the user-visible latency contract.

## Phase 4: Finish Migration Ownership Cleanup

Owner: backend first, app follow-through

Files:

- `TRR-Backend/supabase/migrations/`
- `TRR-APP/apps/web/db/migrations/`
- `TRR-APP/apps/web/POSTGRES_SETUP.md`
- `TRR-APP/apps/web/scripts/run-migrations.mjs`
- `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/typography-repository.ts`

Tasks:

1. Port shared-schema files listed in `POSTGRES_SETUP.md` from app migrations into backend-owned Supabase migrations.
2. Prove backend parity before removing or quarantining app migration files.
3. Convert app runtime bootstrap DDL into migrations:
   - `survey_shows` columns and palette library objects;
   - `site_typography_sets`, `site_typography_assignments`, and triggers.
4. Add a test or static guard that app route/repository code cannot execute DDL during request handling.
5. Keep app migration runner app-local only.

Static guard:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
rg -n "CREATE TABLE|ALTER TABLE|CREATE OR REPLACE FUNCTION|CREATE TRIGGER|DROP TABLE|DROP FUNCTION" apps/web/src/lib/server apps/web/src/app/api
```

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
supabase migration list --linked
pytest tests/db tests/api

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run db:migrate -- --dry-run
```

Remote migration safety:

- Do not run `supabase db push` against production without confirming the project ref, target branch/environment, and approved direct connection lane.
- Record migration rollback or forward-fix strategy in the migration PR.

Acceptance criteria:

- No request-time DDL remains in app server repositories.
- Shared schema changes have backend-owned migrations.
- App migration runner is documented as app-local compatibility only.

## Phase 5: RLS, Grants, And Exposed Schema Review

Owner: backend

Files:

- `TRR-Backend/supabase/config.toml`
- `TRR-Backend/supabase/migrations/`
- new audit SQL under `TRR-Backend/scripts/db/`
- `docs/workspace/supabase-rls-grants-review.md`

Tasks:

1. Review exposed local API schemas: `public`, `graphql_public`, `core`, and `admin`.
2. Generate table-policy inventory for exposed schemas:
   - RLS enabled?
   - RLS forced?
   - grants to `anon`?
   - grants to `authenticated`?
   - service-role-only intent?
3. Decide whether `admin` should be exposed via PostgREST locally at all, or kept backend-service-only.
4. Ensure SQL-created tables in exposed schemas either have RLS enabled or are intentionally excluded from API exposure.
5. Document which public read policies are product-intentional.

Validation SQL:

```sql
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND n.nspname IN ('public', 'core', 'admin', 'firebase_surveys', 'social')
ORDER BY n.nspname, c.relname;
```

Grant inventory SQL:

```sql
SELECT
  table_schema,
  table_name,
  grantee,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('public', 'core', 'admin', 'firebase_surveys', 'social')
  AND grantee IN ('anon', 'authenticated', 'service_role')
ORDER BY table_schema, table_name, grantee, privilege_type;
```

Acceptance criteria:

- Every exposed table has a documented RLS/grant posture.
- Any intentionally public read is named and justified.
- Any accidental `anon` or `authenticated` grant has a migration fix or explicit owner decision.

## Phase 6: Production Capacity And Deployment Controls

Owner: workspace plus deployment owner

Files:

- `docs/workspace/supabase-capacity-budget.md`
- `docs/workspace/vercel-env-review.md`
- Vercel project settings
- Supabase dashboard/settings

Tasks:

1. Fill the production capacity table in `supabase-capacity-budget.md`.
2. Add Vercel production env checklist:
   - `TRR_DB_URL` is session pooler `:5432` unless a future transaction lane is approved;
   - `POSTGRES_POOL_MAX` is set intentionally;
   - `POSTGRES_MAX_CONCURRENT_OPERATIONS=1`;
   - `POSTGRES_APPLICATION_NAME` is a non-secret lane label;
   - legacy aliases are absent or explicitly tooling-only.
3. Confirm Vercel production project is `trr-app`, not nested `web`.
4. Confirm backend production platform and instance/worker counts, then include them in Supabase holder math.
5. Keep Supavisor pool-size changes separate from code deploys and record rollback targets.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
vercel env ls production
vercel env ls preview
```

Do not print secret values in logs or docs.

Acceptance criteria:

- Capacity budget has a production section with current numbers and owner.
- Vercel env review identifies the project of record and stale/nested project disposition.
- Any pool-size change has a separate change record and rollback target.

## Phase 7: API Boundary Consolidation

Owner: backend first, app follow-through

Files:

- `TRR-Backend/api/routers/`
- `TRR-Backend/trr_backend/repositories/`
- `TRR-APP/apps/web/src/lib/server/trr-api/`
- `TRR-APP/apps/web/src/lib/server/admin/`
- `TRR Workspace Brain/api-contract.md`

Tasks:

1. Treat TRR-Backend as owner of shared schema read models and admin write commands.
2. For each migrated app direct-SQL surface, add or extend a backend API route and app proxy/repository client.
3. Preserve app route cache/in-flight dedupe where it reduces browser fan-out.
4. Update `api-contract.md` for every app/backend contract change in the same session.
5. Keep backend routes additive until app consumers are migrated.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c apps/web/vitest.config.ts apps/web/tests
```

Acceptance criteria:

- App/backend contract changes are recorded in `api-contract.md`.
- Migrated app surfaces no longer import the app Postgres helper.
- Backend routes preserve auth, cacheability, and error contracts expected by app clients.

## Phase 8: Optional Transaction-Mode Experiment

Owner: workspace plus TRR-APP

Run this only after Phases 0, 2, and 3.

Tasks:

1. Create a non-production transaction-mode test lane.
2. Prove whether the app `pg` usage, transaction-local settings, and RLS auth context work under transaction pooling.
3. Disable or avoid prepared statements if required by the pooler mode.
4. Compare holder count, latency, error rates, and correctness against session mode.

Acceptance criteria:

- No production switch happens during the experiment.
- Results are documented in `docs/workspace/vercel-env-review.md`.
- If transaction mode fails, the plan records why session mode remains the approved lane.

Stop conditions:

- Stop on auth-context leakage, transaction-local setting failure, prepared-statement errors, or unexplained data mismatch.

## ADDITIONAL SUGGESTIONS

These tasks incorporate every numbered suggestion from the prior `SUGGESTIONS.md`. They are now required plan work, not optional follow-ups.

### Task S1: Source Suggestion 1 - Add a connection budget dashboard card

Concrete changes:

- Add an operator-facing connection budget card to the TRR-APP admin health surface after Phase 0/6 establishes the canonical capacity fields.
- Read from existing app/backend DB pressure endpoints first; add backend fields only if the current endpoints cannot expose non-secret holder budget, pool cap, active holder, queue depth, and stale evidence timestamps.
- Display only non-secret lane labels, counts, timestamps, and status; never display connection strings, project tokens, service role keys, or raw env values.

Dependencies:

- Phase 0 production inventory exists.
- Phase 6 production capacity budget fields are defined.
- Existing DB pressure routes are confirmed current.

Affected surfaces:

- `TRR-APP/apps/web/src/app/api/admin/health/app-db-pressure/`
- existing TRR-APP admin health UI surface
- backend DB pressure endpoints if additional non-secret fields are required
- `docs/workspace/supabase-capacity-budget.md`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c apps/web/vitest.config.ts apps/web/tests/admin-app-db-pressure-route.test.ts
pnpm -C apps/web run typecheck
```

Acceptance criteria:

- Admin health shows current holder budget status without requiring manual SQL.
- Card state is useful when evidence is missing, stale, healthy, or over budget.
- No secret values are rendered or logged.

Commit boundary:

- One app-focused commit for health API/UI changes, plus a backend commit only if endpoint fields must change.

### Task S2: Source Suggestion 2 - Add `application_name` conventions to the env contract

Concrete changes:

- Define allowed `application_name` patterns for app, backend default, backend social profile, backend social control, health, scripts, and one-off operator lanes.
- Document max length, safe character set, no-secret rule, and expected examples.
- Update app/backend env examples and generators so `pg_stat_activity` grouping is predictable.

Dependencies:

- Phase 1 env contract cleanup.

Affected surfaces:

- `docs/workspace/env-contract.md`
- `TRR-APP/apps/web/.env.example`
- `TRR-Backend/.env.example`
- env projection/generator scripts that write application-name defaults

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make preflight
python3 -m pytest scripts/test_runtime_db_env.py scripts/test_workspace_app_env_projection.py
```

Acceptance criteria:

- Every runtime lane has a documented non-secret application-name convention.
- Phase 0 `pg_stat_activity` output can be grouped by lane without manual interpretation.
- Preflight catches invalid or secret-looking application names where practical.

Commit boundary:

- One workspace env-contract commit.

### Task S3: Source Suggestion 3 - Add a one-command direct-SQL inventory script

Concrete changes:

- Add a script that scans TRR-APP server code for direct imports/calls of `query`, `withTransaction`, `withAuthTransaction`, and `queryWithAuth`.
- Emit a stable markdown or JSON inventory with file, symbol, rough owner label, and classification status.
- Wire the script into Phase 3 so every migration slice can compare before/after counts.

Dependencies:

- Phase 3 inventory taxonomy is accepted.

Affected surfaces:

- `scripts/` or `TRR-APP/apps/web/scripts/`
- `docs/workspace/app-direct-sql-inventory.md`
- optional test fixture for inventory parsing

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 <inventory-script-path> --check
```

Acceptance criteria:

- The command runs from the workspace root.
- Output is deterministic enough for review diffs.
- It distinguishes app-local direct SQL from high-fan-out/backend-owned candidates.

Commit boundary:

- One tooling commit with docs and tests for the inventory script.

### Task S4: Source Suggestion 4 - Add a migration ownership linter

Concrete changes:

- Add a linter or preflight check that flags new shared-schema migrations under `TRR-APP/apps/web/db/migrations/`.
- Allow explicitly app-local migrations only when they match the documented app-local owner list.
- Add CI/preflight guidance so shared schema changes land in `TRR-Backend/supabase/migrations/`.

Dependencies:

- Phase 4 defines the final app-local vs backend-owned migration boundary.

Affected surfaces:

- workspace preflight scripts
- `TRR-APP/apps/web/POSTGRES_SETUP.md`
- `TRR-Backend/supabase/migrations/`
- `TRR-APP/apps/web/db/migrations/`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make preflight
```

Acceptance criteria:

- New shared-schema app migrations fail the linter unless explicitly allowlisted.
- Backend-owned migration path is named in the failure message.
- Existing app-local migrations are not falsely blocked.

Commit boundary:

- One workspace tooling commit after Phase 4 migration ownership is clarified.

### Task S5: Source Suggestion 5 - Add a Vercel project guard script

Concrete changes:

- Add a guard command that reports the current Vercel project name/id for the current directory and compares it to the project of record.
- Require the guard before production env review or mutation commands.
- Document how to handle the nested `web` project once Phase 0 decides whether it is unlinked, archived, or preview-only.

Dependencies:

- Phase 0 decides project of record and nested-project disposition.

Affected surfaces:

- `TRR-APP` scripts or workspace scripts
- `docs/workspace/vercel-env-review.md`
- Vercel project metadata files under app directories

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
<vercel-project-guard-command> --check
```

Acceptance criteria:

- Guard passes only for the approved project context.
- Guard output prints project names/ids but no secret env values.
- Operators get a clear stop message when running from the wrong directory/project.

Commit boundary:

- One TRR-APP/workspace tooling commit.

### Task S6: Source Suggestion 6 - Add an RLS/grants snapshot artifact

Concrete changes:

- Save before/after RLS and grants snapshots to `docs/workspace/supabase-rls-grants-review.md`.
- Include generated tables for RLS enabled, RLS forced, `anon` grants, `authenticated` grants, and intentionally public reads.
- Link any corrective migration from the snapshot row it fixes.

Dependencies:

- Phase 5 audit SQL is executable against the intended Supabase project.

Affected surfaces:

- `docs/workspace/supabase-rls-grants-review.md`
- `TRR-Backend/scripts/db/`
- `TRR-Backend/supabase/migrations/`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
<rls-grants-snapshot-command> --output ../docs/workspace/supabase-rls-grants-review.md
```

Acceptance criteria:

- Snapshot captures current state without secrets.
- Every exposed schema table has an owner decision.
- Reviewers can compare before/after fixes in one file.

Commit boundary:

- One backend/docs commit for the snapshot script and initial artifact.

### Task S7: Source Suggestion 7 - Track prepared-statement compatibility explicitly

Concrete changes:

- Add a transaction-mode compatibility checklist to the Phase 8 experiment.
- Record whether the app/backend use prepared statements, session-local settings, transaction-local settings, advisory locks, temp tables, or connection-specific behavior.
- Add a test note for `withAuthTransaction` and transaction-local RLS settings.

Dependencies:

- Phase 8 is not run until Phases 0, 2, and 3 complete.

Affected surfaces:

- `docs/workspace/vercel-env-review.md`
- `TRR-APP/apps/web/src/lib/server/postgres.ts`
- app Postgres tests if a transaction-mode experiment branch is created

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c apps/web/vitest.config.ts apps/web/tests/postgres-connection-string-resolution.test.ts
```

Acceptance criteria:

- Transaction-mode decision has explicit prepared-statement/session-state evidence.
- Any rejection of transaction mode records the specific incompatibility.
- No production lane changes during the experiment.

Commit boundary:

- One experiment-doc/test commit, separate from any production env change.

### Task S8: Source Suggestion 8 - Add a production env redaction helper

Concrete changes:

- Add a helper that converts Vercel/Supabase env inventory into redacted shape-only output.
- Preserve variable names, presence/absence, lane classification, host class, port, and project context while removing values.
- Require the helper for `docs/workspace/vercel-env-review.md` updates.

Dependencies:

- Phase 1 env names and lane classifiers are stable.

Affected surfaces:

- workspace scripts
- `docs/workspace/vercel-env-review.md`
- env-contract tests

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
<env-redaction-helper-command> --check
```

Acceptance criteria:

- Output contains no raw secret values.
- Output is useful enough to distinguish session pooler, transaction pooler, direct/API, local, and absent values.
- Helper fails closed when it cannot classify a sensitive variable safely.

Commit boundary:

- One workspace tooling commit.

### Task S9: Source Suggestion 9 - Add an API migration ledger

Concrete changes:

- Add a ledger section or companion document that maps each migrated app direct-SQL caller to its backend API route, response contract, cacheability, auth context, and validation command.
- Update the ledger in the same commit as each direct-SQL migration slice.
- Link the ledger from `TRR Workspace Brain/api-contract.md` if stored elsewhere.

Dependencies:

- Phase 3 direct-SQL inventory exists.
- Phase 7 backend API route migration begins.

Affected surfaces:

- `TRR Workspace Brain/api-contract.md`
- optional `docs/workspace/api-migration-ledger.md`
- TRR-Backend route files
- TRR-APP proxy/repository clients

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "API migration ledger|app direct SQL|backend route" "TRR Workspace Brain/api-contract.md" docs/workspace || true
```

Acceptance criteria:

- Every migrated direct-SQL caller has a ledger row.
- Ledger names the backend route and app client that replaced it.
- Ledger includes auth/cache/error contract notes.

Commit boundary:

- One ledger update per API migration slice, in the same branch as the code change.

### Task S10: Source Suggestion 10 - Add a post-implementation cleanup checklist

Concrete changes:

- Add a cleanup checklist to the implementation PR or final verification notes.
- Include temporary Plan Grader artifacts, generated inventory snapshots, obsolete app migration files, old env aliases, and stale Vercel project references.
- Keep the cleanup checklist gated until implementation is fully verified.

Dependencies:

- All implementation phases that produce temporary artifacts.

Affected surfaces:

- implementation PR checklist or `docs/workspace/` completion note
- `.plan-grader/` package
- generated inventory/snapshot docs

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
```

Acceptance criteria:

- Cleanup is reviewed only after implementation verification passes.
- Evidence artifacts remain available while work is in progress.
- Temporary files are deleted or archived intentionally, not by blanket cleanup.

Commit boundary:

- One final cleanup/documentation commit after verification.

## Priority Order

1. Fix production observability access: advisors, env inventory, live `pg_stat_activity`.
2. Disambiguate Vercel project ownership.
3. Add `application_name` conventions and redacted env/project guard tooling so Phase 0 evidence stays safe and attributable.
4. Add Vercel pool attachment and enforce production pool/env checklist.
5. Add the direct-SQL inventory script, then inventory and reduce high-fan-out Vercel direct SQL behind backend APIs.
6. Remove app runtime DDL, finish migration ownership cleanup, and add the migration ownership linter.
7. Audit RLS/grants for exposed schemas and intentional public reads, with a durable snapshot artifact.
8. Add the admin connection budget dashboard card once the capacity budget fields are stable.
9. Add the API migration ledger as API-boundary work proceeds.
10. Test transaction mode only as an isolated experiment after the safer controls are in place, with prepared-statement/session-state evidence.
11. Finish with the post-implementation cleanup checklist after verification passes.

## Recommended Execution Shape

Use `orchestrate-subagents` for independent workstreams after Phase 0:

- Workstream A: env contract, Vercel ownership, and capacity docs.
- Workstream B: app pool attachment and app direct-SQL inventory.
- Workstream C: migration ownership cleanup and runtime DDL removal.
- Workstream D: RLS/grants/exposed schema audit.
- Workstream E: operator tooling and documentation additions from `ADDITIONAL SUGGESTIONS`.

Do not parallelize app/backend API migrations that touch the same route contract.

## Non-Goals

- Do not broaden app direct SQL just to avoid writing backend endpoints.
- Do not raise Supavisor pool size as the primary fix.
- Do not switch production to transaction mode without an explicit compatibility test pass.
- Do not move auth from Firebase to Supabase in this plan.
- Do not edit generated env docs by hand; update generator/source profiles and regenerate.
- Do not run production migrations through an ambiguous project, branch, or connection lane.

## Verification Checklist

- `make preflight` passes from `/Users/thomashulihan/Projects/TRR`.
- Supabase advisors have been captured or the permission blocker is documented.
- Production Vercel env inventory is documented without secret values.
- `pg_stat_activity` can attribute holders by `application_name`.
- Vercel app pool uses `attachDatabasePool`.
- No request-time DDL remains in app server repositories.
- App direct-SQL inventory has a current count and owner label for every caller.
- App direct-SQL high-fan-out count decreases after migration slices.
- RLS/grants review covers exposed schemas and intentional public reads.
- Backend/app API contract ledger is updated for moved surfaces.
- `application_name` conventions are documented and enforced where practical.
- Direct-SQL inventory can be regenerated with one command.
- Migration ownership linter prevents new shared-schema app migrations.
- Vercel project guard prevents env work against the wrong project.
- RLS/grants snapshot artifact exists and links any fixes.
- Transaction-mode experiment records prepared-statement and session-state compatibility.
- Production env review uses redacted shape-only output.
- API migration ledger maps migrated app callers to backend routes.
- Connection budget dashboard card renders non-secret holder budget state.
- Post-implementation cleanup checklist is completed only after verification.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
