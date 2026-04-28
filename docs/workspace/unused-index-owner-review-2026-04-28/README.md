# Unused Index Owner Review Packets

Status: reopened for full unused-index decision review. Current artifacts are evidence only until the decision matrix approves rows under the full review rules.

## Historical Artifacts Quarantine

Existing `phase3-*-approved-drops.sql` files and previous owner-review files are historical evidence only.

They are not current approval for the full unused-index decision review.

Only rows approved in `docs/workspace/unused-index-decision-matrix-2026-04-28.csv` may appear in proposed Phase 3 batches.

## Current Source Universe

- Current CSV rows: `1302`
- Original requested rows: `1324`
- Reconciliation status: current CSV used for non-destructive artifacts; original count mismatch remains documented.
- Current approved-to-drop rows in the new decision matrix: `0`

## Required Owner Packet Table Columns

| column |
| --- |
| schema |
| table |
| index |
| review_status |
| idx_scan |
| index_size |
| table_size |
| decision |
| decision_reason |
| approved_to_drop |
| approved_by |
| reviewed_routes_or_jobs |
| query_pattern_labels |
| stats_window_checked_at |
| rollback_sql |
| drop_sql_if_approved |
| risk_level |
| phase3_batch_recommendation |
| notes |

## Packet Filenames

| workload | packet filename |
| --- | --- |
| pipeline/other | pipeline-owner-review.md |
| admin tooling | admin-tooling-owner-review.md |
| public/survey | survey-public-app-owner-review.md |
| ml/screenalytics | screenalytics-ml-owner-review.md |
| core catalog/media | catalog-media-owner-review.md |
| social data/backfill | social-data-backfill-owner-review.md |
