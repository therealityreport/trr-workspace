# Phase 3 Admin Tooling Drop Evidence - 2026-04-28

Status: complete for the approved admin-tooling batch.

## Approval Scope

- Owner packet: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/admin-tooling-owner.csv`
- Approved rows: `12`
- Deferred rows: `7`
- Approved-only SQL: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-admin-approved-drops.sql`

The deferred rows were left in owner review because they support active route filters, runtime-created indexes, FK helper paths, reddit season/community filters, or owner-grouping paths.

## Live Evidence

- `pg_stat_database.stats_reset`: `2025-12-05 20:00:25.270075+00`
- Pre-drop targeted backend validation: `250 passed in 68.02s`
- Live DDL: `12` `DROP INDEX CONCURRENTLY` statements executed from the admin-only approved SQL file.
- Post-drop `to_regclass(...)`: null for all `12` approved admin indexes.
- Post-drop targeted backend validation: `250 passed in 68.12s`
- Performance Advisor recheck: `/tmp/trr-performance-advisor-after-phase3-admin-20260428.json`
- Advisor result after this batch: `unused_index=352`, total `352`

## Post-Drop Plan Checks

Representative live `EXPLAIN (ANALYZE, BUFFERS)` checks still used retained access paths:

- `admin.brand_logo_assets` list path used `brand_logo_assets_target_idx`.
- `admin.network_streaming_logo_assets` detail path used `network_streaming_logo_assets_entity_idx`.
- `admin.cast_photo_people_tags` photo-id path used `idx_cast_photo_people_tags_cast_source`.
- `admin.person_cover_photos` person lookup used `person_cover_photos_pkey`.
- `admin.network_streaming_discovery_state` lookup used `network_streaming_discovery_state_pkey`.
- `admin.season_cast_survey_roles` show/season lookup fell back to `season_cast_survey_roles_trr_show_id_season_number_person_i_key`.

## Refreshed Phase 2 Report

- Report: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`
- CSV: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.csv`
- Rows: `1308`
- `drop_review_required`: `260`
- `excluded`: `781`
- `defer:idx_scan_nonzero`: `267`

Remaining `drop_review_required` owner counts:

| owner | remaining |
| --- | ---: |
| admin tooling owner | 6 |
| catalog/media owner | 68 |
| screenalytics/ml owner | 47 |
| social data/backfill owner | 100 |
| survey/public app owner | 39 |
