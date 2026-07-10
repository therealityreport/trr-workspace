# Plan 011: Stop silently swallowing realtime publish failures

> **Executor instructions**: Keep this small. The goal is visible failure
> accounting/logging, not a new realtime subsystem.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- api/routers/discussions.py api/routers/dms.py tests/test_discussions_smoke.py tests/test_dms_smoke.py`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: correctness
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

Discussion and DM writes enqueue realtime publishes as background work. Their
sync wrapper catches every exception and only logs a string, so a broken broker
can drop events without any structured signal for tests or operations.

## Current state

- `api/routers/discussions.py:43` defines `publish_event_sync()`.
- `api/routers/discussions.py:52` runs `asyncio.run(broker.publish(...))`.
- `api/routers/discussions.py:53` catches `Exception` and logs
  `logger.error(...)`.
- `api/routers/dms.py:37` has the same helper and catch-all behavior.

## Scope

**In scope**:
- `api/routers/discussions.py`
- `api/routers/dms.py`
- focused smoke tests

**Out of scope**:
- Changing API response codes for successful DB writes.
- Replacing FastAPI `BackgroundTasks`.

## Steps

1. Replace string-only error logging with `logger.exception(...)` so traceback
   context is preserved.
2. Return a boolean from the helper or extract a shared helper that tests can
   call directly.
3. Add tests that monkeypatch the broker publish to raise and assert the helper
   reports/logs failure deterministically.
4. Do not leak event payload contents that may contain user text into new logs.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -m pytest tests/test_discussions_smoke.py tests/test_dms_smoke.py -q
ruff check api/routers/discussions.py api/routers/dms.py tests/test_discussions_smoke.py tests/test_dms_smoke.py
```

## Done criteria

- Broker publish failures preserve exception context.
- Tests cover failure reporting for discussions and DMs.
- Existing write behavior stays compatible.
