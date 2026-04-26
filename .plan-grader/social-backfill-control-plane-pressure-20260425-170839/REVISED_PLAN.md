# Social Backfill Control Plane Pressure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. The controller must dispatch a fresh implementer subagent for each task, then run spec-compliance and code-quality reviewer subagents before marking the task complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize Instagram, TikTok, X/Twitter, and Facebook social backfills by clearing stale run state, reducing dev Modal pressure, isolating control-plane DB work, cleaning stale advisory-lock sessions, and hardening TikTok/Instagram platform failure behavior.

**Architecture:** Keep the existing social control-plane architecture and add narrow hardening at the current seams. One-time run cleanup lives in an ops script, dev pressure limits stay in workspace profile/config files, DB isolation uses named pools in `trr_backend.db.pg`, run/finalize/read paths opt into the new control pool, and platform fixes stay inside the existing TikTok shared-posts and Instagram comments Scrapling lanes.

**Tech Stack:** Python 3.11, FastAPI backend, psycopg2/Postgres/Supabase pooler, Modal remote social jobs, pytest, shell workspace scripts.

---

## Scope Check

This plan spans three related surfaces: social run state cleanup, shared control-plane pressure, and two platform-specific scraper hardening fixes. They are coupled by the same backfill failure mode, so keep them in one plan, but implement the tasks in order and commit after each task. If time is limited, Tasks 1-5 are the stabilization path; Tasks 6-7 are platform completeness/auth quality fixes.

## Required Subagent-Driven Execution Workflow

Run implementation from a dedicated branch or worktree created from current local `main`; do not start code edits directly on `main`. The final task in this plan applies the fully reviewed implementation back onto local `main`.

Use this setup before Task 1:

```bash
cd /Users/thomashulihan/Projects/TRR
git checkout main
git pull --ff-only
git checkout -b social-backfill-control-plane-pressure
```

Expected: the working tree is on `social-backfill-control-plane-pressure`, based on current `main`, with no uncommitted changes.

The controller must execute every task with `superpowers:subagent-driven-development`:

1. Extract the full text of all tasks once, including files, code snippets, commands, and expected outcomes.
2. Track Tasks 1-11 in the controller checklist.
3. Dispatch exactly one fresh implementer subagent per task with that task's full text and only the scene-setting context needed for that task.
4. Wait for the implementer to write failing tests, implement, run verification, commit, and report `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.
5. After each implementer reports `DONE` or resolved `DONE_WITH_CONCERNS`, dispatch a spec-compliance reviewer subagent. If the reviewer finds any spec gap, send the findings back to the same implementer, require fixes, and re-run spec review.
6. Only after spec review approves, dispatch a code-quality reviewer subagent. If the reviewer finds any issue, send the findings back to the same implementer, require fixes, and re-run code-quality review.
7. Mark a task complete only after implementation, tests, commit, spec review, and code-quality review all pass.
8. Do not dispatch multiple implementation subagents in parallel because these tasks touch overlapping social-control, DB, and workspace contract surfaces.
9. For Task 8, dispatch browser-use-backed benchmark subagents for the Scrapling and Crawlee candidate runs, require comparable evidence from both methods, and refuse to select a default when either candidate lacks browser-use evidence.
10. After Task 10 passes on the feature branch, dispatch one final code-quality reviewer over the complete branch diff before Task 11 merges the result to `main`.

## File Structure

- Create `TRR-Backend/scripts/socials/reconcile_stale_social_run.py`
  - Small CLI for dry-run or execute cleanup of one stale `social.scrape_runs` row and its duplicate/open jobs.
- Create `TRR-Backend/tests/scripts/test_reconcile_stale_social_run.py`
  - Unit tests for the cleanup SQL and dry-run behavior using fake DB calls.
- Modify `profiles/default.env`
  - Lower default local/cloud dev Modal social pressure.
- Modify `scripts/dev-workspace.sh`
  - Match shell fallback defaults and warning fallback values to the lower caps.
- Modify `scripts/status-workspace.sh`
  - Match status fallback defaults to the lower caps.
- Modify `docs/workspace/env-contract.md`
  - Keep the documented workspace contract aligned.
- Modify `scripts/check-workspace-contract.sh`
  - Assert the new default contract.
- Modify `scripts/test_workspace_app_env_projection.py`
  - Assert projected env and pool totals with the new caps.
- Modify `TRR-Backend/trr_backend/db/pg.py`
  - Add `social_control` named pool env vars and allow lightweight read helpers to target a named pool.
- Modify `TRR-Backend/tests/db/test_pg_pool.py`
  - Cover `social_control` pool sizing and `fetch_one`/`fetch_all` named-pool routing.
- Modify `TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py`
  - Route finalization advisory locks and finalizer fallback reads through `social_control`; add a stale active-job reconciliation helper.
- Modify `TRR-Backend/trr_backend/socials/control_plane/run_reads.py`
  - Route run progress reads through `social_control` where they do not already reuse a connection.
- Modify `TRR-Backend/trr_backend/socials/control_plane/shared_status_reads.py`
  - Route live status reads through `social_control`.
- Modify `TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py`
  - Cover finalizer pool routing and stale duplicate active-job reconciliation.
- Modify `TRR-Backend/tests/repositories/test_social_run_reads_repository.py`
  - Cover run progress read routing to `social_control`.
- Create `TRR-Backend/scripts/db/cleanup_stale_social_advisory_locks.py`
  - Dry-run-first operational script that identifies old idle advisory-lock sessions and can terminate them only when their lock key is explicitly allowlisted.
- Create `TRR-Backend/tests/scripts/test_cleanup_stale_social_advisory_locks.py`
  - Unit tests for session selection, allowlist filtering, dry-run, and execute behavior.
- Create `TRR-Backend/scripts/db/social_control_plane_pressure_snapshot.py`
  - Read-only DB pressure snapshot command for before/after verification of pool pressure, wait events, open social jobs, and stale advisory sessions.
- Create `TRR-Backend/tests/scripts/test_social_control_plane_pressure_snapshot.py`
  - Unit tests for snapshot JSON shape and stale advisory-session counts.
- Modify `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Add TikTok near-complete tolerance for empty-body single-runner fallback and preserve strict failure for larger gaps.
- Modify `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  - Add near-complete TikTok tolerance tests and keep existing incomplete-catalog tests strict.
- Modify `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
  - Add a typed warmup exception when the browser warmup does not bridge any cookies.
- Modify `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py`
  - Convert zero-cookie warmup into a terminal job failure before iterating hundreds of target posts.
- Modify `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`
  - Cover zero-cookie warmup failure and verify no per-shortcode fetch happens.
- Create `TRR-Backend/scripts/socials/benchmark_backfill_runtime_methods.py`
  - Small benchmark harness that records equivalent Scrapling and Crawlee backfill attempts, including browser-use evidence links, DB job counts, saved post counts, media counts, runtime seconds, Modal invocation IDs, and failure reasons.
- Create `TRR-Backend/tests/scripts/test_benchmark_backfill_runtime_methods.py`
  - Unit tests for benchmark scoring, typed JSON output, default-method selection, and refusal to select a default when either candidate lacks browser-use evidence.
- Create `TRR-Backend/scripts/socials/run_social_backfill_canaries.py`
  - One-run-per-platform canary wrapper around `scripts/socials/local_catalog_action.py` for Instagram, TikTok, X/Twitter, and Facebook backfill smoke checks.
- Create `TRR-Backend/tests/scripts/test_run_social_backfill_canaries.py`
  - Unit tests for generated per-platform canary commands and fail-fast behavior.
- Modify `TRR-Backend/trr_backend/socials/crawlee_runtime/config.py`
  - Add a single default-method decision surface if benchmark evidence shows Crawlee should replace an existing Scrapling lane, or document no code change when Scrapling remains the better default.
- Modify `TRR-Backend/trr_backend/socials/control_plane/dispatch.py`
  - Route the chosen runtime method through the existing social dispatch contract only after the benchmark task proves the default should change.
- Create `docs/ai/benchmarks/social_backfill_method_comparison.md`
  - Durable benchmark report comparing Scrapling and Crawlee with browser-use screenshots/DOM evidence, selected default, and rollback note.
- Create `docs/ai/benchmarks/social_backfill_method_comparison.json`
  - Typed benchmark evidence artifact consumed by default-selection logic and future comparisons.

---

### Task 1: Add a Dry-Run Stale Run Reconciler

**Files:**
- Create: `TRR-Backend/scripts/socials/reconcile_stale_social_run.py`
- Create: `TRR-Backend/tests/scripts/test_reconcile_stale_social_run.py`

- [ ] **Step 1: Write the failing tests**

Append this test file:

```python
from __future__ import annotations

from dataclasses import dataclass, field

from scripts.socials import reconcile_stale_social_run as subject


@dataclass
class FakePg:
    rows: dict[str, list[dict[str, object]]] = field(default_factory=dict)
    writes: list[tuple[str, list[object]]] = field(default_factory=list)

    def fetch_one(self, query: str, params: list[object]):
        normalized = " ".join(query.lower().split())
        if "from social.scrape_runs" in normalized:
            return {
                "id": "80cf0056-7659-4203-b5f9-0758ee9d98c0",
                "status": "queued",
                "total_jobs": 2,
                "active_jobs": 2,
            }
        return None

    def fetch_all(self, query: str, params: list[object]):
        normalized = " ".join(query.lower().split())
        if "from social.scrape_jobs" in normalized:
            return [
                {
                    "id": "retry-job",
                    "status": "retrying",
                    "job_type": "shared_account_posts",
                    "last_error_code": "shared_stage_failed",
                },
                {
                    "id": "queued-job",
                    "status": "queued",
                    "job_type": "shared_account_posts",
                    "last_error_code": None,
                },
            ]
        return []

    def execute(self, query: str, params: list[object]) -> None:
        self.writes.append((" ".join(query.lower().split()), list(params)))


def test_plan_run_identifies_duplicate_active_jobs_without_writing(monkeypatch):
    fake_pg = FakePg()
    monkeypatch.setattr(subject, "pg", fake_pg)

    result = subject.plan_run_cleanup("80cf0056-7659-4203-b5f9-0758ee9d98c0")

    assert result.run_id == "80cf0056-7659-4203-b5f9-0758ee9d98c0"
    assert result.duplicate_open_job_ids == ["queued-job"]
    assert result.retry_job_ids == ["retry-job"]
    assert fake_pg.writes == []


def test_execute_cleanup_cancels_duplicates_and_recomputes_run(monkeypatch):
    fake_pg = FakePg()
    monkeypatch.setattr(subject, "pg", fake_pg)

    result = subject.execute_run_cleanup("80cf0056-7659-4203-b5f9-0758ee9d98c0")

    assert result.duplicate_open_job_ids == ["queued-job"]
    joined_sql = "\n".join(sql for sql, _params in fake_pg.writes)
    assert "update social.scrape_jobs" in joined_sql
    assert "status = 'cancelled'" in joined_sql
    assert "update social.scrape_runs" in joined_sql
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_reconcile_stale_social_run.py -v
```

Expected: FAIL with `ModuleNotFoundError` or `ImportError` for `scripts.socials.reconcile_stale_social_run`.

- [ ] **Step 3: Implement the minimal reconciler**

Create `TRR-Backend/scripts/socials/reconcile_stale_social_run.py` with:

```python
from __future__ import annotations

import argparse
from dataclasses import dataclass

from trr_backend.db import pg


OPEN_JOB_STATUSES = {"queued", "pending", "retrying", "running", "cancelling"}


@dataclass(frozen=True)
class CleanupPlan:
    run_id: str
    duplicate_open_job_ids: list[str]
    retry_job_ids: list[str]
    run_status: str
    active_jobs: int


def _open_jobs_for_run(run_id: str) -> list[dict[str, object]]:
    return pg.fetch_all(
        """
        select id::text as id, status, job_type, last_error_code
        from social.scrape_jobs
        where run_id = %s::uuid
          and status = any(%s)
        order by created_at asc, id asc
        """,
        [run_id, sorted(OPEN_JOB_STATUSES)],
    )


def plan_run_cleanup(run_id: str) -> CleanupPlan:
    run = pg.fetch_one(
        """
        select id::text as id, status, total_jobs, active_jobs
        from social.scrape_runs
        where id = %s::uuid
        """,
        [run_id],
    )
    if not run:
        raise SystemExit(f"run not found: {run_id}")
    open_jobs = _open_jobs_for_run(run_id)
    by_type: dict[str, list[dict[str, object]]] = {}
    for job in open_jobs:
        by_type.setdefault(str(job.get("job_type") or ""), []).append(job)
    duplicate_ids: list[str] = []
    for jobs in by_type.values():
        if len(jobs) > 1:
            duplicate_ids.extend(str(job["id"]) for job in jobs[1:])
    retry_ids = [str(job["id"]) for job in open_jobs if str(job.get("status")) == "retrying"]
    return CleanupPlan(
        run_id=run_id,
        duplicate_open_job_ids=duplicate_ids,
        retry_job_ids=retry_ids,
        run_status=str(run.get("status") or ""),
        active_jobs=int(run.get("active_jobs") or 0),
    )


def execute_run_cleanup(run_id: str) -> CleanupPlan:
    plan = plan_run_cleanup(run_id)
    if plan.duplicate_open_job_ids:
        pg.execute(
            """
            update social.scrape_jobs
            set status = 'cancelled',
                completed_at = coalesce(completed_at, now()),
                error_message = coalesce(error_message, 'cancelled duplicate open job during stale run cleanup'),
                last_error_code = coalesce(last_error_code, 'duplicate_open_job_cancelled'),
                last_error_class = coalesce(last_error_class, 'StaleRunCleanup')
            where id = any(%s::uuid[])
            """,
            [plan.duplicate_open_job_ids],
        )
    pg.execute(
        """
        update social.scrape_runs
        set active_jobs = greatest(0, active_jobs - %s),
            summary = jsonb_set(
                coalesce(summary, '{}'::jsonb),
                '{cleanup}',
                jsonb_build_object(
                    'source', 'reconcile_stale_social_run',
                    'duplicate_open_jobs_cancelled', %s,
                    'retry_jobs_observed', %s,
                    'cleaned_at', now()
                )
            )
        where id = %s::uuid
        """,
        [len(plan.duplicate_open_job_ids), len(plan.duplicate_open_job_ids), len(plan.retry_job_ids), run_id],
    )
    return plan


def main() -> int:
    parser = argparse.ArgumentParser(description="Reconcile one stale social scrape run.")
    parser.add_argument("run_id")
    parser.add_argument("--execute", action="store_true", help="Apply cleanup writes. Default is dry-run.")
    args = parser.parse_args()
    result = execute_run_cleanup(args.run_id) if args.execute else plan_run_cleanup(args.run_id)
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_reconcile_stale_social_run.py -v
```

Expected: PASS.

- [ ] **Step 5: Run dry-run against the diagnosed Twitter run**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python scripts/socials/reconcile_stale_social_run.py 80cf0056-7659-4203-b5f9-0758ee9d98c0
```

Expected: prints a `CleanupPlan` containing duplicate/open Twitter job information and performs no writes.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/scripts/socials/reconcile_stale_social_run.py TRR-Backend/tests/scripts/test_reconcile_stale_social_run.py
git commit -m "ops: add stale social run reconciler"
```

---

### Task 2: Lower Dev Modal Social Pressure Defaults

**Files:**
- Modify: `profiles/default.env`
- Modify: `scripts/dev-workspace.sh`
- Modify: `scripts/status-workspace.sh`
- Modify: `docs/workspace/env-contract.md`
- Modify: `scripts/check-workspace-contract.sh`
- Modify: `scripts/test_workspace_app_env_projection.py`

- [ ] **Step 1: Write failing assertions for the new defaults**

Update `scripts/test_workspace_app_env_projection.py` assertions that currently expect `25`, `64`, `2`, and `2` so they expect:

```python
assert "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=6" in text
assert "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=12" in text
assert "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1" in text
assert "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=1" in text
```

Update `scripts/check-workspace-contract.sh` expected values:

```bash
assert_equals "profiles/default.env remote social dispatch limit" "6" "$remote_social_dispatch_profile_default"
assert_equals "docs/workspace/env-contract.md remote social dispatch limit" "6" "$remote_social_dispatch_doc_default"
assert_equals "profiles/default.env remote social posts" "1" "$remote_social_posts_profile_default"
assert_equals "docs/workspace/env-contract.md remote social posts" "1" "$remote_social_posts_doc_default"
assert_equals "profiles/default.env remote social comments" "1" "$remote_social_comments_profile_default"
assert_equals "docs/workspace/env-contract.md remote social comments" "1" "$remote_social_comments_doc_default"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
python -m pytest scripts/test_workspace_app_env_projection.py -v
bash scripts/check-workspace-contract.sh
```

Expected: FAIL because files still advertise `25`, `64`, `2`, and `2`.

- [ ] **Step 3: Change workspace defaults**

In `profiles/default.env`, set:

```dotenv
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=6
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=12
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=1
```

In `scripts/dev-workspace.sh`, change the fallback defaults and invalid-value warning fallbacks to:

```bash
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-6}"
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-12}"
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS="${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS="${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-1}"
```

Use matching warning text:

```bash
echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT='${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT}', using 6." >&2
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="6"
echo "[workspace] WARNING: invalid WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT='${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT}', using 12." >&2
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="12"
echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_POSTS='${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS}', using 1." >&2
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS="1"
echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS='${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS}', using 1." >&2
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS="1"
```

In `scripts/status-workspace.sh`, set the same fallback defaults:

```bash
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-6}"
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-12}"
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS="${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS="${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-1}"
```

In `docs/workspace/env-contract.md`, change the default column for these rows:

```markdown
| `WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT` | `12` | integer | `scripts/dev-workspace.sh`, `Makefile` | `advanced` | Maximum concurrent Modal containers allowed for `run_social_job`. |
| `WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS` | `1` | integer | `scripts/dev-workspace.sh`, `Makefile` | `advanced` | Comments-stage cap used by Modal social dispatch and by legacy local social worker mode. |
| `WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT` | `6` | integer | `scripts/dev-workspace.sh`, `Makefile` | `advanced` | Maximum number of queued social jobs the backend will dispatch per Modal sweep. |
| `WORKSPACE_TRR_REMOTE_SOCIAL_POSTS` | `1` | integer | `scripts/dev-workspace.sh`, `Makefile` | `advanced` | Posts-stage cap used by Modal social dispatch and by legacy local social worker mode. |
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
python -m pytest scripts/test_workspace_app_env_projection.py -v
bash scripts/check-workspace-contract.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add profiles/default.env scripts/dev-workspace.sh scripts/status-workspace.sh docs/workspace/env-contract.md scripts/check-workspace-contract.sh scripts/test_workspace_app_env_projection.py
git commit -m "chore: lower dev modal social pressure"
```

---

### Task 3: Add a Dedicated Social Control DB Pool

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py`
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
- Modify: `scripts/workspace-env-contract.sh`
- Modify: `docs/workspace/env-contract.md`
- Modify: `profiles/default.env`
- Modify: `profiles/social-debug.env`
- Modify: `profiles/local-cloud.env`
- Modify: `scripts/check-workspace-contract.sh`

- [ ] **Step 1: Write failing DB pool tests**

Append to `TRR-Backend/tests/db/test_pg_pool.py`:

```python
def test_social_control_pool_uses_social_control_env_names(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TRR_SOCIAL_CONTROL_DB_POOL_MINCONN", "1")
    monkeypatch.setenv("TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN", "2")

    sizing = pg._resolve_pool_sizing("social_control")

    assert sizing["minconn"] == 1
    assert sizing["maxconn"] == 2
    assert sizing["minconn_source"] == "env:TRR_SOCIAL_CONTROL_DB_POOL_MINCONN"
    assert sizing["maxconn_source"] == "env:TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN"


def test_fetch_one_can_use_named_pool(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_pool = _FakeThreadedPool(fetchone_result={"ok": True})
    seen_pool_names: list[str] = []

    def fake_get_pool(pool_name: str = "default"):
        seen_pool_names.append(pool_name)
        return fake_pool

    monkeypatch.setattr(pg, "_get_pool", fake_get_pool)

    row = pg.fetch_one("select 1 as ok", pool_name="social_control")

    assert row == {"ok": True}
    assert seen_pool_names == ["social_control"]
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/db/test_pg_pool.py::test_social_control_pool_uses_social_control_env_names tests/db/test_pg_pool.py::test_fetch_one_can_use_named_pool -v
```

Expected: FAIL because `social_control` env names and `pool_name` on `fetch_one` are not implemented.

- [ ] **Step 3: Implement named pool support**

In `TRR-Backend/trr_backend/db/pg.py`, extend `_pool_size_env_names`:

```python
def _pool_size_env_names(pool_name: str) -> tuple[str, str]:
    if pool_name == "social_profile":
        return "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN", "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN"
    if pool_name == "social_control":
        return "TRR_SOCIAL_CONTROL_DB_POOL_MINCONN", "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN"
    if pool_name == "health":
        return "TRR_HEALTH_DB_POOL_MINCONN", "TRR_HEALTH_DB_POOL_MAXCONN"
    return "TRR_DB_POOL_MINCONN", "TRR_DB_POOL_MAXCONN"
```

Add `pool_name` to `fetch_all` and `fetch_one`:

```python
def fetch_all(
    query: str,
    params: Iterable[Any] | None = None,
    *,
    conn: connection_type | None = None,
    pool_name: str = "default",
) -> list[dict[str, Any]]:
    if conn is not None:
        with db_read_cursor(conn=conn, label="fetch_all") as cur:
            return fetch_all_with_cursor(cur, query, params)

    def _run() -> list[dict[str, Any]]:
        with db_read_connection(label="fetch_all", pool_name=pool_name) as managed_conn:
            with db_read_cursor(conn=managed_conn, label="fetch_all") as cur:
                return fetch_all_with_cursor(cur, query, params)

    return _run_with_transient_retry(_run)


def fetch_one(
    query: str,
    params: Iterable[Any] | None = None,
    *,
    conn: connection_type | None = None,
    pool_name: str = "default",
) -> dict[str, Any] | None:
    if conn is not None:
        with db_read_cursor(conn=conn, label="fetch_one") as cur:
            return fetch_one_with_cursor(cur, query, params)

    def _run() -> dict[str, Any] | None:
        with db_read_connection(label="fetch_one", pool_name=pool_name) as managed_conn:
            with db_read_cursor(conn=managed_conn, label="fetch_one") as cur:
                return fetch_one_with_cursor(cur, query, params)

    return _run_with_transient_retry(_run)
```

- [ ] **Step 4: Add workspace env contract values**

Set the default pool size to min `1`, max `2`:

```dotenv
TRR_SOCIAL_CONTROL_DB_POOL_MINCONN=1
TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2
```

Add those values to:

```text
profiles/default.env
profiles/social-debug.env
profiles/local-cloud.env
```

In `scripts/workspace-env-contract.sh`, include `TRR_SOCIAL_CONTROL_DB_POOL_MINCONN` and `TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN` in the DB pool env rows and descriptions:

```bash
TRR_SOCIAL_CONTROL_DB_POOL_MINCONN)
  echo "Minimum Postgres pool connections reserved for social run/finalize/status control-plane reads."
  ;;
TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN)
  echo "Maximum Postgres pool connections reserved for social run/finalize/status control-plane reads."
  ;;
```

In `docs/workspace/env-contract.md`, add:

```markdown
| `TRR_SOCIAL_CONTROL_DB_POOL_MINCONN` | `1` | integer | `scripts/dev-workspace.sh`, `Makefile` | `advanced` | Minimum Postgres pool connections reserved for social run/finalize/status control-plane reads. |
| `TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN` | `2` | integer | `scripts/dev-workspace.sh`, `Makefile` | `advanced` | Maximum Postgres pool connections reserved for social run/finalize/status control-plane reads. |
```

Update `scripts/check-workspace-contract.sh` to extract and assert these values from default, social-debug, local-cloud, and docs.

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/db/test_pg_pool.py::test_social_control_pool_uses_social_control_env_names tests/db/test_pg_pool.py::test_fetch_one_can_use_named_pool -v
cd /Users/thomashulihan/Projects/TRR
bash scripts/check-workspace-contract.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/db/pg.py TRR-Backend/tests/db/test_pg_pool.py scripts/workspace-env-contract.sh docs/workspace/env-contract.md profiles/default.env profiles/social-debug.env profiles/local-cloud.env scripts/check-workspace-contract.sh
git commit -m "feat: add social control db pool"
```

---

### Task 4: Route Finalization and Status Reads to the Social Control Pool

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py`
- Modify: `TRR-Backend/trr_backend/socials/control_plane/run_reads.py`
- Modify: `TRR-Backend/trr_backend/socials/control_plane/shared_status_reads.py`
- Modify: `TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py`
- Modify: `TRR-Backend/tests/repositories/test_social_run_reads_repository.py`

- [ ] **Step 1: Write failing finalizer pool test**

Update `test_finalize_run_status_reuses_lock_connection_for_all_reads` in `TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py` so the fake advisory lock records the pool name:

```python
seen_lock_pool_names: list[str] = []

@contextmanager
def fake_advisory_lock(lock_key, *, label, pool_name="default"):
    del lock_key, label
    seen_lock_pool_names.append(pool_name)
    yield lock_conn
```

Add this assertion:

```python
assert seen_lock_pool_names == ["social_control"]
```

- [ ] **Step 2: Write failing run reads pool test**

Append to `TRR-Backend/tests/repositories/test_social_run_reads_repository.py`:

```python
def test_get_run_progress_snapshot_uses_social_control_pool_for_initial_run_read(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    seen_pool_names: list[str] = []

    def fake_fetch_one(sql: str, params=None, *, conn=None, pool_name="default"):
        del params, conn
        seen_pool_names.append(pool_name)
        normalized = " ".join(sql.lower().split())
        if "from social.scrape_runs" in normalized:
            return {
                "id": "run-1",
                "status": "running",
                "config": {"pipeline_ingest_mode": "shared_account_catalog_backfill"},
                "summary": {},
            }
        return None

    monkeypatch.setattr(run_reads.legacy.pg, "fetch_one", fake_fetch_one)
    monkeypatch.setattr(run_reads.legacy, "_scrape_jobs_features", lambda: {"has_run_id": True, "has_queue_fields": True})
    monkeypatch.setattr(run_reads.legacy.pg, "fetch_all", lambda *_args, **_kwargs: [])

    payload = run_reads.get_run_progress_snapshot("season-1", "run-1", recent_log_limit=10)

    assert payload["run_id"] == "run-1"
    assert "social_control" in seen_pool_names
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_run_lifecycle_repository.py::test_finalize_run_status_reuses_lock_connection_for_all_reads tests/repositories/test_social_run_reads_repository.py::test_get_run_progress_snapshot_uses_social_control_pool_for_initial_run_read -v
```

Expected: FAIL because finalization and initial run reads still use the default pool.

- [ ] **Step 4: Route finalization through the control pool**

In `run_lifecycle.py`, add a constant near the imports:

```python
SOCIAL_CONTROL_POOL_NAME = "social_control"
```

Change `_finalize_run_status`:

```python
with legacy.pg.advisory_session_lock(
    lock_key,
    label="run-finalize-lock",
    pool_name=SOCIAL_CONTROL_POOL_NAME,
) as lock_conn:
    return _finalize_run_status_locked(run_id, lock_conn, force_recompute=force_recompute)
```

Change the fallback read after `AdvisoryLockUnavailable`:

```python
current = legacy.pg.fetch_one(
    "select status from social.scrape_runs where id = %s",
    [run_id],
    pool_name=SOCIAL_CONTROL_POOL_NAME,
) or {}
```

- [ ] **Step 5: Route run and live-status reads through the control pool**

In `run_reads.py`, for top-level reads that do not already receive `conn=...`, pass:

```python
pool_name=run_lifecycle.SOCIAL_CONTROL_POOL_NAME
```

For example:

```python
run = legacy.pg.fetch_one(
    """
    select ...
    from social.scrape_runs
    where id = %s::uuid
    """,
    [run_id],
    pool_name=run_lifecycle.SOCIAL_CONTROL_POOL_NAME,
) or {}
```

In `shared_status_reads.py`, route live-status summary reads the same way:

```python
rows = legacy.pg.fetch_all(
    """
    select ...
    from social.scrape_runs r
    ...
    """,
    params,
    pool_name=run_lifecycle.SOCIAL_CONTROL_POOL_NAME,
)
```

Keep writes on the default write pool unless they are already inside the finalizer lock connection.

- [ ] **Step 6: Run targeted tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_run_lifecycle_repository.py::test_finalize_run_status_reuses_lock_connection_for_all_reads tests/repositories/test_social_run_reads_repository.py -v
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py TRR-Backend/trr_backend/socials/control_plane/run_reads.py TRR-Backend/trr_backend/socials/control_plane/shared_status_reads.py TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py TRR-Backend/tests/repositories/test_social_run_reads_repository.py
git commit -m "fix: isolate social control plane reads"
```

---

### Task 5: Add DB Pressure Snapshots and Safe Stale Advisory-Lock Cleanup

**Files:**
- Create: `TRR-Backend/scripts/db/cleanup_stale_social_advisory_locks.py`
- Create: `TRR-Backend/tests/scripts/test_cleanup_stale_social_advisory_locks.py`
- Create: `TRR-Backend/scripts/db/social_control_plane_pressure_snapshot.py`
- Create: `TRR-Backend/tests/scripts/test_social_control_plane_pressure_snapshot.py`

- [ ] **Step 1: Write failing advisory cleanup tests**

Create `TRR-Backend/tests/scripts/test_cleanup_stale_social_advisory_locks.py`:

```python
from __future__ import annotations

from dataclasses import dataclass, field

from scripts.db import cleanup_stale_social_advisory_locks as subject


@dataclass
class FakePg:
    terminated: list[int] = field(default_factory=list)

    def fetch_all(self, query: str, params: list[object]):
        normalized = " ".join(query.lower().split())
        assert "pg_stat_activity" in normalized
        assert "pg_try_advisory_lock" in normalized
        assert params == [30, ["658643542"]]
        return [
            {
                "pid": 123,
                "state": "idle in transaction",
                "age_seconds": 3600,
                "query": "select pg_try_advisory_lock(658643542) as locked",
                "lock_key": "658643542",
            },
            {
                "pid": 456,
                "state": "idle in transaction",
                "age_seconds": 3600,
                "query": "select pg_try_advisory_lock(999999999) as locked",
                "lock_key": "999999999",
            }
        ]

    def execute(self, query: str, params: list[object]) -> None:
        normalized = " ".join(query.lower().split())
        assert "select pg_terminate_backend(%s)" in normalized
        self.terminated.append(int(params[0]))


def test_find_stale_advisory_sessions(monkeypatch):
    fake_pg = FakePg()
    monkeypatch.setattr(subject, "pg", fake_pg)

    rows = subject.find_stale_advisory_sessions(min_age_minutes=30, allowed_lock_keys={"658643542"})

    assert len(rows) == 1
    assert rows[0]["pid"] == 123
    assert fake_pg.terminated == []


def test_cleanup_stale_advisory_sessions_requires_execute(monkeypatch):
    fake_pg = FakePg()
    monkeypatch.setattr(subject, "pg", fake_pg)

    count = subject.cleanup_stale_advisory_sessions(
        min_age_minutes=30,
        allowed_lock_keys={"658643542"},
        execute=False,
    )

    assert count == 1
    assert fake_pg.terminated == []


def test_cleanup_stale_advisory_sessions_terminates_when_execute(monkeypatch):
    fake_pg = FakePg()
    monkeypatch.setattr(subject, "pg", fake_pg)

    count = subject.cleanup_stale_advisory_sessions(
        min_age_minutes=30,
        allowed_lock_keys={"658643542"},
        execute=True,
    )

    assert count == 1
    assert fake_pg.terminated == [123]


def test_cleanup_refuses_empty_allowlist(monkeypatch):
    fake_pg = FakePg()
    monkeypatch.setattr(subject, "pg", fake_pg)

    try:
        subject.cleanup_stale_advisory_sessions(min_age_minutes=30, allowed_lock_keys=set(), execute=True)
    except subject.AdvisoryCleanupRefused as exc:
        assert "at least one --lock-key" in str(exc)
    else:
        raise AssertionError("empty allowlist should refuse cleanup")
```

- [ ] **Step 2: Write failing DB pressure snapshot tests**

Create `TRR-Backend/tests/scripts/test_social_control_plane_pressure_snapshot.py`:

```python
from __future__ import annotations

from scripts.db import social_control_plane_pressure_snapshot as subject


class FakePg:
    def fetch_all(self, query: str, params=None, **kwargs):
        normalized = " ".join(query.lower().split())
        if "from pg_stat_activity" in normalized:
            return [
                {
                    "state": "idle in transaction",
                    "wait_event_type": "Client",
                    "wait_event": "ClientRead",
                    "query": "select pg_try_advisory_lock(658643542) as locked",
                    "age_seconds": 3600,
                }
            ]
        if "from social.scrape_jobs" in normalized:
            return [{"platform": "twitter", "status": "retrying", "count": 1}]
        return []


def test_build_snapshot_includes_db_waits_jobs_and_stale_advisory_sessions(monkeypatch):
    monkeypatch.setattr(subject, "pg", FakePg())

    snapshot = subject.build_pressure_snapshot()

    assert snapshot["db_activity"]["total_sessions"] == 1
    assert snapshot["db_activity"]["stale_advisory_lock_sessions"] == 1
    assert snapshot["social_jobs"][0]["platform"] == "twitter"
    assert snapshot["social_jobs"][0]["status"] == "retrying"
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_cleanup_stale_social_advisory_locks.py tests/scripts/test_social_control_plane_pressure_snapshot.py -v
```

Expected: FAIL because the scripts do not exist.

- [ ] **Step 4: Implement allowlisted cleanup**

Create `TRR-Backend/scripts/db/cleanup_stale_social_advisory_locks.py`:

```python
from __future__ import annotations

import argparse
import re

from trr_backend.db import pg


class AdvisoryCleanupRefused(RuntimeError):
    pass


LOCK_KEY_RE = re.compile(r"pg_try_advisory_lock\(([-0-9]+)\)")


def _normalize_lock_keys(values: set[str] | list[str] | tuple[str, ...]) -> set[str]:
    return {str(value).strip() for value in values if str(value).strip()}


def _extract_lock_key(query: object) -> str:
    match = LOCK_KEY_RE.search(str(query or ""))
    return match.group(1) if match else ""


def find_stale_advisory_sessions(*, min_age_minutes: int, allowed_lock_keys: set[str]) -> list[dict[str, object]]:
    allowed = _normalize_lock_keys(allowed_lock_keys)
    if not allowed:
        raise AdvisoryCleanupRefused("Pass at least one --lock-key before advisory cleanup can run.")
    rows = pg.fetch_all(
        """
        select
          pid,
          state,
          extract(epoch from now() - query_start)::int as age_seconds,
          query
        from pg_stat_activity
        where pid <> pg_backend_pid()
          and state in ('idle in transaction', 'idle')
          and query ilike '%pg_try_advisory_lock%'
          and now() - query_start >= make_interval(mins => %s)
        order by query_start asc
        """,
        [min_age_minutes, sorted(allowed)],
    )
    filtered: list[dict[str, object]] = []
    for row in rows:
        lock_key = str(row.get("lock_key") or _extract_lock_key(row.get("query"))).strip()
        if lock_key in allowed:
            filtered.append({**row, "lock_key": lock_key})
    return filtered


def cleanup_stale_advisory_sessions(*, min_age_minutes: int, allowed_lock_keys: set[str], execute: bool) -> int:
    rows = find_stale_advisory_sessions(min_age_minutes=min_age_minutes, allowed_lock_keys=allowed_lock_keys)
    if execute:
        for row in rows:
            pg.execute("select pg_terminate_backend(%s)", [int(row["pid"])])
    return len(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Find or terminate stale advisory-lock sessions.")
    parser.add_argument("--min-age-minutes", type=int, default=30)
    parser.add_argument("--lock-key", action="append", default=[], help="Allowed advisory lock key. Repeat as needed.")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    count = cleanup_stale_advisory_sessions(
        min_age_minutes=args.min_age_minutes,
        allowed_lock_keys=set(args.lock_key),
        execute=args.execute,
    )
    mode = "terminated" if args.execute else "matched"
    print(f"{mode} {count} stale advisory-lock session(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 5: Implement DB pressure snapshot**

Create `TRR-Backend/scripts/db/social_control_plane_pressure_snapshot.py`:

```python
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from trr_backend.db import pg


def _activity_rows() -> list[dict[str, Any]]:
    return pg.fetch_all(
        """
        select
          state,
          wait_event_type,
          wait_event,
          extract(epoch from now() - query_start)::int as age_seconds,
          left(query, 240) as query
        from pg_stat_activity
        where pid <> pg_backend_pid()
        order by query_start nulls last
        limit 50
        """
    )


def _social_job_rows() -> list[dict[str, Any]]:
    return pg.fetch_all(
        """
        select platform, status, count(*)::int as count
        from social.scrape_jobs
        where created_at > now() - interval '36 hours'
          and status in ('queued', 'pending', 'retrying', 'running', 'cancelling')
        group by 1, 2
        order by 1, 2
        """
    )


def build_pressure_snapshot() -> dict[str, Any]:
    activity = _activity_rows()
    stale_advisory = [
        row for row in activity if "pg_try_advisory_lock" in str(row.get("query") or "").lower()
    ]
    return {
        "db_activity": {
            "total_sessions": len(activity),
            "waiting_sessions": sum(1 for row in activity if row.get("wait_event_type")),
            "stale_advisory_lock_sessions": len(stale_advisory),
            "states": sorted({str(row.get("state") or "unknown") for row in activity}),
        },
        "social_jobs": _social_job_rows(),
        "stale_advisory_sessions": stale_advisory,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture a social control-plane DB pressure snapshot.")
    parser.add_argument("--output", required=True, help="Path to write JSON snapshot.")
    args = parser.parse_args()
    snapshot = build_pressure_snapshot()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n")
    print(f"wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 6: Run tests and dry-run commands**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_cleanup_stale_social_advisory_locks.py tests/scripts/test_social_control_plane_pressure_snapshot.py -v
python scripts/db/cleanup_stale_social_advisory_locks.py --min-age-minutes 30 --lock-key 658643542
python scripts/db/social_control_plane_pressure_snapshot.py --output ../docs/ai/benchmarks/social_control_pressure_before.json
```

Expected: pytest PASS; advisory cleanup prints `matched N stale advisory-lock session(s)` and does not terminate sessions; pressure snapshot writes `docs/ai/benchmarks/social_control_pressure_before.json`.

- [ ] **Step 7: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/scripts/db/cleanup_stale_social_advisory_locks.py TRR-Backend/tests/scripts/test_cleanup_stale_social_advisory_locks.py TRR-Backend/scripts/db/social_control_plane_pressure_snapshot.py TRR-Backend/tests/scripts/test_social_control_plane_pressure_snapshot.py
git commit -m "ops: add social db pressure tools"
```

---

### Task 6: Fix TikTok Near-Complete Empty-Body Fallback Behavior

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write failing near-complete tolerance test**

Append near the existing `_run_shared_account_posts_stage` TikTok fallback tests in `TRR-Backend/tests/repositories/test_social_season_analytics.py`:

```python
def test_run_shared_account_posts_stage_tolerates_tiktok_empty_body_near_complete_fallback(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    rows = [{"source_id": str(index), "posted_at": "2026-01-01T00:00:00Z"} for index in range(269)]

    monkeypatch.setattr(
        social_repo,
        "_scrape_shared_posts_for_account",
        lambda **_kwargs: (
            rows,
            {
                "retrieval_mode": "ytdlp",
                "posts_checked": 269,
                "total_posts": 272,
                "persist_counters": {"posts_upserted": 269, "comments_upserted": 0},
            },
        ),
    )
    monkeypatch.setattr(social_repo, "_touch_shared_account_source", lambda **_kwargs: None)
    monkeypatch.setattr(social_repo, "_emit_job_progress", lambda **_kwargs: None)
    monkeypatch.setattr(social_repo, "_shared_account_frontier_progress", lambda **_kwargs: {})

    posts_count, comments_count, metadata = social_repo._run_shared_account_posts_stage(
        run_id="run-1",
        platform="tiktok",
        source_scope="bravo",
        account_handle="thetraitorsus",
        config={
            "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
            "runner_strategy": "single_runner_fallback",
            "recovery_reason": "tiktok_empty_body_transport_failure",
            "expected_total_posts": 272,
            "completion_target_posts": 272,
        },
        job_id="job-1",
    )

    assert posts_count == 269
    assert comments_count == 0
    assert metadata["retrieval_meta"]["completion_tolerance_applied"] is True
    assert metadata["retrieval_meta"]["completion_missing_posts"] == 3
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tolerates_tiktok_empty_body_near_complete_fallback tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_raises_for_incomplete_single_runner_fallback -v
```

Expected: new test FAILS with `catalog_incomplete`; existing strict test PASSES.

- [ ] **Step 3: Add bounded tolerance helper**

In `social_season_analytics.py`, add near `_run_shared_account_posts_stage`:

```python
def _tiktok_empty_body_fallback_completion_tolerance(expected_total: int) -> int:
    if expected_total <= 0:
        return 0
    percent_tolerance = max(1, int(round(expected_total * 0.02)))
    return min(5, percent_tolerance)
```

Replace the single-runner incomplete check with:

```python
    if (
        str(config.get("runner_strategy") or "").strip().lower() == "single_runner_fallback"
        and completion_target_posts > 0
        and max(scraped_posts, saved_posts) < completion_target_posts
    ):
        missing_posts = completion_target_posts - max(scraped_posts, saved_posts)
        tolerance = 0
        if (
            normalized_platform == "tiktok"
            and str(config.get("recovery_reason") or "").strip().lower() == "tiktok_empty_body_transport_failure"
        ):
            tolerance = _tiktok_empty_body_fallback_completion_tolerance(completion_target_posts)
        if missing_posts <= tolerance:
            retrieval_meta["completion_tolerance_applied"] = True
            retrieval_meta["completion_missing_posts"] = missing_posts
            retrieval_meta["completion_tolerance_posts"] = tolerance
        else:
            raise SharedStageRuntimeError(
                (
                    f"Shared-account fallback ended early for @{account_handle}: "
                    f"checked {scraped_posts} of {completion_target_posts} discovered posts"
                ),
                error_code="catalog_incomplete",
                retryable=True,
                runtime_metadata={
                    "retrieval_meta": {
                        **dict(retrieval_meta or {}),
                        "expected_total_posts": expected_total_posts,
                        "completion_target_posts": completion_target_posts,
                        "observed_posts_checked": scraped_posts,
                        "observed_posts_saved": saved_posts,
                        "completion_missing_posts": missing_posts,
                        "completion_tolerance_posts": tolerance,
                    }
                },
            )
```

- [ ] **Step 4: Run targeted tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tolerates_tiktok_empty_body_near_complete_fallback tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_raises_for_incomplete_single_runner_fallback tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tiktok_transport_fallback_allows_source_total_drift -v
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: tolerate near-complete tiktok fallback catalogs"
```

---

### Task 7: Fail Instagram Comments Warmup Before Iterating Targets

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`

- [ ] **Step 1: Write failing fetcher test**

Append to `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`:

```python
def test_warmup_raises_when_no_cookies_are_bridged(monkeypatch: pytest.MonkeyPatch) -> None:
    fetcher = _build_fetcher()

    class Response:
        status_code = 200
        text = "<html></html>"
        headers = {}
        cookies = {}

    async def fake_fetch_page(*_args, **_kwargs):
        return Response()

    monkeypatch.setattr(fetcher, "_fetch_page", fake_fetch_page)
    monkeypatch.setattr(fetcher, "_merge_warmup_cookies", lambda _response: None)

    with pytest.raises(InstagramCommentsWarmupError) as exc_info:
        asyncio.run(fetcher.warmup())

    assert exc_info.value.error_code == "instagram_comments_warmup_no_cookies"
```

- [ ] **Step 2: Write failing job runner test**

Append to the same test file:

```python
def test_comments_job_runner_stops_before_targets_when_warmup_has_no_cookies(monkeypatch: pytest.MonkeyPatch) -> None:
    from trr_backend.socials.instagram.comments_scrapling import job_runner as jr

    fetch_calls: list[str] = []

    class FakeFetcher:
        @property
        def runtime_metadata(self):
            return {"warmup_cookie_count": 0}

        async def warmup(self) -> None:
            raise jr.InstagramCommentsWarmupError(
                "Instagram comments warmup did not bridge cookies.",
                error_code="instagram_comments_warmup_no_cookies",
            )

        async def fetch_comments_for_shortcode(self, shortcode, **_kwargs):
            fetch_calls.append(shortcode)
            raise AssertionError("per-shortcode fetch should not run after failed warmup")

        async def close(self) -> None:
            return None

    monkeypatch.setattr(jr, "InstagramCommentsScraplingFetcher", lambda **_: FakeFetcher())
    monkeypatch.setattr(jr, "resolve_comments_scrapling_session", lambda **_kwargs: _fake_comments_session())
    monkeypatch.setattr(jr, "select_comments_proxy", lambda **_kwargs: None)
    monkeypatch.setattr(jr.repo, "_finish_scrape_job", lambda **kwargs: kwargs)

    result = jr.run_instagram_comments_scrapling_job(
        {
            "id": "job-1",
            "config": {
                "account": "thetraitorsus",
                "target_source_ids": ["DXXAP-Ekb59", "DXP6_XsClha"],
                "stage": "comments_scrapling",
            },
        },
        worker_id="worker-1",
    )

    assert fetch_calls == []
    assert result["last_error_code"] == "instagram_comments_warmup_no_cookies"
```

If `_fake_comments_session()` does not exist in the file, add:

```python
def _fake_comments_session():
    from types import SimpleNamespace

    return SimpleNamespace(
        cookies=[],
        raw_cookies={},
        browser_account_id="thetraitorsus",
        auth_session=SimpleNamespace(cookies={}, metadata={}),
    )
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/socials/test_instagram_comments_scrapling_retry.py::test_warmup_raises_when_no_cookies_are_bridged tests/socials/test_instagram_comments_scrapling_retry.py::test_comments_job_runner_stops_before_targets_when_warmup_has_no_cookies -v
```

Expected: FAIL because `InstagramCommentsWarmupError` is not defined and warmup does not fail on zero bridged cookies.

- [ ] **Step 4: Add typed warmup failure**

In `fetcher.py`, add near imports/classes:

```python
class InstagramCommentsWarmupError(RuntimeError):
    def __init__(self, message: str, *, error_code: str, retryable: bool = False) -> None:
        super().__init__(message)
        self.error_code = error_code
        self.retryable = retryable
```

Update `warmup()`:

```python
        if _status_code(response) in {401, 403} or _auth_failure_text(text):
            raise InstagramCommentsWarmupError(
                "Instagram auth warm-up failed; session appears logged out or challenged.",
                error_code="instagram_comments_warmup_auth_failed",
                retryable=False,
            )
        self._merge_warmup_cookies(response)
        if not self._warmup_cookie_delta:
            raise InstagramCommentsWarmupError(
                "Instagram comments warmup did not bridge cookies.",
                error_code="instagram_comments_warmup_no_cookies",
                retryable=False,
            )
        await self._rebuild_http_client()
```

Export/import it in `job_runner.py`:

```python
from trr_backend.socials.instagram.comments_scrapling.fetcher import (
    InstagramCommentsScraplingFetcher,
    InstagramCommentsWarmupError,
)
```

Catch it immediately around `await fetcher.warmup()`:

```python
            try:
                await fetcher.warmup()
            except InstagramCommentsWarmupError as exc:
                raise CommentsScraplingRuntimeError(
                    str(exc),
                    error_code=exc.error_code,
                    retryable=exc.retryable,
                    runtime_metadata={"fetcher_runtime": fetcher.runtime_metadata},
                ) from exc
```

- [ ] **Step 5: Run targeted tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/socials/test_instagram_comments_scrapling_retry.py::test_warmup_raises_when_no_cookies_are_bridged tests/socials/test_instagram_comments_scrapling_retry.py::test_comments_job_runner_stops_before_targets_when_warmup_has_no_cookies -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py
git commit -m "fix: fail instagram comments warmup without cookies"
```

---

### Task 8: Browser-Use Runtime Method Benchmark and Default Selection

**Files:**
- Create: `TRR-Backend/scripts/socials/benchmark_backfill_runtime_methods.py`
- Create: `TRR-Backend/tests/scripts/test_benchmark_backfill_runtime_methods.py`
- Modify: `TRR-Backend/trr_backend/socials/crawlee_runtime/config.py`
- Modify: `TRR-Backend/trr_backend/socials/control_plane/dispatch.py`
- Create: `docs/ai/benchmarks/social_backfill_method_comparison.md`
- Create: `docs/ai/benchmarks/social_backfill_method_comparison.json`

- [ ] **Step 1: Write failing benchmark scorer tests**

Create `TRR-Backend/tests/scripts/test_benchmark_backfill_runtime_methods.py`:

```python
from __future__ import annotations

import json
from pathlib import Path

from scripts.socials import benchmark_backfill_runtime_methods as subject


def test_score_candidate_prefers_complete_media_and_lower_runtime() -> None:
    scrapling = subject.CandidateResult(
        method="scrapling",
        platform="instagram",
        account="thetraitorsus",
        posts_saved=324,
        expected_posts=324,
        media_saved=310,
        comments_saved=1200,
        runtime_seconds=900.0,
        db_pool_errors=0,
        modal_invocations=2,
        modal_invocation_ids=["fc-scrapling-1", "fc-scrapling-2"],
        browser_evidence_path="docs/ai/benchmarks/evidence/scrapling-instagram.png",
        failure_reason=None,
    )
    crawlee = subject.CandidateResult(
        method="crawlee",
        platform="instagram",
        account="thetraitorsus",
        posts_saved=324,
        expected_posts=324,
        media_saved=324,
        comments_saved=1200,
        runtime_seconds=600.0,
        db_pool_errors=0,
        modal_invocations=2,
        modal_invocation_ids=["fc-crawlee-1", "fc-crawlee-2"],
        browser_evidence_path="docs/ai/benchmarks/evidence/crawlee-instagram.png",
        failure_reason=None,
    )

    winner = subject.select_default_method([scrapling, crawlee])

    assert winner.method == "crawlee"
    assert winner.score > scrapling.score


def test_select_default_rejects_missing_browser_use_evidence() -> None:
    result = subject.CandidateResult(
        method="crawlee",
        platform="twitter",
        account="thetraitorsus",
        posts_saved=324,
        expected_posts=324,
        media_saved=300,
        comments_saved=800,
        runtime_seconds=400.0,
        db_pool_errors=0,
        modal_invocations=1,
        modal_invocation_ids=["fc-twitter-1"],
        browser_evidence_path=None,
        failure_reason=None,
    )

    try:
        subject.select_default_method([result])
    except subject.BenchmarkEvidenceError as exc:
        assert "browser-use evidence" in str(exc)
    else:
        raise AssertionError("missing browser-use evidence should block default selection")


def test_write_results_json_preserves_modal_invocation_ids(tmp_path: Path) -> None:
    result = subject.CandidateResult(
        method="crawlee",
        platform="instagram",
        account="thetraitorsus",
        posts_saved=324,
        expected_posts=324,
        media_saved=324,
        comments_saved=1200,
        runtime_seconds=600.0,
        db_pool_errors=0,
        modal_invocations=2,
        modal_invocation_ids=["fc-crawlee-1", "fc-crawlee-2"],
        browser_evidence_path="docs/ai/benchmarks/evidence/crawlee-instagram.png",
        failure_reason=None,
    )
    output_path = tmp_path / "benchmark.json"

    subject.write_results_json(output_path, results=[result], winner=result)

    payload = json.loads(output_path.read_text())
    assert payload["winner"]["method"] == "crawlee"
    assert payload["results"][0]["modal_invocation_ids"] == ["fc-crawlee-1", "fc-crawlee-2"]
    assert payload["results"][0]["score"] == result.score
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_benchmark_backfill_runtime_methods.py -v
```

Expected: FAIL because `scripts.socials.benchmark_backfill_runtime_methods` does not exist.

- [ ] **Step 3: Implement benchmark data model and scoring**

Create `TRR-Backend/scripts/socials/benchmark_backfill_runtime_methods.py`:

```python
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class BenchmarkEvidenceError(RuntimeError):
    pass


@dataclass(frozen=True)
class CandidateResult:
    method: str
    platform: str
    account: str
    posts_saved: int
    expected_posts: int
    media_saved: int
    comments_saved: int
    runtime_seconds: float
    db_pool_errors: int
    modal_invocations: int
    modal_invocation_ids: list[str]
    browser_evidence_path: str | None
    failure_reason: str | None

    @property
    def completeness_ratio(self) -> float:
        if self.expected_posts <= 0:
            return 0.0
        return min(1.0, max(0.0, self.posts_saved / self.expected_posts))

    @property
    def score(self) -> float:
        if self.failure_reason:
            return 0.0
        completeness = self.completeness_ratio * 50.0
        media = min(20.0, self.media_saved / max(1, self.expected_posts) * 20.0)
        comments = min(10.0, self.comments_saved / max(1, self.expected_posts) * 2.0)
        speed = max(0.0, 15.0 - (self.runtime_seconds / 120.0))
        pressure = max(0.0, 5.0 - float(self.db_pool_errors))
        return completeness + media + comments + speed + pressure

    def to_json_dict(self) -> dict[str, Any]:
        return {
            "method": self.method,
            "platform": self.platform,
            "account": self.account,
            "posts_saved": self.posts_saved,
            "expected_posts": self.expected_posts,
            "media_saved": self.media_saved,
            "comments_saved": self.comments_saved,
            "runtime_seconds": self.runtime_seconds,
            "db_pool_errors": self.db_pool_errors,
            "modal_invocations": self.modal_invocations,
            "modal_invocation_ids": list(self.modal_invocation_ids),
            "browser_evidence_path": self.browser_evidence_path,
            "failure_reason": self.failure_reason,
            "completeness_ratio": self.completeness_ratio,
            "score": self.score,
        }


def select_default_method(results: list[CandidateResult]) -> CandidateResult:
    if not results:
        raise BenchmarkEvidenceError("no benchmark candidates supplied")
    missing_evidence = [result for result in results if not result.browser_evidence_path]
    if missing_evidence:
        methods = ", ".join(sorted({result.method for result in missing_evidence}))
        raise BenchmarkEvidenceError(f"missing browser-use evidence for: {methods}")
    complete_results = [result for result in results if result.completeness_ratio >= 0.98 and not result.failure_reason]
    if not complete_results:
        raise BenchmarkEvidenceError("no candidate reached the 98 percent completeness gate")
    return sorted(complete_results, key=lambda result: result.score, reverse=True)[0]


def write_results_json(path: Path, *, results: list[CandidateResult], winner: CandidateResult) -> None:
    payload = {
        "winner": winner.to_json_dict(),
        "results": [result.to_json_dict() for result in results],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
```

- [ ] **Step 4: Run scorer tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_benchmark_backfill_runtime_methods.py -v
```

Expected: PASS.

- [ ] **Step 5: Dispatch subagents for parallel runtime trials**

Use `superpowers:subagent-driven-development` for this task. Dispatch one fresh subagent per method so the measurements do not bias each other:

```text
Subagent A ownership:
- Method: Scrapling
- Browser tool: @browser-use with in-app browser backend
- URL: http://admin.localhost:3000/social/twitter/thetraitorsus and the matching Instagram/TikTok/Facebook profile pages when available
- Responsibility: launch or observe equivalent backfill actions using the current Scrapling-capable lanes, record screenshots/DOM evidence, collect run id, runtime seconds, posts saved, media saved, comments saved, DB pool errors, Modal invocation count, Modal invocation IDs, and failure reason. If a platform has no Scrapling lane, record `unsupported_by_current_code` for that platform instead of inventing a fake comparison.
- Output file: docs/ai/benchmarks/social_backfill_method_comparison.md section "Scrapling Trial"

Subagent B ownership:
- Method: Crawlee
- Browser tool: @browser-use with in-app browser backend
- URL: http://admin.localhost:3000/social/twitter/thetraitorsus and the matching Instagram/TikTok/Facebook profile pages when available
- Responsibility: launch or observe equivalent backfill actions with Crawlee enabled for the same platform/account/task shape, record screenshots/DOM evidence, collect run id, runtime seconds, posts saved, media saved, comments saved, DB pool errors, Modal invocation count, Modal invocation IDs, and failure reason.
- Output file: docs/ai/benchmarks/social_backfill_method_comparison.md section "Crawlee Trial"
```

Both subagents must use the Browser Use plugin, not macOS `open`, shell-only checks, or generic Playwright. Each subagent must include at least one screenshot path or DOM snapshot evidence path from the in-app browser showing the run status/progress page used for measurement.

- [ ] **Step 6: Record benchmark report**

Create `docs/ai/benchmarks/social_backfill_method_comparison.md` with this exact structure:

```markdown
# Social Backfill Runtime Method Comparison

## Scope

- Account: `thetraitorsus`
- Platforms checked: Instagram, TikTok, X/Twitter, Facebook where the admin profile and configured runtime method are available.
- Candidate methods: Scrapling and Crawlee.
- Browser evidence tool: `@browser-use` in-app browser backend.

## Decision Rule

The default method must satisfy all gates:
- At least 98 percent post completeness for the tested account/platform.
- No missing media class that the competing method saved.
- No increase in DB pool errors compared with the competing method.
- No long-lived `live-status/stream` or profile summary timeout during the trial.
- Browser-use evidence is present for the run status/progress page.

If both methods pass, choose the higher benchmark score from `scripts/socials/benchmark_backfill_runtime_methods.py`.

## Scrapling Trial

- Browser evidence:
- Run ids:
- Runtime seconds:
- Posts saved / expected:
- Media saved:
- Comments saved:
- DB pool errors:
- Modal invocations:
- Modal invocation IDs:
- Failure reason:

## Crawlee Trial

- Browser evidence:
- Run ids:
- Runtime seconds:
- Posts saved / expected:
- Media saved:
- Comments saved:
- DB pool errors:
- Modal invocations:
- Modal invocation IDs:
- Failure reason:

## Typed JSON Evidence

- Path: `docs/ai/benchmarks/social_backfill_method_comparison.json`
- Winner method:
- Candidate count:
- Modal invocation IDs present for every Modal-backed candidate:
- Browser evidence present for every default-eligible candidate:

## Selected Default

- Method:
- Why this method won:
- Platforms where default changes:
- Platforms where default stays unchanged:

## Rollback

To roll back, revert the runtime default change in `TRR-Backend/trr_backend/socials/crawlee_runtime/config.py` and `TRR-Backend/trr_backend/socials/control_plane/dispatch.py`, then restart `make dev`.
```

- [ ] **Step 7: Make the winning method the default only after evidence passes**

If Crawlee wins for a platform, change only that platform's default runtime decision in `TRR-Backend/trr_backend/socials/crawlee_runtime/config.py` and route the dispatch decision through `TRR-Backend/trr_backend/socials/control_plane/dispatch.py`. If Scrapling wins, keep or make Scrapling the default for that platform. If a platform lacks a real Scrapling or Crawlee implementation, do not change its default; record `unsupported_by_current_code` in the benchmark report. Keep the losing method available behind an explicit env/config override.

Use this decision rule in code:

```python
BENCHMARK_APPROVED_RUNTIME_DEFAULTS: dict[str, str] = {
    # Fill only with methods proven by docs/ai/benchmarks/social_backfill_method_comparison.md.
    # Example after evidence: "instagram": "scrapling" or "instagram": "crawlee".
}


def default_runtime_method_for_platform(platform: str) -> str:
    normalized = (platform or "").strip().lower()
    platform_override = os.getenv(f"SOCIAL_{normalized.upper()}_RUNTIME_METHOD")
    if platform_override:
        return platform_override.strip().lower()
    if normalized in BENCHMARK_APPROVED_RUNTIME_DEFAULTS:
        return BENCHMARK_APPROVED_RUNTIME_DEFAULTS[normalized]
    return os.getenv("SOCIAL_DEFAULT_RUNTIME_METHOD", "legacy").strip().lower()
```

If no candidate has browser-use evidence, do not change the runtime default. Instead, record the no-change decision in `docs/ai/benchmarks/social_backfill_method_comparison.md`.

- [ ] **Step 8: Run benchmark tests and verify report exists**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_benchmark_backfill_runtime_methods.py -v
cd /Users/thomashulihan/Projects/TRR
test -s docs/ai/benchmarks/social_backfill_method_comparison.md
test -s docs/ai/benchmarks/social_backfill_method_comparison.json
```

Expected: pytest PASS and both benchmark artifacts exist.

- [ ] **Step 9: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/scripts/socials/benchmark_backfill_runtime_methods.py TRR-Backend/tests/scripts/test_benchmark_backfill_runtime_methods.py TRR-Backend/trr_backend/socials/crawlee_runtime/config.py TRR-Backend/trr_backend/socials/control_plane/dispatch.py docs/ai/benchmarks/social_backfill_method_comparison.md docs/ai/benchmarks/social_backfill_method_comparison.json
git commit -m "test: benchmark social runtime methods"
```

---

### Task 9: Add One-Run Backfill Canary Wrapper

**Files:**
- Create: `TRR-Backend/scripts/socials/run_social_backfill_canaries.py`
- Create: `TRR-Backend/tests/scripts/test_run_social_backfill_canaries.py`

- [ ] **Step 1: Write failing canary command tests**

Create `TRR-Backend/tests/scripts/test_run_social_backfill_canaries.py`:

```python
from __future__ import annotations

from scripts.socials import run_social_backfill_canaries as subject


def test_build_canary_commands_includes_one_command_per_required_platform() -> None:
    commands = subject.build_canary_commands(account="thetraitorsus")

    platforms = [command[command.index("--platform") + 1] for command in commands]
    assert platforms == ["instagram", "tiktok", "twitter", "facebook"]
    for command in commands:
        assert command[:2] == [subject.sys.executable, "scripts/socials/local_catalog_action.py"]
        assert command[command.index("--account") + 1] == "thetraitorsus"
        assert command[command.index("--action") + 1] == "backfill"
        assert command.count("--selected-task") == 1
        assert command[command.index("--selected-task") + 1] == "post_details"


def test_run_canaries_stops_on_first_failure(monkeypatch) -> None:
    calls: list[list[str]] = []

    class Result:
        def __init__(self, returncode: int) -> None:
            self.returncode = returncode

    def fake_run(command, cwd, check):  # noqa: ARG001
        calls.append(command)
        return Result(returncode=1)

    monkeypatch.setattr(subject.subprocess, "run", fake_run)

    exit_code = subject.run_canaries(account="thetraitorsus")

    assert exit_code == 1
    assert len(calls) == 1
    assert "--platform" in calls[0]
    assert calls[0][calls[0].index("--platform") + 1] == "instagram"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_run_social_backfill_canaries.py -v
```

Expected: FAIL because `scripts.socials.run_social_backfill_canaries` does not exist.

- [ ] **Step 3: Implement canary wrapper**

Create `TRR-Backend/scripts/socials/run_social_backfill_canaries.py`:

```python
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
BACKEND_ROOT = REPO_ROOT / "TRR-Backend"
CANARY_PLATFORMS = ["instagram", "tiktok", "twitter", "facebook"]


def build_canary_commands(*, account: str) -> list[list[str]]:
    commands: list[list[str]] = []
    for platform in CANARY_PLATFORMS:
        commands.append(
            [
                sys.executable,
                "scripts/socials/local_catalog_action.py",
                "--platform",
                platform,
                "--account",
                account,
                "--source-scope",
                "bravo",
                "--action",
                "backfill",
                "--selected-task",
                "post_details",
            ]
        )
    return commands


def run_canaries(*, account: str) -> int:
    for command in build_canary_commands(account=account):
        print(json.dumps({"running": command}, sort_keys=True))
        result = subprocess.run(command, cwd=BACKEND_ROOT, check=False)
        if result.returncode != 0:
            print(json.dumps({"failed": command, "returncode": result.returncode}, sort_keys=True))
            return int(result.returncode)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run one post-details backfill canary per social platform.")
    parser.add_argument("--account", default="thetraitorsus")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    commands = build_canary_commands(account=args.account)
    if args.dry_run:
        print(json.dumps({"commands": commands}, indent=2))
        return 0
    return run_canaries(account=args.account)


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run canary wrapper tests and dry-run**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_run_social_backfill_canaries.py -v
python scripts/socials/run_social_backfill_canaries.py --account thetraitorsus --dry-run
```

Expected: pytest PASS; dry-run JSON contains exactly four commands, one each for `instagram`, `tiktok`, `twitter`, and `facebook`.

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/scripts/socials/run_social_backfill_canaries.py TRR-Backend/tests/scripts/test_run_social_backfill_canaries.py
git commit -m "test: add social backfill canaries"
```

---

### Task 10: Verification Pass

**Files:**
- No source files changed in this task.

- [ ] **Step 1: Run focused backend tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest \
  tests/scripts/test_reconcile_stale_social_run.py \
  tests/scripts/test_cleanup_stale_social_advisory_locks.py \
  tests/scripts/test_social_control_plane_pressure_snapshot.py \
  tests/scripts/test_run_social_backfill_canaries.py \
  tests/db/test_pg_pool.py \
  tests/repositories/test_social_run_lifecycle_repository.py \
  tests/repositories/test_social_run_reads_repository.py \
  tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tolerates_tiktok_empty_body_near_complete_fallback \
  tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_raises_for_incomplete_single_runner_fallback \
  tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tiktok_transport_fallback_allows_source_total_drift \
  tests/socials/test_instagram_comments_scrapling_retry.py::test_warmup_raises_when_no_cookies_are_bridged \
  tests/socials/test_instagram_comments_scrapling_retry.py::test_comments_job_runner_stops_before_targets_when_warmup_has_no_cookies \
  tests/scripts/test_benchmark_backfill_runtime_methods.py \
  -v
```

Expected: PASS.

- [ ] **Step 2: Run workspace contract checks**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
python -m pytest scripts/test_workspace_app_env_projection.py -v
bash scripts/check-workspace-contract.sh
bash scripts/status-workspace.sh | sed -n '1,75p'
```

Expected: tests PASS; status output shows `dispatch_limit=6`, `max_concurrency=12`, `posts=1`, `comments=1`.

- [ ] **Step 3: Dry-run operational cleanup commands**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python scripts/socials/reconcile_stale_social_run.py 80cf0056-7659-4203-b5f9-0758ee9d98c0
python scripts/db/cleanup_stale_social_advisory_locks.py --min-age-minutes 30 --lock-key 658643542
python scripts/db/social_control_plane_pressure_snapshot.py --output ../docs/ai/benchmarks/social_control_pressure_before.json
python scripts/socials/run_social_backfill_canaries.py --account thetraitorsus --dry-run
```

Expected: cleanup commands print dry-run summaries and perform no writes; DB pressure snapshot writes `docs/ai/benchmarks/social_control_pressure_before.json`; canary dry-run prints one command per platform.

- [ ] **Step 4: Run one canary per platform**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python scripts/socials/run_social_backfill_canaries.py --account thetraitorsus
```

Expected: the command executes one `post_details` backfill canary for `instagram`, `tiktok`, `twitter`, and `facebook`, stopping at the first failure. Each successful platform prints JSON from `scripts/socials/local_catalog_action.py` containing `run_id`, `executed_run_ids`, and `status`.

- [ ] **Step 5: Browser smoke after restart**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

Open `http://admin.localhost:3000/social/twitter/thetraitorsus`.

Expected:
- Backend health in `scripts/status-workspace.sh` is no longer `hung/unresponsive`.
- Twitter profile summary no longer returns a 60s `504`.
- Live status stream no longer accumulates 5-10 minute body timeouts.
- New backfill launch shows one active Twitter posts job for one account, not duplicate active posts jobs for the same run/stage.
- Browser-use benchmark evidence exists for Scrapling and Crawlee in `docs/ai/benchmarks/social_backfill_method_comparison.md`, and any runtime default change matches the selected winner.

- [ ] **Step 6: Capture after-pressure snapshot**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python scripts/db/social_control_plane_pressure_snapshot.py --output ../docs/ai/benchmarks/social_control_pressure_after.json
```

Expected: writes `docs/ai/benchmarks/social_control_pressure_after.json`. Compare it with `social_control_pressure_before.json`; `db_activity.stale_advisory_lock_sessions` should not increase, and active/retrying social job counts should not show duplicate jobs for the same platform/account/run shape.

- [ ] **Step 7: Commit verification notes if a repo doc changed during execution**

If execution adds a short evidence note, commit only that evidence file:

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/ai/local-status/social-backfill-control-plane-pressure.md
git commit -m "docs: record social backfill stabilization evidence"
```

Do not create this evidence file during implementation unless the worker captured live verification output worth preserving.

---

### Task 11: Apply Reviewed Work to Local Main

**Files:**
- No source files changed in this task.

- [ ] **Step 1: Confirm the implementation branch is clean and complete**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
git branch --show-current
git log --oneline --decorate --max-count=12
```

Expected: `git status --short` prints nothing, the current branch is the implementation branch such as `social-backfill-control-plane-pressure`, and the log includes the task commits from this plan.

- [ ] **Step 2: Run final branch diff checks before integration**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git diff --stat main...HEAD
git diff --check main...HEAD
```

Expected: `git diff --stat` shows only the planned files from this document, and `git diff --check` prints nothing.

After these commands pass, dispatch the final code-quality reviewer subagent required by `superpowers:subagent-driven-development`. Give the reviewer the full branch diff against `main`, the plan file path, and the Task 10 verification output. Do not continue until the final reviewer reports that the complete implementation is approved for integration.

- [ ] **Step 3: Switch to local main and update it**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git checkout main
git pull --ff-only
```

Expected: checkout succeeds and `main` is current. If `git pull --ff-only` fails, stop before merging and resolve the upstream divergence outside this task.

- [ ] **Step 4: Merge the reviewed implementation branch into main**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git merge --no-ff social-backfill-control-plane-pressure
```

Expected: merge succeeds and creates a merge commit on `main`.

If merge conflicts occur, run:

```bash
cd /Users/thomashulihan/Projects/TRR
git merge --abort
git checkout social-backfill-control-plane-pressure
```

Expected: the repository returns to the implementation branch. Reconcile `main` into the implementation branch, re-run Tasks 10 and 11 Steps 1-2, re-dispatch the final reviewer, and retry the merge only after the branch is reviewed again.

- [ ] **Step 5: Run final smoke tests on main**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest \
  tests/scripts/test_reconcile_stale_social_run.py \
  tests/scripts/test_cleanup_stale_social_advisory_locks.py \
  tests/scripts/test_social_control_plane_pressure_snapshot.py \
  tests/scripts/test_run_social_backfill_canaries.py \
  tests/db/test_pg_pool.py \
  tests/repositories/test_social_run_lifecycle_repository.py \
  tests/repositories/test_social_run_reads_repository.py \
  tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tolerates_tiktok_empty_body_near_complete_fallback \
  tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_raises_for_incomplete_single_runner_fallback \
  tests/repositories/test_social_season_analytics.py::test_run_shared_account_posts_stage_tiktok_transport_fallback_allows_source_total_drift \
  tests/socials/test_instagram_comments_scrapling_retry.py::test_warmup_raises_when_no_cookies_are_bridged \
  tests/socials/test_instagram_comments_scrapling_retry.py::test_comments_job_runner_stops_before_targets_when_warmup_has_no_cookies \
  tests/scripts/test_benchmark_backfill_runtime_methods.py \
  -v
cd /Users/thomashulihan/Projects/TRR
python -m pytest scripts/test_workspace_app_env_projection.py -v
bash scripts/check-workspace-contract.sh
```

Expected: all focused backend tests and workspace contract checks pass on `main`.

- [ ] **Step 6: Confirm local main contains the applied work and is clean**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
git branch --show-current
git log --oneline --decorate --max-count=5
```

Expected: `git status --short` prints nothing, current branch is `main`, and the latest log entries include the merge commit and task commits.

- [ ] **Step 7: Stop before pushing**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
```

Expected: the working tree is clean. Do not push local `main` or create a PR unless the user explicitly asks for that after this plan is complete.

---

## Self-Review

Spec coverage:
- Reconcile/cancel stale run `80cf0056...`: Task 1, Task 10.
- Lower dev Modal social concurrency/dispatch caps: Task 2.
- Isolate finalization/live-status/profile-summary DB access: Tasks 3 and 4. Profile summary already uses `social_profile`; this plan adds a separate `social_control` pool for finalization and status/read paths.
- Add stale advisory-lock/session cleanup or stricter lock behavior: Task 5, with explicit advisory lock-key allowlisting.
- Fix TikTok 269/272 incomplete catalog after empty-body fallback: Task 6.
- Repair Instagram comments zero-cookie warmup: Task 7.
- Orchestrate subagents with `@browser-use` to compare Scrapling vs Crawlee and make the better method default: Task 8.
- Add DB pool pressure before/after snapshots: Tasks 5 and 10.
- Add one-run canary command per platform: Tasks 9 and 10.
- Capture Modal invocation IDs and typed benchmark JSON: Task 8.
- Require `superpowers:subagent-driven-development` with fresh implementer, spec reviewer, and code-quality reviewer subagents per task: Required Subagent-Driven Execution Workflow and Tasks 1-11.
- Apply completed, reviewed changes to local `main`: Task 11.

Placeholder scan:
- The plan contains concrete file paths, test functions, implementation snippets, commands, and expected outcomes.
- No task relies on unstated behavior or a future design decision.

Type consistency:
- `CleanupPlan`, `InstagramCommentsWarmupError`, `SOCIAL_CONTROL_POOL_NAME`, and `pool_name` are introduced before later tasks reference them.
- `completion_tolerance_applied`, `completion_missing_posts`, and `completion_tolerance_posts` are written to `retrieval_meta` and asserted from returned metadata.
- `CandidateResult.modal_invocation_ids`, `CandidateResult.to_json_dict()`, `write_results_json()`, `build_pressure_snapshot()`, and `build_canary_commands()` are defined before verification steps reference their artifacts or commands.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
