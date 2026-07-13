# Plan 044: Fix the unreachable `runs` fallback in the YouTube view-count parser

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` — unless a reviewer dispatched you and said
> they maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/youtube/scraper.py`
> On any change, compare the "Current state" excerpt to live code first;
> mismatch → STOP. If the SHA does not resolve, compare by hand.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

In `_parse_video_renderer`, the view-count extraction reads
`viewCountText.simpleText` with a **default of `"0"`**, then checks `if not
view_text:` to fall back to the `viewCountText.runs` form. Because the default
`"0"` is truthy, `if not view_text:` is always `False`, so the `runs` fallback is
**dead code** and never executes. YouTube channel-page renderers that express the
view count via `runs` (rather than `simpleText`) are therefore parsed as `0`
views. This is bounded (some rows get corrected later by yt-dlp enrichment) but
non-enriched rows keep a wrong `0`.

## Current state

- `trr_backend/socials/youtube/scraper.py`, `_parse_video_renderer` (lines
  1205–1211):
```python
        # Extract view count
        view_text = renderer.get("viewCountText", {}).get("simpleText", "0")
        if not view_text:
            runs = renderer.get("viewCountText", {}).get("runs", [])
            if isinstance(runs, list):
                view_text = "".join(str(item.get("text", "")) for item in runs if isinstance(item, dict))
        views = self._parse_view_count(view_text)
```
The `.get("simpleText", "0")` default makes `if not view_text:` unreachable.

Convention: ruff py311, line 120, double quotes. `_parse_view_count` already
handles empty/garbage input (returns 0), so an empty `view_text` is safe to pass
through.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                 | Expected on success  |
|--------------|-------------------------------------------------------------------|----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                            | exit 0               |
| Focused test | `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` | all pass         |
| Lint         | `ruff check trr_backend/socials/youtube/scraper.py`               | `All checks passed!` |

## Scope

**In scope**:
- `trr_backend/socials/youtube/scraper.py` — only the view-count block in
  `_parse_video_renderer`.
- `tests/socials/youtube/test_scraper.py`.

**Out of scope**:
- `_parse_view_count` itself (it already parses "1.2K"/"3,456"/empty correctly).
- Any other renderer field or method.

## Git workflow

- Branch: `advisor/044-youtube-view-count-runs-fallback`
- One commit; message e.g. `parse youtube runs-form view counts instead of zeroing them`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Make the empty check reachable

Change the default so an absent `simpleText` yields an empty string, letting the
`runs` fallback run:
```python
        view_count_text = renderer.get("viewCountText", {})
        view_text = view_count_text.get("simpleText") or ""
        if not view_text:
            runs = view_count_text.get("runs", [])
            if isinstance(runs, list):
                view_text = "".join(str(item.get("text", "")) for item in runs if isinstance(item, dict))
        views = self._parse_view_count(view_text)
```
(Reuse a local `view_count_text` so the dict is fetched once. Keep the `runs`
join logic identical.)

**Verify**: `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` → all pass.

## Test plan

Add to `tests/socials/youtube/test_scraper.py` (model after the existing
`_parse_video_renderer` tests). Cover:
- **runs-form view count parsed**: a renderer whose `viewCountText` has only
  `{"runs": [{"text": "1,234"}, {"text": " views"}]}` (no `simpleText`) →
  parsed views == 1234 (not 0).
- **simpleText still works**: a renderer with
  `viewCountText={"simpleText": "5,678 views"}` → views == 5678 (regression guard).

Verification: `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` → all pass, with the new cases.

## Done criteria

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` passes, with the new cases
- [ ] `ruff check trr_backend/socials/youtube/scraper.py` prints `All checks passed!`
- [ ] `grep -n 'get("simpleText", "0")' trr_backend/socials/youtube/scraper.py` returns no match (the truthy default is gone)
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report if:
- The "Current state" excerpt does not match live code (drift).
- `_parse_view_count` does NOT tolerate an empty string (it should return 0) —
  if it raises on `""`, guard with `view_text or "0"` at the call and report.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- If YouTube changes the `runs` shape for view counts, this block and the
  comment-count/like-count parsers (which may share the pattern) should be
  updated together — grep the file for other `.get("simpleText", "0")` defaults
  that hide the same dead-fallback bug and flag them for a follow-up.
