# Cross-Platform Social Post Schema Unification Plan

Date: 2026-04-28
Status: revised by Plan Grader
Recommended executor after approval: `inline sequential execution`

## summary

Unify TRR's social post storage across Instagram, TikTok, Twitter/X, Facebook, Threads, YouTube, and Reddit by introducing a shared sanitized canonical post model with platform-specific adapters, private raw-observation storage, and explicit legacy-reference bridges. The current Supabase schema has overlapping platform materialized tables, account catalog tables, comments/replies tables, and Reddit community-first tables.

The implementation is additive and backend-first. Keep legacy platform tables and comment/reply FKs stable during rollout, backfill shared canonical rows from every existing source table, dual-write new scrape/refresh output, migrate backend reads behind parity gates, and only retire or replace legacy tables after platform-specific parity reports pass.

## saved_path

`/Users/thomashulihan/Projects/TRR/.plan-grader/cross-platform-social-post-schema-unification-20260428-070313/REVISED_PLAN.md`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owner: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- App owner: `/Users/thomashulihan/Projects/TRR/TRR-APP`
- Live Supabase evidence from 2026-04-28:
  - `social.instagram_posts`: about 1,583 rows; `social.instagram_account_catalog_posts`: about 29,799 rows.
  - `social.tiktok_posts`: about 678 rows; `social.tiktok_account_catalog_posts`: about 11,501 rows.
  - `social.facebook_posts`: about 141 rows; `social.facebook_account_catalog_posts`: empty but present.
  - `social.meta_threads_posts`: about 3,495 rows; `social.threads_account_catalog_posts`: empty but present.
  - `social.twitter_tweets`: about 5,814 rows; `social.twitter_account_catalog_posts`: about 77 rows.
  - `social.youtube_videos`: about 418 rows; `social.youtube_account_catalog_posts`: about 40 rows.
  - `social.reddit_posts`: about 2,204 rows.
  - Large comment stores already exist: Instagram, TikTok, Reddit, YouTube, Threads, Facebook.
- Current social source tables generally have RLS enabled with public read policies. New shared tables must not accidentally expose raw scraper payloads just because current legacy tables do.
- Current backend platform mappings live in `TRR-Backend/trr_backend/repositories/social_season_analytics.py`:
  - `PLATFORM_POST_TABLES`
  - `PLATFORM_CATALOG_POST_TABLES`
  - `PLATFORM_COMMENT_TABLES`

## assumptions

1. Existing platform-specific comment/reply tables and FKs remain unchanged during this plan.
2. Canonical identity is `(platform, source_id)`, where `source_id` maps to the native stable post ID for each platform.
3. Account/profile/community/show/season/person relationships are memberships, not canonical post identity.
4. Raw scraper payloads and normalized provenance must live in private tables or backend-only routes, not public-readable canonical tables.
5. Reddit is community/thread-first; it participates through canonical rows, community memberships, entities, and media, not account catalog semantics.
6. Backend API response envelopes remain compatible unless a separate contract update is explicitly approved.
7. No legacy table is dropped, renamed, or replaced until per-platform parity passes.

## goals

1. Establish one shared canonical row per platform source ID.
2. Preserve all existing comments/replies and platform-specific FK relationships.
3. Introduce explicit bridge rows from legacy source tables to `social.social_posts`.
4. Represent account, community, show, season, and person relationships as indexed memberships.
5. Normalize hot arrays and JSON payload fields into indexed entity/media tables.
6. Keep raw payload/provenance in private observation tables.
7. Preserve existing backend/admin API response shapes.
8. Add parity checks by platform, account/community, source ID, comments/replies, media, and entity counts.
9. Keep rollback possible through legacy read paths until parity and route validation pass.

## non_goals

- No immediate destructive retirement of legacy platform or catalog tables.
- No comments/replies unification into `social.social_posts`; that is a later plan.
- No app redesign.
- No Supabase capacity or pool-size change.
- No scraper/proxy/auth/worker orchestration rewrite.
- No public API response shape break.

## phased_implementation

### Phase 0 - Baseline Platform Matrix And Contract Lock

Concrete changes:

- Add a local-status doc with the corrected platform matrix:

| Platform | Materialized table | Catalog table | Comment/reply table | Shared model path |
|---|---|---|---|---|
| Instagram | `social.instagram_posts` | `social.instagram_account_catalog_posts` | `social.instagram_comments` | canonical + account memberships |
| TikTok | `social.tiktok_posts` | `social.tiktok_account_catalog_posts` | `social.tiktok_comments` | canonical + account memberships + sound entities |
| Twitter/X | `social.twitter_tweets` | `social.twitter_account_catalog_posts` | no first-class comments table in current platform map | canonical + account memberships + thread metadata |
| Facebook | `social.facebook_posts` | `social.facebook_account_catalog_posts` | `social.facebook_comments` | canonical + account memberships |
| Threads | `social.meta_threads_posts` | `social.threads_account_catalog_posts` | `social.meta_threads_comments` | canonical + account memberships |
| YouTube | `social.youtube_videos` | `social.youtube_account_catalog_posts` | `social.youtube_comments` | canonical + account/channel memberships |
| Reddit | `social.reddit_posts` | none | `social.reddit_comments` | canonical + community memberships |

- Add read-only parity script `TRR-Backend/scripts/db/social_post_schema_parity.py` with:
  - `--platform instagram|tiktok|twitter|facebook|threads|youtube|reddit|all`
  - `--account <handle>`
  - `--community <subreddit>`
  - `--json`
- Include checks for:
  - materialized rows;
  - catalog rows;
  - legacy rows with no shared canonical row;
  - shared rows with no legacy source row;
  - comments/replies whose legacy target is missing;
  - source ID duplicates/conflicts;
  - public grants/RLS presence on new shared tables once they exist.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```

Acceptance criteria:

- Baseline is read-only and platform-specific.
- Twitter/X and YouTube materialized tables are included.
- Reddit is community-first.

Commit boundary:

- Baseline doc and read-only parity script.

### Phase 1 - Add Shared Sanitized Tables, Private Observation Tables, And Integrity Bridges

Concrete changes:

- Add additive migration for `social.social_posts` without raw payload columns:

```sql
create table if not exists social.social_posts (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('instagram', 'tiktok', 'twitter', 'facebook', 'threads', 'youtube', 'reddit')),
  source_id text not null,
  owner_handle text,
  owner_handle_norm text,
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
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_scraped_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, source_id),
  unique (platform, id)
);
```

- Add private raw/provenance table:

```sql
create table if not exists social.social_post_observations (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  post_id uuid not null,
  source_table text not null,
  source_pk text,
  scrape_run_id uuid references social.scrape_runs(id) on delete set null,
  observed_at timestamptz not null default now(),
  raw_payload jsonb not null default '{}'::jsonb,
  normalized_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  foreign key (platform, post_id) references social.social_posts(platform, id) on delete cascade
);
```

- Add legacy source bridge:

```sql
create table if not exists social.social_post_legacy_refs (
  platform text not null,
  post_id uuid not null,
  legacy_schema text not null default 'social',
  legacy_table text not null,
  legacy_pk text not null,
  legacy_source_id text not null,
  created_at timestamptz not null default now(),
  primary key (platform, legacy_table, legacy_pk),
  unique (platform, legacy_table, legacy_source_id),
  foreign key (platform, post_id) references social.social_posts(platform, id) on delete cascade
);
```

- Add memberships with normalized lookup keys and composite FK:

```sql
create table if not exists social.social_post_memberships (
  platform text not null,
  membership_type text not null check (membership_type in ('account', 'community', 'show', 'season', 'person', 'channel')),
  membership_key text not null,
  membership_key_norm text not null,
  post_id uuid not null,
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
  primary key (platform, membership_type, membership_key_norm, post_id),
  foreign key (platform, post_id) references social.social_posts(platform, id) on delete cascade
);
```

- Add entities/media with normalized keys and composite FKs.
- Enable RLS on shared tables.
- Grant public select only on sanitized canonical/membership/entity/media tables if needed. Do not grant public select on `social.social_post_observations`.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/api/test_startup_validation.py -k "social or platform"
```

Acceptance criteria:

- Shared schema is additive.
- Raw payloads are private.
- Child rows cannot point at a post from another platform.
- Normalized keys prevent case-variant duplicates.

Commit boundary:

- Migration plus schema/advisor tests.

### Phase 2 - Backfill Shared Canonical Rows Per Platform

Concrete changes:

- Add `TRR-Backend/scripts/db/backfill_social_post_canonical_schema.py`.
- Support dry run by default, `--execute`, `--platform`, `--account`, `--community`, `--batch-size`, and `--json`.
- Backfill all source pairs:
  - Instagram: `instagram_posts` and `instagram_account_catalog_posts`.
  - TikTok: `tiktok_posts` and `tiktok_account_catalog_posts`.
  - Twitter/X: `twitter_tweets` and `twitter_account_catalog_posts`.
  - Facebook: `facebook_posts` and `facebook_account_catalog_posts`.
  - Threads: `meta_threads_posts` and `threads_account_catalog_posts`.
  - YouTube: `youtube_videos` and `youtube_account_catalog_posts`.
  - Reddit: `reddit_posts`.
- Insert/update:
  - `social.social_posts`;
  - `social.social_post_legacy_refs`;
  - `social.social_post_memberships`;
  - `social.social_post_entities`;
  - `social.social_post_media_assets`;
  - private `social.social_post_observations`.
- Preserve legacy rows and never delete source data.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/backfill_social_post_canonical_schema.py --platform all --dry-run --json
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```

Acceptance criteria:

- Backfill is idempotent.
- Per-platform parity can be proven before all-platform execution.
- Legacy comments/replies keep their original FK targets.

Commit boundary:

- Backfill script plus focused tests.

### Phase 3 - Dual-Write New Scrape/Refresh Output

Concrete changes:

- Add shared helpers:
  - `_upsert_social_canonical_post(...)`
  - `_sync_social_post_legacy_ref(...)`
  - `_sync_social_post_memberships(...)`
  - `_sync_social_post_entities(...)`
  - `_sync_social_post_media_assets(...)`
  - `_record_social_post_observation(...)`
- Update platform write paths for Instagram, TikTok, Twitter/X, Facebook, Threads, YouTube, and Reddit.
- Keep legacy platform/catalog writes active.
- Emit diagnostics when shared write and legacy write diverge.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py tests/api/test_admin_reddit_reads.py -k "instagram or tiktok or twitter or facebook or threads or youtube or reddit"
```

Acceptance criteria:

- New scrape/refresh output writes shared and legacy state.
- Rollback remains possible by reading legacy tables.
- Divergence is visible in diagnostics.

Commit boundary:

- Backend write-path refactor plus tests.

### Phase 4 - Migrate Backend Reads Behind Compatibility Helpers

Concrete changes:

- Migrate reads in this order:
  1. Catalog/profile lists for account-profile platforms.
  2. Post detail and media previews.
  3. Entity lookups.
  4. Comments-only post lists using legacy comment tables plus bridge refs.
  5. Reddit community/thread reads where shared tables reduce duplication without changing Reddit semantics.
- Preserve existing route response envelopes.
- Keep fallback helpers for legacy tables until parity gates pass.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/api/test_admin_reddit_reads.py -k "social or reddit"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/reddit-sources-repository-backend.test.ts --reporter=dot
```

Acceptance criteria:

- API envelopes remain shape-compatible.
- Counts match per-platform parity reports.
- Entity/media queries use shared indexed tables.
- Legacy FK targets remain intact.

Commit boundary:

- Backend read migration plus app fixture updates only if needed.

### Phase 5 - Rollout, Parity Gate, And Legacy Retirement Decision

Concrete changes:

- Run all-platform parity:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```

- Add operator-facing diagnostics for:
  - shared canonical rows by platform;
  - membership rows by type;
  - legacy rows without shared rows;
  - comments/replies missing legacy targets;
  - observation rows with public grants accidentally enabled;
  - entity/media sync gaps.
- Decide per platform whether legacy tables remain archives, compatibility views, permanent FK targets, or candidates for a later retirement plan.

Manual validation:

- `make dev`
- Validate active social profile pages for Instagram, TikTok, Twitter/X, Facebook, Threads, and YouTube where handles exist.
- Validate Reddit community/thread pages.
- Run one safe bounded backfill or refresh per active platform.

Acceptance criteria:

- Admin surfaces remain behaviorally stable.
- Parity reports pass or document accepted exceptions.
- No destructive retirement happens in this plan.

Commit boundary:

- Rollout diagnostics and optional legacy-read disable flags.

## architecture_impact

- `TRR-Backend` owns schema, persistence, adapters, and API composition.
- `TRR-APP` remains a consumer/proxy surface unless route envelopes change.
- Target model:
  - `social.social_posts`: sanitized canonical row per `(platform, source_id)`.
  - `social.social_post_observations`: private raw/provenance history.
  - `social.social_post_legacy_refs`: bridge from legacy source rows and comments/replies to canonical rows.
  - `social.social_post_memberships`: account, community, channel, show, season, person relationships.
  - `social.social_post_entities`: hashtags, mentions, collaborators, profile tags, flairs, sounds, channels, thread roots.
  - `social.social_post_media_assets`: source/hosted media assets.

## data_or_api_impact

- Schema impact is broad but additive.
- Existing comment/reply FKs remain unchanged.
- Public/backend response envelopes remain unchanged.
- Raw payloads move to private observation storage instead of public canonical rows.
- Platform-specific semantics remain adapter-owned.

## ux_admin_ops_considerations

- No new admin workflow during migration.
- Diagnostics must show parity by platform.
- Backfill commands default to dry run.
- Mismatches must include platform, source table, source ID, account/community, old value, new value, and recommended action.

## validation_plan

Automated:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/api/test_admin_reddit_reads.py -k "social or reddit"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/reddit-sources-repository-backend.test.ts --reporter=dot
```

Database:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```

Manual:

- `make dev`
- Validate active social profile pages for supported platforms.
- Validate Reddit community/thread pages.
- Confirm private observation table has no public select grant.

## acceptance_criteria

1. One shared sanitized `social.social_posts` row exists per platform source ID.
2. Legacy comments/replies remain attached to current platform-specific post targets.
3. Bridge refs exist for legacy source rows used by read paths.
4. Raw payloads are private and not exposed through public table policies.
5. Membership/entity/media rows have normalized keys and platform-consistent FKs.
6. Backend APIs remain shape-compatible.
7. Parity scripts pass for active platforms and known handles/communities.
8. Legacy table retirement is deferred to a separate approval boundary.

## risks_edge_cases_open_questions

- Should legacy materialized platform tables remain permanent FK targets for comments/replies?
- Which metric resolution rule should win per platform: max observed, newest observed, or trusted-source priority?
- Should show/person/season membership fully replace compatibility columns later?
- Should raw observation retention have TTL or archival policy?
- How should multiple source IDs for the same platform post be canonicalized if a scraper changes ID format?

## follow_up_improvements

- Separate comment/reply unification plan.
- Materialized social profile summary read model.
- Per-field provenance confidence scoring.
- RLS/security tightening for legacy source tables.
- Compatibility views for legacy catalog tables after read migration.

## recommended_next_step_after_approval

Use sequential inline execution from this `REVISED_PLAN.md`. The work is tightly coupled at the schema and write-path levels, so avoid splitting implementation into independent workers until each phase lands. Platform-focused review or validation can run after each phase.

## ready_for_execution

Yes after approval, with the hard constraint that no legacy platform/catalog table may be dropped, renamed, or replaced until a separate parity report proves the new shared canonical/membership model matches current production data for that platform.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
