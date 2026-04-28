# Unused Index Owner Packet - pipeline owner

Status: review-only. No index is approved by default.

Approval requirements:

- Set `approved_to_drop=yes` only after route/job review.
- Fill `approval_reason`, `approved_by`, `reviewed_routes_or_jobs`, and `stats_window_checked_at`.
- Keep the generated `rollback_sql`; it was captured from `pg_get_indexdef` for this live index.
- Do not approve rows whose workload has not had a meaningful stats window, unless the owner records an urgent approval reason.

Candidate count: `4`.

Approval evidence:

- Live `pg_stat_database.stats_reset`: `2025-12-05 20:00:25.270075+00`.
- Live table stats: `pipeline.run_stages` and `pipeline.runs` have `n_live_tup=0`; `pipeline.socialblade_growth_data` has `n_live_tup=9`.
- Targeted backend tests passed: `tests/pipeline/test_models.py`, `tests/pipeline/test_orchestrator.py`, `tests/pipeline/test_show_refresh_orchestrator.py`, and SocialBlade fallback test selection: `57 passed in 0.64s`.
- Live EXPLAIN showed `pipeline.runs` list path uses `pipeline_runs_created_at_idx`, SocialBlade lookup uses `socialblade_growth_data_platform_account_handle_idx` plus `socialblade_growth_data_person_id_instagram_handle_key`, and no known route/job path uses the four candidate indexes.
- The `pipeline_run_stages_run_id_idx` candidate is redundant for known `run_id` lookups because `run_stages_run_id_stage_name_key` has `run_id` as its leading column.

Full rollback SQL is in the companion CSV.

| schema | table | index | idx_scan | index_size | table_size | migration_path | approved_to_drop | drop_sql |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pipeline | run_stages | pipeline_run_stages_run_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0086_create_pipeline_schema.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."pipeline_run_stages_run_id_idx"; |
| pipeline | run_stages | pipeline_run_stages_status_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0086_create_pipeline_schema.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."pipeline_run_stages_status_idx"; |
| pipeline | runs | pipeline_runs_status_idx | 0 | 8192 bytes | 32 kB | supabase/migrations/0086_create_pipeline_schema.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."pipeline_runs_status_idx"; |
| pipeline | socialblade_growth_data | socialblade_growth_data_person_platform_account_handle_idx | 0 | 16 kB | 496 kB | supabase/migrations/0206_generalize_socialblade_growth_data.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "pipeline"."socialblade_growth_data_person_platform_account_handle_idx"; |
