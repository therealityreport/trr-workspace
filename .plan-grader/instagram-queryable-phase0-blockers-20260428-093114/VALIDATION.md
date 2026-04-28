# Validation

## Static Repo Checks

- Confirmed canonical migration file exists:
  - `TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql`
- Confirmed legacy public-read migrations exist:
  - `TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`
  - `TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`
- Confirmed recent Instagram surfaces that Phase 0 must reconcile:
  - `TRR-Backend/supabase/migrations/20260323173500_add_instagram_post_search_columns.sql`
  - `TRR-Backend/supabase/migrations/20260428114500_instagram_catalog_post_collaborators.sql`
- Confirmed existing broad search indexes that require an index gate before adding more:
  - `TRR-Backend/supabase/migrations/20260323175500_add_social_post_search_indexes.sql`

## Live Supabase Read-Only Checks

Supabase MCP confirmed the following tables exist in `social`:

- `social.social_posts`
- `social.social_post_observations`
- `social.social_post_legacy_refs`
- `social.social_post_memberships`
- `social.social_post_entities`
- `social.social_post_media_assets`
- `social.instagram_posts`
- `social.instagram_comments`
- `social.instagram_account_catalog_posts`

Raw column existence check found:

- `social.instagram_posts.raw_data`
- `social.instagram_comments.raw_data`
- `social.instagram_account_catalog_posts.raw_data`
- `social.social_post_observations.raw_payload`
- `social.social_post_observations.normalized_payload`

Grant/policy check found:

- `social.instagram_posts`: `anon` and `authenticated` `SELECT`; public read policy.
- `social.instagram_comments`: `anon` and `authenticated` `SELECT`; public read policy.
- `social.instagram_account_catalog_posts`: `anon` and `authenticated` `SELECT`; public read policy.
- `social.social_post_observations`: service-role privileges only in the checked grants.

Job constraint check found live `scrape_jobs_job_type_check_v6` allows existing types such as `posts`, `comments`, `search`, `replies`, `shared_account_posts`, `shared_account_discovery`, and media mirror job types, but not `instagram_profile_snapshot`, `instagram_profile_following`, or `instagram_profile_relationships`.

## Target Branch Check

- `TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql` exists on disk.
- `git -C TRR-Backend ls-files --stage supabase/migrations/20260428152000_social_post_canonical_foundation.sql` returned no tracked entry.
- `git -C TRR-Backend status --short supabase/migrations/20260428152000_social_post_canonical_foundation.sql` reports the migration as untracked.
- Result: live Supabase has the canonical foundation, but the nested backend target branch has not yet proven that migration as tracked branch history.

## Plan Validation

- `latestComments` remains only as excluded/raw-only scope language.
- `social.instagram_post_embedded_comments` appears only in negative requirements.
- `ready_for_execution` now says Phase 0 only.
- The revised plan requires an API contract appendix before Phase 5.
- The revised plan requires RLS/grant classification for both legacy and new raw surfaces.
- Phase 1 now anchors canonical source fields to repo-native Instagram Graph/XDT, REST, HTML/meta, profile, and comments source families; Apify names are adapter aliases only.
- Phase 0 decision note now records the storage map, raw-data exposure classification, live Supabase findings, actual Phase 1 source-family direction, and Phase 1+ blockers.
