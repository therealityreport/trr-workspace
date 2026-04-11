# TikTok Path Reprioritization Follow-Ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unblock workspace handoff sync after the TikTok posts-path pivot, create a bounded HTML-parser fallback spike, and park comments-via-browser-intercept behind a trigger-based follow-up.

**Architecture:** Keep this pass docs-and-research only. Do not change `scraper.py`, `account_browser_sessions.py`, or `modal_jobs.py` in this TODO. The only generated artifact that may change is `docs/ai/HANDOFF.md` when `scripts/handoff-lifecycle.sh post-phase` is rerun after the source note is fixed.

**Tech Stack:** Markdown, workspace handoff tooling, Python 3.11 shell snippets, existing TikTok scraper internals

---

## Summary

- Current blocker is verified: `python3 scripts/sync-handoffs.py --check` fails on `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/tiktok-bravowwhl-run-093de71d-diagnostics.md` because it lacks `## Handoff Snapshot`.
- The existing TikTok planning artifacts live at workspace root, not under `TRR-Backend`: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_PATH_REPRIORITIZATION_PLAN.md` and `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`.
- Task 5 should become a dated, 2-hour, no-code research note that uses `_fetch_profile_html()` plus `_extract_posts_from_html_data()` against `@bravotv` with authenticated and anonymous captures.
- Task 6 stays parked until Task 5 records a binary go/no-go result.

## File Structure

- Modify: `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/tiktok-bravowwhl-run-093de71d-diagnostics.md`
- Create: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md`
- Modify: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`
- Generated on verify if drift exists: `/Users/thomashulihan/Projects/TRR/docs/ai/HANDOFF.md`

### Task 1: Repair the handoff source note

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/tiktok-bravowwhl-run-093de71d-diagnostics.md`
- Generated on verify: `/Users/thomashulihan/Projects/TRR/docs/ai/HANDOFF.md`

- [ ] Add this block immediately after `Last updated: 2026-04-09`:

```md
## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active
  last_updated: 2026-04-10
  current_phase: "post-pivot follow-ups queued"
  next_action: "land handoff repair and bounded html-parser fallback research note"
  detail: self
```
```

- [ ] Add a short `## Post-Pivot Snapshot` section under the existing summary with exactly these facts:
  - posts-path default is `ytdlp`
  - `auto` is a deprecated compatibility alias for `ytdlp`
  - reference `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_PATH_REPRIORITIZATION_PLAN.md`
  - smoke summary: `16` posts via `ytdlp`, `0` via explicit `api`, with structured failure metadata on `@bravotv`

- [ ] Run: `cd /Users/thomashulihan/Projects/TRR && python3 scripts/sync-handoffs.py --check`
Expected: exit `0` with no missing-snapshot error.

- [ ] Run: `cd /Users/thomashulihan/Projects/TRR && bash scripts/handoff-lifecycle.sh post-phase`
Expected: exit `0` and `[handoff-lifecycle] mode=post-phase complete`.

- [ ] Inspect: `git -C /Users/thomashulihan/Projects/TRR diff -- docs/ai/local-status/tiktok-bravowwhl-run-093de71d-diagnostics.md docs/ai/HANDOFF.md`
Expected: only the source note and generated handoff drift, nothing else.

### Task 2: Convert Task 5 into a bounded research spike

**Files:**
- Create: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md`

- [ ] Create the file with this fixed structure and date `2026-04-10`:
  - title
  - `Date`
  - `Time Budget: 2 hours hard cap`
  - `Inputs`
  - `Selector Set Under Test`
  - `Procedure`
  - `Pass Criterion`
  - `Fail Criterion`
  - `Findings`
  - `Go/No-Go Outcome (2026-04-10)`

- [ ] Use the existing repo codepath only. From `/Users/thomashulihan/Projects/TRR/TRR-Backend`, run one anonymous and one authenticated capture with a one-off Python snippet that:
  - imports `TikTokScraper` from `trr_backend.socials.tiktok`
  - imports `_load_tiktok_cookies` from `trr_backend.repositories.social_season_analytics`
  - calls `scraper._fetch_profile_html("bravotv", 0.0)` and `scraper._extract_posts_from_html_data(data or {}, "bravotv")`
  - writes raw capture summaries to `/tmp/tiktok-html-parser-drift-20260410/{anonymous,authenticated}.json`

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python - <<'PY'
import json; from pathlib import Path
from trr_backend.socials.tiktok import TikTokScraper
from trr_backend.repositories.social_season_analytics import _load_tiktok_cookies
base = Path("/tmp/tiktok-html-parser-drift-20260410"); base.mkdir(parents=True, exist_ok=True)
for label, cookies in {"anonymous": {}, "authenticated": _load_tiktok_cookies()}.items():
    s = TikTokScraper(cookies=cookies); data = s._fetch_profile_html("bravotv", 0.0)
    items, sec_uid = s._extract_posts_from_html_data(data or {}, "bravotv") if data else ([], None)
    summary = {"posts": len(items), "sec_uid": bool(sec_uid), "sample": items[:5]}
    (base / f"{label}.json").write_text(json.dumps({"summary": summary, "html_data": data}, indent=2, default=str))
    print(label, summary["posts"], summary["sec_uid"])
PY
```

- [ ] In `Selector Set Under Test`, explicitly diff the live captures against these selector families from `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py:717`:
  - `__DEFAULT_SCOPE__.webapp.user-detail.userInfo.itemList`
  - `ItemModule`
  - `UserModule.users.<username>.secUid`

- [ ] In `Findings`, record whether both captures produce at least `5` posts with populated `aweme_id`, `create_time`, and `statistics.play_count` / equivalent nested play-count field.

- [ ] Finish `Go/No-Go Outcome (2026-04-10)` with one paragraph only:
  - `GO` if both captures meet the pass criterion.
  - `NO-GO` if either capture returns fewer than `5` posts or misses required fields, and explicitly state “not viable as fallback”.

### Task 3: Park Task 6 on the resilience board

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

- [ ] Insert `## Deferred` between `## Execution Order` and `## Active Shortlist`.

- [ ] Add one deferred item titled `Task 6 — TikTok comments via _scrape_browser_intercept` with these exact fields:
  - status: parked until `TIKTOK_HTML_PARSER_DRIFT_SPIKE.md` records a go/no-go
  - unpark trigger: revisit in the next planning cycle immediately after Task 5 closes
  - target entrypoint: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py:1616`
  - open questions:
    - storage-state partition reuse vs comments-only partition at `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/account_browser_sessions.py:188`
    - separate browser image need at `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_jobs.py:174`
    - reuse `SOCIAL_TIKTOK_ENABLE_DIRECT_COMMENT_API_EXPERIMENT=1` vs new env gate
  - non-goals: do not revisit request signing (`msToken`, `X-Bogus`, `_signature`)

- [ ] Verify: `rg -n "## Deferred|Task 6 — TikTok comments via _scrape_browser_intercept|Unpark trigger" /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

## Test Plan

1. `cd /Users/thomashulihan/Projects/TRR && python3 scripts/sync-handoffs.py --check`
2. `cd /Users/thomashulihan/Projects/TRR && bash scripts/handoff-lifecycle.sh post-phase`
3. `test -f /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md`
4. `rg -n "Go/No-Go Outcome \(2026-04-10\): (GO|NO-GO)" /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md`
5. `rg -n "Task 6 — TikTok comments via _scrape_browser_intercept" /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

## Assumptions And Defaults

- This TODO is intentionally docs/research only; do not expand it into repo-wide Ruff cleanup or unrelated TikTok transport changes.
- Default handoff snapshot state is `active`; switch to `recent` only if the implementer decides the follow-up lane is fully closed after `post-phase`.
- The workspace-root `.planning/research` directory is the intended durable location for Task 5 and Task 6 tracking.
- If `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_PATH_REPRIORITIZATION_PLAN.md` is still untracked when execution starts, either add it unchanged in the same change or replace the link with a path that will exist after commit; do not leave a committed handoff note pointing only to local untracked state.
- When execution starts outside Plan Mode, save this plan as `/Users/thomashulihan/Projects/TRR/docs/superpowers/plans/2026-04-10-tiktok-path-reprioritization-followups.md`.
