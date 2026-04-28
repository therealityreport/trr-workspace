# PATCHES

Source plan: `/Users/thomashulihan/Projects/TRR/.plan-grader/unused-index-full-decision-review-20260428-064550/REVISED_PLAN.md`

## Patch 1 - Promote reusable decision-matrix validator to required work

Added `TRR-Backend/scripts/db/validate_unused_index_decision_matrix.py` as a required Phase 2 artifact and Phase 7/8 validation gate.

Concrete requirements added:

- source row count matches approved universe
- status counts reconcile
- required columns exist
- every row has a decision
- approved rows have all approval, route/job, stats, rollback, risk, and batch fields
- excluded rows cannot be approved without explicit replacement/integrity proof
- nonzero-usage rows default to keep unless exception evidence is present
- social hashtag/search rows cannot be approved while architecture is unresolved

## Patch 2 - Promote no-destructive-SQL scanner to required work

Added `TRR-Backend/scripts/db/scan_no_destructive_sql.py` as required tooling.

It must flag accidental runnable:

- `DROP INDEX`
- `DROP INDEX CONCURRENTLY`
- `CREATE INDEX`
- `CREATE INDEX CONCURRENTLY`

The only allowed proposed-SQL exception is `docs/workspace/unused-index-phase3-proposed-batches-2026-04-28.md`, and even there the SQL must be labeled as proposed text only.

## Patch 3 - Add machine-checkable stats-window JSON

Added required artifact `docs/workspace/unused-index-stats-window-2026-04-28.json`.

The validator now depends on this artifact so zero-scan approvals require either a seven-day stats window or explicit owner/canary risk acceptance.

## Patch 4 - Add social hashtag architecture stub

Added required artifact `docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md`.

The social owner packet and canonical remediation plan must reference it, and social hashtag/search indexes remain blocked until the architecture is resolved or an index is proven unrelated.

## Patch 5 - Add query-pattern taxonomy labels

Added `query_pattern_labels` to the matrix and controlled label values for integrity, FK-hardening, public reads, admin tooling, backfill, worker hot paths, media mirror queues, comment/feed lookups, search, leaderboard candidates, survey, ML, catalog/media, recent migration, and manual review.

## Patch 6 - Generate owner packet filenames from workload slugs

Added a workload-to-packet mapping so packet filenames are deterministic and aligned with subagent write scopes.

## Patch 7 - Add owner packet README schema and prior-approval quarantine

Added required updates for `docs/workspace/unused-index-owner-review-2026-04-28/README.md`:

- shared owner packet table schema
- `Historical artifacts quarantine`
- explicit rule that prior Phase 3 SQL and old owner packets are evidence only

## Patch 8 - Add per-workload time budgets as soft triage

Added workload review posture guidance. The plan states that time budgets are guardrails, not approval shortcuts. Unclear rows become `needs_manual_query_review` or `keep_pending_7_day_recheck`.

## Patch 9 - Add optional post-review Advisor delta snapshot

Added Phase 8 closeout task to attempt a post-review Advisor snapshot with `TRR_SUPABASE_ACCESS_TOKEN`. It is optional evidence only and does not block closeout if unavailable or lagging.
