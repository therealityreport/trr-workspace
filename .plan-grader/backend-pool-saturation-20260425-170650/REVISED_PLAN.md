# Backend Pool Saturation Revised Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent TRR-Backend local dev from entering the observed state where all default DB pool slots are checked out, sync route execution stalls, `/health/live` times out, and active social backfill traffic keeps the workspace watchdog from restarting the backend.

**Architecture:** Keep Modal-backed social backfill. Make liveness async and DB-free, replace unbounded detached control-plane threads with a bounded de-duplicating queue that preserves eventual execution for accepted runs, add explicit Modal SDK call timeouts, and verify with focused tests plus live launch checks.

**Tech Stack:** Python 3.11, FastAPI, pytest, psycopg pool wrapper, Modal SDK.

---

## File Structure

```text
TRR-Backend/
  api/main.py
  api/routers/socials.py
  trr_backend/modal_dispatch.py
  trr_backend/repositories/social_season_analytics.py
  trr_backend/socials/control_plane/background_tasks.py
  tests/api/test_health.py
  tests/api/routers/test_socials_season_analytics.py
  tests/repositories/test_social_season_analytics.py
  tests/socials/test_background_tasks.py
  tests/test_modal_dispatch.py
```

## Acceptance Criteria

- [ ] `/health/live` is an async DB-free endpoint and returns within 2 seconds during an active catalog launch.
- [ ] Every API-accepted catalog launch finalizer is either running, queued, completed, or explicitly recoverable; no finalizer is silently dropped because the local cap is busy.
- [ ] Duplicate dispatch/finalizer submissions for the same run are de-duplicated.
- [ ] Modal SDK `from_name`, `hydrate`, and `spawn` calls run behind a bounded executor and timeout.
- [ ] Targeted tests cover liveness, queue semantics, catalog finalizer queuing, dispatch de-duplication, and Modal timeout classification.

## Task 1: Baseline Current Tests

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/api/test_health.py tests/test_modal_dispatch.py -q
PYTHONPATH=. pytest tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches -q
```

Expected: selected tests pass or fail only for existing unrelated environment setup. Record any baseline failure in the final implementation notes.

## Task 2: Make Liveness Async First

- [ ] Edit `TRR-Backend/api/main.py`.

Change `/health/live` from `def health_live()` to:

```python
@app.get("/health/live")
async def health_live() -> dict[str, str]:
    return {"status": "alive", "service": "trr-backend"}
```

- [ ] Edit `TRR-Backend/tests/api/test_health.py`.

Add:

```python
import inspect
```

Add:

```python
def test_health_live_is_async_endpoint() -> None:
    assert inspect.iscoroutinefunction(health_live)
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/api/test_health.py -q
```

- [ ] Commit:

```bash
git add TRR-Backend/api/main.py TRR-Backend/tests/api/test_health.py
git commit -m "Keep backend liveness off sync worker path"
```

## Task 3: Add Bounded De-Duplicating Background Queue

- [ ] Create `TRR-Backend/trr_backend/socials/control_plane/background_tasks.py`.

Implement a module-level queue manager with these public functions:

```python
def submit_named_background_task(
    *,
    group: str,
    key: str,
    thread_name: str,
    target: Callable[..., Any],
    kwargs: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    ...


def background_task_snapshot() -> dict[str, Any]:
    ...
```

Implementation requirements:

- Use one bounded `queue.Queue` per group and one daemon worker thread per group.
- Track `active_keys` and `queued_keys` under a `Lock`.
- Return `{"submitted": True, "state": "queued"}` when a task is accepted.
- Return `{"submitted": False, "state": "duplicate"}` when the same key is already queued or active.
- Return `{"submitted": False, "state": "queue_full"}` when the group queue is full.
- Default env limits:

```python
TRR_CATALOG_FINALIZER_MAX_ACTIVE=1
TRR_CATALOG_FINALIZER_QUEUE_MAXSIZE=25
TRR_SOCIAL_DISPATCH_BACKGROUND_MAX_ACTIVE=1
TRR_SOCIAL_DISPATCH_BACKGROUND_QUEUE_MAXSIZE=25
```

The worker must remove the key from `queued_keys` before running, add it to `active_keys` while running, and always clear it in `finally`.

- [ ] Create `TRR-Backend/tests/socials/test_background_tasks.py`.

Add tests for:

- duplicate key is rejected while queued or running,
- a second distinct key is accepted and eventually runs,
- snapshot exposes group counts without requiring DB access.

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/socials/test_background_tasks.py -q
```

- [ ] Commit:

```bash
git add TRR-Backend/trr_backend/socials/control_plane/background_tasks.py TRR-Backend/tests/socials/test_background_tasks.py
git commit -m "Queue local social control-plane background tasks"
```

## Task 4: Wire Catalog Finalizers Through The Queue

- [ ] Edit `TRR-Backend/api/routers/socials.py`.

Import:

```python
from trr_backend.socials.control_plane.background_tasks import submit_named_background_task
```

Replace the `Thread(...).start()` in `_queue_catalog_backfill_finalize_task(...)` with a `submit_named_background_task(...)` call using:

```python
group = "catalog-finalize"
key = f"{platform}:{account_handle}:{run_id}".lower()
thread_name = f"catalog-finalize:{str(platform or '').strip().lower()}:{str(account_handle or '').strip().lower()[:24]}"
```

If the queue returns `duplicate`, log at info level and do not alter run state. If it returns `queue_full`, log warning and leave the run's existing `launch_task_resolution_pending=true` state intact so existing recovery paths can retry it. Do not mark the run failed just because the local queue is full.

- [ ] Update `tests/api/routers/test_socials_season_analytics.py`.

Patch `submit_named_background_task` in the existing finalizer test so it immediately invokes the target and asserts:

```python
assert submitted[0]["group"] == "catalog-finalize"
assert submitted[0]["key"] == "instagram:bravotv:catalog-run-1"
assert submitted[0]["thread_name"] == "catalog-finalize:instagram:bravotv"
```

Add a new test for `queue_full` that asserts the target is not called, a warning is logged, and the route helper does not mutate the run into a terminal failure.

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest \
  tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches \
  tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_logs_when_queue_full \
  -q
```

- [ ] Commit:

```bash
git add TRR-Backend/api/routers/socials.py TRR-Backend/tests/api/routers/test_socials_season_analytics.py
git commit -m "Queue catalog launch finalizers"
```

## Task 5: Wire Social Dispatch Through The Same Queue

- [ ] Edit `TRR-Backend/trr_backend/repositories/social_season_analytics.py`.

Import:

```python
from trr_backend.socials.control_plane.background_tasks import submit_named_background_task
```

Replace `_dispatch_due_social_jobs_in_background(...)` so it returns the queue submission payload plus `run_id`. Use group `social-dispatch`, key equal to normalized `run_id`, and thread name `dispatch-social-jobs:{run_id[:24]}`.

If the queue returns `duplicate`, log at info level. If it returns `queue_full`, log warning. Existing scheduled/recovery dispatch paths should remain the retry mechanism.

- [ ] Add tests in `tests/repositories/test_social_season_analytics.py` for successful submission and duplicate/queue-full logging.

- [ ] Run the new targeted tests.

- [ ] Commit:

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "Queue social dispatch background runs"
```

## Task 6: Add Modal SDK Timeouts

- [ ] Edit `TRR-Backend/trr_backend/modal_dispatch.py`.

Add a bounded `ThreadPoolExecutor` for Modal SDK calls, helpers `_modal_sdk_timeout_seconds()` and `_run_modal_sdk_call(label, callback)`, and route `resolve_modal_function(...)` and `_spawn_named_modal_function(...)` through that helper.

Add timeout classification:

```python
if "timeout" in normalized:
    return "modal_sdk_timeout"
```

Include `"modal_sdk_timeout"` in the heartbeat blocked-reason set.

- [ ] Add tests in `tests/test_modal_dispatch.py` proving `_run_modal_sdk_call(...)` times out and `resolve_modal_function(...)` reports `modal_sdk_timeout`.

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/test_modal_dispatch.py -q
```

- [ ] Commit:

```bash
git add TRR-Backend/trr_backend/modal_dispatch.py TRR-Backend/tests/test_modal_dispatch.py
git commit -m "Timeout blocking Modal SDK dispatch calls"
```

## Task 7: Add Optional Runtime Snapshot Endpoint

- [ ] Prefer a separate DB-free endpoint instead of changing `/health/live` payload:

```python
@app.get("/health/runtime")
async def health_runtime() -> dict[str, object]:
    return {
        "status": "alive",
        "service": "trr-backend",
        "background_tasks": background_task_snapshot(),
    }
```

- [ ] Add a focused test proving `/health/runtime` does not call DB helpers and includes `background_tasks`.

- [ ] Commit:

```bash
git add TRR-Backend/api/main.py TRR-Backend/tests/api/test_health.py
git commit -m "Expose backend control-plane runtime snapshot"
```

## Task 8: Verification

- [ ] Run targeted regression:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest \
  tests/api/test_health.py \
  tests/socials/test_background_tasks.py \
  tests/test_modal_dispatch.py \
  tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches \
  tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_logs_when_queue_full \
  tests/repositories/test_social_season_analytics.py::test_dispatch_due_social_jobs_background_submits_to_queue \
  tests/repositories/test_social_season_analytics.py::test_dispatch_due_social_jobs_background_reports_duplicate_or_full_queue \
  -q
```

- [ ] Run compile check:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m compileall api/main.py api/routers/socials.py trr_backend/modal_dispatch.py trr_backend/repositories/social_season_analytics.py trr_backend/socials/control_plane/background_tasks.py
```

- [ ] Restart `make dev`, launch two catalog backfills in quick succession from the admin UI, and verify:

```bash
curl --max-time 2 -sS http://127.0.0.1:8000/health/live
curl --max-time 2 -sS http://127.0.0.1:8000/health/runtime | python -m json.tool
```

Expected:

- `/health/live` returns within 2 seconds.
- `/health/runtime` shows bounded queue state.
- No repeated `acquire_failed ... in_use=4 available=0` storm appears during the launch.
- Each accepted catalog run eventually reaches `launch_task_resolution_pending=false`, a terminal failure with explicit error metadata, or a documented pending recovery state.

## Optional Suggestions

These suggestions are not required for approval. Apply them only if they fit the implementation budget after the required tasks are complete.

1. **Add Queue Age To Runtime Snapshot**  
   Type: Small  
   Where: `background_task_snapshot()`  
   Add oldest queued age so operators can distinguish normal launch activity from stuck queue work.

2. **Emit Structured Queue Events**  
   Type: Small  
   Where: `background_tasks.py`, `socials.py`, `social_season_analytics.py`  
   Log stable fields such as `group`, `key`, `state`, and `queue_size` for easier log search.

3. **Add Env Contract Follow-Up**  
   Type: Small  
   Where: `docs/workspace/env-contract.md`  
   Document the new queue and Modal timeout env knobs after implementation so future local-dev debugging has a durable source of truth.

4. **Add Queue Drain Test**  
   Type: Medium  
   Where: `tests/socials/test_background_tasks.py`  
   Add a test that proves accepted queued tasks eventually leave `queued_keys` and run.

5. **Add Worker Exception Counter**  
   Type: Small  
   Where: `background_task_snapshot()`  
   Count worker exceptions so `/health/runtime` can show repeated local control-plane failures without touching the DB.

6. **Add Modal Executor Saturation Snapshot**  
   Type: Medium  
   Where: `modal_dispatch.py`, `/health/runtime`  
   Expose whether Modal SDK worker slots are occupied, since timed-out SDK calls may remain blocked underneath.

7. **Add Recovery Probe Command**  
   Type: Small  
   Where: Task 8 manual verification  
   Add one SQL or API check for pending catalog launches where `launch_task_resolution_pending=true`.

8. **Keep Pool-Size Increase As Explicit Non-Goal**  
   Type: Small  
   Where: plan header or implementation notes  
   State that widening `TRR_DB_POOL_MAXCONN` is not the primary fix, because it can hide local fan-out bugs.

9. **Add Rollback Knob For Queue Use**  
   Type: Medium  
   Where: `background_tasks.py`  
   Add a temporary env bypass that restores plain-thread behavior during emergency local debugging.

10. **Add Thread Name Assertion In Runtime Check**  
    Type: Small  
    Where: Task 8 manual verification  
    Confirm the new worker thread names appear in runtime inspection so future samples remain easy to read.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
