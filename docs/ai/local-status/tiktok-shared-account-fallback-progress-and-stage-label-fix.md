# TikTok Shared-Account Fallback Progress And Stage Label Fix

Date: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "tiktok shared-account fallback progress and stage labeling fixed"
  next_action: "Reload the TikTok shared-account admin page and confirm the active fallback runner now reports checked counts and renders as Catalog Fetch instead of Shard Workers."
  detail: self
```

## Summary
- Fixed shared-account TikTok fallback runs so scraper progress is forwarded into catalog job progress.
- Fixed admin page labeling so `single_runner_fallback` shared-account post work renders as `Catalog Fetch` instead of `Shard Workers`.

## Backend
- File: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `_scrape_shared_posts_for_account(...)` now forwards `progress_cb` into `_scrape_shared_tiktok_posts(...)`.
- `_scrape_shared_tiktok_posts(...)` now:
  - accepts `progress_cb`
  - forwards it into `TikTokScraper.scrape(...)`
  - emits `persist_catalog_posts` progress while upserting shared catalog rows
  - records `persist_counters` for shared catalog mode

## Frontend
- File: `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `shared_account_posts` is now displayed as `Catalog Fetch` when the live run reports `worker_runtime.runner_strategy = single_runner_fallback`.
- Stage activity summaries use `checked/saved` copy for fallback fetch mode.
- Phase copy now says `Fetching catalog posts` instead of implying shard workers for the fallback runner.

## Tests
- Backend:
  - `pytest -q /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'forwards_progress_cb_to_tiktok or emits_catalog_persist_progress or incomplete_single_runner_fallback'`
- Frontend:
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx`

## Notes
- This fixes the admin visibility gap for live TikTok shared-account fallback runs. It does not change Modal ownership of the job plane.
- 2026-03-22 live BravoTV follow-up:
  - The original `@bravotv` fallback job was not just mislabeled; it had two runtime bugs in the TikTok fallback path.
  - First, the `yt-dlp` fallback was capped at `500` videos when no date window was present, so the worker could never progress past `500 / 10,100` discovered posts even though discovery had already established a much larger expected total.
  - Second, the long-running uncapped `yt-dlp` scan emitted no intermediate job progress, so `heartbeat_at` stopped moving and the queue recovered the still-running Modal worker as `stale_heartbeat_timeout` after five minutes.
  - `TikTokScrapeConfig` now carries an advisory `ytdlp_max_videos_hint`, shared-account fallback jobs pass the discovered/expected total into that hint, and the TikTok scraper now emits `scrape_ytdlp_fallback` progress plus updated scan counts while the playlist is still being enumerated.
  - Validation:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/socials/test_comment_scraper_fixes.py -k 'test_tiktok_auto_mode_uses_ytdlp_after_empty_browser_intercept or test_tiktok_scrape_skips_api_pagination_after_poisoned_preflight_and_uses_ytdlp'`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k 'test_scrape_shared_tiktok_posts_single_runner_fallback_bypasses_partition_api_path or test_run_shared_account_discovery_stage_enqueues_partitioned_fallback_job or test_get_social_account_catalog_run_progress_prefers_active_single_runner_fallback_runtime'`
  - Modal was redeployed twice during the live recovery. The current BravoTV replay for run `64600f95-5042-420d-bc82-6fc7b9f2ae41` is now genuinely running on Modal and has advanced past the old ceiling, reaching `700 / 10,100` checked with fresh heartbeats as of the latest check.
