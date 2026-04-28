# Phase 3 Pipeline Index Drop Evidence - 2026-04-28

Status: completed for the pipeline owner packet only.

## Approved Rows

The following rows were approved in `pipeline-owner.csv` with rollback SQL and review evidence:

- `pipeline.pipeline_run_stages_run_id_idx`
- `pipeline.pipeline_run_stages_status_idx`
- `pipeline.pipeline_runs_status_idx`
- `pipeline.socialblade_growth_data_person_platform_account_handle_idx`

## Review Evidence

- `pg_stat_database.stats_reset`: `2025-12-05 20:00:25.270075+00`
- `pipeline.run_stages`: `n_live_tup=0`, `idx_scan=0`
- `pipeline.runs`: `n_live_tup=0`
- `pipeline.socialblade_growth_data`: `n_live_tup=9`
- Targeted backend tests: `57 passed in 0.64s`
- Live EXPLAIN:
  - `pipeline.runs` list path uses `pipeline_runs_created_at_idx`.
  - SocialBlade lookup uses `socialblade_growth_data_platform_account_handle_idx` and `socialblade_growth_data_person_id_instagram_handle_key`.
  - Known `run_stages` `run_id` lookups remain covered by `run_stages_run_id_stage_name_key`.

## Live DDL

Executed with direct TRR DB URL:

```sql
DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."pipeline_run_stages_run_id_idx";
DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."pipeline_run_stages_status_idx";
DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."pipeline_runs_status_idx";
DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."socialblade_growth_data_person_platform_account_handle_idx";
```

Result: all four commands returned `DROP INDEX`.

## Verification

`to_regclass(...)` returned null for all four dropped indexes.

Post-drop targeted tests:

- `106 passed in 1.53s`

Post-drop live EXPLAIN:

- `pipeline.runs` list path still uses `pipeline_runs_created_at_idx`.
- SocialBlade lookup still uses `socialblade_growth_data_platform_account_handle_idx`.

Performance Advisor recheck:

- Source response: `/tmp/trr-performance-advisor-after-phase3-pipeline-20260428.json`
- `unused_index=365`
- total performance findings: `365`

Fresh unused-index evidence report:

- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.csv`
- rows: `1320`
- `drop_review_required`: `273`
- `excluded`: `781`
- `defer:idx_scan_nonzero`: `266`

## Rollback

Rollback SQL is retained in `phase3-approved-drops.sql` and `pipeline-owner.csv`.
