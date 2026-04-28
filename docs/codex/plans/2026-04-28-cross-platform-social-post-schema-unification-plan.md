# Cross-Platform Social Post Schema Unification Plan

Date: 2026-04-28
Status: ready for approval
Recommended executor after approval: `orchestrate-plan-execution`

## summary

Unify TRR's social post storage across Instagram, TikTok, Twitter/X, Facebook, Threads, YouTube, and Reddit by introducing a shared canonical post model with platform-specific adapters. The current Supabase schema has several overlapping shapes:

- Instagram and TikTok have both materialized post tables and account-catalog tables.
- Facebook and Meta Threads have materialized post tables, plus empty account-catalog tables already shaped like the shared catalog model.
- Twitter/X and YouTube currently have account-catalog post tables but no first-class materialized post tables.
- Reddit already has a distinct canonical `social.reddit_posts` model tied to communities/threads rather than account profiles.

The implementation should be additive and backend-first. Keep existing platform tables and comment FKs stable during rollout, add shared canonical/membership/entity/media tables, backfill platform rows into the shared model, switch backend write/read paths by platform, then retire or compatibility-wrap legacy catalog tables only after parity checks pass.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-cross-platform-social-post-schema-unification-plan.md`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owner: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- App owner: `/Users/thomashulihan/Projects/TRR/TRR-APP`
- Live Supabase evidence from 2026-04-28:
  - `social.instagram_posts`: 1,583 rows, 39 MB, 62 columns.
  - `social.instagram_account_catalog_posts`: 29,799 rows, 241 MB, 41 columns.
  - `social.tiktok_posts`: 678 rows, 6,296 kB, 50 columns.
  - `social.tiktok_account_catalog_posts`: 11,501 rows, 32 MB, 41 columns.
  - `social.facebook_posts`: 141 rows, 1,224 kB, 38 columns.
  - `social.facebook_account_catalog_posts`: 0 rows, 64 kB, 41 columns.
  - `social.meta_threads_posts`: 3,495 rows, 26 MB, 38 columns.
  - `social.threads_account_catalog_posts`: 0 rows, 64 kB, 41 columns.
  - `social.twitter_account_catalog_posts`: 77 rows, 368 kB, 45 columns.
  - `social.youtube_account_catalog_posts`: 40 rows, 328 kB, 41 columns.
  - `social.reddit_posts`: 2,204 rows, 13 MB, 30 columns.
- Repo evidence:
  - Base Instagram/TikTok post tables come from `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`.
  - Facebook and Meta Threads materialized tables come from `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0152_add_facebook_and_meta_threads_social_platforms.sql`.
  - Reddit post storage comes from `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0157_reddit_refresh_pipeline.sql` plus enhanced columns in `0166_enhanced_reddit_post_columns.sql`.
  - Shared account catalog tables for Instagram, TikTok, Twitter/X, and Threads come from `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`.
  - YouTube and Facebook catalog tables come from `0202_shared_account_youtube_catalog.sql` and `0204_shared_account_facebook_catalog.sql`.
  - Current backend persistence lives mainly in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`.
  - The cross-repo API contract says backend owns schema and social profile contracts; app follow-through happens after backend contract changes.

## assumptions

1. Existing platform-specific comment tables and FKs must remain stable during rollout.
2. The shared canonical model should not erase platform-specific identity. Every canonical row needs `(platform, source_id)` plus platform-native IDs such as Instagram `shortcode`, TikTok `video_id`, Twitter/X tweet ID, YouTube video ID, Reddit post ID, Facebook post ID, and Threads post ID.
3. Account/profile membership is separate from post identity. A post can belong to one owner and appear in one or more account/profile catalog contexts.
4. Reddit applies only partially: its community/thread model should map to shared canonical posts and entities/media where useful, but it should not be forced into account-profile catalog semantics.
5. Backend API response shapes should remain compatible for `SocialAccountProfilePage`, catalog tabs, comments tabs, detail modals, Reddit community/thread pages, and admin backfill progress.
6. Current public read behavior should remain unchanged unless the user explicitly asks for a security/RLS tightening pass.
7. Data migration must be reversible until parity is proven. Do not drop legacy platform or catalog tables in the first implementation pass.

## goals

1. Establish one shared canonical row per platform post identity.
2. Preserve all existing comments and platform-specific FK relationships.
3. Represent account/profile/community membership separately from canonical post identity.
4. Normalize hot arrays and JSON payload fields into indexed entity/media tables across platforms.
5. Stop duplicating post writes between materialized tables and account-catalog tables.
6. Preserve existing backend/admin API response envelopes.
7. Add parity checks for each applicable platform:
   - old platform rows
   - old catalog rows
   - new canonical rows
   - membership rows
   - comments/replies coverage
   - media coverage
   - per-account or per-community totals
8. Leave a clear rollback path until old and new read models match.

## non_goals

- No immediate destructive drop of platform-specific post tables or account-catalog tables.
- No app redesign.
- No Supabase capacity or pool-size change.
- No scraper/proxy/auth/worker orchestration rewrite.
- No forced single API envelope for account-profile platforms and Reddit community/thread pages.
- No RLS/security redesign beyond matching current table exposure for new tables.
- No public API response shape break.

## phased_implementation

### Phase 0 - Baseline Platform Matrix And Contract Lock

Concrete changes:

- Add a short status doc under `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/` recording the live platform matrix:

| Platform | Materialized table | Catalog table | Special model | First-class in shared model |
|---|---|---|---|---|
| Instagram | `social.instagram_posts` | `social.instagram_account_catalog_posts` | comments FK target | yes |
| TikTok | `social.tiktok_posts` | `social.tiktok_account_catalog_posts` | sound/quality analytics | yes |
| Twitter/X | none currently | `social.twitter_account_catalog_posts` | threads/bookmarks fields | yes, catalog-first |
| Facebook | `social.facebook_posts` | `social.facebook_account_catalog_posts` | page posts/comments | yes |
| Threads | `social.meta_threads_posts` | `social.threads_account_catalog_posts` | Meta Threads replies/reposts | yes |
| YouTube | none currently | `social.youtube_account_catalog_posts` | video/channel semantics | yes, catalog-first |
| Reddit | `social.reddit_posts` | none | community/thread/flair model | partial adapter |

- Add a backend parity script, for example `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/social_post_schema_parity.py`, that supports:
  - `--platform instagram|tiktok|twitter|facebook|threads|youtube|reddit|all`
  - `--account <handle>` for account-profile platforms
  - `--community <subreddit>` for Reddit
  - `--json`
  - read-only default behavior
- The script should report:
  - materialized row count by platform and source account/community
  - catalog row count by platform and source account when a catalog table exists
  - catalog rows with no matching materialized row
  - materialized rows with no catalog membership
  - duplicate/conflicting platform source IDs
  - mismatched metrics and timestamps
  - comment/reply rows whose post target is missing
- Update `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` only if a backend response or freshness contract changes.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
.venv/bin/python scripts/db/social_post_schema_parity.py --platform instagram --account thetraitorsus --json
.venv/bin/python scripts/db/social_post_schema_parity.py --platform tiktok --account thetraitorsus --json
```

Expected result:

- Script runs read-only.
- Current gaps are classified by platform.
- Twitter/X and YouTube are explicitly recognized as catalog-first platforms.
- Reddit is explicitly recognized as community/thread-first, not account-catalog-first.

Acceptance criteria:

- Current state is documented with live evidence for every applicable platform.
- No implementation mutation happens before baseline evidence exists.
- The execution agent knows which counts must match after migration.

Commit boundary:

- Docs and read-only parity script only.

### Phase 1 - Add Shared Canonical, Membership, Entity, And Media Tables

Concrete changes:

- Add an additive Supabase migration with shared canonical post storage:

```sql
create table if not exists social.social_posts (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('instagram', 'tiktok', 'twitter', 'facebook', 'threads', 'youtube', 'reddit')),
  source_id text not null,
  owner_handle text,
  owner_id text,
  canonical_url text,
  title text,
  body text,
  media_type text,
  posted_at timestamptz,
  like_count bigint not null default 0 check (like_count >= 0),
  comment_count bigint not null default 0 check (comment_count >= 0),
  share_count bigint not null default 0 check (share_count >= 0),
  view_count bigint not null default 0 check (view_count >= 0),
  save_count bigint not null default 0 check (save_count >= 0),
  quote_count bigint not null default 0 check (quote_count >= 0),
  raw_data jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_scraped_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, source_id)
);

create index if not exists social_posts_platform_owner_posted_idx
  on social.social_posts (platform, lower(owner_handle), posted_at desc nulls last, id);

create index if not exists social_posts_platform_posted_idx
  on social.social_posts (platform, posted_at desc nulls last, id);
```

- Add account/profile/community membership:

```sql
create table if not exists social.social_post_memberships (
  platform text not null check (platform in ('instagram', 'tiktok', 'twitter', 'facebook', 'threads', 'youtube', 'reddit')),
  membership_type text not null check (membership_type in ('account', 'community', 'show', 'season', 'person')),
  membership_key text not null,
  post_id uuid not null references social.social_posts(id) on delete cascade,
  assignment_status text not null default 'unassigned'
    check (assignment_status in ('assigned', 'unassigned', 'ambiguous', 'needs_review')),
  assigned_show_id uuid references core.shows(id) on delete set null,
  assigned_season_id uuid references core.seasons(id) on delete set null,
  assignment_source text,
  candidate_matches jsonb not null default '[]'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_backfill_run_id uuid references social.scrape_runs(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (platform, membership_type, membership_key, post_id)
);

create index if not exists social_post_memberships_post_idx
  on social.social_post_memberships (post_id);

create index if not exists social_post_memberships_lookup_idx
  on social.social_post_memberships
  (platform, membership_type, lower(membership_key), last_seen_at desc, post_id);
```

- Add normalized entities:

```sql
create table if not exists social.social_post_entities (
  post_id uuid not null references social.social_posts(id) on delete cascade,
  platform text not null,
  entity_type text not null check (entity_type in (
    'hashtag', 'mention', 'profile_tag', 'collaborator', 'tagged_user',
    'author', 'subreddit', 'flair', 'sound', 'thread_root', 'channel'
  )),
  entity_key text not null,
  source text,
  raw_detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id, entity_type, entity_key)
);

create index if not exists social_post_entities_lookup_idx
  on social.social_post_entities (platform, entity_type, entity_key, post_id);
```

- Add normalized media assets:

```sql
create table if not exists social.social_post_media_assets (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references social.social_posts(id) on delete cascade,
  platform text not null,
  position integer not null default 0,
  media_kind text,
  source_url text,
  hosted_url text,
  thumbnail_url text,
  width integer,
  height integer,
  duration_seconds numeric,
  mirror_status text,
  mirror_error text,
  mirror_attempt_count integer not null default 0,
  mirror_last_attempt_at timestamptz,
  raw_detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, position)
);

create index if not exists social_post_media_assets_post_idx
  on social.social_post_media_assets (post_id, position);
```

- Add optional platform-specific extension tables only where the shared table would become distorted:
  - `social.social_post_twitter_thread_meta` for thread root, position, bookmarks if not stored as canonical fields/entities.
  - `social.social_post_tiktok_sound_meta` only if existing TikTok sound analytics need a stable FK to `social.social_posts`.
  - `social.social_post_reddit_meta` for flair, spoiler/nsfw/self-post fields if not handled through `raw_data` and entities.
- Enable RLS and create public read policies matching current public-read behavior for source tables.

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- Backend migration/advisor tests.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/api/test_startup_validation.py -k "social or platform"
```

Expected result:

- New shared tables exist.
- Existing platform/comment FKs remain untouched.
- New read policies match the current exposure model.

Acceptance criteria:

- Migration is additive and rollback-safe.
- No legacy table is dropped or renamed.
- Shared schema can represent all applicable account-profile platforms and Reddit via adapters.

Commit boundary:

- One migration plus migration/advisor tests.

### Phase 2 - Backfill Shared Canonical Rows Per Platform

Concrete changes:

- Add a resumable backend script, for example `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/backfill_social_post_canonical_schema.py`.
- The script should support:
  - default dry run
  - `--execute`
  - `--platform`
  - `--account`
  - `--community`
  - `--batch-size`
  - `--json`
- Platform mapping:
  - Instagram: `instagram_posts.shortcode` and catalog `source_id` map to `social_posts(platform='instagram', source_id)`.
  - TikTok: `tiktok_posts.video_id` and catalog `source_id` map to `platform='tiktok'`.
  - Twitter/X: `twitter_account_catalog_posts.source_id` maps to `platform='twitter'`; no materialized table is required before backfill.
  - Facebook: `facebook_posts.post_id` and catalog `source_id` map to `platform='facebook'`.
  - Threads: `meta_threads_posts.post_id` or catalog `source_id` maps to `platform='threads'`.
  - YouTube: `youtube_account_catalog_posts.source_id` maps to `platform='youtube'`.
  - Reddit: `reddit_posts.reddit_post_id` maps to `platform='reddit'`; membership uses `membership_type='community'` and `membership_key=lower(subreddit)`.
- For account-profile catalog rows, insert/update `social.social_post_memberships` with `membership_type='account'`.
- For existing show/person/season associations on materialized platform tables, insert/update `membership_type='show'`, `season`, and `person` rows or keep those as compatibility columns until Phase 4. The implementation should choose one path and document it before read migration.
- Sync entities and media from each platform's current arrays/raw fields.
- Preserve legacy rows and never delete source data during this phase.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/backfill_social_post_canonical_schema.py --platform instagram --account thetraitorsus --dry-run --json
.venv/bin/python scripts/db/backfill_social_post_canonical_schema.py --platform tiktok --account thetraitorsus --dry-run --json
.venv/bin/python scripts/db/backfill_social_post_canonical_schema.py --platform all --dry-run --json
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```

Expected result:

- Dry runs show per-platform insert/update counts and conflicts.
- Catalog-only platforms create shared canonical rows without needing new platform-specific materialized tables first.
- Reddit rows map to community memberships without account-catalog assumptions.

Acceptance criteria:

- Backfill is idempotent.
- Per-platform parity can be proven before all-platform execution.
- No comments/replies lose their existing source table target.

Commit boundary:

- Backfill script plus focused script tests.

### Phase 3 - Switch Write Paths To Shared Canonical Plus Membership

Concrete changes:

- Add shared repository helpers in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py` or a new focused module:
  - `_upsert_social_canonical_post(...)`
  - `_sync_social_post_memberships(...)`
  - `_sync_social_post_entities(...)`
  - `_sync_social_post_media_assets(...)`
  - platform mappers such as `_instagram_post_to_social_post_payload(...)`, `_tiktok_post_to_social_post_payload(...)`, `_twitter_catalog_row_to_social_post_payload(...)`
- Update write paths by platform:
  - Instagram: `_upsert_instagram_post(...)`, `_shared_catalog_instagram_post_payload(...)`, batch catalog upserts.
  - TikTok: `_upsert_tiktok_post(...)`, `_upsert_shared_catalog_tiktok_post(...)`, shared-post hydration paths.
  - Twitter/X: `_upsert_shared_catalog_twitter_post(...)` and thread/reply/bookmark hydration paths.
  - Facebook: `facebook_posts` persistence plus `facebook_account_catalog_posts` if/when backfill populates it.
  - Threads: `meta_threads_posts` persistence and `threads_account_catalog_posts`.
  - YouTube: `youtube_account_catalog_posts`.
  - Reddit: refresh pipeline writes to `reddit_posts` and mirrors into shared canonical/membership rows.
- Keep dual-write to legacy platform/catalog tables during this phase for rollback and parity checks.
- Add per-platform diagnostics when shared canonical upsert succeeds but legacy write fails, or vice versa.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "instagram or tiktok or twitter or facebook or threads or youtube or reddit"
```

Expected result:

- New writes maintain shared canonical rows and legacy compatibility rows in the same logical operation.
- Existing diagnostics such as zero-save and follow-up hydration still work.
- Catalog-only platforms begin producing canonical rows.

Acceptance criteria:

- Dual-write is covered by tests for each active platform.
- Shared helpers preserve platform-specific identity and metrics semantics.
- Rollback remains possible by reading legacy tables.

Commit boundary:

- Backend write-path refactor plus tests.

### Phase 4 - Migrate Backend Read Paths By Surface

Concrete changes:

- Move read paths to shared tables in this order:
  1. Account/profile catalog list reads for Instagram, TikTok, Twitter/X, Facebook, Threads, and YouTube.
  2. Post detail surfaces and media preview fields.
  3. Hashtag/mention/collaborator/profile tag lookup.
  4. Comments-only post lists, preserving existing comments table joins.
  5. Reddit stored-post/community reads where shared canonical rows provide value without breaking Reddit-specific behavior.
- Preserve existing backend API response envelopes for:
  - profile dashboard/snapshot
  - profile posts
  - catalog posts
  - catalog post detail
  - comments-only posts
  - hashtags/collaborators/tags tabs
  - Reddit community/thread list/detail routes
- Replace JSON unnesting hot paths with indexed `social.social_post_entities` joins.
- Keep fallback reads from legacy tables behind explicit compatibility helpers during rollout.

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Reddit repositories/routes where stored-post reads are backend-owned.
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py`
- `/Users/thomashulihan/Projects/TRR/TRR-APP` tests only if backend fixtures or envelopes change.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/api/test_admin_reddit_reads.py -k "social or reddit"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/reddit-sources-repository-backend.test.ts --reporter=dot
```

Expected result:

- API responses remain shape-compatible.
- Per-account and per-community counts match old source tables.
- Existing comments/replies still join through legacy FK targets until a separate comments unification plan exists.
- Entity/media queries use indexed shared tables.

Acceptance criteria:

- Backend route tests prove compatibility.
- App tests do not require response-shape changes.
- Query plans no longer depend on unbounded JSON expansion for common social profile reads.

Commit boundary:

- Backend read-path migration, plus app fixture/test follow-through only if needed.

### Phase 5 - Rollout, Parity Gate, And Legacy Retirement

Concrete changes:

- Run parity checks for every platform:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```

- Add an operator-facing health check or diagnostic summary for:
  - shared canonical rows by platform
  - membership rows by platform/type
  - legacy rows without shared canonical rows
  - shared canonical rows without legacy source rows
  - comments/replies with missing source targets
  - entity/media sync gaps
- After at least one clean full backfill and one clean live scrape/write cycle per active platform, decide per platform whether to:
  - keep legacy tables as archives
  - replace legacy catalog tables with compatibility views
  - keep materialized platform tables as comments/replies FK targets
  - rename old catalog tables to `_legacy`
  - leave retirement for a separate plan
- Do not drop old tables in the same commit that migrates reads.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

Manual checks:

- Open:
  - `http://admin.localhost:3000/social/instagram/thetraitorsus`
  - `http://admin.localhost:3000/social/tiktok/thetraitorsus`
  - a Twitter/X account profile with saved catalog rows
  - a Reddit community/thread page with stored posts
- Check Posts, Comments, Catalog, Hashtags, Collaborators / Tags, and detail modals where available.
- Run or inspect one bounded backfill per active account-profile platform and one Reddit refresh.

Expected result:

- Admin surfaces remain behaviorally stable.
- Parity reports are clean or have documented known exceptions.
- Legacy table retirement is a separate explicit step.

Acceptance criteria:

- Existing user-facing admin workflows still work.
- Backend and app targeted tests pass.
- No destructive retirement happens without clean parity evidence.

Commit boundary:

- Rollout diagnostics and optional legacy-read disable flags. Table retirement should be a separate approval boundary.

## architecture_impact

- `TRR-Backend` remains the owner of schema, persistence, and social API composition.
- `TRR-APP` remains a consumer/proxy surface unless backend response envelopes change.
- The target model becomes:
  - `social.social_posts`: one canonical row per `(platform, source_id)`.
  - `social.social_post_memberships`: account, community, show, season, and person relationships.
  - `social.social_post_entities`: hashtags, mentions, collaborators, profile tags, flairs, sounds, channels, thread roots, etc.
  - `social.social_post_media_assets`: source/hosted media assets.
  - Legacy platform tables: preserved during rollout for comments/replies FKs, compatibility, and rollback.
- Reddit is included through a community membership adapter, not by pretending it is an account-profile catalog platform.

## data_or_api_impact

- Schema impact is broad but can be additive through the first implementation pass.
- Existing comment/reply table FKs remain unchanged.
- Existing backend API response envelopes should remain unchanged.
- New shared tables need RLS/policies aligned to current public-read behavior.
- Backfill scripts must be idempotent and handle partial execution.
- Metrics should use `bigint` in shared canonical storage to avoid per-platform integer drift.
- Platform-specific semantics should be mapped deliberately:
  - Twitter/X: `retweets`, `replies_count`, `quotes`, `bookmarks`, `thread_root_source_id`.
  - TikTok: `sound_id`, sound analytics, saves, quality/velocity fields.
  - Reddit: subreddit, flair, score, upvote ratio, spoiler/nsfw, post type.
  - YouTube: channel/video identity, title/description, duration.
  - Facebook/Threads: page/profile ownership, replies/reposts/shares, user avatars.

## ux_admin_ops_considerations

- Admin users should not see a new workflow during migration.
- Operator diagnostics should show parity by platform, not one blended total.
- Backfill commands should default to dry run and print JSON summaries.
- Any mismatch should identify platform, account/community, source ID, old values, new values, and proposed resolution.
- During rollout, keep legacy dual-write/fallback available so a bad read-path migration does not block social admin pages.

## validation_plan

Automated validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/api/test_admin_reddit_reads.py -k "social or reddit"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/reddit-sources-repository-backend.test.ts --reporter=dot
```

Database validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
.venv/bin/python scripts/db/social_post_schema_parity.py --platform instagram --account thetraitorsus --json
.venv/bin/python scripts/db/social_post_schema_parity.py --platform tiktok --account thetraitorsus --json
```

Manual validation:

- `make dev`
- Validate active social profile pages for Instagram, TikTok, Twitter/X, Facebook, Threads, and YouTube where handles exist.
- Validate Reddit community/thread pages.
- Verify Posts, Comments, Catalog, Hashtags, Collaborators / Tags, and detail modals where supported.
- Run one safe bounded backfill or refresh per active platform and confirm shared canonical/membership/entity/media rows are updated.

Remaining risk:

- Some platforms have catalog-only data and will need shared canonical rows before any materialized-table parity exists.
- Some current read paths may rely on platform-specific raw payload details not yet normalized.
- Reddit should not be over-normalized into account semantics.
- Full all-platform backfill may expose old rows with malformed source IDs or conflicting metadata.

## acceptance_criteria

1. There is one shared canonical `social.social_posts` row per platform source ID for every applicable platform.
2. Existing comments/replies remain attached to their current platform-specific post targets during rollout.
3. Every legacy account-catalog row has a matching `social.social_post_memberships` row, except documented invalid rows.
4. Reddit rows have community memberships and preserve Reddit-specific read behavior.
5. Social profile, catalog, and Reddit backend APIs remain shape-compatible.
6. Hashtag, mention, collaborator, tagged-user, flair, sound, channel, thread-root, and media read paths have normalized indexed tables available where applicable.
7. Backfill and live scrape/refresh writes maintain shared canonical, membership, entity, and media tables.
8. Parity scripts pass for active platforms and known handles/communities.
9. Legacy table retirement is not performed until a separate explicit approval boundary.

## risks_edge_cases_open_questions

- Should legacy platform materialized tables remain permanently as FK targets for comments/replies, or should comments eventually migrate to `social.social_posts` too?
- Should canonical metrics preserve max observed values, newest scrape values, or source/confidence-specific observations?
- Should show/person/season relationships live only in membership rows, or remain duplicated as compatibility columns on platform tables during a longer transition?
- Twitter/X and YouTube currently have catalog-only storage; implementation must not invent comment/materialized semantics that do not exist.
- Reddit has community-first semantics and rich moderation/flair fields. Include it through shared canonical/media/entity tables only where useful.
- Public read policies are currently permissive. Matching them preserves behavior, but a later security pass should revisit raw payload exposure.
- The plan assumes platform source IDs are stable within each platform. If any scraper uses multiple ID formats for the same post, identity normalization must happen before migration.

## follow_up_improvements

- Plan a separate comment/reply unification model after post canonicalization is stable.
- Add a materialized social profile summary read model after shared canonical reads settle.
- Split raw scraper payload history into append-only observation tables.
- Add provenance/confidence metadata for metrics and media fields.
- Revisit RLS for raw data and admin-only operational fields.

## recommended_next_step_after_approval

Use `orchestrate-plan-execution` because the work is tightly sequenced: baseline evidence, additive migration, backfill, write-path switch, read-path switch, parity gate. Parallel reviewer subagents can inspect platform-specific tests and query plans after each phase, but the main implementation should remain sequential to avoid conflicting schema/write-path edits.

## ready_for_execution

Yes, with one required execution discipline: do not drop, rename, or replace any legacy platform/catalog table until a separate parity report proves the new shared canonical/membership model matches current production data for that platform.
