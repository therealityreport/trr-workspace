# Unused Index Owner Packet - survey/public app owner

Status: reviewed. `2` flashback gameplay indexes approved and dropped on 2026-04-28; `37` survey/public rows remain owner-review only.

Approval requirements:

- Set `approved_to_drop=yes` only after route/job review.
- Fill `approval_reason`, `approved_by`, `reviewed_routes_or_jobs`, and `stats_window_checked_at`.
- Keep the generated `rollback_sql`; it was captured from `pg_get_indexdef` for this live index.
- Do not approve rows whose workload has not had a meaningful stats window, unless the owner records an urgent approval reason.

Candidate count: `39`.

Full rollback SQL is in the companion CSV.

## Review Evidence

- Production stats window: `pg_stat_database.stats_reset = 2025-12-05 20:00:25.270075+00`.
- Live flashback row counts checked on `2026-04-28T05:37:38Z`: `public.flashback_sessions=0`, `public.flashback_user_stats=0`, while quiz/event setup content was retained.
- Owner direction: flashback gameplay is not set up yet, so remove the empty gameplay write path for now rather than retaining session indexes.
- The two approved index drops first reduced unused-index findings but introduced one `unindexed_foreign_keys` finding on the empty session table. Follow-up DDL removed `public.flashback_sessions`, `public.flashback_user_stats`, and the three flashback gameplay RPC helpers while keeping `public.flashback_quizzes` and `public.flashback_events`.
- Post-removal Management API Advisor recheck reports only `unused_index=350`.
- Targeted backend validation after removal: `23 passed in 0.90s`.
- Targeted app validation after removal: `14 passed in 1.64s` for flashback disabled/admin routes and no-runtime-DDL guard.
- Deferred survey/public rows remain active app/backend query surfaces, FK helpers, response-table filters, or Supabase-auth survey RPC support and are not approved by this packet.

## Approved Rows

| schema | table | index | idx_scan | index_size | table_size | migration_path | approved_to_drop | drop_sql |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| public | flashback_sessions | idx_flashback_sessions_quiz | 0 | 8192 bytes | 40 kB |  | yes | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_flashback_sessions_quiz"; |
| public | flashback_sessions | idx_flashback_sessions_user | 0 | 8192 bytes | 40 kB |  | yes | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_flashback_sessions_user"; |

## Deferred Rows

| schema | table | index | idx_scan | index_size | table_size | migration_path | approved_to_drop | drop_sql |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| firebase_surveys | answers | idx_firebase_answers_response | 0 | 8192 bytes | 48 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "firebase_surveys"."idx_firebase_answers_response"; |
| firebase_surveys | responses | idx_firebase_responses_user | 0 | 8192 bytes | 40 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "firebase_surveys"."idx_firebase_responses_user"; |
| firebase_surveys | survey_trr_links | idx_survey_trr_links_season | 0 | 16 kB | 72 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "firebase_surveys"."idx_survey_trr_links_season"; |
| public | survey_cast | idx_survey_cast_display_order | 0 | 8192 bytes | 56 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_cast_display_order"; |
| public | survey_cast | idx_survey_cast_is_alumni | 0 | 8192 bytes | 56 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_cast_is_alumni"; |
| public | survey_cast | idx_survey_cast_status | 0 | 8192 bytes | 56 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_cast_status"; |
| public | survey_cast | idx_survey_cast_survey_id | 0 | 8192 bytes | 56 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_cast_survey_id"; |
| public | survey_episodes | idx_survey_episodes_air_date | 0 | 8192 bytes | 64 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_episodes_air_date"; |
| public | survey_episodes | idx_survey_episodes_is_active | 0 | 8192 bytes | 64 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_episodes_is_active"; |
| public | survey_episodes | idx_survey_episodes_is_current | 0 | 8192 bytes | 64 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_episodes_is_current"; |
| public | survey_episodes | idx_survey_episodes_survey_id | 0 | 8192 bytes | 64 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_episodes_survey_id"; |
| public | survey_global_profile_responses | idx_sgpr_app_username | 0 | 8192 bytes | 40 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_sgpr_app_username"; |
| public | survey_rhop_s10_responses | idx_rhop_s10_app_user_id | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_rhop_s10_app_user_id"; |
| public | survey_rhop_s10_responses | idx_rhop_s10_created_at | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_rhop_s10_created_at"; |
| public | survey_rhop_s10_responses | idx_rhop_s10_season_episode | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_rhop_s10_season_episode"; |
| public | survey_rhoslc_s6_responses | idx_rhoslc_s6_app_username | 0 | 16 kB | 96 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_rhoslc_s6_app_username"; |
| public | survey_rhoslc_s6_responses | idx_rhoslc_s6_show_episode | 0 | 16 kB | 96 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_rhoslc_s6_show_episode"; |
| public | survey_show_seasons | idx_survey_show_seasons_is_active | 0 | 16 kB | 88 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_show_seasons_is_active"; |
| public | survey_show_seasons | idx_survey_show_seasons_is_current | 0 | 8192 bytes | 88 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_show_seasons_is_current"; |
| public | survey_show_seasons | idx_survey_show_seasons_show_id | 0 | 16 kB | 88 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_show_seasons_show_id"; |
| public | survey_shows | idx_survey_shows_is_active | 0 | 16 kB | 96 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_shows_is_active"; |
| public | survey_x_responses | idx_survey_x_app_username | 0 | 8192 bytes | 40 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_x_app_username"; |
| public | survey_x_responses | idx_survey_x_created_at | 0 | 8192 bytes | 40 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_survey_x_created_at"; |
| public | surveys | idx_surveys_air_schedule | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_surveys_air_schedule"; |
| public | surveys | idx_surveys_is_active | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_surveys_is_active"; |
| public | surveys | idx_surveys_show_season | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_surveys_show_season"; |
| public | surveys | idx_surveys_theme | 0 | 16 kB | 120 kB |  | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."idx_surveys_theme"; |
| public | surveys | public_surveys_current_episode_id_idx | 0 | 8192 bytes | 120 kB | supabase/migrations/20260402213000_supabase_connection_index_hardening.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "public"."public_surveys_current_episode_id_idx"; |
| surveys | aggregates | survey_aggregates_question_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_aggregates_question_id_idx"; |
| surveys | aggregates | survey_aggregates_survey_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_aggregates_survey_id_idx"; |
| surveys | answers | survey_answers_question_id_idx | 0 | 8192 bytes | 64 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_answers_question_id_idx"; |
| surveys | answers | survey_answers_response_id_idx | 0 | 8192 bytes | 64 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_answers_response_id_idx"; |
| surveys | answers | survey_answers_survey_id_idx | 0 | 8192 bytes | 64 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_answers_survey_id_idx"; |
| surveys | options | survey_options_question_id_idx | 0 | 8192 bytes | 32 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_options_question_id_idx"; |
| surveys | questions | survey_questions_survey_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_questions_survey_id_idx"; |
| surveys | responses | survey_responses_survey_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_responses_survey_id_idx"; |
| surveys | responses | survey_responses_user_id_idx | 0 | 8192 bytes | 40 kB | supabase/migrations/0001_init.sql | no | DROP INDEX CONCURRENTLY IF EXISTS "surveys"."survey_responses_user_id_idx"; |
