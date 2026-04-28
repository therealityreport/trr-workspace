# TRR Unused Index Full Decision Review Plan

Date: 2026-04-28
Status: revised by Plan Grader with required guardrails
Source plan: `/Users/thomashulihan/Projects/TRR/.plan-grader/unused-index-full-decision-review-20260428-064550/REVISED_PLAN.md`
Saved path: `/Users/thomashulihan/Projects/TRR/.plan-grader/unused-index-full-decision-review-required-guardrails-20260428-065657/REVISED_PLAN.md`
Recommended execution handoff after blockers clear: `orchestrate-subagents`

## summary

Perform a complete owner decision review for every row in the TRR unused-index evidence universe, then produce a durable decision matrix, owner packets, validation scripts, machine-checkable stats-window evidence, a social hashtag architecture stub, and proposed Phase 3 batches only for rows newly approved by this review.

This is an evidence and classification task only. It must not execute `DROP INDEX`, `CREATE INDEX`, replacement DDL, or live destructive SQL. No index is approved to drop by default, and prior Phase 3 SQL or owner packets are historical evidence only.

Execution is currently blocked until Phase 0 reconciles the report-universe mismatch: the owner request names `1,324` rows with `781 excluded`, `266 deferred`, and `277 drop_review_required`, while the currently present CSV parses as `1,302` rows with `777 excluded`, `267 deferred`, and `258 drop_review_required`.

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Grading-time branch: `chore/workspace-batch-2026-04-28`
- Grading-time dirty state includes unrelated changes to `Makefile` and `scripts/dev-workspace.sh`, prior `.plan-grader/` packages, the source plan, and unrelated backend restart diagnostic scripts. Re-run `git status --short --branch` immediately before execution.
- Current unused-index inputs are present at:
  - `docs/workspace/unused-index-advisor-review-2026-04-28.csv`
  - `docs/workspace/unused-index-advisor-review-2026-04-28.md`
  - `docs/workspace/unused-index-owner-review-2026-04-28/`
- Current CSV check during revision:
  - rows: `1,302`
  - `drop_review_required`: `258`
  - `excluded`: `777`
  - `defer:idx_scan_nonzero`: `267`
  - `approved_to_drop`: all `no`
- Existing `phase3-*-approved-drops.sql` and previous owner-review files in `docs/workspace/unused-index-owner-review-2026-04-28/` are historical evidence only.
- Use `TRR_SUPABASE_ACCESS_TOKEN` for Supabase Management API and Advisor rechecks. Do not use generic `SUPABASE_ACCESS_TOKEN` for TRR.

## assumptions

1. The owner-supplied `1,324` rows remain the intended review universe unless Phase 0 proves and records a corrected owner-approved universe.
2. The TRR owner can record owner decisions, but each approval still requires evidence.
3. `drop_review_required` means review required, not approval granted.
4. Excluded rows default to keep because exclusions represent integrity, uniqueness, FK-hardening, recent migration, or other protection.
5. Nonzero `idx_scan` defaults to keep because the database used the index during the stats window.
6. Social hashtag/search index decisions remain blocked until hashtag leaderboard/search architecture is explicitly resolved or each index is proven unrelated.
7. If stats have not accumulated for at least seven days, zero-scan conclusions are weak and default to `keep_pending_7_day_recheck` unless the owner explicitly accepts canary/urgent risk.

## goals

1. Reconcile the source report universe before row decisions begin.
2. Create a complete decision matrix with one row per approved source-universe member.
3. Add and run a reusable decision-matrix validator.
4. Add and run a no-destructive-SQL scanner for review artifacts.
5. Capture stats-window evidence as machine-checkable JSON.
6. Add a social hashtag leaderboard/search architecture stub and reference it from the social packet and canonical remediation plan.
7. Use controlled `query_pattern_labels` alongside free-form query explanations.
8. Generate owner packet filenames from normalized workload slugs and keep all packet tables mergeable.
9. Quarantine prior approvals in the owner-review README.
10. Generate proposed Phase 3 batches only from rows newly approved under this review.
11. Update the canonical Advisor remediation plan with final decision status and artifact paths.

## non_goals

- Do not execute live `DROP INDEX`, `CREATE INDEX`, or replacement DDL.
- Do not treat Supabase Advisor output as sufficient drop evidence.
- Do not approve primary-key, unique, exclusion, constraint-backed, FK-hardening, or recent indexes without explicit replacement/integrity proof.
- Do not resolve hashtag leaderboard architecture by assumption.
- Do not rewrite backend/app routes during the review.
- Do not stage broad dirty-worktree changes or resolve unrelated conflicts as part of this task.
- Do not let time budgets become approval shortcuts.

## phased_implementation

### Phase 0 - Preflight And Report-Universe Reconciliation

Owner: main session.

Tasks:

- Re-run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short --branch
```

- Stop if unresolved conflicts are present unless the owner explicitly approves artifact-only work in that state.
- Classify dirty files as unrelated, plan-owned, or blockers. Do not overwrite unrelated edits.
- Confirm `TRR_SUPABASE_ACCESS_TOKEN` is available for Advisor checks and do not use generic `SUPABASE_ACCESS_TOKEN`.
- Confirm live DB connection source through the repo resolver without printing credentials.
- Parse the CSV and MD report. Record row count, status counts, and `approved_to_drop` counts.
- Reconcile current CSV counts against the owner-supplied target of `1,324`. If the CSV still has `1,302` rows, stop and either regenerate the report, recover the intended input, or record owner approval that `1,302` is the corrected universe.
- Confirm live inventory for `(schema, table, index)` against `pg_class`, `pg_index`, and `pg_namespace`.
- Capture stats reset/window age from `pg_stat_database`.
- Create `docs/workspace/unused-index-stats-window-2026-04-28.json` with:

```json
{
  "captured_at": "...",
  "stats_reset_at": "...",
  "stats_window_hours": 0,
  "stats_window_days": 0,
  "stats_window_is_7_days_or_more": false,
  "source": "pg_stat_database",
  "notes": "..."
}
```

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
- Stats-window JSON exists and parses.
- No row decisions begin before this phase passes.

### Phase 1 - Matrix Schema, Workload Slugs, And Artifact Scaffolding

Owner: main session.

Tasks:

- Build `docs/workspace/unused-index-decision-matrix-2026-04-28.csv` and `.md`.
- Preserve source row traceability. If duplicate report rows map to one live index, deduplicate only the reporting interpretation, not the live index.
- Add required matrix columns:

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
query_pattern_labels
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

- Use controlled `query_pattern_labels` values. Allowed labels:
  - `integrity_constraint`
  - `fk_hardening`
  - `dedupe_unique`
  - `primary_key_lookup`
  - `public_page_read`
  - `admin_tooling`
  - `backfill_ingest`
  - `worker_claim_hotpath`
  - `worker_heartbeat`
  - `media_mirror_queue`
  - `comment_thread_lookup`
  - `post_feed_lookup`
  - `hashtag_search`
  - `text_search`
  - `handle_search`
  - `leaderboard_candidate`
  - `survey_response_flow`
  - `ml_review_flow`
  - `catalog_media_lookup`
  - `recent_migration`
  - `unknown_needs_manual_review`
- Keep `query_pattern_supported` as free-form explanation.
- Normalize workload labels and generate packet filenames from workload slugs:

| Workload | Packet filename |
| --- | --- |
| `pipeline/other` | `pipeline-owner-review.md` |
| `admin tooling` | `admin-tooling-owner-review.md` |
| `public/survey` | `survey-public-app-owner-review.md` |
| `ml/screenalytics` | `screenalytics-ml-owner-review.md` |
| `core catalog/media` | `catalog-media-owner-review.md` |
| `social data/backfill` | `social-data-backfill-owner-review.md` |

- Create or update `docs/workspace/unused-index-owner-review-2026-04-28/README.md` with the owner packet table schema and historical approval quarantine section.
- Required owner packet table columns:
  - `schema`
  - `table`
  - `index`
  - `review_status`
  - `idx_scan`
  - `index_size`
  - `table_size`
  - `decision`
  - `decision_reason`
  - `approved_to_drop`
  - `approved_by`
  - `reviewed_routes_or_jobs`
  - `query_pattern_labels`
  - `stats_window_checked_at`
  - `rollback_sql`
  - `drop_sql_if_approved`
  - `risk_level`
  - `phase3_batch_recommendation`
  - `notes`
- Add `Historical artifacts quarantine` to the README:
  - Existing `phase3-*-approved-drops.sql` files and previous owner-review files are historical evidence only.
  - They are not current approval for the full decision review.
  - Only rows approved in `docs/workspace/unused-index-decision-matrix-2026-04-28.csv` may appear in proposed Phase 3 batches.
- Default decisions:
  - excluded -> `keep_current_index`
  - nonzero usage -> `keep_because_nonzero_usage`
  - zero-scan candidates -> `needs_manual_query_review`

Acceptance criteria:

- Matrix totals match the approved source universe exactly.
- Every row has `decision`, `query_pattern_labels`, and `approved_to_drop=no` unless later phases prove approval.
- Owner packet names are generated from normalized workload slugs.
- README quarantine and table schema are present.

### Phase 2 - Required Validation Tooling

Owner: main session or tooling worker.

Tasks:

- Add `TRR-Backend/scripts/db/validate_unused_index_decision_matrix.py`.
- The validator must check:
  - source row count matches the approved universe
  - status counts reconcile
  - required columns exist
  - every row has a decision
  - every row has valid `query_pattern_labels`
  - `approved_to_drop=yes` rows have `approved_by`, `approval_reason`, `reviewed_routes_or_jobs`, `stats_window_checked_at`, `rollback_sql`, `drop_sql_if_approved`, `risk_level`, and `phase3_batch_recommendation`
  - excluded rows are not approved unless explicit replacement/integrity proof exists
  - nonzero-usage rows default to keep unless exception evidence is present
  - social hashtag/search rows are not approved while architecture is unresolved
  - zero-scan approvals either have `stats_window_is_7_days_or_more=true` in `unused-index-stats-window-2026-04-28.json` or explicit owner/canary risk acceptance
- Add `TRR-Backend/scripts/db/scan_no_destructive_sql.py`.
- The scanner must flag accidental runnable destructive SQL in review artifacts, especially:
  - `DROP INDEX`
  - `DROP INDEX CONCURRENTLY`
  - `CREATE INDEX`
  - `CREATE INDEX CONCURRENTLY`
- Allowed exception: `docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md`, where SQL must be clearly labeled as proposed text only and not executed.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 -m compileall -q scripts/db/validate_unused_index_decision_matrix.py scripts/db/scan_no_destructive_sql.py
```

Acceptance criteria:

- Both scripts exist and compile.
- Validator and scanner are required in Phase 6 and Phase 7 validation.

### Phase 3 - Social Hashtag Architecture Stub

Owner: social data/backfill reviewer or main session.

Tasks:

- Create `docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md`.
- Minimum content:
  - `Status: unresolved / stub`
  - Decision needed: whether hashtag leaderboard/search should be served from raw platform tables or from normalized `hashtag_mentions` plus rollup/materialized-view layer.
  - Current blocker: do not approve deletion of social `*_search_hashtags_idx`, `*_search_text_trgm_idx`, `*_search_handles_idx`, or `*_search_handle_identities_idx` until this architecture is resolved or each index is proven unrelated.
  - Preferred direction:

```text
raw posts/comments
  -> ingest/backfill hashtag extraction
  -> social.hashtag_mentions
  -> leaderboard rollups/materialized views
  -> Page/API reads
```

- Reference the stub from:
  - `docs/workspace/unused-index-owner-review-2026-04-28/social-data-backfill-owner-review.md`
  - `docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`

Acceptance criteria:

- Social hashtag/search indexes cannot be approved unless the matrix cites this stub and records an explicit unrelated-path proof or later architecture resolution.

### Phase 4 - Excluded Row Verification

Owner: excluded-row verifier or main session.

Tasks:

- Review all excluded rows.
- Keep primary-key, unique, exclusion, and constraint-backed indexes.
- Keep FK-hardening indexes unless equivalent/better coverage and integrity proof exist.
- Keep recent indexes pending a meaningful stats window unless clearly wrong and replacement/rollback evidence exists.
- Identify report duplicates, but do not infer live duplicate drops without live DB proof.
- Use taxonomy labels such as `integrity_constraint`, `dedupe_unique`, `primary_key_lookup`, `fk_hardening`, and `recent_migration`.

Output:

- `docs/workspace/unused-index-keep-report-2026-04-28.md`

Acceptance criteria:

- No excluded row is approved to drop without explicit replacement/integrity proof.

### Phase 5 - Nonzero-Usage Review

Owner: nonzero-usage reviewer or owner-packet subagents.

Tasks:

- Rank nonzero-usage rows by `idx_scan`, tuple counts, size, and workload.
- Mark high-use rows `keep_current_index` unless strong redundancy proof exists.
- For low-use/large rows, inspect migrations, schema docs, routes, jobs, scripts, cron/backfill workers, and query builders.
- Only mark `replace_with_better_index` or `approve_to_drop` when code review, EXPLAIN evidence, coverage by another index or replacement SQL, rollback SQL, and risk documentation are present.
- Assign controlled `query_pattern_labels`; use `unknown_needs_manual_review` when the access path cannot be classified.

Output:

- nonzero-usage section in `unused-index-keep-report-2026-04-28.md`
- candidate entries in `unused-index-replacement-candidates-2026-04-28.md`

Acceptance criteria:

- Nonzero usage defaults to keep, and exceptions are evidence-rich.

### Phase 6 - Zero-Scan Candidate Review And Owner Packets

Owner: six owner/workload packet subagents plus main-session integration.

Subagent write scopes:

| Workstream | Packet path | Review posture |
| --- | --- | --- |
| `pipeline/other` | `docs/workspace/unused-index-owner-review-2026-04-28/pipeline-owner-review.md` | quick full review |
| `admin tooling` | `docs/workspace/unused-index-owner-review-2026-04-28/admin-tooling-owner-review.md` | quick/moderate review |
| `public/survey` | `docs/workspace/unused-index-owner-review-2026-04-28/survey-public-app-owner-review.md` | moderate review |
| `ml/screenalytics` | `docs/workspace/unused-index-owner-review-2026-04-28/screenalytics-ml-owner-review.md` | moderate review |
| `core catalog/media` | `docs/workspace/unused-index-owner-review-2026-04-28/catalog-media-owner-review.md` | deeper review |
| `social data/backfill` | `docs/workspace/unused-index-owner-review-2026-04-28/social-data-backfill-owner-review.md` | deepest review; defer unclear rows |

Per-workload review budget is a triage guardrail, not an approval shortcut. If a row cannot be confidently classified within the workload review budget, mark it `needs_manual_query_review` or `keep_pending_7_day_recheck`. Do not approve it merely to finish the packet.

Tasks:

- Search code and migrations for table, index, and query-pattern usage.
- Populate `reviewed_routes_or_jobs` with specific reviewed surfaces.
- Populate `query_pattern_labels` and `query_pattern_supported`.
- Capture `live_indexdef` and `rollback_sql` with `pg_get_indexdef`.
- Generate proposed drop SQL as text only:

```sql
DROP INDEX CONCURRENTLY IF EXISTS "schema"."index";
```

- Approve only when `idx_scan=0`, stats evidence is meaningful or owner accepts canary risk, no active route/job needs it, it is not protected/recent without proof, rollback SQL is captured, and risk is documented.
- For approved rows set `approved_to_drop=yes`, `approved_by=TRR owner`, specific `approval_reason`, `risk_level`, and `phase3_batch_recommendation`.

Social rule:

- Do not approve `*_search_hashtags_idx`, `*_search_text_trgm_idx`, `*_search_handles_idx`, or `*_search_handle_identities_idx` until `social-hashtag-leaderboard-architecture-2026-04-28.md` is resolved or the index is proven unrelated.
- Large comment, feed/date, parent/post, ingest queue, media mirror, heartbeat, and worker/claim-hotpath indexes need extra evidence.

Acceptance criteria:

- Every zero-scan candidate receives an explicit reviewed decision.
- No protected or social-architecture-blocked index is approved by default.
- All six packet tables use the README schema.

### Phase 7 - Replacement Candidate Packet And Proposed Phase 3 Batches

Owner: main session with input from packet reviewers.

Tasks:

- Create `docs/workspace/unused-index-replacement-candidates-2026-04-28.md`.
- For each replacement candidate, include current index, query pattern, problem, replacement SQL if known, EXPLAIN evidence needed, old index it may replace later, rollback/safety notes, and `approved_to_drop=no`.
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
- Do not combine replacement creation and old-index drop in this task.

Required validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 scripts/db/validate_unused_index_decision_matrix.py \
  --matrix ../docs/workspace/unused-index-decision-matrix-2026-04-28.csv \
  --source ../docs/workspace/unused-index-advisor-review-2026-04-28.csv \
  --stats-window ../docs/workspace/unused-index-stats-window-2026-04-28.json \
  --architecture-stub ../docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 scripts/db/scan_no_destructive_sql.py \
  --root .. \
  --allow-proposed docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md
```

Acceptance criteria:

- Proposed batches contain only newly approved rows from this full-review matrix.
- The validator passes.
- The scanner finds no runnable destructive SQL outside the allowed proposed-batches artifact.
- No SQL is executed.

### Phase 8 - Canonical Plan Status Update And Closeout

Owner: main session.

Tasks:

- Update `docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md` with the new review status if the canonical file is present.
- Reference `docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md`.
- Record final counts by decision, approved Phase 3 count, unresolved architecture blockers, stats-window limitation, and artifact paths.
- Attempt a post-review Supabase Advisor snapshot using `TRR_SUPABASE_ACCESS_TOKEN`.
- Because this task does not execute live drops, Advisor counts are not expected to materially improve. Record the snapshot only to detect drift during the review window.
- If Advisor access fails or data lags, document the blocker. Do not block closeout solely on this snapshot.
- Keep `.plan-grader/.../REVISED_PLAN.md` as evidence only unless the owner explicitly asks to sync it.
- Append a short TRR workspace brain session note after artifacts are generated.

Required validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 -m compileall -q scripts/db/unused_index_evidence_report.py scripts/db/validate_unused_index_decision_matrix.py scripts/db/scan_no_destructive_sql.py
```

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
```

```bash
cd /Users/thomashulihan/Projects/TRR
git diff --check -- docs/workspace docs/codex/plans TRR-Backend/scripts/db
```

Acceptance criteria:

- Future execution can start from the canonical plan, matrix, validator output, and owner packets without reconstructing the review.

## architecture_impact

- No live schema change in this task.
- The decision matrix becomes the durable review contract for future Phase 3 work.
- `social-hashtag-leaderboard-architecture-2026-04-28.md` becomes the explicit blocker and decision stub for social hashtag/search index retirement.
- Backend route/job review may identify replacement-index candidates, but implementation is a separate plan.
- `validate_unused_index_decision_matrix.py` and `scan_no_destructive_sql.py` become reusable guardrails for future unused-index cycles.

## data_or_api_impact

- No data mutation.
- No API contract mutation.
- Proposed drop rows require live rollback SQL from `pg_get_indexdef`.
- Replacement rows require replacement SQL or pending-design notes and remain `approved_to_drop=no`.
- Stats-window evidence is stored as JSON so zero-scan approval rules can be machine-checked.

## ux_admin_ops_considerations

- Admin, worker, and backfill routes must be reviewed before approval.
- Owner packets should be readable without opening the CSV.
- Packet filenames and workload labels must remain stable so subagent output is mergeable.
- Social/backfill is last because query patterns are volatile.
- Every proposed future batch needs smoke checks and rollback notes.

## validation_plan

Run after artifact generation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 -m compileall -q scripts/db/unused_index_evidence_report.py scripts/db/validate_unused_index_decision_matrix.py scripts/db/scan_no_destructive_sql.py
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 scripts/db/validate_unused_index_decision_matrix.py \
  --matrix ../docs/workspace/unused-index-decision-matrix-2026-04-28.csv \
  --source ../docs/workspace/unused-index-advisor-review-2026-04-28.csv \
  --stats-window ../docs/workspace/unused-index-stats-window-2026-04-28.json \
  --architecture-stub ../docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 scripts/db/scan_no_destructive_sql.py \
  --root .. \
  --allow-proposed docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md
```

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
git diff --check -- docs/workspace docs/codex/plans TRR-Backend/scripts/db
```

Also parse every generated CSV/JSON/MD artifact and reconcile matrix totals against the approved source universe.

## acceptance_criteria

- The source universe mismatch is resolved before decisions begin.
- `TRR-Backend/scripts/db/validate_unused_index_decision_matrix.py` exists, compiles, and passes against the final matrix.
- `TRR-Backend/scripts/db/scan_no_destructive_sql.py` exists, compiles, and passes against review artifacts.
- `docs/workspace/unused-index-stats-window-2026-04-28.json` exists and is used by the validator.
- `docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md` exists and is referenced by the social owner packet and canonical remediation plan.
- `docs/workspace/unused-index-owner-review-2026-04-28/README.md` includes the owner packet schema and historical artifacts quarantine.
- `unused-index-decision-matrix-2026-04-28.csv` and `.md` exist and reconcile to the approved row count.
- Matrix includes `query_pattern_labels` with controlled values.
- All six `*-owner-review.md` packets exist and use the shared schema.
- `unused-index-keep-report-2026-04-28.md` explains keep decisions.
- `unused-index-replacement-candidates-2026-04-28.md` isolates replacement candidates.
- `unused-index-phase3-proposed-batches-2026-04-28.md` contains only newly approved rows.
- Every approved-to-drop row has all approval, route/job, stats, rollback, drop SQL, risk, and batch fields.
- Every keep row has `approved_to_drop=no` and a specific reason.
- No live index drops occur.

## risks_edge_cases_open_questions

- Current CSV count differs from the owner-supplied review universe.
- Current worktree has unrelated dirty files.
- Live inventory may differ from the report.
- Stats may be too fresh for strong zero-scan conclusions.
- Social hashtag/search architecture remains unresolved.
- Prior Phase 3 SQL files may confuse execution if treated as approval.
- Free-form review notes may drift unless `query_pattern_labels` and the owner packet schema are enforced.

## follow_up_improvements

- Add a durable do-not-drop registry.
- Add route-owner labels to the evidence script source output if not already covered by the matrix generation path.
- Add candidate-age detection if incomplete.
- Add a rollback smoke checklist template per future execution batch.
- Track write-latency impact for future social backfill drops.

## recommended_next_step_after_approval

Use `orchestrate-subagents` after Phase 0 blockers clear. The main session owns preflight, source-universe reconciliation, validator/scanner integration, final matrix integration, validation, and stop-rule enforcement. Subagents own only their assigned owner packet paths and must not edit live SQL or unrelated files.

## ready_for_execution

Not yet. The plan is stronger, but execution is blocked until the row-count mismatch is resolved and the current dirty worktree is either cleaned or explicitly accepted by the owner.

## stop_rules

- Stop if current report counts do not match the owner-approved review universe.
- Stop if live DB index inventory differs materially from the report.
- Stop if stats reset/window evidence cannot be captured or written to JSON.
- Stop if rollback SQL cannot be captured for a proposed drop.
- Stop if any proposed drop is primary-key, unique, exclusion, constraint-backed, or FK-hardening without explicit replacement/integrity proof.
- Stop if code search finds an active route/job depending on the index.
- Stop if a social hashtag/search index is proposed for deletion without resolving or explicitly deferring the hashtag leaderboard/search architecture question.
- Stop if destructive `DROP INDEX` or `CREATE INDEX` would be executed during this task.
- Stop if the validator or destructive-SQL scanner fails.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
