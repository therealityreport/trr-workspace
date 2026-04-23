# Backfill Posts Pipeline Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan with the parallel workstreams below. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Backfill Posts reliably create scrape work, refresh incomplete Instagram post details, avoid no-op placeholder runs, and preserve selected Post Details / Comments / Media tasks in the local fallback command.

**Architecture:** Keep the fast Instagram launch path, but treat the route response as a reserved-launch acknowledgement until scrape jobs exist. Replace the raw catalog-finalize daemon thread with the existing FastAPI background-task surface, and make deterministic read-path recovery the durability layer for reserved runs that still have no jobs. Make Instagram materialization detail-aware using successful detail-refresh signals, then make no-work launches terminal and truthful. Extend the local CLI and app command builder so operator fallback launches the same task set as the UI.

**Tech Stack:** FastAPI / Starlette `BackgroundTasks`, Python repository code with pytest, Supabase Postgres through existing `pg` helpers, React / TypeScript with Vitest.

**Acceptance Criteria:**
- A reserved Instagram Backfill Posts run with zero jobs self-heals from account profile/recent-run reads or progress reads into either a real catalog/comments/media launch or a terminal `completed_no_work` state.
- `post_details` is skipped only when materialized Instagram rows have successful detail-refresh state and required media fields, not merely matching row counts.
- A selected-task launch that resolves to no remaining work returns a truthful terminal payload and does not leave an indefinite queued placeholder.
- The local fallback command copied from the admin UI includes selected task flags and the CLI executes every run ID returned by the launch orchestrator.

**Non-Goals:**
- Do not introduce a new external queue or worker lane in this phase.
- Do not broaden the change to unrelated catalog cancellation daemon threads or non-backfill social ingestion flows.
- Do not create feature branches. All accepted changes land on the workspace `main` branch.

**Rollback / Containment:**
- If Task 1 causes route-level regressions, revert only the router checkpoint commit; Task 2 recovery still protects already reserved pending launches once merged.
- If Task 2 read-path recovery causes unexpected load or duplicate launch symptoms, revert the combined repository launch-state commit and keep Task 5 if already merged because the local fallback is independent.
- If Task 5 app/CLI changes fail, revert only the local fallback checkpoint commit; backend API behavior remains unchanged.
- Do not run destructive data cleanup as part of rollback. Existing reserved runs should be repaired through the same recovery path or explicitly dismissed by the existing admin controls.

---

## Parallel Execution Model

**Main-branch policy:** The coordinator must start from `/Users/thomashulihan/Projects/TRR` on branch `main`. Run `git branch --show-current` before edits and expect `main`. If the workspace is not on `main`, stop and resolve that before implementation. Do not create, switch to, or push any other branch for this work.

**Subagent commit policy:** Subagents may work in their isolated/forked agent workspaces, but they must not create branches and must not run `git commit`. They should edit only their assigned files, run their focused tests when possible, and report changed paths plus test results. The coordinator integrates accepted patches into the shared workspace on `main`, then runs the task checkpoint commits from the main workspace.

**Run these workstreams in parallel:**
- **Subagent A: Router Finalize Workstream** owns Task 1 only.
  - Write set: `TRR-Backend/api/routers/socials.py`, `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`.
  - Do not edit repository launch logic, CLI files, or app files.
- **Subagent B: Repository Launch State Workstream** owns Tasks 2, 3, and 4, executed serially inside that subagent because they all touch `TRR-Backend/trr_backend/repositories/social_season_analytics.py` and `TRR-Backend/tests/repositories/test_social_season_analytics.py`. Subagent B returns one combined patch after Task 4.
  - Write set: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`.
  - Do not edit router, CLI, or app files.
- **Subagent C: Local Fallback Workstream** owns Task 5 only.
  - Write set: `TRR-Backend/scripts/socials/local_catalog_action.py`, `TRR-Backend/tests/scripts/test_local_catalog_action.py`, `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`, `TRR-APP/apps/web/tests/social-account-profile-backfill-command.test.ts`.
  - Do not edit router or repository launch-state files.

**Coordinator integration order:**
1. Start all three subagents after the main-branch preflight.
2. While subagents run, the coordinator monitors for overlapping edits and answers implementation questions.
3. Integrate Subagent A and C patches as soon as they finish because their write sets are disjoint.
4. Integrate Subagent B after its serial Tasks 2-4 are complete, then make one coordinator commit for the combined repository launch-state work.
5. Run Task 6 from the main workspace after all patches are integrated.
6. Leave the workspace on `main` with the final changes applied there. No branch creation is part of this plan.

**Stop conditions:**
- If `git status --short` shows unrelated edits inside a subagent's write set before integration, stop and inspect before applying that subagent patch.
- If any subagent needs to edit outside its declared write set, pause that workstream and have the coordinator reassign ownership before continuing.
- If Subagent B changes public payload keys used by the app (`launch_state`, `launch_task_resolution_pending`, `selected_tasks`, `effective_selected_tasks`, `attached_followups`), pause and run an app typecheck before committing backend changes.
- If the advisory-lock implementation cannot be kept on a single DB connection, stop and use an existing repository lock helper instead of inventing a partial lock.

---

## File Structure

- Modify `TRR-Backend/api/routers/socials.py`
  - Replace `_start_catalog_backfill_finalize_in_background` daemon-thread scheduling with the existing FastAPI background task surface.
  - Preserve cache clearing around successful and failed finalization.

- Modify `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Add detail-aware Instagram materialization state.
  - Add recoverable pending catalog-launch behavior for reserved runs with no jobs from progress and account profile/recent-run read surfaces.
  - Add terminal no-work completion for launches where all selected work is skipped.

- Modify `TRR-Backend/scripts/socials/local_catalog_action.py`
  - Add `--selected-task` CLI flags.
  - Route selected-task backfills through `launch_social_account_catalog_backfill`.
  - Execute both catalog and comments run IDs when the launch creates both.

- Modify `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
  - Export and extend `buildLocalCatalogCommand`.
  - Include selected task flags in copied Backfill Posts commands.

- Modify `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
  - Update route tests from the raw thread helper to the background-task helper.
  - Add a focused background-task execution test.

- Modify `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  - Add materialization-state tests.
  - Add no-work launch completion tests.
  - Add pending-launch recovery tests.

- Modify `TRR-Backend/tests/scripts/test_local_catalog_action.py`
  - Add selected-task CLI parsing and dispatch tests.
  - Add multi-run inline execution test.

- Create `TRR-APP/apps/web/tests/social-account-profile-backfill-command.test.ts`
  - Unit-test the exported command builder and the copy-button selected-task default helper.

---

### Task 0: Coordinator Main-Branch Preflight And Subagent Dispatch

**Owner:** Coordinator only.

**Files:**
- No source edits

- [ ] **Step 1: Verify workspace branch**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git branch --show-current
git status --short
```

Expected: branch is `main`. If it is not `main`, stop before spawning subagents. Do not create a feature branch for this work. If any of the planned write-set files already have user edits, record that before spawning subagents and preserve those edits during integration.

- [ ] **Step 2: Start the three subagents with disjoint write ownership**

Spawn the subagents from the same plan context:

```text
Subagent A: Implement Task 1 only from /Users/thomashulihan/Projects/TRR. Edit only TRR-Backend/api/routers/socials.py and TRR-Backend/tests/api/routers/test_socials_season_analytics.py. Do not commit. Report changed paths and tests run.

Subagent B: Implement Tasks 2, 3, and 4 serially from /Users/thomashulihan/Projects/TRR/TRR-Backend. Edit only TRR-Backend/trr_backend/repositories/social_season_analytics.py and TRR-Backend/tests/repositories/test_social_season_analytics.py. Do not commit. Report changed paths and tests run.

Subagent C: Implement Task 5 only from /Users/thomashulihan/Projects/TRR. Edit only TRR-Backend/scripts/socials/local_catalog_action.py, TRR-Backend/tests/scripts/test_local_catalog_action.py, TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx, and TRR-APP/apps/web/tests/social-account-profile-backfill-command.test.ts. Do not commit. Report changed paths and tests run.
```

- [ ] **Step 3: Integrate subagent patches into `main`**

As each subagent finishes, inspect its patch, apply accepted changes to the shared workspace on `main`, and run that workstream's focused tests before moving to the relevant coordinator checkpoint commit. If a subagent reports conflicts, resolve them in the shared workspace without creating a branch. After every integration, run `git diff --check` against the changed files before committing.

---

### Task 1: Move Catalog Finalize Scheduling Onto FastAPI BackgroundTasks

**Owner:** Subagent A, Router Finalize Workstream.

**Files:**
- Modify: `TRR-Backend/api/routers/socials.py:349-410`
- Modify: `TRR-Backend/api/routers/socials.py:5121-5185`
- Test: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py:714-885`

**Important boundary:** `BackgroundTasks` is not the durability fix. It only removes the unmanaged raw daemon thread from the route. Task 2 is mandatory because a process crash or interrupted response can still leave a reserved run with no jobs.

- [ ] **Step 1: Update the failing route/helper tests**

Replace the existing `test_start_catalog_backfill_finalize_in_background_clears_account_profile_caches` test with this test, and update route tests that patch `api.routers.socials._start_catalog_backfill_finalize_in_background` so they patch `api.routers.socials._queue_catalog_backfill_finalize_task` instead.

```python
def test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import asyncio

    from fastapi import BackgroundTasks
    from api.routers import socials as socials_router

    finalized: list[dict[str, Any]] = []
    cleared: list[str] = []
    background_tasks = BackgroundTasks()

    monkeypatch.setattr(
        "trr_backend.repositories.social_season_analytics.finalize_social_account_catalog_backfill_launch",
        lambda **kwargs: finalized.append(kwargs) or {"run_id": kwargs["run_id"], "status": "queued"},
    )
    monkeypatch.setattr(socials_router, "_clear_account_profile_caches", lambda: cleared.append("cleared"))

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
        selected_tasks=["post_details", "comments", "media"],
        launch_group_id="launch-group-1",
    )

    assert len(background_tasks.tasks) == 1

    asyncio.run(background_tasks())

    assert finalized == [
        {
            "platform": "instagram",
            "account_handle": "bravotv",
            "run_id": "catalog-run-1",
            "source_scope": "bravo",
            "date_start": None,
            "date_end": None,
            "initiated_by": "admin@example.com",
            "allow_local_dev_inline_bypass": False,
            "execution_preference": "auto",
            "selected_tasks": ["post_details", "comments", "media"],
            "launch_group_id": "launch-group-1",
        }
    ]
    assert cleared == ["cleared"]
```

In `test_post_social_account_catalog_backfill` and `test_post_social_account_catalog_backfill_forwards_selected_tasks`, change the patch target:

```python
with patch(
    "api.routers.socials._queue_catalog_backfill_finalize_task",
    return_value=None,
) as mocked_finalize:
    ...
```

- [ ] **Step 2: Run the route tests and confirm they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches tests/api/routers/test_socials_season_analytics.py::test_post_social_account_catalog_backfill tests/api/routers/test_socials_season_analytics.py::test_post_social_account_catalog_backfill_forwards_selected_tasks -q
```

Expected: FAIL with `AttributeError: module 'api.routers.socials' has no attribute '_queue_catalog_backfill_finalize_task'` or route tests still calling the removed helper.

- [ ] **Step 3: Implement the managed background task helper**

In `TRR-Backend/api/routers/socials.py`, remove `Thread` from imports if it is only used by the old finalize helper, delete `_start_catalog_backfill_finalize_in_background`, and add this replacement in the same location.

```python
def _finalize_catalog_backfill_launch_task(
    *,
    platform: str,
    account_handle: str,
    run_id: str,
    source_scope: str,
    date_start: datetime | None,
    date_end: datetime | None,
    initiated_by: str | None,
    allow_local_dev_inline_bypass: bool,
    execution_preference: str,
    selected_tasks: list[str] | None,
    launch_group_id: str | None,
) -> None:
    from trr_backend.repositories.social_season_analytics import finalize_social_account_catalog_backfill_launch

    try:
        finalize_social_account_catalog_backfill_launch(
            platform=platform,
            account_handle=account_handle,
            run_id=run_id,
            source_scope=source_scope,
            date_start=date_start,
            date_end=date_end,
            initiated_by=initiated_by,
            allow_local_dev_inline_bypass=allow_local_dev_inline_bypass,
            execution_preference=execution_preference,  # type: ignore[arg-type]
            selected_tasks=selected_tasks,
            launch_group_id=launch_group_id,
        )
    except Exception:
        logger.exception(
            "[catalog-launch] finalize_background_task_failed platform=%s account=%s run_id=%s",
            platform,
            account_handle,
            run_id,
        )
        raise
    finally:
        _clear_account_profile_caches()


def _queue_catalog_backfill_finalize_task(
    *,
    background_tasks: BackgroundTasks,
    platform: str,
    account_handle: str,
    run_id: str,
    source_scope: str,
    date_start: datetime | None,
    date_end: datetime | None,
    initiated_by: str | None,
    allow_local_dev_inline_bypass: bool,
    execution_preference: str,
    selected_tasks: list[str] | None,
    launch_group_id: str | None,
) -> None:
    background_tasks.add_task(
        _finalize_catalog_backfill_launch_task,
        platform=platform,
        account_handle=account_handle,
        run_id=run_id,
        source_scope=source_scope,
        date_start=date_start,
        date_end=date_end,
        initiated_by=initiated_by,
        allow_local_dev_inline_bypass=allow_local_dev_inline_bypass,
        execution_preference=execution_preference,
        selected_tasks=selected_tasks,
        launch_group_id=launch_group_id,
    )
```

Then replace the route call:

```python
_queue_catalog_backfill_finalize_task(
    background_tasks=background_tasks,
    platform=platform,
    account_handle=account_handle,
    run_id=str(result.get("run_id") or ""),
    source_scope=payload.source_scope,
    date_start=date_start,
    date_end=date_end,
    initiated_by=(user or {}).get("email"),
    allow_local_dev_inline_bypass=used_inline_fallback,
    execution_preference=payload.execution_preference,
    selected_tasks=payload.selected_tasks,
    launch_group_id=str(result.get("launch_group_id") or ""),
)
```

- [ ] **Step 4: Run the route tests and confirm they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches tests/api/routers/test_socials_season_analytics.py::test_post_social_account_catalog_backfill tests/api/routers/test_socials_season_analytics.py::test_post_social_account_catalog_backfill_forwards_selected_tasks -q
```

Expected: PASS.

- [ ] **Step 5: Coordinator checkpoint commit on `main`**

```bash
cd /Users/thomashulihan/Projects/TRR
test "$(git branch --show-current)" = "main"
git add TRR-Backend/api/routers/socials.py TRR-Backend/tests/api/routers/test_socials_season_analytics.py
git commit -m "fix: schedule catalog backfill finalize with background tasks"
```

---

### Task 2: Recover Pending Launches From Account Read Surfaces

**Owner:** Subagent B, Repository Launch State Workstream.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:27698-27886`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:39552-39603`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the pending-launch recovery tests**

Add these tests near the existing catalog backfill tests.

```python
def test_recover_pending_social_account_catalog_launch_finalizes_reserved_run(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from contextlib import contextmanager

    launch_calls: list[dict[str, Any]] = []

    @contextmanager
    def _ready_lock(*_args: Any, **_kwargs: Any):
        yield True

    monkeypatch.setattr(social_repo, "_catalog_launch_recovery_lock", _ready_lock)
    monkeypatch.setattr(
        social_repo,
        "_load_social_account_catalog_run_row",
        lambda **_kwargs: {
            "run_id": "catalog-run-pending-1",
            "status": "queued",
            "source_scope": "bravo",
            "config": {
                "launch_state": "pending",
                "launch_task_resolution_pending": True,
                "platform": "instagram",
                "account_handle": "bravotv",
                "source_scope": "bravo",
                "date_start": None,
                "date_end": None,
                "allow_local_dev_inline_bypass": False,
                "execution_preference": "auto",
                "selected_tasks": ["post_details", "comments", "media"],
                "launch_group_id": "launch-group-1",
            },
        },
    )
    monkeypatch.setattr(
        social_repo,
        "finalize_social_account_catalog_backfill_launch",
        lambda **kwargs: launch_calls.append(kwargs) or {"run_id": kwargs["run_id"], "status": "queued"},
    )

    result = social_repo.recover_pending_social_account_catalog_launch(
        platform="instagram",
        account_handle="bravotv",
        run_id="catalog-run-pending-1",
    )

    assert result["recovered"] is True
    assert launch_calls == [
        {
            "platform": "instagram",
            "account_handle": "bravotv",
            "run_id": "catalog-run-pending-1",
            "source_scope": "bravo",
            "date_start": None,
            "date_end": None,
            "initiated_by": "catalog_launch_recovery",
            "allow_local_dev_inline_bypass": False,
            "execution_preference": "auto",
            "selected_tasks": ["post_details", "comments", "media"],
            "launch_group_id": "launch-group-1",
        }
    ]


def test_recover_pending_social_account_catalog_launch_skips_when_recovery_lock_is_busy(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from contextlib import contextmanager

    @contextmanager
    def _busy_lock(*_args: Any, **_kwargs: Any):
        yield False

    monkeypatch.setattr(social_repo, "_catalog_launch_recovery_lock", _busy_lock)
    monkeypatch.setattr(
        social_repo,
        "finalize_social_account_catalog_backfill_launch",
        lambda **_kwargs: pytest.fail("busy recovery lock must not finalize"),
    )

    result = social_repo.recover_pending_social_account_catalog_launch(
        platform="instagram",
        account_handle="bravotv",
        run_id="catalog-run-pending-1",
    )

    assert result == {"recovered": False, "reason": "recovery_lock_busy"}


def test_get_social_account_catalog_run_progress_recovers_pending_run_before_run_not_found(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    job_calls = {"count": 0}
    recovered: list[str] = []

    monkeypatch.setattr(social_repo, "_relation_exists", lambda _name: True)
    monkeypatch.setattr(social_repo, "_scrape_jobs_features", lambda: {"has_run_id": True})
    monkeypatch.setattr(
        social_repo,
        "_load_social_account_catalog_run_row",
        lambda **_kwargs: {
            "run_id": "catalog-run-pending-1",
            "status": "queued",
            "season_id": None,
            "source_scope": "bravo",
            "config": {
                "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
                "launch_state": "pending",
                "launch_task_resolution_pending": True,
                "platforms": ["instagram"],
                "accounts_override": ["bravotv"],
                "selected_tasks": ["post_details", "comments", "media"],
            },
            "summary": {},
            "created_at": None,
            "started_at": None,
            "completed_at": None,
        },
    )

    def _jobs(**_kwargs: Any) -> list[dict[str, Any]]:
        job_calls["count"] += 1
        if job_calls["count"] == 1:
            return []
        return [
            {
                "id": "job-1",
                "run_id": "catalog-run-pending-1",
                "platform": "instagram",
                "job_type": social_repo.SHARED_ACCOUNT_POSTS_JOB_TYPE,
                "status": "queued",
                "items_found": 0,
                "config": {"stage": social_repo.SHARED_ACCOUNT_POSTS_STAGE, "account": "bravotv"},
                "metadata": {},
                "created_at": None,
                "started_at": None,
                "completed_at": None,
                "worker_id": None,
                "error_message": None,
            }
        ]

    monkeypatch.setattr(social_repo, "_load_social_account_catalog_jobs", _jobs)
    monkeypatch.setattr(
        social_repo,
        "recover_pending_social_account_catalog_launch",
        lambda **kwargs: recovered.append(kwargs["run_id"]) or {"recovered": True},
    )
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(social_repo, "recover_stale_unclaimed_dispatched_jobs", lambda **_kwargs: {})
    monkeypatch.setattr(social_repo, "recover_dispatch_blocked_no_progress_jobs", lambda **_kwargs: {})

    payload = social_repo.get_social_account_catalog_run_progress(
        platform="instagram",
        account_handle="bravotv",
        run_id="catalog-run-pending-1",
    )

    assert recovered == ["catalog-run-pending-1"]
    assert payload["run_id"] == "catalog-run-pending-1"


def test_catalog_recent_runs_recovers_pending_reserved_run_without_jobs(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fetch_calls = {"count": 0}
    captured_sql: list[str] = []
    captured_params: list[list[Any]] = []
    recovered: list[str] = []

    def _fetch_all(_sql: str, _params: list[Any]) -> list[dict[str, Any]]:
        fetch_calls["count"] += 1
        captured_sql.append(_sql)
        captured_params.append(list(_params))
        if fetch_calls["count"] == 1:
            return [
                {
                    "run_id": "catalog-run-pending-1",
                    "run_config": {
                        "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
                        "launch_state": "pending",
                        "launch_task_resolution_pending": True,
                        "platform": "instagram",
                        "account_handle": "bravotv",
                        "selected_tasks": ["post_details", "comments", "media"],
                    },
                    "run_summary": {},
                    "status": "queued",
                    "created_at": None,
                    "started_at": None,
                    "completed_at": None,
                    "job_id": None,
                    "metadata": {},
                    "error_message": None,
                }
            ]
        return [
            {
                "run_id": "catalog-run-pending-1",
                "run_config": {
                    "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
                    "launch_state": "ready",
                    "launch_task_resolution_pending": False,
                    "platform": "instagram",
                    "account_handle": "bravotv",
                    "selected_tasks": ["post_details", "comments", "media"],
                },
                "run_summary": {},
                "status": "queued",
                "created_at": None,
                "started_at": None,
                "completed_at": None,
                "job_id": "job-1",
                "metadata": {},
                "error_message": None,
            }
        ]

    monkeypatch.setattr(social_repo.pg, "fetch_all", _fetch_all)
    monkeypatch.setattr(social_repo, "_load_scrape_run_statuses", lambda *_args, **_kwargs: {})
    monkeypatch.setattr(social_repo, "_load_scrape_jobs_for_ids", lambda *_args, **_kwargs: [])
    monkeypatch.setattr(social_repo, "_load_media_followup_jobs_for_runs", lambda *_args, **_kwargs: {})
    monkeypatch.setattr(
        social_repo,
        "recover_pending_social_account_catalog_launch",
        lambda **kwargs: recovered.append(kwargs["run_id"]) or {"recovered": True},
    )

    rows = social_repo._catalog_recent_runs("instagram", "bravotv", limit=3)

    assert recovered == ["catalog-run-pending-1"]
    assert fetch_calls["count"] == 2
    assert "launch_task_resolution_pending" in captured_sql[0]
    assert captured_params[0].count("instagram") >= 3
    assert captured_params[0].count("bravotv") >= 3
    assert rows[0]["job_id"] == "job-1"
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_recover_pending_social_account_catalog_launch_finalizes_reserved_run tests/repositories/test_social_season_analytics.py::test_recover_pending_social_account_catalog_launch_skips_when_recovery_lock_is_busy tests/repositories/test_social_season_analytics.py::test_get_social_account_catalog_run_progress_recovers_pending_run_before_run_not_found tests/repositories/test_social_season_analytics.py::test_catalog_recent_runs_recovers_pending_reserved_run_without_jobs -q
```

Expected: FAIL with `AttributeError: module ... has no attribute 'recover_pending_social_account_catalog_launch'`, no second recent-runs fetch, or a recent-runs query that still excludes zero-job pending launches.

- [ ] **Step 3: Add the recovery helper**

Add this helper near `finalize_social_account_catalog_backfill_launch`.

```python
@contextmanager
def _catalog_launch_recovery_lock(platform: str, account_handle: str):
    lock_key = _social_account_catalog_start_lock_key(platform, account_handle)
    locked = False
    with pg.db_connection(label="catalog_launch_recovery_lock") as lock_conn:
        try:
            with pg.db_cursor(conn=lock_conn, label="catalog_launch_recovery_lock") as cur:
                row = pg.fetch_one_with_cursor(cur, "select pg_try_advisory_lock(%s) as locked", [lock_key]) or {}
            locked = bool(row.get("locked"))
            yield locked
        finally:
            if locked:
                with pg.db_cursor(conn=lock_conn, label="catalog_launch_recovery_unlock") as cur:
                    pg.fetch_one_with_cursor(cur, "select pg_advisory_unlock(%s) as unlocked", [lock_key])


def recover_pending_social_account_catalog_launch(
    *,
    platform: str,
    account_handle: str,
    run_id: str,
) -> dict[str, Any]:
    normalized_platform = _normalize_social_account_profile_platform(platform)
    normalized_account = _normalize_social_account_profile_handle(account_handle)
    normalized_run_id = str(run_id or "").strip()
    if not normalized_run_id:
        return {"recovered": False, "reason": "missing_run_id"}

    with _catalog_launch_recovery_lock(normalized_platform, normalized_account) as locked:
        if not locked:
            return {"recovered": False, "reason": "recovery_lock_busy"}
        run_row = _load_social_account_catalog_run_row(
            platform=normalized_platform,
            account_handle=normalized_account,
            run_id=normalized_run_id,
        )
        run_config = _metadata_dict(run_row.get("config"))
        launch_state = str(run_config.get("launch_state") or "").strip().lower()
        task_pending_raw = run_config.get("launch_task_resolution_pending")
        task_pending = task_pending_raw is True or str(task_pending_raw).strip().lower() == "true"
        if launch_state != "pending" and not task_pending:
            return {"recovered": False, "reason": "not_pending"}

        result = finalize_social_account_catalog_backfill_launch(
            platform=normalized_platform,
            account_handle=normalized_account,
            run_id=normalized_run_id,
            source_scope=str(run_config.get("source_scope") or run_row.get("source_scope") or "bravo"),
            date_start=_coerce_dt(run_config.get("date_start")),
            date_end=_coerce_dt(run_config.get("date_end")),
            initiated_by="catalog_launch_recovery",
            allow_local_dev_inline_bypass=bool(run_config.get("allow_local_dev_inline_bypass")),
            execution_preference=str(run_config.get("execution_preference") or "auto"),  # type: ignore[arg-type]
            selected_tasks=_normalize_optional_social_account_catalog_backfill_selected_tasks(
                run_config.get("selected_tasks")
            )
            or None,
            launch_group_id=str(run_config.get("launch_group_id") or "").strip() or None,
        )
        return {"recovered": True, "result": result}
```

The lock is mandatory, and the try/unlock calls must use the same DB connection. Account profile polling and progress polling can overlap, and this recovery path calls job creation; without a per-account advisory lock, two reads could finalize the same reserved run twice.

- [ ] **Step 4: Include zero-job pending launches in `_catalog_recent_runs` and recover them before profile summary serializes placeholders**

First, broaden the `scoped_runs` CTE in `_catalog_recent_runs`. The current query only includes runs that already have a matching catalog job. Add an `or` branch that includes runs for the same platform/account when `r.config->>'launch_state' = 'pending'` or `r.config->>'launch_task_resolution_pending' = 'true'`, even if no job exists yet.

The intent is:

```sql
and (
  exists (
    -- existing matching social.scrape_jobs predicate
  )
  or (
    (
      lower(coalesce(r.config->>'launch_state', '')) = 'pending'
      or lower(coalesce(r.config->>'launch_task_resolution_pending', 'false')) = 'true'
    )
    and lower(coalesce(r.config->>'platform', r.config->'platforms'->>0, '')) = %s
    and lower(coalesce(r.config->>'account_handle', r.config->>'account', r.config->'accounts_override'->>0, '')) = %s
  )
)
```

Add the two new SQL parameters for this branch (`normalized_platform`, `normalized_account`) before the existing `latest_job`/`latest_error` parameter groups so placeholder recovery is scoped to the same account as the visible profile page. Keep the parameter order aligned with the SQL placeholders; the test above should fail if the added branch is present but the platform/account params were not added.

After `normalized_rows = [dict(row) for row in rows]` in `_catalog_recent_runs`, detect rows with `launch_state=pending` or `launch_task_resolution_pending=true` that still have no `job_id`. Call recovery for those run IDs, then reload the recent-run rows once so account profile summaries and admin recent-run cards do not keep showing an unrecovered placeholder.

```python
        def _fetch_recent_rows() -> list[dict[str, Any]]:
            if conn is None:
                return [dict(row) for row in pg.fetch_all(sql, params)]
            with pg.db_cursor(conn=conn, label="catalog_recent_runs") as cur:
                return [dict(row) for row in pg.fetch_all_with_cursor(cur, sql, params)]

        normalized_rows = _fetch_recent_rows()

        def _row_needs_pending_launch_recovery(row: Mapping[str, Any]) -> bool:
            if str(row.get("job_id") or "").strip():
                return False
            run_config = _metadata_dict(row.get("run_config"))
            task_pending_raw = run_config.get("launch_task_resolution_pending")
            task_pending = task_pending_raw is True or str(task_pending_raw or "").strip().lower() == "true"
            return str(run_config.get("launch_state") or "").strip().lower() == "pending" or task_pending

        pending_without_jobs = [row for row in normalized_rows if _row_needs_pending_launch_recovery(row)]
        if pending_without_jobs:
            for row in pending_without_jobs:
                try:
                    recover_pending_social_account_catalog_launch(
                        platform=normalized_platform,
                        account_handle=normalized_account,
                        run_id=str(row.get("run_id") or "").strip(),
                    )
                except Exception:
                    logger.warning(
                        "[catalog-launch] recent_runs_recovery_failed platform=%s account=%s run_id=%s",
                        normalized_platform,
                        normalized_account,
                        str(row.get("run_id") or "").strip(),
                        exc_info=True,
                    )
            normalized_rows = _fetch_recent_rows()
```

When implementing this, replace the current inline fetch block with `_fetch_recent_rows()` so both the initial fetch and the post-recovery reload work for `conn is None` and `conn is not None`.

- [ ] **Step 5: Call recovery before `run_not_found` in progress**

In `get_social_account_catalog_run_progress`, replace the empty-job branch with this block.

```python
job_rows = _load_social_account_catalog_jobs(
    run_id=run_id,
    platform=normalized_platform,
    account_handle=normalized_account,
    features=features,
)
if not job_rows:
    recovery_result = recover_pending_social_account_catalog_launch(
        platform=normalized_platform,
        account_handle=normalized_account,
        run_id=run_id,
    )
    if bool(recovery_result.get("recovered")):
        run_row = _load_social_account_catalog_run_row(
            platform=normalized_platform,
            account_handle=normalized_account,
            run_id=run_id,
        )
        job_rows = _load_social_account_catalog_jobs(
            run_id=run_id,
            platform=normalized_platform,
            account_handle=normalized_account,
            features=features,
        )
    if not job_rows:
        raise ValueError("run_not_found")
```

- [ ] **Step 6: Run the recovery tests and confirm they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_recover_pending_social_account_catalog_launch_finalizes_reserved_run tests/repositories/test_social_season_analytics.py::test_recover_pending_social_account_catalog_launch_skips_when_recovery_lock_is_busy tests/repositories/test_social_season_analytics.py::test_get_social_account_catalog_run_progress_recovers_pending_run_before_run_not_found tests/repositories/test_social_season_analytics.py::test_catalog_recent_runs_recovers_pending_reserved_run_without_jobs -q
```

Expected: PASS.

- [ ] **Step 7: Subagent B internal checkpoint only**

Do not commit yet. Keep these Task 2 changes in Subagent B's workspace and continue directly to Task 3. The coordinator will commit the combined Tasks 2-4 repository patch after Task 4 passes.

---

### Task 3: Make Instagram Materialization Detail-Aware

**Owner:** Subagent B, Repository Launch State Workstream. Start after Task 2 in the same subagent workspace.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:56748-56780`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py:6104-6229`

- [ ] **Step 1: Write materialization-state tests**

Add these tests near the existing Instagram catalog coverage tests.

```python
def test_instagram_materialization_state_requires_detail_fields(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts_for_window", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_materialized_social_account_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(
        social_repo,
        "_instagram_materialized_detail_gap_counts",
        lambda *_args, **_kwargs: {
            "posts_missing_detail_refresh_success": 2,
            "posts_missing_detail_payload": 2,
            "posts_missing_source_media": 1,
            "posts_needing_detail_refresh": 3,
        },
    )

    state = social_repo._instagram_materialization_state("bravotv")

    assert state["catalog_posts"] == 12
    assert state["materialized_posts"] == 12
    assert state["details_complete"] is False
    assert state["bootstrap_required"] is False
    assert state["detail_gap_counts"] == {
        "posts_missing_detail_refresh_success": 2,
        "posts_missing_detail_payload": 2,
        "posts_missing_source_media": 1,
        "posts_needing_detail_refresh": 3,
    }


def test_instagram_materialization_state_is_complete_when_counts_and_detail_fields_are_complete(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts_for_window", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_materialized_social_account_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(
        social_repo,
        "_instagram_materialized_detail_gap_counts",
        lambda *_args, **_kwargs: {
            "posts_missing_detail_refresh_success": 0,
            "posts_missing_detail_payload": 0,
            "posts_missing_source_media": 0,
            "posts_needing_detail_refresh": 0,
        },
    )

    state = social_repo._instagram_materialization_state("bravotv")

    assert state["details_complete"] is True
    assert state["bootstrap_required"] is False


def test_instagram_materialized_detail_gap_counts_treats_raw_data_without_metadata_success_as_incomplete(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured_sql: list[str] = []

    def _fetch_one(sql: str, _params: list[Any]) -> dict[str, Any]:
        captured_sql.append(sql)
        return {
            "posts_missing_detail_refresh_success": 1,
            "posts_missing_detail_payload": 0,
            "posts_missing_source_media": 0,
            "posts_needing_detail_refresh": 1,
        }

    monkeypatch.setattr(social_repo, "_instagram_posts_has_column", lambda _column: True)
    monkeypatch.setattr(social_repo.pg, "fetch_one", _fetch_one)

    counts = social_repo._instagram_materialized_detail_gap_counts("bravotv")

    assert counts["posts_missing_detail_payload"] == 0
    assert counts["posts_missing_detail_refresh_success"] == 1
    assert counts["posts_needing_detail_refresh"] == 1
    assert "metadata_scraped_at is null" in captured_sql[0]
    assert "metadata_error" in captured_sql[0]
```

- [ ] **Step 2: Run tests and confirm they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_instagram_materialization_state_requires_detail_fields tests/repositories/test_social_season_analytics.py::test_instagram_materialization_state_is_complete_when_counts_and_detail_fields_are_complete tests/repositories/test_social_season_analytics.py::test_instagram_materialized_detail_gap_counts_treats_raw_data_without_metadata_success_as_incomplete -q
```

Expected: FAIL because `_instagram_materialized_detail_gap_counts` is missing or ignored.

- [ ] **Step 3: Add detail gap helper**

Add this helper immediately before `_instagram_materialization_state`.

```python
def _instagram_materialized_detail_gap_counts(
    account_handle: str,
    *,
    date_start: datetime | None = None,
    date_end: datetime | None = None,
) -> dict[str, int]:
    normalized_account = _normalize_social_account_profile_handle(account_handle)
    where_clauses = [
        _social_account_profile_owner_match_sql("instagram", alias="p"),
        "nullif(p.shortcode, '') is not null",
    ]
    params: list[Any] = [normalized_account]
    if date_start is not None:
        where_clauses.append("p.posted_at >= %s")
        params.append(date_start)
    if date_end is not None:
        where_clauses.append("p.posted_at <= %s")
        params.append(date_end)
    detail_refresh_missing_conditions = ["p.scraped_at is null"]
    if _instagram_posts_has_column("metadata_scraped_at"):
        detail_refresh_missing_conditions.append("p.metadata_scraped_at is null")
    if _instagram_posts_has_column("metadata_error"):
        detail_refresh_missing_conditions.append("nullif(p.metadata_error, '') is not null")

    detail_payload_missing_conditions = ["p.scraped_at is null"]
    if _instagram_posts_has_column("raw_data"):
        detail_payload_missing_conditions.append("p.raw_data is null or p.raw_data = '{}'::jsonb")

    thumbnail_expr = "nullif(p.thumbnail_url, '')" if _instagram_posts_has_column("thumbnail_url") else "null"
    media_count_expr = (
        "jsonb_array_length(coalesce(p.media_urls, '[]'::jsonb))"
        if _instagram_posts_has_column("media_urls")
        else "0"
    )
    missing_detail_refresh_sql = " or ".join(f"({condition})" for condition in detail_refresh_missing_conditions)
    missing_detail_payload_sql = " or ".join(f"({condition})" for condition in detail_payload_missing_conditions)
    missing_source_media_sql = f"{thumbnail_expr} is null and {media_count_expr} = 0"
    needs_refresh_sql = f"({missing_detail_refresh_sql}) or ({missing_detail_payload_sql}) or ({missing_source_media_sql})"
    query = f"""
        select
          count(*) filter (
            where {missing_detail_refresh_sql}
          )::int as posts_missing_detail_refresh_success,
          count(*) filter (
            where {missing_detail_payload_sql}
          )::int as posts_missing_detail_payload,
          count(*) filter (
            where {missing_source_media_sql}
          )::int as posts_missing_source_media,
          count(*) filter (
            where {needs_refresh_sql}
          )::int as posts_needing_detail_refresh
        from social.instagram_posts p
        where {" and ".join(where_clauses)}
    """
    try:
        row = pg.fetch_one(query, params) or {}
    except psycopg_errors.UndefinedTable:
        row = {}
    missing_detail_refresh_success = _normalize_non_negative_int(row.get("posts_missing_detail_refresh_success"))
    missing_detail_payload = _normalize_non_negative_int(row.get("posts_missing_detail_payload"))
    missing_source_media = _normalize_non_negative_int(row.get("posts_missing_source_media"))
    posts_needing_detail_refresh = _normalize_non_negative_int(row.get("posts_needing_detail_refresh"))
    return {
        "posts_missing_detail_refresh_success": missing_detail_refresh_success,
        "posts_missing_detail_payload": missing_detail_payload,
        "posts_missing_source_media": missing_source_media,
        "posts_needing_detail_refresh": posts_needing_detail_refresh,
    }
```

Do not use `raw_data` as positive proof of detail hydration. In this pipeline `raw_data` can be present from catalog materialization, so the success gate must include `metadata_scraped_at` with no `metadata_error` when those columns exist.

- [ ] **Step 4: Use detail gaps in materialization state**

Replace the `details_complete` computation in `_instagram_materialization_state` with:

```python
    detail_gap_counts = _instagram_materialized_detail_gap_counts(
        normalized_account,
        date_start=date_start,
        date_end=date_end,
    )
    posts_needing_detail_refresh = _normalize_non_negative_int(
        detail_gap_counts.get("posts_needing_detail_refresh")
    )
    details_complete = catalog_posts > 0 and materialized_posts >= catalog_posts and posts_needing_detail_refresh == 0
    bootstrap_required = catalog_posts == 0 or materialized_posts < catalog_posts
    return {
        "platform": "instagram",
        "account_handle": normalized_account,
        "catalog_posts": catalog_posts,
        "materialized_posts": materialized_posts,
        "details_complete": details_complete,
        "bootstrap_required": bootstrap_required,
        "detail_gap_counts": detail_gap_counts,
    }
```

- [ ] **Step 5: Update selected-task launch expectations**

Update tests that currently expect count-complete rows to skip detail fetch by default. In tests that still want the skip path, patch `_instagram_materialized_detail_gap_counts` to return zeros:

```python
monkeypatch.setattr(
    social_repo,
    "_instagram_materialized_detail_gap_counts",
    lambda *_args, **_kwargs: {
        "posts_missing_detail_refresh_success": 0,
        "posts_missing_detail_payload": 0,
        "posts_missing_source_media": 0,
        "posts_needing_detail_refresh": 0,
    },
)
```

Add this new launch test:

```python
def test_launch_social_account_catalog_backfill_instagram_keeps_post_details_when_detail_fields_are_incomplete(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    catalog_calls: list[dict[str, Any]] = []
    comments_calls: list[dict[str, Any]] = []
    merged_config_updates: list[dict[str, Any]] = []

    monkeypatch.setattr(social_repo, "uuid4", lambda: "launch-group-detail-gaps")
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts_for_window", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_materialized_social_account_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(
        social_repo,
        "_instagram_materialized_detail_gap_counts",
        lambda *_args, **_kwargs: {
            "posts_missing_detail_refresh_success": 1,
            "posts_missing_detail_payload": 1,
            "posts_missing_source_media": 0,
            "posts_needing_detail_refresh": 1,
        },
    )
    monkeypatch.setattr(
        social_repo,
        "start_social_account_catalog_backfill",
        lambda platform, account_handle, **kwargs: (
            catalog_calls.append({"platform": platform, "account_handle": account_handle, **kwargs})
            or {"run_id": "catalog-run-detail-gaps", "status": "queued"}
        ),
    )
    monkeypatch.setattr(
        social_repo,
        "start_social_account_comments_scrape",
        lambda platform, account_handle, **kwargs: (
            comments_calls.append({"platform": platform, "account_handle": account_handle, **kwargs})
            or {"run_id": "comments-run-detail-gaps", "status": "queued"}
        ),
    )
    monkeypatch.setattr(
        social_repo,
        "_merge_catalog_run_config",
        lambda *, run_id, metadata_updates: (
            merged_config_updates.append({"run_id": run_id, **metadata_updates})
            or {"id": run_id, "status": "queued", "config": metadata_updates}
        ),
    )

    payload = social_repo.launch_social_account_catalog_backfill(
        "instagram",
        "bravotv",
        source_scope="bravo",
        selected_tasks=["post_details", "comments", "media"],
    )

    assert payload["effective_selected_tasks"] == ["post_details", "comments", "media"]
    assert payload["post_details_skipped_reason"] is None
    assert catalog_calls[0]["details_refresh_skip_detail_fetch"] is False
    assert catalog_calls[0]["details_refresh_skip_media_followups"] is False
    assert comments_calls[0]["comments_enable_media_followups"] is True
    assert merged_config_updates[-1]["effective_selected_tasks"] == ["post_details", "comments", "media"]
```

- [ ] **Step 6: Run materialization and launch tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_instagram_materialization_state_requires_detail_fields tests/repositories/test_social_season_analytics.py::test_instagram_materialization_state_is_complete_when_counts_and_detail_fields_are_complete tests/repositories/test_social_season_analytics.py::test_instagram_materialized_detail_gap_counts_treats_raw_data_without_metadata_success_as_incomplete tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_keeps_post_details_when_detail_fields_are_incomplete tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_skips_detail_hydration_when_materialized_coverage_is_complete -q
```

Expected: PASS.

- [ ] **Step 7: Subagent B internal checkpoint only**

Do not commit yet. Keep these Task 3 changes with the Task 2 changes in Subagent B's workspace and continue directly to Task 4. The coordinator will commit the combined Tasks 2-4 repository patch after Task 4 passes.

---

### Task 4: Complete No-Work Reserved Launches Truthfully

**Owner:** Subagent B, Repository Launch State Workstream. Start after Task 3 in the same subagent workspace.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:58040-58250`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write no-work launch tests**

Add this test near the selected-task launch tests.

```python
def test_launch_social_account_catalog_backfill_instagram_completes_existing_run_when_post_details_only_is_already_complete(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    merged_config_updates: list[dict[str, Any]] = []

    monkeypatch.setattr(social_repo, "uuid4", lambda: "launch-group-no-work")
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts_for_window", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(social_repo, "_materialized_social_account_total_posts", lambda *_args, **_kwargs: 12)
    monkeypatch.setattr(
        social_repo,
        "_instagram_materialized_detail_gap_counts",
        lambda *_args, **_kwargs: {
            "posts_missing_detail_refresh_success": 0,
            "posts_missing_detail_payload": 0,
            "posts_missing_source_media": 0,
            "posts_needing_detail_refresh": 0,
        },
    )
    monkeypatch.setattr(
        social_repo,
        "_merge_catalog_run_config",
        lambda *, run_id, metadata_updates: (
            merged_config_updates.append({"run_id": run_id, **metadata_updates})
            or {"id": run_id, "status": "completed", "config": metadata_updates}
        ),
    )
    monkeypatch.setattr(social_repo, "_set_run_status", lambda run_id, status, **_kwargs: None)

    payload = social_repo.launch_social_account_catalog_backfill(
        "instagram",
        "bravotv",
        source_scope="bravo",
        selected_tasks=["post_details"],
        existing_catalog_run_id="catalog-run-existing-1",
        launch_group_id_override="launch-group-no-work",
    )

    assert payload["run_id"] == "catalog-run-existing-1"
    assert payload["catalog_run_id"] == "catalog-run-existing-1"
    assert payload["status"] == "completed"
    assert payload["catalog_status"] == "completed"
    assert payload["selected_tasks"] == ["post_details"]
    assert payload["effective_selected_tasks"] == []
    assert payload["post_details_skipped_reason"] == "already_materialized"
    assert payload["attached_followups"] == {}
    assert merged_config_updates[-1]["run_id"] == "catalog-run-existing-1"
    assert merged_config_updates[-1]["launch_state"] == "completed_no_work"
    assert merged_config_updates[-1]["launch_task_resolution_pending"] is False
    assert merged_config_updates[-1]["no_work_reason"] == "selected_tasks_already_satisfied"
```

- [ ] **Step 2: Run the no-work test and confirm it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_completes_existing_run_when_post_details_only_is_already_complete -q
```

Expected: FAIL because the current code returns no run and no completed metadata for this edge.

- [ ] **Step 3: Add no-work completion helper**

Add this helper near the selected-task helpers.

```python
def _complete_catalog_launch_no_work(
    *,
    run_id: str | None,
    selected_tasks: list[str],
    effective_selected_tasks: list[str],
    post_details_skipped_reason: str | None,
) -> dict[str, Any]:
    normalized_run_id = str(run_id or "").strip() or None
    metadata_updates = {
        "launch_state": "completed_no_work",
        "launch_task_resolution_pending": False,
        "launch_completed_at": _iso(_now_utc()),
        "selected_tasks": selected_tasks,
        "effective_selected_tasks": effective_selected_tasks,
        "post_details_skipped_reason": post_details_skipped_reason,
        "no_work_reason": "selected_tasks_already_satisfied",
        "attached_followups": {},
    }
    if normalized_run_id:
        _merge_catalog_run_config(run_id=normalized_run_id, metadata_updates=metadata_updates)
        _set_run_status(normalized_run_id, "completed")
    return {
        "run_id": normalized_run_id,
        "status": "completed",
        "catalog_run_id": normalized_run_id,
        "catalog_status": "completed" if normalized_run_id else None,
        "comments_run_id": None,
        "comments_status": None,
        "attached_followups": {},
        "no_work_reason": "selected_tasks_already_satisfied",
    }
```

- [ ] **Step 4: Use the helper before returning from launch**

In `launch_social_account_catalog_backfill`, after `catalog_selected`, `comments_deferred_until_catalog_complete`, and `media_attachment_id` are computed, add:

```python
    if not catalog_selected and not any(task in effective_selected_tasks for task in ("comments", "media")):
        no_work = _complete_catalog_launch_no_work(
            run_id=existing_catalog_run_id,
            selected_tasks=normalized_selected_tasks,
            effective_selected_tasks=effective_selected_tasks,
            post_details_skipped_reason=post_details_skipped_reason,
        )
        return {
            "run_id": no_work["run_id"],
            "status": no_work["status"],
            "platform": normalized_platform,
            "account_handle": normalized_account,
            "launch_group_id": launch_group_id,
            "selected_tasks": normalized_selected_tasks,
            "effective_selected_tasks": effective_selected_tasks,
            "post_details_skipped_reason": post_details_skipped_reason,
            "catalog_run_id": no_work["catalog_run_id"],
            "comments_run_id": None,
            "catalog_status": no_work["catalog_status"],
            "comments_status": None,
            "catalog_bootstrap_required": False,
            "comments_deferred_until_catalog_complete": False,
            "attached_followups": {},
            "no_work_reason": no_work["no_work_reason"],
        }
```

- [ ] **Step 5: Run the no-work test and selected-task regression tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_completes_existing_run_when_post_details_only_is_already_complete tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_coordinates_selected_tasks tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_defaults_selected_tasks_to_full_set -q
```

Expected: PASS.

- [ ] **Step 6: Coordinator checkpoint commit on `main` for combined Tasks 2-4**

```bash
cd /Users/thomashulihan/Projects/TRR
test "$(git branch --show-current)" = "main"
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: repair catalog backfill launch state"
```

---

### Task 5: Preserve Selected Tasks In Local Backfill Fallback

**Owner:** Subagent C, Local Fallback Workstream.

**Files:**
- Modify: `TRR-Backend/scripts/socials/local_catalog_action.py:24-202`
- Modify: `TRR-Backend/tests/scripts/test_local_catalog_action.py`
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:307-313`
- Create: `TRR-APP/apps/web/tests/social-account-profile-backfill-command.test.ts`

- [ ] **Step 1: Write CLI selected-task tests**

Add these tests to `TRR-Backend/tests/scripts/test_local_catalog_action.py`.

```python
def test_parse_args_accepts_selected_tasks() -> None:
    args = cli.parse_args(
        [
            "--platform",
            "instagram",
            "--account",
            "bravotv",
            "--action",
            "backfill",
            "--selected-task",
            "post_details",
            "--selected-task",
            "comments",
            "--selected-task",
            "media",
        ]
    )

    assert args.selected_tasks == ["post_details", "comments", "media"]


def test_main_dispatches_selected_task_backfill_through_launch_orchestrator(monkeypatch, capsys) -> None:
    monkeypatch.setattr(cli, "load_dotenv", lambda *args, **kwargs: None)
    monkeypatch.setattr(cli, "apply_workspace_runtime_env", lambda **kwargs: {})
    monkeypatch.setattr(
        cli,
        "parse_args",
        lambda argv=None: SimpleNamespace(
            platform="instagram",
            account="bravotv",
            source_scope="bravo",
            action="backfill",
            selected_tasks=["post_details", "comments", "media"],
        ),
    )

    captured: dict[str, object] = {}

    def _launch(*args, **kwargs):
        captured.update(kwargs)
        return {
            "run_id": "catalog-run-1",
            "catalog_run_id": "catalog-run-1",
            "comments_run_id": "comments-run-1",
            "status": "queued",
        }

    executed: list[tuple[str, str]] = []

    monkeypatch.setitem(
        __import__("sys").modules,
        "trr_backend.repositories.social_season_analytics",
        SimpleNamespace(launch_social_account_catalog_backfill=_launch),
    )
    monkeypatch.setitem(
        __import__("sys").modules,
        "trr_backend.socials.control_plane",
        SimpleNamespace(
            execute_run_with_inline_worker_registration=lambda run_id, **kwargs: executed.append(
                (run_id, kwargs["worker_id"])
            )
        ),
    )

    assert cli.main() == 0
    assert captured["selected_tasks"] == ["post_details", "comments", "media"]
    assert captured["allow_local_dev_inline_bypass"] is True
    assert executed == [
        ("catalog-run-1", "local-script:catalog:instagram:1"),
        ("comments-run-1", "local-script:catalog:instagram:2"),
    ]
    assert "catalog-run-1" in capsys.readouterr().out
```

- [ ] **Step 2: Run CLI tests and confirm they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_local_catalog_action.py::test_parse_args_accepts_selected_tasks tests/scripts/test_local_catalog_action.py::test_main_dispatches_selected_task_backfill_through_launch_orchestrator -q
```

Expected: FAIL because `selected_tasks` parsing and launch orchestration do not exist.

- [ ] **Step 3: Add selected-task parsing and multi-run execution**

In `local_catalog_action.py`, add:

```python
SUPPORTED_SELECTED_TASKS = ("post_details", "comments", "media")
```

Add this parser argument:

```python
    parser.add_argument(
        "--selected-task",
        dest="selected_tasks",
        action="append",
        choices=SUPPORTED_SELECTED_TASKS,
        default=[],
        help="Backfill task to run. Repeat for post_details, comments, and media.",
    )
```

Replace `_execute_run` with:

```python
def _payload_run_ids(payload: dict[str, Any]) -> list[str]:
    ordered = [
        str(payload.get("catalog_run_id") or "").strip(),
        str(payload.get("comments_run_id") or "").strip(),
        str(payload.get("run_id") or "").strip(),
    ]
    seen: set[str] = set()
    run_ids: list[str] = []
    for run_id in ordered:
        if not run_id or run_id in seen:
            continue
        seen.add(run_id)
        run_ids.append(run_id)
    return run_ids


def _execute_run(payload: dict[str, Any], worker_id: str, control_plane: Any) -> int:
    run_ids = _payload_run_ids(payload)
    if not run_ids:
        print("Catalog action did not return a run_id.", file=sys.stderr)
        return 1
    for index, run_id in enumerate(run_ids, start=1):
        control_plane.execute_run_with_inline_worker_registration(
            run_id,
            worker_id=f"{worker_id}:{index}",
        )
    print(json.dumps({"run_id": run_ids[0], "executed_run_ids": run_ids, "status": "completed"}, sort_keys=True))
    return 0
```

Update `_start_backfill` signature and body:

```python
def _start_backfill(
    analytics_repo: Any,
    *,
    platform: str,
    account: str,
    source_scope: str,
    worker_id: str,
    scope: str,
    selected_tasks: list[str] | None = None,
    date_start: str | None = None,
    date_end: str | None = None,
) -> dict[str, Any]:
    normalized_selected_tasks = [str(task).strip() for task in (selected_tasks or []) if str(task).strip()]
    if normalized_selected_tasks:
        return analytics_repo.launch_social_account_catalog_backfill(
            platform=platform,
            account_handle=account,
            source_scope=source_scope,
            date_start=date_start,
            date_end=date_end,
            initiated_by=LOCAL_SCRIPT_LABEL,
            inline_worker_id=worker_id,
            allow_local_dev_inline_bypass=True,
            catalog_action="backfill",
            catalog_action_scope=scope,
            selected_tasks=normalized_selected_tasks,
        )
    return analytics_repo.start_social_account_catalog_backfill(
        platform=platform,
        account_handle=account,
        source_scope=source_scope,
        date_start=date_start,
        date_end=date_end,
        initiated_by=LOCAL_SCRIPT_LABEL,
        inline_worker_id=worker_id,
        allow_local_dev_inline_bypass=True,
        catalog_action="backfill",
        catalog_action_scope=scope,
    )
```

In `main`, pass selected tasks for the direct `backfill` branch:

```python
selected_tasks=list(getattr(args, "selected_tasks", []) or []),
```

- [ ] **Step 4: Run CLI tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/scripts/test_local_catalog_action.py -q
```

Expected: PASS.

- [ ] **Step 5: Write app command builder test**

Create `TRR-APP/apps/web/tests/social-account-profile-backfill-command.test.ts`.

```typescript
import { describe, expect, it } from "vitest";
import {
  buildLocalCatalogCommand,
  defaultLocalCatalogCommandSelectedTasks,
} from "@/components/admin/SocialAccountProfilePage";

describe("buildLocalCatalogCommand", () => {
  it("includes selected tasks for local Backfill Posts fallback", () => {
    const command = buildLocalCatalogCommand("instagram", "bravotv", "bravo", "backfill", [
      "post_details",
      "comments",
      "media",
    ]);

    expect(command).toContain("--platform instagram");
    expect(command).toContain("--account bravotv");
    expect(command).toContain("--source-scope bravo");
    expect(command).toContain("--action backfill");
    expect(command).toContain("--selected-task post_details");
    expect(command).toContain("--selected-task comments");
    expect(command).toContain("--selected-task media");
  });

  it("uses the same default selected tasks as the Backfill Posts copy action", () => {
    expect(defaultLocalCatalogCommandSelectedTasks("instagram", "backfill")).toEqual([
      "post_details",
      "comments",
      "media",
    ]);
    expect(defaultLocalCatalogCommandSelectedTasks("tiktok", "backfill")).toEqual([
      "post_details",
      "comments",
      "media",
    ]);
    expect(defaultLocalCatalogCommandSelectedTasks("instagram", "fill_missing_posts")).toEqual([]);
  });
});
```

- [ ] **Step 6: Run app test and confirm it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
npm test -- social-account-profile-backfill-command.test.ts
```

Expected: FAIL because `buildLocalCatalogCommand` is not exported and does not accept selected tasks.

- [ ] **Step 7: Export and extend command builder**

In `SocialAccountProfilePage.tsx`, replace the helper with:

```typescript
export const defaultLocalCatalogCommandSelectedTasks = (
  platform: SocialPlatformSlug,
  action: "backfill" | "fill_missing_posts",
): CatalogBackfillSelectedTask[] => {
  if (action !== "backfill") {
    return [];
  }
  if (platform === "instagram") {
    return [...INSTAGRAM_BACKFILL_DEFAULT_SELECTED_TASKS];
  }
  if (platform === "tiktok") {
    return [...TIKTOK_BACKFILL_DEFAULT_SELECTED_TASKS];
  }
  return [];
};

export const buildLocalCatalogCommand = (
  platform: SocialPlatformSlug,
  handle: string,
  sourceScope: string,
  action: "backfill" | "fill_missing_posts",
  selectedTasks: CatalogBackfillSelectedTask[] = [],
): string => {
  const selectedTaskArgs = selectedTasks.map((task) => ` --selected-task ${task}`).join("");
  return `cd ~/Projects/TRR/TRR-Backend && source .venv/bin/activate && python3 scripts/socials/local_catalog_action.py --platform ${platform} --account ${handle} --source-scope ${sourceScope} --action ${action}${selectedTaskArgs}`;
};
```

Update `copyCatalogCommand` so Backfill Posts uses that same exported helper:

```typescript
const selectedTasks = defaultLocalCatalogCommandSelectedTasks(platform, action);
await clipboard.writeText(buildLocalCatalogCommand(platform, handle, activeCatalogSourceScope, action, selectedTasks));
```

- [ ] **Step 8: Run app command test**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
npm test -- social-account-profile-backfill-command.test.ts
```

Expected: PASS.

- [ ] **Step 9: Coordinator checkpoint commit on `main`**

```bash
cd /Users/thomashulihan/Projects/TRR
test "$(git branch --show-current)" = "main"
git add TRR-Backend/scripts/socials/local_catalog_action.py TRR-Backend/tests/scripts/test_local_catalog_action.py TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx TRR-APP/apps/web/tests/social-account-profile-backfill-command.test.ts
git commit -m "fix: preserve backfill selected tasks in local fallback"
```

---

### Task 6: Final Verification

**Owner:** Coordinator only, after all subagent patches are integrated into the shared workspace on `main`.

**Files:**
- No source edits

- [ ] **Step 1: Run focused backend verification**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api/routers/test_socials_season_analytics.py::test_post_social_account_catalog_backfill tests/api/routers/test_socials_season_analytics.py::test_post_social_account_catalog_backfill_forwards_selected_tasks tests/api/routers/test_socials_season_analytics.py::test_queue_catalog_backfill_finalize_task_runs_finalize_and_clears_caches tests/repositories/test_social_season_analytics.py::test_recover_pending_social_account_catalog_launch_finalizes_reserved_run tests/repositories/test_social_season_analytics.py::test_recover_pending_social_account_catalog_launch_skips_when_recovery_lock_is_busy tests/repositories/test_social_season_analytics.py::test_get_social_account_catalog_run_progress_recovers_pending_run_before_run_not_found tests/repositories/test_social_season_analytics.py::test_catalog_recent_runs_recovers_pending_reserved_run_without_jobs tests/repositories/test_social_season_analytics.py::test_instagram_materialization_state_requires_detail_fields tests/repositories/test_social_season_analytics.py::test_instagram_materialization_state_is_complete_when_counts_and_detail_fields_are_complete tests/repositories/test_social_season_analytics.py::test_instagram_materialized_detail_gap_counts_treats_raw_data_without_metadata_success_as_incomplete tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_keeps_post_details_when_detail_fields_are_incomplete tests/repositories/test_social_season_analytics.py::test_launch_social_account_catalog_backfill_instagram_completes_existing_run_when_post_details_only_is_already_complete tests/scripts/test_local_catalog_action.py -q
```

Expected: PASS.

- [ ] **Step 2: Run focused app verification**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
npm test -- social-account-profile-backfill-command.test.ts
```

Expected: PASS.

- [ ] **Step 3: Run static checks for removed catalog finalize daemon usage**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
rg "_start_catalog_backfill_finalize_in_background|catalog-finalize" TRR-Backend/api/routers/socials.py TRR-Backend/tests/api/routers/test_socials_season_analytics.py
```

Expected: no matches. Do not include a broad `daemon=True` check here; `TRR-Backend/api/routers/socials.py` already has unrelated daemon threads for timeout/cancel paths that are out of scope for this plan.

- [ ] **Step 4: Run command smoke check**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 scripts/socials/local_catalog_action.py --help | rg -- "--selected-task"
```

Expected: output includes `--selected-task`.

- [ ] **Step 5: Run syntax/patch hygiene checks**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git diff --check
python3 -m py_compile TRR-Backend/api/routers/socials.py TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/scripts/socials/local_catalog_action.py
```

Expected: no whitespace errors and no Python syntax errors.

- [ ] **Step 6: Optional live-state smoke check when DB env is available**

Only run this when the local backend database environment is configured. This is a read-only check for stuck placeholders after implementation; it should not replace tests.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python3 - <<'PY'
from trr_backend.db import pg

rows = pg.fetch_all(
    """
    select r.id::text as run_id, r.status, r.config
    from social.scrape_runs r
    where coalesce(r.config->>'pipeline_ingest_mode', '') = 'shared_account_catalog_backfill'
      and lower(coalesce(r.config->>'launch_state', '')) = 'pending'
      and lower(coalesce(r.config->>'launch_task_resolution_pending', 'false')) = 'true'
      and not exists (select 1 from social.scrape_jobs j where j.run_id = r.id)
    order by r.created_at desc
    limit 5
    """,
    [],
)
print({"pending_zero_job_reserved_runs": len(rows), "sample_run_ids": [row["run_id"] for row in rows]})
PY
```

Expected: either `pending_zero_job_reserved_runs` is `0`, or any listed run self-heals after loading the affected account profile/progress read path.

- [ ] **Step 7: Review acceptance criteria against implemented tests**

Confirm the focused tests prove:
- pending reserved runs recover through both `get_social_account_catalog_run_progress` and `_catalog_recent_runs`;
- pending recovery is guarded by a same-connection advisory lock;
- raw `raw_data` alone does not mark Instagram details complete;
- no-work selected-task launches become `completed_no_work`;
- the copied local command includes selected task flags through `defaultLocalCatalogCommandSelectedTasks`.

- [ ] **Step 8: Confirm verification did not create unreviewed files**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
```

Expected: only intentional implementation and test files are listed. Do not commit generated artifacts from this verification task unless a preceding task explicitly created them.

---

## Self-Review

**Spec coverage:** Finding 1 is covered by Tasks 1 and 2, with Task 2 providing the real recovery layer across progress and profile recent-run reads plus an advisory-lock guard against double finalization. Finding 2 is covered by Task 3, using metadata success/error fields instead of row-count or `raw_data` presence alone. Finding 3 is covered by Task 4. Finding 4 is covered by Task 5, including copy-action default selected-task coverage.

**Placeholder scan:** The plan contains concrete file paths, test names, code snippets, commands, and expected results for each implementation task.

**Type consistency:** `selected_tasks`, `effective_selected_tasks`, `launch_group_id`, `catalog_run_id`, `comments_run_id`, `launch_state`, and `launch_task_resolution_pending` use the same names as the current backend/app contracts. The app command builder uses existing `CatalogBackfillSelectedTask` values: `post_details`, `comments`, and `media`.

**Execution safety:** Parallel work is limited to disjoint write sets, Subagent B returns one combined repository patch, final changes stay on `main`, and rollback is commit-scoped by workstream.
