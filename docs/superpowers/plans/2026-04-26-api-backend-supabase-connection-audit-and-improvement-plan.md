# TRR API/Backend/Supabase Connection Audit And Improvement Plan

Date: 2026-04-26

## Goal

Audit the local development and production-facing Supabase/API/backend connection posture, decide where the current implementation matches best practice, and define the remaining improvement plan for TRR-APP on Vercel, TRR-Backend, local `make dev`, migrations, auth, and Supabase operations.

This plan is broader than the existing Supavisor stabilization plan. That plan focuses on session-pool saturation. This plan covers all connection surfaces and ownership boundaries.

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

I inspected the local env files without printing secret values.

| Surface | Canonical runtime DB env | Current class | Notes |
|---|---|---|---|
| `TRR-APP/apps/web/.env.local` | `TRR_DB_URL` | Supavisor session mode `pooler.supabase.com:5432` | Also still contains legacy `DATABASE_URL` and `SUPABASE_DB_URL` aliases pointing at the same session lane. |
| `TRR-Backend/.env` | `TRR_DB_URL` | Supavisor session mode `pooler.supabase.com:5432` | Also still contains deprecated `SUPABASE_DB_URL`; `DATABASE_URL` is absent. |
| TRR Supabase MCP binding | `.codex/config.toml` | project `vwxfvzutyufrkhfgoeaa` | MCP advisory/migration/storage reads are currently blocked by permission. |
| Vercel production app | `trr-app` project | latest deployment `READY`, target `production`, region `iad1` | Vercel MCP confirms deployment metadata, but does not expose env values here. |

### What Already Looks Good

- Runtime DB names are mostly standardized on `TRR_DB_URL` and optional `TRR_DB_FALLBACK_URL`. `TRR-APP` runtime code explicitly does not use `DATABASE_URL` or `SUPABASE_DB_URL` for request handling.
- Both app and backend classify connection lanes and reject direct/transaction/unknown runtime lanes where the local contract expects session mode.
- Local `make dev` now projects conservative pool defaults: app pool `1`, backend default `2`, social profile `4`, social control `2`, health `1`, for a projected local holder budget of `10`.
- Backend has separate named psycopg2 pools for `default`, `social_profile`, `social_control`, and `health`, plus safe DB pressure endpoints.
- App Postgres helper sets `application_name`, caps pool/concurrent operations, logs pool init/queue/retry events, pins transaction-local `search_path`, and uses transaction-local auth settings for RLS-sensitive flows.
- Supabase JS in TRR-APP is intentionally isolated to auth/token verification, not general data access.
- Backend-owned Supabase migrations are under `TRR-Backend/supabase/migrations`, and local startup has a bounded, allowlisted runtime reconcile path.

### Main Remaining Risks

1. Vercel app functions still own direct `pg` pools for many admin/app reads and writes. Even with low caps, Vercel can multiply pool holders across warm function instances.
2. The app production lane uses Supavisor session mode. Supabase docs say transaction mode is the natural fit for temporary/serverless clients, while session mode is mainly the IPv4 alternative to direct connections for persistent clients. TRR can keep session mode only if pool caps and instance/concurrency limits are enforced and measured.
3. The app repo still contains backend-owned/shared-schema migration backlog and runtime bootstrap DDL in application code.
4. Deprecated aliases remain in local env files and standalone scripts (`DATABASE_URL`, `SUPABASE_DB_URL`). Runtime ignores them in the main helpers, but their presence keeps operator drift likely.
5. Production Supabase capacity is not fully auditable from this session because Supabase MCP advisor/migration/storage reads returned permission errors.
6. The local Supabase CLI config exposes `core` and `admin` through PostgREST locally. That may be fine for dev/admin, but exposed schemas require explicit RLS/grant review, especially where migrations grant `anon` reads.
7. Vercel project discovery shows two linked projects: `trr-app` is production-ready, while nested `apps/web` project `web` has latest deployment in `ERROR`. That second Vercel project can confuse env/deployment ownership if left connected.

## Best-Practice Verdict

TRR is partially aligned with Supabase best practices and has already corrected the biggest local-dev failure mode: unbounded session-pool pressure.

The current approach is acceptable for local dev if the holder budget guardrail stays enforced and all DB-heavy local modes are opt-in. It is more fragile in Vercel production because session-mode poolers plus serverless fan-out can still exhaust Supavisor. The durable best-practice direction is:

- keep persistent backend/API services on direct connection where IPv6 or IPv4 add-on supports it, or session pooler where direct is unavailable;
- move Vercel app direct SQL behind backend-owned APIs where practical;
- for remaining Vercel direct SQL, either prove session mode is safe with low concurrency and Vercel function pool attachment, or test a transaction-mode lane with prepared-statement compatibility explicitly handled;
- keep migrations and shared schema backend-owned;
- run Supabase advisors and live `pg_stat_activity` snapshots before any production capacity change.

## Implementation Plan

### Phase 0: Capture Production Truth Before Changing Capacity

Owner: workspace/backend operator

Files:

- `docs/workspace/supabase-capacity-budget.md`
- optionally `docs/workspace/production-supabase-connection-inventory.md`

Tasks:

- Run Supabase security and performance advisors once permissions are fixed.
- Capture `pg_stat_activity` grouped by `application_name`, `usename`, `client_addr`, and `state`.
- Record current Supavisor pool size, Postgres `max_connections`, active internal/service usage, and Vercel production deployment settings.
- Confirm whether Vercel production env has only `TRR_DB_URL`/`TRR_DB_FALLBACK_URL`, or still also has legacy `DATABASE_URL`/`SUPABASE_DB_URL`.
- Decide whether the stale/nested Vercel `web` project should be unlinked or kept as an explicit preview-only project.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make status
```

Manual evidence:

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

### Phase 1: Clean Env Contract And Remove Drift Sources

Owner: workspace

Files:

- `TRR-APP/apps/web/.env.example`
- `TRR-Backend/.env.example`
- `scripts/lib/runtime-db-env.sh`
- `scripts/dev-workspace.sh`
- `scripts/check-workspace-contract.sh`
- `docs/workspace/env-contract.md`
- `docs/workspace/env-deprecations.md`

Tasks:

- Make `TRR_DB_URL` and `TRR_DB_FALLBACK_URL` the only runtime DB variables in docs and generated contracts.
- Keep `DATABASE_URL` compatibility only in explicitly named tooling scripts.
- Add a preflight warning when `.env.local` or `.env` contains legacy aliases equal to the canonical runtime URL.
- Add a stricter production/deploy preflight that fails if Vercel production uses `DATABASE_URL` or `SUPABASE_DB_URL` as the app runtime source.
- Preserve `DATABASE_URL` only for third-party tools that demand that exact name, and require scripts to label it as tooling-only.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make preflight
python3 -m pytest scripts/test_runtime_db_env.py scripts/test_workspace_app_env_projection.py
```

### Phase 2: Harden Vercel App Database Pool Handling

Owner: TRR-APP

Files:

- `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `TRR-APP/apps/web/package.json`
- `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- `TRR-APP/apps/web/tests/admin-app-db-pressure-route.test.ts`

Tasks:

- Add `@vercel/functions` and call `attachDatabasePool(pool)` immediately after creating the `pg.Pool` when running on Vercel.
- Keep `POSTGRES_POOL_MAX=1` for preview and local; keep production at `2` only if live capacity math proves it is safe.
- Add structured logs for `VERCEL_ENV`, selected connection class, pool cap, active permit count, and queue depth at pool init.
- Add a test proving invalid `POSTGRES_APPLICATION_NAME` values are sanitized.
- Add a test proving Vercel runtime still rejects direct and transaction lanes unless an explicit future transaction-mode flag is introduced.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c apps/web/vitest.config.ts apps/web/tests/postgres-connection-string-resolution.test.ts apps/web/tests/admin-app-db-pressure-route.test.ts
pnpm -C apps/web run typecheck
```

### Phase 3: Decide Vercel Direct-SQL Strategy

Owner: workspace plus TRR-APP/TRR-Backend

Decision options:

| Option | Description | Recommendation |
|---|---|---|
| A | Keep Vercel app direct SQL on session pooler with strict pool caps. | Accept as short-term only. Requires live evidence and Vercel pool attachment. |
| B | Move most direct SQL from Vercel app into backend APIs. | Preferred durable path. Reduces serverless DB holder multiplication. |
| C | Move app direct SQL to Supavisor transaction mode. | Evaluate only after proving `pg` usage has no prepared-statement/session-state conflicts. |

Tasks:

- Inventory all `TRR-APP/apps/web/src/lib/server/**` imports of `query`, `withTransaction`, `withAuthTransaction`, and `queryWithAuth`.
- Classify each as app-local-only, shared/backend-owned, or admin read-model candidate.
- Move high-fan-out read paths first: social landing, profile snapshots, Reddit summaries, media asset detail reads, cast/photo freshness reads.
- Keep low-volume legacy survey editor writes app-local until their tables are ported.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
rg -n "from \"@/lib/server/postgres\"|from '@/lib/server/postgres'" apps/web/src/lib/server apps/web/src/app/api
```

Success criterion: the count decreases each phase, and remaining direct SQL has an explicit owner label in `POSTGRES_SETUP.md`.

### Phase 4: Finish Migration Ownership Cleanup

Owner: backend first, app follow-through

Files:

- `TRR-Backend/supabase/migrations/`
- `TRR-APP/apps/web/db/migrations/`
- `TRR-APP/apps/web/POSTGRES_SETUP.md`
- `TRR-APP/apps/web/scripts/run-migrations.mjs`
- `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`
- `TRR-APP/apps/web/src/lib/server/admin/typography-repository.ts`

Tasks:

- Port shared-schema files listed in `POSTGRES_SETUP.md` from app migrations into backend-owned Supabase migrations.
- Remove or quarantine those app migration files after backend parity is proven.
- Convert app runtime bootstrap DDL into migrations:
  - `survey_shows` columns and palette library objects.
  - `site_typography_sets`, `site_typography_assignments`, and triggers.
- Add a test that app route handlers cannot execute DDL during request handling.
- Keep app migration runner app-local only.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
supabase db push --db-url "$TRR_DB_URL" --include-all
pytest tests/db tests/api

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run db:migrate -- --dry-run
```

### Phase 5: RLS, Grants, And Exposed Schema Review

Owner: backend

Files:

- `TRR-Backend/supabase/config.toml`
- `TRR-Backend/supabase/migrations/`
- new audit SQL under `TRR-Backend/scripts/db/`

Tasks:

- Review exposed local API schemas: `public`, `graphql_public`, `core`, `admin`.
- Generate a table-policy inventory for exposed schemas:
  - table has RLS enabled?
  - grants to `anon`?
  - grants to `authenticated`?
  - grants to `service_role` only?
- Decide whether `admin` should be exposed via PostgREST locally at all, or kept backend-service-only.
- Ensure all raw SQL-created tables in exposed schemas either have RLS enabled or are intentionally excluded from API exposure.
- Document which public read policies are product-intentional.

Validation SQL:

```sql
SELECT
  schemaname,
  tablename,
  rowsecurity,
  hasrls
FROM pg_tables
WHERE schemaname IN ('public', 'core', 'admin', 'firebase_surveys', 'social')
ORDER BY schemaname, tablename;
```

### Phase 6: Production Capacity And Deployment Controls

Owner: workspace plus deployment owner

Files:

- `docs/workspace/supabase-capacity-budget.md`
- `docs/workspace/vercel-env-review.md`
- Vercel project settings
- Supabase dashboard/settings

Tasks:

- Fill the production capacity table in `supabase-capacity-budget.md`.
- Add Vercel production env checklist:
  - `TRR_DB_URL` is session pooler `:5432` unless a future transaction lane is approved.
  - `POSTGRES_POOL_MAX` is set intentionally.
  - `POSTGRES_MAX_CONCURRENT_OPERATIONS=1`.
  - `POSTGRES_APPLICATION_NAME` is a non-secret lane label.
  - legacy aliases are absent or explicitly tooling-only.
- Confirm Vercel production project is `trr-app`, not nested `web`.
- Confirm backend production platform and instance/worker counts, then include those in Supabase holder math.
- Keep Supavisor pool-size changes separate from code deploys and record rollback targets.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
vercel env ls production
vercel env ls preview
```

Do not print secret values in logs or docs.

### Phase 7: API Boundary Consolidation

Owner: backend first, app follow-through

Files:

- `TRR-Backend/api/routers/`
- `TRR-Backend/trr_backend/repositories/`
- `TRR-APP/apps/web/src/lib/server/trr-api/`
- `TRR-APP/apps/web/src/lib/server/admin/`
- `TRR Workspace Brain/api-contract.md`

Tasks:

- Treat TRR-Backend as owner of shared schema read models and admin write commands.
- For each migrated app direct-SQL surface, add or extend a backend API route and app proxy/repository client.
- Preserve app route cache/in-flight dedupe where it reduces browser fan-out.
- Update `api-contract.md` for every app/backend contract change in the same session.
- Keep backend routes additive until app consumers are migrated.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c apps/web/vitest.config.ts apps/web/tests
```

## Priority Order

1. Fix Supabase/Vercel production observability access: advisors, env inventory, live `pg_stat_activity`.
2. Add Vercel pool attachment and enforce production pool/env checklist.
3. Remove app runtime DDL and finish migration ownership cleanup.
4. Move high-fan-out Vercel direct SQL behind backend APIs.
5. Audit RLS/grants for exposed schemas and intentional public reads.
6. Clean deprecated env aliases from local files and standalone scripts.
7. Decide whether transaction-mode is worth testing for any remaining Vercel direct SQL.

## Non-Goals

- Do not broaden app direct SQL just to avoid writing backend endpoints.
- Do not raise Supavisor pool size as the primary fix.
- Do not switch to transaction mode without an explicit compatibility test pass.
- Do not move auth from Firebase to Supabase in this plan.
- Do not edit generated env docs by hand; update the generator/source profiles and regenerate.

## Verification Checklist

- `make preflight` passes from `/Users/thomashulihan/Projects/TRR`.
- Supabase advisors have been captured or the permission blocker is documented.
- Production Vercel env inventory is documented without secret values.
- `pg_stat_activity` can attribute holders by `application_name`.
- Vercel app pool uses `attachDatabasePool`.
- No request-time DDL remains in app server repositories.
- App direct SQL inventory is smaller and every remaining caller has an owner label.
- Backend/app API contract ledger is updated for moved surfaces.
