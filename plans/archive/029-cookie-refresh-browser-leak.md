# Plan 029: Close the browser on the error path in `open_cookie_refresh_context`

> **Executor instructions**: Follow step by step. Run every verification command
> before moving on. If a "STOP conditions" item occurs, stop and report. Update
> the `plans/README.md` status row when done unless a reviewer maintains it.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/browser_cookie_refresh.py`
> The nested `TRR-Backend` tree is authoritative and dirty. Confirm the "Current
> state" excerpt before editing. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

`open_cookie_refresh_context` launches a Chromium browser, then creates a browser
context, then wraps both in a `CookieRefreshBrowserContext` whose `.close()` is
what later closes the browser. Between the launch and the wrap there is no
cleanup guard: if `browser.new_context(...)` raises (browser crash, bad context
kwargs), the exception propagates before the wrapper (which owns cleanup) is
constructed, so the launched Chromium process is **leaked** — never closed. On a
Modal worker doing repeated Instagram/social auth refreshes, this leaks browser
processes and handles until the container is recycled, degrading the whole
worker.

## Current state

`trr_backend/socials/browser_cookie_refresh.py`, the non-persistent branch
(around line 415):

```python
    browser = launch_browser(playwright, headless=headless)
    context = browser.new_context(**context_kwargs)
    return CookieRefreshBrowserContext(context=context, browser=browser)
```

The wrapper's cleanup (around line 51):

```python
@dataclass
class CookieRefreshBrowserContext:
    context: Any
    browser: Any | None = None
    ...
    def close(self) -> None:
        if self.browser is not None:
            self.browser.close()
            return
        self.context.close()
```

So `browser.close()` is only reachable once the wrapper is returned. The
`if effective_require_profile:` branch just above (line 410) raises before the
launch and is not affected.

Repo conventions: ruff py311, line 120, double quotes. Test exemplar for this
module: `tests/socials/test_cookie_refresh_flows.py`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Import gate | `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.browser_cookie_refresh"` | exit 0 |
| Focused tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_cookie_refresh_flows.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/socials/browser_cookie_refresh.py tests/socials/test_cookie_refresh_flows.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/trr_backend/socials/browser_cookie_refresh.py` — only the
  non-persistent launch/new_context/wrap sequence.
- `TRR-Backend/tests/socials/test_cookie_refresh_flows.py` (add a test).

**Out of scope**:
- The persistent-context / profile branch above (it has its own return path;
  check whether it has the same gap and note it in your report, but do not change
  it here unless it is the identical launch→new_context→wrap shape — if it is,
  you may apply the same guard and say so).
- `CookieRefreshBrowserContext` and `launch_browser` internals.

## Steps

### Step 1: Guard `new_context` so a failure closes the browser

Replace the three-line sequence with a try/except that closes the browser if
context creation fails:

```python
    browser = launch_browser(playwright, headless=headless)
    try:
        context = browser.new_context(**context_kwargs)
    except Exception:
        browser.close()
        raise
    return CookieRefreshBrowserContext(context=context, browser=browser)
```

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.browser_cookie_refresh"` → exit 0.

### Step 2: Add a regression test

In `tests/socials/test_cookie_refresh_flows.py`, add a test that:
- Fakes `launch_browser` to return a stub browser whose `new_context` raises and
  whose `close()` sets a flag (or is a `unittest.mock.Mock`).
- Calls `open_cookie_refresh_context` in the non-persistent (profile-less) mode
  so it reaches line 415.
- Asserts the raised exception propagates AND the stub browser's `close()` was
  called exactly once.

Match the monkeypatch/stub style already used in that test file.

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_cookie_refresh_flows.py -q` → all pass, including the new test.

## Test plan

- One new test per Step 2 (browser closed on `new_context` failure).
- Verification: focused test command above → all pass.

## Done criteria

- [ ] `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.browser_cookie_refresh"` exits 0
- [ ] `grep -n "browser.close()" TRR-Backend/trr_backend/socials/browser_cookie_refresh.py` shows the new error-path close
- [ ] New test exists and asserts `close()` is called on the `new_context` failure path
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_cookie_refresh_flows.py -q` exits 0
- [ ] `ruff check ...` exits 0
- [ ] No files outside scope modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- The launch/new_context/wrap sequence does not match the "Current state" excerpt.
- `launch_browser` returns something without a `.close()` method (then the fix
  shape differs — report it).
- The test cannot be made to reach line 415 without a real browser (report; the
  profile-less branch should be reachable with a faked `launch_browser`).

## Maintenance notes

- If the persistent-context branch is later refactored to the same
  launch→new_context→wrap shape, it needs the same guard.
- A reviewer should confirm `browser.close()` is idempotent/safe to call before
  any page is opened (Playwright's is).
