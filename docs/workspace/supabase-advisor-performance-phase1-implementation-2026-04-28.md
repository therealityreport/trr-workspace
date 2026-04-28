# Supabase Advisor Performance Phase 1 Implementation - 2026-04-28

Status: live Phase 1 DDL deployed to `db.vwxfvzutyufrkhfgoeaa.supabase.co` on 2026-04-28 after a transaction dry-run passed. Post-deploy verifier passed. Supabase Advisor API recheck passed with `TRR_SUPABASE_ACCESS_TOKEN`.

Canonical plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`

Phase 0 evidence: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-phase0-evidence-2026-04-28.md`

Advisor recheck: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-recheck-2026-04-28.md`

## Artifacts Added

- Safety hotfix migration: `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql`
- RLS performance cleanup migration: `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql`
- RLS rollback SQL: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/db/advisor-performance/20260428111000_advisor_rls_policy_cleanup_rollback.sql`
- Post-deploy verifier: `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/verify_advisor_remediation_phase1.sql`
- SQL artifact tests: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_advisor_remediation_sql.py`

## Safety Hotfix Scope

- Enables RLS on `public.__migrations`.
- Revokes table privileges on `public.__migrations` from `public`, `anon`, and `authenticated`.
- Adds a restrictive deny policy for API-role access to `public.__migrations`.
- Skips the migration-ledger lock-down block safely when `public.__migrations` is absent in an environment.
- Revokes `EXECUTE` from `public`, `anon`, and `authenticated` on the eight exposed `SECURITY DEFINER` functions identified by the advisor snapshot.
- Grants those functions explicitly to `service_role`.

The `social.get_or_create_direct_conversation(uuid)` revoke is intentionally visible as a product-risk item because migration `0003_dms.sql` originally granted it to `authenticated`. Restore client access only through an explicitly reviewed backend-owned path or documented exception.

## RLS Cleanup Scope

- Replaces the seven broad service-role `FOR ALL` policies with command-specific `INSERT`, `UPDATE`, and `DELETE` service-role policies.
- Preserves the seven public read policies.
- Disables legacy Firebase survey app collection by dropping the Phase 0 `firebase_surveys.responses` and `firebase_surveys.answers` owner/admin policies without creating replacement `trr_app` policies.
- Leaves rollback SQL able to restore the exact Phase 0 Firebase survey policies by name if the legacy lane must be temporarily re-enabled.
- Leaves table grants unchanged.

Survey collection should use the Supabase-auth `surveys.*` path, specifically `surveys.submit_response(uuid, jsonb)`, rather than the legacy Firebase UID session-variable path.

## Dry-Run Evidence

The Phase 1 dry-run was executed against the configured remote DB inside an explicit transaction and ended with `ROLLBACK`.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
psql "$TRR_DB_DIRECT_URL" -v ON_ERROR_STOP=1 <<'SQL'
begin;
\i supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql
\i supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql
\i scripts/db/verify_advisor_remediation_phase1.sql
rollback;
SQL
```

Verifier result:

- safety migration applied inside transaction;
- RLS cleanup applied inside transaction;
- `scripts/db/verify_advisor_remediation_phase1.sql` passed;
- effective table privileges for `service_role` checked with `has_table_privilege(...)`;
- legacy Firebase survey app RLS policies verified disabled on `firebase_surveys.responses` and `firebase_surveys.answers`;
- expected post-change target policy count: 21;
- transaction rolled back.

Supabase survey path repair:

- Live schema had `surveys` tables and migration versions `0089`, `0090`, and `0092`, but `surveys.submit_response(uuid, jsonb)` was absent.
- Reapplied `TRR-Backend/supabase/migrations/0090_survey_submit_response_rpc.sql`, which recreated the RPC and grants.
- Verified `to_regprocedure('surveys.submit_response(uuid,jsonb)') is not null`.

## Live Deployment Evidence

Commands run against the direct TRR project host:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
psql "$TRR_DB_DIRECT_URL" -v ON_ERROR_STOP=1 -X -f supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql
psql "$TRR_DB_DIRECT_URL" -v ON_ERROR_STOP=1 -X -f supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql
psql "$TRR_DB_DIRECT_URL" -v ON_ERROR_STOP=1 -X -f scripts/db/verify_advisor_remediation_phase1.sql
```

Post-deploy verifier result: pass.

Post-deploy policy summary:

| Check | Result |
| --- | --- |
| target policy count | 28 |
| Firebase survey policy count | 0 |
| service-role write policy count | 21 |
| old Phase 0 policy count | 0 |
| `surveys.submit_response(uuid,jsonb)` present | true |
| `public.__migrations` RLS enabled | true |

Supabase Advisor API recheck:

| Advisor | Result |
| --- | --- |
| Performance Advisor API | HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`: after the approved Phase 3 pipeline-owner, admin-tooling, and flashback gameplay batches, only `unused_index=350` remains; total findings `350` |
| Security Advisor API | HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`: total findings `117` |

The generic `SUPABASE_ACCESS_TOKEN` belonged to a different Supabase account/project and returned HTTP 403 for TRR advisor endpoints. Non-interactive shells must source or export `TRR_SUPABASE_ACCESS_TOKEN`; do not use the generic token for TRR.

Advisor API responses were saved locally under `/tmp/trr-performance-advisor-20260428.json`, `/tmp/trr-performance-advisor-after-thb-bbl-drop-20260428.json`, `/tmp/trr-performance-advisor-phase4-complete-20260428.json`, `/tmp/trr-performance-advisor-after-phase3-pipeline-20260428.json`, `/tmp/trr-performance-advisor-after-phase3-admin-20260428.json`, `/tmp/trr-performance-advisor-after-phase3-flashback-gameplay-removal-20260428.json`, and `/tmp/trr-security-advisor-phase4-complete-20260428.json`.

Stray schema correction:

- The original advisor snapshot included non-TRR `thb_bbl` objects in the same Supabase project.
- A backup was written to `/tmp/trr-thb-bbl-drop-backup-20260428-002111.sql`.
- `drop schema if exists thb_bbl cascade;` was executed against the TRR project.
- Verification query returned `thb_bbl_schema_exists = false`.
- Follow-up Performance Advisor recheck dropped `unindexed_foreign_keys` from `17` to `0`.

Phase 4 singleton remediation:

- Applied `TRR-Backend/supabase/migrations/20260428112000_advisor_external_id_conflicts_primary_key.sql`.
- Verified `core.external_id_conflicts` has `external_id_conflicts_pkey` on `id`.
- Verified an insert that omits `id` receives a generated UUID; the smoke row was rolled back.
- Changed Supabase Auth DB allocation through the Management API from `10 connections` to `17 percent`, preserving the approximate allocation against `SHOW max_connections = 60`.
- Follow-up Performance Advisor recheck cleared both `no_primary_key` and `auth_db_connections_absolute`.

## Local Tests

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_advisor_remediation_sql.py tests/scripts/test_reconcile_runtime_db.py
```

Result: `15 passed`.

Expanded verification:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_advisor_remediation_sql.py tests/scripts/test_reconcile_runtime_db.py tests/db/test_connection_resolution.py tests/api/test_startup_validation.py
```

Result: `40 passed`.

Post-review validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/scripts/test_unused_index_evidence_report.py tests/db/test_advisor_remediation_sql.py
```

Result: `11 passed`.

Phase 4 closeout validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_advisor_remediation_sql.py tests/scripts/test_unused_index_evidence_report.py tests/scripts/test_reconcile_runtime_db.py tests/db/test_connection_resolution.py tests/api/test_startup_validation.py
```

Result: `49 passed in 2.18s`.

## Deployment Gates Still Open

- Live Phase 1 DDL is deployed and the post-deploy verifier passed.
- Supabase Performance/Security Advisor API rechecks succeeded after switching from generic `SUPABASE_ACCESS_TOKEN` to `TRR_SUPABASE_ACCESS_TOKEN`.
- Runtime reconcile has a pre-existing pending local migration `20260427140000`, so these advisor migrations are marked manual-only and must not be auto-applied by `make dev`.
- Phase 2 live unused-index evidence report was generated: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`.
- Owner review packets and the approved-only Phase 3 SQL gate were generated under `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/`.
- Phase 3 pipeline-owner batch dropped four approved indexes and rechecked Advisor: `unused_index=365`.
- Phase 3 admin-tooling batch dropped twelve approved indexes and rechecked Advisor: `unused_index=352`.
- Phase 3 flashback gameplay cleanup dropped two approved `public.flashback_sessions` indexes, then removed empty gameplay tables/RPC helpers after the first recheck surfaced a new FK-helper lint; backend migration `20260428113000_remove_flashback_gameplay_write_path.sql` preserves the removal; follow-up Advisor recheck reports `unused_index=350`.
- Phase 4 singleton findings are complete.
- Further Phase 3 index drops remain blocked until another owner packet has explicit approvals; the fresh live report has `258` `drop_review_required` rows.
