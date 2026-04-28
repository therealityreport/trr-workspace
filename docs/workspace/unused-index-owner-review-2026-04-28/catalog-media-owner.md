# Unused Index Owner Packet - catalog/media owner

Status: review-only. No index is approved by default.

Approval requirements:

- Set `approved_to_drop=yes` only after route/job review.
- Fill `approval_reason`, `approved_by`, `reviewed_routes_or_jobs`, and `stats_window_checked_at`.
- Keep the generated `rollback_sql`; it was captured from `pg_get_indexdef` for this live index.
- Do not approve rows whose workload has not had a meaningful stats window, unless the owner records an urgent approval reason.

Candidate count: `68`.

Full rollback SQL is in the companion CSV.

| schema | table | index | idx_scan | index_size | table_size | migration_path | approved_to_drop | drop_sql |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| core | admin_operations | idx_admin_operations_parent_id | 0 | 8192 bytes | 40 MB | supabase/migrations/20260408000000_admin_sub_operations.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_admin_operations_parent_id"; |
| core | admin_operations | idx_admin_operations_worker_heartbeat | 0 | 128 kB | 40 MB | supabase/migrations/0173_remote_job_plane_claims.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_admin_operations_worker_heartbeat"; |
| core | bravotv_image_runs | idx_bravotv_image_runs_mode_created_at | 0 | 8192 bytes | 56 kB | supabase/migrations/0203_bravotv_image_runs.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_bravotv_image_runs_mode_created_at"; |
| core | bravotv_image_runs | idx_bravotv_image_runs_person_created_at | 0 | 8192 bytes | 56 kB | supabase/migrations/0203_bravotv_image_runs.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_bravotv_image_runs_person_created_at"; |
| core | bravotv_image_runs | idx_bravotv_image_runs_status_created_at | 0 | 8192 bytes | 56 kB | supabase/migrations/0203_bravotv_image_runs.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_bravotv_image_runs_status_created_at"; |
| core | cast_fandom | core_cast_fandom_source_idx | 0 | 16 kB | 464 kB | supabase/migrations/0041_create_cast_fandom_and_extend_cast_photos.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_cast_fandom_source_idx"; |
| core | cast_photos | cast_photos_hosted_at_idx | 0 | 952 kB | 97 MB | supabase/migrations/0043_cast_photos_add_hosted_fields.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."cast_photos_hosted_at_idx"; |
| core | cast_photos | cast_photos_person_gallery_idx | 0 | 1136 kB | 97 MB | supabase/migrations/0134_optimize_cast_role_members.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."cast_photos_person_gallery_idx"; |
| core | cast_photos | cast_photos_person_hosted_gallery_idx | 0 | 0 bytes | 97 MB | supabase/migrations/20260325140500_add_cast_photos_person_hosted_gallery_idx.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."cast_photos_person_hosted_gallery_idx"; |
| core | cast_tmdb | idx_cast_tmdb_imdb_id | 0 | 40 kB | 288 kB | supabase/migrations/0044_create_cast_tmdb.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_cast_tmdb_imdb_id"; |
| core | cast_tmdb | idx_cast_tmdb_instagram_id | 0 | 16 kB | 288 kB | supabase/migrations/0044_create_cast_tmdb.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_cast_tmdb_instagram_id"; |
| core | cast_tmdb | idx_cast_tmdb_twitter_id | 0 | 16 kB | 288 kB | supabase/migrations/0044_create_cast_tmdb.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_cast_tmdb_twitter_id"; |
| core | episode_external_ids | episode_external_ids_episode_id_idx | 0 | 1384 kB | 11 MB | supabase/migrations/0070_external_ids.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_external_ids_episode_id_idx"; |
| core | episode_images | episode_images_hosted_at_idx | 0 | 40 kB | 2032 kB | supabase/migrations/0067_create_episode_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_images_hosted_at_idx"; |
| core | episode_images | episode_images_hosted_sha256_idx | 0 | 88 kB | 2032 kB | supabase/migrations/0067_create_episode_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_images_hosted_sha256_idx"; |
| core | episode_images | episode_images_metadata_idx | 0 | 32 kB | 2032 kB | supabase/migrations/0067_create_episode_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_images_metadata_idx"; |
| core | episode_images | episode_images_season_id_idx | 0 | 40 kB | 2032 kB | supabase/migrations/0067_create_episode_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_images_season_id_idx"; |
| core | episode_images | episode_images_source_image_id_idx | 0 | 104 kB | 2032 kB | supabase/migrations/0067_create_episode_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_images_source_image_id_idx"; |
| core | episode_source_history | core_episode_source_history_source_id_idx | 0 | 8192 bytes | 32 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_episode_source_history_source_id_idx"; |
| core | episode_source_history | episode_source_history_lookup_idx | 0 | 8192 bytes | 32 kB | supabase/migrations/0071_source_snapshots.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."episode_source_history_lookup_idx"; |
| core | episode_source_latest | core_episode_source_latest_source_id_idx | 0 | 8192 bytes | 24 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_episode_source_latest_source_id_idx"; |
| core | fandom_community_allowlist | core_fandom_community_allowlist_active_idx | 0 | 8192 bytes | 24 kB | supabase/migrations/0139_add_fandom_allowlist_table.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_fandom_community_allowlist_active_idx"; |
| core | google_news_sync_jobs | idx_google_news_sync_jobs_status | 0 | 16 kB | 256 kB | supabase/migrations/0138_news_feature_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_google_news_sync_jobs_status"; |
| core | google_news_sync_jobs | idx_google_news_sync_jobs_status_heartbeat | 0 | 16 kB | 256 kB | supabase/migrations/0140_google_news_sync_job_heartbeat.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_google_news_sync_jobs_status_heartbeat"; |
| core | google_news_sync_jobs | idx_google_news_sync_jobs_worker_heartbeat | 0 | 40 kB | 256 kB | supabase/migrations/0173_remote_job_plane_claims.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_google_news_sync_jobs_worker_heartbeat"; |
| core | media_assets | idx_media_assets_archived | 0 | 8192 bytes | 150 MB | supabase/migrations/0116_archive_media_assets_and_show_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_media_assets_archived"; |
| core | media_assets | media_assets_ingest_next_retry_idx | 0 | 8192 bytes | 150 MB | supabase/migrations/0061_add_media_assets_ingest_fields.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."media_assets_ingest_next_retry_idx"; |
| core | media_links | idx_media_links_person_gallery_entity_kind_id | 0 | 1336 kB | 56 MB | supabase/migrations/0168_person_gallery_pipeline_acceleration.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_media_links_person_gallery_entity_kind_id"; |
| core | media_uploads | core_media_uploads_media_asset_id_idx | 0 | 8192 bytes | 56 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_media_uploads_media_asset_id_idx"; |
| core | media_uploads | core_media_uploads_media_link_id_idx | 0 | 8192 bytes | 56 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_media_uploads_media_link_id_idx"; |
| core | media_uploads | media_uploads_entity_idx | 0 | 8192 bytes | 56 kB | supabase/migrations/0064_create_media_uploads.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."media_uploads_entity_idx"; |
| core | media_uploads | media_uploads_status_idx | 0 | 8192 bytes | 56 kB | supabase/migrations/0064_create_media_uploads.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."media_uploads_status_idx"; |
| core | media_uploads | media_uploads_uploader_idx | 0 | 8192 bytes | 56 kB | supabase/migrations/0064_create_media_uploads.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."media_uploads_uploader_idx"; |
| core | person_images | person_images_person_id_is_primary_idx | 0 | 592 kB | 7032 kB | supabase/migrations/0056_create_person_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."person_images_person_id_is_primary_idx"; |
| core | person_source_history | core_person_source_history_source_id_idx | 0 | 16 kB | 5456 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_person_source_history_source_id_idx"; |
| core | person_source_history | person_source_history_lookup_idx | 0 | 16 kB | 5456 kB | supabase/migrations/0071_source_snapshots.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."person_source_history_lookup_idx"; |
| core | person_source_latest | core_person_source_latest_source_id_idx | 0 | 16 kB | 272 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_person_source_latest_source_id_idx"; |
| core | season_external_ids | season_external_ids_season_id_idx | 0 | 88 kB | 712 kB | supabase/migrations/0070_external_ids.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."season_external_ids_season_id_idx"; |
| core | season_fandom | core_season_fandom_season_number_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0133_fandom_sync_expansion.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_season_fandom_season_number_idx"; |
| core | season_fandom | core_season_fandom_show_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0133_fandom_sync_expansion.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_season_fandom_show_id_idx"; |
| core | season_images | core_season_images_show_id_idx | 0 | 48 kB | 8072 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_season_images_show_id_idx"; |
| core | season_images | season_images_metadata_idx | 0 | 112 kB | 8072 kB | supabase/migrations/0052_season_images_add_metadata_fields.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."season_images_metadata_idx"; |
| core | season_images | season_images_source_image_id_idx | 0 | 224 kB | 8072 kB | supabase/migrations/0052_season_images_add_metadata_fields.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."season_images_source_image_id_idx"; |
| core | season_source_history | core_season_source_history_source_id_idx | 0 | 8192 bytes | 32 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_season_source_history_source_id_idx"; |
| core | season_source_history | season_source_history_lookup_idx | 0 | 8192 bytes | 32 kB | supabase/migrations/0071_source_snapshots.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."season_source_history_lookup_idx"; |
| core | season_source_latest | core_season_source_latest_source_id_idx | 0 | 8192 bytes | 24 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_season_source_latest_source_id_idx"; |
| core | show_alternative_names | show_alternative_names_show_id_idx | 0 | 16 kB | 120 kB | supabase/migrations/0082_create_show_alternative_names.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."show_alternative_names_show_id_idx"; |
| core | show_cast_role_assignments | core_show_cast_role_assignments_season_id_idx | 0 | 16 kB | 168 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_show_cast_role_assignments_season_id_idx"; |
| core | show_cast_role_assignments | show_cast_role_assignments_role_idx | 0 | 16 kB | 168 kB | supabase/migrations/0120_show_admin_links_and_roles.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."show_cast_role_assignments_role_idx"; |
| core | show_images | idx_show_images_archived | 0 | 8192 bytes | 28 MB | supabase/migrations/0116_archive_media_assets_and_show_images.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_show_images_archived"; |
| core | show_images | idx_show_images_hosted_at | 0 | 488 kB | 28 MB | supabase/migrations/0045_show_images_add_hosted_fields.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_show_images_hosted_at"; |
| core | show_images | idx_show_images_hosted_sha256 | 0 | 1408 kB | 28 MB | supabase/migrations/0045_show_images_add_hosted_fields.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."idx_show_images_hosted_sha256"; |
| core | show_images | show_images_source_image_id_idx | 0 | 1376 kB | 28 MB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."show_images_source_image_id_idx"; |
| core | show_source_history | core_show_source_history_source_id_idx | 0 | 16 kB | 8400 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_show_source_history_source_id_idx"; |
| core | show_watch_providers | show_watch_providers_region_idx | 0 | 176 kB | 4176 kB | supabase/migrations/0048_create_tmdb_entities_and_watch_providers.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."show_watch_providers_region_idx"; |
| core | shows | core_shows_alternative_names_gin | 0 | 40 kB | 3968 kB | supabase/migrations/0057_add_alternative_names_to_shows.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_alternative_names_gin"; |
| core | shows | core_shows_external_ids_gin | 0 | 80 kB | 3968 kB | supabase/migrations/0004_core_shows.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_external_ids_gin"; |
| core | shows | core_shows_genres_gin | 0 | 104 kB | 3968 kB | supabase/migrations/0037_collapse_show_attributes.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_genres_gin"; |
| core | shows | core_shows_keywords_gin | 0 | 168 kB | 3968 kB | supabase/migrations/0037_collapse_show_attributes.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_keywords_gin"; |
| core | shows | core_shows_listed_on_gin | 0 | 64 kB | 3968 kB | supabase/migrations/0037_collapse_show_attributes.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_listed_on_gin"; |
| core | shows | core_shows_networks_gin | 0 | 56 kB | 3968 kB | supabase/migrations/0037_collapse_show_attributes.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_networks_gin"; |
| core | shows | core_shows_primary_backdrop_image_id_idx | 0 | 16 kB | 3968 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_primary_backdrop_image_id_idx"; |
| core | shows | core_shows_primary_logo_image_id_idx | 0 | 8192 bytes | 3968 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_primary_logo_image_id_idx"; |
| core | shows | core_shows_primary_poster_image_id_idx | 0 | 16 kB | 3968 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_primary_poster_image_id_idx"; |
| core | shows | core_shows_streaming_providers_gin | 0 | 104 kB | 3968 kB | supabase/migrations/0037_collapse_show_attributes.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_streaming_providers_gin"; |
| core | shows | core_shows_tags_gin | 0 | 88 kB | 3968 kB | supabase/migrations/0037_collapse_show_attributes.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_tags_gin"; |
| core | shows | core_shows_tmdb_network_ids_gin | 0 | 32 kB | 3968 kB | supabase/migrations/0047_add_show_source_metadata.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_tmdb_network_ids_gin"; |
| core | shows | core_shows_tmdb_production_company_ids_gin | 0 | 32 kB | 3968 kB | supabase/migrations/0047_add_show_source_metadata.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "core"."core_shows_tmdb_production_company_ids_gin"; |
