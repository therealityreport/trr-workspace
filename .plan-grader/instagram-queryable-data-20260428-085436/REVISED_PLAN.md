# Instagram Queryable Data Plan

## summary

Make Instagram post, profile, profile-relationship, and comment scrape data accessible through typed, searchable, and queryable database surfaces instead of leaving meaningful fields only in `raw_data`. The work is backend-first: define the canonical post/profile/following/comment data contract, add additive schema for scalar fields and nested child entities, update all Instagram normalizers to populate that contract, backfill existing rows from `raw_data`, then expose the fields through admin/profile/catalog/comment read paths without breaking existing UI consumers.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`

## plan_grader_revision

- Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`
- Artifact package: `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-data-20260428-085436`
- Verdict: `APPROVED_WITH_REVISIONS`
- Required revisions integrated here:
  - add a Phase 0 current-state and execution-routing gate before migrations;
  - add an explicit profile/source linking contract so `social.instagram_profiles` joins back to `social.shared_account_sources`;
  - add concrete job-stage/runtime work for profile and relationship scraping;
  - remove follower-list scraping from the implementation scope while keeping profile follower counts;
  - make profile backfill evidence-based instead of assuming full raw profile payloads already exist;
  - change the execution handoff to `orchestrate-subagents` after Phase 0 because schema, normalizers, persistence/backfill, API/admin, and validation can be split safely.

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

## assumptions

- The requirement is not to make every volatile Instagram viewer/session field a first-class business concept. It is to make every known scrape field accessible without ad hoc raw JSON spelunking.
- `raw_data` remains the forensic source of truth, but known fields must be mirrored into typed columns or child tables with indexes where they will be filtered, searched, joined, or displayed.
- Nested repeatable data should use child tables when it needs independent filtering or joining; JSONB columns are acceptable only when paired with stable extraction and GIN/path indexes for queryability.
- Additive migrations are preferred. Existing admin routes and UI should keep working while new fields roll out.
- Backend schema and persistence land before TRR-APP display/filter changes.
- Existing `social.shared_account_sources` is the account registry and should remain the join point for admin profile pages. The new profile tables must link to it rather than relying only on usernames.
- Full historical profile backfill is only possible where raw profile payloads actually exist. If current cached snapshots contain only reduced profile fields, the implementation should backfill what is present and schedule bounded re-scrapes for missing profile/about/link/relationship fields.

## goals

1. Define a canonical Instagram post, profile, profile-relationship, and comment source contract covering Apify flattened output, Instagram GraphQL/XDT `media` nodes, profile/about payloads, following list payloads, and comment/reply payloads.
2. Add queryable storage for currently raw-only fields, including owner identity, profile identity/about fields, profile external links, profile counts, following-list relationships, location, post flags, caption metadata, media variants, tagged users, collaborators, embedded/latest comments, repost/media-note context, and engagement visibility state.
3. Make posts-Scrapling populate the same enriched DTO fields as the richer parser wherever the raw node contains them.
4. Keep `social.instagram_posts` and `social.instagram_account_catalog_posts` aligned enough that profile/catalog/admin reads do not disagree about what data exists.
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

### Phase 0: Current-State Gate And Workstream Routing

Before writing migrations, perform a repo-backed current-state gate so the implementation does not build on stale assumptions.

Required checks:

- Inspect current table definitions and optional-column guards for:
  - `social.instagram_posts`
  - `social.instagram_account_catalog_posts`
  - `social.instagram_comments`
  - `social.shared_account_sources`
  - `social.scrape_jobs`
  - `social.scrape_runs`
- Inspect current Instagram fetch and persistence surfaces:
  - `TRR-Backend/trr_backend/socials/instagram/constants.py`
  - `TRR-Backend/trr_backend/socials/instagram/runtimes/protocol.py`
  - `TRR-Backend/trr_backend/socials/instagram/runtimes/crawlee_runtime.py`
  - `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py`
  - `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py`
  - `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
  - `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py`
  - `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Confirm whether any existing table already stores raw full profile/about payloads. If not, mark profile backfill coverage as partial and require fresh bounded profile scrapes for missing fields.
- Decide exact job-stage names before implementation. Recommended:
  - `instagram_profile_snapshot`
  - `instagram_profile_relationships`
- Decide whether these stages reuse existing `social.scrape_jobs`/worker dispatch or need a small Instagram-specific job runner. Prefer reusing the existing scrape job/run model if the stage can be claimed and observed there.

Parallel workstream map after this gate:

- Workstream A: migrations and schema tests.
- Workstream B: post/comment/profile/relationship normalizers and fixtures.
- Workstream C: fetcher/job-stage/runtime integration for profile snapshots and profile relationships.
- Workstream D: persistence and backfill.
- Workstream E: read APIs/admin app follow-through.
- Workstream F: observability and validation.

Validation:

- Add a short baseline note under `docs/ai/local-status/` listing inspected columns, missing tables, chosen stage names, and whether profile raw backfill is full or partial.
- If the current-state gate finds an existing canonical profile/relationship table, stop and revise Phase 2 instead of creating duplicate tables.

Acceptance criteria:

- The executor can name the exact existing source of truth for account registry, profile identity, scrape job/run provenance, and admin profile reads before writing schema.
- The implementation path is split into safe parallel workstreams only after schema and stage naming are agreed.

Commit boundary:

- Commit 0: baseline/current-state note only, or combine with Commit 1 if the team does not want a standalone evidence commit.

### Phase 1: Field Inventory And Contract

Create a backend-owned Instagram field matrix from the provided payload families:

- Apify-style flattened post output: `shortCode`, `type`, `displayUrl`, `videoUrl`, `dimensionsWidth`, `dimensionsHeight`, `ownerUsername`, `ownerFullName`, `ownerId`, `locationName`, `locationId`, `latestComments`, `taggedUsers`, `coauthorProducers`, `musicInfo`, `videoPlayCount`, `videoDuration`.
- Instagram XDT `media` nodes: `code`, `pk`, `id`, `media_type`, `image_versions2`, `video_versions`, `original_width`, `original_height`, `caption.pk`, `caption.text`, `caption_is_edited`, `accessibility_caption`, `user`, `owner`, `owner_id`, `usertags`, `coauthor_producers`, `location`, `media_notes`, `floating_context_items`, `comment_count`, `like_count`, `like_and_view_counts_disabled`, `comments_disabled`, `commenting_disabled_for_viewer`, `media_repost_count`.
- Profile payloads: `inputUrl`, `id`, `username`, `url`, `fullName`, `biography`, `about.accounts_with_shared_followers`, `about.country`, `about.date_joined`, `about.date_joined_as_timestamp`, `about.date_verified`, `about.date_verified_as_timestamp`, `about.former_usernames`, `about.id`, `about.is_verified`, `about.username`, `followersCount`, `followsCount`, `postsCount`, `highlightReelCount`, `igtvVideoCount`, `isBusinessAccount`, `joinedRecently`, `hasChannel`, `businessCategoryName`, `private`, `verified`, `externalUrl`, `externalUrlShimmed`, `externalUrls[]`, `profilePicUrl`, and `profilePicUrlHD`.
- Following-list payloads: `username_scrape`, `type`, `full_name`, `id`, `is_private`, `is_verified`, `profile_pic_url`, and `username`. The contract must treat the requested scrape mode as `following` only. If a source payload says `type: "Followers"`, the implementation must not persist it as a follower row; it should reject/skip the row or store the raw mismatch only as diagnostics.
- Comment/reply payloads: `id`, `text`, `ownerUsername`, `ownerProfilePicUrl`, `owner.id`, `owner.username`, `owner.is_verified`, `owner.profile_pic_url`, `timestamp`, `likesCount`, `repliesCount`, and recursive `replies`.

Deliverables:

- Add `TRR-Backend/docs/social/instagram-data-contract.md`.
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

- Commit 1: documentation-only contract and source-field matrix.

### Phase 2: Additive Schema

Add additive migrations for `social.instagram_posts` and `social.instagram_account_catalog_posts`.

Scalar columns to add or align:

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

Child/query tables:

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
    - `unique (source_scope, normalized_username)` or equivalent fallback identity where profile id is absent.
  - Do not make `shared_account_source_id` mandatory because relationship rows can discover accounts that are not yet curated shared sources.

Profile child/query tables:

- Add `social.instagram_profile_source_links` only if a single profile can map to multiple shared source scopes over time:
  - `profile_id uuid references social.instagram_profiles(id)`
  - `shared_account_source_id uuid references social.shared_account_sources(id)`
  - platform/source scope/account handle denormalized for query convenience
  - first seen, last seen, raw/source metadata.
  - Unique constraint on profile plus shared source.
  - If the simpler `shared_account_source_id` column is enough for current use, document why this table is deferred.
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
- Schema tests prove profile rows can join back to `shared_account_sources` by `shared_account_source_id` or the approved link table.

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
- `TRR-Backend/trr_backend/repositories/social_scrape_jobs.py` or the current scrape-job repository that claims/updates job stages, if profile jobs use the shared scrape job system.

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
  - validates `account_handle`, `relationship_type`, page/cap config, and auth/session requirements;
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
- Backfill dry-run test against fixture rows.
- Job-runner tests proving profile snapshot and relationship stages reject ambiguous relationship direction and report capped/checkpoint/rate-limit status.
- Local dry run command documented in the plan output.

Acceptance criteria:

- Existing rows can be upgraded without re-scraping Instagram.
- Existing profile snapshots can be upgraded where raw profile payloads exist.
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

## architecture_impact

- Backend remains the owner of Instagram scrape contracts and database shape.
- posts-Scrapling should stop owning a separate reduced DTO contract. It should call the shared normalizer and then the canonical persistence helpers.
- Profile and relationship fetchers should stop treating profile data as transient profile-page decoration. They should call shared profile normalizers and canonical profile/relationship persistence helpers.
- Catalog and canonical post tables should share a field vocabulary, but do not need identical table shapes for all nested data. Shared child tables can use a `surface` discriminator where needed.
- `social.shared_account_sources` remains the source registry/assignment table. It should not be stretched into the canonical full Instagram profile table.
- Durable Instagram profile id should be preferred over username for identity because usernames can change. Username remains indexed and denormalized for operator search.
- TRR-APP remains a consumer of backend-owned response shapes and should not add direct SQL for the new fields.

## data_or_api_impact

- Additive Supabase migrations in `TRR-Backend/supabase/migrations`.
- New child tables require service role grants and RLS/read policy decisions consistent with existing social tables.
- New profile/profile-link/profile-relationship tables require service role grants and RLS/read policy decisions consistent with existing social tables.
- Existing response contracts should be additive; no existing fields should be removed or renamed.
- New or expanded profile endpoints should make following-list completeness explicit via count, cap, cursor, and scrape status metadata.
- Backfill writes must be batched to avoid local/session pool saturation.
- `raw_data` remains present for audit and unknown future fields.

## ux_admin_ops_considerations

- The admin UI should not display every new field in dense lists.
- Detail modals should show new structured sections: Owner, Location, Media Variants, Tagged Users, Collaborators, Embedded Comment Sample, Flags/Diagnostics.
- Profile detail panels should show structured sections: Profile, About, Counts, External Links, Profile Pictures, Relationship Coverage, and Diagnostics.
- List filters should focus on operator value: media type, owner, location, has tags/collabs, comments disabled, counts hidden.
- Relationship list filters should focus on operator value: following, related username, verified/private flags, and first/last seen.
- Backfill should be run from CLI with dry-run first, then bounded batches by account or date.
- Job progress should show promoted-field counts, profile rows, external links, relationship rows, and cap/checkpoint status so operators know the scrape saved more than raw payloads.

## validation_plan

Automated backend checks:

- `pytest tests/repositories/test_social_season_analytics.py -k "instagram"`
- New tests for `post_normalizer.py` with Apify and XDT fixtures.
- New tests for `profile_normalizer.py` with the NASA-style profile fixture.
- New tests for `profile_relationship_normalizer.py` with the following-list fixture.
- New tests for posts-Scrapling persistence proving typed fields populate `_upsert_instagram_post`.
- New tests for profile persistence proving typed fields populate `social.instagram_profiles`, `social.instagram_profile_external_links`, and `social.instagram_profile_relationships`.
- New tests for comments-Scrapling parsing/persistence proving the sample comment/reply shape populates `social.instagram_comments`.
- New migration/schema tests for added columns/tables.
- Backfill dry-run unit tests.
- Job-stage tests for `instagram_profile_snapshot` and `instagram_profile_relationships`, including page-cap completion and ambiguous relationship direction rejection.

Automated app checks if response/UI changes land:

- `pnpm exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx --reporter=dot`
- Targeted route tests for social profile catalog/detail compatibility routes.

Manual checks:

- Run a dry-run backfill for one account with known raw data.
- Run a Phase 0 baseline check that confirms whether raw full profile payloads currently exist. If absent, validate that the backfill reports partial profile coverage instead of pretending all requested profile fields were recovered.
- Inspect one canonical post and one catalog post with SQL selecting new scalar fields and child table rows.
- Inspect one profile with SQL selecting profile id, username, biography, about-derived fields, counts, external URL, profile picture URLs, and external link rows.
- Inspect one relationship list with SQL selecting owner username, relationship type, related username/id, related full name, related avatar URL, private flag, verified flag, and last seen timestamp.
- Inspect one top-level comment and one reply with SQL selecting `comment_id`, `parent_comment_id`, `username`, `user_id`, `author_profile_pic_url`, `author_is_verified`, `created_at`, `likes`, and `reply_count`.
- Open the admin Instagram profile/catalog detail modal and confirm fields render without falling back to raw JSON.

Expected outcomes:

- Representative payload fields from the provided examples appear in typed columns or child tables.
- Representative profile and following-list payload fields appear in typed profile/link/relationship tables.
- Representative comment/reply payload fields appear in typed comment columns with parent-child links.
- Unknown fields remain preserved in `raw_data` and surfaced in drift diagnostics.
- Existing profile/catalog pages continue loading.

## acceptance_criteria

- Every known field from the provided Apify-style and XDT examples is either normalized into a typed column/child table or explicitly documented as intentionally raw-only/viewer-session-only.
- Every known field from the provided profile example is either normalized into `social.instagram_profiles`, `social.instagram_profile_external_links`, or explicitly documented as intentionally raw-only/viewer-session-only.
- Every known field from the provided following-list example is normalized into `social.instagram_profile_relationships` or explicitly documented as intentionally raw-only.
- Every known field from the provided comment/reply example is normalized into `social.instagram_comments` columns or explicitly documented as intentionally raw-only.
- posts-Scrapling promotes enriched data instead of saving it only in `raw_data`.
- profile scraping promotes profile/about/external-link/picture/count fields instead of saving them only in `raw_data`.
- following-list scraping promotes relationship rows instead of saving them only in `raw_data`.
- comments-Scrapling promotes comment and reply data instead of saving nested replies only in `raw_data`.
- Existing canonical and catalog rows can be backfilled from `raw_data`.
- Backend API responses expose the useful new fields additively.
- Tests prove data is queryable without parsing `raw_data` in application code.

## risks_edge_cases_open_questions

- Some source fields are viewer-session-specific and may be misleading if treated as post truth. The contract must label these clearly.
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

## follow_up_improvements

- Extend the same normalizer/field-contract pattern to TikTok, Twitter/X, Threads, Facebook, and YouTube after Instagram is stable.
- Add generated docs from the field map so admins can see source-field coverage by scraper.
- Add a dashboard card for "raw-only known fields detected" per recent scrape job.
- Add a profile relationship coverage card showing rows stored, cap reached, last cursor, and last scrape time.
- Add optional full-text search over caption, alt text, location, owner name, tagged users, collaborators, and embedded comment text.
- Add optional full-text search over profile biography, full name, business category, external link titles, and related usernames/full names.

## recommended_next_step_after_approval

Use `orchestrate-subagents` after Phase 0 because the revised plan has independent workstreams: schema/tests, normalizers/fixtures, profile relationship fetcher/job integration, persistence/backfill, API/admin follow-through, and observability. Keep schema contract and stage naming as the coordination point before workers edit disjoint files.

## ready_for_execution

Yes, pending approval of two storage/crawl stances:

- Recommended: keep embedded/latest comments in a separate snapshot child table first.
- Alternative: upsert them into `social.instagram_comments` with a new `source_stage`/`coverage_source` column and mark them partial.
- Recommended: store only `following` rows in `social.instagram_profile_relationships` with explicit `relationship_type = 'following'`, bounded page/cap metadata, and no hard delete on unseen rows during normal scrapes.
- Explicitly out of scope: follower-list scrape stages, follower-list tables, and follower-list API routes. Keep `followersCount`/`followers_count` only as profile scalar counts.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
