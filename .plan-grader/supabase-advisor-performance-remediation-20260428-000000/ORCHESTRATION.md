# ORCHESTRATION

Approved plan reference: `/Users/thomashulihan/Projects/TRR/.plan-grader/supabase-advisor-performance-remediation-20260428-000000/REVISED_PLAN.md`

Canonical execution plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`

## scope_statement

Implemented the `orchestrate-subagents` pass for the Supabase Advisor performance remediation plan. This pass covered local artifact inspection, scoped patching, targeted validation, approved live Phase 1 DDL, removal of a stray non-TRR schema from the TRR Supabase project, corrected live evidence reporting, Phase 4 singleton remediation, and the approved Phase 3 pipeline-owner, admin-tooling, and flashback gameplay batches.

## current_branch

`main`

## main_branch_verified

`true`

## worktree_or_branch_created

`false`

## execution_mode

`orchestrate-subagents`

## subagents_used

| Subagent | Scope | Result |
|---|---|---|
| Worker 1 | Safety hotfix DDL | Completed. No patch needed. Static inspection found the migration guards `public.__migrations`, revokes `public`/`anon`/`authenticated`, grants `service_role`, and contains no index/RLS cleanup work. |
| Worker 2 | RLS cleanup and rollback SQL | Completed. Later revised by main session to disable legacy Firebase survey app policies instead of preserving text Firebase UID semantics. Rollback still restores Phase 0 policies by name. |
| Worker 3 | Verifier SQL and artifact tests | Completed. Patched verifier/test artifacts. Targeted test passed: `5 passed in 0.03s`. |
| Worker 4 | Phase evidence and rollout docs | Completed. Patched docs/runbooks to clarify local-only vs live-deployed truth, post-deploy verifier, advisor token routing, and Phase 2/3 gates. |
| Reviewer | Integrated artifact review | Completed. Found two medium issues; both were fixed before handoff. |
| Phase 4 DB worker | `core.external_id_conflicts` primary key | Completed. Added migration, artifact tests, and schema docs for a defaulted surrogate `uuid` primary key. Main session applied it live and verified insert/default behavior. |
| Phase 4 Auth/capacity worker | Auth DB allocation docs | Completed doc-gate review. Main session then applied the Management API change with `TRR_SUPABASE_ACCESS_TOKEN` and reconciled docs to the live result. |

## ownership_scopes

- Safety hotfix DDL: `TRR-Backend/supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql`
- RLS cleanup/rollback: `TRR-Backend/supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql`, `TRR-Backend/docs/db/advisor-performance/20260428111000_advisor_rls_policy_cleanup_rollback.sql`
- Verifier/tests: `TRR-Backend/scripts/db/verify_advisor_remediation_phase1.sql`, `TRR-Backend/tests/db/test_advisor_remediation_sql.py`
- Evidence/runbooks: `docs/workspace/supabase-advisor-performance-phase0-evidence-2026-04-28.md`, `docs/workspace/supabase-advisor-performance-phase1-implementation-2026-04-28.md`, `TRR-Backend/docs/db/advisor-performance/20260428110000_20260428111000_phase1_rollout.md`
- Phase 2 evidence gate: `TRR-Backend/scripts/db/unused_index_evidence_report.py`, `TRR-Backend/tests/scripts/test_unused_index_evidence_report.py`, `docs/workspace/query-plan-evidence-runbook.md`
- Phase 4 external ID conflicts PK: `TRR-Backend/supabase/migrations/20260428112000_advisor_external_id_conflicts_primary_key.sql`, `TRR-Backend/tests/db/test_advisor_remediation_sql.py`, `TRR-Backend/supabase/schema_docs/core.external_id_conflicts.md`, `TRR-Backend/supabase/schema_docs/core.external_id_conflicts.json`, `TRR-Backend/supabase/schema_docs/diagrams/core.external_id_conflicts.mermaid.md`
- Phase 4 Auth allocation evidence: `docs/workspace/supabase-capacity-budget.md`, `docs/workspace/production-supabase-connection-inventory.md`

## reviewer_findings_resolved

1. Phase 2 unused-index evidence keyed migration provenance and recent-migration exclusions by bare index name. Fixed by keying migration sources and FK-hardening exclusions by exact `(schema, table, index)` identity and adding a duplicate-name regression test.
2. Phase 1 verifier lacked behavioral Firebase survey permission-matrix checks. User chose to disable the legacy Firebase survey collection lane instead; fixed by asserting no active app RLS policies remain on `firebase_surveys.responses` or `firebase_surveys.answers` and that `surveys.submit_response(uuid,jsonb)` exists.

## phase_status

- Phase 0 evidence: captured.
- Parallel safety hotfix gate: live migration deployed on 2026-04-28.
- Phase 1 RLS cleanup: live migration deployed on 2026-04-28; post-deploy verifier passed.
- Supabase survey path: `0090_survey_submit_response_rpc.sql` reapplied because the migration version was recorded but the RPC was missing; `surveys.submit_response(uuid,jsonb)` is now present.
- Stray non-TRR schema correction: `thb_bbl` backed up to `/tmp/trr-thb-bbl-drop-backup-20260428-002111.sql`, dropped from the TRR Supabase project, and verified absent.
- Phase 2 unused-index evidence gate: live report regenerated from the corrected schema.
- Phase 4 external ID conflicts primary key: live migration deployed on 2026-04-28 and verified.
- Phase 4 Auth DB allocation: changed from `10 connections` to `17 percent`; Advisor recheck cleared `auth_db_connections_absolute`.
- Phase 3+ index retirement: pipeline-owner, admin-tooling, and flashback gameplay batches completed; additional batches remain blocked until another owner packet has explicit approvals.

## files_changed

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/verify_advisor_remediation_phase1.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_advisor_remediation_sql.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/unused_index_evidence_report.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_unused_index_evidence_report.py`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-phase0-evidence-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-phase1-implementation-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/db/advisor-performance/20260428110000_20260428111000_phase1_rollout.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/supabase-advisor-performance-remediation-20260428-000000/ORCHESTRATION.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.csv`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/admin-tooling-owner.csv`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/admin-tooling-owner.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-admin-approved-drops.sql`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-admin-drop-evidence.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/survey-public-app-owner.csv`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/survey-public-app-owner.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-survey-public-approved-drops.sql`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-flashback-gameplay-removal.sql`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-flashback-drop-evidence.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-recheck-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428112000_advisor_external_id_conflicts_primary_key.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428113000_remove_flashback_gameplay_write_path.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/schema_docs/core.external_id_conflicts.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/schema_docs/core.external_id_conflicts.json`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/schema_docs/diagrams/core.external_id_conflicts.mermaid.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/dev/runtime_reconcile_migration_allowlist.txt`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/production-supabase-connection-inventory.md`

## validations_run

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/scripts/test_unused_index_evidence_report.py
python3 -m compileall -q scripts/db/unused_index_evidence_report.py
.venv/bin/python -m pytest -q tests/db/test_advisor_remediation_sql.py tests/scripts/test_unused_index_evidence_report.py tests/scripts/test_reconcile_runtime_db.py tests/db/test_connection_resolution.py tests/api/test_startup_validation.py
```

Results:

- `tests/scripts/test_unused_index_evidence_report.py`: `5 passed in 0.14s`
- Reviewer fix slice: `11 passed in 0.18s`
- Combined targeted suite after reviewer fixes: `46 passed in 3.04s`
- Combined targeted suite after Firebase disable revision: `46 passed in 1.58s`
- Combined targeted suite after Phase 4 closeout: `49 passed in 2.18s`
- Live Phase 1 transaction dry-run: pass, rolled back.
- Live Phase 1 deployment: pass.
- Post-deploy verifier: pass.
- Performance Advisor API recheck with `TRR_SUPABASE_ACCESS_TOKEN`: pass, HTTP 200, `auth_rls_initplan=0`, `multiple_permissive_policies=0`, `unused_index=415`, total findings `434`.
- Performance Advisor API recheck after stray schema removal: pass, HTTP 200, `auth_rls_initplan=0`, `multiple_permissive_policies=0`, `unindexed_foreign_keys=0`, `unused_index=369`, total findings `371`.
- Phase 4 external ID conflicts PK live migration: pass; `external_id_conflicts_pkey` exists and smoke insert generated `id`, then rolled back.
- Phase 4 Auth allocation change: pass; Auth config changed from `10 connections` to `17 percent`.
- Performance Advisor API recheck after Phase 4: pass, HTTP 200, only `unused_index=369` remains.
- Security Advisor API recheck with `TRR_SUPABASE_ACCESS_TOKEN`: pass, HTTP 200, total findings `117`.
- Initial Phase 2 live unused-index report after schema correction, Phase 4 completion, and fresh Advisor JSON input: `1324` rows, `277` `drop_review_required`, `0` `approved_to_drop`.
- Phase 2 owner-specific review packets generated under `docs/workspace/unused-index-owner-review-2026-04-28/`; the initial `277` candidates all had rollback SQL and started with `approved_to_drop=no`.
- Phase 3 approved-drop SQL gate generated `phase3-approved-drops.sql`; after pipeline-owner review it rendered and executed only the `4` explicitly approved pipeline drops.
- Pipeline owner packet reviewed and approved `4` indexes with rollback SQL, live stats, static route review, targeted tests, and live EXPLAIN evidence.
- Phase 3 pipeline-owner batch deployed: `4` `DROP INDEX CONCURRENTLY` statements executed and `to_regclass(...)` verified all four indexes absent.
- Performance Advisor API recheck after Phase 3 pipeline-owner batch: pass, HTTP 200, only `unused_index=365` remains.
- Phase 2 live unused-index report after Phase 3 pipeline-owner batch and fresh Advisor JSON input: `1320` rows, `273` `drop_review_required`, `0` `approved_to_drop` in the fresh report.
- Post-drop targeted backend validation: `106 passed in 1.53s`.
- Post-drop live EXPLAIN still uses `pipeline_runs_created_at_idx` for `pipeline.runs` list and `socialblade_growth_data_platform_account_handle_idx` for SocialBlade lookup.
- Admin-tooling packet reviewed and approved `12` indexes with rollback SQL, live stats, static route review, targeted tests, and live EXPLAIN evidence; `7` admin rows remain deferred.
- Phase 3 admin-tooling batch deployed: `12` `DROP INDEX CONCURRENTLY` statements executed and `to_regclass(...)` verified all twelve indexes absent.
- Performance Advisor API recheck after Phase 3 admin-tooling batch: pass, HTTP 200, only `unused_index=352` remains.
- Phase 2 live unused-index report after Phase 3 admin-tooling batch and fresh Advisor JSON input: `1308` rows, `260` `drop_review_required`, `0` `approved_to_drop` in the fresh report.
- Admin post-drop targeted backend validation: `250 passed in 68.12s`.
- Admin post-drop live EXPLAIN still uses retained brand target, network entity, cast tag, person-cover pkey, discovery-state pkey, and survey unique-prefix indexes for reviewed paths.
- Survey/public flashback gameplay packet reviewed and approved `2` indexes after owner direction to remove flashback gameplay for now; `37` survey/public rows remain deferred.
- Phase 3 flashback gameplay index batch deployed: `2` `DROP INDEX CONCURRENTLY` statements executed and `to_regclass(...)` verified both indexes absent.
- Follow-up DDL removed empty `public.flashback_sessions`, empty `public.flashback_user_stats`, and three flashback gameplay RPC helpers while retaining `public.flashback_quizzes` and `public.flashback_events`.
- Backend migration `20260428113000_remove_flashback_gameplay_write_path.sql` preserves the live flashback gameplay removal for future environments.
- Performance Advisor API recheck after flashback gameplay cleanup: pass, HTTP 200, only `unused_index=350` remains.
- Live read-only flashback verification: `public.flashback_quizzes` and `public.flashback_events` exist; `public.flashback_sessions`, `public.flashback_user_stats`, and `public.flashback_%` RPC helpers are absent; stray `thb_bbl` schema count is `0`.
- Phase 2 live unused-index report after flashback gameplay cleanup and fresh Advisor JSON input: `1302` rows, `258` `drop_review_required`, `0` `approved_to_drop` in the fresh report.
- Flashback post-cleanup targeted backend validation: `23 passed in 0.90s`; app validation: `14 passed in 1.64s`.
- `result.json` parses with `python3 -m json.tool`
- Scoped `git diff --check` completed cleanly
- `python3 scripts/migration-ownership-lint.py`: OK

## blocked_checks

- Generic `SUPABASE_ACCESS_TOKEN` is not valid for TRR advisor rechecks; use `TRR_SUPABASE_ACCESS_TOKEN` for project `vwxfvzutyufrkhfgoeaa`.
- Additional Phase 3 index drops remain blocked because no remaining owner packet row is approved to drop.

## remaining_risks

- The fresh live report has 258 remaining candidates requiring route-owner review and soak/recheck evidence before any additional drop batch.
- `social.get_or_create_direct_conversation(uuid)` is intentionally revoked from `authenticated`; restore client access only through a reviewed backend-owned path or documented exception.

## acceptance_check_tracking

- Main branch verified: pass.
- No branch/worktree created: pass.
- Disjoint subagent ownership scopes: pass.
- Live DDL from Codex: pass after explicit user direction.
- Phase 2 live report: pass.
- Phase 4 singleton remediation: pass.
- Phase 3 index drops: pipeline-owner, admin-tooling, and flashback gameplay batches completed; all additional batches blocked pending explicit approvals.
- Main-session targeted validation after integration: pass.

## ready_for_handoff

`true` for the next Phase 2 owner review handoff. `false` for additional Phase 3 execution until more rows are approved to drop.
