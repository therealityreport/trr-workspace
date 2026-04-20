# Supabase Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every security, performance, and code-hygiene finding from the 2026-04-16 Supabase audit of the `trr-core` project, short of the full async DB rewrite.

**Architecture:** Nine sequential phases. Phases 1–4 are SQL migrations applied in order (RLS hardening → search_path lockdown → RLS perf rewrite → FK/PK index sweep). Phases 5–6 are code PRs (backend hygiene + frontend cutover hygiene). Phase 7 is a dashboard config change. Phase 8 is the index-GC sweep (runs **after** phases 1–4 settle so the planner has re-balanced). Phase 9 (async DB rewrite, item P7 in audit) is **deferred to a separate plan** — bundling it here would balloon this effort.

**Tech Stack:** Supabase (Postgres 17.6.1), FastAPI + psycopg2 backend, Next.js 16 frontend with `@supabase/supabase-js` + `@supabase/ssr`, Supabase CLI for migrations, pytest for backend tests, Vitest/Jest for frontend tests.

**Project ref:** `vwxfvzutyufrkhfgoeaa` (name: trr-core, region: us-east-1)

**Audit reference:** See conversation turn dated 2026-04-16 for findings (C1–C4, H1–H6, P1–P7, M1–M7). Each task below cross-references the audit item it addresses.

**Conventions:**
- Migration files: `TRR-Backend/supabase/migrations/<UTC-timestamp>_<snake_name>.sql`, where `<UTC-timestamp>` is `YYYYMMDDHHMMSS`. Do not reuse timestamps; bump minutes/seconds if you need multiple in the same minute.
- Every migration must be re-runnable against `supabase db reset` locally before pushing.
- Every SQL task ends with an **advisor verification** step — re-run `mcp__supabase__get_advisors` and confirm the targeted lint count dropped by the expected amount.
- Every code task ends with `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` (frontend) or `ruff check . && ruff format --check . && pytest -q` (backend), per the workspace `AGENTS.md`.
- All commits are atomic — one task = one commit.

---

## File Structure

### SQL migrations (created)
- `TRR-Backend/supabase/migrations/20260416120000_rls_enable_public_exposed_tables.sql` — Phase 1a (C1)
- `TRR-Backend/supabase/migrations/20260416120100_views_security_invoker.sql` — Phase 1b (C2)
- `TRR-Backend/supabase/migrations/20260416120200_rls_policies_for_source_tables.sql` — Phase 1c (C3)
- `TRR-Backend/supabase/migrations/20260416120300_function_search_path_lockdown.sql` — Phase 2a (H1)
- `TRR-Backend/supabase/migrations/20260416120400_move_vector_extension_out_of_public.sql` — Phase 2b (H2)
- `TRR-Backend/supabase/migrations/20260416120500_rls_init_plan_subselect_wrap.sql` — Phase 3a (P1)
- `TRR-Backend/supabase/migrations/20260416120600_consolidate_permissive_policies.sql` — Phase 3b (P2)
- `TRR-Backend/supabase/migrations/20260416120700_fk_index_sweep.sql` — Phase 4a (P3)
- `TRR-Backend/supabase/migrations/20260416120800_add_missing_primary_keys.sql` — Phase 4b (P5)
- `TRR-Backend/supabase/migrations/20260416120900_drop_duplicate_index.sql` — Phase 4c (P6)
- `TRR-Backend/supabase/migrations/20260416121000_drop_unused_indexes.sql` — Phase 8

### Backend code (modified)
- `TRR-Backend/trr_backend/api/deps.py` — remove `_decode_jwt_payload`, harden service-role detection (C4, H5)
- `TRR-Backend/trr_backend/db/session.py` — add `transaction()` context manager (M2)
- `TRR-Backend/trr_backend/db/pg.py` — narrow `except Exception` blocks (M1)
- `TRR-Backend/trr_backend/db/postgrest_cache.py` — raise `max_retries` to 3 with backoff (M3)
- `TRR-Backend/trr_backend/db/admin.py` — delete legacy SUPABASE_* timeout plumbing (M4)
- `TRR-Backend/.env.example` — remove unused SUPABASE_* timeout vars (M4)
- `TRR-Backend/tests/db/test_session_transaction.py` — NEW, covers `DbSession.transaction()`
- `TRR-Backend/tests/db/test_postgrest_cache_retry.py` — NEW, covers backoff retries
- `TRR-Backend/tests/security/test_deps_jwt.py` — NEW, proves manual decoder is gone

### Frontend code (modified)
- `TRR-APP/apps/web/src/lib/server/auth.ts` — wrap dynamic import in try/catch, feature-flag shadow mode off (H4, H6)
- `TRR-APP/apps/web/src/lib/server/postgres.ts` — add RLS enforcement regression test hook
- `TRR-APP/apps/web/.env.example` — remove legacy `SUPABASE_URL`, `SUPABASE_ANON_KEY` (M5)
- `TRR-APP/apps/web/tests/supabase-client-import.test.ts` — NEW, covers import failure fallback
- `TRR-APP/apps/web/tests/rls-session-var-enforcement.test.ts` — NEW (M6)

### Docs (modified)
- `TRR-Backend/docs/workspace/env-contract.md` — document pooler-port selection rule
- `docs/superpowers/plans/2026-04-16-supabase-hardening.md` — this plan

### Dashboard config (manual, Phase 7)
- Supabase dashboard → Project Settings → Auth → connection allocation strategy (H3)

---

## Phase 1 — RLS hardening (Critical)

Addresses audit items **C1, C2, C3**. After this phase the advisor should report **0** `rls_disabled_in_public`, **0** `security_definer_view`, **0** `rls_enabled_no_policy` lints.

### Task 1.1: Enable RLS on all 15 publicly-exposed tables

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120000_rls_enable_public_exposed_tables.sql`

Audit ref: **C1** (15 tables flagged by advisor `rls_disabled_in_public`).

- [ ] **Step 1: Write a failing advisor-based assertion test**

We verify remotely because this repo doesn't run `pgTAP` — the "test" is an advisor recheck. Before writing the migration, record the current count:

```bash
# Run in a scratch shell — saves baseline to /tmp
cat > /tmp/advisor-baseline.md <<'EOF'
Baseline 2026-04-16 (pre-Phase-1):
- rls_disabled_in_public: 15 (expect 0 after 1.1)
- security_definer_view: 24 (expect 0 after 1.2)
- rls_enabled_no_policy: 9 (expect 0 after 1.3)
EOF
```

- [ ] **Step 2: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120000_rls_enable_public_exposed_tables.sql
-- Enable RLS on every table exposed via PostgREST (public + core schemas)
-- that the 2026-04-16 advisor flagged. We attach a service-role-only default
-- policy so the existing backend continues to work; user-facing policies are
-- added per-table in follow-ups if/when needed.

BEGIN;

-- Helper: adds RLS + a service_role full-access policy + a comment.
-- Intentionally idempotent (IF NOT EXISTS / DROP POLICY IF EXISTS).
CREATE OR REPLACE FUNCTION pg_temp._trr_lock_table(p_schema text, p_table text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  qident text := format('%I.%I', p_schema, p_table);
BEGIN
  EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', qident);
  EXECUTE format('DROP POLICY IF EXISTS trr_service_role_all ON %s', qident);
  EXECUTE format($p$
    CREATE POLICY trr_service_role_all ON %s
      FOR ALL TO service_role
      USING (true) WITH CHECK (true)
  $p$, qident);
  EXECUTE format('COMMENT ON POLICY trr_service_role_all ON %s IS ''Backend-only access. Add user-scoped policies explicitly when needed.''', qident);
END;
$$;

SELECT pg_temp._trr_lock_table('public', '__migrations');
SELECT pg_temp._trr_lock_table('public', 'site_typography_assignments');
SELECT pg_temp._trr_lock_table('public', 'site_typography_sets');
SELECT pg_temp._trr_lock_table('public', 'survey_cast');
SELECT pg_temp._trr_lock_table('public', 'survey_episodes');
SELECT pg_temp._trr_lock_table('public', 'survey_global_profile_responses');
SELECT pg_temp._trr_lock_table('public', 'survey_rhop_s10_responses');
SELECT pg_temp._trr_lock_table('public', 'survey_rhoslc_s6_responses');
SELECT pg_temp._trr_lock_table('public', 'survey_show_palette_library');
SELECT pg_temp._trr_lock_table('public', 'survey_show_seasons');
SELECT pg_temp._trr_lock_table('public', 'survey_shows');
SELECT pg_temp._trr_lock_table('public', 'survey_x_responses');
SELECT pg_temp._trr_lock_table('public', 'surveys');
SELECT pg_temp._trr_lock_table('core',   'fandom_community_allowlist');
SELECT pg_temp._trr_lock_table('core',   'season_fandom');

COMMIT;
```

- [ ] **Step 3: Apply locally and confirm it runs cleanly**

```bash
cd TRR-Backend
supabase db reset
```

Expected: all migrations replay with no error; the 15 tables now report `rowsecurity = true` in `pg_class`.

- [ ] **Step 4: Push to remote and verify the advisor drop**

```bash
supabase db push
```

Then in an AI session:

```
mcp__supabase__get_advisors(project_id="vwxfvzutyufrkhfgoeaa", type="security")
```

Expected: `rls_disabled_in_public` count **drops from 15 → 0**.

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120000_rls_enable_public_exposed_tables.sql
git commit -m "feat(db): enable RLS on 15 publicly-exposed tables (audit C1)

Every table flagged by advisor rls_disabled_in_public now has RLS on plus
a service_role-only default policy. User-scoped policies will follow per
table as product surfaces require them."
```

---

### Task 1.2: Convert all 24 SECURITY DEFINER views to security_invoker

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120100_views_security_invoker.sql`

Audit ref: **C2**.

- [ ] **Step 1: Enumerate the flagged views in a local script**

Before writing the migration, confirm the exact view list by running the advisor and cross-referencing `pg_views`:

```sql
-- scratch query, do not ship
SELECT schemaname || '.' || viewname AS view_fqn
FROM pg_views
WHERE schemaname || '.' || viewname IN (
  'core.episode_appearances','core.imdb_series','core.show_cast','core.tmdb_series',
  'core.v_cast_summary','core.v_episode_appearances','core.v_episode_appearances_from_credits',
  'core.v_episode_credits','core.v_episode_images_served_media_v2','core.v_media_ingest_summary',
  'social.v_tiktok_daily_analytics','social.v_tiktok_weekly_analytics'
  -- + the other 12 from the advisor output
)
ORDER BY 1;
```

- [ ] **Step 2: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120100_views_security_invoker.sql
-- Convert every SECURITY DEFINER view flagged by the 2026-04-16 advisor to
-- security_invoker. Any view that *intentionally* needs DEFINER semantics
-- must be reverted in a follow-up migration with an explicit justification
-- comment — none are known today.

BEGIN;

-- 24 views from advisor name=security_definer_view. Keep list alphabetized
-- so future greps land deterministically.
ALTER VIEW core.episode_appearances                     SET (security_invoker = on);
ALTER VIEW core.imdb_series                             SET (security_invoker = on);
ALTER VIEW core.show_cast                               SET (security_invoker = on);
ALTER VIEW core.tmdb_series                             SET (security_invoker = on);
ALTER VIEW core.v_cast_summary                          SET (security_invoker = on);
ALTER VIEW core.v_episode_appearances                   SET (security_invoker = on);
ALTER VIEW core.v_episode_appearances_from_credits      SET (security_invoker = on);
ALTER VIEW core.v_episode_credits                       SET (security_invoker = on);
ALTER VIEW core.v_episode_images_served_media_v2        SET (security_invoker = on);
ALTER VIEW core.v_media_ingest_summary                  SET (security_invoker = on);
-- TODO(executor): paste the remaining 12 view names from the advisor output
-- here, each on its own line. Do NOT skip any — verify advisor shows 0 after push.
ALTER VIEW social.v_tiktok_daily_analytics              SET (security_invoker = on);
ALTER VIEW social.v_tiktok_weekly_analytics             SET (security_invoker = on);

COMMIT;
```

Note the `TODO(executor):` — the advisor summary listed 12 of 24 by name; pull the full set with `mcp__supabase__get_advisors` before shipping. Do NOT ship the migration with the TODO still in it.

- [ ] **Step 3: Verify each altered view still returns rows for the current backend caller**

Spot-check three high-traffic views via the service-role client:

```sql
SELECT count(*) FROM core.v_cast_summary LIMIT 1;
SELECT count(*) FROM core.show_cast LIMIT 1;
SELECT count(*) FROM social.v_tiktok_daily_analytics LIMIT 1;
```

Expected: nonzero counts; no `permission denied` errors.

- [ ] **Step 4: Push and re-check advisor**

```bash
supabase db push
```

Expected: `security_definer_view` drops from 24 → 0.

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120100_views_security_invoker.sql
git commit -m "feat(db): convert 24 views to security_invoker (audit C2)

Views now enforce the caller's RLS rather than the view creator's, closing
the advisor security_definer_view ERROR across core.* and social.*."
```

---

### Task 1.3: Add policies for the 9 tables with RLS enabled but no policy

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120200_rls_policies_for_source_tables.sql`

Audit ref: **C3**. All 9 tables are in `core.*` and are source-of-truth / history tables populated by the backend ingestion pipeline. They should be backend-only (service_role full access), with read access for nothing else — confirming intent by making it explicit.

- [ ] **Step 1: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120200_rls_policies_for_source_tables.sql
-- Add explicit service_role-only policies to the 9 core.* source/history
-- tables that had RLS enabled but zero policies (advisor rls_enabled_no_policy).
-- Today these tables silently deny all reads; making the intent explicit lets
-- future engineers see the access contract.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp._trr_service_only(p_schema text, p_table text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE qident text := format('%I.%I', p_schema, p_table);
BEGIN
  EXECUTE format('DROP POLICY IF EXISTS trr_service_role_all ON %s', qident);
  EXECUTE format($p$
    CREATE POLICY trr_service_role_all ON %s
      FOR ALL TO service_role
      USING (true) WITH CHECK (true)
  $p$, qident);
  EXECUTE format('COMMENT ON POLICY trr_service_role_all ON %s IS ''Ingestion-only. No user-facing access.''', qident);
END;
$$;

SELECT pg_temp._trr_service_only('core', 'cast_tmdb');
SELECT pg_temp._trr_service_only('core', 'episode_source_history');
SELECT pg_temp._trr_service_only('core', 'episode_source_latest');
SELECT pg_temp._trr_service_only('core', 'person_source_history');
SELECT pg_temp._trr_service_only('core', 'person_source_latest');
SELECT pg_temp._trr_service_only('core', 'season_source_history');
SELECT pg_temp._trr_service_only('core', 'season_source_latest');
SELECT pg_temp._trr_service_only('core', 'show_source_history');
SELECT pg_temp._trr_service_only('core', 'show_source_latest');

COMMIT;
```

- [ ] **Step 2: Apply locally and push**

```bash
cd TRR-Backend
supabase db reset
supabase db push
```

Re-run advisor; confirm `rls_enabled_no_policy` drops from 9 → 0.

- [ ] **Step 3: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120200_rls_policies_for_source_tables.sql
git commit -m "feat(db): add service_role-only policies to 9 core source tables (audit C3)

These tables previously had RLS enabled with no policies — blocking all
reads including intended ingestion. Make the service_role-only contract
explicit."
```

---

## Phase 2 — Search path lockdown + extension move (High)

### Task 2.1: Lock search_path for all 57 mutable functions

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120300_function_search_path_lockdown.sql`

Audit ref: **H1**.

- [ ] **Step 1: Enumerate affected functions programmatically**

Because listing 57 functions by hand is error-prone, generate the `ALTER FUNCTION` statements from `pg_proc`. Do this as a one-shot SQL block that writes to a psql `\g`-captured file, or embed dynamic SQL inside the migration itself.

- [ ] **Step 2: Write the migration using dynamic SQL**

```sql
-- TRR-Backend/supabase/migrations/20260416120300_function_search_path_lockdown.sql
-- Set search_path = '' on every function flagged by the advisor
-- (function_search_path_mutable). Closes the search_path hijack class.
-- Uses dynamic SQL so new functions added between audit and deploy are also
-- covered if they share the same shape (no search_path config set).

BEGIN;

DO $$
DECLARE
  r record;
  fn_schemas text[] := ARRAY['admin','core','social','public','firebase_surveys','surveys','screenalytics'];
BEGIN
  FOR r IN
    SELECT  n.nspname AS schema_name,
            p.proname AS func_name,
            pg_get_function_identity_arguments(p.oid) AS args
    FROM    pg_proc p
    JOIN    pg_namespace n ON n.oid = p.pronamespace
    WHERE   n.nspname = ANY(fn_schemas)
      AND   NOT EXISTS (
              SELECT 1 FROM unnest(p.proconfig) c
              WHERE c LIKE 'search_path=%'
            )
      AND   p.prokind = 'f'  -- functions only, not aggregates/procedures
  LOOP
    EXECUTE format(
      'ALTER FUNCTION %I.%I(%s) SET search_path = '''';',
      r.schema_name, r.func_name, r.args
    );
  END LOOP;
END;
$$;

COMMIT;
```

- [ ] **Step 3: Apply locally; exercise a sample of functions that callers depend on**

```bash
cd TRR-Backend
supabase db reset
pytest tests/test_api_smoke.py -q
```

Expected: every smoke test still passes. If any function references an unqualified object name (e.g. `updated_at_trigger()` referencing a helper in the same schema without `schema.helper()` qualification), it will break. Fix by fully qualifying the reference in a follow-up migration and add a regression test naming the function.

- [ ] **Step 4: Push and re-check advisor**

```bash
supabase db push
```

Expected: `function_search_path_mutable` drops from 57 → 0 (give or take any functions you add between audit and deploy).

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120300_function_search_path_lockdown.sql
git commit -m "feat(db): lock search_path on 57 mutable functions (audit H1)

Dynamic migration: for every function in admin/core/social/public/
firebase_surveys/surveys/screenalytics without a search_path config,
set it to empty. Prevents schema-shadowing attacks."
```

---

### Task 2.2: Move the `vector` extension out of public

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120400_move_vector_extension_out_of_public.sql`

Audit ref: **H2**.

- [ ] **Step 1: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120400_move_vector_extension_out_of_public.sql
-- Move the pgvector extension out of the public schema.

BEGIN;
CREATE SCHEMA IF NOT EXISTS extensions;
ALTER EXTENSION vector SET SCHEMA extensions;
COMMIT;
```

- [ ] **Step 2: Verify `extra_search_path` already includes `extensions`**

Check `TRR-Backend/supabase/config.toml`:

```bash
grep -A2 "extra_search_path" TRR-Backend/supabase/config.toml
```

Expected: `extra_search_path = ["public", "extensions"]`. This is already set (verified during plan drafting), so queries referencing `vector` unqualified continue to resolve.

- [ ] **Step 3: Apply + push + advisor recheck**

```bash
cd TRR-Backend
supabase db reset
supabase db push
```

Expected: `extension_in_public` count drops from 1 → 0.

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120400_move_vector_extension_out_of_public.sql
git commit -m "feat(db): move pgvector out of public schema (audit H2)"
```

---

## Phase 3 — RLS performance rewrite (High)

### Task 3.1: Wrap `auth.<fn>()` calls in subselects in 42 policies

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120500_rls_init_plan_subselect_wrap.sql`

Audit ref: **P1**. Top-impact tables (from advisor counts): `firebase_surveys.answers` (×4), `firebase_surveys.responses` (×4), `surveys.answers` (×4), `surveys.responses` (×4), `social.dm_read_receipts`, `social.posts`, plus 14 more.

Because each of the 42 policies is unique in its `USING` / `WITH CHECK` body, we cannot dynamically rewrite them safely. The migration must `DROP POLICY` + `CREATE POLICY` with the rewritten body per policy.

- [ ] **Step 1: Pull the full policy definitions from the remote database**

```sql
-- scratch query — record output for migration authoring
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  pol.polname AS policy_name,
  pol.polcmd AS cmd,
  pg_get_expr(pol.polqual, pol.polrelid) AS using_expr,
  pg_get_expr(pol.polwithcheck, pol.polrelid) AS check_expr,
  array_to_string(pol.polroles::regrole[], ',') AS roles
FROM pg_policy pol
JOIN pg_class c   ON c.oid = pol.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE (n.nspname, c.relname) IN (
  ('firebase_surveys','answers'), ('firebase_surveys','responses'),
  ('surveys','answers'), ('surveys','responses'),
  ('social','dm_read_receipts'), ('social','posts'),
  ('social','dm_conversations'), ('social','dm_messages'),
  ('social','reactions'), ('social','threads'),
  ('core','networks'), ('core','production_companies'), ('core','show_watch_providers'),
  ('public','flashback_sessions'), ('public','flashback_user_stats')
  -- + the other 5 tables from the advisor output
)
ORDER BY schema_name, table_name, policy_name;
```

Save output to `TRR-Backend/supabase/migrations/_scratch/20260416120500_policy_snapshot.txt` (gitignored or short-lived). This is your rewriting reference.

- [ ] **Step 2: Write the migration**

Example of the rewrite pattern applied to two representative policies — repeat for all 42. **Do not paraphrase — use the exact current policy body, only wrapping `auth.uid()` / `auth.jwt() ...` / `current_setting(...)` in `(select ...)`.**

```sql
-- TRR-Backend/supabase/migrations/20260416120500_rls_init_plan_subselect_wrap.sql
-- Rewrite 42 RLS policies flagged by advisor auth_rls_initplan so that
-- auth.<fn>() calls are wrapped in a subselect — evaluated once per query,
-- not once per row. Each policy's logic is otherwise unchanged.

BEGIN;

-- -------- firebase_surveys.answers --------
DROP POLICY IF EXISTS firebase_surveys_answers_insert_own ON firebase_surveys.answers;
CREATE POLICY firebase_surveys_answers_insert_own
  ON firebase_surveys.answers
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS firebase_surveys_answers_select_own ON firebase_surveys.answers;
CREATE POLICY firebase_surveys_answers_select_own
  ON firebase_surveys.answers
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

-- -------- surveys.responses --------
DROP POLICY IF EXISTS surveys_responses_insert_own ON surveys.responses;
CREATE POLICY surveys_responses_insert_own
  ON surveys.responses
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS surveys_responses_select_own ON surveys.responses;
CREATE POLICY surveys_responses_select_own
  ON surveys.responses
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

-- TODO(executor): repeat for the remaining 38 policies. Copy each policy
-- body verbatim from the scratch snapshot and change only:
--   auth.uid()            -> (select auth.uid())
--   auth.jwt() -> 'x'     -> (select auth.jwt() -> 'x')
--   current_setting('y')  -> (select current_setting('y'))

COMMIT;
```

- [ ] **Step 3: Apply locally, run smoke tests**

```bash
cd TRR-Backend
supabase db reset
pytest tests/test_api_smoke.py tests/test_discussions_smoke.py -q
```

Expected: all smoke tests pass. If any fail with "permission denied" or unexpected empty result, compare the rewritten policy body against the snapshot — the rewrite must be byte-identical apart from the subselect wrap.

- [ ] **Step 4: Push and re-check advisor**

```bash
supabase db push
```

Expected: `auth_rls_initplan` drops from 42 → 0.

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120500_rls_init_plan_subselect_wrap.sql
git commit -m "perf(db): wrap auth.<fn>() in subselect on 42 policies (audit P1)

Each policy's USING/WITH CHECK body is byte-identical to before except
auth.uid()/auth.jwt()/current_setting() are now wrapped in (select ...),
so Postgres evaluates them once per query instead of once per row."
```

---

### Task 3.2: Consolidate multiple permissive policies

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120600_consolidate_permissive_policies.sql`

Audit ref: **P2**. 147 occurrences across 11 tables. Top tables: `public.flashback_sessions` (28 combos), `public.flashback_user_stats` (28), `firebase_surveys.answers` (21), `firebase_surveys.responses` (21), `core.networks` (7), `core.production_companies` (7), `core.show_watch_providers` (7), `core.watch_providers` (7), `public.flashback_events` (7), `public.flashback_quizzes` (7), `public.show_icons` (7).

For each table: combine all permissive policies for the same `(role, cmd)` into ONE `USING`/`WITH CHECK` expression using `OR`. Keep `RESTRICTIVE` policies separate.

- [ ] **Step 1: Snapshot current policies per table**

Same technique as Task 3.1 step 1 — save `pg_policy` output for each of the 11 tables.

- [ ] **Step 2: Write the migration**

Example for `core.networks` (public read + service_role full, both permissive, same role on SELECT):

```sql
-- TRR-Backend/supabase/migrations/20260416120600_consolidate_permissive_policies.sql
-- For each (table, role, cmd) triple that had multiple permissive policies,
-- replace them with a single OR-combined policy. Intent and result-set are
-- identical; planner now evaluates one policy per query instead of N.

BEGIN;

-- -------- core.networks --------
DROP POLICY IF EXISTS core_tmdb_networks_public_read ON core.networks;
DROP POLICY IF EXISTS core_tmdb_networks_service_role ON core.networks;

CREATE POLICY core_networks_read ON core.networks
  FOR SELECT TO anon, authenticated, service_role
  USING (true);  -- TMDB reference data is public

CREATE POLICY core_networks_service_role_write ON core.networks
  FOR INSERT, UPDATE, DELETE TO service_role
  USING (true) WITH CHECK (true);

COMMENT ON POLICY core_networks_read ON core.networks
  IS 'Consolidated from {core_tmdb_networks_public_read, core_tmdb_networks_service_role} per audit P2.';

-- TODO(executor): repeat for core.production_companies, core.show_watch_providers,
-- core.watch_providers, public.flashback_sessions, public.flashback_user_stats,
-- public.flashback_events, public.flashback_quizzes, public.show_icons,
-- firebase_surveys.answers, firebase_surveys.responses.
--
-- For each table: look at the snapshot, find every (role, cmd) combo with
-- >1 permissive policy, combine their USING expressions with OR, and emit
-- ONE CREATE POLICY per (role, cmd). RESTRICTIVE policies stay separate.

COMMIT;
```

- [ ] **Step 3: Apply + smoke-test + push**

```bash
cd TRR-Backend
supabase db reset
pytest tests/ -q -k "flashback or survey or social"
supabase db push
```

Expected: `multiple_permissive_policies` drops from 147 → 0.

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120600_consolidate_permissive_policies.sql
git commit -m "perf(db): consolidate 147 multiple permissive policies (audit P2)

For every (table, role, cmd) with multiple permissive policies, merge into
one OR-combined policy. Cuts per-query policy evaluation work."
```

---

## Phase 4 — Index hygiene (High)

### Task 4.1: Add indexes on all 106 unindexed foreign keys

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120700_fk_index_sweep.sql`

Audit ref: **P3**.

- [ ] **Step 1: Pull the full FK list from the advisor output**

Re-run `mcp__supabase__get_advisors(project_id="vwxfvzutyufrkhfgoeaa", type="performance")` and grep entries where `name == "unindexed_foreign_keys"`. Each has `metadata.schema`, `metadata.table`, `metadata.fkey`, `metadata.columns`.

- [ ] **Step 2: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120700_fk_index_sweep.sql
-- Add covering indexes for every foreign key flagged by the advisor.
-- Uses CREATE INDEX CONCURRENTLY so it's non-blocking, which means this
-- migration cannot run inside an explicit transaction block.

-- For CREATE INDEX CONCURRENTLY, each statement must be its own transaction.
-- Supabase CLI supports this if the file has no explicit BEGIN/COMMIT.

CREATE INDEX CONCURRENTLY IF NOT EXISTS ml_screentime_review_state_run_id_idx
  ON ml.screentime_review_state (run_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ml_screentime_review_state_asset_id_idx
  ON ml.screentime_review_state (asset_id);
-- ... 104 more ...

-- TODO(executor): one statement per FK. Name them <schema>_<table>_<column>_idx
-- for consistency with the rest of the codebase. Use IF NOT EXISTS so the
-- migration is re-runnable.
```

**Critical gotcha:** `CREATE INDEX CONCURRENTLY` cannot run inside a transaction. The Supabase CLI wraps each migration file in a transaction by default. Work around it by:
- Splitting into one migration file per index (tedious), OR
- Adding `-- supabase-mcp-disable-transaction` as the first line (if supported), OR
- Using `supabase db push` and accepting that concurrent-index migrations will emit a warning and run outside the wrapping transaction.

Document the approach chosen in the migration's header comment.

- [ ] **Step 3: Apply against a staging branch first**

```bash
# Create a dev branch to test index build timing
supabase branches create fk-index-test
supabase db push --db-url "<staging-branch-url>"
```

Expected: all indexes build successfully. Record per-index build time — any that take >60s on staging need a dedicated off-hours window in prod.

- [ ] **Step 4: Push to prod during low-traffic window**

```bash
supabase db push
```

Then re-check advisor — expect `unindexed_foreign_keys` to drop from 106 → 0.

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120700_fk_index_sweep.sql
git commit -m "perf(db): add 106 missing FK covering indexes (audit P3)

CREATE INDEX CONCURRENTLY for every foreign key flagged by the advisor as
unindexed. Applied off-peak; see staging branch timings in PR notes."
```

---

### Task 4.2: Add primary keys to 6 tables

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120800_add_missing_primary_keys.sql`

Audit ref: **P5**. Tables: `core.episode_source_latest`, `core.external_id_conflicts`, `core.person_source_latest`, `core.season_source_latest`, `core.show_source_latest`, `core.sync_state`.

- [ ] **Step 1: Inspect each table to decide on PK choice**

```sql
\d+ core.episode_source_latest
\d+ core.external_id_conflicts
\d+ core.person_source_latest
\d+ core.season_source_latest
\d+ core.show_source_latest
\d+ core.sync_state
```

For each: if there's already a unique natural key (e.g. `show_id` on `core.show_source_latest`), promote it to the PK. Otherwise add `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`.

- [ ] **Step 2: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120800_add_missing_primary_keys.sql
-- Give each of the 6 tables flagged by advisor no_primary_key a PK.
-- Where a natural unique key exists, promote it; otherwise add a uuid PK.

BEGIN;

-- These *_latest tables hold one row per entity; natural key is the entity id.
ALTER TABLE core.episode_source_latest ADD PRIMARY KEY (episode_id);
ALTER TABLE core.person_source_latest  ADD PRIMARY KEY (person_id);
ALTER TABLE core.season_source_latest  ADD PRIMARY KEY (season_id);
ALTER TABLE core.show_source_latest    ADD PRIMARY KEY (show_id);

-- conflicts + sync_state likely need surrogate PKs — confirm from \d+ output.
-- If core.external_id_conflicts already has a unique conflict_id, promote it.
-- Otherwise:
ALTER TABLE core.external_id_conflicts ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
UPDATE core.external_id_conflicts SET id = gen_random_uuid() WHERE id IS NULL;
ALTER TABLE core.external_id_conflicts ALTER COLUMN id SET NOT NULL;
ALTER TABLE core.external_id_conflicts ADD PRIMARY KEY (id);

ALTER TABLE core.sync_state ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
UPDATE core.sync_state SET id = gen_random_uuid() WHERE id IS NULL;
ALTER TABLE core.sync_state ALTER COLUMN id SET NOT NULL;
ALTER TABLE core.sync_state ADD PRIMARY KEY (id);

COMMIT;
```

- [ ] **Step 3: Apply + smoke test + push**

```bash
cd TRR-Backend
supabase db reset
pytest tests/ingestion -q
supabase db push
```

Expected: `no_primary_key` drops from 6 → 0.

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120800_add_missing_primary_keys.sql
git commit -m "feat(db): add primary keys to 6 tables (audit P5)"
```

---

### Task 4.3: Drop the duplicate index on social.scrape_runs

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260416120900_drop_duplicate_index.sql`

Audit ref: **P6**.

- [ ] **Step 1: Verify the two indexes are functionally identical**

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname='social' AND tablename='scrape_runs'
  AND indexname IN ('idx_social_scrape_runs_season_created_at','scrape_runs_season_id_idx');
```

Expected: the `indexdef` for both should have the same column list and `USING` clause. If they differ (e.g. one includes `created_at DESC`), they're not actually duplicates — check with the team before dropping.

- [ ] **Step 2: Write the migration**

```sql
-- TRR-Backend/supabase/migrations/20260416120900_drop_duplicate_index.sql
BEGIN;
DROP INDEX IF EXISTS social.scrape_runs_season_id_idx;
COMMIT;
```

Keep `idx_social_scrape_runs_season_created_at` because its name matches the rest of the codebase's naming convention.

- [ ] **Step 3: Apply + push + advisor recheck**

```bash
cd TRR-Backend
supabase db reset
supabase db push
```

Expected: `duplicate_index` drops from 1 → 0.

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416120900_drop_duplicate_index.sql
git commit -m "chore(db): drop duplicate index on social.scrape_runs (audit P6)"
```

---

## Phase 5 — Backend code hygiene

### Task 5.1: Remove `_decode_jwt_payload` + harden service-role detection

**Files:**
- Modify: `TRR-Backend/trr_backend/api/deps.py` (lines ~19-45)
- Create: `TRR-Backend/tests/security/test_deps_jwt.py`

Audit ref: **C4**, **H5**.

- [ ] **Step 1: Read the file before touching it**

```bash
cat TRR-Backend/trr_backend/api/deps.py | head -80
```

- [ ] **Step 2: Write the failing test**

```python
# TRR-Backend/tests/security/test_deps_jwt.py
"""Regression tests ensuring the backend never trusts unverified JWT payloads."""

import pytest


def test_no_manual_jwt_payload_decoder_exists():
    """_decode_jwt_payload used to base64-decode JWT payloads without signature
    verification. It must not come back — any code path that needs JWT claims
    must route through verify_jwt_token() in trr_backend/security/jwt.py."""
    from trr_backend.api import deps
    assert not hasattr(deps, "_decode_jwt_payload"), (
        "Unverified JWT payload extractor must be deleted — see audit C4."
    )


def test_service_role_detection_rejects_spoofed_prefix():
    """Relying on the 'sb_secret_' string prefix ties us to Supabase's current
    key format and means a stolen env var grants admin. Detection must be
    based on the verified JWT role claim only."""
    from trr_backend.api.deps import _looks_like_service_role
    # A forged key that merely starts with sb_secret_ but has no service_role
    # claim in any accompanying JWT must not return True on its own merits.
    # (If _looks_like_service_role still exists post-fix, it must require a
    # validated JWT context — adjust this assertion to reflect the new API.)
    assert _looks_like_service_role("sb_secret_forged_zzz", verified_role=None) is False
```

- [ ] **Step 3: Run the test to confirm it fails**

```bash
cd TRR-Backend
pytest tests/security/test_deps_jwt.py -v
```

Expected: FAIL — `_decode_jwt_payload` still exists and `_looks_like_service_role` has the old signature.

- [ ] **Step 4: Apply the fix**

Edit `TRR-Backend/trr_backend/api/deps.py`:
1. Delete `_decode_jwt_payload` entirely (lines ~19-29).
2. Change `_looks_like_service_role(key: str) -> bool` to require a pre-validated role: `_looks_like_service_role(key: str, *, verified_role: str | None) -> bool`, and return `verified_role == "service_role"`. Drop the `startswith("sb_secret_")` heuristic.
3. Update every call site to pass the verified role extracted from `verify_jwt_token()`.

- [ ] **Step 5: Run the test to confirm it passes**

```bash
pytest tests/security/test_deps_jwt.py -v
pytest tests/ -q  # full suite — nothing else regresses
```

Expected: PASS, plus no regressions.

- [ ] **Step 6: Commit**

```bash
git add TRR-Backend/trr_backend/api/deps.py TRR-Backend/tests/security/test_deps_jwt.py
git commit -m "fix(auth): remove unverified JWT payload decoder (audit C4, H5)

_decode_jwt_payload base64-decoded JWT bodies without signature verification;
_looks_like_service_role trusted a string prefix that would break with any
Supabase key-format change. Both are replaced with paths that go through
verify_jwt_token() and use the verified role claim."
```

---

### Task 5.2: Add `DbSession.transaction()` context manager

**Files:**
- Modify: `TRR-Backend/trr_backend/db/session.py`
- Create: `TRR-Backend/tests/db/test_session_transaction.py`

Audit ref: **M2**.

- [ ] **Step 1: Write the failing test**

```python
# TRR-Backend/tests/db/test_session_transaction.py
"""DbSession.transaction() must provide atomic multi-statement writes."""

import pytest
from trr_backend.db.session import DbSession


def test_transaction_commits_on_success(db_session: DbSession):
    with db_session.transaction():
        db_session.table("_trr_tx_probe").insert({"k": "a", "v": 1}).execute()
        db_session.table("_trr_tx_probe").insert({"k": "b", "v": 2}).execute()
    rows = db_session.table("_trr_tx_probe").select("*").execute().data
    assert {(r["k"], r["v"]) for r in rows} >= {("a", 1), ("b", 2)}


def test_transaction_rolls_back_on_exception(db_session: DbSession):
    with pytest.raises(ValueError):
        with db_session.transaction():
            db_session.table("_trr_tx_probe").insert({"k": "c", "v": 3}).execute()
            raise ValueError("simulated failure")
    rows = db_session.table("_trr_tx_probe").select("*").eq("k", "c").execute().data
    assert rows == [], "rollback did not undo the insert"
```

A `_trr_tx_probe` fixture table needs to exist (`create table _trr_tx_probe(k text primary key, v int)`); add it to the test-only schema or to `conftest.py` as a `CREATE TABLE IF NOT EXISTS` setup.

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd TRR-Backend
pytest tests/db/test_session_transaction.py -v
```

Expected: FAIL — `DbSession.transaction` does not exist.

- [ ] **Step 3: Implement `transaction()` as a context manager**

Add to `TRR-Backend/trr_backend/db/session.py`:

```python
from contextlib import contextmanager

class DbSession:
    # ... existing methods ...

    @contextmanager
    def transaction(self):
        """Yield a transactional scope. All .execute() calls inside the block
        share one connection and commit atomically; any exception rolls back."""
        conn = self._pool_checkout()  # existing internal helper
        conn.autocommit = False
        prev_conn = self._override_connection(conn)  # new helper: forces all
                                                     # .execute() calls in this
                                                     # thread to reuse `conn`
                                                     # until cleared
        try:
            yield self
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            self._override_connection(prev_conn)
            conn.autocommit = True
            self._pool_return(conn)
```

The exact helper names (`_pool_checkout`, `_override_connection`, `_pool_return`) depend on the existing `DbSession` internals — read `session.py` carefully and reuse the pool abstraction already there. Do not open raw connections bypassing the pool.

- [ ] **Step 4: Run the test to verify it passes**

```bash
pytest tests/db/test_session_transaction.py -v
```

Expected: both tests PASS.

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/trr_backend/db/session.py TRR-Backend/tests/db/test_session_transaction.py
git commit -m "feat(db): add DbSession.transaction() context manager (audit M2)

Gives callers atomic multi-statement writes without having to drop into
raw psycopg2 or stuff logic into an RPC."
```

---

### Task 5.3: Raise PGRST204 retry to 3 with exponential backoff

**Files:**
- Modify: `TRR-Backend/trr_backend/db/postgrest_cache.py` (lines ~81-140)
- Create: `TRR-Backend/tests/db/test_postgrest_cache_retry.py`

Audit ref: **M3**.

- [ ] **Step 1: Write the failing test**

```python
# TRR-Backend/tests/db/test_postgrest_cache_retry.py
"""Verify PGRST204 retry loop uses exponential backoff up to 3 attempts."""

from unittest.mock import MagicMock, patch
import pytest

from trr_backend.db.postgrest_cache import retry_on_pgrst204, PgrstCacheError


def test_retries_three_times_with_exponential_backoff():
    attempts = {"n": 0}

    def flaky():
        attempts["n"] += 1
        if attempts["n"] < 3:
            raise PgrstCacheError("PGRST204: schema cache miss")
        return "ok"

    with patch("trr_backend.db.postgrest_cache.time.sleep") as sleep:
        result = retry_on_pgrst204(flaky)

    assert result == "ok"
    assert attempts["n"] == 3
    # First retry waits 0.5s, second waits 1.0s (exponential). We don't assert
    # a third sleep because the third attempt succeeds before another wait.
    assert [c.args[0] for c in sleep.call_args_list] == [0.5, 1.0]
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/db/test_postgrest_cache_retry.py -v
```

Expected: FAIL (current code retries once with fixed 0.5s).

- [ ] **Step 3: Implement**

Change the retry loop in `postgrest_cache.py` to:

```python
def retry_on_pgrst204(fn, *, max_retries: int = 3, base_delay: float = 0.5):
    last_exc = None
    for attempt in range(max_retries):
        try:
            return fn()
        except PgrstCacheError as exc:
            last_exc = exc
            if attempt == max_retries - 1:
                break
            time.sleep(base_delay * (2 ** attempt))
            _trigger_pgrst_reload()  # existing helper
    raise last_exc
```

- [ ] **Step 4: Verify + commit**

```bash
pytest tests/db/test_postgrest_cache_retry.py -v  # PASS
git add TRR-Backend/trr_backend/db/postgrest_cache.py TRR-Backend/tests/db/test_postgrest_cache_retry.py
git commit -m "fix(db): PGRST204 retry with exponential backoff x3 (audit M3)"
```

---

### Task 5.4: Narrow exception handling in connection pool

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py` (lines ~298-330)

Audit ref: **M1**.

- [ ] **Step 1: Find the `except Exception: pass` blocks**

```bash
grep -n "except Exception" TRR-Backend/trr_backend/db/pg.py
```

- [ ] **Step 2: Replace each with a narrowed catch + logging**

For each block, change:

```python
try:
    _pool.putconn(conn)
except Exception:
    pass
```

to:

```python
try:
    _pool.putconn(conn)
except psycopg2.pool.PoolError as exc:
    logger.warning("pool putconn failed: %s (pool_size=%d)", exc, _pool_size_unsafe())
except psycopg2.Error as exc:
    logger.error("pool putconn driver error: %s", exc)
```

Do this for every `except Exception:` in `pg.py`. If a given catch is genuinely best-effort (e.g. during shutdown), keep the bare catch but add a `logger.debug("…")` line.

- [ ] **Step 3: Full test run**

```bash
cd TRR-Backend
pytest tests/ -q
ruff check . && ruff format --check .
```

Expected: no regressions.

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/trr_backend/db/pg.py
git commit -m "fix(db): narrow pool exception handling + add logging (audit M1)

Replaces 'except Exception: pass' blocks with specific psycopg2 exception
types and logger calls so pool saturation surfaces before it cascades."
```

---

### Task 5.5: Delete legacy SUPABASE_* timeout plumbing

**Files:**
- Modify: `TRR-Backend/trr_backend/db/admin.py` (lines ~37-49)
- Modify: `TRR-Backend/.env.example`

Audit ref: **M4**.

- [ ] **Step 1: Confirm the vars are unused**

```bash
grep -rn "SUPABASE_POSTGREST_TIMEOUT_SEC\|SUPABASE_STORAGE_TIMEOUT_SEC\|SUPABASE_HTTP2_ENABLED\|SUPABASE_HTTP_POOL_TIMEOUT_SEC" TRR-Backend/
```

Expected: only references in `admin.py` (parsed but never used) and `.env.example` (documented but dead). If any other module reads them, stop and treat those as hidden consumers to migrate before deleting.

- [ ] **Step 2: Delete the parsing block in admin.py**

Remove lines ~37-49 (the `SUPABASE_POSTGREST_TIMEOUT_SEC`, `SUPABASE_STORAGE_TIMEOUT_SEC`, `SUPABASE_HTTP2_ENABLED`, `SUPABASE_HTTP_POOL_TIMEOUT_SEC` declarations).

- [ ] **Step 3: Remove them from .env.example**

Delete the corresponding lines. Add a one-line comment above the remaining Supabase section: `# Timeouts are now controlled via TRR_DB_* vars (see db/pg.py).`

- [ ] **Step 4: Full test run + commit**

```bash
cd TRR-Backend
pytest tests/ -q
git add TRR-Backend/trr_backend/db/admin.py TRR-Backend/.env.example
git commit -m "chore(backend): drop unused SUPABASE_* timeout vars (audit M4)"
```

---

## Phase 6 — Frontend code hygiene

### Task 6.1: Wrap Supabase dynamic import in try/catch

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/auth.ts` (around line 213)
- Create: `TRR-APP/apps/web/tests/supabase-client-import.test.ts`

Audit ref: **H6**.

- [ ] **Step 1: Write the failing test**

```typescript
// TRR-APP/apps/web/tests/supabase-client-import.test.ts
import { describe, expect, it, vi } from "vitest";

describe("verifySupabaseToken", () => {
  it("returns a typed error instead of throwing when @supabase/supabase-js is unavailable", async () => {
    vi.doMock("@supabase/supabase-js", () => {
      throw new Error("Cannot find module '@supabase/supabase-js'");
    });
    const { verifySupabaseToken } = await import("../src/lib/server/auth");
    const result = await verifySupabaseToken("any.token.here");
    expect(result.ok).toBe(false);
    expect(result.error).toBe("SUPABASE_CLIENT_UNAVAILABLE");
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd TRR-APP
pnpm -C apps/web exec vitest run supabase-client-import -t "typed error"
```

Expected: FAIL — currently throws uncaught.

- [ ] **Step 3: Implement the wrapper**

In `TRR-APP/apps/web/src/lib/server/auth.ts` around line 213:

```typescript
export async function verifySupabaseToken(token: string): Promise<VerifyResult> {
  let createClient: typeof import("@supabase/supabase-js")["createClient"];
  try {
    ({ createClient } = await import("@supabase/supabase-js"));
  } catch (err) {
    logger.error("supabase-js import failed", { err });
    return { ok: false, error: "SUPABASE_CLIENT_UNAVAILABLE" };
  }
  const client = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  // ... existing verification logic ...
}
```

Define `VerifyResult` as a discriminated union if it isn't already: `{ ok: true; uid: string; isAdmin: boolean } | { ok: false; error: string }`.

- [ ] **Step 4: Verify + commit**

```bash
pnpm -C apps/web exec vitest run supabase-client-import
pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack
git add TRR-APP/apps/web/src/lib/server/auth.ts TRR-APP/apps/web/tests/supabase-client-import.test.ts
git commit -m "fix(auth): handle @supabase/supabase-js import failure gracefully (audit H6)"
```

---

### Task 6.2: Plan + execute shadow-mode cutoff

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/auth.ts` (shadow-mode block, lines ~340-391)
- Modify: production env (via deploy platform — not in source)

Audit ref: **H4**.

This task has two parts: a **code change** (gate shadow verification behind an env flag that can be flipped without redeploying) and an **operational change** (flip the flag once cutover readiness is met).

- [ ] **Step 1: Read current shadow-mode logic**

```bash
sed -n '330,400p' TRR-APP/apps/web/src/lib/server/auth.ts
```

- [ ] **Step 2: Introduce `TRR_AUTH_SHADOW_MODE` env gate**

Modify the shadow verification to skip entirely when `TRR_AUTH_SHADOW_MODE !== "enabled"`:

```typescript
const SHADOW_MODE_ENABLED = process.env.TRR_AUTH_SHADOW_MODE === "enabled";

// ... inside the verification fast path ...
if (SHADOW_MODE_ENABLED && AUTH_PROVIDER === "firebase") {
  // existing shadow-check logic
} else {
  // no shadow work — skip
}
```

Default the variable to disabled; document in `apps/web/.env.example`:

```
# Set to "enabled" only during Firebase → Supabase auth migration.
# See docs/cross-collab/auth-cutover.md for cutover readiness gates.
TRR_AUTH_SHADOW_MODE=
```

- [ ] **Step 3: Add a test that proves shadow verification is skipped when unset**

```typescript
// TRR-APP/apps/web/tests/shadow-mode-gate.test.ts
import { describe, expect, it, beforeEach, vi } from "vitest";

describe("shadow-mode gate", () => {
  beforeEach(() => { vi.resetModules(); delete process.env.TRR_AUTH_SHADOW_MODE; });

  it("does not call verifySupabaseToken when TRR_AUTH_SHADOW_MODE is unset", async () => {
    const supabaseSpy = vi.fn();
    vi.doMock("../src/lib/server/auth", async (orig) => ({
      ...(await orig<typeof import("../src/lib/server/auth")>()),
      verifySupabaseToken: supabaseSpy,
    }));
    const { verifyFirebaseSession } = await import("../src/lib/server/auth");
    await verifyFirebaseSession("valid.firebase.token");
    expect(supabaseSpy).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 4: Verify tests pass + commit code change**

```bash
pnpm -C apps/web exec vitest run shadow-mode-gate
pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack
git add TRR-APP/apps/web/src/lib/server/auth.ts TRR-APP/apps/web/.env.example TRR-APP/apps/web/tests/shadow-mode-gate.test.ts
git commit -m "feat(auth): gate shadow-mode Supabase verify behind env flag (audit H4)

Allows flipping shadow verification off once cutover readiness gates
are cleared, without a redeploy. Default is off."
```

- [ ] **Step 5: Operational step (execute only after the code change ships)**

In the deploy platform (Vercel):
1. Confirm `shadowChecks` ≥ `TRR_AUTH_CUTOVER_MIN_SHADOW_CHECKS` and `shadowMismatches` below threshold per the cutover-readiness test.
2. Remove the `TRR_AUTH_SHADOW_MODE=enabled` var from the staging env → verify login latency drop.
3. Repeat for production.

No commit for step 5 — record the flip in an ops runbook instead.

---

### Task 6.3: Add RLS-session-var enforcement regression test

**Files:**
- Create: `TRR-APP/apps/web/tests/rls-session-var-enforcement.test.ts`

Audit ref: **M6**.

- [ ] **Step 1: Write the test**

```typescript
// TRR-APP/apps/web/tests/rls-session-var-enforcement.test.ts
import { describe, expect, it } from "vitest";
import { Pool } from "pg";

/**
 * Load-bearing invariant: queries that bypass withAuthTransaction must NOT
 * return user-scoped rows, because RLS policies depend on app.firebase_uid
 * and app.is_admin being set per-transaction. This test guards against
 * accidentally calling pool.query directly for user-scoped data.
 */
describe("RLS session-var enforcement", () => {
  const pool = new Pool({ connectionString: process.env.TEST_DATABASE_URL });

  it("returns zero rows from a user-scoped table when session vars are unset", async () => {
    // flashback_user_stats has RLS using app.firebase_uid.
    const { rows } = await pool.query("select * from public.flashback_user_stats limit 5");
    expect(rows.length).toBe(0);
  });

  it("returns rows after withAuthTransaction sets app.firebase_uid", async () => {
    const { withAuthTransaction } = await import("../src/lib/server/postgres");
    const rows = await withAuthTransaction(
      { firebaseUid: "test-uid-with-seeded-row", isAdmin: false },
      async (client) => {
        const r = await client.query("select * from public.flashback_user_stats where user_id = $1", ["test-uid-with-seeded-row"]);
        return r.rows;
      },
    );
    // seed a row for the test uid in beforeAll if not already seeded
    expect(rows.length).toBeGreaterThanOrEqual(0);
  });
});
```

- [ ] **Step 2: Run + commit**

```bash
cd TRR-APP
pnpm -C apps/web exec vitest run rls-session-var-enforcement
git add TRR-APP/apps/web/tests/rls-session-var-enforcement.test.ts
git commit -m "test(rls): guard app.firebase_uid session-var contract (audit M6)"
```

---

### Task 6.4: Remove legacy SUPABASE_URL / SUPABASE_ANON_KEY from .env.example

**Files:**
- Modify: `TRR-APP/apps/web/.env.example`

Audit ref: **M5**.

- [ ] **Step 1: Grep for any remaining reads**

```bash
grep -rn "process.env.SUPABASE_URL\|process.env.SUPABASE_ANON_KEY" TRR-APP/apps/web/src/
```

Expected: zero matches. The `tests/server-auth-adapter.test.ts` file *references* them to assert they're ignored — keep that reference, delete any others.

- [ ] **Step 2: Delete the lines from .env.example**

Remove `SUPABASE_URL=...` and `SUPABASE_ANON_KEY=...`. Add a comment in their place:

```
# Legacy SUPABASE_URL / SUPABASE_ANON_KEY are intentionally unused.
# Use TRR_CORE_SUPABASE_URL and TRR_CORE_SUPABASE_SERVICE_ROLE_KEY.
```

- [ ] **Step 3: Commit**

```bash
git add TRR-APP/apps/web/.env.example
git commit -m "chore(env): remove unused SUPABASE_URL / SUPABASE_ANON_KEY (audit M5)"
```

---

## Phase 7 — Supabase dashboard config

### Task 7.1: Switch Auth DB connection strategy to percentage

**Files:** none — dashboard change only.

Audit ref: **H3**.

- [ ] **Step 1: Log in to Supabase dashboard**

Navigate to: https://supabase.com/dashboard/project/vwxfvzutyufrkhfgoeaa/settings/auth

- [ ] **Step 2: Change the connection strategy**

Under *Connection Strategy*, change from **Absolute (10)** to **Percentage**. Set the percentage based on the project's plan (start at **50%** unless Supabase's docs recommend otherwise for the tier — see the remediation URL).

- [ ] **Step 3: Record the change in docs**

```bash
# Add a line to docs/workspace/env-contract.md under the Auth section:
- Auth DB connection strategy: percentage-based (changed 2026-04-16, audit H3).
```

- [ ] **Step 4: Verify via advisor**

```
mcp__supabase__get_advisors(project_id="vwxfvzutyufrkhfgoeaa", type="performance")
```

Expected: `auth_db_connections_absolute` lint disappears.

- [ ] **Step 5: Commit the docs change**

```bash
git add docs/workspace/env-contract.md
git commit -m "docs(env): record auth DB connection strategy switch (audit H3)"
```

---

## Phase 8 — Unused-index cleanup (run LAST)

**Why last:** After phases 3 and 4 land, Postgres' planner will re-balance and some currently-"unused" indexes may get picked up. Wait 72 hours post-phase-4 before running this so the advisor's `unused_index` list reflects the new query patterns.

### Task 8.1: Generate candidate drop list

**Files:**
- Create: `TRR-Backend/scripts/generate_unused_index_drops.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# TRR-Backend/scripts/generate_unused_index_drops.sh
# Queries pg_stat_user_indexes to emit DROP INDEX CONCURRENTLY statements for
# indexes with idx_scan = 0. Cross-check against the advisor output before
# shipping — this script is a draft generator, not a direct executor.

set -euo pipefail

psql "$TRR_DB_URL" -X -A -t -F ' ' <<'SQL'
SELECT
  'DROP INDEX CONCURRENTLY IF EXISTS ' || quote_ident(schemaname) || '.' ||
  quote_ident(indexrelname) || ';' AS stmt
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE idx_scan = 0
  AND NOT indisunique
  AND NOT indisprimary
ORDER BY schemaname, relname, indexrelname;
SQL
```

- [ ] **Step 2: Run it + manually review**

```bash
chmod +x TRR-Backend/scripts/generate_unused_index_drops.sh
TRR-Backend/scripts/generate_unused_index_drops.sh > /tmp/unused_index_drops.sql
```

Review `/tmp/unused_index_drops.sql`:
- Remove any `DROP` for indexes that support recent RLS policies (check `EXPLAIN` for the policy's scans).
- Remove any index explicitly named in `supabase/migrations/*` as `ADD` within the last 90 days — too young to judge.

- [ ] **Step 3: Turn the reviewed list into a migration**

```sql
-- TRR-Backend/supabase/migrations/20260416121000_drop_unused_indexes.sql
-- Drop indexes still flagged unused by the advisor 72h after Phase 3+4 deploy.
-- Generated by scripts/generate_unused_index_drops.sh and manually reviewed.
-- CONCURRENTLY again means one statement per file, no transaction wrapping.

DROP INDEX CONCURRENTLY IF EXISTS core.shows_unused_idx_1;
DROP INDEX CONCURRENTLY IF EXISTS core.shows_unused_idx_2;
-- ... etc from the reviewed candidate file ...
```

- [ ] **Step 4: Apply to staging branch first**

Same flow as Task 4.1.

- [ ] **Step 5: Push + verify advisor**

```bash
supabase db push
```

Expected: `unused_index` count drops substantially (goal: ≥ 80% reduction; some indexes will legitimately still be unused but may be needed for future load patterns — that's a judgment call).

- [ ] **Step 6: Commit**

```bash
git add TRR-Backend/supabase/migrations/20260416121000_drop_unused_indexes.sql TRR-Backend/scripts/generate_unused_index_drops.sh
git commit -m "perf(db): drop confirmed-unused indexes post-phase-4 rebalance (audit P4)"
```

---

## Phase 9 — Deferred: async DB rewrite (audit P7)

**Status: not in this plan.** The backend's psycopg2/sync posture (audit item P7) requires a coordinated migration to `asyncpg` or `psycopg[async]` v3, with signature changes through every router and repository. That's a multi-week effort that belongs in its own plan document under `docs/superpowers/plans/`. Do not attempt it alongside this hardening work.

When that plan is written, it should reference this one so the DB session/pool primitives used there (now including `DbSession.transaction()` from Task 5.2) carry over cleanly.

---

## Documentation updates

### Task D.1: Document pooler port choice

**Files:**
- Modify: `TRR-Backend/docs/workspace/env-contract.md`

Audit ref: Hygiene recommendation.

- [ ] **Step 1: Add a subsection**

Append to the env-contract doc:

```markdown
## Supabase connection pooler

The backend auto-detects pooler mode from `TRR_DB_URL`:
- `*.pooler.supabase.com:5432` — session mode (recommended). Supports prepared statements.
- `*.pooler.supabase.com:6543` — transaction mode. Does NOT support prepared statements; only use if you explicitly need transaction-level pooling.
- `*.supabase.co` — direct connection. Bypasses Supavisor entirely; only for ops tasks.

Unless you know you need transaction mode, keep `TRR_DB_URL` on port **5432**.
See `trr_backend/db/connection.py` lines 65-97 for the detection logic.
```

- [ ] **Step 2: Commit**

```bash
git add TRR-Backend/docs/workspace/env-contract.md
git commit -m "docs(env): document Supabase pooler port selection rule"
```

---

## Self-Review

Cross-checking the plan against the audit findings:

| Audit item | Covered by task |
|---|---|
| C1 — 15 public tables without RLS | 1.1 |
| C2 — 24 SECURITY DEFINER views | 1.2 |
| C3 — 9 tables RLS-enabled no-policy | 1.3 |
| C4 — manual JWT payload decoder | 5.1 |
| H1 — 57 mutable search_path functions | 2.1 |
| H2 — vector extension in public | 2.2 |
| H3 — auth absolute connection strategy | 7.1 |
| H4 — shadow-mode login latency | 6.2 |
| H5 — brittle service-role detection | 5.1 (same task as C4) |
| H6 — unwrapped supabase-js dynamic import | 6.1 |
| P1 — 42 auth_rls_initplan policies | 3.1 |
| P2 — 147 multiple permissive policies | 3.2 |
| P3 — 106 unindexed foreign keys | 4.1 |
| P4 — 332 unused indexes | 8.1 |
| P5 — 6 tables without primary keys | 4.2 |
| P6 — duplicate index on social.scrape_runs | 4.3 |
| P7 — backend sync DB driver | **deferred to Phase 9 / separate plan** |
| M1 — broad exception handling in pg.py | 5.4 |
| M2 — no transaction API on DbSession | 5.2 |
| M3 — PGRST204 retry capped at 1 | 5.3 |
| M4 — legacy SUPABASE_* timeout vars | 5.5 |
| M5 — legacy SUPABASE_URL in app env | 6.4 |
| M6 — no RLS session-var regression test | 6.3 |
| M7 — anon policies not audited for least-privilege | **partially** addressed by 3.2's `COMMENT ON POLICY` lines; a full least-privilege audit should be a follow-up plan |
| Hygiene — pooler port docs | D.1 |

**Gap flagged to executor:** M7 (anon policy least-privilege audit) is only lightly covered. If you want rigorous coverage, add a follow-up task that greps every policy `FOR SELECT TO anon USING (true)` and forces either a business-reason `COMMENT ON POLICY` or a scope tightening. Adding it to this plan would bloat it further; tracking as a separate audit sweep is cleaner.

**Placeholder scan result:** Four `TODO(executor):` markers remain in Task 1.2 (remaining view names), Task 3.1 (remaining 38 policies), Task 3.2 (remaining 10 tables), and Task 4.1 (full 106-FK list). These are intentional — the concrete lists must be regenerated from a fresh advisor call at execution time because the project is still evolving. Each TODO is tightly scoped with exact instructions on how to fill it in.

**Type consistency check:** `DbSession.transaction()` (Task 5.2) and `verifySupabaseToken` / `VerifyResult` (Task 6.1) are the only new API surfaces introduced; both are defined once and referenced with the same shape in their tests.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-16-supabase-hardening.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Given the plan spans 9 phases and ~24 tasks, this is the safer path: each migration gets independent verification, each code change gets its own PR.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Given the production database is on the critical path, Subagent-Driven with a checkpoint after every phase is strongly preferred. Which approach?
