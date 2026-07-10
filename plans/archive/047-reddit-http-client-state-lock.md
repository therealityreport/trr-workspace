# Plan 047: Lock the shared Reddit HTTP client's cooldown and OAuth-token state against concurrent workers

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` — unless a reviewer dispatched you and said
> they maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/repositories/reddit_refresh.py`
> On any change, compare the "Current state" excerpts to live code first;
> mismatch → STOP. If the SHA does not resolve, compare by hand.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug (concurrency)
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

Reddit refresh runs fan requests across several `ThreadPoolExecutor` pools
(listing, comments, backfill, detail/media), but they all share **one
module-level singleton** `_HTTP_CLIENT = RedditHttpClient()`. That singleton holds
mutable state — `_adaptive_cooldown` (the rate-limit backoff), `_oauth_token`, and
`_oauth_expires_at` — that is read-modified-written from every pool thread with
**no synchronization**. Two concrete races:

1. **Cooldown thrash.** One thread doubles `_adaptive_cooldown` on a 429 while
   another decays it by ×0.9 on a success; the decay immediately undoes the
   backoff, so the mechanism meant to protect against Reddit 429s is defeated
   under the exact concurrency it runs in. More 429s follow — and (before plan
   036) a 429 that exhausts retries could crash the whole worker.
2. **Duplicate token fetches.** Near expiry, multiple threads see the stale token
   and each POST a new `access_token`, and interleaved writes to
   `_oauth_token`/`_oauth_expires_at` can leave inconsistent state.

The fix serializes access to this shared state with a lock, without holding the
lock across any network call or sleep (so throughput is unaffected). The larger
token-bucket redesign (one global request budget) is intentionally **out of
scope** here — this plan removes the data race only.

## Current state

- `trr_backend/repositories/reddit_refresh.py` — `import threading` already
  present (line 11). `class RedditHttpClient:` at line 1003; the module singleton
  `_HTTP_CLIENT = RedditHttpClient()` at line 1150.
- `__init__` initializes the shared state (lines 1030–1035):
```python
        self._oauth_token: str | None = None
        self._oauth_expires_at: float = 0.0
        self._adaptive_cooldown: float = self.page_cooldown
        self._adaptive_cooldown_min: float = self.page_cooldown
        self._adaptive_cooldown_max: float = max(0.5, self.page_cooldown * 10)
```
- `_get_oauth_token` (lines 1051–1076) reads the cached token and writes the new
  one, unlocked:
```python
    def _get_oauth_token(self) -> str | None:
        if not self.client_id or not self.client_secret:
            return None
        now = time.time()
        if self._oauth_token and now < (self._oauth_expires_at - 30):
            return self._oauth_token
        try:
            response = self.session.post(... "access_token" ...)   # network — must NOT hold a lock
            ...
            self._oauth_token = token
            self._oauth_expires_at = time.time() + max(60.0, expires_in)
            return token
```
- `get_json` mutates `_adaptive_cooldown` in two places (lines 1098–1101 on 429,
  and 1128–1133 on success):
```python
                    if response.status_code == 429:
                        self._adaptive_cooldown = min(self._adaptive_cooldown_max, self._adaptive_cooldown * 2)
                        ...
                    ...
                    if self._adaptive_cooldown > 0:
                        time.sleep(self._adaptive_cooldown)          # sleep — must NOT hold a lock
                    self._adaptive_cooldown = max(self._adaptive_cooldown_min, self._adaptive_cooldown * 0.9)
```

Convention: ruff py311, line 120, double quotes. `threading` is imported. Keep the
lock **fine-grained**: guard only the state read/modify/write, never a network
call or `time.sleep`.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                        | Expected on success  |
|--------------|--------------------------------------------------------------------------|----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                   | exit 0               |
| Focused test | `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` | all pass             |
| Lint         | `ruff check trr_backend/repositories/reddit_refresh.py`                  | `All checks passed!` |

## Scope

**In scope**:
- `trr_backend/repositories/reddit_refresh.py` — `RedditHttpClient.__init__`,
  `_get_oauth_token`, and the two `_adaptive_cooldown` mutation sites in `get_json`.
- `tests/repositories/test_reddit_refresh.py`.

**Out of scope**:
- Any token-bucket / global-rate-limiter redesign, per-pool client instances, or
  changes to how pools are created — those are a separate (recorded) perf effort.
- `get_json`'s retry/backoff control flow, error raising, and base-URL fallback —
  leave the logic; only wrap the shared-state access.
- The duplicated comment-fetch retry path (`_fetch_post_comments_tree`) — a
  separate recorded finding; do not touch it here.

## Git workflow

- Branch: `advisor/047-reddit-http-client-state-lock`
- One commit; message e.g. `serialize reddit http client cooldown/token state with a lock`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add a state lock

In `RedditHttpClient.__init__`, add next to the state fields:
```python
        self._state_lock = threading.Lock()
```

### Step 2: Guard the OAuth token cache read + write

In `_get_oauth_token`, read the cached token under the lock, do the network POST
**outside** the lock, then write the new token under the lock:
```python
    def _get_oauth_token(self) -> str | None:
        if not self.client_id or not self.client_secret:
            return None
        now = time.time()
        with self._state_lock:
            if self._oauth_token and now < (self._oauth_expires_at - 30):
                return self._oauth_token
        try:
            response = self.session.post(...)          # unchanged, NOT under the lock
            ...
            if not token:
                return None
            with self._state_lock:
                self._oauth_token = token
                self._oauth_expires_at = time.time() + max(60.0, expires_in)
            return token
        except Exception as exc:  # noqa: BLE001
            ...
```
(A rare duplicate concurrent POST is acceptable and harmless — the last writer
wins; do not add double-checked complexity.)

### Step 3: Guard the cooldown mutations; never sleep under the lock

At the 429 site, wrap the read-modify-write:
```python
                    if response.status_code == 429:
                        with self._state_lock:
                            self._adaptive_cooldown = min(self._adaptive_cooldown_max, self._adaptive_cooldown * 2)
                        ...
```
At the success site, read the current cooldown into a local under the lock, sleep
outside the lock, then apply the decay under the lock:
```python
                    with self._state_lock:
                        current_cooldown = self._adaptive_cooldown
                    if current_cooldown > 0:
                        time.sleep(current_cooldown)
                    with self._state_lock:
                        self._adaptive_cooldown = max(self._adaptive_cooldown_min, self._adaptive_cooldown * 0.9)
```

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` → all pass; `ruff check trr_backend/repositories/reddit_refresh.py` → `All checks passed!`.

## Test plan

Add to `tests/repositories/test_reddit_refresh.py` (model after existing
`RedditHttpClient`/`_HTTP_CLIENT` tests). Cover:
- **Token cache preserved**: with a fake `session.post` returning a token, call
  `_get_oauth_token()` twice and assert `session.post` is called **once** (the
  second call returns the cached token without a network hit) — proves the lock
  didn't break the fast path.
- **Concurrency smoke (no crash, bounded value)**: build a `RedditHttpClient`,
  then run ~20 threads that each call a small helper hammering the cooldown
  mutation (e.g. directly invoke the 429-branch mutation and the decay mutation in
  a loop, or drive `get_json` with a stubbed 429/200 `session`), join them, and
  assert no exception was raised and `_adaptive_cooldown` stays within
  `[_adaptive_cooldown_min, _adaptive_cooldown_max]`. Use `threading.Thread`; keep
  iteration counts small so the test is fast and deterministic-ish.

Verification: `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` → all pass, with the new tests.

## Done criteria

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` passes, with the new tests
- [ ] `ruff check trr_backend/repositories/reddit_refresh.py` prints `All checks passed!`
- [ ] `grep -n "_state_lock" trr_backend/repositories/reddit_refresh.py` shows the lock defined and used at the token + both cooldown sites
- [ ] No `time.sleep` or `self.session.` call occurs inside a `with self._state_lock:` block (read the diff to confirm)
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report if:
- The "Current state" excerpts do not match live code (drift).
- A cooldown or token mutation exists at a site not listed here (grep
  `_adaptive_cooldown =` and `_oauth_token =`) — guard it too, or report if its
  context makes locking unclear.
- Holding the lock would have to span a network call or sleep to preserve
  behavior — it must not; if you can't avoid it, STOP and report.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should verify no lock is held across I/O (deadlock/throughput risk)
  and that the fast-path token cache still avoids a network call.
- Deferred (recorded separately): a shared token-bucket so N pool threads respect
  one global Reddit request budget, and unifying the second retry path in
  `_fetch_post_comments_tree` onto `get_json`. This plan only removes the data
  race on the existing state.
- Pairs with the landed Reddit worker-loop resilience change (a 429 that exhausts
  retries no longer crashes the drainer); reducing 429 thrash here compounds that.
