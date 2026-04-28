# VALIDATION

## files inspected

- `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/SKILL.md`
- `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/skills/revise-plan/SKILL.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/supabase-advisor-performance-remediation-20260428-000000/REVISED_PLAN.md`
- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-snapshot-2026-04-27.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-phase0-evidence-2026-04-28.md`
- `/Users/thomashulihan/.codex/skills/orchestrate-subagents/SKILL.md`
- `/Users/thomashulihan/.codex/skills/write-plan/SKILL.md`

## commands run

```bash
sed -n '1,260p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/skills/revise-plan/SKILL.md
sed -n '1,280p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/SKILL.md
sed -n '1,280p' .plan-grader/supabase-advisor-performance-remediation-20260428-000000/REVISED_PLAN.md
sed -n '1,320p' docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md
sed -n '280,620p' .plan-grader/supabase-advisor-performance-remediation-20260428-000000/REVISED_PLAN.md
sed -n '320,720p' docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md
./scripts/db/run_sql.sh /tmp/trr-phase0-evidence.PJdQdE
./scripts/db/run_sql.sh /tmp/trr-phase0-summary.w9Y7FW
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_advisor_remediation_sql.py tests/scripts/test_reconcile_runtime_db.py tests/db/test_connection_resolution.py tests/api/test_startup_validation.py
cd /Users/thomashulihan/Projects/TRR
python3 -m json.tool .plan-grader/supabase-advisor-performance-remediation-20260428-000000/result.json
sed -n '1,220p' /Users/thomashulihan/.codex/skills/orchestrate-subagents/SKILL.md
sed -n '1,220p' /Users/thomashulihan/.codex/skills/write-plan/SKILL.md
rg -n 'subagent_orchestration|orchestrate-subagents|Parallel workstream roster|Orchestration checks' .plan-grader/supabase-advisor-performance-remediation-20260428-000000/REVISED_PLAN.md docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md
```

## current-state fit

PASS for Phase 1 live deployment, Phase 2 live evidence reporting, Phase 4 singleton remediation, and the approved Phase 3 pipeline-owner, admin-tooling, and flashback gameplay batches. Additional Phase 3 batches remain gated.

Phase 0 live inventory has been captured in `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-phase0-evidence-2026-04-28.md`. Phase 1+ now has the required gates but is intentionally blocked pending explicit approval of:

- parallel safety hotfix work for `public.__migrations` and exposed `SECURITY DEFINER` RPCs.
- GRANT/table-owner/FORCE RLS inventory.
- exact command-specific RLS DDL semantics.
- legacy Firebase survey app-policy disable checks.
- per-table policy and grant checks.
- rollback SQL that restores exact Phase 0 policies by name.
- immediate Phase 1 advisor recheck with `TRR_SUPABASE_ACCESS_TOKEN`.
- canonical execution from `docs/codex/plans/`, not `.plan-grader`.

## latest verification result

- Targeted backend artifact/startup/connection tests passed: `40 passed in 2.32s`.
- Orchestrated implementation validation passed after reviewer fixes: `46 passed in 3.04s` for advisor SQL artifacts, unused-index evidence tooling, runtime DB reconcile tests, connection resolution tests, and startup validation.
- Firebase-disable revision validation passed: `46 passed in 1.58s`.
- Phase 4 closeout validation passed: `49 passed in 2.18s` for advisor SQL artifacts, unused-index evidence tooling, runtime DB reconcile tests, connection resolution tests, and startup validation.
- Live dry-run passed against `db.vwxfvzutyufrkhfgoeaa.supabase.co` and rolled back.
- Live Phase 1 DDL deployment passed and `scripts/db/verify_advisor_remediation_phase1.sql` passed post-deploy.
- Reapplied `0090_survey_submit_response_rpc.sql` because the live migration version existed but `surveys.submit_response(uuid,jsonb)` was missing; the function is now present.
- Supabase Performance Advisor API recheck: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; `auth_rls_initplan=0`, `multiple_permissive_policies=0`, `unused_index=415`, total findings `434`.
- Supabase Performance Advisor API recheck after stray schema removal: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; `auth_rls_initplan=0`, `multiple_permissive_policies=0`, `unindexed_foreign_keys=0`, `unused_index=369`, total findings `371`.
- Phase 4 external ID conflicts PK migration deployed live; `external_id_conflicts_pkey` exists and a smoke insert generated `id`, then rolled back.
- Phase 4 Auth DB allocation changed from `10 connections` to `17 percent` through the Management API with `TRR_SUPABASE_ACCESS_TOKEN`.
- Supabase Performance Advisor API recheck after Phase 4: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; only `unused_index=369` remains.
- Supabase Security Advisor API recheck: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; total findings `117`.
- Generic `SUPABASE_ACCESS_TOKEN` returned HTTP 403 because it is scoped to a different Supabase project/account; TRR rechecks must use `TRR_SUPABASE_ACCESS_TOKEN`.
- Stray non-TRR schema correction: `thb_bbl` backed up to `/tmp/trr-thb-bbl-drop-backup-20260428-002111.sql`, dropped from the TRR Supabase project, and verified absent.
- Initial Phase 2 live unused-index report regenerated from fresh Advisor JSON after Phase 4 completion: `1324` rows with `277` `drop_review_required` and `0` `approved_to_drop`.
- Phase 2 owner-specific review packets generated under `docs/workspace/unused-index-owner-review-2026-04-28/`: initial `277` candidates had rollback SQL present and `0` approved.
- Phase 3 approved-drop SQL gate generated `phase3-approved-drops.sql`; after pipeline-owner review it rendered and executed only the `4` explicitly approved pipeline drops.
- Pipeline owner packet reviewed and approved `4` indexes with rollback SQL, live stats, static route review, targeted tests, and live EXPLAIN evidence.
- Phase 3 pipeline-owner batch deployed: `4` `DROP INDEX CONCURRENTLY` statements executed and `to_regclass(...)` verified all four indexes absent.
- Supabase Performance Advisor API recheck after Phase 3 pipeline-owner batch: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; only `unused_index=365` remains.
- Phase 2 live unused-index report regenerated from fresh Advisor JSON after Phase 3 pipeline-owner batch: `1320` rows with `273` `drop_review_required` and `0` `approved_to_drop` in the fresh report.
- Post-drop targeted backend validation passed: `106 passed in 1.53s`.
- Post-drop live EXPLAIN still uses `pipeline_runs_created_at_idx` for `pipeline.runs` list and `socialblade_growth_data_platform_account_handle_idx` for SocialBlade lookup.
- Admin-tooling packet reviewed and approved `12` indexes with rollback SQL, live stats, static route review, targeted tests, and live EXPLAIN evidence; `7` admin rows remain deferred.
- Phase 3 admin-tooling batch deployed: `12` `DROP INDEX CONCURRENTLY` statements executed and `to_regclass(...)` verified all twelve indexes absent.
- Supabase Performance Advisor API recheck after Phase 3 admin-tooling batch: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; only `unused_index=352` remains.
- Phase 2 live unused-index report regenerated from fresh Advisor JSON after Phase 3 admin-tooling batch: `1308` rows with `260` `drop_review_required` and `0` `approved_to_drop` in the fresh report.
- Admin post-drop targeted backend validation passed: `250 passed in 68.12s`.
- Admin post-drop live EXPLAIN still uses retained brand target, network entity, cast tag, person-cover pkey, discovery-state pkey, and survey unique-prefix indexes for reviewed paths.
- Survey/public flashback gameplay packet reviewed and approved `2` indexes with owner direction to remove flashback gameplay for now; `37` survey/public rows remain deferred.
- Phase 3 flashback gameplay index batch deployed: `2` `DROP INDEX CONCURRENTLY` statements executed and `to_regclass(...)` verified both indexes absent.
- Follow-up DDL removed empty `public.flashback_sessions`, empty `public.flashback_user_stats`, and three flashback gameplay RPC helpers while retaining `public.flashback_quizzes` and `public.flashback_events`.
- Backend migration `20260428113000_remove_flashback_gameplay_write_path.sql` now preserves that live removal for future environments.
- Supabase Performance Advisor API recheck after flashback gameplay cleanup: HTTP 200 with `TRR_SUPABASE_ACCESS_TOKEN`; only `unused_index=350` remains.
- Live read-only verification after cleanup: `public.flashback_quizzes` and `public.flashback_events` exist; `public.flashback_sessions`, `public.flashback_user_stats`, and `public.flashback_%` RPC helpers are absent; stray `thb_bbl` schema count is `0`.
- Phase 2 live unused-index report regenerated from fresh Advisor JSON after flashback gameplay cleanup: `1302` rows with `258` `drop_review_required` and `0` `approved_to_drop` in the fresh report.
- Flashback cleanup targeted validation passed: backend `23 passed in 0.90s`, app `14 passed in 1.64s`.
- A broader accidental app test run had `425` passing tests and one unrelated generated admin API reference artifact mismatch for `/api/admin/health/app-db-pressure`.
- Phase 4 subagents completed disjoint DB PK and Auth/capacity documentation scopes; main session applied and verified the live changes.
- Reviewer follow-up fixes passed: `11 passed in 0.18s` for advisor SQL artifact tests plus unused-index evidence tests.
- `result.json` is valid JSON.
- `python3 scripts/migration-ownership-lint.py` passed.
- The revised `.plan-grader` plan and canonical `docs/codex/plans/` plan now both contain the `subagent_orchestration` section, parallel workstream roster, orchestration stop rules, and orchestration validation checks.
- `ORCHESTRATION.md` records branch, subagents used, ownership scopes, validations, blocked checks, remaining risks, and handoff readiness.
- Current repo inspection confirms the Phase 1 local artifacts named by the revised plan exist:
  - `TRR-Backend/supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql`
  - `TRR-Backend/supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql`
  - `TRR-Backend/scripts/db/verify_advisor_remediation_phase1.sql`
  - `TRR-Backend/docs/db/advisor-performance/20260428111000_advisor_rls_policy_cleanup_rollback.sql`
  - `TRR-Backend/tests/db/test_advisor_remediation_sql.py`

## evidence gaps

- Supabase MCP Performance Advisor recheck was previously attempted and blocked with `MCP error -32600: You do not have permission to perform this action`; Management API advisor recheck works when it uses `TRR_SUPABASE_ACCESS_TOKEN`.
- Only the approved pipeline-owner, admin-tooling, and flashback gameplay Phase 3 batches were run. Additional Phase 3 index drops remain blocked because no remaining owner packet rows are approved.
- Independent reviewer found two medium issues. Duplicate `(schema, table, index)` keying was fixed. The Firebase behavior-verification issue was superseded by the user-approved legacy Firebase survey disable path.

## recommended next skill

Phase 2 owner review for the 258 remaining `drop_review_required` index candidates. Additional Phase 3 batches remain blocked until candidates are explicitly approved with rollback SQL and review evidence. Phase 4 is complete and the pipeline-owner, admin-tooling, and flashback gameplay Phase 3 batches are deployed.
