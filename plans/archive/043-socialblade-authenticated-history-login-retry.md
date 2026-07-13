# Plan 043: Stop SocialBlade re-logging-in and false-failing complete 14/30/31-day histories

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` — unless a reviewer dispatched you and said
> they maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/socialblade/scraper.py`
> On any change, compare the "Current state" excerpt to live code before
> proceeding; mismatch → STOP. If the SHA does not resolve, compare by hand.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

`_socialblade_payload_needs_login_retry` decides whether a SocialBlade fetch was
"too short" and must be retried behind an expensive credential login (a visible
Chrome/Playwright login). Its **first** check short-circuits to `True` whenever
the metrics `period` string matches `14|30|31 days`. But `period` is built as
`f"Last {min(limit, len(rendered_rows))} Days"`, so an account whose *real*
SocialBlade history is exactly 14/30/31 days produces `period = "Last 30 Days"`
even from a fully authenticated capture. Result: those accounts pay an
unnecessary login on every refresh, and if the login can't complete (Modal
disallows visible login, or Cloudflare Turnstile blocks it) the otherwise-valid
payload is flipped to a failed/degraded refresh via
`_mark_payload_as_degraded_attempt`, blocking persistence of good growth data.

The fix: don't force a re-login based on the period label when the payload's
`history_source` already indicates an authenticated/complete capture.

## Current state

- `trr_backend/socials/socialblade/scraper.py` — `_socialblade_payload_needs_login_retry`
  (lines 742–777). The offending early-return is the period regex at line 758,
  which runs before the row-count / source logic below it:
```python
def _socialblade_payload_needs_login_retry(payload: dict[str, Any] | None) -> bool:
    if not isinstance(payload, dict):
        return False
    metrics = payload.get("daily_channel_metrics_60day")
    if not isinstance(metrics, dict):
        return True
    try:
        row_count = int(metrics.get("row_count") or 0)
    except (TypeError, ValueError):
        row_count = 0
    ...
    period = str(metrics.get("period") or "").strip()
    if re.search(r"\b(?:14|30|31)\s+days\b", period, re.IGNORECASE):
        return True                      # <-- fires even for a complete authenticated 30-day account
    if chart_points > row_count:
        return False
    ...
    if 0 < row_count < _SOCIALBLADE_AUTHENTICATED_HISTORY_LIMIT:
        return True
    if row_count >= _SOCIALBLADE_AUTHENTICATED_HISTORY_LIMIT:
        return False
    return False
```

- The payload carries `history_source` (set around lines 997–1095), with authenticated
  values `"authenticated_api"`, `"page_trpc_capture"`, `"page_trpc_capture_short"`
  (the same set `service._AUTHENTICATED_HISTORY_SOURCES` uses at
  `trr_backend/socials/socialblade/service.py:27`), plus non-authenticated values
  like `"table_fallback"` and `"unavailable"`.
- `_SOCIALBLADE_AUTHENTICATED_HISTORY_LIMIT = 60` (scraper.py:104).
- The call site (lines 1188–1205): a `True` return triggers
  `_refresh_socialblade_cookies_via_login()` and, on login failure,
  `return _mark_payload_as_degraded_attempt(payload, login_exc)`.

Convention: ruff py311, line 120, double quotes; module-level constants are
UPPER_SNAKE. To avoid an import cycle (`scraper.py` ↔ `service.py`), define the
authenticated-source set locally in `scraper.py` rather than importing it.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                            | Expected on success  |
|--------------|------------------------------------------------------------------------------|----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                       | exit 0               |
| Focused test | `.venv/bin/python -m pytest tests/socials/test_socialblade_scraper.py -q`     | all pass             |
| Lint         | `ruff check trr_backend/socials/socialblade/scraper.py`                       | `All checks passed!` |

## Scope

**In scope**:
- `trr_backend/socials/socialblade/scraper.py` — only `_socialblade_payload_needs_login_retry`
  (and a new module-level constant next to `_SOCIALBLADE_AUTHENTICATED_HISTORY_LIMIT`).
- `tests/socials/test_socialblade_scraper.py`.

**Out of scope**:
- The login/degraded-attempt machinery (`_refresh_socialblade_cookies_via_login`,
  `_mark_payload_as_degraded_attempt`) and the call site — only change the
  decision function.
- `service.py` — do not import from it (cycle risk); mirror the constant locally.
- The `table_fallback`/short-capture path — its `0 < row_count < LIMIT → True`
  behavior must remain so genuinely short unauthenticated captures still retry.

## Git workflow

- Branch: `advisor/043-socialblade-authenticated-history-login-retry`
- One commit; message e.g. `stop re-logging-in on complete authenticated socialblade histories`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add the authenticated-source set

Next to `_SOCIALBLADE_AUTHENTICATED_HISTORY_LIMIT`, add:
```python
_SOCIALBLADE_AUTHENTICATED_HISTORY_SOURCES = frozenset(
    {"authenticated_api", "page_trpc_capture", "page_trpc_capture_short"}
)
```

### Step 2: Gate the period-regex early-return on the source

In `_socialblade_payload_needs_login_retry`, read the source and only apply the
period-regex early-return when the payload is **not** already authenticated:
```python
    history_source = str(payload.get("history_source") or "").strip()
    period = str(metrics.get("period") or "").strip()
    if (
        history_source not in _SOCIALBLADE_AUTHENTICATED_HISTORY_SOURCES
        and re.search(r"\b(?:14|30|31)\s+days\b", period, re.IGNORECASE)
    ):
        return True
```
Everything below (the `chart_points`/`selected_expected_chart_controls`/row-count
logic) stays as-is. An authenticated payload now falls through to that logic,
where a complete capture correctly returns `False`.

**Verify**: `.venv/bin/python -m pytest tests/socials/test_socialblade_scraper.py -q` → all pass.

## Test plan

Add to `tests/socials/test_socialblade_scraper.py` (model after existing tests of
`_socialblade_payload_needs_login_retry`). Cover:
- **Authenticated 30-day is complete**: a payload with
  `history_source="page_trpc_capture"`, `metrics={"row_count": 30, "period": "Last 30 Days"}`
  (and chart consistent) → `_socialblade_payload_needs_login_retry(...)` is `False`.
- **Unauthenticated short capture still retries**: a payload with
  `history_source="table_fallback"`, `row_count=30`, `period="Last 30 Days"` →
  `True` (regression guard — the fix must not disable retry for the genuinely
  short unauthenticated case).
- **Missing metrics still retries**: `metrics` absent → `True` (unchanged).

Verification: `.venv/bin/python -m pytest tests/socials/test_socialblade_scraper.py -q` → all pass, with the new cases.

## Done criteria

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/test_socialblade_scraper.py -q` passes, with the new cases
- [ ] `ruff check trr_backend/socials/socialblade/scraper.py` prints `All checks passed!`
- [ ] `grep -n "_SOCIALBLADE_AUTHENTICATED_HISTORY_SOURCES" trr_backend/socials/socialblade/scraper.py` shows the constant defined and used in the gate
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report if:
- The "Current state" excerpt does not match live code (drift).
- `history_source` is not present on the payload at this point in the flow
  (grep the fetch path) — if authenticated captures don't set it before this
  function runs, report; the gate would be a no-op.
- Importing or mirroring the source set would change another test's expectation
  in a way that suggests the authenticated-source list differs here — report.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Keep `_SOCIALBLADE_AUTHENTICATED_HISTORY_SOURCES` in sync with
  `service._AUTHENTICATED_HISTORY_SOURCES` (they mirror deliberately to avoid an
  import cycle; a divergence is a latent bug — consider a shared constants module
  as a follow-up).
- A reviewer should confirm the genuinely-short unauthenticated path still
  retries (the second test).
