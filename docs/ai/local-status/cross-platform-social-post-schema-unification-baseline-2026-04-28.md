# Cross-Platform Social Post Schema Unification Baseline

Date: 2026-04-28
Status: implementation slice 0/1
Scope: backend schema foundation only

## Contract Lock

This rollout is additive. It does not drop, rename, or replace any legacy platform table, catalog table, comment table, reply relationship, or backend API response envelope.

Raw scraper payloads must remain backend-private. The shared public-readable model is sanitized canonical post data plus lookup/membership/media/entity records. Private observations are stored separately in `social.social_post_observations` with no public grants or public RLS policy.

## Current Platform Matrix

| Platform | Materialized table | Catalog table | Comment/reply table | Shared model path |
|---|---|---|---|---|
| Instagram | `social.instagram_posts` | `social.instagram_account_catalog_posts` | `social.instagram_comments` | canonical + account memberships |
| TikTok | `social.tiktok_posts` | `social.tiktok_account_catalog_posts` | `social.tiktok_comments` | canonical + account memberships + sound entities |
| Twitter/X | `social.twitter_tweets` | `social.twitter_account_catalog_posts` | none in `PLATFORM_COMMENT_TABLES` | canonical + account memberships + thread metadata |
| Facebook | `social.facebook_posts` | `social.facebook_account_catalog_posts` | `social.facebook_comments` | canonical + account memberships |
| Threads | `social.meta_threads_posts` | `social.threads_account_catalog_posts` | `social.meta_threads_comments` | canonical + account memberships |
| YouTube | `social.youtube_videos` | `social.youtube_account_catalog_posts` | `social.youtube_comments` | canonical + account/channel memberships |
| Reddit | `social.reddit_posts` | none | `social.reddit_comments` | canonical + community memberships |

## Live Baseline Evidence

Captured from Supabase on 2026-04-28 before the shared schema foundation:

| Table | Approx rows | Approx size |
|---|---:|---:|
| `social.instagram_posts` | 1,583 | 39 MB |
| `social.instagram_account_catalog_posts` | 29,799 | 241 MB |
| `social.tiktok_posts` | 678 | 6,296 kB |
| `social.tiktok_account_catalog_posts` | 11,501 | 32 MB |
| `social.facebook_posts` | 141 | 1,224 kB |
| `social.facebook_account_catalog_posts` | 0 | not material |
| `social.meta_threads_posts` | 3,495 | 26 MB |
| `social.threads_account_catalog_posts` | 0 | not material |
| `social.twitter_tweets` | 5,814 | 26 MB |
| `social.twitter_account_catalog_posts` | 77 | not material |
| `social.youtube_videos` | 418 | 4,064 kB |
| `social.youtube_account_catalog_posts` | 40 | not material |
| `social.reddit_posts` | 2,204 | 13 MB |

Large legacy comment stores remain on their current FKs:

| Table | Approx rows | Approx size |
|---|---:|---:|
| `social.instagram_comments` | 152,980 | 409 MB |
| `social.tiktok_comments` | 95,412 | 199 MB |
| `social.reddit_comments` | 100,026 | 305 MB |
| `social.youtube_comments` | 30,529 | 47 MB |
| `social.meta_threads_comments` | 1,744 | not material |
| `social.facebook_comments` | 6 | not material |

## Execution Notes

- `social.social_posts` is the shared sanitized row keyed by `(platform, source_id)`.
- `social.social_post_legacy_refs` bridges every legacy source row to its canonical post without changing legacy FKs.
- `social.social_post_memberships` represents account, community, channel, show, season, and person relationships through normalized lookup keys.
- `social.social_post_entities` and `social.social_post_media_assets` hold indexed arrays/media that should not stay trapped in raw JSON for shared read paths.
- `social.social_post_observations` stores raw/provenance payloads and remains private.

Use `TRR-Backend/scripts/db/social_post_schema_parity.py` for read-only before/after checks:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
```
