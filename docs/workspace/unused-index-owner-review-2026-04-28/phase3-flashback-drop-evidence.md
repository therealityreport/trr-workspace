# Phase 3 Flashback Gameplay Drop Evidence

Date: 2026-04-28

Scope:

- Dropped approved unused indexes:
  - `public.idx_flashback_sessions_quiz`
  - `public.idx_flashback_sessions_user`
- Removed empty flashback gameplay write path after owner direction that flashback is not set up yet:
  - `public.flashback_sessions`
  - `public.flashback_user_stats`
  - `public.flashback_get_or_create_session(text, uuid)`
  - `public.flashback_save_placement(uuid, jsonb, integer, integer, boolean)`
  - `public.flashback_update_user_stats(text, integer, boolean)`

Retained:

- `public.flashback_quizzes`
- `public.flashback_events`
- Backend migration: `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428113000_remove_flashback_gameplay_write_path.sql`

Live pre-check:

- `public.flashback_quizzes`: `1` row
- `public.flashback_events`: `7` rows
- `public.flashback_sessions`: `0` rows
- `public.flashback_user_stats`: `0` rows

Execution:

- `phase3-survey-public-approved-drops.sql` executed two `DROP INDEX CONCURRENTLY` statements.
- `phase3-flashback-gameplay-removal.sql` removed the empty gameplay tables and RPC helpers.
- `to_regclass(...)` verified `public.flashback_sessions` and `public.flashback_user_stats` are absent.
- `pg_proc` lookup verified no `public.flashback_%` RPC helpers remain.

Validation:

- Backend targeted tests after removal: `23 passed in 0.90s`.
- App targeted tests after removal: `14 passed in 1.64s`.
- Management API Performance Advisor recheck: `/tmp/trr-performance-advisor-after-phase3-flashback-gameplay-removal-20260428.json`.
- Advisor result after removal: `unused_index=350`, total findings `350`; no `unindexed_foreign_keys` finding remains.

Rollback:

- Index rollback SQL is captured in `survey-public-app-owner.csv` and `phase3-survey-public-approved-drops.sql`.
- Table/RPC rollback SQL and source migration pointers are captured in `phase3-flashback-gameplay-removal.sql`.
