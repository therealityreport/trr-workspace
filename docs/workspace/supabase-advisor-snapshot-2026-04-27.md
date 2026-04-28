# Supabase Advisor Snapshot — 2026-04-27

Project: `trr-core` (`vwxfvzutyufrkhfgoeaa`), Postgres 17.6.1.062, region us-east-1.
Captured via Supabase MCP `get_advisors` (security advisor type).

Total findings: **130** | Severity: **ERROR 1, WARN 68, INFO 61**.

## Security Advisor — Summary

| Lint | Severity | Count |
|---|---|---:|
| `rls_enabled_no_policy` | INFO | 61 |
| `function_search_path_mutable` | WARN | 51 |
| `anon_security_definer_function_executable` | WARN | 8 |
| `authenticated_security_definer_function_executable` | WARN | 8 |
| `rls_disabled_in_public` | ERROR | 1 |
| `extension_in_public` | WARN | 1 |

Schema breakdown of affected objects: `core` 71, `admin` 26, `public` 17, `social` 15, `firebase_surveys` 1.

## Security Advisor — Top 5 Priority Findings

### 1. `rls_disabled_in_public` — `public.__migrations`
- Risk: A PostgREST-exposed table runs without row-level security, so any role with table-level grants can `SELECT/INSERT/UPDATE/DELETE` migrations metadata over the REST API. Tampering with this ledger could enable replay or rollback of schema migrations and bypass deploy guardrails.
- Remediation: Either remove the table from any exposed schema or enable RLS and add a deny-by-default policy: `ALTER TABLE public.__migrations ENABLE ROW LEVEL SECURITY; REVOKE ALL ON public.__migrations FROM anon, authenticated; CREATE POLICY no_access ON public.__migrations FOR ALL TO public USING (false) WITH CHECK (false);`.
- URL: [0013_rls_disabled_in_public](https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public)

### 2. `anon_security_definer_function_executable` — `core.merge_shows(source_show_id uuid, target_show_id uuid)` (and 7 sibling RPCs)
- Risk: Eight `SECURITY DEFINER` RPCs in `core` and `social` are callable by the unauthenticated `anon` role through `/rest/v1/rpc/*`, executing under the function-owner's privileges and bypassing RLS for any table they touch. `merge_shows`, `set_primary_media_link`, and the `upsert_*` family are write paths that can mutate canonical entities, media bindings, and cast/show photos for any visitor.
- Remediation: Revoke anon execute and either flip to `SECURITY INVOKER` or relocate out of an exposed schema, e.g. `REVOKE EXECUTE ON FUNCTION core.merge_shows(uuid, uuid) FROM anon, public; ALTER FUNCTION core.merge_shows(uuid, uuid) SECURITY INVOKER;` (repeat for each function listed below).
- URL: [0028_anon_security_definer_function_executable](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)

### 3. `authenticated_security_definer_function_executable` — same 8 RPCs callable by `authenticated`
- Risk: The same `SECURITY DEFINER` RPCs are also exposed to every signed-in user, so any user-scoped JWT can invoke writes under owner privileges and override RLS on `core.shows`, `core.cast_photos`, media bindings, and `social` direct conversations. Because the surface mirrors finding #2, every fix needs to revoke from `authenticated` in addition to `anon`.
- Remediation: After flipping each RPC to `SECURITY INVOKER` or scoping ownership, also `REVOKE EXECUTE ON FUNCTION <fn> FROM authenticated;` and add explicit `GRANT EXECUTE` only to backend service roles that legitimately need it.
- URL: [0029_authenticated_security_definer_function_executable](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)

### 4. `function_search_path_mutable` — 51 functions across `admin`, `core`, `firebase_surveys`, `public`, `social`
- Risk: Functions without a pinned `search_path` resolve unqualified identifiers using the caller's path, so a hostile user (or a future schema collision) can shadow built-in objects like `pg_temp.now()` and trick `SECURITY DEFINER` functions into executing attacker-controlled code with elevated privileges. The breadth (51 functions, including `core.bridge_*`, `core.propagate_*`, `social._build_post_search_*`, and every `set_updated_at` trigger helper) makes this the largest privilege-escalation surface in the project.
- Remediation: For each function, set an empty or explicit search path and fully qualify references inside the body, e.g. `ALTER FUNCTION core.bridge_show_images_to_media() SET search_path = '';` (or `SET search_path = pg_catalog, core` if the body needs those schemas). Apply through a migration that touches every function in the full table below.
- URL: [0011_function_search_path_mutable](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable)

### 5. `extension_in_public` — `public.vector`
- Risk: Installing the `vector` extension into `public` exposes its operators and functions to PostgREST and to any role with default `public` usage, complicates upgrades, and fights namespace hygiene for the rest of the schema. It also expands the search-path attack surface flagged in finding #4.
- Remediation: Move the extension to a dedicated schema, e.g. `CREATE SCHEMA IF NOT EXISTS extensions; ALTER EXTENSION vector SET SCHEMA extensions;` then update any application search paths and migration baselines that referenced `public.vector`.
- URL: [0014_extension_in_public](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)

## Security Advisor — Full Lint Table

The 130 findings are listed below. Description column abbreviates the advisor's text — see linked URL on the lint name for full guidance.

| Lint | Severity | Object | Description |
|---|---|---|---|
| [`rls_disabled_in_public`](https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public) | ERROR | `public.__migrations` | Table is public but RLS is not enabled |
| [`extension_in_public`](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public) | WARN | `public.vector` | Extension installed in public schema |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.merge_shows(source_show_id uuid, target_show_id uuid)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.set_primary_media_link(p_entity_type text, p_entity_id uuid, p_kind text, p_media_link_id uuid)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.upsert_cast_photos_by_canonical(rows jsonb)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.upsert_cast_photos_by_identity(rows jsonb)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.upsert_person_images(rows jsonb)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.upsert_show_images_by_identity(rows jsonb)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `core.upsert_tmdb_show_images_by_identity(rows jsonb)` | SECURITY DEFINER RPC callable by anon |
| [`anon_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) | WARN | `social.get_or_create_direct_conversation(other_user_id uuid)` | SECURITY DEFINER RPC callable by anon |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.merge_shows(source_show_id uuid, target_show_id uuid)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.set_primary_media_link(p_entity_type text, p_entity_id uuid, p_kind text, p_media_link_id uuid)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.upsert_cast_photos_by_canonical(rows jsonb)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.upsert_cast_photos_by_identity(rows jsonb)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.upsert_person_images(rows jsonb)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.upsert_show_images_by_identity(rows jsonb)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `core.upsert_tmdb_show_images_by_identity(rows jsonb)` | SECURITY DEFINER RPC callable by authenticated |
| [`authenticated_security_definer_function_executable`](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) | WARN | `social.get_or_create_direct_conversation(other_user_id uuid)` | SECURITY DEFINER RPC callable by authenticated |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `admin.set_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._cast_photos_best_width` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._cast_photos_pick_height` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._cast_photos_pick_url` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._cast_photos_pick_url_path` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._normalize_cast_photo_canonical_url` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._show_images_best_width` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core._show_images_pick_url` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.bridge_cast_photos_to_media` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.bridge_episode_images_to_media` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.bridge_person_images_to_media` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.bridge_season_images_to_media` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.bridge_show_images_to_media` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.bridge_show_source_snapshots` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.cast_tmdb_set_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.jsonb_sha256` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.propagate_person_name_to_dependents` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.propagate_show_name_to_dependents` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.propagate_show_name_to_episodes` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.propagate_show_name_to_seasons` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.propagate_show_title_to_episodes` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.propagate_show_title_to_seasons` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.purge_admin_operations` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.refresh_season_episode_id_arrays` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.refresh_season_episode_id_arrays_from_episode_deletes` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.refresh_season_episode_id_arrays_from_episode_inserts` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.refresh_season_episode_id_arrays_from_episode_updates` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.set_admin_operation_event_seq` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.set_episode_appearance_names` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.set_episode_show_name` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.set_season_show_name` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.set_show_cast_names` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.set_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `core.touch_media_asset_variants_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `firebase_surveys.set_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `public.set_current_timestamp_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `public.set_site_typography_updated_at` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `public.set_updated_at_timestamp` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._build_post_search_handle_identities` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._build_post_search_handles` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._build_post_search_hashtags` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._build_post_search_text` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._jsonb_detail_handle_values` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._jsonb_text_values` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._normalize_search_handle` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._normalize_search_hashtag` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._regex_capture_values` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._search_identity` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social._search_unique_text_array` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social.enforce_instagram_comment_parent_same_post` | Function has no pinned search_path |
| [`function_search_path_mutable`](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable) | WARN | `social.refresh_platform_post_search_fields` | Function has no pinned search_path |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brand_families` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brand_family_link_rules` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brand_family_members` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brand_family_wikipedia_show_links` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brand_logo_assets` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brand_logo_source_queries` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.brands_franchise_rules` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.cast_photo_people_tags` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.covered_shows` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.entity_logo_imports` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.network_streaming_completion` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.network_streaming_completion_attempts` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.network_streaming_discovery_state` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.network_streaming_logo_assets` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.network_streaming_overrides` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.network_streaming_sync_runs` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.person_cover_photos` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.person_reprocess_job_events` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.person_reprocess_jobs` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.recent_people_views` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.reddit_communities` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.reddit_discovery_posts` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.reddit_threads` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.season_cast_survey_roles` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `admin.show_social_posts` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `core.admin_operation_events` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `core.admin_operations` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `core.bravotv_image_runs` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `core.cast_fandom` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `core.cast_photos` | RLS enabled but no policies defined |
| [`rls_enabled_no_policy`](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) | INFO | `core.cast_tmdb` | RLS enabled but no policies defined |

Row-cap reached at 100. The remaining 30 findings are all `rls_enabled_no_policy` (INFO) covering these objects: `core.episode_source_history`, `core.episode_source_latest`, `core.external_id_conflicts`, `core.fandom_community_allowlist`, `core.fandom_page_directory`, `core.google_news_sync_jobs`, `core.media_asset_variants`, `core.media_assets`, `core.media_links`, `core.news_topic_taxonomy`, `core.people_overrides`, `core.person_source_history`, `core.person_source_latest`, `core.season_fandom`, `core.season_source_history`, `core.season_source_latest`, `core.show_source_history`, `core.show_source_latest`, `public.site_typography_assignments`, `public.site_typography_sets`, `public.survey_cast`, `public.survey_episodes`, `public.survey_global_profile_responses`, `public.survey_rhop_s10_responses`, `public.survey_rhoslc_s6_responses`, `public.survey_show_palette_library`, `public.survey_show_seasons`, `public.survey_shows`, `public.survey_x_responses`, `public.surveys`. All share the same lint URL: [0008_rls_enabled_no_policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

## Performance Advisor — Summary

Source: `mcp__873f9389__get_advisors` (type=performance) on project `vwxfvzutyufrkhfgoeaa` (Postgres 17.6.1.062), captured 2026-04-27. Total findings: **532** (`INFO`: 434, `WARN`: 98).

| Lint | Severity | Count |
|---|---|---:|
| [`unused_index`](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) | INFO | 415 |
| [`multiple_permissive_policies`](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies) | WARN | 91 |
| [`unindexed_foreign_keys`](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys) | INFO | 17 |
| [`auth_rls_initplan`](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan) | WARN | 7 |
| [`no_primary_key`](https://supabase.com/docs/guides/database/database-linter?lint=0004_no_primary_key) | INFO | 1 |
| [`auth_db_connections_absolute`](https://supabase.com/docs/guides/deployment/going-into-prod) | INFO | 1 |

Schema distribution (top): `social` 151, `core` 101, `thb_bbl` 63, `public` 53, `screenalytics` 49, `firebase_surveys` 47, `ml` 32, `admin` 20.

## Performance Advisor — Top 10 Priority Findings (TRR-targeted)

### 1. `auth_rls_initplan` — `core.networks` policy `core_tmdb_networks_service_role`
- TRR impact: Every TMDB network read on serverless app paths re-evaluates `auth.<fn>()` per row — under Vercel concurrency this fans out into thousands of repeat planner calls and saturates the pool faster than any other lint here.
- Remediation: rewrite the policy USING/CHECK clauses to wrap calls: `(select auth.role()) = 'service_role'` instead of bare `auth.role() = 'service_role'`.
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 2. `auth_rls_initplan` — `core.production_companies` policy `core_tmdb_production_companies_service_role`
- TRR impact: TMDB production companies are joined into high-fan-out admin dashboards (cast/show pages); per-row initplan inflates the planner cost on every paginated render.
- Remediation: same `(select auth.<fn>())` wrap as above.
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 3. `auth_rls_initplan` — `core.show_watch_providers` policy `core_show_watch_providers_service_role`
- TRR impact: Watch-provider rows feed homepage and show-detail surfaces; admin sweeps over them re-evaluate auth per row, multiplying serverless DB time.
- Remediation: `(select auth.role()) = 'service_role'`.
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 4. `auth_rls_initplan` — `core.watch_providers` policy `core_tmdb_watch_providers_service_role`
- TRR impact: Catalog table read by every region-aware list endpoint; per-row initplan negates the index plan and triples plan time under Supavisor session contention.
- Remediation: wrap auth functions in subselect.
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 5. `auth_rls_initplan` — `public.show_icons` policy `Allow service role all on show_icons`
- TRR impact: `show_icons` is read on app shell (icons hydrated everywhere); initplan churn is multiplied by every page render across serverless functions.
- Remediation: rewrite policy as `(select auth.role()) = 'service_role'`.
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 6. `auth_rls_initplan` — `public.flashback_quizzes` policy `Service role full access to quizzes`
- TRR impact: Flashback quiz reads happen during admin authoring + public play; both surfaces hit the same RLS path and pay the per-row auth cost twice.
- Remediation: wrap in `(select auth.<fn>())`.
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 7. `auth_rls_initplan` — `public.flashback_events` policy `Service role full access to events`
- TRR impact: Per-event RLS evaluation under quiz analytics queries amplifies plan time as the events table grows; combined with `multiple_permissive_policies` on the same table it doubles the cost.
- Remediation: wrap auth call + collapse with public-read policy (see #10).
- URL: [auth_rls_initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)

### 8. `multiple_permissive_policies` — `firebase_surveys.responses` (21 dup combos × roles `dashboard_user`, `supabase_privileged_role`, `trr_app` × INSERT/SELECT/UPDATE)
- TRR impact: Every survey response write/read evaluates BOTH `responses_admin_all` and `responses_<action>_own` permissive policies — that's a 2x policy execution on a table that takes the entire submission burst when a survey goes live.
- Remediation: keep `responses_admin_all` permissive but rewrite owner policies as `RESTRICTIVE` or merge into a single permissive policy via `OR`: `DROP POLICY responses_select_own ON firebase_surveys.responses; CREATE POLICY responses_admin_or_own ON firebase_surveys.responses FOR SELECT USING ((select auth.uid()) = user_id OR (select auth.role()) = 'service_role');`
- URL: [multiple_permissive_policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies)

### 9. `multiple_permissive_policies` — `firebase_surveys.answers` (21 dup combos × all three roles, INSERT/SELECT/UPDATE)
- TRR impact: Same shape as `responses`, but `answers` has many more rows per submission — the per-row dual-policy evaluation compounds with row count.
- Remediation: drop `answers_select_own` / `answers_insert_own` / `answers_update_own` and merge into a single permissive policy combining admin + owner via `OR`, with auth wrapped in `(select ...)`.
- URL: [multiple_permissive_policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies)

### 10. `multiple_permissive_policies` — `core.{networks, production_companies, show_watch_providers, watch_providers}`, `public.{flashback_events, flashback_quizzes, show_icons}` (7 dup combos each)
- TRR impact: All seven tables have a `*_public_read` policy AND a `*_service_role` policy on the same SELECT — `dashboard_user` / `trr_app` / `supabase_privileged_role` each re-execute both. These are exactly the tables already flagged in #1–#7 for `auth_rls_initplan`, so each row pays the double-policy + per-row-auth tax simultaneously.
- Remediation: collapse the two SELECT policies into one combined permissive: `CREATE POLICY core_tmdb_networks_combined ON core.networks FOR SELECT USING (true OR (select auth.role()) = 'service_role'); DROP POLICY core_tmdb_networks_public_read ON core.networks; DROP POLICY core_tmdb_networks_service_role ON core.networks;`. Apply same pattern to all seven.
- URL: [multiple_permissive_policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies)

## Performance Advisor — Full Lint Inventory

### `unused_index` (415 — drop candidates after pg_stat_user_indexes corroboration)

#### `social` (151 unused indexes; showing first 50)
- `facebook_posts_username_idx` on `social.facebook_posts`
- `facebook_posts_show_id_idx` on `social.facebook_posts`
- `facebook_posts_person_id_idx` on `social.facebook_posts`
- `facebook_posts_job_id_idx` on `social.facebook_posts`
- `idx_facebook_posts_media_mirror_pending` on `social.facebook_posts`
- `ig_comments_season_created_idx` on `social.instagram_comments`
- `tt_comments_season_created_idx` on `social.tiktok_comments`
- `yt_comments_season_created_idx` on `social.youtube_comments`
- `threads_created_by_idx` on `social.threads`
- `posts_thread_id_created_at_idx` on `social.posts`
- `posts_parent_post_id_created_at_idx` on `social.posts`
- `posts_user_id_idx` on `social.posts`
- `instagram_posts_person_id_idx` on `social.instagram_posts`
- `reactions_post_id_reaction_idx` on `social.reactions`
- `idx_dm_members_user_joined` on `social.dm_members`
- `idx_dm_messages_conversation_created` on `social.dm_messages`
- `instagram_comments_parent_comment_id_idx` on `social.instagram_comments`
- `tiktok_posts_show_id_idx` on `social.tiktok_posts`
- `tiktok_posts_person_id_idx` on `social.tiktok_posts`
- `tiktok_comments_parent_comment_id_idx` on `social.tiktok_comments`
- `youtube_videos_person_id_idx` on `social.youtube_videos`
- `youtube_videos_show_id_idx` on `social.youtube_videos`
- `twitter_tweets_show_id_idx` on `social.twitter_tweets`
- `twitter_tweets_person_id_idx` on `social.twitter_tweets`
- `idx_youtube_videos_media_mirror_pending` on `social.youtube_videos`
- `meta_threads_posts_show_id_idx` on `social.meta_threads_posts`
- `meta_threads_posts_person_id_idx` on `social.meta_threads_posts`
- `idx_meta_threads_posts_media_mirror_pending` on `social.meta_threads_posts`
- `meta_threads_comments_parent_comment_id_idx` on `social.meta_threads_comments`
- `reddit_posts_created_at_idx` on `social.reddit_posts`
- `reddit_comments_created_at_idx` on `social.reddit_comments`
- `reddit_period_post_matches_created_at_idx` on `social.reddit_period_post_matches`
- `reddit_period_post_matches_flair_key_idx` on `social.reddit_period_post_matches`
- `reddit_period_post_matches_flair_mode_idx` on `social.reddit_period_post_matches`
- `idx_tiktok_posts_sound_id` on `social.tiktok_posts`
- `idx_tiktok_sound_posts_posted_at` on `social.tiktok_sound_posts`
- `idx_tiktok_post_cast_members_cast_member_id` on `social.tiktok_post_cast_members`
- `idx_tiktok_anomaly_events_season_created` on `social.tiktok_anomaly_events`
- `season_targets_show_id_idx` on `social.season_targets`
- `idx_tiktok_comments_media_mirror_pending` on `social.tiktok_comments`
- `youtube_comments_job_id_idx` on `social.youtube_comments`
- `twitter_tweets_job_id_idx` on `social.twitter_tweets`
- `meta_threads_comments_job_id_idx` on `social.meta_threads_comments`
- `idx_meta_threads_comments_media_mirror_pending` on `social.meta_threads_comments`
- `instagram_comments_job_id_idx` on `social.instagram_comments`
- `facebook_comments_parent_comment_id_idx` on `social.facebook_comments`
- `facebook_comments_created_at_idx` on `social.facebook_comments`
- `facebook_comments_job_id_idx` on `social.facebook_comments`
- `idx_facebook_comments_media_mirror_pending` on `social.facebook_comments`
- `idx_social_instagram_comments_season_created_at` on `social.instagram_comments`
- _...and 101 more in `social` (top tables: twitter_tweets 11, facebook_posts 10, reddit_period_post_matches 8)._

#### `core` (68 unused indexes; showing first 30)
- `core_shows_alternative_names_gin` on `core.shows`
- `core_shows_genres_gin` on `core.shows`
- `core_shows_keywords_gin` on `core.shows`
- `core_shows_tags_gin` on `core.shows`
- `core_shows_networks_gin` on `core.shows`
- `core_shows_streaming_providers_gin` on `core.shows`
- `core_shows_listed_on_gin` on `core.shows`
- `core_shows_tmdb_network_ids_gin` on `core.shows`
- `core_shows_tmdb_production_company_ids_gin` on `core.shows`
- `core_shows_external_ids_gin` on `core.shows`
- `media_assets_ingest_next_retry_idx` on `core.media_assets`
- `idx_media_assets_archived` on `core.media_assets`
- `core_season_fandom_show_id_idx` on `core.season_fandom`
- `core_season_fandom_season_number_idx` on `core.season_fandom`
- `cast_photos_person_gallery_idx` on `core.cast_photos`
- `cast_photos_hosted_at_idx` on `core.cast_photos`
- `idx_show_images_hosted_at` on `core.show_images`
- `idx_show_images_hosted_sha256` on `core.show_images`
- `show_images_source_image_id_idx` on `core.show_images`
- `idx_show_images_archived` on `core.show_images`
- `core_cast_fandom_source_idx` on `core.cast_fandom`
- `media_uploads_entity_idx` on `core.media_uploads`
- `media_uploads_status_idx` on `core.media_uploads`
- `media_uploads_uploader_idx` on `core.media_uploads`
- `idx_cast_tmdb_imdb_id` on `core.cast_tmdb`
- `idx_cast_tmdb_instagram_id` on `core.cast_tmdb`
- `idx_cast_tmdb_twitter_id` on `core.cast_tmdb`
- `idx_google_news_sync_jobs_status` on `core.google_news_sync_jobs`
- `idx_google_news_sync_jobs_status_heartbeat` on `core.google_news_sync_jobs`
- `idx_google_news_sync_jobs_worker_heartbeat` on `core.google_news_sync_jobs`
- _...and 38 more in `core` (heaviest: shows 13, media_uploads 5, episode_images 5)._

#### `screenalytics`, `thb_bbl`, `ml`, `surveys`, `firebase_surveys`, `pipeline` (combined 167 unused indexes)
- `screenalytics` 49 — heaviest: `video_assets` (5), `cast_screentime_*` reference/decision tables (12), `runs_v2_*` status indexes (3).
- `thb_bbl` 46 — entirely on legacy basketball-league tables (`RegistrationSubmission`, `EventSchedule*`, `RequestAnalysis*`); drop candidates if tenant is dormant.
- `ml` 32 — `ml_face_reference_*`, `ml_screentime_*`, `ml_analysis_*` per-FK indexes; many are duplicate of single-column FK helpers covered by composite indexes.
- `surveys` 11, `firebase_surveys` 5, `pipeline` 4 — full list in source artifact.

#### `public` (29 unused indexes; showing all)
- `idx_surveys_is_active` on `public.surveys`
- `idx_surveys_show_season` on `public.surveys`
- `idx_surveys_theme` on `public.surveys`
- `idx_surveys_air_schedule` on `public.surveys`
- `public_surveys_current_episode_id_idx` on `public.surveys`
- `idx_survey_cast_survey_id` on `public.survey_cast`
- `idx_survey_cast_display_order` on `public.survey_cast`
- `idx_survey_cast_status` on `public.survey_cast`
- `idx_survey_cast_is_alumni` on `public.survey_cast`
- `idx_survey_episodes_survey_id` on `public.survey_episodes`
- `idx_survey_episodes_is_current` on `public.survey_episodes`
- `idx_survey_episodes_air_date` on `public.survey_episodes`
- `idx_survey_episodes_is_active` on `public.survey_episodes`
- `idx_rhoslc_s6_show_episode` on `public.survey_rhoslc_s6_responses`
- `idx_rhoslc_s6_app_username` on `public.survey_rhoslc_s6_responses`
- `idx_sgpr_app_username` on `public.survey_global_profile_responses`
- `idx_survey_x_created_at` on `public.survey_x_responses`
- `idx_survey_x_app_username` on `public.survey_x_responses`
- `idx_rhop_s10_app_user_id` on `public.survey_rhop_s10_responses`
- `idx_rhop_s10_created_at` on `public.survey_rhop_s10_responses`
- `idx_rhop_s10_season_episode` on `public.survey_rhop_s10_responses`
- `idx_survey_shows_is_active` on `public.survey_shows`
- `idx_survey_show_seasons_show_id` on `public.survey_show_seasons`
- `idx_survey_show_seasons_is_current` on `public.survey_show_seasons`
- `idx_survey_show_seasons_is_active` on `public.survey_show_seasons`
- `idx_survey_show_palette_library_show` on `public.survey_show_palette_library`
- `idx_site_typography_assignments_set_id` on `public.site_typography_assignments`
- `idx_flashback_sessions_user` on `public.flashback_sessions`
- `idx_flashback_sessions_quiz` on `public.flashback_sessions`

#### `admin` (20 unused indexes; showing all)
- `network_streaming_logo_assets_sha_idx` on `admin.network_streaming_logo_assets`
- `idx_person_cover_photos_photo` on `admin.person_cover_photos`
- `cast_photo_people_tags_people_names_idx` on `admin.cast_photo_people_tags`
- `entity_logo_imports_target_idx` on `admin.entity_logo_imports`
- `network_streaming_sync_runs_finished_idx` on `admin.network_streaming_sync_runs`
- `network_streaming_discovery_state_updated_idx` on `admin.network_streaming_discovery_state`
- `idx_season_cast_survey_roles_show_season` on `admin.season_cast_survey_roles`
- `idx_season_cast_survey_roles_person` on `admin.season_cast_survey_roles`
- `idx_reddit_communities_active` on `admin.reddit_communities`
- `idx_reddit_threads_season` on `admin.reddit_threads`
- `network_streaming_completion_attempts_run_idx` on `admin.network_streaming_completion_attempts`
- `brands_franchise_rules_active_rank_idx` on `admin.brands_franchise_rules`
- `brand_families_active_idx` on `admin.brand_families`
- `network_streaming_completion_owner_idx` on `admin.network_streaming_completion`
- `brand_logo_assets_sha_idx` on `admin.brand_logo_assets`
- `idx_person_reprocess_jobs_person_created` on `admin.person_reprocess_jobs`
- `idx_person_reprocess_jobs_status_created` on `admin.person_reprocess_jobs`
- `idx_person_reprocess_job_events_job_created` on `admin.person_reprocess_job_events`
- `admin_brand_family_wikipedia_show_links_matched_show_id_idx` on `admin.brand_family_wikipedia_show_links`
- `admin_recent_people_views_person_id_idx` on `admin.recent_people_views`

### `unindexed_foreign_keys` (17 — all in legacy `thb_bbl`)

All seventeen findings are confined to `thb_bbl.*` tables (`AuditLog`, `Coach`, `Division`, `Event`, `EventSchedule`, `Player`, `Request`, `RequestMatchCandidate`, `Team`, `TeamAssignment`, `TeamCoach`, `User`). None touch TRR-hot schemas. Remediation template:

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS auditlog_eventid_idx ON thb_bbl."AuditLog" ("eventId");
CREATE INDEX CONCURRENTLY IF NOT EXISTS auditlog_organizationid_idx ON thb_bbl."AuditLog" ("organizationId");
CREATE INDEX CONCURRENTLY IF NOT EXISTS auditlog_userid_idx ON thb_bbl."AuditLog" ("userId");
-- repeat for the remaining 14 fkeys (Coach_eventId, Division_eventId, Event_organizationId,
-- EventSchedule_templateId, Player_{division,event,registrationRow}Id, Request_{division,player}Id,
-- RequestMatchCandidate_requestId, Team_divisionId, TeamAssignment_playerId, TeamCoach_coachId,
-- User_organizationId).
```

### `auth_rls_initplan` (7) and `multiple_permissive_policies` (91)

Already enumerated in the Top 10. Affected tables span `core.{networks, production_companies, show_watch_providers, watch_providers}`, `public.{flashback_events, flashback_quizzes, show_icons}`, and `firebase_surveys.{answers, responses}`. The two lints overlap on every one of these tables — fixing them together in a single migration is strictly cheaper than sequencing them.

### `no_primary_key` (1) and `auth_db_connections_absolute` (1)

- `core.external_id_conflicts` — add a surrogate PK before any UPSERT path or replication tooling touches it: `ALTER TABLE core.external_id_conflicts ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;`.
- Auth server pinned at 10 absolute connections — switch to percentage allocation per [going-into-prod](https://supabase.com/docs/guides/deployment/going-into-prod) so capacity scales with instance size.

## Recommended Wave Sequencing (from advisor evidence)

**Wave B (high-fan-out migrations)** absorbs the bulk of the remediation work. The seven `auth_rls_initplan` policies and the nine tables hit by `multiple_permissive_policies` are the highest-leverage fixes for the bleeding patterns the plan calls out — every Vercel admin route that reads `core.networks`, `core.show_watch_providers`, `public.show_icons`, or writes to `firebase_surveys.{answers,responses}` is paying a per-row auth cost AND a duplicate-policy cost on the same query plan. A single migration per table can: (1) wrap `auth.<fn>()` in `(select auth.<fn>())`, (2) collapse the duplicate `*_public_read` + `*_service_role` SELECT policies into one combined permissive, and (3) optionally convert owner-scoped policies to RESTRICTIVE for `firebase_surveys.{answers,responses}`. This is the cleanest backend-first slice — it changes only RLS DDL and is independently verifiable via `EXPLAIN (ANALYZE, BUFFERS)` on representative queries before/after.

**Wave C (architectural cleanup)** is where the 415 `unused_index` rows belong. Do not bulk-drop; the canonical pattern is: (a) cross-reference `pg_stat_user_indexes.idx_scan` over the last 14 days to confirm zero scans, (b) verify no migration in `migrations_app/` recreates the index, (c) drop with `DROP INDEX CONCURRENTLY` in batches grouped by schema (start with `social` 151, then `core` 68, `screenalytics` 49, `ml` 32). The `social.{twitter_tweets, facebook_posts, reddit_period_post_matches, tiktok_posts, youtube_videos, meta_threads_posts}` cluster alone is ~50 indexes — dropping these reduces write amplification on the social backfill control plane without touching read paths. The 17 `thb_bbl` `unindexed_foreign_keys` also belong here as they are tenant-isolated and require coordination, not urgency.

**Wave D (production posture)** picks up the singletons: `auth_db_connections_absolute` (switch Auth pool to percentage allocation as part of the broader Supavisor capacity work in `docs/superpowers/plans/2026-04-26-supavisor-session-pool-stabilization.md`) and `core.external_id_conflicts` `no_primary_key` (one-line migration that slots into any production-hardening sweep). These have low blast radius but should not lead — they only matter once the high-fan-out RLS work has landed and the index churn is bounded.

Reference plan: `/Users/thomashulihan/.claude/plans/write-the-plan-containing-lexical-kitten.md`.
