# YouTube `bravo` Backfill Diagnostics

Last updated: 2026-04-10

## Summary

- Platform/account: `youtube` / `bravo`
- Root causes:
  1. **Schema drift** — `music_info` (and 6 other Apify enrichment columns) missing from `social.youtube_account_catalog_posts` and `social.facebook_account_catalog_posts`
  2. **Shorts pre-window page cap bypass** — `page_before_only` logic didn't count `timestamp_unknown` shorts pages, causing indefinite pagination through the shorts surface
- Fixes:
  1. Migration `20260410000000_catalog_posts_youtube_facebook_enrichment_columns.sql` (commit `9367c2e`)
  2. Scraper `page_before_only` fix in `scraper.py:1855` — undated shorts pages now count toward `PRE_WINDOW_PAGE_CAP` (pending deploy)
- Original failed run: `14570e52-57d7-4cf8-b3fc-21e0d476b707` (2026-03-24, 0 posts — empty channel page on Modal)
- Canary runs: see below

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

### Canary run 1 (2026-04-09): `4bc2af1d`

- Triggered via admin proxy: `POST /api/admin/trr-api/social/profiles/youtube/bravo/catalog/backfill`
- Scope: `bounded_window`, 2026-04-02 to 2026-04-09
- Dispatched to Modal: `modal:social:modal:2:f2f7a887`
- **Attempt 1:** Scraper found 76 matched posts across ~27 pages (videos + shorts), but persistence failed:
  ```
  UndefinedColumn: column "music_info" of relation "youtube_account_catalog_posts" does not exist
  ```
- **Between attempts:** Applied migration `20260410000000_catalog_posts_youtube_facebook_enrichment_columns.sql`
- **Attempt 2:** Scraper re-scanned but stalled — lease expired, 3/3 dispatch attempts exhausted, 0 posts persisted. Manually cancelled.

### Canary run 2 (2026-04-10): `e916e55b`

- Fresh run after schema fix, 7-day window (Apr 2–9)
- Scraper found 39 matched posts across 18 pages
- **Stalled on shorts surface** — per-video timestamp refinement (`_fetch_precise_publish_timestamp`) makes 2 HTTP requests per shorts video, causing ~5 min/page for shorts
- Lease expired, activity frozen at page 18. Manually cancelled.
- 0 posts persisted — scraper never reached persistence phase

### Canary run 3 (2026-04-10): `da0b00c0`

- Tight 2-day window (Apr 7–9) to reduce pagination
- Scraper checked 933 posts across 25+ pages, **0 matched** (window too narrow)
- **Confirmed shorts page cap bypass**: scraper continued past page 24 (cap=12 per surface) because undated shorts pages were not counted as "before-window"
- Confirmed Modal function stays alive past lease expiry — lease is a soft dispatcher concept, not a hard timeout
- Manually cancelled after confirming the cap bypass bug.

### Shared account source

- `social.shared_account_sources` row exists: `youtube/bravo`, `is_active=true`, `scrape_priority=100`
- Seed: `migration:20260402194500_seed_bravo_shared_account_sources`
- No prior successful scrape (`last_scrape_status=null`)

### Worker health

- `modal:social-dispatcher`: active, youtube in `supported_platforms`, `dispatch_enabled=true`
- Last heartbeat: recent (healthy)
- Instagram auth: `checkpoint_required` (unrelated to YouTube)

## Root Causes

### 1. Schema drift (fixed)

The migration `20260407170000_catalog_posts_apify_enrichment.sql` added 7 enrichment columns (`music_info`, `audio_url`, `paid_partnership`, `child_posts_data`, `owner_username`, `video_play_count`, `video_duration`) to Instagram, TikTok, Twitter, and Threads catalog tables but **missed YouTube and Facebook**.

The shared upsert function `_build_shared_catalog_upsert_payload` (line 25454 of `social_season_analytics.py`) writes these columns unconditionally for ALL platforms, causing `UndefinedColumn` errors when YouTube/Facebook backfill tries to persist posts.

### 2. Shorts pre-window page cap bypass (fixed locally, pending deploy)

The `page_before_only` flag in `scraper.py` (line 1855) was:
```python
page_before_only = (
    bool(page_stats.get("before_window_items"))
    and not bool(page_stats.get("window_candidate_items"))
    and not bool(page_stats.get("after_window_items"))
)
```

YouTube Shorts have low-precision timestamps ("2 days ago"). The scraper attempts to refine these via per-video HTTP requests (`_fetch_precise_publish_timestamp`), but when refinement fails, the items are classified as `timestamp_unknown` — NOT `before_window_items`. A page full of undated shorts had `page_before_only = False`, which:
1. **Reset `surface_pre_window_pages`** counter to 0 (preventing the cap from reaching 12)
2. **Did not increment** `surface_no_hit_pages` (because the `continue` on line 1904 was taken for mixed pages)

The net effect: the pre-window cap never triggered for shorts, and the scraper paginated indefinitely through the entire shorts catalog at ~5 min/page (due to per-video timestamp refinement).

### 3. Shorts timestamp refinement performance (identified, not yet addressed)

For each shorts video with a low-precision timestamp, `_refine_video_publish_timestamp_if_needed` calls `_fetch_precise_publish_timestamp` which makes **up to 2 HTTP requests** (watch page + shorts page) per video. With ~30 shorts per continuation page, processing a single shorts page can take 2-3 minutes instead of seconds. This is the proximate cause of why runs appear to "stall" and why the Modal dispatcher's lease expires.

## Fixes Applied

1. **Schema fix** (commit `9367c2e`, deployed): Migration adds the 7 missing columns to `youtube_account_catalog_posts` and `facebook_account_catalog_posts` with the same defaults as other platforms.

2. **Shorts page cap fix** (in working tree, pending deploy): Changed `page_before_only` to treat pages with ONLY `before_window_items` and/or `timestamp_unknown` items as "before-window" for capping:
   ```python
   page_before_only = (
       (_has_before or _has_unknown)
       and not _has_window
       and not _has_after
   )
   ```

3. **Diagnostic instrumentation** (in working tree, pending deploy):
   - `youtube_empty_channel_page` error code detection when scraper returns 0 posts with 0 first_page_counts
   - `ytdlp_available` boolean in `retrieval_meta` for runtime debugging
   - Tests: `tests/repositories/test_youtube_catalog_backfill_diagnostics.py` (7 tests)

## Canary Results

- **7-day bounded (canary 1, attempt 1):** Scraper found 76 matched posts, persistence failed (missing column `music_info`)
- **7-day bounded (canary 2):** Scraper found 39 matched posts but stalled on shorts timestamp refinement; lease expired before persistence
- **2-day bounded (canary 3):** 0 matched posts (window too narrow), confirmed shorts cap bypass bug
- **30-day bounded:** Not yet attempted (requires shorts cap fix deployed to Modal)
- **Full history:** Not yet attempted

## Show Assignment

- Total catalog posts: 0 (pending successful canary after deploy)
- Classification jobs: Not yet created (requires completed backfill)

## Follow-Up

1. **Deploy scraper fixes to Modal** — the `page_before_only` fix and diagnostic instrumentation require Modal redeployment to take effect
2. **Re-run 7-day bounded canary** after deploy to verify persistence succeeds with fixed schema AND reasonable shorts pagination
3. **Run 30-day bounded and full history** canaries
4. **Verify show assignment** — check classify jobs are enqueued and posts get assigned
5. **Consider optimizing shorts timestamp refinement** — the per-video HTTP request pattern is O(n) where n = total shorts across all pages. Options:
   - Batch timestamp lookups
   - Skip refinement for pages clearly outside the date window
   - Use a faster timestamp resolution strategy for shorts
6. **Monitor yt-dlp availability** — if `ytdlp_available=false` on Modal, metrics will be incomplete
7. **Facebook backfill** — same schema fix now enables Facebook catalog backfill too
