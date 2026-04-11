# TikTok Scraping Path Reprioritization Plan

## Summary

- Pivot TikTok post scraping to explicit `yt-dlp`-first behavior.
- Keep direct `api` and `browser_intercept` paths available only as explicit experiments.
- Park direct comments behind an experiment flag until the browser-intercept comments phase lands.
- Route shared-account TikTok posts away from the partitioned direct API path without changing persisted config metadata in this pass.

## Implementation Focus

1. Make `TikTokScrapeConfig.scrape_mode` default to `ytdlp`, keep `auto` as a deprecated alias, and make direct HTTP transport lazy so default runs never build `requests` or `curl_cffi`.
2. Normalize first-class `yt-dlp` diagnostics: `retrieval_mode=ytdlp`, `http_client=yt_dlp`, `fallback_chain=["yt_dlp"]`, bounded `stop_reason`, cookie presence and usage fields, and `profile_enrichment_status=skipped`.
3. Force explicit `scrape_mode="ytdlp"` at production callers in `social_season_analytics.py`, the TikTok scrape CLI, and the Bravo benchmark script.
4. Bypass `_scrape_shared_tiktok_posts_partitioned(...)` at the top of `_scrape_shared_tiktok_posts(...)` for TikTok, even when the catalog metadata still advertises cursor partitions.
5. Park direct TikTok comments by default with `SOCIAL_TIKTOK_ENABLE_DIRECT_COMMENT_API_EXPERIMENT=1` as the only opt-in override.
6. Preserve `http_client.py` and direct transport CLI flags for experiments, but document the Bright Data proxy failure as known operational debt that is off the critical path.

## Validation

- `ruff check .`
- `ruff format --check .`
- `pytest -q`
- `make schema-docs-check` only if schema or docs contracts drift

## Operational Notes

- Evidence captures belong under `TRR-Backend/docs/ai/evidence/`.
- Session notes belong under `TRR-Backend/docs/ai/local-status/`.
- Permanent operational debt belongs under `TRR-Backend/docs/known-issues/`.
- Do not buy more residential or ISP proxy credits on current evidence; let the Bright Data trial expire unless `yt-dlp` stops working and a new hypothesis appears.
