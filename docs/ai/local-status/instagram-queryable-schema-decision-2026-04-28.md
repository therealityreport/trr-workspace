# Instagram Queryable Schema Decision

Date: 2026-04-28

Scope: Commit -1 and Phase 0 only for the Instagram queryable-data plan.

Status: Phase 0 decision drafted with blockers. This note proposes the storage map and records static repo plus live Supabase evidence, but it is not approval to start Phase 1 migrations, Python changes, backfill work, tests, or worker fan-out.

## Evidence Mode

- Static repo evidence plus read-only Supabase MCP SQL checks. No migrations, DDL, direct database writes, or live/local database mutations were run.
- Parent workspace branch: `chore/workspace-batch-2026-04-28` at `122c8c4`.
- Nested backend checkout containing schema evidence: `TRR-Backend` branch `chore/backend-batch-2026-04-28` at `983309e`.
- The parent workspace and nested backend worktrees were already dirty. This artifact does not touch those unrelated edits.

## Commit -1 Preflight

Required canonical migration name from the plan:

- `TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql`

Static file evidence:

- The migration exists on disk in the current checkout.
- It creates the canonical foundation tables:
  - `social.social_posts`
  - `social.social_post_observations`
  - `social.social_post_legacy_refs`
  - `social.social_post_memberships`
  - `social.social_post_entities`
  - `social.social_post_media_assets`
- It enables RLS on all six canonical tables.
- It grants public read to curated canonical tables only: `social_posts`, `social_post_memberships`, `social_post_entities`, and `social_post_media_assets`.
- It grants all privileges on all six canonical tables to `service_role`.
- It revokes `public`, `anon`, and `authenticated` access from `social.social_post_observations` and `social.social_post_legacy_refs`.

Target-branch blocker:

- `git -C TRR-Backend ls-files --stage supabase/migrations/20260428152000_social_post_canonical_foundation.sql` returned no tracked entry.
- Therefore the current target backend branch does not yet prove the canonical foundation migration is part of tracked branch history. The file is static evidence only, not target-branch evidence.

Live/local schema verification:

- Supabase MCP read-only checks confirmed the live `social` schema has:
  - `social.social_posts`
  - `social.social_post_observations`
  - `social.social_post_legacy_refs`
  - `social.social_post_memberships`
  - `social.social_post_entities`
  - `social.social_post_media_assets`
- Live grant checks found `social.social_post_observations` and `social.social_post_legacy_refs` have `service_role` privileges only among the checked roles.
- Live policy checks returned no public read policies for `social.social_post_observations` or `social.social_post_legacy_refs`.
- Phase 0 still cannot be accepted as execution-ready until the canonical foundation migration is tracked on the target backend branch, or the plan is revised to remove the canonical-table dependency.

## Current Schema Evidence

Legacy Instagram post/comment tables:

- `0101_social_scrape_tables.sql` creates `social.instagram_posts.raw_data` and `social.instagram_comments.raw_data`.
- The same migration grants `select` on both tables to `anon` and `authenticated`, enables RLS, and creates public read policies using `true`.
- Live Supabase MCP grant/policy checks confirmed `social.instagram_posts` and `social.instagram_comments` have `anon` and `authenticated` `SELECT` plus public read policies using `true`.
- Current classification: `social.instagram_posts.raw_data` is public, and `social.instagram_comments.raw_data` is public.

Shared-account catalog:

- `0199_shared_account_catalog_backfill.sql` creates `social.instagram_account_catalog_posts.raw_data`.
- The same migration grants `select` on the table to `anon` and `authenticated`, enables RLS, and creates a public read policy using `true`.
- Live Supabase MCP grant/policy checks confirmed `social.instagram_account_catalog_posts` has `anon` and `authenticated` `SELECT` plus a public read policy using `true`.
- Current classification: `social.instagram_account_catalog_posts.raw_data` is public.

Canonical observation payloads:

- `20260428152000_social_post_canonical_foundation.sql` creates `social.social_post_observations.raw_payload` and `normalized_payload`.
- The migration grants this table to `service_role` and revokes `public`, `anon`, and `authenticated`.
- Live Supabase MCP grant/policy checks confirmed `social.social_post_observations` is service-role-only among checked roles and has no public read policy.
- Current classification: `social.social_post_observations.raw_payload` and `normalized_payload` are service-role-only in the checked live schema.

Recent Instagram-specific migrations to reconcile:

- `20260323173500_add_instagram_post_search_columns.sql` adds `search_text`, `search_hashtags`, `search_handles`, and `search_handle_identities` to `social.instagram_posts`.
- `20260428114500_instagram_catalog_post_collaborators.sql` creates `social.instagram_account_catalog_post_collaborators`, backfills it from catalog `collaborators` and `raw_data->collaborators_detail`, grants public read, and anchors rows to `catalog_post_id`.

Job constraint evidence:

- `0201_shared_account_discovery_job_type.sql` defines `scrape_jobs_job_type_check_v6`.
- Allowed static job types include `posts`, `comments`, `search`, `replies`, `shared_account_posts`, `shared_account_discovery`, `post_classify`, `season_materialize`, `analytics_refresh`, platform media-mirror jobs, and platform comment-media-mirror jobs.
- Live Supabase MCP confirmed the active `scrape_jobs_job_type_check_v6` constraint allows the same existing job types and does not allow `instagram_profile_snapshot`, `instagram_profile_following`, or `instagram_profile_relationships`.

Hot file evidence:

- `TRR-Backend/trr_backend/repositories/social_season_analytics.py` is 60,646 lines.
- Static search found `_upsert_instagram_post` at line 16306 and seven call sites at lines 18851, 19142, 30018, 31353, 31511, 31537, and 50261.
- The same file contains `_batch_upsert_instagram_comments`, `_batch_upsert_shared_catalog_instagram_posts`, `get_social_account_profile_summary`, and the Instagram profile/catalog/comment read paths.

## Storage Map

Default rule: new queryable post-level data should go through the canonical `social.social_post*` foundation when the field fits that cross-platform model. Legacy Instagram tables stay compatibility/source tables unless a bridge is required for an existing read path.

| Field family | Selected storage surface | Notes and blockers |
| --- | --- | --- |
| Post identity, platform source id, owner handle/id, canonical URL, caption/body, media type, posted time, top-level likes/comments/views/shares/saves/quotes | `social.social_posts` | Use `platform='instagram'` and stable source id. Do not deepen duplicate scalar storage in both `instagram_posts` and catalog posts except temporary bridge fields. |
| Account/show/season/person membership and assignment | `social.social_post_memberships` | Replaces catalog-only assignment as the canonical query surface once each legacy row is materialized to a canonical post. |
| Hashtags, mentions, collaborators, URLs, external ids, sounds/music keys | `social.social_post_entities` | Current entity type check supports `hashtag`, `mention`, `collaborator`, `sound`, `url`, and `external_id`. New entity kinds need a foundation extension before migration work. |
| Tagged users and location | Prefer `social.social_post_entities` if the canonical entity type check is extended; otherwise use Instagram-specific extension tables | Current static migration does not include `tagged_user` or `location` in the entity type check. This is a Phase 1 schema-design blocker, not a reason to add duplicate legacy child tables. |
| Media variants, hosted media, thumbnails, dimensions, duration, carousel slide assets, mirror state | `social.social_post_media_assets` | `duration_seconds` is integer in the canonical table; subsecond `video_duration` can remain in `media_payload` unless a numeric duration column is approved. |
| Raw source snapshots and normalized extraction diagnostics | `social.social_post_observations` | Must remain private/service-role-only. Live access is verified; target-branch acceptance is still blocked until the canonical migration is tracked. |
| Legacy row traceability | `social.social_post_legacy_refs` | Required for `social.instagram_posts.id` and `social.instagram_account_catalog_posts.id` traceability. Legacy IDs should not be the parent for new child/query tables. |
| Instagram search columns | Existing `social.instagram_posts.search_*` columns remain compatibility bridge fields | Do not add new legacy search columns. Canonical search should derive from `social_posts.body` plus `social_post_entities` after canonical materialization. |
| Catalog collaborators | Existing `social.instagram_account_catalog_post_collaborators` remains a public compatibility table | Future canonical collaborator queries should read `social.social_post_entities` after legacy catalog rows have canonical refs. Do not create `social.instagram_post_collaborators` unless a written exception proves the catalog table and canonical entity table are insufficient. |
| Full comments and replies | Existing `social.instagram_comments` remains the current full-comments persistence path | Any new canonical comment bridge or query surface must reference `canonical_post_id` by default. Existing `instagram_comments.post_id -> instagram_posts.id` is a legacy constraint and must be bridged through `social_post_legacy_refs` before canonical comment reads are claimed. |
| Profile identity, biography/about, follower/following/post counts, business/private/verified flags, profile picture variants | Instagram-specific profile table, proposed `social.instagram_profiles` | No current static migration creates this table. Raw columns such as `raw_data` and `about_raw` must be service-role-only, with curated reads exposed through backend/admin APIs or views. |
| Profile external links | Instagram-specific child table, proposed `social.instagram_profile_external_links` | Parent should be the Instagram profile row, not a post. Public/API exposure should be curated fields only. |
| Following-list relationships | Instagram-specific child table, proposed `social.instagram_profile_relationships` | In scope for following lists only. Follower-list scraping remains out of scope. Rows from payloads claiming follower mode must be skipped/rejected or preserved only as raw diagnostics. |
| Viewer-session fields such as `has_liked`, `has_viewer_saved`, `friendship_status`, `top_likers`, shared-follower account samples | Private diagnostics only | Store only in `social.social_post_observations` or planned profile diagnostic raw columns if needed. Do not expose as business facts. |
| Media notes, repost/floating context, source-shape edge cases | Private diagnostics first; Instagram extension only if a stable query need is approved | These do not justify new public legacy columns during Phase 0. |

## Raw-Data Exposure Strategy

Current status:

| Column | Current classification | Evidence |
| --- | --- | --- |
| `social.instagram_posts.raw_data` | public | Created in `0101_social_scrape_tables.sql`; live table has `anon`/`authenticated` `SELECT` grants and public read policy. |
| `social.instagram_comments.raw_data` | public | Same `0101_social_scrape_tables.sql` posture; live table has `anon`/`authenticated` `SELECT` grants and public read policy. |
| `social.instagram_account_catalog_posts.raw_data` | public | Created in `0199_shared_account_catalog_backfill.sql`; live table has `anon`/`authenticated` `SELECT` grants and public read policy. |
| `social.social_post_observations.raw_payload` | service-role-only | Live table has service-role privileges only among checked roles and no public read policy. Target branch still must track the canonical migration. |
| `social.social_post_observations.normalized_payload` | service-role-only | Same canonical observation table. Target branch still must track the canonical migration. |
| planned `social.instagram_profiles.raw_data` | absent; must be service-role-only if created | No static migration currently creates it. |
| planned `social.instagram_profiles.about_raw` | absent; must be service-role-only if created | No static migration currently creates it. |

Exposure options before Phase 1:

1. Compatibility-risk option: keep existing legacy public reads temporarily, document raw columns as transitional public risk, and expose new curated fields only through backend/admin APIs. This avoids breaking existing consumers but does not satisfy a private-raw posture.
2. Curated-view option: revoke public reads on raw-bearing legacy tables and replace public consumers with views or backend routes that omit raw payload columns. This is the preferred privacy posture but needs consumer inventory and app/backend follow-through.
3. Backend-only option: make all raw-bearing Instagram tables service-role-only and require every admin/public read through backend APIs. This is cleanest but has the largest compatibility blast radius.

Current decision: do not claim raw payloads are private. The legacy raw columns are public by static and live Supabase evidence. Phase 1+ must either approve a transitional risk with a deadline or first implement curated views/API replacements and grant cleanup.

## Phase 1 Source Field Direction

Phase 1 must inventory actual repo-native Instagram source shapes first. Apify-style flattened names are adapter/reference aliases only.

Canonical source families to inspect and map:

- Profile timeline GraphQL/XDT connection:
  - `xdt_api__v1__feed__user_timeline_graphql_connection`
  - `PolarisProfilePostsTabContentQuery_connection`
  - request tags including `fb_api_req_friendly_name`, `doc_id`, `variables`, `av`, `__user`, `__a`, `__req`, `__comet_req`, `x-fb-friendly-name`, and `x-fb-lsd`
  - response paths `data.xdt_api__v1__feed__user_timeline_graphql_connection.edges`, `.page_info`, and `.count`
- Shortcode/permalink GraphQL and HTML fallbacks:
  - `PolarisPostActionLoadPostQueryQuery`
  - `data.xdt_shortcode_media`
  - legacy `graphql.shortcode_media`
  - `script[data-sjs]`, `window._sharedData`, `__additionalDataLoaded(...)`, `script[type="application/ld+json"]`, `meta[property="og:image"]`, and `meta[property="og:video"]`
- Media-info REST:
  - `https://www.instagram.com/api/v1/media/{media_id}/info/`
  - `items[0]`, `caption.text`, `media_type`, `product_type`, `image_versions2.candidates[]`, `video_versions[]`, `carousel_media[]`, `original_width`, `original_height`, `usertags.in[]`, and `coauthor_producers[]`
- Web profile info:
  - `https://www.instagram.com/api/v1/users/web_profile_info/?username={username}`
  - `data.user`, `data.user.edge_owner_to_timeline_media.edges`, `.page_info`, and `.count`
  - profile scalar fields such as `username`, `id`, `full_name`, `biography`, counts, privacy/verification flags, and profile picture variants
- Comments REST:
  - `https://www.instagram.com/api/v1/media/{media_id}/comments/` and reply-page endpoints used by the comments lane
  - page/cursor fields `comments[]`, `has_more_comments`, `has_more_headload_comments`, `next_min_id`, `next_max_id`, `child_comments[]`, `has_more_tail_child_comments`, and `next_min_child_cursor`
  - comment fields `pk`, `id`, `text`, `created_at`, `timestamp`, `comment_like_count`, `like_count`, `user.*`, `owner.*`, `replies[]`, and `child_comments[]`

Apify/reference aliases such as `shortCode`, `displayUrl`, `videoUrl`, `ownerUsername`, `ownerFullName`, `ownerId`, `locationName`, `locationId`, `taggedUsers`, `coauthorProducers`, `musicInfo`, `videoPlayCount`, `videoDuration`, `commentsCount`, and `likesCount` must map into those source families. `latestComments` and `firstComment` remain excluded from comment persistence.

## Job Type And Stage Strategy

Option A: add new job types.

- Candidate values: `instagram_profile_snapshot`, `instagram_profile_following`, `instagram_profile_relationships`.
- Benefit: explicit queue semantics.
- Current blocker: `scrape_jobs_job_type_check_v6` does not allow these values. This option requires a tracked migration and live/local constraint validation before any runner writes those job types.

Option B: use existing job types with `config.stage`.

- Candidate job type: `shared_account_discovery`.
- Candidate stages:
  - `instagram_profile_snapshot`
  - `instagram_profile_following`
- Benefit: compatible with the static `job_type` constraint because `shared_account_discovery` is allowed, and current repository code already reads stage from `config->>'stage'`, `metadata->>'stage'`, or `job_type`.
- Constraint: worker routing, dedupe keys, progress labels, and run summaries must explicitly support those stages before jobs are emitted.

Phase 0 default decision: use Option B unless the user explicitly approves an Option A constraint migration. The current hard blocker is that no profile/following runner work may write new job_type values, and no jobs may be emitted until stage routing/dedupe/progress compatibility is implemented after Phase 0 approval.

## Child-Table Parent Strategy

- Default parent key for new post child/query tables: `canonical_post_id` referencing `social.social_posts.id`.
- Legacy Instagram IDs are traceability data only through `social.social_post_legacy_refs`.
- If a catalog-only row lacks a canonical post, materialize the canonical post first or skip child-row sync until one exists.
- Approved exceptions in this Phase 0 note: none.
- Existing exceptions that remain legacy compatibility surfaces:
  - `social.instagram_comments.post_id` currently references `social.instagram_posts.id`.
  - `social.instagram_account_catalog_post_collaborators.catalog_post_id` currently references `social.instagram_account_catalog_posts.id`.
- Those existing legacy parents must not be copied into new schema as the default pattern.

## Comment Scope

Closed decision:

- Embedded/latest comments are not persisted as comments.
- `latestComments`, `firstComment`, XDT embedded snippets, and similar partial samples are not inserted into `social.instagram_comments`.
- Do not create `social.instagram_post_embedded_comments`.
- Do not count embedded/latest comment snippets as comment coverage.
- Full comments scrape payloads remain the only persisted/queryable Instagram comment source.

## Profile Backfill Coverage

- Static migration search did not find an existing `social.instagram_profiles` table or profile/about raw payload table.
- Existing legacy post/catalog raw payloads may contain some owner/profile-like fields, but static evidence is not enough to claim full profile/about backfill coverage.
- Current decision: profile backfill coverage is partial. Missing profile/about/external-link fields require bounded fresh profile snapshot scrapes after the profile table and job-stage strategy are approved.

## Ownership Rule

- `TRR-Backend/trr_backend/repositories/social_season_analytics.py` is a hot file and must have exactly one writer during Phase 1+.
- Phase 0 assigns no implementation writer because Phase 1+ is not approved.
- Before any implementation starts, the user must explicitly approve either the main session or one named worker as the sole writer for this file.
- All other workers are read-only on `social_season_analytics.py`. If they discover required monolith edits, they must produce a patch request or handoff for the named owner instead of editing the file directly.

## Phase 1+ Approval Gate

Stop here.

No one should start Phase 1 migrations, Python implementation, tests, backfills, subagents, or DB mutation until the user reviews and approves this decision note.

Required approvals before Phase 1+:

- Resolve or accept the canonical foundation blocker: track/apply the canonical migration or revise the plan to not depend on it.
- Accept the current live/local schema verification or refresh it against the exact execution environment if it changes.
- Choose the raw-data exposure strategy.
- Confirm the `config.stage` strategy or approve a job_type constraint migration.
- Name the single `social_season_analytics.py` writer.

## Assumptions And Blockers

Assumptions:

- The approved scope is documentation-only for Commit -1 and Phase 0.
- Static migration posture plus live Supabase MCP checks are acceptable evidence for this artifact, but not for accepting Phase 1+ as execution-ready while the canonical migration is untracked.
- Legacy Instagram tables remain compatibility/source tables during the first implementation pass.

Blockers:

- The canonical foundation migration is present on disk but untracked in the backend repo, so target-branch evidence is incomplete.
- Legacy raw payloads are public by static and live Supabase evidence.
- New profile/following job types are blocked by the current `scrape_jobs_job_type_check_v6` constraint unless a migration is approved.
- Existing comments and catalog collaborator child tables still parent to legacy IDs; canonical child/query tables require canonical materialization and `social_post_legacy_refs`.
- No `social_season_analytics.py` implementation writer has been named for Phase 1+.
