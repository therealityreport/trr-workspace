# Plan 012: Isolate modal job reload pollution in tests

> **Executor instructions**: This is test-only. Do not change Modal production
> runtime defaults to satisfy tests.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- tests/test_modal_jobs.py tests/conftest.py trr_backend/modal_jobs.py`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: 001
- **Category**: tests
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

Plan 001 handled the main `os.environ` pollution from `modal_jobs`. A second
test-only vector remains around `monkeypatch.setitem(sys.modules, ...)` followed
by `importlib.reload(modal_jobs)`. Reloading can leave module-level defaults or
stub modules behind for later tests.

## Current state

- `tests/test_modal_jobs.py:607`, `645`, `680`, `1095`, and `1100` patch
  `sys.modules` for social/control-plane modules.
- Nearby tests call Modal function wrappers from the already-imported
  `trr_backend.modal_jobs` module.
- `tests/conftest.py` now owns the pristine env baseline from plan 001.

## Scope

**In scope**:
- `tests/test_modal_jobs.py`
- `tests/conftest.py` only if a shared cleanup fixture is needed

**Out of scope**:
- `trr_backend/modal_jobs.py`
- Any Modal image/function binding behavior.

## Steps

1. Grep all `importlib.reload(modal_jobs)` and `monkeypatch.setitem(sys.modules`
   sites in `tests/test_modal_jobs.py`.
2. Add a small local fixture that snapshots/restores only the affected
   `sys.modules` keys and reloads `modal_jobs` back to a clean state when a test
   requires reload.
3. Prefer fixing the shared reload helper once over adding cleanup to each test.
4. Add one regression test that runs a patched-module test and then a real-module
   expectation in the same process.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -m pytest tests/test_modal_jobs.py -q
ruff check tests/test_modal_jobs.py tests/conftest.py
```

## Done criteria

- `tests/test_modal_jobs.py` passes in isolation.
- Patched `sys.modules` state does not leak across tests.
- No production Modal code changed.
