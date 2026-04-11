# TikTok Browser Intercept Recovery Triage

Date: 2026-04-10

## Question

Why does `browser_intercept` return `0` posts on `@bravotv`?

## Inputs

- `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md`
- `/tmp/tiktok-browser-intercept-recovery-20260410.json`

## Hypotheses

1. auth/session state
2. interception target drift
3. scroll/pagination drift
4. Playwright/TikTok runtime change

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
  --diagnostics-json /tmp/tiktok-browser-intercept-recovery-20260410.json
```

## Diagnostics

- `retrieval_mode="browser_intercept"`
- `auth_mode="with_cookies"`
- `http_client="requests"`
- `fallback_chain=["browser_intercept"]`
- `triage_bucket="scroll_or_pagination_drift"`
- `error_code="browser_intercept_zero_posts"`
- `stop_reason="browser_intercept_zero_posts"`
- `intercepted_post_responses=0`
- `intercepted_user_detail_responses=0`
- `dom_cards_seen=0`
- `scroll_iterations=5`
- `playwright_error=null`
- `endpoint_responses.fetch_user_detail.failure_reason="non_json_response"`
- `endpoint_responses.fetch_user_detail.http_status=200`

## Conclusion

The authenticated 2026-04-10 recovery-triage run classified the failure as `scroll_or_pagination_drift`, not `interception_target_drift`: the browser path produced `0` post-list intercepts, `0` intercepted user-detail browser responses, and `0` DOM cards across `5` scroll iterations before ending with `browser_intercept_zero_posts`. The direct `fetch_user_detail` preflight still recorded a structured `non_json_response`, but that signal did not come from browser interception and should not be treated as evidence that the intercept target itself is live. Do not broaden this into request-signing or proxy work; the next engineering decision is whether to repair the browser scroll/intercept surface or keep TikTok fallback risk explicit.
