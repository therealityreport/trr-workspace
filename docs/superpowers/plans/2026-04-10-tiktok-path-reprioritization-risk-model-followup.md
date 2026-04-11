# TikTok Path Reprioritization Risk-Model Follow-Up Plan

## Summary

This follow-up is still docs/research only. It updates the TikTok risk narrative after the HTML-parser `NO-GO`, makes the collapsed fallback topology explicit, refreshes the parked Task 6 justification, scopes one bounded live `browser_intercept` sanity check for `@bravotv`, and records the pre-existing `TRR-Backend` dirty files in the existing TikTok diagnostics note.

Current repo facts that drive the plan:
- [TIKTOK_HTML_PARSER_DRIFT_SPIKE.md](/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md) already records `NO-GO`, but it does not yet spell out the mechanism/hypothesis/re-run trigger.
- [TIKTOK_SCRAPE_RESILIENCE_BOARD.md](/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md) still does not explicitly show the post-spike fallback topology.
- There is no repo evidence of a recent TikTok-specific `browser_intercept` run; the only `browser_intercept` benchmark artifact found is Instagram-only (`TRR-Backend/docs/ai/benchmarks/bravotv_benchmark_20260402T220433Z.json`).
- The pre-existing dirty `TRR-Backend` paths are discoverable now from `git status --short` and should be copied into the existing TikTok diagnostics note verbatim.

## Public Interfaces / Types

No API, schema, env-contract, or type changes. This plan only changes Markdown planning/status artifacts and runs one bounded live scrape check that writes diagnostics to `/tmp`.

## Key Changes

### 1. Extend the HTML parser spike note with mechanism and revisit criteria

Modify [TIKTOK_HTML_PARSER_DRIFT_SPIKE.md](/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md) by adding one paragraph immediately after `## Go/No-Go Outcome (2026-04-10): NO-GO` that states all three points explicitly:
- observed mechanism: both anonymous and authenticated captures retained `secUid` but exposed an empty `userInfo.itemList`
- working hypothesis: TikTok likely moved post listing to an XHR/deferred fetch path that the static HTML parser never sees
- re-run trigger: if a future capture shows `itemList` populated again, rerun the same bounded 2-hour spike and reconsider the `NO-GO`

Keep this as one paragraph so it reads as explanation, not a new investigation.

### 2. Make the collapsed fallback matrix explicit on the resilience board

Modify [TIKTOK_SCRAPE_RESILIENCE_BOARD.md](/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md) by inserting a new section near the top, before `## Execution Order`:

`## Current Fallback Topology — 2026-04-10`

List these five candidate paths with status and blocker/failure mode:

1. `yt-dlp`
   - status: sole production posts path
   - current state: known-good on `@bravotv` from the 2026-04-10 smoke (`16` posts)

2. `browser_intercept`
   - status: only remaining in-repo backup path
   - current state before item 4: no recent TikTok-specific live evidence found in repo
   - note: this status should be updated after the sanity-check note lands

3. direct `/api/*`
   - status: unavailable for production fallback
   - blocker: pivot root cause; explicit `api` run returns `0` posts with structured failure metadata

4. `curl_cffi + proxy`
   - status: unavailable / parked
   - blocker: Bright Data authenticated CONNECT `ProxyError`; do not reopen here

5. HTML parser
   - status: unavailable / `NO-GO`
   - blocker: `secUid` present but `itemList` empty on both anonymous and authenticated captures; parser sees no posts

End the section with one sentence that the effective fallback matrix has collapsed from five candidate paths to two meaningful paths (`yt-dlp` and `browser_intercept`), with only one currently proven live.

### 3. Update Task 6 parking notes to reflect concentrated risk, not old rationale

In the existing `## Deferred` Task 6 entry in [TIKTOK_SCRAPE_RESILIENCE_BOARD.md](/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md), keep Task 6 parked, but replace the implied old rationale with updated notes that say:
- the Task 5 trigger has fired, so the next cycle must explicitly re-evaluate rather than blindly keep parking
- `browser_intercept` is now load-bearing for both posts-backup risk and the eventual comments path
- Task 6 remains parked for scoping/risk-control reasons, not because fallback capacity is abundant
- the next planning pass should compare “comments urgency” against “single-safety-net fragility” before implementation

Do not change the non-goals. Do not start Task 6 implementation.

### 4. Scope and record one bounded `browser_intercept` sanity check

Create a new dated research note at:

[ TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md ](/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md)

Use this exact structure:
- title
- `Date`
- `Question`
- `Prior Evidence Search`
- `Invocation`
- `Diagnostics`
- `Result`
- `Interpretation`

Execution to scope into the plan:
- first record that no recent TikTok-specific `browser_intercept` evidence was found in repo docs/tests/scripts, and that the only discovered `browser_intercept` benchmark artifact was Instagram-only
- then run one bounded live scrape from `TRR-Backend` using the existing CLI:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m scripts.socials.tiktok.scrape \
  --username bravotv \
  --start 2026-03-31 \
  --end 2026-04-10 \
  --max-pages 2 \
  --scrape-mode browser_intercept \
  --diagnostics-json /tmp/tiktok-browser-intercept-20260410.json
```

Decision rules for the note:
- if the run returns `>=5` posts, record that `browser_intercept` is a real, recently exercised backup and cite the post count plus `retrieval_mode`, `posts_checked`, `pages_scanned`, and `stop_reason`
- if the run errors, returns `<5` posts, or cannot run because Playwright/browser prerequisites are unavailable, record that the safety net is currently theoretical or broken
- after the note is written, update the `browser_intercept` row in `## Current Fallback Topology — 2026-04-10` to cite this note and its outcome

This is a bounded research check, not a feature spike and not a code change.

### 5. Add the pre-existing dirty-file note to the TikTok diagnostics doc

Modify [tiktok-bravowwhl-run-093de71d-diagnostics.md](/Users/thomashulihan/Projects/TRR/docs/ai/local-status/tiktok-bravowwhl-run-093de71d-diagnostics.md) by appending one flat bullet under `## Follow-Up` with the exact pre-existing dirty `TRR-Backend` paths discovered from `git -C TRR-Backend status --short`:

- `.env.example`
- `docs/ai/HANDOFF.md`
- `requirements.in`
- `requirements.lock.txt`
- `scripts/socials/benchmark_bravotv.py`
- `scripts/socials/tiktok/scrape.py`
- `tests/repositories/test_social_season_analytics.py`
- `tests/scripts/test_refresh_social_cookies.py`
- `tests/socials/test_comment_scraper_fixes.py`
- `trr_backend/repositories/social_season_analytics.py`
- `trr_backend/socials/tiktok/scraper.py`
- `docs/ai/evidence/tiktok-path-reprioritization-20260410/`
- `docs/ai/local-status/tiktok-http-triage-followups.md`
- `docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`
- `docs/known-issues/`
- `docs/superpowers/`
- `tests/socials/tiktok/test_http_client.py`
- `trr_backend/socials/tiktok/http_client.py`

Keep it factual only. No blame, no interpretation.

## Test Plan

1. `python3 /Users/thomashulihan/Projects/TRR/scripts/sync-handoffs.py --check`
   - expected: still green

2. `bash /Users/thomashulihan/Projects/TRR/scripts/handoff-lifecycle.sh post-phase`
   - expected: still green

3. `test -f /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md`
   - expected: note exists

4. `rg -n "Current Fallback Topology — 2026-04-10|browser_intercept|itemList|XHR|re-run trigger|pre-existing dirty" /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md /Users/thomashulihan/Projects/TRR/docs/ai/local-status/tiktok-bravowwhl-run-093de71d-diagnostics.md /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md`
   - expected: all new notes/sections are present

5. No `ruff` or `pytest` runs
   - this remains doc-only work plus one live scrape check and `/tmp` diagnostics capture

## Assumptions And Defaults

- Still out of scope: request signing (`msToken`, `X-Bogus`, `_signature`), `curl_cffi + proxy` remediation, and Task 6 implementation.
- The browser-intercept check is intentionally one invocation only; do not expand into retries, code fixes, or a broader matrix.
- If the browser-intercept run cannot execute because Playwright/browser runtime is missing, that is itself the result and should be documented as such.
- Save this plan, when execution mode is allowed, as `/Users/thomashulihan/Projects/TRR/docs/superpowers/plans/2026-04-10-tiktok-path-reprioritization-risk-model-followup.md`.
