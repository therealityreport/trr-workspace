# TRR Unused Index Full Decision Review Plan

Date: 2026-04-28
Status: planning artifact, not approval to drop indexes
Saved path: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-unused-index-full-decision-review-plan.md`
Execution handoff after approval: `orchestrate-subagents`

## summary

Perform a complete owner decision review for all `1,324` rows in the current unused-index evidence package, then produce a durable decision matrix and owner review packet set. This task is an evidence and classification gate only. It must not execute `DROP INDEX`, and no index is approved to drop by default.

The expected output is a row-complete matrix that classifies every report row as keep, approve-to-drop, replacement candidate, pending seven-day recheck, pending product architecture decision, constraint/integrity keep, nonzero-usage keep, or manual-query-review needed. Any proposed Phase 3 drop batch must be generated only from rows that satisfy the explicit approval rules and have live rollback SQL captured with `pg_get_indexdef(indexrelid)`.

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Draft-time branch/worktree checks changed during this planning pass, so execution must not rely on a stale branch snapshot. Re-confirm `git status --short --branch` immediately before any review work.
- Latest draft-time status observed detached `HEAD` with existing unresolved conflicts in workspace env docs plus untracked `.plan-grader/` and `docs/codex/`; treat these as preflight blockers unless the owner intentionally wants to continue in that state.
- Advisor remediation context: Phase 4 is complete; Supabase Advisor now reports only unused-index findings.
- Current report shape supplied by owner:
  - `277` `drop_review_required` rows
  - `266` deferred rows because `idx_scan` is nonzero
  - `781` excluded rows because they are primary keys, unique indexes, constraint-backed indexes, FK-hardening indexes, recent indexes, or otherwise protected
- Current Plan Grader package records the active remediation state under `/Users/thomashulihan/Projects/TRR/.plan-grader/supabase-advisor-performance-remediation-20260428-000000/`.
- Execution must use `TRR_SUPABASE_ACCESS_TOKEN` for Supabase Management API and Advisor rechecks. Do not use generic `SUPABASE_ACCESS_TOKEN` for TRR.
- Primary code/data surfaces:
  - `docs/workspace/unused-index-advisor-review-2026-04-28.csv`
  - `docs/workspace/unused-index-advisor-review-2026-04-28.md`
  - `docs/workspace/unused-index-owner-review-2026-04-28/`
  - `docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`
  - `docs/workspace/supabase-advisor-recheck-2026-04-28.md`
  - `docs/workspace/supabase-advisor-performance-phase1-implementation-2026-04-28.md`
  - `TRR-Backend/supabase/migrations/`
  - `TRR-Backend/supabase/schema_docs/`
  - `TRR-Backend/scripts/db/`
  - backend app code, API routes, jobs, scripts, cron/backfill workers, and query builders that touch reviewed tables

## assumptions

1. The supplied `1,324` rows are the authoritative review universe for this task unless live inventory comparison shows material drift.
2. The owner is allowed to record decisions as `TRR owner`, but each approval still needs evidence. Ownership does not equal automatic approval.
3. The `277` `drop_review_required` rows are candidates for review only, not drop approvals.
4. Existing report exclusions are protective signals. They can be verified or corrected, but zero scans alone do not override primary-key, uniqueness, constraint, FK-hardening, or recent-index protection.
5. Nonzero `idx_scan` means the database used the index during the captured stats window. Those rows default to keep unless code review, EXPLAIN evidence, and coverage by a better index prove otherwise.
6. Social hashtag/search index decisions are blocked by product architecture until the hashtag leaderboard/search read model is decided.
7. If the current stats window is under seven days, zero-scan conclusions are weaker evidence and default to `keep_pending_7_day_recheck` unless the owner explicitly accepts canary/urgent cleanup risk.

## goals

1. Normalize the current unused-index evidence into a complete decision matrix for all `1,324` rows.
2. Verify excluded rows and keep protected indexes by default.
3. Review nonzero-usage rows for keep/replacement/redundancy, with high-usage rows defaulting to keep.
4. Review zero-scan candidates by workload, code paths, migrations, query plans, and live index definitions.
5. Produce owner-specific review packets with specific reasoning, not generic rubber stamps.
6. Generate small Phase 3 proposed batches only from rows that are explicitly approved to drop.
7. Preserve rollback paths for every proposed drop using live `pg_get_indexdef`.
8. Update the canonical Advisor remediation plan with the new decision-review status.

## non_goals

- Do not execute `DROP INDEX`, `CREATE INDEX`, or replacement DDL in this task.
- Do not treat Advisor unused-index output as sufficient evidence to drop.
- Do not approve primary-key, unique, exclusion, constraint-backed, or FK-hardening indexes without explicit replacement/integrity proof.
- Do not resolve the hashtag leaderboard architecture by assumption.
- Do not rewrite unrelated backend/app routes while reviewing index usage.
- Do not stage broad dirty-worktree changes or overwrite unrelated edits.

## phased_implementation

### Phase 0 - Preflight, Source Validation, And Live DB Contract

Purpose: prove the review is operating against the intended repo, token, database, report, and stats window.

Tasks:

- Confirm branch and dirty state:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short --branch
```

- Classify existing dirty files as unrelated, plan-owned, or blocker. Do not overwrite unrelated edits.
- Confirm `TRR_SUPABASE_ACCESS_TOKEN` is set for Advisor checks and explicitly confirm generic `SUPABASE_ACCESS_TOKEN` is not being used for TRR Advisor/Management API calls.
- Confirm live DB connection source through the repo resolver without printing credentials. Prefer the same connection resolution path used by `TRR-Backend/scripts/db/unused_index_evidence_report.py`.
- Confirm the current CSV/MD report paths exist. If not, stop and either restore or regenerate the report from the canonical evidence script before making decisions.
- Confirm live index inventory matches the report universe by comparing `(schema, table, index)` from the CSV against `pg_class/pg_index/pg_namespace`.
- Capture stats window age:

```sql
select
  datname,
  stats_reset,
  now() as checked_at,
  now() - stats_reset as stats_window_age
from pg_stat_database
where datname = current_database();
```

- If `stats_window_age < interval '7 days'`, mark zero-scan conclusions as weak and default unresolved zero-scan rows to `keep_pending_7_day_recheck` unless the owner explicitly accepts canary/urgent cleanup.
- Capture live rollback SQL source for candidate rows with:

```sql
select
  n.nspname as schema,
  c.relname as table,
  i.relname as index,
  pg_get_indexdef(i.oid) as rollback_sql
from pg_index ix
join pg_class i on i.oid = ix.indexrelid
join pg_class c on c.oid = ix.indrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = $1
  and i.relname = $2;
```

Validation:

- Source report row count is exactly `1,324`, or the execution stops with a material drift note.
- Live inventory comparison has no missing live indexes for any proposed drop.
- Stats reset evidence is recorded in every owner packet and matrix row where it affects the decision.
- No destructive SQL has run.

Acceptance criteria:

- Preflight evidence is captured in the matrix markdown.
- Any drift or missing primary input stops the review before decisions are recorded.

### Phase 1 - Reporting And Inventory Cleanup Only

Purpose: build the normalized matrix without making drop decisions.

Tasks:

- Parse `docs/workspace/unused-index-advisor-review-2026-04-28.csv` and MD summary.
- Preserve all `1,324` report rows in the decision matrix.
- Deduplicate repeated report rows as a reporting artifact by grouping on `(schema, table, index)`, while preserving traceability to source row numbers in `notes` or an additional trace column.
- Normalize workload labels:
  - `pipeline/other`
  - `admin tooling`
  - `public/survey`
  - `ml/screenalytics`
  - `core catalog/media`
  - `social data/backfill`
- Add the required decision matrix columns:

```text
workload
owner
schema
table
index
current_review_status
current_idx_scan
idx_tup_read
idx_tup_fetch
index_size
table_size
advisor_reported
exclude_reasons
migration_path
live_indexdef
constraint_status
uniqueness_status
fk_hardening_status
recent_migration_status
app_or_job_references_found
reviewed_routes_or_jobs
query_pattern_supported
decision
decision_reason
approved_to_drop
approved_by
stats_window_checked_at
rollback_sql
drop_sql_if_approved
replacement_index_sql_if_needed
risk_level
phase3_batch_recommendation
notes
```

- Add `approval_reason` as an extra column even though it was listed separately from the required column block, because approved rows require it.
- Populate default decisions:
  - excluded rows -> `keep_current_index`
  - nonzero-usage rows -> `keep_because_nonzero_usage`
  - zero-scan `drop_review_required` rows -> `needs_manual_query_review` until reviewed
- Add summary tables by workload, current status, decision, risk, and proposed Phase 3 batch.

Output:

- `docs/workspace/unused-index-decision-matrix-2026-04-28.csv`
- `docs/workspace/unused-index-decision-matrix-2026-04-28.md`

Validation:

- CSV parses cleanly with Python `csv.DictReader`.
- Markdown summary totals reconcile to `1,324`.
- Decision totals reconcile to the CSV row count.

Acceptance criteria:

- Matrix exists, has all required columns, and every source row has exactly one decision row.
- Duplicate reporting artifacts are visible without implying live duplicate index drops.

### Phase 2 - Excluded Row Verification

Purpose: verify the `781` excluded rows and produce a keep report.

Tasks:

- Confirm primary-key, unique, exclusion, and constraint-backed rows remain `keep_current_index` and `approved_to_drop=no`.
- Confirm FK-hardening indexes stay unless another equivalent or better index covers the same foreign-key path and integrity/performance proof exists.
- Confirm recent indexes stay as `keep_current_index` or `keep_pending_7_day_recheck` unless they are obviously wrong/duplicative and a replacement/rollback plan exists.
- Identify suspicious duplicates or redundant excluded rows in the report, but do not approve drops without live proof.
- Populate:
  - `constraint_status`
  - `uniqueness_status`
  - `fk_hardening_status`
  - `recent_migration_status`
  - `decision_reason`
  - `risk_level`
- Keep `approved_to_drop=no` for every excluded row unless a later explicit owner-approved exception satisfies all drop rules.

Output:

- `docs/workspace/unused-index-keep-report-2026-04-28.md`
- owner packet sections for all excluded rows

Validation:

- No excluded row has `approved_to_drop=yes` without explicit replacement/integrity proof.
- The keep report includes counts by exclusion reason and workload.

Acceptance criteria:

- Excluded rows are not rubber-stamped from zero scans; each keep reason is classifiable and auditable.

### Phase 3 - Nonzero-Usage Review

Purpose: verify the `266` `defer:idx_scan_nonzero` rows and separate true keeps from possible future replacement candidates.

Tasks:

- Rank nonzero-usage rows by `idx_scan`, `idx_tup_read`, `idx_tup_fetch`, `index_size`, and table size.
- Mark high-use indexes as `keep_current_index` unless there is very strong redundancy evidence.
- For low-use or large indexes, review:
  - migration source
  - schema docs
  - backend route/query usage
  - jobs, scripts, cron, workers, and backfill paths
  - EXPLAIN evidence for the supported query pattern
  - whether another index fully covers the same access path
- Only mark `replace_with_better_index` or `approve_to_drop` when all of these are true:
  - code/query review proves redundancy
  - EXPLAIN shows the preferred plan does not need the current index
  - another index fully covers the same access path, or replacement SQL is specified
  - rollback SQL is captured live
  - risk is documented
- Replacement candidates must keep `approved_to_drop=no` until the replacement exists and is verified.

Output:

- nonzero-usage section in `docs/workspace/unused-index-keep-report-2026-04-28.md`
- replacement rows in `docs/workspace/unused-index-replacement-candidates-2026-04-28.md`

Validation:

- Every nonzero-usage row has `decision_reason` tied to observed usage, route/job support, redundancy proof, or replacement evidence.
- No high-use row is approved to drop without exceptional proof.

Acceptance criteria:

- Nonzero usage defaults to keep and any exception is evidence-rich enough for owner review.

### Phase 4 - Zero-Scan Candidate Review

Purpose: review the `277` `drop_review_required` rows without approving anything by default.

Tasks:

- Group candidates by owner/workload:
  - `pipeline/other`
  - `admin tooling`
  - `public/survey`
  - `ml/screenalytics`
  - `core catalog/media`
  - `social data/backfill`
- For each row, search code and migrations for table, index, and query-pattern usage. Include backend app code, API routes, jobs, scripts, cron/backfill workers, query builders, migrations, and schema docs.
- Populate `reviewed_routes_or_jobs` with specific routes/jobs/scripts reviewed, not generic labels.
- Populate `app_or_job_references_found` and `query_pattern_supported`.
- Capture `live_indexdef` and `rollback_sql` live with `pg_get_indexdef`.
- Generate `drop_sql_if_approved` only as text:

```sql
DROP INDEX CONCURRENTLY IF EXISTS "schema"."index";
```

- Classify each row as one of:
  - `approve_to_drop`
  - `replace_with_better_index`
  - `keep_pending_7_day_recheck`
  - `keep_pending_product_architecture_decision`
  - `keep_current_index`
  - `needs_manual_query_review`
- Mark `approve_to_drop` only when:
  - `idx_scan = 0`
  - stats window is meaningful, or owner explicitly accepts canary/urgent risk
  - no relevant route/job/query needs it
  - it is not primary, unique, exclusion, constraint-backed, FK-hardening, or recent unless explicitly justified
  - rollback SQL is captured live
  - drop SQL is generated with `DROP INDEX CONCURRENTLY IF EXISTS`
  - risk is documented
  - `approved_to_drop=yes`
  - `approved_by=TRR owner`
  - `approval_reason` is specific
  - `phase3_batch_recommendation` is assigned

Special social architecture rule:

- Do not approve social hashtag/search indexes for deletion until the hashtag leaderboard architecture is decided.
- Classify `*_search_hashtags_idx`, `*_search_text_trgm_idx`, `*_search_handles_idx`, and `*_search_handle_identities_idx` as:
  - `keep_pending_product_architecture_decision`
  - `replace_with_hashtag_mentions_rollup_indexing`
  - `approve_to_drop` only if confirmed unrelated to future hashtag search/leaderboard paths
- Treat these especially carefully:
  - social comment parent/post indexes
  - social season/date/feed indexes
  - social ingest/backfill queue indexes
  - media mirror pending indexes
  - worker/heartbeat/claim-hotpath indexes
  - large comment table indexes on `instagram_comments`, `tiktok_comments`, `reddit_comments`, and `youtube_comments`

Output:

- `docs/workspace/unused-index-owner-review-2026-04-28/pipeline-owner-review.md`
- `docs/workspace/unused-index-owner-review-2026-04-28/admin-tooling-owner-review.md`
- `docs/workspace/unused-index-owner-review-2026-04-28/survey-public-app-owner-review.md`
- `docs/workspace/unused-index-owner-review-2026-04-28/screenalytics-ml-owner-review.md`
- `docs/workspace/unused-index-owner-review-2026-04-28/catalog-media-owner-review.md`
- `docs/workspace/unused-index-owner-review-2026-04-28/social-data-backfill-owner-review.md`

Validation:

- Every approved row has `rollback_sql`, `drop_sql_if_approved`, `approval_reason`, `approved_by`, `reviewed_routes_or_jobs`, `stats_window_checked_at`, `risk_level`, and `phase3_batch_recommendation`.
- No social hashtag/search index is approved without resolving or explicitly ruling out the hashtag leaderboard/search path.

Acceptance criteria:

- All `277` zero-scan candidates have an explicit non-default decision and evidence reason.

### Phase 5 - Replacement Candidate Packet

Purpose: isolate indexes that are probably wrong or suboptimal but should not be dropped until a replacement exists and is verified.

Tasks:

- For each replacement candidate, document:
  - current index and supported query pattern
  - problem with current index
  - replacement index SQL
  - EXPLAIN evidence needed before creation
  - old index it may replace after verification
  - rollback/safety notes
- Keep `approved_to_drop=no` for replacement candidates.
- Do not recommend dropping old and replacement indexes in the same step unless the owner later approves a separate execution batch.

Output:

- `docs/workspace/unused-index-replacement-candidates-2026-04-28.md`

Validation:

- Every replacement candidate includes `replacement_index_sql_if_needed` or a clear reason why design work is still pending.

Acceptance criteria:

- Replacement candidates are separated from drop approvals and cannot leak into Phase 3 drop batches.

### Phase 6 - Proposed Phase 3 Batches

Purpose: produce small, reversible proposed batches only from rows approved to drop.

Tasks:

- Filter the matrix to `approved_to_drop=yes`.
- Exclude all keep, pending, manual-review, and replacement rows.
- Create small batches in this order:
  1. `pipeline/other`
  2. `admin tooling`
  3. `public/survey`
  4. `ml/screenalytics`
  5. `core catalog/media`
  6. `social data/backfill`
- Put social/backfill last because query patterns are volatile and feature architecture is evolving.
- For each batch, include:
  - rows included
  - exact `DROP INDEX CONCURRENTLY IF EXISTS` statements as proposed SQL only
  - rollback SQL per row
  - smoke-check routes/jobs
  - Advisor recheck command
  - soak window expectation
  - stop criteria

Output:

- `docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md`

Validation:

- Batch artifact contains only rows with `approved_to_drop=yes`.
- Every batch has rollback and smoke-check notes.
- No SQL is executed.

Acceptance criteria:

- The proposed Phase 3 artifact is ready for a separate owner-approved execution task.

### Phase 7 - Canonical Plan Status Update And Closeout

Purpose: update the remediation plan with the new decision status and make the artifact set self-consistent.

Tasks:

- Update `docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md` if present. If it is absent, update the current canonical copy or record the missing canonical plan as a blocker.
- Add the new status:
  - full unused-index decision review completed
  - decision matrix path
  - owner packet directory
  - count by final decision
  - count approved for Phase 3
  - unresolved architecture blockers
  - stats-window limitation if under seven days
  - no live drops executed during this task
- Keep `.plan-grader/.../REVISED_PLAN.md` as evidence only unless the owner explicitly asks to sync it.
- Append a short session note to the appropriate TRR workspace brain session log after artifacts are generated.

Validation:

- All generated CSV/JSON/MD artifacts parse cleanly.
- Canonical status points to the generated matrix and owner packets.

Acceptance criteria:

- A future execution session can start from the canonical plan and matrix without reconstructing this review.

## architecture_impact

- Database architecture: no live schema change in this task. The review may identify future index drops or replacement indexes, but those remain proposed artifacts only.
- Backend architecture: code search and query-plan review may identify active route/job dependencies, especially in social profile, social backfill, admin tooling, survey/public, screenalytics, and media/catalog surfaces.
- Product architecture: social hashtag/search indexes are blocked pending the hashtag leaderboard/search architecture decision. The likely long-term shape is raw social posts/comments -> hashtag extraction during ingest/backfill -> `social.hashtag_mentions` -> rollups/materialized views -> API/page reads against small leaderboard results.
- Ownership: decisions are grouped into owner packets so the TRR owner can approve specific rows without losing workload context.

## data_or_api_impact

- No data mutation and no API contract mutation are expected.
- The decision matrix becomes the durable data contract for future Phase 3 index work.
- Approved drop rows must include rollback SQL generated from live `pg_get_indexdef`.
- Replacement rows must include proposed replacement SQL but remain `approved_to_drop=no`.
- If future replacement indexes affect backend/app query plans, those changes must be handled in a separate execution plan with EXPLAIN evidence.

## ux_admin_ops_considerations

- Admin and operator routes must be reviewed before any index is approved to drop.
- Social/backfill indexes require extra caution because local admin workflows, workers, queue claiming, and profile dashboards are still evolving.
- Proposed Phase 3 batches must include smoke checks for affected routes/jobs and rollback instructions.
- The final markdown summary should be readable by the owner without opening the CSV.

## validation_plan

Run these checks after generating artifacts:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 -m compileall -q scripts/db/unused_index_evidence_report.py
```

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
```

```bash
cd /Users/thomashulihan/Projects/TRR
git diff --check -- docs/workspace docs/codex/plans TRR-Backend/scripts/db
```

Also validate:

- Parse generated CSV with `csv.DictReader` and assert required columns are present.
- Parse any generated JSON with `python3 -m json.tool`.
- Check markdown artifacts for reconciled totals.
- Run existing targeted tests for touched scripts/docs if available.
- If SQL helpers are added, validate them against a safe local or read-only production query path.

Expected result:

- All generated artifacts parse.
- Matrix totals reconcile to `1,324`.
- No destructive SQL has run.
- Proposed Phase 3 batches include only `approved_to_drop=yes` rows.

## acceptance_criteria

- `docs/workspace/unused-index-decision-matrix-2026-04-28.csv` exists and contains all `1,324` report rows.
- `docs/workspace/unused-index-decision-matrix-2026-04-28.md` summarizes decisions by workload, status, risk, and proposed batch.
- `docs/workspace/unused-index-owner-review-2026-04-28/` contains all six owner review packets.
- `docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md` contains only approved drop rows.
- `docs/workspace/unused-index-keep-report-2026-04-28.md` explains all keep decisions.
- `docs/workspace/unused-index-replacement-candidates-2026-04-28.md` isolates replacement candidates with replacement SQL/evidence requirements.
- Every approved-to-drop row has `approved_to_drop=yes`, `approved_by=TRR owner`, specific `approval_reason`, populated `reviewed_routes_or_jobs`, populated `stats_window_checked_at`, live `rollback_sql`, `DROP INDEX CONCURRENTLY IF EXISTS "schema"."index";`, `risk_level`, and `phase3_batch_recommendation`.
- Every keep row has `approved_to_drop=no` and a specific reason.
- Every replacement candidate has `approved_to_drop=no`, replacement SQL or pending-design notes, and EXPLAIN evidence requirements.
- Canonical plan status is updated with final decision counts and artifact paths.
- No index drops are executed.

## risks_edge_cases_open_questions

- The current checkout did not show the named `docs/workspace/unused-index-*` artifacts at the workspace root during drafting. Execution must stop if those inputs are still missing and regenerate or restore them before review.
- The workspace is `ahead 5` and `behind 9`; execution must avoid mixing this review with unrelated local commits or remote drift.
- If live inventory differs from the report, decisions may be invalid. Stop on material drift.
- If stats reset evidence cannot be captured, zero-scan decisions cannot be promoted to approved drops.
- If the stats window is under seven days, zero-scan rows should usually remain pending.
- If code search finds active route/job usage, the row must not be approved to drop.
- If rollback SQL cannot be captured live, the row must not be approved to drop.
- The hashtag leaderboard/search architecture decision remains open and blocks social hashtag/search drops.
- Large social comment tables may have rare but important query paths that do not show up in a short stats window.

## follow_up_improvements

- Add an advisor diff helper to compare saved Advisor snapshots and live rechecks.
- Add a durable `do-not-drop` registry for intentionally retained low-scan indexes.
- Add route-owner labels directly to the evidence script output.
- Add candidate age detection to the unused-index evidence script if it is incomplete.
- Add a rollback smoke checklist template per proposed drop batch.
- Track write-latency impact for social backfills after any future approved drop batch.

## recommended_next_step_after_approval

Use `orchestrate-subagents` because the review is broad and parallelizable by owner/workload. The main session should own preflight, live DB connection confirmation, matrix reconciliation, final integration, and stop-rule enforcement. Subagents can independently review the six owner/workload packets with disjoint write scopes under `docs/workspace/unused-index-owner-review-2026-04-28/`.

## ready_for_execution

Yes, after the owner confirms the current unused-index CSV/MD inputs are present or approves regenerating them from the evidence script. The plan is intentionally non-destructive and blocks all live index drops until a separate Phase 3 execution batch is explicitly approved.

## stop_rules

- Stop if live DB index inventory differs materially from the report.
- Stop if stats reset/window evidence cannot be captured.
- Stop if rollback SQL cannot be captured for a proposed drop.
- Stop if any proposed drop is primary-key, unique, exclusion, constraint-backed, or FK-hardening without explicit replacement/integrity proof.
- Stop if code search finds an active route/job depending on the index.
- Stop if a social hashtag/search index is proposed for deletion without resolving the hashtag leaderboard/search architecture question.
- Stop if a destructive `DROP INDEX` statement would be executed during this task.
