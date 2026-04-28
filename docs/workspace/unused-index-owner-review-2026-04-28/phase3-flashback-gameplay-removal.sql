-- Phase 3 flashback gameplay removal.
-- Owner approval: Thomas Hulihan via Codex, 2026-04-28.
-- Reason: Flashback gameplay is not set up yet; live gameplay tables are empty.
-- Scope: remove the empty session/stat write path that created a new unindexed FK lint
-- after dropping unused flashback session indexes. Keep quiz/event setup content.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

drop function if exists public.flashback_get_or_create_session(text, uuid);
drop function if exists public.flashback_save_placement(uuid, jsonb, integer, integer, boolean);
drop function if exists public.flashback_update_user_stats(text, integer, boolean);

drop table if exists public.flashback_user_stats;
drop table if exists public.flashback_sessions;

commit;

-- Rollback SQL:
--
-- create table if not exists public.flashback_sessions (
--   id uuid primary key default gen_random_uuid(),
--   user_id text not null,
--   quiz_id uuid not null references public.flashback_quizzes(id) on delete cascade,
--   current_round integer not null default 0,
--   score integer not null default 0,
--   placements jsonb not null default '[]'::jsonb,
--   completed boolean not null default false,
--   started_at timestamptz not null default now(),
--   completed_at timestamptz,
--   unique (user_id, quiz_id)
-- );
--
-- create table if not exists public.flashback_user_stats (
--   user_id text primary key,
--   games_played integer not null default 0,
--   total_points integer not null default 0,
--   perfect_scores integer not null default 0,
--   current_streak integer not null default 0,
--   max_streak integer not null default 0,
--   updated_at timestamptz not null default now()
-- );
--
-- alter table public.flashback_sessions enable row level security;
-- alter table public.flashback_user_stats enable row level security;
--
-- create policy "own_sessions" on public.flashback_sessions for all using (true);
-- create policy "own_stats" on public.flashback_user_stats for all using (true);
--
-- grant all on public.flashback_sessions to anon, authenticated, service_role;
-- grant all on public.flashback_user_stats to anon, authenticated, service_role;
--
-- Reapply public.flashback_get_or_create_session, public.flashback_save_placement,
-- and public.flashback_update_user_stats from:
-- TRR-Backend/supabase/migrations/20260330195500_add_flashback_atomic_rpc_helpers.sql
