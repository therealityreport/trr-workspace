# AUDIT

Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-cross-platform-social-post-schema-unification-plan.md`

Verdict: `REVISE BEFORE EXECUTION`

Approval decision: do not execute the source plan as written. The direction is valuable, but Supabase live-state validation found a blocking current-state mismatch and several schema-governance gaps that would create rework or unsafe public exposure if implemented literally.

## Current-State Fit

The plan correctly identifies that social post storage is split across platform materialized tables and account catalog tables. It also correctly includes Reddit as community/thread-first rather than account-profile-first.

Supabase Fullstack live checks corrected one material claim:

- `social.twitter_tweets` exists and has 55 columns, about 5,814 estimated rows, and 26 MB total size.
- `social.youtube_videos` exists and has 44 columns, about 418 estimated rows, and 4,064 kB total size.
- The source plan incorrectly described Twitter/X and YouTube as catalog-only platforms.

Live source-table scale also matters for sequencing:

- `social.instagram_comments`: about 152,980 rows and 409 MB.
- `social.tiktok_comments`: about 95,412 rows and 199 MB.
- `social.reddit_comments`: about 100,026 rows and 305 MB.

## Benefit Score

Benefit score: `8/10`

The work is beneficial because it addresses real duplicated social-post storage, JSON-heavy read paths, and platform drift. The benefit is highest if the plan becomes a canonical read/write bridge with parity gates before any destructive cleanup.

## Blocking Findings

1. `BLOCKER`: Twitter/X and YouTube are not catalog-only in the current schema. Any backfill/write/read migration that ignores `social.twitter_tweets` and `social.youtube_videos` risks dropping existing materialized rows, comments joins, and media state.
2. `BLOCKER`: The proposed `social.social_posts` table stores `raw_data` directly while also saying new tables should match current public-read behavior. Supabase RLS cannot hide individual columns; public `select using true` on a table with raw payloads would intentionally expose raw scraper data.
3. `BLOCKER`: The proposed membership/entity/media tables duplicate `platform` without a composite FK that proves the platform matches the referenced post. This can create internally inconsistent rows such as a TikTok membership pointing at an Instagram post ID.
4. `MAJOR`: The plan does not require normalized membership/entity keys as stored columns. Expression indexes help lookup speed, but case-sensitive primary keys still allow duplicate semantic memberships like `TheTraitorsUS` and `thetraitorsus`.
5. `MAJOR`: Comments/replies are correctly left on legacy FK targets, but the plan needs a bridge table or explicit compatibility joins from legacy post rows to `social.social_posts` before backend read migration.
6. `MAJOR`: The migration phase is too large as one migration. It should split into shared enums/types and sanitized canonical tables, private observation/raw tables, bridge/reference tables, indexes/RLS/grants, then backfill scripts.

## Approval Conditions

The revised plan is approvable if it:

- corrects the platform matrix to include `social.twitter_tweets` and `social.youtube_videos`;
- moves raw scraper payloads into a private observation/provenance table or keeps them in legacy tables until a private table exists;
- adds composite integrity for platform/post relationships;
- stores normalized lookup keys;
- adds a legacy-reference bridge for comments/read migration;
- keeps per-platform parity and no destructive retirement as hard gates.

