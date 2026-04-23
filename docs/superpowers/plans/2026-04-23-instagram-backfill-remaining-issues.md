# Instagram Backfill Remaining Issues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the remaining local failures around Instagram all-selected backfill for `instagram/thetraitorsus` by making completed catalog progress reads fast, making backend readiness truthful under load, and repairing the comments follow-up redirect failure path.

**Architecture:** Keep this backend-first and preserve the existing admin API contract. The fix splits into three isolated slices: a terminal-run fast path in the catalog progress repository, a dedicated low-contention readiness lane plus better status labeling, and a comments fetcher retry/re-auth classification path for homepage redirects. Tasks 1 and 3 can run in parallel; Task 2 touches shared pool and operator surfaces, so land it before the final verification pass.

**Tech Stack:** FastAPI, psycopg2 pooled Postgres connections, Bash workspace-health helpers, Scrapling/Patchright plus `httpx`, `pytest`, local `profiles/default.env`

---

## Scope Note

These remaining issues span three subsystems, but they all block the same operator workflow on `http://admin.localhost:3000/social/instagram/thetraitorsus` and share one final smoke test. Keep them in one plan, but commit each subsystem independently.

## File Map

- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  Purpose: add a terminal single-target fast path for `get_social_account_catalog_run_progress(...)`, postpone account-existence checks until they are actually needed, and skip expensive recovery/frontier/live-total work for already-terminal runs.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  Purpose: lock in the new terminal fast path while preserving the active-run path.
- Modify: `TRR-Backend/trr_backend/db/pg.py`
  Purpose: add a dedicated `"health"` read-pool lane with its own env sizing.
- Modify: `TRR-Backend/api/main.py`
  Purpose: route `/health` through the dedicated health read lane instead of the default transactional pool.
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
  Purpose: verify the health pool sizing and read-lane selection.
- Modify: `TRR-Backend/tests/api/test_health.py`
  Purpose: prove `/health` uses `db_read_connection(label="health-probe", pool_name="health")`.
- Modify: `profiles/default.env`
  Purpose: add local defaults for the health read pool sizing.
- Modify: `scripts/lib/workspace-health.sh`
  Purpose: centralize readiness-status labeling so liveness-alive plus readiness-slow is not reported as a hard hang.
- Modify: `scripts/status-workspace.sh`
  Purpose: call the shared readiness-label helper and reserve `hung/unresponsive` for the true dead path.
- Modify: `scripts/test_workspace_health.py`
  Purpose: test the new readiness-label helper and keep readiness/liveness output distinct.
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
  Purpose: retry a homepage redirect once after a permalink re-warm and reclassify an unrecovered homepage redirect as auth failure.
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`
  Purpose: verify the one-time permalink recovery and the final auth-failure classification.
- Create: `docs/ai/local-status/instagram-backfill-remaining-issues-2026-04-23.md`
  Purpose: store the exact before/after timings, `make status` output, run ids, and comments-follow-up outcome for this debugging pass.

## Acceptance Targets

- Completed single-target catalog progress reads for run `13385039-c22a-41cb-9ea5-a670353a689f` return from the app proxy in under `2.0s` cold and under `0.5s` warm.
- `snapshot?run_id=13385039-c22a-41cb-9ea5-a670353a689f` stays fast and unchanged in shape.
- `make status` no longer reports backend readiness as `hung/unresponsive` while `/health/live` is healthy. If readiness is slow but liveness is alive, the label must be softer than a hard hang.
- A homepage redirect during Instagram comments fetch attempts one bounded permalink recovery. If the retry still redirects home, the run fails as `instagram_comments_auth_failed`, not a generic fetch failure.
- No frontend route or payload shape changes are required for `TRR-APP`.

### Task 1: Fast-Path Terminal Catalog Run Progress

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing regression tests for terminal completed runs**

```python
def test_get_social_account_catalog_run_progress_uses_terminal_fast_path_for_completed_single_target_run(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    run_id = "13385039-c22a-41cb-9ea5-a670353a689f"
    run_row = {
        "run_id": run_id,
        "season_id": None,
        "status": "completed",
        "source_scope": "bravo",
        "config": {
            "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
            "platforms": ["instagram"],
            "accounts_override": ["thetraitorsus"],
            "selected_tasks": ["catalog", "comments"],
            "comments_run_id": "91b481c2-46a1-4124-b2a5-a670353a689f",
        },
        "summary": {"total_jobs": 3, "completed_jobs": 3, "failed_jobs": 0, "active_jobs": 0},
        "created_at": datetime(2026, 4, 23, 0, 0, tzinfo=UTC),
        "started_at": datetime(2026, 4, 23, 0, 1, tzinfo=UTC),
        "completed_at": datetime(2026, 4, 23, 0, 8, tzinfo=UTC),
    }
    job_rows = [
        {
            "id": "job-posts",
            "platform": "instagram",
            "job_type": social_repo.SHARED_ACCOUNT_POSTS_JOB_TYPE,
            "status": "completed",
            "items_found": 431,
            "error_message": None,
            "last_error_code": None,
            "created_at": datetime(2026, 4, 23, 0, 1, tzinfo=UTC),
            "started_at": datetime(2026, 4, 23, 0, 1, tzinfo=UTC),
            "completed_at": datetime(2026, 4, 23, 0, 7, tzinfo=UTC),
            "config": {"account": "thetraitorsus", "stage": social_repo.SHARED_ACCOUNT_POSTS_STAGE},
            "metadata": {"activity": {"posts_checked": 431, "saved_posts": 431}},
            "worker_id": "modal:posts",
        }
    ]

    monkeypatch.setattr(social_repo, "_relation_exists", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(social_repo, "_scrape_jobs_features", lambda: {"has_run_id": True, "has_queue_fields": True})
    monkeypatch.setattr(social_repo, "_load_social_account_catalog_run_row", lambda **_kwargs: run_row)
    monkeypatch.setattr(social_repo, "_load_social_account_catalog_jobs", lambda **_kwargs: job_rows)
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(
        social_repo,
        "_build_run_progress_snapshot_payload",
        lambda **_kwargs: {
            "run_status": "completed",
            "post_progress": {"completed_posts": 431, "matched_posts": 431, "total_posts": 432},
            "stages": {},
            "dispatch_health": {},
            "worker_runtime": {},
            "alerts": [],
            "scrape_complete": True,
            "classify_incomplete": False,
        },
    )
    monkeypatch.setattr(social_repo, "_catalog_run_intent_metadata", lambda _config: {})
    monkeypatch.setattr(social_repo, "_resolve_run_attached_followups", lambda **_kwargs: [])
    monkeypatch.setattr(
        social_repo,
        "recover_stale_unclaimed_dispatched_jobs",
        lambda **_kwargs: pytest.fail("terminal fast path should skip stale-job recovery"),
    )
    monkeypatch.setattr(
        social_repo,
        "recover_dispatch_blocked_no_progress_jobs",
        lambda **_kwargs: pytest.fail("terminal fast path should skip blocked-job recovery"),
    )
    monkeypatch.setattr(
        social_repo,
        "_shared_account_partition_progress",
        lambda **_kwargs: pytest.fail("terminal fast path should skip partition progress"),
    )
    monkeypatch.setattr(
        social_repo,
        "_shared_account_frontier_progress",
        lambda **_kwargs: pytest.fail("terminal fast path should skip frontier progress"),
    )
    monkeypatch.setattr(
        social_repo,
        "_cached_live_profile_total_posts",
        lambda *_args, **_kwargs: pytest.fail("terminal fast path should skip live profile refresh"),
    )

    payload = social_repo.get_social_account_catalog_run_progress("instagram", "thetraitorsus", run_id)

    assert payload["run_state"] == "completed"
    assert payload["discovery"] == {}
    assert payload["frontier"] == {}
    assert payload["post_progress"]["total_posts"] == 432


def test_get_social_account_catalog_run_progress_keeps_full_path_for_active_runs(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    run_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    calls = {"stale": 0, "blocked": 0, "frontier": 0}

    monkeypatch.setattr(social_repo, "_relation_exists", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(social_repo, "_scrape_jobs_features", lambda: {"has_run_id": True, "has_queue_fields": True})
    monkeypatch.setattr(
        social_repo,
        "_load_social_account_catalog_run_row",
        lambda **_kwargs: {
            "run_id": run_id,
            "season_id": None,
            "status": "running",
            "source_scope": "bravo",
            "config": {
                "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
                "platforms": ["instagram"],
                "accounts_override": ["thetraitorsus"],
            },
            "summary": {"total_jobs": 2, "completed_jobs": 1, "failed_jobs": 0, "active_jobs": 1},
        },
    )
    monkeypatch.setattr(
        social_repo,
        "_load_social_account_catalog_jobs",
        lambda **_kwargs: [
            {
                "id": "job-fetch",
                "platform": "instagram",
                "job_type": social_repo.SHARED_ACCOUNT_POSTS_JOB_TYPE,
                "status": "running",
                "items_found": 1848,
                "error_message": None,
                "last_error_code": None,
                "config": {"account": "thetraitorsus", "stage": social_repo.SHARED_ACCOUNT_POSTS_STAGE},
                "metadata": {"activity": {"posts_checked": 1848, "saved_posts": 1848}},
                "worker_id": "modal:fetch",
            }
        ],
    )
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(
        social_repo,
        "recover_stale_unclaimed_dispatched_jobs",
        lambda **_kwargs: calls.__setitem__("stale", calls["stale"] + 1) or [],
    )
    monkeypatch.setattr(
        social_repo,
        "recover_dispatch_blocked_no_progress_jobs",
        lambda **_kwargs: calls.__setitem__("blocked", calls["blocked"] + 1) or [],
    )
    monkeypatch.setattr(social_repo, "_build_run_progress_snapshot_payload", lambda **_kwargs: {"run_status": "running", "post_progress": {}, "stages": {}})
    monkeypatch.setattr(social_repo, "_catalog_run_intent_metadata", lambda _config: {})
    monkeypatch.setattr(social_repo, "_shared_account_partition_progress", lambda **_kwargs: {})
    monkeypatch.setattr(
        social_repo,
        "_shared_account_frontier_progress",
        lambda **_kwargs: calls.__setitem__("frontier", calls["frontier"] + 1) or {"status": "running"},
    )
    monkeypatch.setattr(social_repo, "_load_shared_account_source_row", lambda **_kwargs: {})
    monkeypatch.setattr(social_repo, "_shared_profile_contract", lambda **_kwargs: {})
    monkeypatch.setattr(social_repo, "_queued_jobs_by_type", lambda _stages_payload: {})
    monkeypatch.setattr(social_repo, "_shared_account_recovery_payload", lambda **_kwargs: {})
    monkeypatch.setattr(social_repo, "_build_catalog_run_progress_alerts", lambda **_kwargs: [])
    monkeypatch.setattr(social_repo, "_shared_account_expected_total_posts_from_config", lambda *_args, **_kwargs: 0)
    monkeypatch.setattr(social_repo, "_cached_live_profile_total_posts_cached_only", lambda *_args, **_kwargs: 0)
    monkeypatch.setattr(social_repo, "_cached_live_profile_total_posts", lambda *_args, **_kwargs: 0)
    monkeypatch.setattr(social_repo, "_best_known_social_account_total_posts", lambda *_args, **_kwargs: 0)
    monkeypatch.setattr(social_repo, "_social_account_profile_total_posts", lambda *_args, **_kwargs: 0)
    monkeypatch.setattr(social_repo, "_shared_catalog_total_posts", lambda *_args, **_kwargs: 0)

    social_repo.get_social_account_catalog_run_progress("instagram", "thetraitorsus", run_id)

    assert calls == {"stale": 1, "blocked": 1, "frontier": 1}
```

- [ ] **Step 2: Run the targeted repository tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "terminal_fast_path or keeps_full_path_for_active_runs or skips_live_instagram_total_refresh_while_active"
```

Expected: `FAIL` because the terminal fast-path helper does not exist yet and completed runs still walk the expensive recovery/frontier/live-refresh path.

- [ ] **Step 3: Implement the terminal fast path in the repository**

```python
def _can_fast_path_terminal_catalog_progress(
    *,
    run_row: Mapping[str, Any],
    configured_platforms: set[str],
    configured_accounts: set[str],
    normalized_platform: str,
    normalized_account: str,
) -> bool:
    run_status = str(run_row.get("status") or "").strip().lower()
    return (
        run_status in {"completed", "failed", "cancelled"}
        and (not configured_platforms or configured_platforms == {normalized_platform})
        and (not configured_accounts or configured_accounts == {normalized_account})
    )


def _build_terminal_catalog_run_progress_payload(
    *,
    run_row: Mapping[str, Any],
    job_rows: Sequence[Mapping[str, Any]],
    run_id: str,
    run_config: Mapping[str, Any],
    recent_log_limit: int,
) -> dict[str, Any]:
    payload = _build_run_progress_snapshot_payload(
        run_row=run_row,
        job_rows=job_rows,
        run_id=run_id,
        season_id=str(run_row.get("season_id") or "") or None,
        recent_log_limit=recent_log_limit,
        summary_override=None,
    )
    payload.update(_catalog_run_intent_metadata(run_config))
    payload["launch_group_id"] = str(run_config.get("launch_group_id") or "").strip() or None
    payload["launch_state"] = str(run_config.get("launch_state") or "").strip().lower() or None
    payload["selected_tasks"] = _normalize_optional_social_account_catalog_backfill_selected_tasks(
        run_config.get("selected_tasks")
    )
    payload["effective_selected_tasks"] = (
        _normalize_optional_social_account_catalog_backfill_selected_tasks(run_config.get("effective_selected_tasks"))
        or payload["selected_tasks"]
    )
    payload["comments_run_id"] = str(run_config.get("comments_run_id") or "").strip() or None
    payload["attached_followups"] = _resolve_run_attached_followups(
        run_config=run_config,
        run_id=run_id,
        run_status=str(run_row.get("status") or "").strip().lower() or None,
        comments_run_id=payload["comments_run_id"],
    )
    payload["resume_state"] = run_config.get("resume_state") if isinstance(run_config.get("resume_state"), dict) else None
    payload["discovery"] = {}
    payload["frontier"] = {}
    payload["expected_total_posts"] = _normalize_non_negative_int(_metadata_dict(payload.get("post_progress")).get("total_posts")) or None
    payload["source_total_posts_current"] = None
    payload["completion_gap_posts"] = 0
    payload["completion_gap_reason"] = None
    payload["alerts"] = list(payload.get("alerts") or [])
    payload["run_state"] = _derive_catalog_run_state(
        run_status=str(payload.get("run_status") or ""),
        scrape_complete=bool(payload.get("scrape_complete")),
        classify_incomplete=bool(payload.get("classify_incomplete")),
        stages_payload=_metadata_dict(payload.get("stages")),
        frontier_progress={},
        recovery={},
    )
    return payload
```

Reorder `get_social_account_catalog_run_progress(...)` so it loads and validates the run first, then chooses one of two branches:

```python
if _can_fast_path_terminal_catalog_progress(
    run_row=run_row,
    configured_platforms=configured_platforms,
    configured_accounts=configured_accounts,
    normalized_platform=normalized_platform,
    normalized_account=normalized_account,
):
    return _build_terminal_catalog_run_progress_payload(
        run_row=run_row,
        job_rows=job_rows,
        run_id=run_id,
        run_config=run_config,
        recent_log_limit=safe_recent_log_limit,
    )

_assert_social_account_profile_exists(normalized_platform, normalized_account)
recover_stale_unclaimed_dispatched_jobs(
    run_id=run_id,
    platform=normalized_platform,
    account_handle=normalized_account,
    limit=25,
)
recover_dispatch_blocked_no_progress_jobs(limit=25)
```

The fast path must preserve payload keys but skip:

```text
_assert_social_account_profile_exists(...)
recover_stale_unclaimed_dispatched_jobs(...)
recover_dispatch_blocked_no_progress_jobs(...)
_shared_account_partition_progress(...)
_shared_account_frontier_progress(...)
_cached_live_profile_total_posts(...)
_load_shared_account_source_row(...)
_shared_profile_contract(...)
_shared_account_recovery_payload(...)
_build_catalog_run_progress_alerts(...)
```

- [ ] **Step 4: Run the repository tests again and make sure they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "terminal_fast_path or keeps_full_path_for_active_runs or skips_live_instagram_total_refresh_while_active"
```

Expected: `3 passed`

- [ ] **Step 5: Commit the catalog-progress fast-path slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: fast-path terminal catalog progress reads"
```

### Task 2: Make Backend Readiness Low-Contention And Truthful

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py`
- Modify: `TRR-Backend/api/main.py`
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
- Modify: `TRR-Backend/tests/api/test_health.py`
- Modify: `profiles/default.env`
- Modify: `scripts/lib/workspace-health.sh`
- Modify: `scripts/status-workspace.sh`
- Modify: `scripts/test_workspace_health.py`

- [ ] **Step 1: Write the failing tests for the dedicated health lane and softer status label**

```python
def test_db_read_connection_uses_health_pool_sizing(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_pool = _FakePool()
    created: list[tuple[int, int]] = []

    def _pool_factory(*, minconn, maxconn, **_kwargs):
        created.append((minconn, maxconn))
        return fake_pool

    monkeypatch.setenv("TRR_HEALTH_DB_POOL_MINCONN", "1")
    monkeypatch.setenv("TRR_HEALTH_DB_POOL_MAXCONN", "2")
    monkeypatch.setattr(pg, "resolve_database_url_candidate_details", lambda: (_detail("postgresql://db.example.com/postgres"),))
    monkeypatch.setattr(pg, "ThreadedConnectionPool", _pool_factory)

    with pg.db_read_connection(label="health-probe", pool_name="health"):
        pass

    assert created == [(1, 2)]


def test_health_uses_health_read_pool() -> None:
    calls: list[tuple[str, str]] = []

    @contextmanager
    def _fake_db_read_connection(*, label: str, pool_name: str):
        calls.append((label, pool_name))
        yield MagicMock()

    with patch.object(_real_pg, "db_read_connection", _fake_db_read_connection):
        resp = client.get("/health")

    assert resp.status_code == 200
    assert calls == [("health-probe", "health")]
```

```python
def test_backend_readiness_label_degrades_when_liveness_is_alive() -> None:
    result = _run_bash(
        f'''
        source "{SCRIPT_PATH}"
        printf '%s' "$(workspace_backend_readiness_label 0 1)"
        '''
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "degraded/slow"
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "health_pool"
.venv/bin/python -m pytest -q tests/api/test_health.py -k "health_uses_health_read_pool"

cd /Users/thomashulihan/Projects/TRR
.venv/bin/python -m pytest -q scripts/test_workspace_health.py -k "readiness_label_degrades"
```

Expected: `FAIL` because there is no `"health"` pool sizing, `/health` still uses `db_connection(...)`, and the shared script helper does not exist.

- [ ] **Step 3: Implement the health pool and shared readiness label**

```python
def _pool_size_env_names(pool_name: str) -> tuple[str, str]:
    if pool_name == "social_profile":
        return "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN", "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN"
    if pool_name == "health":
        return "TRR_HEALTH_DB_POOL_MINCONN", "TRR_HEALTH_DB_POOL_MAXCONN"
    return "TRR_DB_POOL_MINCONN", "TRR_DB_POOL_MAXCONN"
```

```python
@app.get("/health")
def health():
    try:
        with pg.db_read_connection(label="health-probe", pool_name="health") as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return {"status": "healthy", "service": "trr-backend", "database": "connected"}
    except Exception:
        logger.warning("[health] readiness probe failed", exc_info=True)
        return JSONResponse(
            status_code=503,
            content={"status": "degraded", "service": "trr-backend", "database": "unreachable"},
        )
```

Add local defaults:

```dotenv
TRR_HEALTH_DB_POOL_MINCONN=1
TRR_HEALTH_DB_POOL_MAXCONN=2
```

Move the label logic into `scripts/lib/workspace-health.sh`:

```bash
workspace_backend_readiness_label() {
  local readiness_ok="$1"
  local liveness_ok="$2"
  if [[ "$readiness_ok" == "1" ]]; then
    printf 'healthy\n'
    return 0
  fi
  if [[ "$liveness_ok" == "1" ]]; then
    printf 'degraded/slow\n'
    return 0
  fi
  printf 'hung/unresponsive\n'
}
```

Then update `scripts/status-workspace.sh` so the current curl checks feed that helper instead of hard-coding `hung/unresponsive` whenever readiness retries exhaust.

- [ ] **Step 4: Run the targeted health and workspace tests again**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "health_pool or social_profile_pool_sizing"
.venv/bin/python -m pytest -q tests/api/test_health.py

cd /Users/thomashulihan/Projects/TRR
.venv/bin/python -m pytest -q scripts/test_workspace_health.py
```

Expected: all targeted tests pass, including the existing readiness/liveness split tests.

- [ ] **Step 5: Commit the readiness slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/db/pg.py TRR-Backend/api/main.py TRR-Backend/tests/db/test_pg_pool.py TRR-Backend/tests/api/test_health.py profiles/default.env scripts/lib/workspace-health.sh scripts/status-workspace.sh scripts/test_workspace_health.py
git commit -m "fix: isolate backend readiness from busy default pool"
```

### Task 3: Repair Instagram Comments Homepage Redirect Handling

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`

- [ ] **Step 1: Write the failing retry and classification tests**

```python
def test_3xx_redirect_to_homepage_rewarms_permalink_and_retries_once() -> None:
    fetcher = _build_fetcher()
    fetcher._fetch_api = AsyncMock(
        side_effect=[
            _mock_httpx_response(status_code=302, location="/"),
            _mock_httpx_response(status_code=200, json_data={"status": "ok", "comments": []}),
        ]
    )
    fetcher._fetch_page = AsyncMock(return_value=_mock_httpx_response(status_code=200, json_data={"status": "ok"}))
    fetcher._rebuild_http_client = AsyncMock()

    result = asyncio.run(
        fetcher._fetch_json_response(
            "https://www.instagram.com/api/v1/media/1/comments/",
            referer="https://www.instagram.com/p/DXXAP-Ekb59/",
        )
    )

    assert fetcher._fetch_api.await_count == 2
    fetcher._fetch_page.assert_awaited_once_with(
        "https://www.instagram.com/p/DXXAP-Ekb59/",
        referer="https://www.instagram.com/p/DXXAP-Ekb59/",
    )
    assert result["failed"] is False


def test_3xx_redirect_to_homepage_marks_auth_failed_after_recovery_retry() -> None:
    fetcher = _build_fetcher()
    fetcher._fetch_api = AsyncMock(
        side_effect=[
            _mock_httpx_response(status_code=302, location="/"),
            _mock_httpx_response(status_code=302, location="/"),
        ]
    )
    fetcher._fetch_page = AsyncMock(return_value=_mock_httpx_response(status_code=200, json_data={"status": "ok"}))
    fetcher._rebuild_http_client = AsyncMock()

    result = asyncio.run(
        fetcher._fetch_json_response(
            "https://www.instagram.com/api/v1/media/1/comments/",
            referer="https://www.instagram.com/p/DXXAP-Ekb59/",
        )
    )

    assert result["failed"] is True
    assert result["auth_failed"] is True
    assert result["reason"] == "redirect_to_homepage"
```

- [ ] **Step 2: Run the targeted comments tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/socials/test_instagram_comments_scrapling_retry.py -k "redirect_to_homepage"
```

Expected: `FAIL` because homepage redirects currently return immediately with `auth_failed=False` and no recovery attempt.

- [ ] **Step 3: Add one permalink re-warm and final auth-failure classification**

```python
async def _recover_homepage_redirect(self, *, referer: str) -> bool:
    recovery_response = await self._fetch_page(referer, referer=referer)
    text = _response_text(recovery_response)
    if _status_code(recovery_response) in {401, 403} or _auth_failure_text(text):
        return False
    self._merge_warmup_cookies(recovery_response)
    await self._rebuild_http_client()
    return True
```

Inside `_fetch_json_response(...)`, add one bounded homepage-recovery branch:

```python
attempt = 0
homepage_redirect_recovery_attempted = False
last_transient_reason: str | None = None
while True:
    attempt += 1
    response = await self._fetch_api(url, referer=referer, params=params)
    status_code = _status_code(response)
    text = _response_text(response)
    auth_failed = status_code in {401, 403} or _auth_failure_text(text)

    if 300 <= status_code < 400:
        location = _safe_location(response)
        reason = (
            "redirect_to_login"
            if "/accounts/login" in location
            else "redirect_to_checkpoint"
            if ("/challenge" in location or "/checkpoint" in location)
            else "redirect_to_homepage"
        )
        if reason == "redirect_to_homepage" and not homepage_redirect_recovery_attempted:
            homepage_redirect_recovery_attempted = True
            recovered = await self._recover_homepage_redirect(referer=referer)
            if recovered:
                continue
            auth_failed = True
        elif reason == "redirect_to_homepage":
            auth_failed = True

        return {
            "failed": True,
            "auth_failed": auth_failed or any(token in location for token in ("login", "challenge", "checkpoint")),
            "reason": reason,
            "retryable": False,
            "payload": None,
        }
```

Keep the behavior bounded:

```text
- exactly one permalink re-warm
- no unbounded redirect loops
- keep `reason == "redirect_to_homepage"` for runtime metadata continuity
- switch only the final classification to `auth_failed=True`
```

- [ ] **Step 4: Run the targeted comments tests again**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/socials/test_instagram_comments_scrapling_retry.py -k "redirect_to_homepage"
```

Expected: `2 passed`

- [ ] **Step 5: Commit the comments redirect slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py
git commit -m "fix: retry instagram comments homepage redirects once"
```

### Task 4: Capture Before/After Evidence And Final Smoke

**Files:**
- Create: `docs/ai/local-status/instagram-backfill-remaining-issues-2026-04-23.md`

- [ ] **Step 1: Create the verification note template before running the smoke pass**

````markdown
# Instagram Backfill Remaining Issues Verification — 2026-04-23

## Fixed slices
- terminal catalog progress fast path
- dedicated health readiness lane
- instagram comments homepage redirect recovery

## Target ids
- completed catalog run: `13385039-c22a-41cb-9ea5-a670353a689f`
- comments follow-up run: `91b481c2-46a1-4124-b2a5-a670353a689f`
- failing shortcode: `DXXAP-Ekb59`

## Commands
```bash
make status
curl -sS -o /tmp/catalog-progress.json -w 'catalog_progress:%{http_code} %{time_total}\n' 'http://127.0.0.1:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/catalog/runs/13385039-c22a-41cb-9ea5-a670353a689f/progress'
curl -sS -o /tmp/catalog-snapshot.json -w 'catalog_snapshot:%{http_code} %{time_total}\n' 'http://127.0.0.1:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/snapshot?run_id=13385039-c22a-41cb-9ea5-a670353a689f'
curl -sS -o /tmp/backend-health.txt -w 'backend_health:%{http_code} %{time_total}\n' 'http://127.0.0.1:8000/health'
curl -sS -o /tmp/backend-live.txt -w 'backend_live:%{http_code} %{time_total}\n' 'http://127.0.0.1:8000/health/live'
```

## Record
- progress route status/time
- snapshot route status/time
- `make status` backend readiness label
- comments follow-up final error code or success outcome
- one browser smoke note from `http://admin.localhost:3000/social/instagram/thetraitorsus`
````

- [ ] **Step 2: Run the focused test suites after all three code slices land**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "terminal_fast_path or keeps_full_path_for_active_runs or skips_live_instagram_total_refresh_while_active"
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py tests/api/test_health.py
.venv/bin/python -m pytest -q tests/socials/test_instagram_comments_scrapling_retry.py -k "redirect_to_homepage"

cd /Users/thomashulihan/Projects/TRR
.venv/bin/python -m pytest -q scripts/test_workspace_health.py
```

Expected: all targeted suites pass before touching the browser again.

- [ ] **Step 3: Run the live local smoke checks and record the outcomes**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
make status
curl -sS -o /tmp/catalog-progress.json -w 'catalog_progress:%{http_code} %{time_total}\n' 'http://127.0.0.1:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/catalog/runs/13385039-c22a-41cb-9ea5-a670353a689f/progress'
curl -sS -o /tmp/catalog-snapshot.json -w 'catalog_snapshot:%{http_code} %{time_total}\n' 'http://127.0.0.1:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/snapshot?run_id=13385039-c22a-41cb-9ea5-a670353a689f'
curl -sS -o /tmp/backend-health.txt -w 'backend_health:%{http_code} %{time_total}\n' 'http://127.0.0.1:8000/health'
curl -sS -o /tmp/backend-live.txt -w 'backend_live:%{http_code} %{time_total}\n' 'http://127.0.0.1:8000/health/live'
```

Expected:

```text
catalog_progress:200 <2.0s
catalog_snapshot:200 <0.25s
backend_live:200
backend_health:200 or 503 quickly, but `make status` does not label the backend as `hung/unresponsive` while liveness is healthy
```

Then do one browser smoke on:

```text
http://admin.localhost:3000/social/instagram/thetraitorsus
```

Verify:

```text
- completed run detail opens without a multi-minute wait
- comments follow-up either succeeds or, if it still cannot fetch, surfaces `instagram_comments_auth_failed`
- the UI no longer reports the original `Failed to start social account catalog backfill` launch error
```

- [ ] **Step 4: Save the evidence note**

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/ai/local-status/instagram-backfill-remaining-issues-2026-04-23.md
git commit -m "docs: capture instagram backfill remaining-issues verification"
```

## Self-Review

- Spec coverage check:
  - terminal catalog progress latency gap: covered by Task 1 and Task 4
  - readiness hangs versus liveness truth: covered by Task 2 and Task 4
  - Instagram comments redirect failure path: covered by Task 3 and Task 4
  - operator-facing proof against the named route and run ids: covered by Task 4
- Placeholder scan:
  - No `TODO`, `TBD`, or "implement later" placeholders remain
  - Every code-changing task includes concrete file paths, commands, and commit steps
  - Every verification step names the exact local URLs, run ids, and expected outcomes
- Type consistency:
  - The plan uses one helper name for the terminal repository fast path: `_can_fast_path_terminal_catalog_progress`
  - The plan uses one helper name for the terminal payload builder: `_build_terminal_catalog_run_progress_payload`
  - The plan uses one helper name for the comments redirect repair: `_recover_homepage_redirect`
  - The health lane consistently uses `db_read_connection(label="health-probe", pool_name="health")`
