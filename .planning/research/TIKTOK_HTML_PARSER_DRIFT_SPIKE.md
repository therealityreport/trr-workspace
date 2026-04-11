# TikTok HTML Parser Drift Spike

Date: 2026-04-10

Time Budget: 2 hours hard cap

## Inputs

- Target account: `@bravotv`
- Capture directory: `/tmp/tiktok-html-parser-drift-20260410`
- Anonymous capture: `/tmp/tiktok-html-parser-drift-20260410/anonymous.json`
- Authenticated capture: `/tmp/tiktok-html-parser-drift-20260410/authenticated.json`
- Existing selector implementation: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py:717`

## Selector Set Under Test

Compared both live captures against the current `_extract_posts_from_html_data(...)` selector families:

- `__DEFAULT_SCOPE__.webapp.user-detail.userInfo.itemList`
  - Anonymous: present, but `itemList` length is `0`
  - Authenticated: present, but `itemList` length is `0`
- `ItemModule`
  - Anonymous: absent / empty (`0` items)
  - Authenticated: absent / empty (`0` items)
- `UserModule.users.<username>.secUid`
  - Anonymous: `UserModule` path absent, but `secUid` is still present under `userInfo.user`
  - Authenticated: `UserModule` path absent, but `secUid` is still present under `userInfo.user`

The two captures are structurally identical for the selectors currently used by `_extract_posts_from_html_data(...)`: `__DEFAULT_SCOPE__` exists, `userInfo` exists, `secUid` survives, but no post list is exposed through the current selector set.

## Procedure

1. Ran a one-off Python snippet from `/Users/thomashulihan/Projects/TRR/TRR-Backend` using the existing repo codepath only.
2. Imported `TikTokScraper` from `trr_backend.socials.tiktok`.
3. Imported `_load_tiktok_cookies` from `trr_backend.repositories.social_season_analytics`.
4. Executed `_fetch_profile_html("bravotv", 0.0)` once with `{}` cookies and once with `_load_tiktok_cookies()`.
5. Passed each capture into `_extract_posts_from_html_data(data or {}, "bravotv")`.
6. Persisted raw capture summaries and the underlying HTML-derived JSON payload to `/tmp/tiktok-html-parser-drift-20260410/{anonymous,authenticated}.json`.
7. Diffed the resulting payload shapes against the selector families listed above.

## Pass Criterion

The extractor returns at least `5` posts on both captures, and those posts include populated `aweme_id`, `create_time`, and `statistics.play_count` or an equivalent nested play-count field.

## Fail Criterion

If either capture returns fewer than `5` posts, or the returned posts omit `aweme_id`, `create_time`, or play-count metadata, record the parser as not viable as fallback and close the spike with no code changes.

## Findings

- Anonymous capture result: `0` posts, `sec_uid` present.
- Authenticated capture result: `0` posts, `sec_uid` present.
- Both captures expose only `__DEFAULT_SCOPE__` at top level.
- Both captures include `webapp.user-detail.userInfo` with keys `itemList`, `stats`, `statsV2`, and `user`.
- In both captures, `userInfo.itemList` is empty, `ItemModule` is absent, and `UserModule.users.bravotv` is absent.
- Because no posts were returned in either capture, neither run produced any records with populated `aweme_id`, `create_time`, or `statistics.play_count`.

## Go/No-Go Outcome (2026-04-10): NO-GO

NO-GO. Both the anonymous and authenticated `_fetch_profile_html` captures for `@bravotv` returned `0` posts through the current `_extract_posts_from_html_data(...)` selector set, even though `secUid` was still present in `userInfo.user`; the extractor therefore failed the minimum `>=5` posts threshold and produced no items with `aweme_id`, `create_time`, or play-count fields, so this path is not viable as fallback.

The observed mechanism was consistent on both captures: `secUid` survived, but `userInfo.itemList` stayed empty, which strongly suggests TikTok has moved the post listing to an XHR-deferred path that the static HTML parser does not see rather than merely serving a degraded static payload; if a future capture shows `itemList` populated again, rerun the same bounded 2-hour exercise and reconsider this `NO-GO`.
