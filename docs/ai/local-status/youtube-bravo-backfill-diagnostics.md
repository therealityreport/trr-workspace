# YouTube `bravo` Backfill Diagnostics

Last updated: 2026-04-10

## Summary

- Platform/account: `youtube` / `bravo`
- Root cause: **Schema drift** — `music_info` (and 6 other Apify enrichment columns) missing from `social.youtube_account_catalog_posts` and `social.facebook_account_catalog_posts`
- Fix: Migration `20260410000000_catalog_posts_youtube_facebook_enrichment_columns.sql` (commit `9367c2e`)
- Original failed run: `14570e52-57d7-4cf8-b3fc-21e0d476b707` (2026-03-24, 0 posts — empty channel page on Modal)
- Canary run: `4bc2af1d-4d58-43bd-84af-a822c4233232` (2026-04-09, in progress)

## Evidence

### Prior run (2026-03-24): `14570e52`

- Executor: `modal:social:modal:2:e83abee9`
- Job status: `completed` with `items_found=0`
- `retrieval_meta.first_page_counts = {"shorts": 0, "videos": 0}` — both surfaces returned 0 renderers
- `retrieval_meta.checked_renderers = 0`
- `retrieval_meta.expected_total_posts = 417`
- `retrieval_meta.canonical_channel_id = null` — channel identity not resolved
- `error_code = "stale_heartbeat_timeout"` — heartbeat timeout masked the real issue
- `job_error_code = "stale_modal_dispatch_unclaimed"` — 3 dispatch attempts with stale recovery

**Interpretation:** The Modal runtime at that time could not extract video renderers from YouTube's channel page. Likely a stale yt-dlp/scraper version on Modal, or YouTube HTML structure change that was later fixed.

### Canary run (2026-04-09): `4bc2af1d`

- Triggered via admin proxy: `POST /api/admin/trr-api/social/profiles/youtube/bravo/catalog/backfill`
- Scope: `bounded_window`, 2026-04-02 to 2026-04-09
- Dispatched to Modal: `modal:social:modal:2:f2f7a887`
- **Attempt 1:** Scraper found 76 matched posts across ~27 pages (videos + shorts), but persistence failed:
  ```
  UndefinedColumn: column "music_info" of relation "youtube_account_catalog_posts" does not exist
  ```
- Status entered `retrying` (max_attempts=3)
- **Between attempts:** Applied migration `20260410000000_catalog_posts_youtube_facebook_enrichment_columns.sql`
- **Attempt 2:** Scraper re-running, currently scanning shorts surface (24 pages, 40 matched so far)
- Awaiting completion to verify persistence succeeds with fixed schema

### Shared account source

- `social.shared_account_sources` row exists: `youtube/bravo`, `is_active=true`, `scrape_priority=100`
- Seed: `migration:20260402194500_seed_bravo_shared_account_sources`
- No prior successful scrape (`last_scrape_status=null`)

### Worker health

- `modal:social-dispatcher`: active, youtube in `supported_platforms`, `dispatch_enabled=true`
- Last heartbeat: recent (healthy)
- Instagram auth: `checkpoint_required` (unrelated to YouTube)

## Root Cause

The migration `20260407170000_catalog_posts_apify_enrichment.sql` added 7 enrichment columns (`music_info`, `audio_url`, `paid_partnership`, `child_posts_data`, `owner_username`, `video_play_count`, `video_duration`) to Instagram, TikTok, Twitter, and Threads catalog tables but **missed YouTube and Facebook**.

The shared upsert function `_build_shared_catalog_upsert_payload` (line 25454 of `social_season_analytics.py`) writes these columns unconditionally for ALL platforms, causing `UndefinedColumn` errors when YouTube/Facebook backfill tries to persist posts.

## Fixes Applied

1. **Schema fix** (commit `9367c2e`): Migration adds the 7 missing columns to `youtube_account_catalog_posts` and `facebook_account_catalog_posts` with the same defaults as other platforms.

2. **Diagnostic instrumentation** (committed in TRR-Backend working tree):
   - `youtube_empty_channel_page` error code detection when scraper returns 0 posts with 0 first_page_counts (analogous to TikTok `discovery_empty_first_page` fix)
   - `ytdlp_available` boolean in `retrieval_meta` for runtime debugging
   - Test: `tests/repositories/test_youtube_catalog_backfill_diagnostics.py`

## Canary Results

- **7-day bounded (attempt 1):** Scraper found 76 matched posts, persistence failed (missing column). Schema fixed mid-retry.
- **7-day bounded (attempt 2):** In progress — scraper re-scanning, 40 matched so far. Awaiting persistence verification.
- **30-day bounded:** Not yet attempted
- **Full history:** Not yet attempted

## Show Assignment

- Total catalog posts: 0 (pending successful canary completion)
- Classification jobs: Not yet created (requires completed backfill)

## Follow-Up

1. **Verify canary attempt 2 completes with posts persisted** — check `persist_counters.posts_upserted > 0`
2. **Run 30-day bounded window** to test continuation pagination more extensively
3. **Run full history** to backfill all ~417 expected posts
4. **Verify show assignment** — check classify jobs are enqueued and posts get assigned
5. **Monitor yt-dlp availability** — if `ytdlp_available=false` on Modal, metrics will be incomplete
6. **Deploy diagnostic instrumentation to Modal** — the `youtube_empty_channel_page` error code only works if the Modal runtime has the updated code
7. **Facebook backfill** — same schema fix now enables Facebook catalog backfill too
