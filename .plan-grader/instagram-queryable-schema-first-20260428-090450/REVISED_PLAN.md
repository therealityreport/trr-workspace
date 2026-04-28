# Instagram Queryable Data Plan

## summary

Make Instagram post, profile, profile-relationship, and comment scrape data accessible through typed, searchable, and queryable database surfaces instead of leaving meaningful fields only in `raw_data`. The work is backend-first and schema-first: decide how the Instagram work aligns with the newer cross-platform `social.social_posts` foundation, define the canonical post/profile/following/comment data contract, add additive schema for scalar fields and nested child entities, update all Instagram normalizers to populate that contract, backfill existing rows from `raw_data`, then expose the fields through admin/profile/catalog/comment read paths without breaking existing UI consumers.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`

## plan_grader_revision

- Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`
- Previous Plan Grader package: `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-data-20260428-085436`
- This artifact package: `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-schema-first-20260428-090450`
- Verdict: `APPROVED_WITH_REVISIONS`
- Required revisions integrated here:
  - add a schema architecture decision gate before Instagram table changes;
  - align post-level storage with the existing `social.social_posts` canonical foundation instead of deepening duplicate `instagram_posts` / `instagram_account_catalog_posts` surfaces;
  - keep legacy Instagram tables stable as compatibility/source tables during migration;
  - keep raw observations private/service-role and expose curated fields through backend/admin APIs;
  - keep follower-list scraping out of scope while preserving follower counts as profile scalar fields;
  - incorporate all ten prior `SUGGESTIONS.md` items as concrete tasks under `ADDITIONAL SUGGESTIONS`.

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owns social schema, scrape persistence, and admin social profile contracts. App follow-through should happen after backend contract changes.
- Existing canonical saved posts table `social.instagram_posts` already stores core fields and several enriched metadata columns: shortcode, media id, username, caption, media type, media URLs, engagement counts, posted/scraped timestamps, tags, mentions, collaborators, owner avatar fields, dimensions, music info, video duration, and child post data.
- Existing catalog table `social.instagram_account_catalog_posts` stores a smaller shared-account row shape: source id/account, posted time, permalink, caption/text, media fields, hashtags, mentions, collaborators, profile tags, engagement counts, raw data, assignment fields, and later Apify-style enrichment fields.
- Current posts-Scrapling persistence narrows XDT/GraphQL nodes into `_ScraplingPostDTO`, then writes through `_upsert_instagram_post`. That adapter currently maps only shortcode/code, media type, caption, likes, comments, views, taken_at, owner username, pk, image/video URLs, thumbnail, and raw node.
- The richer scraper path already knows how to extract hashtags, mentions, post type, tagged users, collaborators, owner detail, dimensions, comments-disabled, music info, audio URL, video duration, and child posts.
- There is an Apify normalizer that recognizes many of the fields in the sample payload, including `shortCode`, `displayUrl`, `videoUrl`, dimensions, owner fields, latest comments, tagged users, coauthors, location, and music info, but that contract is not consistently promoted into canonical database columns.
- Current `social.instagram_comments` already stores the core comment/reply model: external comment id, post id, parent comment id, username, user id, text, likes, reply count, created/scraped timestamps, author profile picture URL, author verification, hosted author profile picture URL, media URLs, lifecycle state, and raw data. The plan must explicitly preserve and validate that contract for Apify-style comment payloads with nested `replies`.
- Current profile support is partial. Instagram runtime code can fetch profile info from `https://www.instagram.com/api/v1/users/web_profile_info/` and extracts some profile fields such as biography/following count, while repository read paths use cached profile snapshots and `social.shared_account_sources`. There is no confirmed typed profile table covering the full profile sample, external link list, account-about fields, profile picture variants, or queryable following-list relationship rows.
- Newer canonical social-post foundation tables already exist in `social.social_posts`, `social.social_post_observations`, `social.social_post_legacy_refs`, `social.social_post_memberships`, `social.social_post_entities`, and `social.social_post_media_assets`. The Instagram queryable-data work must align with this foundation instead of adding duplicate post-level query surfaces wherever the cross-platform tables already fit.

## assumptions

- The requirement is not to make every volatile Instagram viewer/session field a first-class business concept. It is to make every known scrape field accessible without ad hoc raw JSON spelunking.
- `raw_data` remains the forensic source of truth, but known fields must be mirrored into typed columns or child tables with indexes where they will be filtered, searched, joined, or displayed.
- Nested repeatable data should use child tables when it needs independent filtering or joining; JSONB columns are acceptable only when paired with stable extraction and GIN/path indexes for queryability.
- Additive migrations are preferred. Existing admin routes and UI should keep working while new fields roll out.
- Backend schema and persistence land before TRR-APP display/filter changes.
- The first implementation decision is not "add columns to every Instagram table." It is to map each field to the narrowest durable surface: cross-platform canonical post table, cross-platform child table, Instagram-specific extension/profile table, private observation table, or legacy compatibility table.
- `social.instagram_posts` and `social.instagram_account_catalog_posts` should remain stable compatibility/source tables during the first pass. Do not rebuild them or expand them with fields already covered by `social.social_posts`, `social_post_entities`, or `social_post_media_assets` unless a legacy read path requires an additive bridge column.

## goals

1. Define a canonical Instagram post, profile, profile-relationship, and comment source contract covering Apify flattened output, Instagram GraphQL/XDT `media` nodes, profile/about payloads, following list payloads, and comment/reply payloads.
2. Add queryable storage for currently raw-only fields, including owner identity, profile identity/about fields, profile external links, profile counts, following-list relationships, location, post flags, caption metadata, media variants, tagged users, collaborators, embedded/latest comments, repost/media-note context, and engagement visibility state.
3. Make posts-Scrapling populate the same enriched DTO fields as the richer parser wherever the raw node contains them.
4. Keep `social.instagram_posts`, `social.instagram_account_catalog_posts`, and the newer `social.social_posts` foundation aligned enough that profile/catalog/admin reads do not disagree about what data exists.
5. Backfill existing rows from `raw_data` into new columns/tables.
6. Add tests that prove representative Apify, XDT, profile, following-list, and comment/reply payloads populate typed surfaces, not only `raw_data`.

## non_goals

- Do not replace the comments scrape lane. Embedded `latestComments` should be treated as a partial sample or seed, not complete comment coverage.
- Do not make viewer-personal fields operationally authoritative, such as `has_liked`, `has_viewer_saved`, `friendship_status`, or `top_likers`. Store them only if explicitly useful for diagnostics and clearly labeled as viewer-session state.
- Do not scrape followers lists. Follower counts from the profile payload are in scope, but follower list rows are out of scope.
- Following-list retrieval must be explicit, paginated, resumable, and capped by configuration because some accounts can follow many other accounts.
- Do not remove `raw_data`.
- Do not require a destructive table rebuild.
- Do not broaden this to TikTok/Twitter/YouTube until Instagram is stable.

## phased_implementation

### Phase 0: Schema Architecture Decision Gate

Before adding Instagram-specific schema, decide the storage map for every field family against the current social schema. This phase prevents the implementation from deepening duplication between `social.instagram_posts`, `social.instagram_account_catalog_posts`, and the newer cross-platform canonical tables.

Current-state checks:

- Inspect current table definitions and RLS/grants for:
  - `social.instagram_posts`
  - `social.instagram_account_catalog_posts`
  - `social.instagram_comments`
  - `social.shared_account_sources`
  - `social.social_posts`
  - `social.social_post_observations`
  - `social.social_post_legacy_refs`
  - `social.social_post_memberships`
  - `social.social_post_entities`
  - `social.social_post_media_assets`
  - `social.scrape_jobs`
  - `social.scrape_runs`
- Inspect current backend readers/writers that still depend directly on legacy Instagram tables:
  - `_upsert_instagram_post`
  - `_batch_upsert_shared_catalog_instagram_posts`
  - `_batch_upsert_instagram_comments`
  - `get_social_account_profile_summary`
  - Instagram profile/catalog/detail/comment queries in `social_season_analytics.py`.
- Confirm whether any current table already stores raw full profile/about payloads. If not, record profile backfill coverage as partial and require bounded fresh profile scrapes for missing fields.

Storage decision rules:

- Put cross-platform post identity, owner, URL, title/body, posted time, and top-level engagement counts in `social.social_posts` where the canonical foundation already supports them.
- Put hashtags, mentions, collaborators, external ids, and other repeated post entities in `social.social_post_entities` when the data can be represented platform-neutrally.
- Put media variants, hosted media, thumbnails, dimensions, duration, and mirror state in `social.social_post_media_assets` when the data can be represented platform-neutrally.
- Put raw source payload snapshots in `social.social_post_observations`; keep this table private/service-role and do not expose it to `anon` or broad authenticated reads.
- Put legacy row mappings in `social.social_post_legacy_refs` so existing `instagram_posts` and `instagram_account_catalog_posts` rows can be traced without a destructive rebuild.
- Add Instagram-specific extension tables only for data that does not fit the cross-platform foundation, such as profile/about fields, Instagram external links, following-list rows, media notes, and source-shape diagnostics.
- Keep `social.instagram_posts` and `social.instagram_account_catalog_posts` stable as compatibility/source tables. Add bridge columns only when an existing admin read path cannot reasonably join through the canonical foundation yet.

Deliverables:

- Add `docs/ai/local-status/instagram-queryable-schema-decision-2026-04-28.md` documenting:
  - each field family and its selected storage surface;
  - which legacy Instagram tables remain compatibility-only;
  - which fields require Instagram-specific tables;
  - which tables are public read vs service-role/private;
  - raw profile backfill availability;
  - selected profile/following job-stage names.
- Update the plan if the gate finds an existing canonical profile or following table that should be reused instead of creating a new one.

Validation:

- Static schema inspection or live Supabase schema query confirming the listed tables, grants, and RLS policies.
- A field-to-table matrix reviewed against `20260428152000_social_post_canonical_foundation.sql`, `0101_social_scrape_tables.sql`, `0199_shared_account_catalog_backfill.sql`, and `0179_shared_social_account_ingest.sql`.

Acceptance criteria:

- No implementation worker starts migrations until the storage map is written and reviewed.
- The plan explicitly avoids duplicating fields into both legacy Instagram tables and cross-platform canonical tables unless the field is needed as a temporary compatibility bridge.
- Private raw payload and public/admin curated-read boundaries are documented before new tables are created.

Commit boundary:

- Commit 0: schema decision note and any plan updates required by the decision gate.

### Phase 1: Field Inventory And Contract

Create a backend-owned Instagram field matrix from the provided payload families:

- Apify-style flattened post output: `shortCode`, `type`, `displayUrl`, `videoUrl`, `dimensionsWidth`, `dimensionsHeight`, `ownerUsername`, `ownerFullName`, `ownerId`, `locationName`, `locationId`, `latestComments`, `taggedUsers`, `coauthorProducers`, `musicInfo`, `videoPlayCount`, `videoDuration`.
- Instagram XDT `media` nodes: `code`, `pk`, `id`, `media_type`, `image_versions2`, `video_versions`, `original_width`, `original_height`, `caption.pk`, `caption.text`, `caption_is_edited`, `accessibility_caption`, `user`, `owner`, `owner_id`, `usertags`, `coauthor_producers`, `location`, `media_notes`, `floating_context_items`, `comment_count`, `like_count`, `like_and_view_counts_disabled`, `comments_disabled`, `commenting_disabled_for_viewer`, `media_repost_count`.
- Profile payloads: `inputUrl`, `id`, `username`, `url`, `fullName`, `biography`, `about.accounts_with_shared_followers`, `about.country`, `about.date_joined`, `about.date_joined_as_timestamp`, `about.date_verified`, `about.date_verified_as_timestamp`, `about.former_usernames`, `about.id`, `about.is_verified`, `about.username`, `followersCount`, `followsCount`, `postsCount`, `highlightReelCount`, `igtvVideoCount`, `isBusinessAccount`, `joinedRecently`, `hasChannel`, `businessCategoryName`, `private`, `verified`, `externalUrl`, `externalUrlShimmed`, `externalUrls[]`, `profilePicUrl`, and `profilePicUrlHD`.
- Following-list payloads: `username_scrape`, `type`, `full_name`, `id`, `is_private`, `is_verified`, `profile_pic_url`, and `username`. The contract must treat the requested scrape mode as `following` only. If a source payload says `type: "Followers"`, the implementation must not persist it as a follower row; it should reject/skip the row or store the raw mismatch only as diagnostics.
- Comment/reply payloads: `id`, `text`, `ownerUsername`, `ownerProfilePicUrl`, `owner.id`, `owner.username`, `owner.is_verified`, `owner.profile_pic_url`, `timestamp`, `likesCount`, `repliesCount`, and recursive `replies`.

Deliverables:

- Add `TRR-Backend/docs/social/instagram-data-contract.md`.
- Add or update a machine-readable field map, for example `TRR-Backend/docs/social/instagram-data-field-map.json`, so drift checks and tests do not rely only on prose.
- Classify every known field as:
  - normalized scalar column
  - child table row
  - indexed JSONB diagnostic column
  - intentionally ignored viewer-session field
  - raw-only unknown/future field
- Include source-field aliases for Apify, legacy GraphQL, REST/XDT, and current TRR DTO names.

Validation:

- Doc review against `trr_backend/socials/instagram/scraper.py`, `trr_backend/socials/instagram/posts_scrapling/persistence.py`, `trr_backend/socials/instagram/apify_scraper.py`, `trr_backend/socials/instagram/runtimes/*`, and `trr_backend/repositories/social_season_analytics.py`.

Acceptance criteria:

- The contract explicitly says where profile/about fields, profile external links, profile picture variants, following list rows, `locationName/locationId`, owner id/profile pic/full name, tagged users, coauthors, embedded comments, full comments/replies, caption metadata, media notes, image/video variants, and disabled-count flags go.

Commit boundary:

- Commit 1: documentation-only contract, source-field matrix, and machine-readable field map.

### Phase 2: Additive Canonical Schema

Add additive migrations only after Phase 0 assigns each field to the right surface. Prefer the existing cross-platform canonical foundation for post-level data. Use Instagram-specific tables for profile/about/following data and platform-only post details. Keep legacy Instagram tables stable unless a temporary bridge column is necessary for existing reads.

Post-level canonical surfaces:

- Use `social.social_posts` for post identity, owner, canonical URL, text/body, media type, posted time, and top-level engagement counts.
- Use `social.social_post_entities` for hashtags, mentions, collaborators, profile tags, audio/sound references, and external ids where a platform-neutral entity representation works.
- Use `social.social_post_media_assets` for display/video/thumbnail/carousel media variants, hosted mirrors, dimensions, duration, and mirror status.
- Use `social.social_post_observations` for source raw payloads and normalized payload snapshots. Keep this table private/service-role.
- Use `social.social_post_legacy_refs` to map canonical rows back to `instagram_posts` and `instagram_account_catalog_posts`.
- Use `social.social_post_memberships` for account/show/season/person membership and assignment state where it replaces catalog-only assignment fields.

Legacy Instagram bridge columns to add only if Phase 0 proves they are needed:

- `source_input_url text`
- `source_post_id text`
- `permalink text` on `social.instagram_posts` if absent
- `caption_id text`
- `caption_is_edited boolean`
- `caption_has_translation boolean`
- `owner_user_id text`
- `owner_username text`
- `owner_full_name text` alignment for catalog
- `owner_profile_pic_url text` alignment for catalog
- `owner_profile_pic_url_hd text`
- `owner_is_verified boolean` alignment for catalog
- `location_id text`
- `location_name text`
- `location_raw jsonb not null default '{}'::jsonb`
- `original_width integer`
- `original_height integer`
- `like_and_view_counts_disabled boolean`
- `comments_disabled boolean`
- `commenting_disabled_for_viewer boolean`
- `media_repost_count integer`
- `is_paid_partnership boolean`
- `is_advertisement boolean`
- `can_viewer_reshare boolean`
- `has_audio boolean`
- `audio_url text` on `instagram_posts` if absent

These bridge columns are not the preferred long-term storage for fields already covered by `social.social_posts`, `social_post_entities`, or `social_post_media_assets`.

Instagram-specific post child/query tables, only when not covered by canonical child tables:

- `social.instagram_post_media_variants`
  - post id, surface (`canonical` or `catalog`), source id, media role (`display`, `video`, `thumbnail`, `carousel_child`, `image_candidate`, `video_candidate`), URL, width, height, content type hint, variant index, raw data.
- `social.instagram_post_tagged_users`
  - post id/surface/source id, tagged username, user id, full name, verified, profile pic URL, profile pic HD URL, tag x/y, source path, raw data.
- `social.instagram_post_collaborators`
  - post id/surface/source id, collaborator username, user id, full name, verified, profile pic URL, source path, raw data.
- `social.instagram_post_embedded_comments`
  - post id/surface/source id, comment id, text, owner username, owner user id, owner profile pic URL, owner verified, created at, likes count, replies count, is reply, parent comment id, source snapshot type, raw data.
- `social.instagram_post_context_items`
  - post id/surface/source id, context type, media note id, note text, actor username/user id, actor profile pic URL, raw data.

Comment table alignment:

- Confirm `social.instagram_comments` has queryable coverage for the required comment payload:
  - sample `id` -> `comment_id`
  - `text` -> `text`
  - `ownerUsername` / `owner.username` -> `username`
  - `owner.id` -> `user_id`
  - `ownerProfilePicUrl` / `owner.profile_pic_url` -> `author_profile_pic_url`
  - hosted avatar mirror -> `hosted_author_profile_pic_url`
  - `owner.is_verified` -> `author_is_verified`
  - `timestamp` -> `created_at`
  - `likesCount` -> `likes`
  - `repliesCount` -> `reply_count`
  - nested `replies[]` -> separate `social.instagram_comments` rows with `is_reply = true` and `parent_comment_id` pointing at the parent DB row.
- Add only missing additive columns if the inventory finds gaps, such as `author_full_name`, `author_profile_pic_url_hd`, `parent_comment_external_id`, `root_comment_id`, `reply_depth`, or `source_snapshot_type`.
- Add indexes for comment exploration:
  - `(post_id, created_at desc)`
  - `(post_id, parent_comment_id, created_at asc)`
  - `(username, created_at desc)`
  - optional full-text/trigram index on `text` if admin search needs it.

Profile table:

- Add `social.instagram_profiles` as the typed current/profile snapshot surface:
  - `id uuid primary key default gen_random_uuid()`
  - `shared_account_source_id uuid references social.shared_account_sources(id) on delete set null`
  - `source_scope text`
  - `source_account text`
  - stable Instagram profile id: `profile_id text`
  - `input_url text`
  - `username text`
  - `normalized_username text`
  - `url text`
  - `full_name text`
  - `biography text`
  - `country text`
  - `date_joined text`
  - `date_joined_at timestamptz`
  - `date_verified text`
  - `date_verified_at timestamptz`
  - `former_usernames_count integer`
  - `followers_count bigint`
  - `follows_count bigint`
  - `posts_count bigint`
  - `highlight_reel_count integer`
  - `igtv_video_count integer`
  - `is_business_account boolean`
  - `joined_recently boolean`
  - `has_channel boolean`
  - `business_category_name text`
  - `is_private boolean`
  - `is_verified boolean`
  - `external_url text`
  - `external_url_shimmed text`
  - `profile_pic_url text`
  - `profile_pic_url_hd text`
  - `hosted_profile_pic_url text`
  - `hosted_profile_pic_url_hd text`
  - `about_raw jsonb not null default '{}'::jsonb`
  - `raw_data jsonb not null default '{}'::jsonb`
  - `first_seen_at timestamptz`
  - `last_seen_at timestamptz`
  - `last_scraped_at timestamptz`
  - `last_scrape_job_id uuid`
  - `last_scrape_run_id uuid`
  - Unique constraints:
    - `unique (profile_id)` where profile id exists.
    - fallback unique identity on `source_scope` plus `normalized_username` where profile id is absent.
  - Keep `shared_account_source_id` nullable because following-list rows can discover related accounts that are not curated shared sources.

Profile child/query tables:

- Add `social.instagram_profile_source_links` only if a single profile can map to multiple shared source scopes over time:
  - profile FK
  - `shared_account_source_id`
  - platform/source scope/account handle denormalized for query convenience
  - first seen, last seen, raw/source metadata.
  - Unique constraint on profile plus shared source.
  - If the simpler nullable `shared_account_source_id` column is enough for current use, document why this table is deferred.
- Add `social.instagram_profile_external_links`:
  - profile FK, profile id/username denormalized for search, link index, title, URL, Instagram lynx/shim URL, link type, raw data.
  - Unique constraint on profile plus link index/URL to avoid duplicate rows across repeated scrapes.
- Add `social.instagram_profile_relationships` for following-list rows:
  - owner profile id/username from `username_scrape`
  - `relationship_type text check (relationship_type = 'following')`
  - related user id, related username, related full name
  - related private/verified booleans
  - source profile picture URL and hosted profile picture URL
  - raw data
  - first seen, last seen, scrape job/run ids, optional cursor/page metadata
  - optional `missing_at` / `is_missing` fields only if the implementation supports relationship diffing.
  - Unique constraint on owner, relationship type, and related user id/username.
- Add indexes for profile exploration:
  - `lower(username)` / `normalized_username`
  - `profile_id`
  - `is_verified`, `is_private`, `is_business_account`
  - `business_category_name`
  - `country`
  - `followers_count`, `follows_count`, `posts_count`
  - relationship owner plus type, related username/id, related verified/private flags.

Indexes:

- B-tree indexes for owner username/id, location id/name, posted_at, media type/product type, caption id, disabled-count flags where useful.
- B-tree/GIN indexes for profile links and relationship lookups where the admin/API will filter or search.
- GIN indexes for hashtag/mention/collaborator/profile-tag arrays and selected JSONB diagnostic columns.
- Unique constraints for child tables using post/surface/source id plus natural child identity, e.g. comment id, username/source, media URL/role/index.

Validation:

- Migration SQL tests or schema advisor tests proving new columns exist.
- Existing social profile and catalog tests still pass with null/default values.
- Schema tests prove profile, external-link, and relationship fields exist and are indexed for direct queries.
- Schema tests prove profile rows can join back to `social.shared_account_sources` through `shared_account_source_id` or the approved source-link table.
- Schema tests prove raw observation tables remain private/service-role and curated read tables have the intended RLS/grants.

Acceptance criteria:

- No known field from the post, profile, following-list, or comment sample payloads is trapped only in `raw_data` unless documented as intentionally raw-only.

Commit boundary:

- Commit 2: additive migrations and schema tests.

### Phase 3: Shared Instagram Post/Profile Normalizer

Create reusable backend normalizers that accept Apify flattened payloads, legacy GraphQL nodes, REST/XDT nodes, profile/about payloads, following-list rows, and current DTO-like objects, then return canonical typed structures.

Affected files:

- `TRR-Backend/trr_backend/socials/instagram/post_normalizer.py` new module
- `TRR-Backend/trr_backend/socials/instagram/profile_normalizer.py` new module
- `TRR-Backend/trr_backend/socials/instagram/profile_relationship_normalizer.py` new module
- `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py`
- `TRR-Backend/trr_backend/socials/instagram/scraper.py`
- `TRR-Backend/trr_backend/socials/instagram/apify_scraper.py`
- `TRR-Backend/trr_backend/socials/instagram/runtimes/protocol.py`
- `TRR-Backend/trr_backend/socials/instagram/runtimes/crawlee_runtime.py`
- `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/repositories/social_scrape_jobs.py` or the current scrape-job repository that claims/updates job stages, if profile/following jobs use the shared scrape job system.

Concrete changes:

- Move/centralize alias extraction for:
  - shortcode: `shortcode`, `shortCode`, `code`
  - source id/media id: `id`, `pk`, composite XDT id
  - owner: `user`, `owner`, `owner_id`, `ownerUsername`, `ownerFullName`, `ownerId`
  - media: `displayUrl`, `display_url`, `image_versions2`, `videoUrl`, `video_url`, `video_versions`, carousel children
  - dimensions: `dimensionsWidth`, `dimensionsHeight`, `original_width`, `original_height`, `dimensions`
  - caption: string caption, `caption.text`, caption id, edited/translation flags
  - tags/collaborators: `taggedUsers`, `usertags.in`, `coauthorProducers`, `coauthor_producers`, `invited_coauthor_producers`
  - comments: `latestComments`, first comment, XDT embedded comment snapshots when present
  - full comments/replies: `id`, `pk`, `text`, `ownerUsername`, `ownerProfilePicUrl`, `owner`, `user`, `timestamp`, `created_at`, `likesCount`, `comment_like_count`, `repliesCount`, `child_comment_count`, recursive `replies`
  - profile: `id`, `pk`, `username`, `fullName`, `full_name`, `biography`, profile URLs, profile picture URL variants, verified/private/business flags, follower-count/following-count/post-count fields, `about`, external URL fields, external links, date joined, date verified, country, former username count.
  - profile relationships: `username_scrape`, `type`, related user id, related username, related full name, related profile picture URL, related verified/private flags.
  - flags: disabled counts, comments disabled, paid partnership, advertisement, reshare, audio
  - location and context items.
- Normalize profile relationship direction explicitly:
  - Accept only `Following`, `following`, or `Follows` as persisted `following` rows.
  - Treat `Followers`, `followers`, or `Follower` as out-of-scope for this plan.
  - Require the caller to pass the intended relationship mode. If the source field is absent or contradictory, skip the row or fail the page with a classified mismatch instead of guessing.
- Have posts-Scrapling DTO include all fields that `_upsert_instagram_post` can already save plus new fields introduced by Phase 2.
- Have comments-Scrapling return a canonical `InstagramComment` tree with stable parent/reply relationships and all author fields from the sample payload.
- Have profile fetchers return a canonical `InstagramProfile` with profile scalar fields, `about_raw`, external links, and profile picture variants.
- Have relationship fetchers return a canonical `InstagramProfileRelationship` list plus pagination/cursor metadata.
- Add a concrete runtime/fetcher contract for:
  - fetching one profile snapshot by username;
  - fetching one page of `following`;
  - returning next cursor/page token and a completeness/cap status.
- Add job-runner handling for the selected profile stages:
  - validates `account_handle`, page/cap config, and auth/session requirements;
  - records progress in scrape job/run metadata;
  - stops with a classified status for checkpoint, auth, rate limit, page cap, or source-shape drift.
- Preserve raw payload in `raw_data` with a `normalizer_version` and `source_shape` marker.

Validation:

- Unit tests with at least two fixtures:
  - Apify-style NatGeo/video payload
  - XDT `media` payload with `image_versions2`, `usertags`, `coauthor_producers`, caption object, and disabled-count flags.
- Profile fixture matching the NASA-style payload with `about`, counts, external links, profile picture variants, business category, private/verified flags, and biography.
- Relationship fixture matching the following-list sample with `username_scrape`, `type`, full name, related user id, related username, related avatar URL, private flag, and verified flag. Include a negative fixture where `type` says `Followers` and assert it is not persisted as a follower row.
- Comment fixture matching the sample shape: top-level comment with `id`, `text`, owner username/avatar, timestamp, likes count, replies count, and one nested reply with the same fields.
- Assertions must check typed DTO fields and child entity lists, not only raw JSON retention.

Acceptance criteria:

- posts-Scrapling no longer drops hashtags, mentions, owner details, dimensions, usertags, coauthors, location, media variants, caption metadata, or embedded comment samples when source data includes them.
- profile scraping no longer drops profile `about`, external links, profile picture variants, business/category/private/verified flags, or profile count fields when source data includes them.
- following-list scraping no longer drops relationship direction, related user identity, related display name, related avatar URL, private flag, or verified flag when source data includes them.
- comments-Scrapling no longer drops comment author avatar, author verification, timestamp, likes count, replies count, or nested reply relationships when source data includes them.

Commit boundary:

- Commit 3: shared normalizer and unit tests.

### Phase 4: Persistence And Backfill

Update persistence helpers to write scalar fields and child rows transactionally.

Affected functions:

- `_upsert_instagram_post`
- `_shared_catalog_instagram_post_payload`
- `_batch_upsert_shared_catalog_instagram_posts`
- `persist_instagram_posts`
- `persist_instagram_comments_for_post`
- `_batch_upsert_instagram_comments`
- `_persist_without_season_context`
- new `persist_instagram_profile_snapshot`
- new `persist_instagram_profile_relationships`

Concrete changes:

- Extend `_upsert_instagram_post` payload with new scalar fields.
- Extend catalog payload with matching scalar fields where the table has a column.
- Add a profile persistence helper that upserts `social.instagram_profiles` by durable Instagram profile id when available, falling back to normalized username only when the source lacks id.
- Add a profile external-link sync helper that replaces or upserts a profile's current external link set from `externalUrls[]`.
- Add a profile relationship sync helper that upserts bounded `following` pages into `social.instagram_profile_relationships` without deleting unseen rows unless a separate diff/mark-missing mode is explicitly implemented.
- Add helper functions:
  - `_sync_instagram_post_media_variants`
  - `_sync_instagram_post_tagged_users`
  - `_sync_instagram_post_collaborators`
  - `_sync_instagram_post_embedded_comments`
  - `_sync_instagram_post_context_items`
  - `_sync_instagram_profile_external_links`
  - `_sync_instagram_profile_relationships`
- Add or update comment persistence helpers so both season-context and no-season-context paths write the same fields:
  - comment external id
  - text
  - author username
  - author user id
  - source and hosted author avatar URLs
  - author verification
  - created timestamp
  - likes count
  - replies count
  - `is_reply`
  - parent comment DB id
  - optional parent external id/root/reply-depth fields if added in Phase 2.
- Add a bounded backfill script:
  - `TRR-Backend/scripts/socials/backfill_instagram_post_queryable_fields.py`
  - Reads existing `social.instagram_posts.raw_data` and `social.instagram_account_catalog_posts.raw_data`
  - Reads existing `social.instagram_comments.raw_data`
  - Reads any existing profile snapshot/raw profile metadata from profile caches, shared account source metadata, and scrape result rows that contain profile payloads.
  - Re-runs the shared normalizer
  - Updates post scalar fields, profile scalar fields, profile external links, profile relationship rows, comment scalar fields, and child tables in batches
  - Supports `--dry-run`, `--limit`, `--account`, `--since`, and `--surface canonical|catalog|both`
  - Supports `--include-profiles`, `--include-relationships`, and `--relationship-type following` when applicable.
  - Emits counts for fields found, rows updated, child rows inserted, skipped rows, parse errors.
- Add runtime crawl controls for relationships:
  - `max_relationships_per_profile`
  - `relationship_page_limit`
  - checkpoint/cursor resume metadata
  - clear job warnings when the configured cap stops before the full list.

Validation:

- Unit tests for persistence helpers with fake DB/upsert captures.
- Regression tests proving `_batch_upsert_instagram_comments` and `_persist_without_season_context` produce equivalent payloads for the sample nested comment/reply tree.
- Persistence tests proving the NASA-style profile sample writes profile columns and external link rows.
- Persistence tests proving the following-list sample writes relationship rows with direction, owner username, related username/id, avatar URL, private flag, and verified flag.
- Job-runner tests proving profile snapshot and following-list stages reject follower-list payloads and report capped/checkpoint/rate-limit status.
- Backfill dry-run test against fixture rows.
- Local dry run command documented in the plan output.

Acceptance criteria:

- Existing rows can be upgraded without re-scraping Instagram.
- Existing profile snapshots can be upgraded where raw profile payloads exist.
- If existing profile raw payloads are reduced, the backfill reports partial coverage and does not claim missing profile/about/link fields were recovered.
- Following-list collection is bounded, resumable, and queryable by owner and related account.
- Nested replies are persisted as queryable rows linked to their parent comment, not only as nested JSON.
- Backfill is resumable and does not overwrite non-null higher quality values with null/empty values.

Commit boundary:

- Commit 4: persistence writers and backfill script.

### Phase 5: Query/API/Admin Read Follow-Through

Expose the new queryable data through backend read paths used by social profile pages, catalog details, profile detail panels, relationship lists, and post detail modals.

Affected surfaces:

- Backend profile/catalog post queries in `social_season_analytics.py`
- Backend Instagram profile snapshot queries in `social_season_analytics.py` or a dedicated Instagram profile repository
- Backend Instagram profile relationship list queries
- Backend comment detail/list queries in `social_season_analytics.py`
- `GET /api/v1/admin/socials/profiles/{platform}/{handle}/catalog/posts`
- `GET /api/v1/admin/socials/profiles/{platform}/{handle}/catalog/posts/{post_id}` or existing post detail endpoint
- `GET /api/v1/admin/socials/profiles/instagram/{handle}/profile` or the existing profile-detail endpoint if one already owns this contract
- `GET /api/v1/admin/socials/profiles/instagram/{handle}/relationships?type=following`
- Instagram comments panel/detail endpoints that return comment rows and threaded replies
- TRR-APP compatibility routes and `SocialAccountProfilePage` detail modal, if they currently hide fields operators need.

Concrete changes:

- Add explicit fields to catalog/detail response rows:
  - owner id/full name/profile pic/verified
  - location id/name
  - caption metadata
  - media variants count/detail
  - tagged users detail
  - collaborators detail
  - embedded comment sample count
  - disabled-count/comment flags
  - repost/context count.
- Add explicit fields to comment responses:
  - comment id
  - parent comment id
  - text
  - author username/user id
  - author source avatar URL
  - hosted author avatar URL
  - author verification
  - created timestamp
  - likes count
  - reply count
  - nested replies or enough parent metadata for client-side threading.
- Add explicit fields to profile responses:
  - profile id
  - username and normalized username
  - URL and input URL
  - full name
  - biography
  - account-about fields: country, joined date/timestamp, verified date/timestamp, former username count, account-about verified flag
  - follower/following/post/highlight/IGTV counts
  - business/private/verified/joined-recently/channel flags
  - business category
  - external URL, shimmed external URL, and external link list
  - source and hosted profile picture URLs, including HD variant.
- Add explicit fields to relationship responses:
  - relationship type
  - owner username/profile id
  - related account id
  - related username
  - related full name
  - related private/verified flags
  - related source and hosted profile picture URLs
  - first/last seen timestamps and scrape run/job provenance.
- Keep list views bounded. Detailed nested arrays should load in detail/modal routes, not every profile list row.
- Add backend filters only where immediately valuable:
  - location name/id
  - owner username/id
  - has tagged users
  - has collaborators
  - media type/product type
  - comments disabled / counts disabled.
  - comment author username
  - comment has replies
  - comment date range.
  - profile verified/private/business flags
  - profile business category/country
  - relationship type
  - related username/id
  - related verified/private flags.

Validation:

- Backend route tests for response shape.
- Comment route/repository tests for threaded replies and author metadata.
- Profile route/repository tests for profile fields, external links, and relationship list pagination/filtering.
- App route/runtime tests if frontend contracts change.
- Browser/manual check on a known Instagram social profile page after implementation.

Acceptance criteria:

- Operators can inspect and filter/query the fields without opening raw JSON.
- Operators can inspect and filter/query profile/account-about fields, external links, and bounded following-list relationship rows without opening raw JSON.
- Operators can inspect comments and replies with author avatars, likes, reply counts, timestamps, and parent-child relationships without opening raw JSON.

Commit boundary:

- Commit 5: backend API/read paths, app follow-through if needed.

### Phase 6: Observability And Drift Detection

Add diagnostics so scraper source drift is visible when Instagram or Apify changes shapes.

Concrete changes:

- Add normalizer counters to job metadata:
  - fields promoted
  - known fields missing
  - unknown top-level fields seen
  - child rows persisted
  - profile rows persisted
  - profile external links persisted
  - following relationship rows persisted
  - relationship cap/page-limit reached
  - raw-only fields count.
- Add a lightweight validation function comparing raw payload keys against `instagram-data-contract.md` or a checked-in machine-readable field map.
- Emit job warning diagnostics when source payloads contain known fields that did not map to typed output.
- Emit job warning diagnostics when profile relationship collection stops due to cap, auth/checkpoint, pagination error, or rate limit.

Validation:

- Test a fixture with a new unknown field and assert diagnostics include it without failing the scrape.

Acceptance criteria:

- Future source-shape changes produce actionable diagnostics instead of silent data loss.
- Relationship scrapes report whether they are complete, capped, or checkpoint-blocked.

Commit boundary:

- Commit 6: observability and drift tests.

### ADDITIONAL SUGGESTIONS

These tasks incorporate every item from the previous Plan Grader `SUGGESTIONS.md`. They are required in this revised plan because the user explicitly asked to add them to the plan.

#### Suggestion 1: Add a profile coverage SQL view

- Source: suggestion 1, `Add a profile coverage SQL view`
- Concrete changes:
  - Add a read-focused view, for example `social.instagram_profile_coverage`, that summarizes typed profile field coverage by profile/source account.
  - Include booleans or counts for biography, about fields, external links, profile picture variants, following rows, last scrape status, and raw payload availability.
  - Keep the view based on curated typed tables, not private raw observations.
- Dependencies:
  - Phase 2 profile/profile-link/following schema must exist first.
- Affected surfaces:
  - Supabase migration under `TRR-Backend/supabase/migrations`
  - optional backend repository read helper if admin/API uses the view.
- Validation:
  - Schema test proves the view exists and excludes private raw payload columns.
  - SQL smoke check for one profile returns coverage fields without parsing `raw_data`.
- Acceptance criteria:
  - Operators can inspect profile field completeness with one query or API helper.
- Commit boundary:
  - Include with Phase 2 schema or Phase 6 observability.

#### Suggestion 2: Add profile-link domain normalization

- Source: suggestion 2, `Add profile-link domain normalization`
- Concrete changes:
  - Normalize external link domains from `externalUrl`, `externalUrlShimmed`, and `externalUrls[]`.
  - Store `normalized_domain` and optionally `normalized_url` in `social.instagram_profile_external_links`.
  - Strip Instagram shim wrappers where possible while preserving the original source/shim URL.
- Dependencies:
  - Phase 1 field map and Phase 2 external-link table.
- Affected surfaces:
  - `profile_normalizer.py`
  - `social.instagram_profile_external_links`
  - profile external-link tests.
- Validation:
  - Fixture test with `https://l.instagram.com/?u=...` proves source URL, shim URL, normalized URL, and normalized domain are correct.
- Acceptance criteria:
  - External links are searchable/deduplicable by normalized domain without losing original URL evidence.
- Commit boundary:
  - Include with Phase 3 normalizer and Phase 2 schema if the column is required.

#### Suggestion 3: Store relationship source-page ordinal

- Source: suggestion 3, `Store relationship source-page ordinal`
- Concrete changes:
  - Add page/cursor provenance fields to `social.instagram_profile_relationships`, such as `source_page_ordinal`, `source_cursor`, `source_page_size`, and `source_rank`.
  - Populate these fields from the following-list fetcher/job runner.
- Dependencies:
  - Phase 2 following table and Phase 3 following fetch contract.
- Affected surfaces:
  - following-list fetcher/job runner
  - relationship normalizer
  - relationship persistence helper.
- Validation:
  - Unit test with two pages proves rows preserve page ordinal and rank.
- Acceptance criteria:
  - Partial following-list scrapes can be debugged by page/cursor without re-opening raw payloads.
- Commit boundary:
  - Include with following schema/persistence.

#### Suggestion 4: Add profile identity merge report

- Source: suggestion 4, `Add profile identity merge report`
- Concrete changes:
  - Add a backfill/report mode that detects profile id/username collisions, username changes, and duplicate fallback identities.
  - Report potential merges without mutating identity rows unless an explicit execution flag is added later.
- Dependencies:
  - Phase 2 profile unique constraints and Phase 4 backfill script.
- Affected surfaces:
  - `TRR-Backend/scripts/socials/backfill_instagram_post_queryable_fields.py` or a dedicated profile backfill/report script
  - docs/local-status report output.
- Validation:
  - Fixture/backfill dry-run test creates duplicate username/profile-id scenarios and asserts the report flags them.
- Acceptance criteria:
  - The implementation surfaces identity conflicts before canonical profile rows are merged or overwritten.
- Commit boundary:
  - Include with Phase 4 backfill.

#### Suggestion 5: Add admin-only raw payload diff link

- Source: suggestion 5, `Add admin-only raw payload diff link`
- Concrete changes:
  - Add an admin-only route or modal action that compares curated typed profile/post fields to private raw/normalized observation payloads.
  - Gate this behind existing admin/server-side auth; do not expose private raw observation rows directly to public clients.
- Dependencies:
  - Phase 5 backend API and private observation storage.
- Affected surfaces:
  - backend admin route
  - TRR-APP social profile/detail modal
  - auth/permission checks.
- Validation:
  - Backend route test proves non-admin/public clients cannot read raw payload diff data.
  - App test proves the link/action is not shown outside admin context.
- Acceptance criteria:
  - Operators can audit typed-vs-raw mismatches during rollout without making raw JSON the normal workflow.
- Commit boundary:
  - Include with Phase 5 admin follow-through if admin auth surface is already clear; otherwise defer behind a documented feature flag.

#### Suggestion 6: Add a sampled golden fixture directory

- Source: suggestion 6, `Add a sampled golden fixture directory`
- Concrete changes:
  - Add `TRR-Backend/tests/fixtures/social/instagram/`.
  - Store sanitized representative fixtures for Apify post, XDT media, profile/about, following-list page, comment/reply tree, and negative follower-list payload.
  - Add README describing fixture source shape and redaction expectations.
- Dependencies:
  - Phase 1 field map.
- Affected surfaces:
  - test fixtures
  - normalizer tests
  - persistence tests.
- Validation:
  - Tests load fixtures from disk instead of embedding large payloads inline.
- Acceptance criteria:
  - Future scraper-shape changes can be tested by adding fixture files rather than rewriting test setup.
- Commit boundary:
  - Include with Phase 3 normalizer tests.

#### Suggestion 7: Add a relationship cap explanation field

- Source: suggestion 7, `Add a relationship cap explanation field`
- Concrete changes:
  - Add `cap_status` and `cap_reason` or equivalent metadata to following scrape job/run output and following-list API response.
  - Distinguish source exhausted, configured cap reached, checkpoint/auth stop, rate limit, and source-shape failure.
- Dependencies:
  - Phase 3 job runner and Phase 5 API response.
- Affected surfaces:
  - scrape job/run metadata
  - following persistence metadata
  - profile relationship API.
- Validation:
  - Job-runner tests cover at least configured cap and checkpoint/auth stop.
- Acceptance criteria:
  - Operators can tell why a following list is partial without reading logs or raw JSON.
- Commit boundary:
  - Include with Phase 3/6 job diagnostics.

#### Suggestion 8: Add profile field freshness timestamps

- Source: suggestion 8, `Add profile field freshness timestamps`
- Concrete changes:
  - Add freshness metadata for independently drifting profile field groups, such as `counts_scraped_at`, `about_scraped_at`, `links_scraped_at`, and `profile_pic_scraped_at`.
  - Populate them only when the corresponding field group is observed.
- Dependencies:
  - Phase 2 profile schema and Phase 4 profile persistence.
- Affected surfaces:
  - `social.instagram_profiles`
  - profile persistence helper
  - profile API response.
- Validation:
  - Persistence test proves an update with only counts does not falsely refresh links/about timestamps.
- Acceptance criteria:
  - Refresh policy can later target stale profile field groups without guessing from one `last_scraped_at`.
- Commit boundary:
  - Include with Phase 2 profile schema and Phase 4 persistence.

#### Suggestion 9: Add a migration rollback note

- Source: suggestion 9, `Add a migration rollback note`
- Concrete changes:
  - Add a rollback/disable section to the Phase 2 migration PR notes and local-status baseline.
  - Document how to stop writing new canonical/profile/following tables while keeping legacy reads intact.
  - Avoid destructive rollback instructions unless explicitly approved.
- Dependencies:
  - Phase 0 schema decision and Phase 2 migration contents.
- Affected surfaces:
  - `docs/ai/local-status/instagram-queryable-schema-decision-2026-04-28.md`
  - implementation PR description.
- Validation:
  - Review checklist confirms rollback/disable note exists before migration PR approval.
- Acceptance criteria:
  - Reviewers can evaluate migration blast radius and fallback before deployment.
- Commit boundary:
  - Include with Phase 0/2 docs.

#### Suggestion 10: Add an implementation PR checklist

- Source: suggestion 10, `Add an implementation PR checklist`
- Concrete changes:
  - Add a PR checklist covering schema decision, RLS/grants, normalizer fixtures, following-only scope, backfill dry run, admin/API response checks, and cleanup note.
  - Store the checklist in the local-status baseline or final PR body template.
- Dependencies:
  - Full phase list and accepted scope decisions.
- Affected surfaces:
  - `docs/ai/local-status/`
  - final implementation PR body.
- Validation:
  - Checklist is present and maps to the validation plan before execution handoff.
- Acceptance criteria:
  - Reviewers can verify the multi-workstream implementation without reconstructing the plan.
- Commit boundary:
  - Include with Phase 0 docs and update at final handoff.

## architecture_impact

- Backend remains the owner of Instagram scrape contracts and database shape.
- Schema architecture is now an explicit prerequisite. The implementation must decide whether each post field belongs in the cross-platform canonical foundation or in an Instagram-specific extension before writing migrations.
- `social.social_posts` and its child tables are the preferred durable destination for cross-platform post identity, entities, media, observations, memberships, and legacy refs.
- `social.instagram_posts` and `social.instagram_account_catalog_posts` remain compatibility/source tables during this implementation. They should not become the primary home for new post-level query surfaces when the canonical foundation already supports them.
- posts-Scrapling should stop owning a separate reduced DTO contract. It should call the shared normalizer and then the canonical persistence helpers.
- Profile and relationship fetchers should stop treating profile data as transient profile-page decoration. They should call shared profile normalizers and canonical profile/relationship persistence helpers.
- Catalog and canonical post tables should share a field vocabulary, but do not need identical table shapes for all nested data. Shared child tables can use a `surface` discriminator where needed.
- `social.shared_account_sources` remains the source registry/assignment table. It should not be stretched into the canonical full Instagram profile table.
- Durable Instagram profile id should be preferred over username for identity because usernames can change. Username remains indexed and denormalized for operator search.
- TRR-APP remains a consumer of backend-owned response shapes and should not add direct SQL for the new fields.

## data_or_api_impact

- Additive Supabase migrations in `TRR-Backend/supabase/migrations`.
- Phase 0 must prevent duplicate storage by assigning post fields to `social.social_posts`, `social_post_entities`, `social_post_media_assets`, `social_post_observations`, or Instagram-specific extension tables before adding columns.
- New child tables require service role grants and RLS/read policy decisions consistent with existing social tables.
- New profile/profile-link/profile-relationship tables require service role grants and RLS/read policy decisions consistent with existing social tables.
- Raw observation tables and raw-payload diff routes must be service-role/admin-only. Do not grant direct public `anon` reads to private raw payload tables.
- Following-list rows should be exposed through curated admin/backend responses, not broad public table reads, unless a separate product decision approves public relationship visibility.
- Existing response contracts should be additive; no existing fields should be removed or renamed.
- New or expanded profile endpoints should make following-list completeness explicit via count, cap, cursor, and scrape status metadata.
- Backfill writes must be batched to avoid local/session pool saturation.
- `raw_data` remains present for audit and unknown future fields.

## ux_admin_ops_considerations

- The admin UI should not display every new field in dense lists.
- Detail modals should show new structured sections: Owner, Location, Media Variants, Tagged Users, Collaborators, Embedded Comment Sample, Flags/Diagnostics.
- Profile detail panels should show structured sections: Profile, About, Counts, External Links, Profile Pictures, Relationship Coverage, and Diagnostics.
- Admin-only diagnostics can link to typed-vs-raw diff views, but raw payloads should remain a diagnostic path, not the primary operator workflow.
- List filters should focus on operator value: media type, owner, location, has tags/collabs, comments disabled, counts hidden.
- Relationship list filters should focus on operator value: following, related username, verified/private flags, and first/last seen.
- Backfill should be run from CLI with dry-run first, then bounded batches by account or date.
- Job progress should show promoted-field counts, profile rows, external links, relationship rows, and cap/checkpoint status so operators know the scrape saved more than raw payloads.

## validation_plan

Automated backend checks:

- `pytest tests/repositories/test_social_season_analytics.py -k "instagram"`
- New schema-decision validation test or static check proving the implementation did not duplicate canonical post fields into legacy Instagram tables without documenting the bridge need.
- New tests for `post_normalizer.py` with Apify and XDT fixtures.
- New tests for `profile_normalizer.py` with the NASA-style profile fixture.
- New tests for `profile_relationship_normalizer.py` with the following-list fixture.
- New tests for posts-Scrapling persistence proving typed fields populate `_upsert_instagram_post`.
- New tests for profile persistence proving typed fields populate `social.instagram_profiles`, `social.instagram_profile_external_links`, and `social.instagram_profile_relationships`.
- New tests for comments-Scrapling parsing/persistence proving the sample comment/reply shape populates `social.instagram_comments`.
- New migration/schema tests for added columns/tables.
- New RLS/grant tests or SQL assertions for public curated tables vs private raw observation tables.
- Backfill dry-run unit tests.

Automated app checks if response/UI changes land:

- `pnpm exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx --reporter=dot`
- Targeted route tests for social profile catalog/detail compatibility routes.

Manual checks:

- Run a dry-run backfill for one account with known raw data.
- Run the Phase 0 schema decision check and confirm post-level fields are not duplicated across legacy and canonical tables without an explicit bridge note.
- Inspect one canonical post and one catalog post with SQL selecting new scalar fields and child table rows.
- Inspect one profile with SQL selecting profile id, username, biography, about-derived fields, counts, external URL, profile picture URLs, and external link rows.
- Inspect one relationship list with SQL selecting owner username, relationship type, related username/id, related full name, related avatar URL, private flag, verified flag, and last seen timestamp.
- Inspect one top-level comment and one reply with SQL selecting `comment_id`, `parent_comment_id`, `username`, `user_id`, `author_profile_pic_url`, `author_is_verified`, `created_at`, `likes`, and `reply_count`.
- Open the admin Instagram profile/catalog detail modal and confirm fields render without falling back to raw JSON.

Expected outcomes:

- Representative payload fields from the provided examples appear in typed columns or child tables.
- Post-level fields land in the cross-platform canonical foundation where it fits, and Instagram-only fields land in explicit extension/profile/following tables.
- Representative profile and following-list payload fields appear in typed profile/link/relationship tables.
- Representative comment/reply payload fields appear in typed comment columns with parent-child links.
- Unknown fields remain preserved in `raw_data` and surfaced in drift diagnostics.
- Existing profile/catalog pages continue loading.

## acceptance_criteria

- Every known field from the provided Apify-style and XDT examples is either normalized into a typed column/child table or explicitly documented as intentionally raw-only/viewer-session-only.
- Every known field from the provided profile example is either normalized into `social.instagram_profiles`, `social.instagram_profile_external_links`, or explicitly documented as intentionally raw-only/viewer-session-only.
- Every known field from the provided following-list example is normalized into `social.instagram_profile_relationships` or explicitly documented as intentionally raw-only.
- Every known field from the provided comment/reply example is normalized into `social.instagram_comments` columns or explicitly documented as intentionally raw-only.
- Every post-level field has one durable canonical home or a documented temporary compatibility bridge; no new duplicate storage is introduced silently.
- posts-Scrapling promotes enriched data instead of saving it only in `raw_data`.
- profile scraping promotes profile/about/external-link/picture/count fields instead of saving them only in `raw_data`.
- following-list scraping promotes relationship rows instead of saving them only in `raw_data`.
- comments-Scrapling promotes comment and reply data instead of saving nested replies only in `raw_data`.
- Existing canonical and catalog rows can be backfilled from `raw_data`.
- Backend API responses expose the useful new fields additively.
- Tests prove data is queryable without parsing `raw_data` in application code.

## risks_edge_cases_open_questions

- Some source fields are viewer-session-specific and may be misleading if treated as post truth. The contract must label these clearly.
- The largest design risk is duplicating post-level data across `instagram_posts`, `instagram_account_catalog_posts`, and `social.social_posts`. Phase 0 must stop and revise the storage map if a proposed migration would add the same durable field to multiple surfaces without a bridge justification.
- Instagram signed CDN URLs expire; media variant rows should preserve source URLs for traceability but hosted mirror fields remain the stable media surface.
- Profile picture CDN URLs expire too; store source URLs for traceability, but use hosted mirrors where the admin UI needs stable images.
- Public profile counts can drift quickly. Treat `followers_count`, `follows_count`, `posts_count`, and following relationship row totals as scrape-time snapshots, not live truth.
- Username changes can create duplicate relationship rows if identity is username-only. Prefer profile/user id when present and use normalized username as a fallback identity component.
- The user's requested "FOLLOWING list" sample has `type: "Followers"`. Because follower-list scraping is out of scope, the implementation must require explicit `following` direction at fetch time and must not persist `Followers` rows as relationship rows.
- High-following accounts can still produce large following lists. Following scrape completeness must be represented separately from profile counts.
- Embedded latest comments are partial. They should not be counted as complete comments coverage.
- Full comments scrape rows and embedded/latest comment samples must remain distinguishable if both are persisted. Embedded samples should not mark a post's comment scrape complete.
- Child tables spanning canonical and catalog surfaces need careful uniqueness to avoid duplicate source rows.
- If app pages eagerly load too many nested rows, profile pages may regress. Keep heavy nested detail behind detail endpoints.
- Open question: should embedded comments be upserted into `social.instagram_comments` with a `source_stage`, or kept separate in `social.instagram_post_embedded_comments` until a full comment scrape confirms them? Recommended initial answer: keep separate to avoid overstating coverage.
- Open question: should all new Instagram post child tables be skipped in favor of `social_post_entities` and `social_post_media_assets`? Recommended initial answer: use cross-platform child tables first, then add Instagram-specific child tables only for payloads that do not fit.

## follow_up_improvements

- Extend the same normalizer/field-contract pattern to TikTok, Twitter/X, Threads, Facebook, and YouTube after Instagram is stable.
- Add generated docs from the field map so admins can see source-field coverage by scraper.
- Add a dashboard card for "raw-only known fields detected" per recent scrape job.
- Add a profile relationship coverage card showing rows stored, cap reached, last cursor, and last scrape time.
- Add optional full-text search over caption, alt text, location, owner name, tagged users, collaborators, and embedded comment text.
- Add optional full-text search over profile biography, full name, business category, external link titles, and related usernames/full names.

## recommended_next_step_after_approval

Use `orchestrate-subagents` after Phase 0 because the revised plan has independent workstreams: schema/tests, normalizers/fixtures, profile/following fetcher/job integration, persistence/backfill, API/admin follow-through, and observability. Keep schema/stage decisions centralized, then split independent workers by file ownership.

## ready_for_execution

Yes, pending approval of these storage/crawl stances:

- Required: run Phase 0 schema architecture decision gate before migrations. Do not perform a broad destructive redesign; use additive canonicalization aligned with `social.social_posts`.
- Recommended: keep embedded/latest comments in a separate snapshot child table first.
- Alternative: upsert them into `social.instagram_comments` with a new `source_stage`/`coverage_source` column and mark them partial.
- Recommended: store only `following` rows in `social.instagram_profile_relationships` with explicit `relationship_type = 'following'`, bounded page/cap metadata, and no hard delete on unseen rows during normal scrapes.
- Explicitly out of scope: follower-list scrape stages, follower-list tables, and follower-list API routes. Keep `followersCount`/`followers_count` only as profile scalar counts.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
