# Backend Pool Saturation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop TRR-Backend from entering the observed state where all four default DB pool slots are checked out (`in_use=4 available=0`), sync route execution stalls, `/health/live` times out, and the workspace watchdog suppresses restarts during active traffic.

**Architecture:** Keep the existing Modal-backed social backfill architecture, but put hard local bounds around detached finalizer and dispatch threads, add explicit Modal SDK call timeouts, and make liveness independent of the sync worker path. The plan does not raise pool limits as the primary fix because the live evidence showed mostly idle Postgres sessions while Python held local pool slots and blocked elsewhere.

**Tech Stack:** Python 3.11, FastAPI, Starlette TestClient, psycopg pool wrapper in `trr_backend.db.pg`, Modal SDK, pytest.

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
  tests/socials/test_background_tasks.py
  tests/test_modal_dispatch.py
```

## Baseline Commands

- [ ] From the repo root, confirm the targeted tests are green before editing:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/api/test_health.py tests/test_modal_dispatch.py -q
PYTHONPATH=. pytest tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches -q
```

Expected output:

```text
... passed
```

If an unrelated import or environment failure appears, capture the exact failure and continue with the smallest targeted test set after the first code slice.

## Task 1: Make `/health/live` Async And Sync-Pool Independent

- [ ] Edit `TRR-Backend/api/main.py`.

Change:

```python
@app.get("/health/live")
def health_live() -> dict[str, str]:
    return {"status": "alive", "service": "trr-backend"}
```

to:

```python
@app.get("/health/live")
async def health_live() -> dict[str, str]:
    return {"status": "alive", "service": "trr-backend"}
```

Rationale: the observed `/health/live` timeout while `/docs` and `/openapi.json` still responded means the event loop was alive but sync endpoint execution was blocked. Making the static liveness route async keeps the watchdog signal off the sync worker path.

- [ ] Edit `TRR-Backend/tests/api/test_health.py`.

Add this import:

```python
import inspect
```

Add this test after `test_health_live`:

```python
def test_health_live_is_async_endpoint() -> None:
    assert inspect.iscoroutinefunction(health_live)
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/api/test_health.py -q
```

Expected output:

```text
6 passed
```

- [ ] Commit:

```bash
git add TRR-Backend/api/main.py TRR-Backend/tests/api/test_health.py
git commit -m "Keep backend liveness off sync worker path"
```

## Task 2: Add A Bounded Background Task Gate

- [ ] Create `TRR-Backend/trr_backend/socials/control_plane/background_tasks.py`.

Use this complete module:

```python
"""Bounded background task gates for local control-plane work."""

from __future__ import annotations

import logging
import os
from collections.abc import Callable, Mapping
from threading import Lock, Thread
from typing import Any

logger = logging.getLogger(__name__)

_LOCK = Lock()
_ACTIVE_KEYS_BY_GROUP: dict[str, set[str]] = {}

_GROUP_LIMIT_ENV: dict[str, tuple[str, int]] = {
    "catalog-finalize": ("TRR_CATALOG_FINALIZER_MAX_ACTIVE", 1),
    "social-dispatch": ("TRR_SOCIAL_DISPATCH_BACKGROUND_MAX_ACTIVE", 1),
}


def _env_int(name: str, *, default: int, minimum: int = 1) -> int:
    raw = str(os.getenv(name) or "").strip()
    if not raw:
        return default
    try:
        return max(minimum, int(raw))
    except ValueError:
        logger.warning("[background-task-gate] invalid integer env %s=%r; using %s", name, raw, default)
        return default


def _limit_for_group(group: str) -> int:
    env_name, default = _GROUP_LIMIT_ENV.get(group, (f"TRR_{group.upper().replace('-', '_')}_MAX_ACTIVE", 1))
    return _env_int(env_name, default=default)


def background_task_snapshot() -> dict[str, Any]:
    with _LOCK:
        groups = {
            group: {
                "active_count": len(keys),
                "active_keys": sorted(keys),
                "max_active": _limit_for_group(group),
            }
            for group, keys in sorted(_ACTIVE_KEYS_BY_GROUP.items())
        }
    return {"groups": groups}


def try_start_named_background_task(
    *,
    group: str,
    key: str,
    thread_name: str,
    target: Callable[..., Any],
    kwargs: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    normalized_group = str(group or "").strip() or "default"
    normalized_key = str(key or "").strip()
    if not normalized_key:
        return {"started": False, "reason": "missing_key", "group": normalized_group, "key": normalized_key}

    max_active = _limit_for_group(normalized_group)
    with _LOCK:
        active_keys = _ACTIVE_KEYS_BY_GROUP.setdefault(normalized_group, set())
        if normalized_key in active_keys:
            return {
                "started": False,
                "reason": "already_running",
                "group": normalized_group,
                "key": normalized_key,
                "active_count": len(active_keys),
                "max_active": max_active,
            }
        if len(active_keys) >= max_active:
            return {
                "started": False,
                "reason": "limit_reached",
                "group": normalized_group,
                "key": normalized_key,
                "active_count": len(active_keys),
                "max_active": max_active,
            }
        active_keys.add(normalized_key)

    task_kwargs = dict(kwargs or {})

    def _runner() -> None:
        try:
            target(**task_kwargs)
        except Exception:  # noqa: BLE001
            logger.exception(
                "[background-task-gate] task failed group=%s key=%s",
                normalized_group,
                normalized_key,
            )
        finally:
            with _LOCK:
                active_keys = _ACTIVE_KEYS_BY_GROUP.get(normalized_group)
                if active_keys is not None:
                    active_keys.discard(normalized_key)
                    if not active_keys:
                        _ACTIVE_KEYS_BY_GROUP.pop(normalized_group, None)

    Thread(target=_runner, name=thread_name, daemon=True).start()
    return {
        "started": True,
        "reason": None,
        "group": normalized_group,
        "key": normalized_key,
        "active_count": background_task_snapshot()["groups"].get(normalized_group, {}).get("active_count", 0),
        "max_active": max_active,
    }
```

- [ ] Create `TRR-Backend/tests/socials/test_background_tasks.py`.

Use this complete test file:

```python
"""Tests for bounded local background task gates."""

from __future__ import annotations

from threading import Event

from trr_backend.socials.control_plane import background_tasks


def test_background_task_gate_rejects_duplicate_key_until_task_finishes() -> None:
    started = Event()
    release = Event()

    def _blocked_task() -> None:
        started.set()
        release.wait(timeout=2)

    first = background_tasks.try_start_named_background_task(
        group="social-dispatch",
        key="run-1",
        thread_name="test-dispatch:run-1",
        target=_blocked_task,
    )
    assert first["started"] is True
    assert started.wait(timeout=1)

    duplicate = background_tasks.try_start_named_background_task(
        group="social-dispatch",
        key="run-1",
        thread_name="test-dispatch:run-1-duplicate",
        target=_blocked_task,
    )
    assert duplicate["started"] is False
    assert duplicate["reason"] == "already_running"

    release.set()
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/socials/test_background_tasks.py -q
```

Expected output:

```text
1 passed
```

- [ ] Commit:

```bash
git add TRR-Backend/trr_backend/socials/control_plane/background_tasks.py TRR-Backend/tests/socials/test_background_tasks.py
git commit -m "Bound local social control-plane background tasks"
```

## Task 3: Gate Catalog Finalizer Threads

- [ ] Edit `TRR-Backend/api/routers/socials.py`.

Add this import near the other `trr_backend` imports:

```python
from trr_backend.socials.control_plane.background_tasks import try_start_named_background_task
```

Replace the `Thread(...).start()` block inside `_queue_catalog_backfill_finalize_task` with:

```python
    task_key = f"{str(platform or '').strip().lower()}:{str(account_handle or '').strip().lower()}:{str(run_id).strip()}"
    task_name = f"catalog-finalize:{str(platform or '').strip().lower()}:{str(account_handle or '').strip().lower()[:24]}"
    start_result = try_start_named_background_task(
        group="catalog-finalize",
        key=task_key,
        thread_name=task_name,
        target=_finalize_catalog_backfill_launch_task,
        kwargs={
            "platform": platform,
            "account_handle": account_handle,
            "run_id": run_id,
            "source_scope": source_scope,
            "date_start": date_start,
            "date_end": date_end,
            "initiated_by": initiated_by,
            "allow_local_dev_inline_bypass": allow_local_dev_inline_bypass,
            "execution_preference": execution_preference,
            "selected_tasks": selected_tasks,
            "launch_group_id": launch_group_id,
        },
    )
    if not start_result["started"]:
        logger.warning(
            "[catalog-finalize] finalizer deferred platform=%s account=%s run_id=%s reason=%s active=%s max=%s",
            platform,
            account_handle,
            run_id,
            start_result.get("reason"),
            start_result.get("active_count"),
            start_result.get("max_active"),
        )
```

Keep `_ = background_tasks`; Starlette background tasks should remain unused here.

- [ ] Edit `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`.

In `test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches`, remove the fake `Thread` class and the `monkeypatch.setattr(socials_router, "Thread", _FakeThread)` call. Replace them with:

```python
    started_tasks: list[dict[str, Any]] = []

    def _fake_try_start_named_background_task(**kwargs: Any) -> dict[str, Any]:
        started_tasks.append(kwargs)
        kwargs["target"](**dict(kwargs["kwargs"]))
        return {
            "started": True,
            "reason": None,
            "group": kwargs["group"],
            "key": kwargs["key"],
            "active_count": 1,
            "max_active": 1,
        }
```

Patch the router helper:

```python
    monkeypatch.setattr(socials_router, "try_start_named_background_task", _fake_try_start_named_background_task)
```

Replace the thread assertions with:

```python
    assert len(started_tasks) == 1
    assert started_tasks[0]["group"] == "catalog-finalize"
    assert started_tasks[0]["key"] == "instagram:bravotv:catalog-run-1"
    assert started_tasks[0]["thread_name"] == "catalog-finalize:instagram:bravotv"
```

Add this adjacent test:

```python
def test_queue_catalog_backfill_finalize_task_logs_when_gate_is_busy(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    from api.routers import socials as socials_router

    background_tasks = BackgroundTasks()
    finalized: list[dict[str, Any]] = []

    def _fake_try_start_named_background_task(**_kwargs: Any) -> dict[str, Any]:
        return {
            "started": False,
            "reason": "limit_reached",
            "group": "catalog-finalize",
            "key": "instagram:bravotv:catalog-run-1",
            "active_count": 1,
            "max_active": 1,
        }

    monkeypatch.setattr(
        "trr_backend.repositories.social_season_analytics.finalize_social_account_catalog_backfill_launch",
        lambda **kwargs: finalized.append(kwargs) or {"run_id": kwargs["run_id"], "status": "queued"},
    )
    monkeypatch.setattr(socials_router, "try_start_named_background_task", _fake_try_start_named_background_task)

    with caplog.at_level("WARNING"):
        socials_router._queue_catalog_backfill_finalize_task(
            background_tasks=background_tasks,
            platform="instagram",
            account_handle="bravotv",
            run_id="catalog-run-1",
            source_scope="bravo",
            date_start=None,
            date_end=None,
            initiated_by="admin@example.com",
            allow_local_dev_inline_bypass=False,
            execution_preference="auto",
            selected_tasks=["post_details"],
            launch_group_id="launch-group-1",
        )

    assert background_tasks.tasks == []
    assert finalized == []
    assert "finalizer deferred" in caplog.text
    assert "limit_reached" in caplog.text
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_logs_when_gate_is_busy -q
```

Expected output:

```text
2 passed
```

- [ ] Commit:

```bash
git add TRR-Backend/api/routers/socials.py TRR-Backend/tests/api/routers/test_socials_season_analytics.py
git commit -m "Gate catalog launch finalizer threads"
```

## Task 4: Gate Social Dispatch Background Threads

- [ ] Edit `TRR-Backend/trr_backend/repositories/social_season_analytics.py`.

Add this import near the other `trr_backend.socials` imports:

```python
from trr_backend.socials.control_plane.background_tasks import try_start_named_background_task
```

Replace `_dispatch_due_social_jobs_in_background` with:

```python
def _dispatch_due_social_jobs_in_background(*, run_id: str) -> dict[str, Any]:
    normalized_run_id = str(run_id or "").strip()
    if not normalized_run_id:
        return {"started": False, "reason": "missing_run_id", "run_id": normalized_run_id}

    def _runner() -> None:
        dispatch_due_social_jobs(run_id=normalized_run_id)

    start_result = try_start_named_background_task(
        group="social-dispatch",
        key=normalized_run_id,
        thread_name=f"dispatch-social-jobs:{normalized_run_id[:24]}",
        target=_runner,
    )
    if not start_result["started"]:
        logger.warning(
            "[modal-dispatch] background dispatch deferred run_id=%s reason=%s active=%s max=%s",
            normalized_run_id,
            start_result.get("reason"),
            start_result.get("active_count"),
            start_result.get("max_active"),
        )
    return {**start_result, "run_id": normalized_run_id}
```

Rationale: the limiter module already catches and logs exceptions from target functions, so this wrapper does not need a nested `try/except`.

- [ ] Add this test to `TRR-Backend/tests/repositories/test_social_season_analytics.py` near existing dispatch tests:

```python
def test_dispatch_due_social_jobs_background_uses_singleflight_gate(monkeypatch: pytest.MonkeyPatch) -> None:
    started: list[dict[str, Any]] = []

    def _fake_try_start_named_background_task(**kwargs: Any) -> dict[str, Any]:
        started.append(kwargs)
        return {
            "started": True,
            "reason": None,
            "group": kwargs["group"],
            "key": kwargs["key"],
            "active_count": 1,
            "max_active": 1,
        }

    monkeypatch.setattr(social_repo, "try_start_named_background_task", _fake_try_start_named_background_task)

    result = social_repo._dispatch_due_social_jobs_in_background(run_id="run-1")

    assert result["started"] is True
    assert result["run_id"] == "run-1"
    assert started == [
        {
            "group": "social-dispatch",
            "key": "run-1",
            "thread_name": "dispatch-social-jobs:run-1",
            "target": started[0]["target"],
        }
    ]
```

Add this adjacent test:

```python
def test_dispatch_due_social_jobs_background_reports_busy_gate(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    def _fake_try_start_named_background_task(**kwargs: Any) -> dict[str, Any]:
        return {
            "started": False,
            "reason": "already_running",
            "group": kwargs["group"],
            "key": kwargs["key"],
            "active_count": 1,
            "max_active": 1,
        }

    monkeypatch.setattr(social_repo, "try_start_named_background_task", _fake_try_start_named_background_task)

    with caplog.at_level("WARNING"):
        result = social_repo._dispatch_due_social_jobs_in_background(run_id="run-1")

    assert result["started"] is False
    assert result["reason"] == "already_running"
    assert "background dispatch deferred" in caplog.text
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/repositories/test_social_season_analytics.py::test_dispatch_due_social_jobs_background_uses_singleflight_gate tests/repositories/test_social_season_analytics.py::test_dispatch_due_social_jobs_background_reports_busy_gate -q
```

Expected output:

```text
2 passed
```

- [ ] Commit:

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "Singleflight social dispatch background runs"
```

## Task 5: Add Explicit Modal SDK Call Timeouts

- [ ] Edit `TRR-Backend/trr_backend/modal_dispatch.py`.

Add imports:

```python
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError
```

Add helpers near `_env_flag`:

```python
def _env_int(name: str, *, default: int, minimum: int = 1) -> int:
    raw = str(os.getenv(name) or "").strip()
    if not raw:
        return default
    try:
        return max(minimum, int(raw))
    except ValueError:
        logger.warning("[modal-dispatch] invalid integer env %s=%r; using %s", name, raw, default)
        return default


def _modal_sdk_worker_count() -> int:
    return _env_int("TRR_MODAL_SDK_CALL_WORKERS", default=2)
```

Add this module constant after `_modal_sdk_worker_count`:

```python
_MODAL_SDK_EXECUTOR = ThreadPoolExecutor(
    max_workers=_modal_sdk_worker_count(),
    thread_name_prefix="modal-sdk-call",
)
```

Add these helpers below `_MODAL_SDK_EXECUTOR`:

```python
def _modal_sdk_timeout_seconds() -> float:
    raw = str(os.getenv("TRR_MODAL_SDK_CALL_TIMEOUT_SECONDS") or "15").strip()
    try:
        return max(0.1, float(raw))
    except ValueError:
        logger.warning("[modal-dispatch] invalid TRR_MODAL_SDK_CALL_TIMEOUT_SECONDS=%r; using 15", raw)
        return 15.0


def _run_modal_sdk_call(label: str, callback: Callable[[], Any]) -> Any:
    timeout_seconds = _modal_sdk_timeout_seconds()
    future = _MODAL_SDK_EXECUTOR.submit(callback)
    try:
        return future.result(timeout=timeout_seconds)
    except FutureTimeoutError as exc:
        raise TimeoutError(f"modal_{label}_timeout_after_{timeout_seconds:g}s") from exc
```

In `_classify_modal_resolution_error`, add the timeout case before the final fallback:

```python
    if "timeout" in normalized:
        return "modal_sdk_timeout"
```

In `_spawn_named_modal_function`, add `"modal_sdk_timeout"` to the heartbeat `dispatch_enabled` false set:

```python
                "modal_sdk_timeout",
```

In `resolve_modal_function`, replace direct Modal calls:

```python
        fn = modal.Function.from_name(app_name, normalized_function)
        hydrate = getattr(fn, "hydrate", None)
        if callable(hydrate):
            hydrate()
```

with:

```python
        def _resolve() -> Any:
            fn = modal.Function.from_name(app_name, normalized_function)
            hydrate = getattr(fn, "hydrate", None)
            if callable(hydrate):
                hydrate()
            return fn

        _run_modal_sdk_call("resolve_function", _resolve)
```

In `_spawn_named_modal_function`, replace:

```python
        fn = modal.Function.from_name(app_name, normalized_function)
        call = fn.spawn(**kwargs)
```

with:

```python
        def _spawn() -> Any:
            fn = modal.Function.from_name(app_name, normalized_function)
            return fn.spawn(**kwargs)

        call = _run_modal_sdk_call("spawn_function", _spawn)
```

- [ ] Add this test to `TRR-Backend/tests/test_modal_dispatch.py`:

```python
def test_run_modal_sdk_call_times_out(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(modal_dispatch, "_modal_sdk_timeout_seconds", lambda: 0.01)

    def _blocked() -> None:
        import time

        time.sleep(1)

    with pytest.raises(TimeoutError, match="modal_probe_timeout_after_0.01s"):
        modal_dispatch._run_modal_sdk_call("probe", _blocked)
```

Add this test near `test_resolve_modal_function_classifies_missing_app`:

```python
def test_resolve_modal_function_classifies_sdk_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(modal_dispatch, "modal_dispatch_ready", lambda *, function_name: (True, None))
    monkeypatch.setattr(modal_dispatch, "modal_app_name", lambda: "trr-backend-jobs")
    monkeypatch.setattr(modal_dispatch, "modal_environment_name", lambda: "main")
    monkeypatch.setattr(
        modal_dispatch,
        "_run_modal_sdk_call",
        lambda _label, _callback: (_ for _ in ()).throw(TimeoutError("modal_resolve_function_timeout_after_15s")),
    )
    monkeypatch.setitem(sys.modules, "modal", types.SimpleNamespace(Function=types.SimpleNamespace()))

    payload = modal_dispatch.resolve_modal_function("run_social_job")

    assert payload["resolved"] is False
    assert payload["reason"] == "modal_sdk_timeout"
    assert payload["error"] == "modal_resolve_function_timeout_after_15s"
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/test_modal_dispatch.py -q
```

Expected output:

```text
all selected modal dispatch tests pass
```

- [ ] Commit:

```bash
git add TRR-Backend/trr_backend/modal_dispatch.py TRR-Backend/tests/test_modal_dispatch.py
git commit -m "Timeout blocking Modal SDK dispatch calls"
```

## Task 6: Add Runtime Snapshot To Liveness Payload

- [ ] Edit `TRR-Backend/api/main.py`.

Add this import:

```python
from trr_backend.socials.control_plane.background_tasks import background_task_snapshot
```

Change `health_live` to:

```python
@app.get("/health/live")
async def health_live() -> dict[str, object]:
    return {
        "status": "alive",
        "service": "trr-backend",
        "background_tasks": background_task_snapshot(),
    }
```

Rationale: the workspace watchdog can still use `status=alive`, while the payload gives operators a no-DB view into whether local social control-plane background lanes are pinned.

- [ ] Update `TRR-Backend/tests/api/test_health.py`.

In `test_health_live`, add:

```python
    assert "background_tasks" in body
```

In `test_health_live_ignores_database_failure`, add:

```python
    assert "background_tasks" in body
```

- [ ] Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest tests/api/test_health.py -q
```

Expected output:

```text
6 passed
```

- [ ] Commit:

```bash
git add TRR-Backend/api/main.py TRR-Backend/tests/api/test_health.py
git commit -m "Expose backend control-plane liveness snapshot"
```

## Task 7: Run Focused Regression Suite

- [ ] Run all targeted tests touched by this plan:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PYTHONPATH=. pytest \
  tests/api/test_health.py \
  tests/socials/test_background_tasks.py \
  tests/test_modal_dispatch.py \
  tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches \
  tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_logs_when_gate_is_busy \
  tests/repositories/test_social_season_analytics.py::test_dispatch_due_social_jobs_background_uses_singleflight_gate \
  tests/repositories/test_social_season_analytics.py::test_dispatch_due_social_jobs_background_reports_busy_gate \
  -q
```

Expected output:

```text
all selected tests pass
```

- [ ] Run a syntax check for edited backend files:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m compileall api/main.py api/routers/socials.py trr_backend/modal_dispatch.py trr_backend/repositories/social_season_analytics.py trr_backend/socials/control_plane/background_tasks.py
```

Expected output:

```text
Compiling ...
```

- [ ] Commit any final test-only adjustments:

```bash
git status --short
git add TRR-Backend
git commit -m "Verify backend pool saturation guardrails"
```

Only create this final commit if there are changes not already committed by the earlier tasks.

## Task 8: Manual Runtime Verification

- [ ] Restart the workspace backend so the new env-controlled gates and async liveness route are loaded:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

- [ ] In a separate terminal, verify liveness stays fast and does not require a DB checkout:

```bash
curl --max-time 2 -sS http://127.0.0.1:8000/health/live | python -m json.tool
```

Expected output shape:

```json
{
  "status": "alive",
  "service": "trr-backend",
  "background_tasks": {
    "groups": {}
  }
}
```

- [ ] Start one catalog backfill from the admin UI, then immediately hit `/health/live` while it is launching Modal work:

```bash
curl --max-time 2 -sS http://127.0.0.1:8000/health/live | python -m json.tool
```

Expected result: command returns within 2 seconds. During active launch, `background_tasks.groups` may show one `catalog-finalize` or `social-dispatch` active key.

- [ ] Watch backend logs for these strings:

```bash
rg -n "db-pool|background dispatch deferred|finalizer deferred|modal_.*_timeout" /tmp/trr-backend.log
```

Expected result after the fix under one active launch:

```text
No repeated acquire_failed storm with in_use=4 available=0.
No growing stream of duplicate dispatch-social-jobs threads for the same run_id.
```

If a single `limit_reached` or `already_running` warning appears, that is acceptable. It means the local gate rejected duplicate background work instead of spawning more blocking threads.

## Operational Defaults

- [ ] Keep these defaults unless runtime evidence shows a need to tune:

```bash
TRR_CATALOG_FINALIZER_MAX_ACTIVE=1
TRR_SOCIAL_DISPATCH_BACKGROUND_MAX_ACTIVE=1
TRR_MODAL_SDK_CALL_WORKERS=2
TRR_MODAL_SDK_CALL_TIMEOUT_SECONDS=15
```

Rationale: the local backend runs against a small session-pooler profile in `make dev`. The fix should reduce local thread and connection pressure before increasing `TRR_DB_POOL_MAXCONN`.
