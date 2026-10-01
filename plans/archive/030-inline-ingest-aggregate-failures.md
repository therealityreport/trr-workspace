# Plan 030: Stop inline multi-platform ingest from swallowing all-but-first platform failure

> **Executor instructions**: Follow step by step. Run every verification command
> before moving on. If a "STOP conditions" item occurs, stop and report. Update
> the `plans/README.md` status row when done unless a reviewer maintains it.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/inline_ingest.py`
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

`run_inline_season_ingest_execution` fans a multi-platform ingest run out over a
thread pool, then collects results with `for future in futures: future.result()`.
That iterates the submitted futures **in submit order**: the first `.result()`
that raises aborts the loop, and the remaining platforms' futures — which already
ran — never have their exceptions retrieved before the `with ThreadPoolExecutor`
block exits. So if platforms A and B both fail, only A's exception surfaces; B's
failure is silently lost (no log, no re-raise). The operator/run error surface
then reflects only the first failing lane and hides the others, which matters
because this path drives real season ingest across all six platforms.

## Current state

`trr_backend/socials/inline_ingest.py` — the whole module (79 lines). The two
affected blocks:

```python
    if normalized_mode == "comments_only":
        max_workers = min(max(1, int(comments_workers_cap or 1)), max(1, len(target_platforms)))
        with thread_pool_executor_factory(max_workers=max_workers) as pool:
            futures = [
                pool.submit(execute_run, run_id, worker_id=f"{worker_prefix}:comments:{platform}",
                            stage="comments", platform=platform)
                for platform in target_platforms
            ]
            for future in futures:
                future.result()          # <-- first raise aborts; others swallowed
        return

    if len(target_platforms) > 1:
        with thread_pool_executor_factory(max_workers=len(target_platforms)) as pool:
            futures = [
                pool.submit(execute_run, run_id, worker_id=f"{worker_prefix}:{platform}", platform=platform)
                for platform in target_platforms
            ]
            for future in futures:
                future.result()          # <-- same bug
        return
```

There is no dedicated test file for this module today (it is only imported
indirectly via `tests/api/routers/test_socials_season_analytics.py`). Domain
note (from `TRR-Backend/CONTEXT.md`): the pipeline follows "Partial Success with
Retry Queue" — valid data is saved immediately and failures are recorded
explicitly. Losing a platform's failure silently contradicts that contract.

Repo conventions: ruff py311, line 120, double quotes. Standard-library
`concurrent.futures` is already the executor abstraction (the factory yields a
`ThreadPoolExecutor`).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Import gate | `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.inline_ingest"` | exit 0 |
| Focused tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_inline_ingest.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/socials/inline_ingest.py tests/socials/test_inline_ingest.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/trr_backend/socials/inline_ingest.py` — the two collection loops.
- `TRR-Backend/tests/socials/test_inline_ingest.py` (create).

**Out of scope**:
- `execute_run` and the callers that pass it in (signature unchanged).
- The single-platform path (line 74) — it already calls `execute_run` directly
  and raises normally.
- Adding a logger dependency is allowed only if the module already has one; it
  does not. Prefer aggregating into the raised error (see Step 1) rather than
  introducing logging config here.

## Steps

### Step 1: Wait for all futures, then raise an aggregated error

Add a small helper in the module that drains all futures, collects every
exception, and raises once if any failed. Use
`concurrent.futures.wait(futures)` (already the module's executor family) and
inspect `future.exception()`:

```python
from concurrent.futures import Future, wait


def _raise_first_with_all_failures(futures: list[Future]) -> None:
    wait(futures)
    failures = [(idx, f.exception()) for idx, f in enumerate(futures) if f.exception() is not None]
    if not failures:
        return
    # Preserve the first exception as the cause; summarize the rest so no lane is
    # silently swallowed.
    summary = "; ".join(f"future[{idx}]: {type(exc).__name__}: {exc}" for idx, exc in failures)
    first_exc = failures[0][1]
    raise RuntimeError(f"inline ingest had {len(failures)} platform failure(s): {summary}") from first_exc
```

(Adjust import placement to the top of the file with the existing imports.)

Then replace **both** `for future in futures: future.result()` loops with:

```python
            _raise_first_with_all_failures(futures)
```

This still raises on failure (callers that expect an exception keep working), but
every failing lane is now named in the message and none is swallowed.

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.inline_ingest"` → exit 0.

### Step 2: Test both the happy path and the multi-failure path

Create `tests/socials/test_inline_ingest.py`. Use a fake `execute_run` and a real
`concurrent.futures.ThreadPoolExecutor` as the `thread_pool_executor_factory`.
Cover:
1. **All platforms succeed** → `run_inline_season_ingest_execution` returns
   without raising; `execute_run` was called once per platform.
2. **Two platforms raise** → the call raises, and the raised error's message
   mentions **both** failing platforms/futures (proving neither is swallowed).
   Assert every submitted future was awaited (no "exception never retrieved"
   warning — you can assert both fakes ran).
3. **`comments_only` mode** → same two-failure assertion for that branch.

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_inline_ingest.py -q` → all pass.

## Test plan

- New `tests/socials/test_inline_ingest.py`, 3 cases above. Case 2 (both failures
  surfaced) is the mandatory regression.
- Verification: focused test command above → all pass.

## Done criteria

- [ ] `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.inline_ingest"` exits 0
- [ ] `grep -n "future.result()" TRR-Backend/trr_backend/socials/inline_ingest.py` → no matches (both loops replaced)
- [ ] The aggregated-failure helper exists and is used in both multi-platform branches
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_inline_ingest.py -q` passes, including the two-failure case
- [ ] `ruff check ...` exits 0
- [ ] No files outside scope modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- The module's two collection loops do not match the "Current state" excerpt.
- A caller depends on the *specific exception type* propagated from `.result()`
  (grep callers of `run_inline_season_ingest_execution`); if so, preserve that
  type instead of wrapping in `RuntimeError` and note it.
- A test fails twice after a reasonable fix attempt.

## Maintenance notes

- This aligns the inline path with the "Partial Success with Retry Queue"
  contract in `CONTEXT.md`: failures are surfaced, not swallowed. If per-platform
  retry-queueing is later added, this aggregation point is where per-lane failure
  metadata should be recorded.
- A reviewer should confirm no caller was relying on the loop's fail-fast
  ordering (it now waits for all lanes before raising — marginally later, but
  every lane already ran concurrently).
