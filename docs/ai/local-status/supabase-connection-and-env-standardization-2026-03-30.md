# Supabase connection and env standardization

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-30
  current_phase: "complete"
  next_action: "Resume downstream survey compatibility work against the standardized env contract; keep intentional compatibility-only fallbacks and reviewed integration-managed retained envs as documented exceptions."
  detail: self
```

## Summary

- Standardized the remaining active Supabase/Postgres env guidance so canonical names are consistent across backend docs, screenalytics deployment planning, app survey/Postgres setup docs, SQL helper comments, and generated governance reports.
- Kept the canonical ownership model unchanged:
  - runtime Postgres: `TRR_DB_URL`, optional `TRR_DB_FALLBACK_URL`
  - backend base: `TRR_API_URL`
  - app browser Supabase: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - app server/admin Supabase: `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
  - backend Supabase API/auth: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`
- Tightened `scripts/env_contract_report.py` so it now separates:
  - `active drift`
  - `compatibility-only`
  - `historical/docs`
- The validator now fails only on real active drift and ignores archived history, reviewed Vercel retained envs, generated stale OpenAPI artifacts, and explicit compatibility fallbacks/tests.

## Files And Surfaces Updated

- Reporting and generated governance:
  - `scripts/env_contract_report.py`
  - `docs/workspace/env-contract-inventory.md`
  - `docs/workspace/env-deprecations.md`
- Backend active docs/operator surfaces:
  - `TRR-Backend/docs/api/run.md`
  - `TRR-Backend/docs/db/commands.md`
  - `TRR-Backend/docs/runbooks/postgrest_schema_cache.md`
  - `TRR-Backend/docs/runbooks/rhoslc-show-admin-backfill.md`
  - `TRR-Backend/docs/runbooks/supabase_migration_history_repair.md`
  - `TRR-Backend/docs/cloud/quick_cloud_setup.md`
  - `TRR-Backend/scripts/README.md`
  - `TRR-Backend/scripts/db/README.md`
  - `TRR-Backend/scripts/db/guard_core_schema.sql`
  - `TRR-Backend/scripts/db/reload_postgrest_schema.sql`
  - `TRR-Backend/scripts/reload_postgrest_schema.sql`
  - `TRR-Backend/scripts/db/verify_pre_0033_cleanup.sql`
- App and screenalytics docs/generated artifacts:
  - `TRR-APP/apps/web/POSTGRES_SETUP.md`
  - `screenalytics/docs/plans/in_progress/infra/screenalytics_deploy_plan.md`
  - regenerated `screenalytics/web/openapi.json`
  - regenerated `screenalytics/web/api/schema.ts`

## Remaining Intentional Exceptions

- Backend compatibility fallbacks:
  - `TRR-Backend/trr_backend/db/connection.py`
  - `TRR-Backend/scripts/_db_url.py`
  - `TRR-Backend/scripts/db/run_sql.sh`
- Tooling-only `DATABASE_URL` consumers:
  - `TRR-APP/apps/web/scripts/run-migrations.mjs`
  - related one-off survey/import scripts in `TRR-APP/apps/web/scripts/`
- Reviewed integration-managed retained envs:
  - `docs/workspace/vercel-env-review.md` remains the source of truth for active `trr-app` retained `DATABASE_URL`, `POSTGRES_*`, and `SUPABASE_*` integration-managed values

## Validation

- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/db/test_connection_resolution.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/postgres-connection-string-resolution.test.ts`
- `cd /Users/thomashulihan/Projects/TRR/screenalytics && pytest -q tests/unit/test_supabase_db.py tests/api/test_trr_health.py tests/unit/test_startup_config.py`
- `cd /Users/thomashulihan/Projects/TRR && python3 scripts/env_contract_report.py write`
- `cd /Users/thomashulihan/Projects/TRR && python3 scripts/env_contract_report.py validate`
- `cd /Users/thomashulihan/Projects/TRR && ./scripts/preflight.sh`

## Result

- Active runtime and operator-facing docs now prefer canonical `TRR_*` and `TRR_CORE_*` env names.
- Deprecated names are constrained to compatibility-only code paths, tooling-only commands, reviewed live-env exceptions, and historical/archive records.
- Generated governance artifacts are current and the workspace preflight gate now catches future active env-contract drift without blocking on intentional exceptions.
