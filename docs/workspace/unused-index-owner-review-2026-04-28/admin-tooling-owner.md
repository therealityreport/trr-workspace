# Unused Index Owner Packet - admin tooling owner

Status: reviewed. `12` approved for this Phase 3 admin batch; `7` remain owner-review only.

Approval requirements:

- Set `approved_to_drop=yes` only after route/job review.
- Fill `approval_reason`, `approved_by`, `reviewed_routes_or_jobs`, and `stats_window_checked_at`.
- Keep the generated `rollback_sql`; it was captured from `pg_get_indexdef` for this live index.
- Do not approve rows whose workload has not had a meaningful stats window, unless the owner records an urgent approval reason.

Candidate count: `19`.

Full rollback SQL is in the companion CSV.

## Review Evidence

- Production stats window: `pg_stat_database.stats_reset = 2025-12-05 20:00:25.270075+00`.
- Live row counts checked for all candidate tables on `2026-04-28T06:27:30Z`.
- Targeted backend validation before approval: `250 passed in 68.02s`.
- Live EXPLAIN confirmed representative brand-logo reads use `brand_logo_assets_target_idx`, network logo detail reads use `network_streaming_logo_assets_entity_idx`, cast-photo tag reads use cast/source or `people_ids` paths, person cover reads use `person_cover_photos_pkey`, discovery-state reads use its primary key, and sync-run reads use the run-id path rather than `finished_at`.
- Deferred rows include active route filters, runtime-created indexes, FK-support indexes, reddit season/community filters, and owner-grouping paths that should remain with the route owner.

## Approved Rows

| schema | table | index | idx_scan | index_size | table_size | migration_path | approved_to_drop | drop_sql |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | brand_logo_assets | brand_logo_assets_sha_idx | 0 | 32 kB | 392 kB | supabase/migrations/0160_brand_logo_assets_and_expand_import_targets.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."brand_logo_assets_sha_idx"; |
| admin | cast_photo_people_tags | cast_photo_people_tags_people_names_idx | 0 | 24 kB | 472 kB | supabase/migrations/0099_admin_cast_photo_people_tags.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."cast_photo_people_tags_people_names_idx"; |
| admin | entity_logo_imports | entity_logo_imports_target_idx | 0 | 16 kB | 160 kB | supabase/migrations/0136_production_logo_parity_and_imports.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."entity_logo_imports_target_idx"; |
| admin | network_streaming_completion_attempts | network_streaming_completion_attempts_run_idx | 0 | 296 kB | 4152 kB | supabase/migrations/0131_network_streaming_completion_and_overrides.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."network_streaming_completion_attempts_run_idx"; |
| admin | network_streaming_discovery_state | network_streaming_discovery_state_updated_idx | 0 | 40 kB | 224 kB | supabase/migrations/0143_network_streaming_discovery_state.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."network_streaming_discovery_state_updated_idx"; |
| admin | network_streaming_logo_assets | network_streaming_logo_assets_sha_idx | 0 | 240 kB | 3904 kB | supabase/migrations/0135_network_streaming_logo_assets.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."network_streaming_logo_assets_sha_idx"; |
| admin | network_streaming_sync_runs | network_streaming_sync_runs_finished_idx | 0 | 16 kB | 64 kB | supabase/migrations/0144_network_streaming_sync_runs.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."network_streaming_sync_runs_finished_idx"; |
| admin | person_cover_photos | idx_person_cover_photos_photo | 0 | 16 kB | 48 kB |  | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_person_cover_photos_photo"; |
| admin | person_reprocess_job_events | idx_person_reprocess_job_events_job_created | 0 | 8192 bytes | 32 kB | supabase/migrations/0168_person_gallery_pipeline_acceleration.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_person_reprocess_job_events_job_created"; |
| admin | person_reprocess_jobs | idx_person_reprocess_jobs_status_created | 0 | 8192 bytes | 32 kB | supabase/migrations/0168_person_gallery_pipeline_acceleration.sql | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_person_reprocess_jobs_status_created"; |
| admin | season_cast_survey_roles | idx_season_cast_survey_roles_person | 0 | 8192 bytes | 40 kB |  | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_season_cast_survey_roles_person"; |
| admin | season_cast_survey_roles | idx_season_cast_survey_roles_show_season | 0 | 8192 bytes | 40 kB |  | yes | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_season_cast_survey_roles_show_season"; |

## Deferred Rows

| schema | table | index | idx_scan | index_size | table_size | migration_path | approved_to_drop | drop_sql |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | brand_families | brand_families_active_idx | 0 | 16 kB | 64 kB | supabase/migrations/0162_brand_families_and_link_propagation.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."brand_families_active_idx"; |
| admin | brand_family_wikipedia_show_links | admin_brand_family_wikipedia_show_links_matched_show_id_idx | 0 | 16 kB | 1000 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."admin_brand_family_wikipedia_show_links_matched_show_id_idx"; |
| admin | brands_franchise_rules | brands_franchise_rules_active_rank_idx | 0 | 16 kB | 48 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."brands_franchise_rules_active_rank_idx"; |
| admin | network_streaming_completion | network_streaming_completion_owner_idx | 0 | 40 kB | 880 kB | supabase/migrations/0162_brand_families_and_link_propagation.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."network_streaming_completion_owner_idx"; |
| admin | person_reprocess_jobs | idx_person_reprocess_jobs_person_created | 0 | 8192 bytes | 32 kB | supabase/migrations/0168_person_gallery_pipeline_acceleration.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_person_reprocess_jobs_person_created"; |
| admin | reddit_communities | idx_reddit_communities_active | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_reddit_communities_active"; |
| admin | reddit_threads | idx_reddit_threads_season | 0 | 16 kB | 336 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "admin"."idx_reddit_threads_season"; |
