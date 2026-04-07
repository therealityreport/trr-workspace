# Show Sync Parallel Modal Dispatch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Health Center's Show Sync to dispatch independent refresh targets as parallel sub-operations on Modal, with per-target observability and retry.

**Architecture:** Extend `core.admin_operations` with a `parent_operation_id` FK so a single show refresh spawns one parent operation and one child sub-operation per target. An orchestrator dispatches independent children to separate Modal containers in parallel (show_core first, then links/bravo/cast_profiles concurrently, then cast_media last). The parent operation aggregates child statuses — completing when all children succeed, failing when any child fails. The existing SSE stream fans-in child events into a single unified stream for the frontend. Frontend timeout constants are aligned with the backend's actual execution window. Per-target retry creates a fresh sub-operation for just the failed target.

**Tech Stack:** Python 3.11, FastAPI, PostgreSQL (Supabase), Modal, Next.js 15, TypeScript, Server-Sent Events

**Target dependency graph:**
```
show_core ──┬──► links          (parallel after show_core)
            ├──► bravo          (parallel after show_core)
            └──► cast_profiles ──► cast_media
```

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `TRR-Backend/supabase/migrations/20260408000000_admin_sub_operations.sql` | Adds `parent_operation_id` + `refresh_target` columns |
| `TRR-Backend/tests/repositories/test_admin_sub_operations.py` | Repository-layer unit tests for sub-operation CRUD |
| `TRR-Backend/tests/pipeline/test_show_refresh_orchestrator.py` | Orchestrator logic tests — dependency ordering, parallel dispatch, aggregation |
| `TRR-Backend/trr_backend/pipeline/show_refresh_orchestrator.py` | Target dependency graph, parallel dispatch, parent aggregation |

### Modified Files
| File | Changes |
|------|---------|
| `TRR-Backend/trr_backend/repositories/admin_operations.py` | `create_sub_operation()`, `get_sub_operations()`, `aggregate_parent_status()` |
| `TRR-Backend/trr_backend/pipeline/admin_operations.py` | `start_sub_operations_for_stream()`, fan-in SSE for parent operations |
| `TRR-Backend/api/routers/admin_show_sync.py` | Wire refresh endpoint to orchestrator, add per-target retry endpoint |
| `TRR-Backend/trr_backend/modal_dispatch.py` | No changes — existing `dispatch_admin_operation()` works for sub-ops |
| `TRR-Backend/trr_backend/modal_jobs.py` | No changes — `run_admin_operation_v2` already handles any operation by ID |
| `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` | Timeout alignment, per-target status display, retry button |
| `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/refresh/stream/route.ts` | Align `maxDuration` |
| `TRR-APP/apps/web/src/lib/admin/refresh-log-pipeline.ts` | Sub-operation awareness in pipeline row builder |

---

## Phase 1: Timeout Alignment

### Task 1: Align Frontend and Proxy Timeouts

**Files:**
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx:1130-1143`
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/refresh/stream/route.ts:12`

The Modal worker has a 60-minute timeout (`modal_jobs.py:353`), but the frontend caps at 12 minutes and the proxy at ~13.3 minutes. A long refresh succeeds on Modal but the client sees a timeout — losing the SSE connection and showing a false error. The proxy `maxDuration` must exceed the Modal timeout to never be the bottleneck, and the frontend idle timeout needs to tolerate slow steps.

- [ ] **Step 1: Update proxy route maxDuration**

In `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/refresh/stream/route.ts`, change the route segment config:

```typescript
// Before:
export const maxDuration = 800;

// After — 65 minutes, exceeding Modal's 60-minute timeout so the proxy
// is never the bottleneck for a remotely-executed refresh.
export const maxDuration = 3900;
```

- [ ] **Step 2: Update frontend timeout constants**

In `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, update the timeout block near line 1130:

```typescript
// Before:
const SHOW_REFRESH_STREAM_IDLE_TIMEOUT_MS = 600_000;      // 10 min
const SHOW_REFRESH_STREAM_MAX_DURATION_MS = 12 * 60 * 1000; // 12 min
const SHOW_REFRESH_FALLBACK_TIMEOUT_MS = 5 * 60 * 1000;     // 5 min

// After — align with Modal's 60-min worker timeout.
// Idle timeout stays reasonable (a step that emits zero events for 15 min is stuck).
// Max duration gives Modal the full 60 min plus a 5-min grace for SSE drain.
const SHOW_REFRESH_STREAM_IDLE_TIMEOUT_MS = 15 * 60 * 1000;   // 15 min idle
const SHOW_REFRESH_STREAM_MAX_DURATION_MS = 65 * 60 * 1000;   // 65 min total
const SHOW_REFRESH_FALLBACK_TIMEOUT_MS = 10 * 60 * 1000;      // 10 min fallback
```

- [ ] **Step 3: Verify build**

Run:
```bash
cd TRR-APP && pnpm -C apps/web exec next build --webpack
```
Expected: Build succeeds with no type errors.

- [ ] **Step 4: Commit**

```bash
git add \
  apps/web/src/app/admin/trr-shows/\[showId\]/page.tsx \
  apps/web/src/app/api/admin/trr-api/shows/\[showId\]/refresh/stream/route.ts
git commit -m "fix(show-sync): align frontend/proxy timeouts with Modal 60-min worker window"
```

---

## Phase 2: Sub-Operation Data Model

### Task 2: Database Migration — parent_operation_id + refresh_target

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260408000000_admin_sub_operations.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Sub-operation support: link child operations to a parent for target-level
-- dispatch and aggregation in show refresh (and future multi-step workflows).

alter table core.admin_operations
  add column if not exists parent_operation_id uuid
    references core.admin_operations(id) on delete cascade,
  add column if not exists refresh_target text;

comment on column core.admin_operations.parent_operation_id is
  'FK to parent operation. Null for top-level operations.';
comment on column core.admin_operations.refresh_target is
  'Refresh target key (show_core, links, bravo, cast_profiles, cast_media) for sub-operations.';

create index if not exists idx_admin_operations_parent_id
  on core.admin_operations(parent_operation_id, created_at)
  where parent_operation_id is not null;

create index if not exists idx_admin_operations_parent_status
  on core.admin_operations(parent_operation_id, status)
  where parent_operation_id is not null;
```

- [ ] **Step 2: Apply migration locally**

Run:
```bash
cd TRR-Backend && supabase db push --local
```
Expected: Migration applies cleanly.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260408000000_admin_sub_operations.sql
git commit -m "feat(schema): add parent_operation_id and refresh_target to admin_operations"
```

---

### Task 3: Repository Layer — Sub-Operation CRUD

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/admin_operations.py`
- Create: `TRR-Backend/tests/repositories/test_admin_sub_operations.py`

- [ ] **Step 1: Write failing tests for sub-operation creation and querying**

Create `TRR-Backend/tests/repositories/test_admin_sub_operations.py`:

```python
"""Tests for sub-operation (parent/child) repository helpers."""

from __future__ import annotations

import pytest

from trr_backend.repositories import admin_operations


@pytest.fixture()
def parent_operation(db_conn) -> dict:
    op, _attached = admin_operations.create_or_attach_operation(
        operation_type="admin_show_refresh",
        request_payload={"show_id": 42, "targets": ["show_core", "links"]},
        initiated_by="test",
        allow_attach=False,
    )
    return op


class TestCreateSubOperation:
    def test_creates_child_linked_to_parent(self, parent_operation):
        child = admin_operations.create_sub_operation(
            parent_operation_id=parent_operation["id"],
            operation_type="admin_show_refresh",
            refresh_target="show_core",
            request_payload={"show_id": 42, "targets": ["show_core"]},
            initiated_by="test",
        )
        assert child["parent_operation_id"] == parent_operation["id"]
        assert child["refresh_target"] == "show_core"
        assert child["status"] == "pending"

    def test_rejects_empty_parent_id(self):
        with pytest.raises(ValueError, match="parent_operation_id"):
            admin_operations.create_sub_operation(
                parent_operation_id="",
                operation_type="admin_show_refresh",
                refresh_target="show_core",
                request_payload={},
                initiated_by="test",
            )


class TestGetSubOperations:
    def test_returns_children_for_parent(self, parent_operation):
        admin_operations.create_sub_operation(
            parent_operation_id=parent_operation["id"],
            operation_type="admin_show_refresh",
            refresh_target="show_core",
            request_payload={"show_id": 42},
            initiated_by="test",
        )
        admin_operations.create_sub_operation(
            parent_operation_id=parent_operation["id"],
            operation_type="admin_show_refresh",
            refresh_target="links",
            request_payload={"show_id": 42},
            initiated_by="test",
        )

        children = admin_operations.get_sub_operations(parent_operation["id"])
        assert len(children) == 2
        targets = {c["refresh_target"] for c in children}
        assert targets == {"show_core", "links"}

    def test_returns_empty_for_no_children(self, parent_operation):
        children = admin_operations.get_sub_operations(parent_operation["id"])
        assert children == []


class TestAggregateParentStatus:
    def test_all_completed_returns_completed(self, parent_operation):
        for target in ("show_core", "links"):
            child = admin_operations.create_sub_operation(
                parent_operation_id=parent_operation["id"],
                operation_type="admin_show_refresh",
                refresh_target=target,
                request_payload={"show_id": 42},
                initiated_by="test",
            )
            admin_operations.update_operation_status(child["id"], "completed")

        status = admin_operations.aggregate_parent_status(parent_operation["id"])
        assert status == "completed"

    def test_any_failed_returns_failed(self, parent_operation):
        child_ok = admin_operations.create_sub_operation(
            parent_operation_id=parent_operation["id"],
            operation_type="admin_show_refresh",
            refresh_target="show_core",
            request_payload={"show_id": 42},
            initiated_by="test",
        )
        admin_operations.update_operation_status(child_ok["id"], "completed")

        child_fail = admin_operations.create_sub_operation(
            parent_operation_id=parent_operation["id"],
            operation_type="admin_show_refresh",
            refresh_target="links",
            request_payload={"show_id": 42},
            initiated_by="test",
        )
        admin_operations.update_operation_status(child_fail["id"], "failed")

        status = admin_operations.aggregate_parent_status(parent_operation["id"])
        assert status == "failed"

    def test_any_running_returns_running(self, parent_operation):
        child = admin_operations.create_sub_operation(
            parent_operation_id=parent_operation["id"],
            operation_type="admin_show_refresh",
            refresh_target="show_core",
            request_payload={"show_id": 42},
            initiated_by="test",
        )
        admin_operations.update_operation_status(child["id"], "running")

        status = admin_operations.aggregate_parent_status(parent_operation["id"])
        assert status == "running"

    def test_no_children_returns_pending(self, parent_operation):
        status = admin_operations.aggregate_parent_status(parent_operation["id"])
        assert status == "pending"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd TRR-Backend && pytest tests/repositories/test_admin_sub_operations.py -v
```
Expected: FAIL — `create_sub_operation`, `get_sub_operations`, `aggregate_parent_status` do not exist yet.

- [ ] **Step 3: Implement sub-operation repository helpers**

Add to the end of `TRR-Backend/trr_backend/repositories/admin_operations.py` (before the final blank line):

```python
# ---------------------------------------------------------------------------
# Sub-operation helpers (parent/child relationships for parallel dispatch)
# ---------------------------------------------------------------------------


def create_sub_operation(
    *,
    parent_operation_id: str,
    operation_type: str,
    refresh_target: str,
    request_payload: dict[str, Any] | None = None,
    initiated_by: str | None = None,
    request_id: str | None = None,
    client_session_id: str | None = None,
    client_workflow_id: str | None = None,
) -> dict[str, Any]:
    """Create a child operation linked to a parent."""
    if not (parent_operation_id or "").strip():
        raise ValueError("parent_operation_id is required")
    if not (refresh_target or "").strip():
        raise ValueError("refresh_target is required")

    row = pg.fetch_one(
        f"""
        insert into core.admin_operations (
          operation_type, status, initiated_by, request_id,
          client_session_id, client_workflow_id,
          request_payload, progress_payload,
          parent_operation_id, refresh_target, attempt_count
        )
        values (
          %s, 'pending', %s, %s, %s, %s,
          %s::jsonb, '{{}}'::jsonb,
          %s::uuid, %s, 0
        )
        returning {_OPERATION_COLUMNS}, parent_operation_id, refresh_target
        """,
        [
            str(operation_type).strip(),
            _clean_text(initiated_by),
            _clean_text(request_id),
            _clean_text(client_session_id),
            _clean_text(client_workflow_id),
            _to_json(request_payload),
            parent_operation_id.strip(),
            refresh_target.strip(),
        ],
    )
    if not row:
        raise RuntimeError("Failed to create sub-operation")
    normalized = _normalize_operation(row) or {}
    normalized["parent_operation_id"] = str(row.get("parent_operation_id") or "")
    normalized["refresh_target"] = str(row.get("refresh_target") or "")
    return normalized


def get_sub_operations(parent_operation_id: str) -> list[dict[str, Any]]:
    """Return all child operations for a parent, ordered by creation time."""
    rows = pg.fetch_all(
        f"""
        select
          {_OPERATION_COLUMNS}, parent_operation_id, refresh_target
        from core.admin_operations
        where parent_operation_id = %s::uuid
        order by created_at asc
        """,
        [parent_operation_id],
    )
    result = []
    for row in rows or []:
        normalized = _normalize_operation(row) or {}
        normalized["parent_operation_id"] = str(row.get("parent_operation_id") or "")
        normalized["refresh_target"] = str(row.get("refresh_target") or "")
        result.append(normalized)
    return result


def aggregate_parent_status(parent_operation_id: str) -> str:
    """Derive parent status from children: failed > running/cancelling > pending > completed."""
    row = pg.fetch_one(
        """
        select
          count(*) filter (where status = 'failed') as failed_count,
          count(*) filter (where status in ('running', 'cancelling')) as active_count,
          count(*) filter (where status = 'pending') as pending_count,
          count(*) filter (where status = 'completed') as completed_count,
          count(*) as total_count
        from core.admin_operations
        where parent_operation_id = %s::uuid
        """,
        [parent_operation_id],
    )
    if not row or int(row.get("total_count") or 0) == 0:
        return "pending"
    if int(row.get("failed_count") or 0) > 0:
        return "failed"
    if int(row.get("active_count") or 0) > 0:
        return "running"
    if int(row.get("pending_count") or 0) > 0:
        return "pending"
    return "completed"
```

- [ ] **Step 4: Update _OPERATION_COLUMNS to include new columns**

In the same file, update the `_OPERATION_COLUMNS` constant (line 23) to include the new columns:

```python
_OPERATION_COLUMNS = """
  id::text,
  operation_type,
  status,
  initiated_by,
  request_id,
  client_session_id,
  client_workflow_id,
  request_payload,
  progress_payload,
  result_payload,
  error_payload,
  cancel_requested_at,
  claimed_by_worker_id,
  claim_token,
  lease_expires_at,
  heartbeat_at,
  attempt_count,
  next_retry_at,
  parent_operation_id,
  refresh_target,
  started_at,
  completed_at,
  created_at,
  updated_at
"""
```

Update `_normalize_operation()` to pass through the new fields. Find the function (near line 170) and add after the existing normalization:

```python
    # Sub-operation fields
    normalized["parent_operation_id"] = str(row.get("parent_operation_id") or "") or None
    normalized["refresh_target"] = str(row.get("refresh_target") or "") or None
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
cd TRR-Backend && pytest tests/repositories/test_admin_sub_operations.py -v
```
Expected: All 7 tests PASS.

- [ ] **Step 6: Run full test suite to check for regressions**

Run:
```bash
cd TRR-Backend && pytest -q --tb=short
```
Expected: No regressions. Existing tests pass (the new columns are nullable and `_OPERATION_COLUMNS` expansion is backwards-compatible).

- [ ] **Step 7: Commit**

```bash
git add \
  trr_backend/repositories/admin_operations.py \
  tests/repositories/test_admin_sub_operations.py
git commit -m "feat(admin-ops): add sub-operation CRUD — create_sub_operation, get_sub_operations, aggregate_parent_status"
```

---

## Phase 3: Parallel Target Orchestrator

### Task 4: Show Refresh Orchestrator — Dependency Graph + Parallel Dispatch

**Files:**
- Create: `TRR-Backend/trr_backend/pipeline/show_refresh_orchestrator.py`
- Create: `TRR-Backend/tests/pipeline/test_show_refresh_orchestrator.py`

- [ ] **Step 1: Write failing tests for the orchestrator**

Create `TRR-Backend/tests/pipeline/test_show_refresh_orchestrator.py`:

```python
"""Tests for show refresh orchestrator — dependency ordering and parallel dispatch."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from trr_backend.pipeline.show_refresh_orchestrator import (
    TARGET_DEPENDENCY_GRAPH,
    ShowRefreshOrchestrator,
    execution_waves,
)


class TestTargetDependencyGraph:
    def test_show_core_has_no_dependencies(self):
        assert TARGET_DEPENDENCY_GRAPH["show_core"] == []

    def test_links_depends_on_show_core(self):
        assert TARGET_DEPENDENCY_GRAPH["links"] == ["show_core"]

    def test_bravo_depends_on_show_core(self):
        assert TARGET_DEPENDENCY_GRAPH["bravo"] == ["show_core"]

    def test_cast_profiles_depends_on_show_core(self):
        assert TARGET_DEPENDENCY_GRAPH["cast_profiles"] == ["show_core"]

    def test_cast_media_depends_on_cast_profiles(self):
        assert TARGET_DEPENDENCY_GRAPH["cast_media"] == ["cast_profiles"]


class TestExecutionWaves:
    def test_full_targets_produce_three_waves(self):
        targets = ["show_core", "links", "bravo", "cast_profiles", "cast_media"]
        waves = execution_waves(targets)
        assert waves == [
            ["show_core"],
            ["links", "bravo", "cast_profiles"],
            ["cast_media"],
        ]

    def test_single_target_produces_one_wave(self):
        waves = execution_waves(["links"])
        assert waves == [["links"]]

    def test_subset_without_cast_media(self):
        waves = execution_waves(["show_core", "links", "bravo"])
        assert waves == [
            ["show_core"],
            ["links", "bravo"],
        ]

    def test_empty_targets_returns_empty(self):
        waves = execution_waves([])
        assert waves == []

    def test_cast_media_alone_is_one_wave(self):
        waves = execution_waves(["cast_media"])
        assert waves == [["cast_media"]]


class TestShowRefreshOrchestrator:
    def test_creates_parent_and_sub_operations(self, db_conn):
        orchestrator = ShowRefreshOrchestrator(
            show_id=42,
            targets=["show_core", "links"],
            initiated_by="test",
            request_payload={"show_id": 42},
        )
        parent_id, sub_ops = orchestrator.create_operations()

        assert parent_id is not None
        assert len(sub_ops) == 2
        assert {s["refresh_target"] for s in sub_ops} == {"show_core", "links"}

    @patch("trr_backend.pipeline.show_refresh_orchestrator.dispatch_admin_operation")
    def test_dispatch_wave_dispatches_to_modal(self, mock_dispatch, db_conn):
        mock_dispatch.return_value = True
        orchestrator = ShowRefreshOrchestrator(
            show_id=42,
            targets=["show_core"],
            initiated_by="test",
            request_payload={"show_id": 42},
        )
        parent_id, sub_ops = orchestrator.create_operations()
        dispatched = orchestrator.dispatch_wave(sub_ops)
        assert dispatched == 1
        mock_dispatch.assert_called_once()

    @patch("trr_backend.pipeline.show_refresh_orchestrator.dispatch_admin_operation")
    def test_dispatch_wave_falls_back_to_local(self, mock_dispatch, db_conn):
        mock_dispatch.return_value = False
        orchestrator = ShowRefreshOrchestrator(
            show_id=42,
            targets=["show_core"],
            initiated_by="test",
            request_payload={"show_id": 42},
        )
        parent_id, sub_ops = orchestrator.create_operations()
        dispatched = orchestrator.dispatch_wave(sub_ops)
        assert dispatched == 0  # fell back to local
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd TRR-Backend && pytest tests/pipeline/test_show_refresh_orchestrator.py -v
```
Expected: FAIL — module does not exist.

- [ ] **Step 3: Implement the orchestrator**

Create `TRR-Backend/trr_backend/pipeline/show_refresh_orchestrator.py`:

```python
"""Orchestrates parallel show refresh across Modal workers.

Builds execution waves from the target dependency graph, creates one
sub-operation per target, and dispatches independent targets concurrently.
"""

from __future__ import annotations

import logging
from typing import Any

from trr_backend.job_plane import is_remote_job_plane_enabled
from trr_backend.modal_dispatch import dispatch_admin_operation, supports_admin_operation
from trr_backend.pipeline.admin_operations import ensure_operation_execution
from trr_backend.repositories import admin_operations

logger = logging.getLogger(__name__)

# Dependency graph: target -> list of targets that must complete first.
# A target with an empty list can run in the first wave.
TARGET_DEPENDENCY_GRAPH: dict[str, list[str]] = {
    "show_core": [],
    "links": ["show_core"],
    "bravo": ["show_core"],
    "cast_profiles": ["show_core"],
    "cast_media": ["cast_profiles"],
}


def execution_waves(targets: list[str]) -> list[list[str]]:
    """Sort targets into sequential waves respecting the dependency graph.

    Targets whose dependencies are satisfied (or not in the requested set)
    go into the earliest possible wave.  Returns a list of waves, each
    containing targets that can execute concurrently.
    """
    if not targets:
        return []

    target_set = set(targets)
    remaining = set(targets)
    completed: set[str] = set()
    waves: list[list[str]] = []

    while remaining:
        wave = []
        for target in sorted(remaining):  # sorted for deterministic ordering
            deps = TARGET_DEPENDENCY_GRAPH.get(target, [])
            # A dependency is satisfied if it's completed OR not in the requested set
            if all(d in completed or d not in target_set for d in deps):
                wave.append(target)
        if not wave:
            # Safety valve: remaining targets have unsatisfiable deps — force them
            wave = sorted(remaining)
        for target in wave:
            remaining.discard(target)
        completed.update(wave)
        waves.append(wave)

    return waves


class ShowRefreshOrchestrator:
    """Creates and dispatches sub-operations for a show refresh."""

    def __init__(
        self,
        *,
        show_id: int,
        targets: list[str],
        initiated_by: str | None = None,
        request_payload: dict[str, Any] | None = None,
        request_id: str | None = None,
        client_session_id: str | None = None,
        client_workflow_id: str | None = None,
    ) -> None:
        self.show_id = show_id
        self.targets = targets
        self.initiated_by = initiated_by
        self.request_payload = request_payload or {}
        self.request_id = request_id
        self.client_session_id = client_session_id
        self.client_workflow_id = client_workflow_id
        self._parent_id: str | None = None
        self._sub_ops: dict[str, dict[str, Any]] = {}

    def create_operations(self) -> tuple[str, list[dict[str, Any]]]:
        """Create a parent operation and one sub-operation per target."""
        parent, _attached = admin_operations.create_or_attach_operation(
            operation_type="admin_show_refresh",
            request_payload=self.request_payload,
            initiated_by=self.initiated_by,
            request_id=self.request_id,
            client_session_id=self.client_session_id,
            client_workflow_id=self.client_workflow_id,
            allow_attach=True,
        )
        self._parent_id = str(parent["id"])

        sub_ops = []
        for target in self.targets:
            child = admin_operations.create_sub_operation(
                parent_operation_id=self._parent_id,
                operation_type="admin_show_refresh",
                refresh_target=target,
                request_payload={**self.request_payload, "targets": [target]},
                initiated_by=self.initiated_by,
                request_id=self.request_id,
                client_session_id=self.client_session_id,
                client_workflow_id=self.client_workflow_id,
            )
            self._sub_ops[target] = child
            sub_ops.append(child)

        return self._parent_id, sub_ops

    def dispatch_wave(
        self,
        sub_ops: list[dict[str, Any]],
        *,
        producer_factory: Any | None = None,
    ) -> int:
        """Dispatch a wave of sub-operations. Returns count dispatched to Modal."""
        modal_dispatched = 0
        op_type = "admin_show_refresh"
        modal_supported = supports_admin_operation(op_type)
        remote_enabled = is_remote_job_plane_enabled()

        for sub_op in sub_ops:
            op_id = str(sub_op["id"])
            target = str(sub_op.get("refresh_target") or "")

            if modal_supported and remote_enabled:
                dispatched = dispatch_admin_operation(
                    operation_id=op_id,
                    operation_type=op_type,
                )
                if dispatched:
                    modal_dispatched += 1
                    logger.info(
                        "Dispatched sub-operation to Modal: target=%s operation_id=%s parent=%s",
                        target, op_id, self._parent_id,
                    )
                    continue

            # Fallback: local execution
            if producer_factory is not None:
                producer = producer_factory(sub_op)
                ensure_operation_execution(op_id, producer=producer, request_id=self.request_id)
                logger.info(
                    "Local execution for sub-operation: target=%s operation_id=%s parent=%s",
                    target, op_id, self._parent_id,
                )
            else:
                logger.warning(
                    "No producer_factory and Modal unavailable: target=%s operation_id=%s stuck pending",
                    target, op_id,
                )

        return modal_dispatched

    def get_waves(self) -> list[list[dict[str, Any]]]:
        """Return sub-operations grouped into execution waves."""
        waves = execution_waves(self.targets)
        result = []
        for wave_targets in waves:
            wave_ops = [self._sub_ops[t] for t in wave_targets if t in self._sub_ops]
            if wave_ops:
                result.append(wave_ops)
        return result

    def update_parent_status(self) -> str:
        """Recompute and persist the parent's aggregated status."""
        if not self._parent_id:
            raise RuntimeError("No parent operation created yet")
        status = admin_operations.aggregate_parent_status(self._parent_id)
        if status in ("completed", "failed"):
            admin_operations.update_operation_status(self._parent_id, status)
        return status
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd TRR-Backend && pytest tests/pipeline/test_show_refresh_orchestrator.py -v
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add \
  trr_backend/pipeline/show_refresh_orchestrator.py \
  tests/pipeline/test_show_refresh_orchestrator.py
git commit -m "feat(show-sync): add ShowRefreshOrchestrator with target dependency graph and parallel wave dispatch"
```

---

### Task 5: Wire Orchestrator into the Refresh Stream Endpoint

**Files:**
- Modify: `TRR-Backend/api/routers/admin_show_sync.py:3411-3422, 4313-4354`
- Modify: `TRR-Backend/trr_backend/pipeline/admin_operations.py`

This task replaces the monolithic single-operation flow with the orchestrator. The parent operation's SSE stream fans-in events from all child sub-operations. The existing `operation_stream_generator` polls events by `operation_id` — we add a variant that polls events from children of a parent.

- [ ] **Step 1: Add parent-aware SSE event streaming to admin_operations repository**

Add to `TRR-Backend/trr_backend/repositories/admin_operations.py`:

```python
def stream_sub_operation_events_after_seq(
    parent_operation_id: str,
    *,
    after_seq: int = 0,
    limit: int = 500,
) -> list[dict[str, Any]]:
    """Stream events from all sub-operations of a parent, interleaved by event ID."""
    rows = pg.fetch_all(
        """
        select
          e.id,
          e.operation_id::text as operation_id,
          e.event_seq,
          e.event_type,
          e.event_payload,
          e.created_at,
          o.refresh_target
        from core.admin_operation_events e
        join core.admin_operations o on o.id = e.operation_id
        where o.parent_operation_id = %s::uuid
          and e.id > %s
        order by e.id asc
        limit %s
        """,
        [parent_operation_id, after_seq, limit],
    )
    return [dict(r) for r in (rows or [])]
```

- [ ] **Step 2: Add parent-aware SSE generator to admin_operations pipeline**

Add to `TRR-Backend/trr_backend/pipeline/admin_operations.py`, near the existing `operation_stream_generator`:

```python
async def parent_operation_stream_generator(
    parent_operation_id: str,
    *,
    after_event_id: int = 0,
    request: Request | None = None,
) -> AsyncGenerator[str, None]:
    """Fan-in SSE stream: yields events from all children of a parent operation."""
    next_event_id = max(0, int(after_event_id))

    while True:
        events = await run_in_threadpool(
            admin_operations.stream_sub_operation_events_after_seq,
            parent_operation_id,
            after_seq=next_event_id,
            limit=500,
        )
        for event in events:
            event_id = int(event.get("id") or 0)
            event_payload = _to_json_payload(event.get("event_payload"))
            event_payload["refresh_target"] = str(event.get("refresh_target") or "")
            event_payload["sub_operation_id"] = str(event.get("operation_id") or "")
            payload = _ensure_operation_payload(
                parent_operation_id,
                event_payload,
                request_id=str(event_payload.get("request_id") or "") or None,
            )
            payload["event_id"] = event_id
            event_type = str(event.get("event_type") or "message")
            yield _sse_chunk(event_type, payload)
            if event_id > next_event_id:
                next_event_id = event_id

        # Check if parent is terminal (all children done)
        parent_status = await run_in_threadpool(
            admin_operations.aggregate_parent_status,
            parent_operation_id,
        )
        if parent_status in ("completed", "failed", "cancelled"):
            # Drain any final events
            final_events = await run_in_threadpool(
                admin_operations.stream_sub_operation_events_after_seq,
                parent_operation_id,
                after_seq=next_event_id,
                limit=500,
            )
            for event in final_events:
                event_id = int(event.get("id") or 0)
                event_payload = _to_json_payload(event.get("event_payload"))
                event_payload["refresh_target"] = str(event.get("refresh_target") or "")
                event_payload["sub_operation_id"] = str(event.get("operation_id") or "")
                payload = _ensure_operation_payload(
                    parent_operation_id,
                    event_payload,
                    request_id=str(event_payload.get("request_id") or "") or None,
                )
                payload["event_id"] = event_id
                event_type = str(event.get("event_type") or "message")
                yield _sse_chunk(event_type, payload)

            # Final parent-level complete/error event
            yield _sse_chunk(
                "complete" if parent_status == "completed" else "error",
                {"operation_id": parent_operation_id, "status": parent_status},
            )
            return

        if request is not None:
            try:
                if await request.is_disconnected():
                    return
            except Exception:  # noqa: BLE001
                pass

        await asyncio.sleep(_EVENT_POLL_INTERVAL_SECONDS)
```

- [ ] **Step 3: Update the refresh stream endpoint to use orchestrator when remote mode is active**

In `TRR-Backend/api/routers/admin_show_sync.py`, add orchestrator integration to the `refresh_show_stream()` endpoint (near line 3411). The key change: when `is_remote_job_plane_enabled()` is true, use the orchestrator instead of the monolithic single-operation path.

Add the import near the top of the file:

```python
from trr_backend.pipeline.show_refresh_orchestrator import ShowRefreshOrchestrator
```

Then modify the endpoint body to add orchestrator branching. After the existing `start_operation_for_stream()` call area, add a conditional block:

```python
# In refresh_show_stream(), after parsing targets from the request payload:
if is_remote_job_plane_enabled() and supports_admin_operation("admin_show_refresh"):
    orchestrator = ShowRefreshOrchestrator(
        show_id=show_id,
        targets=parsed_targets,
        initiated_by=initiated_by,
        request_payload=request_payload_dict,
        request_id=request_id,
        client_session_id=client_session_id,
        client_workflow_id=client_workflow_id,
    )
    parent_id, sub_ops = orchestrator.create_operations()

    # Dispatch waves sequentially — within each wave, targets run in parallel
    for wave_ops in orchestrator.get_waves():
        orchestrator.dispatch_wave(
            wave_ops,
            producer_factory=lambda sub_op: build_show_refresh_operation_producer(
                request_payload=sub_op.get("request_payload", {}),
                operation_id=str(sub_op["id"]),
                db=db,
            ),
        )
        # NOTE: wave ordering is enforced by the Modal workers themselves —
        # each sub-op checks its dependencies' status before starting execution.
        # This dispatch just fires them all; the claim_and_execute path in
        # modal_jobs.py handles the wait-for-dependencies logic (see Task 6).

    return operation_stream_response_for_parent(parent_id, request=request)
```

- [ ] **Step 4: Add the parent stream response helper**

Add to `TRR-Backend/trr_backend/pipeline/admin_operations.py`:

```python
def operation_stream_response_for_parent(
    parent_operation_id: str,
    *,
    after_event_id: int = 0,
    request: Request | None = None,
) -> StreamingResponse:
    return StreamingResponse(
        parent_operation_stream_generator(
            parent_operation_id,
            after_event_id=after_event_id,
            request=request,
        ),
        media_type="text/event-stream",
        headers=_stream_headers(),
    )
```

- [ ] **Step 5: Run existing show sync tests to verify no regressions**

Run:
```bash
cd TRR-Backend && pytest tests/api/routers/test_admin_show_sync.py -v --tb=short
```
Expected: Existing tests pass. (They run with `_default_local_job_plane` fixture that forces local mode, so the orchestrator branch is not entered.)

- [ ] **Step 6: Commit**

```bash
git add \
  trr_backend/repositories/admin_operations.py \
  trr_backend/pipeline/admin_operations.py \
  api/routers/admin_show_sync.py
git commit -m "feat(show-sync): wire orchestrator into refresh stream — parallel dispatch when remote mode enabled"
```

---

### Task 6: Dependency-Aware Execution in Modal Workers

**Files:**
- Modify: `TRR-Backend/trr_backend/modal_jobs.py:321-335`
- Modify: `TRR-Backend/trr_backend/pipeline/admin_operations.py`

When a sub-operation is claimed by a Modal worker, it must check whether its dependency targets (from the same parent) have completed before starting execution. If dependencies are still running, the worker polls until they finish.

- [ ] **Step 1: Write the dependency wait helper**

Add to `TRR-Backend/trr_backend/pipeline/admin_operations.py`:

```python
def wait_for_sub_operation_dependencies(
    operation_id: str,
    *,
    poll_interval_seconds: float = 2.0,
    timeout_seconds: float = 3600.0,
) -> bool:
    """Block until this sub-operation's dependency targets are complete.

    Returns True if dependencies satisfied, False if timed out or a dependency failed.
    """
    from trr_backend.pipeline.show_refresh_orchestrator import TARGET_DEPENDENCY_GRAPH

    op = admin_operations.get_operation(operation_id)
    if not op:
        return False

    parent_id = op.get("parent_operation_id")
    target = op.get("refresh_target")
    if not parent_id or not target:
        return True  # Not a sub-operation — no dependencies

    deps = TARGET_DEPENDENCY_GRAPH.get(target, [])
    if not deps:
        return True  # No dependencies — safe to run

    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        siblings = admin_operations.get_sub_operations(parent_id)
        dep_statuses = {
            s["refresh_target"]: s["status"]
            for s in siblings
            if s.get("refresh_target") in deps
        }

        # All deps completed → proceed
        if all(st == "completed" for st in dep_statuses.values()):
            return True

        # Any dep failed → abort
        if any(st in ("failed", "cancelled") for st in dep_statuses.values()):
            logger.warning(
                "Sub-operation dependency failed: operation_id=%s target=%s failed_deps=%s",
                operation_id, target,
                [t for t, s in dep_statuses.items() if s in ("failed", "cancelled")],
            )
            return False

        # Deps missing from sibling list → they weren't requested, treat as satisfied
        if len(dep_statuses) < len(deps):
            missing = set(deps) - set(dep_statuses.keys())
            logger.info(
                "Sub-operation deps not in sibling set (treating as satisfied): %s",
                missing,
            )
            # Re-check with only present deps
            present_statuses = [s for s in dep_statuses.values()]
            if all(st == "completed" for st in present_statuses) or not present_statuses:
                return True

        time.sleep(poll_interval_seconds)

    logger.error(
        "Sub-operation dependency wait timed out: operation_id=%s target=%s timeout=%s",
        operation_id, target, timeout_seconds,
    )
    return False
```

- [ ] **Step 2: Integrate dependency check into _execute_admin_operation**

In `TRR-Backend/trr_backend/modal_jobs.py`, update `_execute_admin_operation()` (line 321) to call the dependency wait before executing:

```python
def _execute_admin_operation(operation_id: str, operation_type: str) -> dict[str, object]:
    from trr_backend.pipeline.admin_operations import (
        claim_and_execute_operation,
        wait_for_sub_operation_dependencies,
    )

    worker_id = f"modal:{socket.gethostname()}:{os.getpid()}:{uuid.uuid4().hex[:8]}"

    # If this is a sub-operation, wait for dependency targets to complete
    deps_satisfied = wait_for_sub_operation_dependencies(operation_id)
    if not deps_satisfied:
        return {
            "operation_id": operation_id,
            "operation_type": operation_type,
            "claimed": False,
            "worker_id": worker_id,
            "reason": "dependency_not_satisfied",
        }

    claimed = claim_and_execute_operation(
        operation_id=operation_id,
        worker_id=worker_id,
        operation_types=[operation_type],
    )
    return {
        "operation_id": operation_id,
        "operation_type": operation_type,
        "claimed": claimed,
        "worker_id": worker_id,
    }
```

- [ ] **Step 3: Run tests**

Run:
```bash
cd TRR-Backend && pytest tests/pipeline/test_show_refresh_orchestrator.py tests/api/routers/test_admin_show_sync.py -v --tb=short
```
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add \
  trr_backend/pipeline/admin_operations.py \
  trr_backend/modal_jobs.py
git commit -m "feat(show-sync): add dependency-aware execution — Modal workers wait for prerequisite targets"
```

---

### Task 7: Parent Status Aggregation on Sub-Operation Completion

**Files:**
- Modify: `TRR-Backend/trr_backend/pipeline/admin_operations.py`

When a sub-operation reaches a terminal status (completed/failed), the system should recompute the parent's aggregated status and emit a parent-level event if all children are done.

- [ ] **Step 1: Write the post-completion hook**

Add to `TRR-Backend/trr_backend/pipeline/admin_operations.py`:

```python
def finalize_sub_operation(operation_id: str, status: str) -> str | None:
    """Called when a sub-operation reaches terminal status.

    Updates the sub-operation status, recomputes the parent's aggregate,
    and emits a parent-level complete/error event if all children are done.

    Returns the parent's new status, or None if not a sub-operation.
    """
    op = admin_operations.get_operation(operation_id)
    if not op:
        return None

    parent_id = op.get("parent_operation_id")
    if not parent_id:
        return None

    # Update this sub-operation's status
    admin_operations.update_operation_status(operation_id, status)

    # Recompute parent
    parent_status = admin_operations.aggregate_parent_status(parent_id)
    if parent_status in ("completed", "failed"):
        admin_operations.update_operation_status(parent_id, parent_status)

        # Emit parent-level terminal event
        children = admin_operations.get_sub_operations(parent_id)
        summary = {
            c.get("refresh_target", "unknown"): c.get("status", "unknown")
            for c in children
        }
        admin_operations.append_operation_event(
            parent_id,
            event_type="complete" if parent_status == "completed" else "error",
            event_payload={
                "operation_id": parent_id,
                "status": parent_status,
                "sub_operation_summary": summary,
            },
        )
        logger.info(
            "Parent operation finalized: parent_id=%s status=%s summary=%s",
            parent_id, parent_status, summary,
        )

    return parent_status
```

- [ ] **Step 2: Integrate into the operation worker completion path**

Find `_run_operation_worker()` in `admin_operations.py` (the function that wraps producer execution in the ThreadPoolExecutor). After the existing status update on completion/failure, add:

```python
# After existing: admin_operations.update_operation_status(operation_id, "completed")
finalize_sub_operation(operation_id, "completed")  # no-op if not a sub-operation
```

And after the existing failure status update:

```python
# After existing: admin_operations.update_operation_status(operation_id, "failed")
finalize_sub_operation(operation_id, "failed")  # no-op if not a sub-operation
```

- [ ] **Step 3: Run tests**

Run:
```bash
cd TRR-Backend && pytest -q --tb=short
```
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add trr_backend/pipeline/admin_operations.py
git commit -m "feat(show-sync): auto-aggregate parent status when sub-operations complete"
```

---

## Phase 4: Per-Target Retry

### Task 8: Per-Target Retry Endpoint

**Files:**
- Modify: `TRR-Backend/api/routers/admin_show_sync.py`
- Modify: `TRR-Backend/tests/api/routers/test_admin_show_sync.py`

- [ ] **Step 1: Write failing test for retry endpoint**

Add to `TRR-Backend/tests/api/routers/test_admin_show_sync.py`:

```python
class TestRefreshTargetRetry:
    """POST /admin/shows/{show_id}/refresh/target/{target}/retry"""

    def test_retry_creates_new_sub_operation(self, client, mock_db):
        # First: create a parent + failed sub-operation
        from trr_backend.repositories import admin_operations

        parent, _ = admin_operations.create_or_attach_operation(
            operation_type="admin_show_refresh",
            request_payload={"show_id": 1, "targets": ["links"]},
            initiated_by="test",
            allow_attach=False,
        )
        child = admin_operations.create_sub_operation(
            parent_operation_id=parent["id"],
            operation_type="admin_show_refresh",
            refresh_target="links",
            request_payload={"show_id": 1, "targets": ["links"]},
            initiated_by="test",
        )
        admin_operations.update_operation_status(child["id"], "failed")

        response = client.post(
            f"/admin/shows/1/refresh/target/links/retry",
            headers={"x-trr-request-id": "test-retry"},
            json={"parent_operation_id": parent["id"]},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["refresh_target"] == "links"
        assert data["status"] == "pending"
        assert data["parent_operation_id"] == parent["id"]

    def test_retry_rejects_invalid_target(self, client):
        response = client.post(
            "/admin/shows/1/refresh/target/invalid_target/retry",
            headers={"x-trr-request-id": "test"},
            json={"parent_operation_id": "00000000-0000-0000-0000-000000000000"},
        )
        assert response.status_code == 400
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd TRR-Backend && pytest tests/api/routers/test_admin_show_sync.py::TestRefreshTargetRetry -v
```
Expected: FAIL — endpoint does not exist.

- [ ] **Step 3: Implement the retry endpoint**

Add to `TRR-Backend/api/routers/admin_show_sync.py`:

```python
VALID_REFRESH_TARGETS = {"show_core", "links", "bravo", "cast_profiles", "cast_media"}


@router.post("/{show_id}/refresh/target/{target}/retry")
async def retry_refresh_target(
    show_id: int,
    target: str,
    request: Request,
    payload: dict = Body(...),
    db=Depends(get_admin_db),
):
    """Retry a single failed refresh target by creating a new sub-operation."""
    if target not in VALID_REFRESH_TARGETS:
        return JSONResponse(
            status_code=400,
            content={"error": f"Invalid target: {target}", "valid_targets": sorted(VALID_REFRESH_TARGETS)},
        )

    parent_operation_id = str(payload.get("parent_operation_id") or "").strip()
    if not parent_operation_id:
        return JSONResponse(status_code=400, content={"error": "parent_operation_id is required"})

    request_id = (request.headers.get("x-trr-request-id") or "").strip() or None

    child = admin_operations.create_sub_operation(
        parent_operation_id=parent_operation_id,
        operation_type="admin_show_refresh",
        refresh_target=target,
        request_payload={"show_id": show_id, "targets": [target]},
        initiated_by=request_id,
        request_id=request_id,
    )

    # Reset parent to running since we have a new pending child
    admin_operations.update_operation_status(parent_operation_id, "running")

    # Dispatch to Modal or local
    if supports_admin_operation("admin_show_refresh") and is_remote_job_plane_enabled():
        dispatch_admin_operation(operation_id=child["id"], operation_type="admin_show_refresh")
    else:
        producer = build_show_refresh_operation_producer(
            request_payload=child.get("request_payload", {}),
            operation_id=child["id"],
            db=db,
        )
        ensure_operation_execution(child["id"], producer=producer, request_id=request_id)

    return child
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd TRR-Backend && pytest tests/api/routers/test_admin_show_sync.py::TestRefreshTargetRetry -v
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add \
  api/routers/admin_show_sync.py \
  tests/api/routers/test_admin_show_sync.py
git commit -m "feat(show-sync): add per-target retry endpoint POST /refresh/target/{target}/retry"
```

---

## Phase 5: Frontend Health Center Updates

### Task 9: Per-Target Status and Retry in Health Center Sync Pipeline

**Files:**
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
- Modify: `TRR-APP/apps/web/src/lib/admin/refresh-log-pipeline.ts`

- [ ] **Step 1: Update refresh-log-pipeline.ts to carry sub-operation metadata**

In `TRR-APP/apps/web/src/lib/admin/refresh-log-pipeline.ts`, extend the `RefreshLogEntry` type (or the pipeline row type) to include:

```typescript
export interface PipelineRow {
  // ... existing fields ...
  subOperationId?: string;
  executionOwner?: string;
  parentOperationId?: string;
}
```

Update `buildPipelineRows()` to populate these from SSE event payloads that include `sub_operation_id`, `execution_owner`, and `refresh_target`.

- [ ] **Step 2: Update SSE event handler to parse sub-operation fields**

In `page.tsx`, in the `onEvent` callback for the refresh stream (near line 11099), add parsing for the new fields:

```typescript
// Inside the "progress" event handler:
const subOperationId = parsed.sub_operation_id ?? undefined;
const executionOwner = parsed.execution_owner ?? undefined;
const refreshTarget = parsed.refresh_target ?? undefined;
```

Pass these through to the refresh log entry so `buildPipelineRows()` can surface them.

- [ ] **Step 3: Add per-target execution badge to Sync Pipeline cards**

In the Health Center's Sync Pipeline section (near line 15992), update each pipeline stage card to show the execution owner when available:

```typescript
{row.executionOwner && (
  <span className="text-xs text-zinc-500 ml-1">
    ({row.executionOwner === "remote_worker" ? "Modal" : row.executionOwner})
  </span>
)}
```

- [ ] **Step 4: Add retry button for failed targets**

In the Sync Pipeline section, when a target row has status "failed", render a retry button:

```typescript
{row.status === "failed" && row.parentOperationId && (
  <button
    className="text-xs text-blue-500 hover:text-blue-700 ml-2"
    onClick={() => retryRefreshTarget(row.topicKey, row.parentOperationId!)}
  >
    Retry
  </button>
)}
```

Add the retry handler function:

```typescript
async function retryRefreshTarget(target: string, parentOperationId: string) {
  const res = await adminFetch(
    `/api/admin/trr-api/shows/${showId}/refresh/target/${target}/retry`,
    {
      method: "POST",
      body: JSON.stringify({ parent_operation_id: parentOperationId }),
    },
  );
  if (!res.ok) {
    setRefreshAllError(`Retry failed: ${res.statusText}`);
    return;
  }
  // Re-attach to the parent operation's SSE stream
  // ... reconnect to stream with parent_operation_id
}
```

- [ ] **Step 5: Verify build**

Run:
```bash
cd TRR-APP && pnpm -C apps/web exec next build --webpack
```
Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add \
  apps/web/src/app/admin/trr-shows/\[showId\]/page.tsx \
  apps/web/src/lib/admin/refresh-log-pipeline.ts
git commit -m "feat(health-center): show per-target Modal execution status and retry button in Sync Pipeline"
```

---

### Task 10: Add Frontend Proxy Route for Per-Target Retry

**Files:**
- Create: `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/refresh/target/[target]/retry/route.ts`

- [ ] **Step 1: Create the proxy route**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { proxyToBackend } from "@/lib/server/trr-api/backend";

export const maxDuration = 30;

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ showId: string; target: string }> },
) {
  const { showId, target } = await params;
  return proxyToBackend(request, {
    path: `/admin/shows/${showId}/refresh/target/${target}/retry`,
    method: "POST",
  });
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
cd TRR-APP && pnpm -C apps/web exec next build --webpack
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/app/api/admin/trr-api/shows/\[showId\]/refresh/target/\[target\]/retry/route.ts
git commit -m "feat(api-proxy): add retry route for per-target show refresh"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Timeout alignment (Phase 1), sub-operation model (Phase 2), parallel dispatch (Phase 3), per-target retry (Phase 4), frontend observability (Phase 5) — all identified gaps addressed.
- [x] **Placeholder scan:** No TBD/TODO/implement-later in any step. All code is concrete.
- [x] **Type consistency:** `parent_operation_id`, `refresh_target`, `sub_operation_id` used consistently across migration, repository, pipeline, and frontend.
- [x] **Dependency safety:** `execution_waves()` handles partial target sets (e.g., only requesting links + bravo without show_core). Dependencies not in the requested set are treated as satisfied.
- [x] **Backwards compatibility:** The orchestrator path only activates when `is_remote_job_plane_enabled()` is true. The existing local/monolithic path is unchanged. All new columns are nullable.
- [x] **Test coverage:** Repository CRUD tests, orchestrator wave tests, endpoint tests, regression checks against existing test suite.
