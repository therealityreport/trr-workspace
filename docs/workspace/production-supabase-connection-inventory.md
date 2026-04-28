# Production Supabase Connection Inventory

Last reviewed: 2026-04-28

This is the Phase 0 evidence ledger for API/backend/Supabase connection work.
Do not put secret values in this file.

Status labels in this file are intentionally explicit:

- `verified`: checked against repo files or local command output in this pass.
- `blocked`: could not be checked because required Dashboard/MCP access was unavailable.
- `pending`: must be captured from production before mutation.
- `sandbox/stale`: known non-production surface; commands must fail for production work.

## Evidence Status

| Evidence | Status | Notes |
|---|---|---|
| Supabase security advisor | verified | Management API advisor read passed with `TRR_SUPABASE_ACCESS_TOKEN` on 2026-04-28. Current total: `117`. See `docs/workspace/supabase-advisor-recheck-2026-04-28.md`. |
| Supabase performance advisor | verified | Management API advisor read passed with `TRR_SUPABASE_ACCESS_TOKEN` on 2026-04-28. Current total after the approved Phase 3 pipeline-owner batch: `365`, all `unused_index`. See `docs/workspace/supabase-advisor-recheck-2026-04-28.md`. |
| Auth DB allocation config | verified | Phase 4 changed Auth DB allocation from `10 connections` to `17 percent` through the Management API with `TRR_SUPABASE_ACCESS_TOKEN`; this preserves the approximate allocation against `SHOW max_connections = 60` and clears `auth_db_connections_absolute`. Rollback target: `10 connections`. |
| Supabase migration/storage/edge inventory | blocked | Supabase MCP migration, storage, and edge-function reads returned permission errors in the audit and implementation sessions. |
| Dashboard evidence checklist | verified | Use `docs/workspace/supabase-dashboard-evidence-template.md`; current dated placeholder is `docs/workspace/supabase-advisor-snapshot-2026-04-27.md`. |
| `pg_stat_activity` holder snapshot | pending | Capture with the query in `docs/workspace/supabase-capacity-budget.md` before any production capacity change. |
| Vercel project of record | verified | `TRR-APP/.vercel/project.json` -> `trr-app` / `prj_MHpStkwr26rV5kjt0f80zqhwZpAs`; guard passed on 2026-04-27. |
| Nested Vercel project | sandbox/stale | `TRR-APP/apps/web/.vercel/project.json` -> `web` / `prj_0nWn8xpm9ikhcvhzE3ma4jUXTe1p`; guard must fail and block production env mutation. |
| Production env shape | verified | `docs/workspace/vercel-env-review.md` records historical retained integration-variable review. Re-run redacted inventory before mutation. |

## Production Runtime Review

| Surface | Status | Evidence / next action |
|---|---|---|
| Active Vercel project ID | verified | `python3 scripts/vercel-project-guard.py --project-dir TRR-APP` returned OK for `trr-app` / `prj_MHpStkwr26rV5kjt0f80zqhwZpAs` on 2026-04-27. |
| Nested Vercel project guard | sandbox/stale | `python3 scripts/vercel-project-guard.py --project-dir TRR-APP/apps/web` returned non-zero and classified `sandbox/stale-nested-project` on 2026-04-27. |
| App DB URL source order | verified repo contract | App runtime resolves `TRR_DB_SESSION_URL`, then `TRR_DB_URL`, then `TRR_DB_FALLBACK_URL`; `TRR_DB_TRANSACTION_URL` is gated by `TRR_DB_TRANSACTION_FLIGHT_TEST=1`. |
| Deprecated DB alias primary runtime use | verified absent from app DB resolver | Current app DB resolver tests confirm runtime does not use deprecated DB aliases. See `docs/workspace/env-deprecations.md` for the reviewed compatibility-only names. |
| Vercel `attachDatabasePool` status | verified repo contract, pending production observation | App pool attaches when Vercel runtime markers are present and exposes `vercel_pool_attached` in the app DB pressure snapshot. Confirm from production logs or protected admin endpoint before deploy claims. |
| App direct-SQL callers still present | pending current inventory | Run `python3 scripts/app-direct-sql-inventory.py --check`; the migration ledger owns remaining exceptions. |
| Production Auth DB allocation | verified | Phase 4 completed on 2026-04-28: `db_max_pool_size=17`, `db_max_pool_size_unit=percent`; rollback target is `10 connections`. Do not persist full Auth config responses. |
| Production Auth/Storage/SMTP posture | blocked/pending | Requires Supabase Dashboard evidence. Use `docs/workspace/supabase-dashboard-evidence-template.md`; do not paste secrets. |

## No-Write Gate

No production env changes, Supavisor pool changes, transaction-mode changes,
Vercel project relinking, or remote migration application should happen until:

- advisors are captured with `TRR_SUPABASE_ACCESS_TOKEN` or a fresh permission blocker is accepted with a fallback;
- `pg_stat_activity` holders are grouped by `application_name`;
- `docs/workspace/supabase-capacity-budget.md` production fields are verified
  or carry explicit pending/blocked owner notes;
- Auth DB allocation current value and unit are captured through the
  Management API with `TRR_SUPABASE_ACCESS_TOKEN` before any future Auth
  allocation change;
- `scripts/vercel-project-guard.py --project-dir TRR-APP` passes;
- redacted env output is saved without secret values.

## Commands

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/vercel-project-guard.py --project-dir TRR-APP
python3 scripts/vercel-project-guard.py --project-dir TRR-APP/apps/web # expected non-zero sandbox/stale block
python3 scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md
```

Dashboard-only evidence should use:

```bash
cp docs/workspace/supabase-dashboard-evidence-template.md docs/workspace/supabase-advisor-snapshot-YYYY-MM-DD.md
```

Then fill statuses and shape-only values manually from Supabase Dashboard.

Auth DB allocation evidence should use the Management API only when the TRR
token is available. Capture the narrow fields below and discard the full Auth
config response because it can contain provider, SMTP, hook, and SMS secrets:

```bash
curl -sS "https://api.supabase.com/v1/projects/vwxfvzutyufrkhfgoeaa/config/auth" \
  -H "Authorization: Bearer $TRR_SUPABASE_ACCESS_TOKEN" \
  | jq '{db_max_pool_size, db_max_pool_size_unit}'
```

The installed Supabase CLI checked on 2026-04-28 was `2.84.2`; it exposes
`supabase config push` but no granular Auth config get/update command for this
setting. Do not use CLI config push as the Phase 4 mutation path.

## Holder Query

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

## Rollback Targets

Record before production changes:

| Change | Rollback target | Owner | Time to rollback |
|---|---|---|---|
| Vercel env change | pending | pending | pending |
| Supavisor pool-size change | current production pool size, captured before change | pending | pending |
| Auth DB allocation change | current `db_max_pool_size` and `db_max_pool_size_unit`, captured before change | pending | pending |
| Transaction-mode experiment | `TRR_DB_RUNTIME_LANE=session` and session-mode `TRR_DB_SESSION_URL`/`TRR_DB_URL` | pending | pending |
| Remote migration | forward-fix migration or restore point | pending | pending |
