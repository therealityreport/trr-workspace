# Plan 036: Stop one failed Reddit run from crashing the whole Reddit refresh drainer

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/repositories/reddit_refresh.py scripts/workers/reddit_refresh_worker.py tests/repositories/test_reddit_refresh.py`
> If any file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition. If the SHA does not resolve, compare by hand and note it.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

The persistent Reddit refresh worker drains a shared queue of refresh runs for
every tracked community/season. Its loop, `run_reddit_refresh_worker_loop`, calls
`execute_refresh_run` with **no exception handling**, and `execute_refresh_run`
re-raises on any failure that is not an HTTP 403 — *after* it has already marked
the run `failed` and released the claim. So a routine 404 (renamed/nonexistent
subreddit), a 429 that exhausts retries (Reddit is strict), a brief 5xx outage,
or any transient DB hiccup propagates out of the loop, the wrapper process exits
`1`, and the supervisor (`start_remote_job_workers.sh`) has **no respawn loop** —
it launches workers with `"$@" &` and ends on a bare `wait`. The result: one bad
run stops Reddit refreshes for *all* communities until an operator restarts the
whole supervisor. The re-raise buys nothing in loop context because the run is
already persisted as `failed` and the claim already released.

After this plan, a failed run is logged and the loop continues to the next
claimable run; the single-run/Modal path (which still wants the exception) is
unchanged.

## Current state

- `trr_backend/repositories/reddit_refresh.py` — `execute_refresh_run` (the
  per-run executor) and `run_reddit_refresh_worker_loop` (the drainer). Relevant
  excerpts:

`execute_refresh_run`'s failure tail (lines 4272-4345). The 403 branch returns
without raising; every other error marks `failed`, releases the claim, then
re-raises:
```python
    except Exception as exc:  # noqa: BLE001
        if isinstance(exc, RedditRefreshError) and exc.status == 403:
            ...  # marks status="partial", returns get_refresh_run(run_id)
            return get_refresh_run(run_id)
        logger.exception("[reddit_refresh_failed] run_id=%s", run_id)
        _update_run(
            run_id,
            status="failed",
            ...
            set_completed=True,
            claim_token=claim_token,
            release_claim=True,
        )
        raise
```

The loop (lines 4348-4382) — note the bare call on the line that ends the
excerpt, with no try/except:
```python
def run_reddit_refresh_worker_loop(
    *,
    worker_id: str | None = None,
    poll_seconds: float = 2.0,
    once: bool = False,
) -> int:
    normalized_worker = str(worker_id or "").strip() or _default_worker_id()
    safe_poll = max(0.2, float(poll_seconds))
    logger.info("[reddit_refresh_worker_loop_start] ...", ...)

    while True:
        claimed = claim_next_refresh_run(worker_id=normalized_worker)
        if not claimed:
            if once:
                logger.info("[reddit_refresh_worker_no_work] ...")
                return 1
            time.sleep(safe_poll)
            continue

        run_id = str(claimed.get("id") or "").strip()
        logger.info("[reddit_refresh_claimed] ...", ...)
        execute_refresh_run(run_id, preclaimed_run=claimed, worker_id=normalized_worker)
        if once:
            logger.info("[reddit_refresh_worker_once_complete] ...")
            return 0
```

- `scripts/workers/reddit_refresh_worker.py` — the process wrapper. `main()`
  catches a propagated exception and returns `1` (lines 55-69):
```python
    try:
        exit_code = run_reddit_refresh_worker_loop(
            worker_id=worker_id,
            poll_seconds=args.poll_seconds,
            once=bool(args.once),
        )
    except KeyboardInterrupt:
        logger.info("[reddit_refresh_worker_interrupted] worker_id=%s", worker_id)
        return 130
    except Exception:  # noqa: BLE001
        logger.exception("[reddit_refresh_worker_crashed] worker_id=%s", worker_id)
        return 1
```

- `scripts/start_remote_job_workers.sh` — supervisor: `start_worker` runs
  `"$@" &` (line 82), `stop_all` sends `kill -TERM` to each pid, `trap stop_all
  EXIT INT TERM` (line 133), and the script ends on `wait` (line 191). There is
  no per-worker respawn `until`/`while` loop.

Existing tests: `tests/repositories/test_reddit_refresh.py` covers the loop only
for the `once=True` no-work path (returns 1) and the 403→partial branch; there is
no test that the loop survives a non-403 run failure (it cannot today).

Convention: this repo logs structured events with bracketed snake_case tags
(`[reddit_refresh_...]`) via the module `logger`. Match that. ruff py311, line
120, double quotes.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                         | Expected on success   |
|--------------|---------------------------------------------------------------------------|-----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                    | exit 0                |
| Focused test | `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` | all pass              |
| Lint         | `ruff check trr_backend/repositories/reddit_refresh.py scripts/workers/reddit_refresh_worker.py` | `All checks passed!` |

## Scope

**In scope** (the only files you should modify):
- `trr_backend/repositories/reddit_refresh.py` — add loop-level resilience
- `tests/repositories/test_reddit_refresh.py` — add regression tests
- `scripts/start_remote_job_workers.sh` — add a per-worker respawn wrapper
  (Step 3; keep it minimal and behind the existing supervisor semantics)

**Out of scope** (do NOT touch, even though they look related):
- `execute_refresh_run`'s persistence/diagnostics logic — do not change how a
  failed run is recorded; only change whether the loop re-raises.
- `claim_next_refresh_run` and the claim/lease logic — it is sound (`FOR UPDATE
  SKIP LOCKED` + lease/heartbeat). Do not touch.
- The Modal single-run dispatch path in `trr_backend/modal_jobs.py`
  (`run_reddit_refresh` with `retries=0`) — it wants the exception to propagate.
- The racy shared `_HTTP_CLIENT` cooldown/token state (a separate, recorded
  finding). Not in this plan.

## Git workflow

- Branch: `advisor/036-reddit-worker-loop-resilience`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `keep reddit refresh drainer alive after a failed run`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Make the loop survive a failed run, keep the single-run path raising

The cleanest fix is to give `execute_refresh_run` a flag that suppresses the
re-raise when it is being driven by the drainer, and to wrap the call in the loop
defensively regardless.

1. Add a keyword-only parameter to `execute_refresh_run`:
   `raise_on_failure: bool = True`. In the non-403 failure tail, replace the
   final `raise` with:
   ```python
   if raise_on_failure:
       raise
   return get_refresh_run(run_id)
   ```
   Do not change the persistence calls above it — the run is still marked
   `failed`, claim still released. (If the 403 branch already `return`s, leave it
   as-is.)

2. In `run_reddit_refresh_worker_loop`, call it with `raise_on_failure=False`
   and additionally wrap the call so an *unexpected* error (e.g. a failure inside
   `_update_run` itself) still cannot kill the drainer:
   ```python
   try:
       execute_refresh_run(
           run_id,
           preclaimed_run=claimed,
           worker_id=normalized_worker,
           raise_on_failure=False,
       )
   except Exception:  # noqa: BLE001
       logger.exception(
           "[reddit_refresh_worker_run_error] worker_id=%s run_id=%s",
           normalized_worker,
           run_id[:8] if run_id else None,
       )
       # run is already persisted as failed inside execute_refresh_run;
       # keep draining the queue rather than crashing the worker.
   if once:
       logger.info("[reddit_refresh_worker_once_complete] ...", ...)
       return 0
   ```
   Keep the `once=True` early-return semantics intact (a single-run invocation
   still returns after one claim, success or failure).

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` → existing tests still pass (the 403 and once-no-work paths are unchanged).

### Step 2: Add regression tests for loop resilience

In `tests/repositories/test_reddit_refresh.py` (model after the existing loop
tests around the `once=True` case), add:

- A test that patches `claim_next_refresh_run` to return one claimable run then
  `None`, patches `execute_refresh_run` to raise a non-403 error on the first
  call, and asserts the loop does **not** propagate the exception and goes on to
  the next `claim_next_refresh_run` call (use a side-effect list / call counter;
  drive the loop with `once=False` and break it by making the second claim
  return `None` plus patching `time.sleep` to raise a sentinel you catch, or run
  with a bounded fake that flips `once` — mirror whatever loop-termination
  technique the existing loop test already uses).
- A test that `execute_refresh_run(..., raise_on_failure=False)` on a simulated
  non-403 failure still marks the run `failed` and releases the claim (assert the
  `_update_run`/status path is invoked), and returns a run dict instead of
  raising.

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` → all pass, including the 2 new tests.

### Step 3: Add a per-worker respawn wrapper in the supervisor

The loop fix stops the common crash, but the supervisor should still restart a
worker that exits for any reason (OOM, an error the loop cannot catch). In
`scripts/start_remote_job_workers.sh`, change `start_worker` so each worker runs
inside a bounded restart loop instead of a single `"$@" &`:

```bash
start_worker() {
  local label="$1"
  shift
  echo "[remote-job-workers] starting ${label}: $*"
  (
    while true; do
      "$@"
      local rc=$?
      # rc 0 with --once, or a clean shutdown, should not respawn-storm.
      echo "[remote-job-workers] ${label} exited rc=${rc}; respawning in ${RESPAWN_DELAY:-5}s"
      sleep "${RESPAWN_DELAY:-5}"
    done
  ) &
  PIDS+=("$!")
}
```

Guard against a respawn storm: if a worker exits `0` (e.g. a `--once` invocation
or a clean disable via the enable flag), break the inner loop instead of
respawning — add `if [[ "$rc" -eq 0 ]]; then break; fi` before the sleep. Keep
`stop_all`/`trap` behavior working: because the subshell is the tracked PID,
`kill -TERM "$pid"` still stops the supervised worker; confirm `stop_all` sends
the signal to the subshell process group if needed.

**STOP and report** if the supervisor already has a respawn mechanism you did
not see (search the file for `until`, `while true`, `restart`, `supervise`), or
if `start_remote_job_workers.sh` is not the script that launches the Reddit
worker in this deployment — in that case, describe what you found and leave the
shell script unchanged (Steps 1-2 are the load-bearing fix; Step 3 is
defense-in-depth).

**Verify**: `bash -n scripts/start_remote_job_workers.sh` → exit 0 (syntax OK).

## Test plan

- New tests in `tests/repositories/test_reddit_refresh.py` (see Step 2):
  loop-survives-non-403-failure and
  execute_refresh_run-does-not-raise-under-flag-but-still-persists-failed.
- Structural pattern: model after the existing `run_reddit_refresh_worker_loop`
  test(s) in that file (the `once=True` no-work / 403 cases).
- Verification: `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` → all pass, ≥2 new tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/repositories/test_reddit_refresh.py -q` passes, with the new tests present
- [ ] `ruff check trr_backend/repositories/reddit_refresh.py scripts/workers/reddit_refresh_worker.py` prints `All checks passed!`
- [ ] `bash -n scripts/start_remote_job_workers.sh` exits 0
- [ ] `grep -n "raise_on_failure" trr_backend/repositories/reddit_refresh.py` shows the new parameter used in both the signature and the loop call
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts do not match live code (drift).
- Removing the re-raise would break the Modal single-run path — verify by
  grepping callers of `execute_refresh_run`; the Modal path must still get the
  exception (that is why the flag defaults to `True`).
- `start_remote_job_workers.sh` is not the launcher for the Reddit worker in
  this deployment (see Step 3 STOP note).
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- If a future change makes `execute_refresh_run` swallow errors internally,
  revisit the loop wrapper — the `raise_on_failure=False` return value must stay
  a real run dict so downstream loop logging is correct.
- A reviewer should confirm the Modal single-run dispatch still propagates
  failures (retries/dead-letter depend on it) and that the respawn loop cannot
  storm (the `rc==0 → break` guard).
- Deferred out of this plan: the shared `_HTTP_CLIENT` adaptive-cooldown/token
  race and the unbounded in-memory row accumulation in exhaustive runs — both
  recorded as separate backlog findings.
