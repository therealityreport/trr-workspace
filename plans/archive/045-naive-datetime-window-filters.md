# Plan 045: Normalize naive datetimes to UTC in the YouTube and Twitter scrape window filters

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` — unless a reviewer dispatched you and said
> they maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/youtube/scraper.py trr_backend/socials/twitter/scraper.py`
> On any change, compare the "Current state" excerpts to live code first;
> mismatch → STOP. If the SHA does not resolve, compare by hand.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

Two scrapers filter a date window by calling `.timestamp()` on datetimes that can
be **naive** (no tzinfo). Python interprets a naive datetime's `.timestamp()` in
the **host's local timezone**, while the content timestamps they compare against
are parsed as UTC. On a non-UTC host, videos/tweets near the window's start/end
boundary are wrongly included or excluded. Production runs on UTC (Modal), so the
impact is bounded to CLI runs and any non-UTC host — but the two code paths
disagree by design, and each module already has the correct UTC-normalizing
pattern elsewhere, so this is drift, not a hard design question.

## Current state

**YouTube** — `trr_backend/socials/youtube/scraper.py`, `YouTubeScrapeConfig`
(dataclass at line 81, with a `__post_init__` at line 112). Its window
properties use raw `.timestamp()` on possibly-naive fields (lines 124–133):
```python
    date_start: datetime | None = None   # line 86
    date_end: datetime | None = None     # line 87
    ...
    @property
    def start_timestamp(self) -> float:
        return self.date_start.timestamp() if self.date_start else 0
    @property
    def end_timestamp(self) -> float:
        if self.date_end:
            return self.date_end.replace(hour=23, minute=59, second=59).timestamp()
        return datetime.now(UTC).timestamp()
```
The CLI feeds naive datetimes: `scripts/socials/youtube/scrape.py`
`parse_date` returns `datetime.strptime(date_str, "%Y-%m-%d")` (naive). Video
timestamps are parsed as UTC (e.g. `.replace(tzinfo=UTC)` at scraper.py:1631,
1672). `UTC` is already imported in scraper.py.

**Twitter** — `trr_backend/socials/twitter/scraper.py`, `_scrape_syndication`
(lines 1740–1744) uses raw `.timestamp()`:
```python
            if tweet.created_at > 0:
                if tweet.created_at < config.date_start.timestamp():
                    continue
                if tweet.created_at >= config.date_end.timestamp():
                    continue
```
The module already has the correct helper, used everywhere else
(`_window_bound_timestamp` at line 3160, e.g. `window_start_ts =
self._window_bound_timestamp(config.date_start)` at 3207), which UTC-normalizes
naive datetimes before `.timestamp()`.

Convention: ruff py311, line 120, double quotes. `UTC` is imported in both files.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                                              | Expected on success  |
|--------------|------------------------------------------------------------------------------------------------|----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                                         | exit 0               |
| YT test      | `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q`                           | all pass             |
| TW test      | `.venv/bin/python -m pytest tests/socials/twitter/test_twitter_direct_scrape.py -q`             | all pass             |
| Lint         | `ruff check trr_backend/socials/youtube/scraper.py trr_backend/socials/twitter/scraper.py`     | `All checks passed!` |

## Scope

**In scope**:
- `trr_backend/socials/youtube/scraper.py` — `YouTubeScrapeConfig.__post_init__`
  (coerce naive dates to UTC).
- `trr_backend/socials/twitter/scraper.py` — the `_scrape_syndication` window
  comparison only (use the existing `_window_bound_timestamp`).
- `tests/socials/youtube/test_scraper.py` and
  `tests/socials/twitter/test_twitter_direct_scrape.py`.

**Out of scope**:
- `_window_bound_timestamp` and `_clamp_tweets_to_window` (already correct — reuse,
  don't change).
- The CLI `parse_date` in `scripts/socials/youtube/scrape.py` — fix at the config
  boundary (`__post_init__`) so every caller benefits, not just the CLI.
- Any other window/date logic.

## Git workflow

- Branch: `advisor/045-naive-datetime-window-filters`
- One commit; message e.g. `normalize naive scrape-window datetimes to UTC (youtube + twitter)`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Coerce naive dates to UTC in `YouTubeScrapeConfig.__post_init__`

In `__post_init__`, after the existing logic, normalize both fields so a naive
datetime is treated as UTC (matching how video timestamps are parsed):
```python
        if self.date_start is not None and self.date_start.tzinfo is None:
            self.date_start = self.date_start.replace(tzinfo=UTC)
        if self.date_end is not None and self.date_end.tzinfo is None:
            self.date_end = self.date_end.replace(tzinfo=UTC)
```
The `start_timestamp`/`end_timestamp` properties then compute UTC-correct epochs
without further change (`.replace(hour=23,...)` preserves the now-UTC tzinfo).

**Verify**: `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` → all pass.

### Step 2: Use the UTC helper in Twitter `_scrape_syndication`

Replace the raw `.timestamp()` comparisons with the existing helper:
```python
            if tweet.created_at > 0:
                if tweet.created_at < self._window_bound_timestamp(config.date_start):
                    continue
                if tweet.created_at >= self._window_bound_timestamp(config.date_end):
                    continue
```
Confirm `_window_bound_timestamp` is a method reachable as `self.` in this scope
(it is — line 3160, same class). Do not change its implementation.

**Verify**: `.venv/bin/python -m pytest tests/socials/twitter/test_twitter_direct_scrape.py -q` → all pass.

## Test plan

- **YouTube** (`tests/socials/youtube/test_scraper.py`, model after existing
  config tests): construct a `YouTubeScrapeConfig` with a **naive** `date_start`
  and assert `config.date_start.tzinfo is UTC` after construction, and that
  `start_timestamp` equals the UTC epoch of that date (not the local-time epoch).
- **Twitter** (`tests/socials/twitter/test_twitter_direct_scrape.py`, model after
  existing syndication/window tests): drive `_scrape_syndication` (or its window
  filter) with a boundary-date tweet and a naive-datetime config, and assert the
  include/exclude decision matches the UTC interpretation (equals what
  `_window_bound_timestamp` yields). If `_scrape_syndication` is hard to invoke in
  isolation, assert at the `_window_bound_timestamp` level that the same naive
  input now drives the syndication filter (i.e. the call site uses the helper).

Verification: both focused test commands pass, with the new cases.

## Done criteria

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py tests/socials/twitter/test_twitter_direct_scrape.py -q` passes, with the new cases
- [ ] `ruff check trr_backend/socials/youtube/scraper.py trr_backend/socials/twitter/scraper.py` prints `All checks passed!`
- [ ] `grep -n "config.date_start.timestamp()\|config.date_end.timestamp()" trr_backend/socials/twitter/scraper.py` returns no match in `_scrape_syndication`
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report if:
- The "Current state" excerpts do not match live code (drift).
- `YouTubeScrapeConfig` has no `__post_init__` at the live head (it should, line
  112) — if the dataclass shape differs, report rather than restructuring it.
- Coercing `date_end` to UTC changes an existing test that assumed local-time
  boundaries — that test encodes the bug; report it rather than special-casing.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should confirm nothing downstream depends on `date_start`/`date_end`
  staying naive (grep for `.tzinfo`, `.replace(tzinfo`).
- The durable fix for the class is to make `parse_date` return tz-aware UTC at the
  CLI boundary too; this plan fixes it at the config boundary so all callers
  (CLI + programmatic) are covered.
