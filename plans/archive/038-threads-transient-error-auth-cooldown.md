# Plan 038: Stop the Threads posts lane from turning transient transport errors into escalating auth cooldowns

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/threads/posts_scrapling/fetcher.py trr_backend/socials/threads/posts_scrapling/job_runner.py`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch, treat
> it as a STOP condition. If the SHA does not resolve, compare by hand and note it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

In the Threads posts-scrapling lane, when the legacy scraper raises *any*
exception (a connection reset, DNS blip, proxy error, or an anonymous-fallback
failure), the fetcher reports the result with
`auth_failed=bool(self._raw_cookies)`. Because the Threads session is always
resolved with cookies, `auth_failed` is effectively always `True` on that error
path. The job runner then checks the `auth_failed` branch **before** the
`fetch_failed`/retryable branch, and calls
`auth_cooldown.record_auth_block("threads", account_handle, …)`, which UPSERTs an
**escalating** cross-container cooldown (`consecutive_auth_failures` +1, next
`cooldown_until = now() + backoff(count)`). A subsequent
`_raise_if_threads_auth_cooldown_active` then locks the account out of the posts
lane for that growing window (seconds → up to an hour), and the counter compounds
across retries. Net effect: a transient network hiccup is converted into a
self-inflicted, escalating outage for that Threads handle, and the retry that
*should* have just re-fetched instead trips a cooldown.

After this plan, only a genuine auth signal records an auth block; transient
transport errors flow through the existing `fetch_failed`/retryable legacy-retry
path and simply retry.

## Current state

- `trr_backend/socials/threads/posts_scrapling/fetcher.py` — the legacy-scraper
  fallback path (lines 291-311). On any exception it flags `auth_failed` from the
  mere presence of cookies:

```python
        try:
            posts = await asyncio.to_thread(_scrape)
        except Exception:  # noqa: BLE001
            self._last_transport = "legacy_threads_scraper"
            self._fallback_chain = self._fallback_prefix() + ["legacy_threads_scraper"]
            self._last_stop_reason = str(reason or "legacy_threads_scraper_failed")
            self._last_retryable = True
            self._last_complete = False
            logger.warning(
                "threads_posts_legacy_scraper_failed account=%s reason=%s",
                config.normalized_username,
                reason,
                exc_info=True,
            )
            return ThreadsPostsFetchResult(
                posts=[],
                fetch_failed=True,
                auth_failed=bool(self._raw_cookies),   # <-- the bug
                retryable=True,
                fetch_reason=str(reason or "legacy_threads_scraper_failed"),
            )
```

- `trr_backend/socials/threads/posts_scrapling/job_runner.py` — the branch order
  (lines 474-494). The `auth_failed` branch fires the escalating cooldown and
  raises **before** the `fetch_failed` retry branch:

```python
            if result.auth_failed and not result.posts:
                error_code = str(result.fetch_reason or "threads_posts_auth_failed").strip()
                cooldown = auth_cooldown.record_auth_block("threads", account_handle, error_code)
                cooldown_metadata = _auth_cooldown_metadata(cooldown)
                raise ThreadsPostsScraplingRuntimeError(
                    f"Threads posts auth failed for @{account_handle}.",
                    error_code=error_code,
                    retryable=True,
                    runtime_metadata={...},
                )

            if result.fetch_failed and not result.posts:
                legacy_scraper = ThreadsScraper(
                    cookies=session.raw_cookies,
                    proxy_url=proxy_config.api_proxy_url if proxy_config else None,
                )
```

- `trr_backend/socials/instagram/auth_cooldown.py` — `record_auth_block` (lines
  166+) UPSERTs an escalating cooldown: it increments
  `consecutive_auth_failures` and sets `cooldown_until = now() +
  cooldown_backoff_seconds(new_count)`. This is shared by Instagram and Threads.

Convention: results are typed `ThreadsPostsFetchResult` dataclasses; the fetcher
sets `self._last_*` runtime metadata. Match the existing field/flag usage. ruff
py311, line 120, double quotes.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                                                | Expected on success   |
|--------------|--------------------------------------------------------------------------------------------------|-----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                                           | exit 0                |
| Focused test | `.venv/bin/python -m pytest tests/socials/threads/posts_scrapling/test_fetcher.py tests/socials/threads/posts_scrapling/test_job_runner.py -q` | all pass |
| Lint         | `ruff check trr_backend/socials/threads/posts_scrapling/fetcher.py trr_backend/socials/threads/posts_scrapling/job_runner.py` | `All checks passed!` |

## Scope

**In scope** (the only files you should modify):
- `trr_backend/socials/threads/posts_scrapling/fetcher.py`
- `trr_backend/socials/threads/posts_scrapling/job_runner.py` (only if the
  branch-order fix is needed — see Step 2)
- The matching tests: `tests/socials/threads/posts_scrapling/test_fetcher.py`
  and `tests/socials/threads/posts_scrapling/test_job_runner.py`

**Out of scope** (do NOT touch):
- `trr_backend/socials/instagram/auth_cooldown.py` — the cooldown mechanism is
  correct; the bug is *what triggers it*, not the escalation. Do not change it.
- The Instagram posts lane's own `auth_failed` handling — Instagram has its own
  auth-signal detection; do not touch it.
- The Decodo proxy gating in the Threads lane (recorded/planned separately).

## Git workflow

- Branch: `advisor/038-threads-transient-error-auth-cooldown`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `stop classifying transient threads transport errors as auth failures`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Only flag `auth_failed` on a real auth signal in the exception path

In `fetcher.py`'s legacy-scraper `except` block, stop deriving `auth_failed` from
`bool(self._raw_cookies)`. A caught exception from `_scrape()` is a transport
failure, not an authentication verdict. Set `auth_failed=False` there and let the
existing `fetch_failed=True, retryable=True` fields drive a retry:

```python
            return ThreadsPostsFetchResult(
                posts=[],
                fetch_failed=True,
                auth_failed=False,
                retryable=True,
                fetch_reason=str(reason or "legacy_threads_scraper_failed"),
            )
```

If the codebase has a helper that inspects an exception/response for an actual
auth signal (search the threads lane for `_looks_auth_failed`, `is_auth`,
`401`, `403`, `login_required`, `checkpoint`), prefer gating `auth_failed` on
that helper applied to the caught exception, rather than a blanket `False`. Only
fall back to `False` if no such signal is available on this path. Do **not**
change the non-exception path (lines 313-319), which reads `stop_reason`/
`retryable` from the scraper's real runtime metadata — that path can legitimately
surface an auth stop reason.

**Verify**: `.venv/bin/python -m pytest tests/socials/threads/posts_scrapling/test_fetcher.py -q` → passes.

### Step 2: Confirm the job runner only cools down on a real auth result (adjust branch order only if needed)

With Step 1, a transient error now returns `auth_failed=False, fetch_failed=True`,
so the job runner's `if result.auth_failed and not result.posts:` branch no
longer fires for transient errors, and control falls through to the
`fetch_failed` legacy-retry branch. Verify this by reading the two branches
(lines 474-494) after Step 1.

Only if you find another path that still sets `auth_failed=True` for a
non-auth reason, make the cooldown branch require a genuine auth error code
(e.g. gate `record_auth_block` on `result.fetch_reason` being an auth-class code,
not any string). Do not reorder the branches unless a concrete case requires it;
prefer fixing the classification at the source (Step 1).

**Verify**: `.venv/bin/python -m pytest tests/socials/threads/posts_scrapling/test_job_runner.py -q` → passes.

## Test plan

- In `tests/socials/threads/posts_scrapling/test_fetcher.py` (model after the
  existing fetcher tests): add a test that patches the legacy scraper's
  `_scrape` to raise a transport-style exception (e.g. `ConnectionError`) with
  cookies present, and asserts the returned `ThreadsPostsFetchResult` has
  `auth_failed is False`, `fetch_failed is True`, `retryable is True`.
- In `tests/socials/threads/posts_scrapling/test_job_runner.py` (model after the
  existing job-runner tests): add a test that drives the runner with a fetch
  result of `auth_failed=False, fetch_failed=True, posts=[]` and asserts
  `auth_cooldown.record_auth_block` is **not** called (patch/spy it) and the
  fetch_failed retry branch is taken instead. If the existing tests already spy
  on `record_auth_block`, mirror that technique.
- Keep any existing test that asserts a *genuine* auth failure still records a
  cooldown green (find it first; do not weaken it).

Verification: `.venv/bin/python -m pytest tests/socials/threads/posts_scrapling/test_fetcher.py tests/socials/threads/posts_scrapling/test_job_runner.py -q` → all pass, with the new tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/threads/posts_scrapling/test_fetcher.py tests/socials/threads/posts_scrapling/test_job_runner.py -q` passes, with the new tests
- [ ] `ruff check trr_backend/socials/threads/posts_scrapling/fetcher.py trr_backend/socials/threads/posts_scrapling/job_runner.py` prints `All checks passed!`
- [ ] `grep -n "auth_failed=bool(self._raw_cookies)" trr_backend/socials/threads/posts_scrapling/fetcher.py` returns no match
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts do not match live code (drift).
- There is a legitimate reason the exception path must record an auth block that
  you can identify from the code (e.g. the only exceptions that reach that
  `except` are already auth exceptions) — if so, the fix is wrong; report it.
- A genuine-auth-failure test exists and your change would make it stop recording
  a cooldown — that means your classification is too broad; report it.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should confirm the *real* auth path (HTTP 401/403, checkpoint,
  `login_required`) still records a cooldown — the escalating cooldown is a
  correct anti-abuse mechanism; this plan only stops it firing on transport
  noise.
- If a shared auth-signal classifier is later added for the Threads lane, route
  this path through it so the distinction lives in one place.
- Related (not in this plan): the Threads full-history N+1 per-post view-count
  GraphQL fetch — a separate recorded performance finding.
