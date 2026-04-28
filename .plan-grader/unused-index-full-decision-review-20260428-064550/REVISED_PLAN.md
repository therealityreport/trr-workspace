# TRR Unused Index Full Decision Review Plan

Date: 2026-04-28
Status: revised by Plan Grader; planning artifact only
Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-unused-index-full-decision-review-plan.md`
Saved path: `/Users/thomashulihan/Projects/TRR/.plan-grader/unused-index-full-decision-review-20260428-064550/REVISED_PLAN.md`
Recommended execution handoff after blockers clear: `orchestrate-subagents`

## summary

Perform a complete owner decision review for every row in the current TRR unused-index evidence universe, then produce a durable decision matrix and owner packet set. This is an evidence and classification gate only. It must not execute `DROP INDEX`, must not approve any index by default, and must not reuse prior Phase 3 SQL artifacts as current approval.

Execution is currently blocked until Phase 0 reconciles a report-universe mismatch: the owner request names `1,324` rows with `781 excluded`, `266 deferred`, and `277 drop_review_required`, while the currently present CSV parses as `1,302` rows with `777 excluded`, `267 deferred`, and `258 drop_review_required`.

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Current grading-time worktree state: detached `HEAD` with unresolved conflicts and many staged/added workspace artifacts. Re-run `git status --short --branch` immediately before execution.
- Relevant current conflicts observed during grading include `docs/workspace/env-deprecations.md`, `scripts/check-workspace-contract.sh`, `scripts/status-workspace.sh`, and `scripts/test_workspace_app_env_projection.py`.
- Phase 4 Supabase Advisor remediation is complete; Advisor now reports only unused-index findings.
- Current unused-index inputs are present at:
  - `docs/workspace/unused-index-advisor-review-2026-04-28.csv`
  - `docs/workspace/unused-index-advisor-review-2026-04-28.md`
  - `docs/workspace/unused-index-owner-review-2026-04-28/`
- Existing `phase3-*-approved-drops.sql` and prior owner-review files in that directory are historical evidence only. They are not approval for this full-review cycle.
- Use `TRR_SUPABASE_ACCESS_TOKEN` for Supabase Management API and Advisor rechecks. Do not use generic `SUPABASE_ACCESS_TOKEN` for TRR.

## assumptions

1. The owner-supplied `1,324` rows remain the intended review universe unless Phase 0 proves and records a corrected owner-approved universe.
2. The TRR owner can record owner decisions, but each approval still requires evidence.
3. `drop_review_required` means review required, not approval granted.
4. Excluded rows default to keep because exclusions represent integrity, uniqueness, FK-hardening, recent migration, or other protection.
5. Nonzero `idx_scan` defaults to keep because the database used the index during the stats window.
6. Social hashtag/search index decisions remain blocked until hashtag leaderboard/search architecture is decided.
7. If stats have not accumulated for at least seven days, zero-scan conclusions are weak and default to `keep_pending_7_day_recheck` unless the owner explicitly accepts canary/urgent risk.

## goals

1. Reconcile the source report universe before row decisions begin.
2. Create a complete decision matrix with one row per approved source-row universe member.
3. Verify all excluded rows and keep protected indexes by default.
4. Review all nonzero-usage rows and separate true keeps from replacement candidates.
5. Review zero-scan candidates by workload, route/job usage, migrations, query plans, and live index definitions.
6. Generate owner packets with specific evidence and reasoning.
7. Generate proposed Phase 3 batches only from rows newly approved under this review.
8. Update the canonical Advisor remediation plan with final decision status and artifact paths.

## non_goals

- Do not execute live `DROP INDEX`, `CREATE INDEX`, or replacement DDL.
- Do not treat Supabase Advisor output as sufficient drop evidence.
- Do not approve primary-key, unique, exclusion, constraint-backed, FK-hardening, or recent indexes without explicit replacement/integrity proof.
- Do not resolve hashtag leaderboard architecture by assumption.
- Do not rewrite backend/app routes during the review.
- Do not stage broad dirty-worktree changes or resolve unrelated conflicts as part of this task.

## phased_implementation

### Phase 0 - Preflight And Report-Universe Reconciliation

Owner: main session.

Tasks:

- Re-run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short --branch
```

- Stop if unresolved conflicts remain unless the owner explicitly approves continuing with artifact-only work.
- Confirm `TRR_SUPABASE_ACCESS_TOKEN` is available for Advisor checks and do not use generic `SUPABASE_ACCESS_TOKEN`.
- Confirm live DB connection source through the repo resolver without printing credentials.
- Parse the CSV and MD report. Record row count and status counts.
- Reconcile the current CSV counts against the owner-supplied target of `1,324`. If the CSV still has `1,302` rows, stop and either regenerate the report, recover the intended input, or record owner approval that `1,302` is the corrected universe.
- Confirm live inventory for `(schema, table, index)` against `pg_class`, `pg_index`, and `pg_namespace`.
- Capture stats reset/window age from `pg_stat_database`.
- Record whether the stats window is at least seven days.
- Treat existing prior owner packets and `phase3-*-approved-drops.sql` files as historical evidence only.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 - <<'PY'
import csv
from collections import Counter
p='docs/workspace/unused-index-advisor-review-2026-04-28.csv'
with open(p, newline='') as f:
    rows=list(csv.DictReader(f))
print('rows', len(rows))
print('review_status', Counter(r['review_status'] for r in rows))
print('approved_to_drop', Counter(r['approved_to_drop'] for r in rows))
PY
```

Acceptance criteria:

- The review universe is explicitly approved and recorded.
- Worktree conflicts are resolved or explicitly accepted by the owner.
- No row decisions begin before this phase passes.

### Phase 1 - Matrix Schema And Inventory Normalization

Owner: main session.

Tasks:

- Build `docs/workspace/unused-index-decision-matrix-2026-04-28.csv` and `.md`.
- Preserve source row traceability. If duplicate report rows map to one live index, deduplicate only the reporting interpretation, not the live index.
- Add required columns:

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
approval_reason
stats_window_checked_at
rollback_sql
drop_sql_if_approved
replacement_index_sql_if_needed
risk_level
phase3_batch_recommendation
notes
```

- Normalize workload labels to:
  - `pipeline/other`
  - `admin tooling`
  - `public/survey`
  - `ml/screenalytics`
  - `core catalog/media`
  - `social data/backfill`
- Default decisions:
  - excluded -> `keep_current_index`
  - nonzero usage -> `keep_because_nonzero_usage`
  - zero-scan candidates -> `needs_manual_query_review`

Acceptance criteria:

- Matrix totals match the approved source universe exactly.
- Every row has a decision and `approved_to_drop=no` unless later phases prove approval.

### Phase 2 - Excluded Row Verification

Owner: excluded-row verifier or main session.

Tasks:

- Review all excluded rows.
- Keep primary-key, unique, exclusion, and constraint-backed indexes.
- Keep FK-hardening indexes unless equivalent/better coverage and integrity proof exist.
- Keep recent indexes pending a meaningful stats window unless clearly wrong and replacement/rollback evidence exists.
- Identify report duplicates, but do not infer live duplicate drops without live DB proof.

Output:

- `docs/workspace/unused-index-keep-report-2026-04-28.md`

Acceptance criteria:

- No excluded row is approved to drop without explicit replacement/integrity proof.

### Phase 3 - Nonzero-Usage Review

Owner: nonzero-usage reviewer or owner-packet subagents.

Tasks:

- Rank nonzero-usage rows by `idx_scan`, tuple counts, size, and workload.
- Mark high-use rows `keep_current_index` unless strong redundancy proof exists.
- For low-use/large rows, inspect migrations, schema docs, routes, jobs, scripts, cron/backfill workers, and query builders.
- Only mark `replace_with_better_index` or `approve_to_drop` when code review, EXPLAIN evidence, coverage by another index or replacement SQL, rollback SQL, and risk documentation are present.

Output:

- nonzero-usage section in `unused-index-keep-report-2026-04-28.md`
- candidate entries in `unused-index-replacement-candidates-2026-04-28.md`

Acceptance criteria:

- Nonzero usage defaults to keep, and exceptions are evidence-rich.

### Phase 4 - Zero-Scan Candidate Review

Owner: six owner/workload packet subagents plus main-session integration.

Subagent write scopes:

| Workstream | Packet path |
| --- | --- |
| pipeline/other | `docs/workspace/unused-index-owner-review-2026-04-28/pipeline-owner-review.md` |
| admin tooling | `docs/workspace/unused-index-owner-review-2026-04-28/admin-tooling-owner-review.md` |
| public/survey | `docs/workspace/unused-index-owner-review-2026-04-28/survey-public-app-owner-review.md` |
| ml/screenalytics | `docs/workspace/unused-index-owner-review-2026-04-28/screenalytics-ml-owner-review.md` |
| core catalog/media | `docs/workspace/unused-index-owner-review-2026-04-28/catalog-media-owner-review.md` |
| social data/backfill | `docs/workspace/unused-index-owner-review-2026-04-28/social-data-backfill-owner-review.md` |

Tasks:

- Search code and migrations for table, index, and query-pattern usage.
- Populate `reviewed_routes_or_jobs` with specific reviewed surfaces.
- Capture `live_indexdef` and `rollback_sql` with `pg_get_indexdef`.
- Generate proposed drop SQL as text only:

```sql
DROP INDEX CONCURRENTLY IF EXISTS "schema"."index";
```

- Approve only when `idx_scan=0`, stats evidence is meaningful or owner accepts canary risk, no active route/job needs it, it is not protected/recent without proof, rollback SQL is captured, and risk is documented.
- For approved rows set `approved_to_drop=yes`, `approved_by=TRR owner`, specific `approval_reason`, `risk_level`, and `phase3_batch_recommendation`.

Social rule:

- Do not approve `*_search_hashtags_idx`, `*_search_text_trgm_idx`, `*_search_handles_idx`, or `*_search_handle_identities_idx` until hashtag leaderboard/search architecture is resolved or the index is proven unrelated.
- Large comment, feed/date, parent/post, ingest queue, media mirror, heartbeat, and worker/claim-hotpath indexes need extra evidence.

Acceptance criteria:

- Every zero-scan candidate receives an explicit reviewed decision.
- No protected or social-architecture-blocked index is approved by default.

### Phase 5 - Replacement Candidate Packet

Owner: main session with input from packet reviewers.

Tasks:

- Create `docs/workspace/unused-index-replacement-candidates-2026-04-28.md`.
- For each replacement candidate, include current index, query pattern, problem, replacement SQL if known, EXPLAIN evidence needed, old index it may replace later, rollback/safety notes, and `approved_to_drop=no`.
- Do not combine replacement creation and old-index drop in this task.

Acceptance criteria:

- Replacement candidates cannot leak into proposed Phase 3 drop batches.

### Phase 6 - Proposed Phase 3 Batches

Owner: main session.

Tasks:

- Create `docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md`.
- Include only rows with `approved_to_drop=yes` from the new decision matrix.
- Exclude keep, pending, manual-review, and replacement rows.
- Batch order:
  1. `pipeline/other`
  2. `admin tooling`
  3. `public/survey`
  4. `ml/screenalytics`
  5. `core catalog/media`
  6. `social data/backfill`
- For each batch include proposed SQL text, rollback SQL, smoke checks, Advisor recheck, soak expectation, and stop criteria.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 - <<'PY'
import csv, sys
p='docs/workspace/unused-index-decision-matrix-2026-04-28.csv'
required = {
  'decision','approved_to_drop','approved_by','approval_reason',
  'reviewed_routes_or_jobs','stats_window_checked_at','rollback_sql',
  'drop_sql_if_approved','risk_level','phase3_batch_recommendation'
}
with open(p, newline='') as f:
    rows=list(csv.DictReader(f))
missing=required-set(rows[0])
if missing:
    raise SystemExit(f'missing columns: {sorted(missing)}')
for i, row in enumerate(rows, 2):
    if row['approved_to_drop'] == 'yes':
        empty=[c for c in required if not row.get(c)]
        if empty:
            raise SystemExit(f'row {i} approved but missing {empty}')
print('ok', len(rows))
PY
```

Acceptance criteria:

- Proposed batches contain only newly approved rows from this full-review matrix.
- No SQL is executed.

### Phase 7 - Canonical Plan Status Update And Closeout

Owner: main session.

Tasks:

- Update `docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md` with the new review status if the canonical file is present.
- Record final counts by decision, approved Phase 3 count, unresolved architecture blockers, stats-window limitation, and artifact paths.
- Keep `.plan-grader/.../REVISED_PLAN.md` as evidence only unless the owner explicitly asks to sync it.
- Append a short TRR workspace brain session note after artifacts are generated.

Acceptance criteria:

- Future execution can start from the canonical plan and matrix without reconstructing the review.

## architecture_impact

- No live schema change in this task.
- The decision matrix becomes the durable review contract for future Phase 3 work.
- Social hashtag/search architecture remains a product decision blocker.
- Backend route/job review may identify replacement-index candidates, but implementation is a separate plan.

## data_or_api_impact

- No data mutation.
- No API contract mutation.
- Proposed drop rows require live rollback SQL from `pg_get_indexdef`.
- Replacement rows require replacement SQL or pending-design notes and remain `approved_to_drop=no`.

## ux_admin_ops_considerations

- Admin, worker, and backfill routes must be reviewed before approval.
- Owner packets should be readable without opening the CSV.
- Social/backfill is last because query patterns are volatile.
- Every proposed future batch needs smoke checks and rollback notes.

## validation_plan

Run after artifact generation:

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

Also parse every generated CSV/JSON/MD artifact and reconcile matrix totals against the approved source universe.

## acceptance_criteria

- The source universe mismatch is resolved before decisions begin.
- `unused-index-decision-matrix-2026-04-28.csv` and `.md` exist and reconcile to the approved row count.
- All six `*-owner-review.md` packets exist.
- `unused-index-keep-report-2026-04-28.md` explains keep decisions.
- `unused-index-replacement-candidates-2026-04-28.md` isolates replacement candidates.
- `unused-index-phase3-proposed-batches-2026-04-28.md` contains only approved rows.
- Every approved-to-drop row has all approval, route/job, stats, rollback, drop SQL, risk, and batch fields.
- Every keep row has `approved_to_drop=no` and a specific reason.
- No live index drops occur.

## risks_edge_cases_open_questions

- Current CSV count differs from the owner-supplied review universe.
- Current worktree has unresolved conflicts.
- Live inventory may differ from the report.
- Stats may be too fresh for strong zero-scan conclusions.
- Social hashtag/search architecture remains unresolved.
- Prior Phase 3 SQL files may confuse execution if treated as approval.

## follow_up_improvements

- Add a reusable decision-matrix validator.
- Add a durable do-not-drop registry.
- Add route-owner labels to the evidence script.
- Add candidate-age detection if incomplete.
- Add a rollback smoke checklist template per batch.
- Track write-latency impact for future social backfill drops.

## recommended_next_step_after_approval

Use `orchestrate-subagents` after Phase 0 blockers clear. The main session owns preflight, source-universe reconciliation, final matrix integration, validation, and stop-rule enforcement. Subagents own only their assigned owner packet paths and must not edit live SQL or unrelated files.

## ready_for_execution

Not yet. The plan is ready, but execution is blocked until the row-count mismatch and current worktree conflicts are resolved or explicitly accepted by the owner.

## stop_rules

- Stop if current report counts do not match the owner-approved review universe.
- Stop if live DB index inventory differs materially from the report.
- Stop if stats reset/window evidence cannot be captured.
- Stop if rollback SQL cannot be captured for a proposed drop.
- Stop if any proposed drop is primary-key, unique, exclusion, constraint-backed, or FK-hardening without explicit replacement/integrity proof.
- Stop if code search finds an active route/job depending on the index.
- Stop if a social hashtag/search index is proposed for deletion without resolving the hashtag leaderboard/search architecture question.
- Stop if destructive `DROP INDEX` would be executed during this task.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
