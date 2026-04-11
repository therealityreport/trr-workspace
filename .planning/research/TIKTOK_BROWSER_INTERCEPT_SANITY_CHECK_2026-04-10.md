# TikTok Browser Intercept Sanity Check

Date: 2026-04-10

## Question

Has `browser_intercept` been exercised against `@bravotv` recently, and does it still return at least `5` posts?

## Prior Evidence Search

- Searched repo docs, tests, and scripts for recent TikTok-specific `browser_intercept` evidence.
- Found no recent TikTok-specific live artifact in repo documentation or planning notes.
- The only discovered `browser_intercept` benchmark artifact was Instagram-only: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/benchmarks/bravotv_benchmark_20260402T220433Z.json`.
- The first planned invocation without hashtags failed immediately because `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/socials/tiktok/scrape.py` requires `--hashtags` for post scraping, so the bounded retry used `--hashtags RHOBH` to align with the existing 2026-04-10 TikTok smoke.

## Invocation

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m scripts.socials.tiktok.scrape \
  --username bravotv \
  --hashtags RHOBH \
  --start 2026-03-31 \
  --end 2026-04-10 \
  --max-pages 2 \
  --scrape-mode browser_intercept \
  --diagnostics-json /tmp/tiktok-browser-intercept-20260410.json
```

## Diagnostics

- Diagnostics file: `/tmp/tiktok-browser-intercept-20260410.json`
- `retrieval_mode="browser_intercept"`
- `auth_mode="with_cookies"`
- `http_client="requests"`
- `fallback_chain=["browser_intercept"]`
- `error_code="browser_intercept_zero_posts"`
- `stop_reason="browser_intercept_zero_posts"`
- `proxy_enabled=false`
- `endpoint_responses.fetch_user_detail.failure_reason="non_json_response"`
- `endpoint_responses.fetch_user_detail.http_status=200`
- CLI runtime summary: `browser_intercept complete for @bravotv: 0 posts in 5 scrolls (stop: no_new_data)`

## Result

The bounded 2026-04-10 `browser_intercept` run against `@bravotv` returned `0` posts, which is below the `>=5` threshold. The command itself succeeded and produced diagnostics, but the retrieval path did not surface any qualifying posts.

## Interpretation

`browser_intercept` is not currently a proven live TikTok backup path. It was exercised successfully enough to produce structured diagnostics, but because it returned `0` posts and stopped with `browser_intercept_zero_posts`, the remaining safety net is currently theoretical or broken rather than a known-good fallback.
