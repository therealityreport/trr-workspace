# Supabase RLS Plan: `pipeline.socialblade_growth_data`

Prepared: 2026-05-14

Status: planning package only. Do not apply DDL from this document without explicit approval.

## Scope

This is the first non-`screenalytics`, non-`ml` RLS migration candidate from `docs/workspace/supabase-security-posture-ledger.md`.

Included object:

- `pipeline.socialblade_growth_data`

Explicitly excluded:

- `pipeline.socialblade_growth_snapshots`
- `social.instagram_profile_following_snapshots`
- `social.instagram_profile_relationship_snapshot_items`
- all `ml` tables
- all `screenalytics` tables
- function `search_path` and security-definer findings

## Intended Posture

`pipeline.socialblade_growth_data` should be worker/backend-owned data.

- Browser clients should not read or write it directly through anon or authenticated Supabase clients.
- Admin UI reads should go through authenticated TRR admin routes and backend-owned internal routes.
- Worker, scraper, Modal, and backend refresh paths should keep read/write access.
- Public read is not approved for this table.

## Current Evidence

Live Supabase check on 2026-05-14:

- `pipeline.socialblade_growth_data`: RLS disabled, 21 rows.
- Supabase Advisor reports `rls_disabled` for `pipeline.socialblade_growth_data` at critical level.
- `pipeline.socialblade_growth_snapshots`: RLS enabled, 21 rows.
- No policies currently exist for either `pipeline.socialblade_growth_data` or `pipeline.socialblade_growth_snapshots`.
- Explicit `information_schema.table_privileges` rows observed for `pipeline.socialblade_growth_data` were only for `postgres`; do not treat that as sufficient protection because the Advisor still flags disabled RLS as critical.

Local caller inventory:

| Surface | Operation | Evidence |
| --- | --- | --- |
| Backend repository | table existence, `SELECT`, `INSERT ... ON CONFLICT DO UPDATE` | `TRR-Backend/trr_backend/repositories/socialblade_growth.py` |
| Backend admin person routes | admin read, refresh, batch refresh | `TRR-Backend/api/routers/admin_socialblade.py` |
| Backend social profile routes | admin read, profile refresh, landing SocialBlade row read | `TRR-Backend/api/routers/socials/__init__.py` |
| Backend scripts | seed import, saved-account backfill, ops smoke, index-advisor explain support | `TRR-Backend/scripts/socials/*`, `TRR-Backend/scripts/ops/socialblade_deployed_smoke.py`, `TRR-Backend/scripts/db/*` |
| App admin server code | backend-proxied progress-count read and backend-proxied cast-row read | `TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts` |
| App admin routes | SocialBlade person/profile reads and refreshes through TRR backend | `TRR-APP/apps/web/src/app/api/admin/trr-api/**/socialblade/**` |
| Existing migrations | table creation/generalization and snapshot sidecar | `TRR-Backend/supabase/migrations/0197_create_socialblade_growth_data.sql`, `0206_generalize_socialblade_growth_data.sql`, `20260513123000_socialblade_following_snapshots.sql` |

## DDL Gate

The original app-side direct progress-count blocker has been resolved.

Resolution:

- TRR-Backend now owns `POST /api/v1/admin/socials/landing-socialblade-progress-counts`.
- TRR-APP now calls `/landing-socialblade-progress-counts` through `fetchSocialBackendJson`.
- Current source search should find no `pipeline.socialblade_growth_data` references under `TRR-APP/apps/web/src`.

Before applying RLS, still complete the runtime-role preflight below. If TRR-Backend uses an owner or privileged database role such as `postgres`, RLS may not constrain that backend role even though browser/client roles are blocked.

## Preflight Checklist

1. Confirm runtime roles.
   - Capture `current_user`, `session_user`, and `application_name` for TRR-APP, TRR-Backend default pool, and TRR-Backend `social_profile` pool.
   - If runtime still uses `postgres`, document that table-owner/superuser behavior may bypass RLS. Prefer a least-privilege runtime role before treating RLS as complete protection.

2. Confirm current grants and policies.
   - Save current grants for `pipeline.socialblade_growth_data`.
   - Save current policies for `pipeline.socialblade_growth_data` and `pipeline.socialblade_growth_snapshots`.
   - Save current RLS state for both tables.

3. Confirm route behavior before migration.
   - Backend `GET /api/v1/admin/people/{person_id}/socialblade?handle={handle}` returns a known row.
   - Backend `POST /api/v1/admin/socials/landing-socialblade-rows` returns rows for the same known person or handle.
   - Backend `GET /api/v1/admin/socials/profiles/{platform}/{handle}/socialblade` returns a known row.
   - App `GET /api/admin/trr-api/people/{personId}/social-growth?handle={handle}` still reaches backend.
   - App Social landing loads without direct-query failure after the blocker is resolved.

4. Confirm worker/write behavior before migration.
   - Run repository tests for `get_growth_data`, `upsert_growth_data`, and freshness reuse.
   - Run SocialBlade service tests covering refresh persistence.
   - Prefer rollback-safe fixture writes in a transaction; do not force a live SocialBlade scrape just to validate RLS.

## Role Probes

Use a rollback-safe transaction or isolated fixture row. If SQL `SET ROLE` is unavailable through the selected connection, run equivalent PostgREST probes with anon, authenticated, and service-role credentials without printing secrets.

Live probe results captured on 2026-05-14:

| Role | `SELECT` | `INSERT` | `UPDATE` | `DELETE` | Current blocker |
| --- | --- | --- | --- | --- | --- |
| `anon` | denied | denied | denied | denied | `42501: permission denied for schema pipeline` |
| `authenticated` | denied | denied | denied | denied | `42501: permission denied for schema pipeline` |
| `service_role` | denied | denied | denied | denied | `42501: permission denied for table socialblade_growth_data` |

The probe used rollback-safe transactions and isolated fixture handles; no persistent fixture rows or DDL were applied. Because `service_role` is currently blocked at table access, the forward migration must grant `usage` on schema `pipeline` and table-level read/write privileges before the service-role policy can validate the intended backend/worker posture. Do not grant `anon` or `authenticated` access.

Expected results:

| Role | `SELECT` | `INSERT` | `UPDATE` | `DELETE` |
| --- | --- | --- | --- | --- |
| `anon` | denied | denied | denied | denied |
| `authenticated` | denied | denied | denied | denied |
| `service_role` | allowed | allowed | allowed | allowed |
| approved backend runtime role | allowed only if explicitly documented | allowed only if explicitly documented | allowed only if explicitly documented | allowed only if explicitly documented |

Probe SQL shape:

```sql
begin;
set local role anon;
select count(*) from pipeline.socialblade_growth_data;
rollback;

begin;
set local role authenticated;
select count(*) from pipeline.socialblade_growth_data;
rollback;

begin;
set local role service_role;
select count(*) from pipeline.socialblade_growth_data;
rollback;
```

Add write probes with an isolated handle such as `rls_probe_do_not_use` and roll the transaction back.

## Draft Forward SQL Shape

This is the intended shape, not an approved migration.

```sql
begin;

grant usage on schema pipeline to service_role;

grant select, insert, update, delete
  on table pipeline.socialblade_growth_data
  to service_role;

revoke all on table pipeline.socialblade_growth_data
  from public, anon, authenticated;

alter table pipeline.socialblade_growth_data enable row level security;

drop policy if exists socialblade_growth_data_service_role_all
  on pipeline.socialblade_growth_data;

create policy socialblade_growth_data_service_role_all
  on pipeline.socialblade_growth_data
  as permissive
  for all
  to service_role
  using (true)
  with check (true);

commit;
```

Notes:

- If the runtime direct-SQL role is not `service_role`, add no policy for it until the role is named and approved.
- If the runtime role is `postgres`, RLS alone is not sufficient as an access-control boundary for that runtime.
- The live role probe showed `service_role` lacks table access and needs the schema/table grants above.
- Do not add `anon`, `authenticated`, or public read policies for this table.
- Do not bundle snapshot-table or function-finding fixes into this migration.

## Rollback SQL Shape

Capture current grants first, then replace the grant restoration comments below with the captured state.

```sql
begin;

drop policy if exists socialblade_growth_data_service_role_all
  on pipeline.socialblade_growth_data;

-- Restore grants captured during preflight, if any were removed.
-- Example only:
-- grant select on table pipeline.socialblade_growth_data to <captured_role>;
-- revoke usage on schema pipeline from service_role only if preflight proves
-- this migration added it solely for this table and no approved pipeline access depends on it.

alter table pipeline.socialblade_growth_data disable row level security;

commit;
```

Rollback decision: disabling RLS is acceptable only as an emergency restoration to the current posture. A forward-fix migration that restores intended backend-only access is preferred once route behavior is stable.

## Validation Commands

App validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run -c vitest.config.mts tests/social-landing-repository.test.ts
pnpm -C apps/web exec vitest run -c vitest.config.mts tests/social-growth-refresh-route.test.ts tests/social-growth-batch-route.test.ts
```

Backend validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. .venv/bin/python -m pytest -q \
  tests/repositories/test_socialblade_growth.py \
  tests/socials/test_socialblade_service.py \
  tests/api/test_admin_socialblade.py
```

Database validation:

```sql
select n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'pipeline'
  and c.relname in ('socialblade_growth_data', 'socialblade_growth_snapshots')
order by c.relname;

select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'pipeline'
  and tablename in ('socialblade_growth_data', 'socialblade_growth_snapshots')
order by tablename, policyname;
```

After migration:

- Rerun the role probes.
- Rerun the route checks.
- Rerun Supabase Security Advisor.
- Update `docs/workspace/supabase-security-posture-ledger.md` with the final posture, applied migration file, and any deferred follow-up.

## First Implementation Slice

Completed first implementation slice before DDL:

1. Moved the remaining TRR-APP social landing progress-count read for `pipeline.socialblade_growth_data` behind a backend internal-admin endpoint.
2. Added tests proving the app progress SQL no longer queries this table.

Remaining implementation slice:

1. Re-run the caller inventory and role probes.
2. Write a single backend migration for `pipeline.socialblade_growth_data` only.
3. Apply only after explicit owner approval.
