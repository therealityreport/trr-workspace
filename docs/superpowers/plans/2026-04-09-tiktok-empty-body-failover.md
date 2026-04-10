# TikTok Empty-Body Failover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover TikTok full-history catalog backfills when Modal receives fake-success TikTok API responses (`HTTP 200` + empty body) by reusing the existing `single_runner_fallback` / `scrape_mode="auto"` path and exposing an intentional local rerun control in dev.

**Architecture:** Keep `full_history_cursor_breakpoints` as the primary TikTok path. When discovery fails with `tiktok_discovery_empty_first_page` plus empty-body transport metadata, enqueue a direct `shared_account_posts` fallback job with `runner_strategy="single_runner_fallback"` so the existing TikTok scraper can use HTML + yt-dlp fallback instead of the broken cursor API. Add an explicit admin request flag for dev-only local execution so operators can rerun the same account inline on the local network without overloading the existing `allow_inline_dev_fallback` semantics.

**Tech Stack:** Python 3.11, FastAPI, Supabase/Postgres, Modal, Next.js, React, Vitest, pytest, Ruff

---

## Scope Check

This plan intentionally excludes residential proxy integration. Proxy/auth rotation is a separate subsystem with new env contracts, secret handling, and transport plumbing in `TikTokScraper`; it should be implemented in a separate plan after this failover path exists.

## File Structure

- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Add a helper that classifies TikTok fake-200 empty-body discovery failures.
  - Reuse the existing `single_runner_fallback` posts path when discovery cannot create partitions.
  - Start explicit local TikTok full-history runs as direct posts jobs instead of repartitioned discovery jobs.
- Modify: `TRR-Backend/api/routers/socials.py`
  - Extend the catalog backfill request contract with an explicit execution preference.
  - Allow dev-only local execution when the operator explicitly requests it.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  - Add regression coverage for TikTok transport-failure detection, discovery failover, and local-start job shape.
- Modify: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
  - Add API tests for explicit local TikTok backfill execution preference.
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
  - Align the web request type with the backend backfill contract.
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
  - Add a “Retry Locally” backfill control when TikTok reports the empty-body diagnostic in dev.
- Modify: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
  - Verify the page sends `allow_inline_dev_fallback` plus the new execution preference when the operator clicks the new control.
- Modify: `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
  - Document how to verify remote readiness, when the new failover should auto-engage, and when operators should choose a local rerun.

### Task 1: Classify TikTok Fake-200 Empty-Body Failures

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing repository tests**

```python
def test_is_tiktok_empty_body_transport_failure_detects_fake_200_response() -> None:
    assert social_repo._is_tiktok_empty_body_transport_failure(
        {
            "error_code": "tiktok_discovery_empty_first_page",
            "posts_checked": 0,
            "endpoint_responses": {
                "fetch_posts": {
                    "failure_reason": "non_json_response",
                    "http_status": 200,
                    "content_type": "application/json",
                    "content_length": 0,
                    "request_id": "posts-logid",
                },
                "fetch_user_detail": {
                    "failure_reason": "non_json_response",
                    "http_status": 200,
                    "content_type": "application/json",
                    "content_length": 0,
                    "request_id": "detail-logid",
                },
            },
        }
    ) is True


def test_is_tiktok_empty_body_transport_failure_rejects_real_http_failure() -> None:
    assert social_repo._is_tiktok_empty_body_transport_failure(
        {
            "error_code": "tiktok_discovery_empty_first_page",
            "posts_checked": 0,
            "endpoint_responses": {
                "fetch_posts": {
                    "failure_reason": "http_error",
                    "http_status": 403,
                    "content_type": "text/html",
                    "content_length": 1211,
                }
            },
        }
    ) is False
```

- [ ] **Step 2: Run the repository tests and confirm they fail**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "is_tiktok_empty_body_transport_failure" -v`

Expected: FAIL with `AttributeError: module 'trr_backend.repositories.social_season_analytics' has no attribute '_is_tiktok_empty_body_transport_failure'`

- [ ] **Step 3: Implement the minimal helper in the repository**

```python
def _is_tiktok_empty_body_transport_failure(retrieval_meta: Mapping[str, Any] | None) -> bool:
    meta = _metadata_dict(retrieval_meta)
    if str(meta.get("error_code") or "").strip().lower() != "tiktok_discovery_empty_first_page":
        return False
    if _normalize_non_negative_int(meta.get("posts_checked")) > 0:
        return False

    endpoint_responses = _metadata_dict(meta.get("endpoint_responses"))
    fetch_posts = _metadata_dict(endpoint_responses.get("fetch_posts"))
    failure_reason = str(fetch_posts.get("failure_reason") or "").strip().lower()
    http_status = _normalize_non_negative_int(fetch_posts.get("http_status"))
    content_length = _normalize_non_negative_int(fetch_posts.get("content_length"))

    return (
        failure_reason == "non_json_response"
        and http_status == 200
        and content_length == 0
    )
```

- [ ] **Step 4: Run the tests again and confirm they pass**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "is_tiktok_empty_body_transport_failure" -v`

Expected: PASS with both tests green

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py
git commit -m "test(tiktok): classify fake-200 empty-body discovery failures"
```

### Task 2: Auto-Enqueue `single_runner_fallback` When TikTok Discovery Hits Empty Bodies

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing discovery-stage regression test**

```python
def test_run_shared_account_discovery_stage_enqueues_tiktok_single_runner_fallback_for_empty_body(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(social_repo, "_emit_job_progress", lambda **_kwargs: None)
    monkeypatch.setattr(social_repo, "_touch_shared_account_source", lambda **_kwargs: None)
    monkeypatch.setattr(
        social_repo,
        "_catalog_backfill_run_scheduler_lanes",
        lambda _runner_count: ["lane-a", "lane-b"],
    )
    monkeypatch.setattr(
        social_repo,
        "_discover_shared_account_cursor_partitions",
        lambda **_kwargs: (
            [],
            {
                "error_code": "tiktok_discovery_empty_first_page",
                "pages_scanned": 1,
                "posts_checked": 0,
                "total_posts": 3277,
                "profile_snapshot": {"username": "bravowwhl", "total_posts": 3277},
                "endpoint_responses": {
                    "fetch_posts": {
                        "failure_reason": "non_json_response",
                        "http_status": 200,
                        "content_type": "application/json",
                        "content_length": 0,
                        "request_id": "posts-logid",
                    }
                },
            },
        ),
    )

    create_calls: list[dict[str, Any]] = []
    monkeypatch.setattr(
        social_repo,
        "_create_job",
        lambda *_args, **kwargs: create_calls.append(kwargs) or "fallback-job-1",
    )

    posts_count, comments_count, metadata = social_repo._run_shared_account_discovery_stage(
        run_id="33333333-3333-3333-3333-333333333333",
        platform="tiktok",
        source_scope="bravo",
        account_handle="bravowwhl",
        config={
            "stage": social_repo.SHARED_ACCOUNT_DISCOVERY_STAGE,
            "platform": "tiktok",
            "source_scope": "bravo",
            "account": "bravowwhl",
            "runner_strategy": "full_history_cursor_breakpoints",
            "partition_strategy": social_repo.CATALOG_FULL_HISTORY_CURSOR_PARTITION_STRATEGY,
            "pipeline_ingest_mode": social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
            "required_execution_backend": "modal",
            "allow_local_dev_inline_bypass": False,
            "expected_total_posts": 3277,
            "recovery_depth": 0,
        },
        job_id="job-1",
    )

    assert posts_count == 0
    assert comments_count == 0
    assert metadata["fallback_direct_job_enqueued"] is True
    assert metadata["recovery_reason"] == "tiktok_empty_body_transport_failure"
    assert create_calls[0]["config"]["runner_strategy"] == "single_runner_fallback"
    assert create_calls[0]["config"]["required_execution_backend"] == "modal"
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "enqueues_tiktok_single_runner_fallback_for_empty_body" -v`

Expected: FAIL because `_run_shared_account_discovery_stage(...)` still raises `SharedStageRuntimeError`

- [ ] **Step 3: Implement the failover branch in discovery**

```python
        if (
            platform == "tiktok"
            and _is_tiktok_empty_body_transport_failure(discovery_meta)
            and _normalize_non_negative_int(config.get("recovery_depth")) <= 0
        ):
            fallback_job_id = _create_job(
                None,
                run_id=run_id,
                platform=platform,
                source_scope=source_scope,
                job_type=SHARED_ACCOUNT_POSTS_JOB_TYPE,
                stage=SHARED_ACCOUNT_POSTS_STAGE,
                config={
                    "stage": SHARED_ACCOUNT_POSTS_STAGE,
                    "platform": platform,
                    "source_scope": source_scope,
                    "account": account_handle,
                    "shared_account_source_id": config.get("shared_account_source_id"),
                    "pipeline_ingest_mode": config.get("pipeline_ingest_mode"),
                    "partition_strategy": CATALOG_FULL_HISTORY_CURSOR_PARTITION_STRATEGY,
                    "runner_strategy": "single_runner_fallback",
                    "runner_count": 1,
                    "max_posts_per_target": 0,
                    "discovery_total_posts": discovery_meta.get("total_posts"),
                    "expected_total_posts": expected_total_posts,
                    "discovery_fallback_reason": "tiktok_empty_body_transport_failure",
                    "profile_snapshot": profile_snapshot,
                    "required_worker_lane": config.get("required_worker_lane"),
                    "required_execution_backend": config.get("required_execution_backend"),
                    "allow_local_dev_inline_bypass": bool(config.get("allow_local_dev_inline_bypass")),
                    "recovery_depth": _normalize_non_negative_int(config.get("recovery_depth")) + 1,
                },
                initiated_by=None,
                status="queued" if is_queue_enabled() else "pending",
                priority=100,
                worker_id=None,
                preclaim=False,
            )
            activity["phase"] = "discovery_transport_fallback_enqueued"
            activity["queued_jobs"] = 1
            _flush_progress(force=True)
            return (
                0,
                0,
                {
                    "stage": SHARED_ACCOUNT_DISCOVERY_STAGE,
                    "platform": platform,
                    "account": account_handle,
                    "discovered_partition_count": 0,
                    "fallback_direct_job_enqueued": True,
                    "fallback_job_id": fallback_job_id,
                    "fallback_job_stage": SHARED_ACCOUNT_POSTS_STAGE,
                    "recovery_reason": "tiktok_empty_body_transport_failure",
                    "retrieval_meta": discovery_meta,
                    "expected_total_posts": expected_total_posts,
                    "activity": dict(activity),
                },
            )
```

- [ ] **Step 4: Run the focused repository tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "tiktok_empty_body_transport_failure or enqueues_tiktok_single_runner_fallback_for_empty_body or scrape_shared_tiktok_posts_single_runner_fallback_bypasses_partition_api_path" -v`

Expected: PASS with the new failover test green and the existing `single_runner_fallback` test still green

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py
git commit -m "fix(tiktok): fail over discovery empty-body runs to single-runner fallback"
```

### Task 3: Add Explicit Dev-Only Local Execution Preference for TikTok Backfills

**Files:**
- Modify: `TRR-Backend/api/routers/socials.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing backend API and repository tests**

```python
def test_post_social_account_catalog_backfill_prefers_local_inline_when_explicitly_requested_for_tiktok_in_dev(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret-32-bytes-minimum-abcdef")
    monkeypatch.setenv("APP_ENV", "development")
    token = _make_admin_token("test-secret-32-bytes-minimum-abcdef")

    with (
        patch("trr_backend.repositories.social_season_analytics.is_queue_enabled", return_value=True),
        patch(
            "trr_backend.repositories.social_season_analytics.assert_worker_available_when_queue_enabled",
            return_value=None,
        ),
        patch("api.routers.socials._start_runs_in_background") as mocked_background,
        patch(
            "trr_backend.repositories.social_season_analytics.start_social_account_catalog_backfill",
            return_value={"run_id": "catalog-run-inline-1", "status": "pending"},
        ) as mocked_start,
    ):
        response = client.post(
            "/api/v1/admin/socials/profiles/tiktok/bravowwhl/catalog/backfill",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "backfill_scope": "full_history",
                "allow_inline_dev_fallback": True,
                "execution_preference": "prefer_local_inline",
            },
        )

    assert response.status_code == 200
    assert mocked_start.call_args.kwargs["allow_local_dev_inline_bypass"] is True
    assert mocked_start.call_args.kwargs["inline_worker_id"] == "api-background:catalog:tiktok"


def test_ingest_shared_accounts_starts_tiktok_local_full_history_as_single_runner_fallback(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    create_calls: list[dict[str, Any]] = []
    monkeypatch.setattr(social_repo, "_assert_social_queue_schema_ready", lambda: None)
    monkeypatch.setattr(social_repo, "get_shared_account_sources", lambda **_kwargs: {"sources": [{
        "id": "source-1",
        "platform": "tiktok",
        "account_handle": "bravowwhl",
        "scrape_priority": 100,
    }]})
    monkeypatch.setattr(social_repo, "_create_run", lambda *_args, **_kwargs: "run-1")
    monkeypatch.setattr(
        social_repo,
        "_create_job",
        lambda *_args, **kwargs: create_calls.append(kwargs) or "job-1",
    )
    monkeypatch.setattr(social_repo, "_run_counter_columns_ready", lambda: False)

    social_repo.ingest_shared_accounts(
        platforms=["tiktok"],
        source_scope="bravo",
        accounts_override=["bravowwhl"],
        pipeline_ingest_mode=social_repo.SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
        inline_worker_id="api-background:catalog:tiktok",
        allow_local_dev_inline_bypass=True,
        catalog_action="backfill",
        catalog_action_scope="full_history",
        execution_preference="prefer_local_inline",
    )

    assert create_calls[0]["stage"] == social_repo.SHARED_ACCOUNT_POSTS_STAGE
    assert create_calls[0]["config"]["runner_strategy"] == "single_runner_fallback"
    assert create_calls[0]["config"]["required_execution_backend"] is None
```

- [ ] **Step 2: Run the failing tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_socials_season_analytics.py -k "prefers_local_inline_when_explicitly_requested_for_tiktok_in_dev" -v && python -m pytest tests/repositories/test_social_season_analytics.py -k "starts_tiktok_local_full_history_as_single_runner_fallback" -v`

Expected: FAIL because `CatalogBackfillRequest` has no `execution_preference` field and `ingest_shared_accounts(...)` does not accept or honor it

- [ ] **Step 3: Implement the new execution preference and local-start strategy**

```python
class CatalogBackfillRequest(BaseModel):
    source_scope: Literal["bravo", "creator", "community"] = Field(default="bravo")
    date_start: datetime | None = None
    date_end: datetime | None = None
    backfill_scope: Literal["full_history", "bounded_window"] = Field(default="full_history")
    allow_inline_dev_fallback: bool = Field(default=False)
    execution_preference: Literal["auto", "prefer_local_inline"] = Field(default="auto")
```

```python
def _resolve_social_account_catalog_route_execution(
    *,
    platform: str,
    allow_inline_dev_fallback: bool,
    execution_preference: str = "auto",
    pipeline_ingest_mode: str = "shared_account_catalog_backfill",
) -> dict[str, Any]:
    ...
    if (
        execution_preference == "prefer_local_inline"
        and _can_use_local_catalog_inline_fallback(
            allow_inline_dev_fallback=allow_inline_dev_fallback,
            remote_plane_enforced=remote_plane_enforced,
        )
    ):
        return {
            "queue_enabled": False,
            "used_inline_fallback": True,
            "requires_modal_executor": requires_modal_executor,
        }
```

```python
def ingest_shared_accounts(
    ...
    execution_preference: str | None = None,
) -> dict[str, Any]:
    ...
    prefer_local_tiktok_single_runner = (
        str(execution_preference or "").strip().lower() == "prefer_local_inline"
        and allow_local_dev_inline_bypass
        and normalized_ingest_mode == SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE
        and not bounded_window
        and normalized_catalog_action == "backfill"
        and normalized_catalog_action_scope == "full_history"
    )
    ...
    if prefer_local_tiktok_single_runner and platform == "tiktok":
        job_config["runner_strategy"] = "single_runner_fallback"
        job_config["runner_count"] = 1
        job_config["partition_strategy"] = CATALOG_FULL_HISTORY_CURSOR_PARTITION_STRATEGY
```

- [ ] **Step 4: Re-run the focused backend tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_socials_season_analytics.py -k "prefers_local_inline_when_explicitly_requested_for_tiktok_in_dev" -v && python -m pytest tests/repositories/test_social_season_analytics.py -k "starts_tiktok_local_full_history_as_single_runner_fallback" -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/socials.py trr_backend/repositories/social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/repositories/test_social_season_analytics.py
git commit -m "feat(tiktok): allow explicit local full-history fallback in dev"
```

### Task 4: Surface a Dev-Only “Retry Locally” Control in the Admin Page

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Write the failing app runtime test**

```tsx
it("sends explicit local TikTok backfill preference when retry locally is clicked", async () => {
  mocks.fetchAdminWithAuth.mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.includes("/snapshot")) {
      return jsonResponse({
        summary: {
          ...baseSummary,
          platform: "tiktok",
          account_handle: "bravowwhl",
        },
        catalog_run_progress: {
          run_id: "run-1",
          run_status: "failed",
          last_error_code: "tiktok_discovery_empty_first_page",
          run_diagnostics: {
            last_transport_response: null,
          },
        },
      });
    }
    if (url.includes("/catalog/backfill")) {
      return jsonResponse({ run_id: "run-2", status: "queued" });
    }
    return jsonResponse({});
  });

  render(<SocialAccountProfilePage platform="tiktok" handle="bravowwhl" activeTab="catalog" />);

  const retryButton = await screen.findByRole("button", { name: /retry locally/i });
  fireEvent.click(retryButton);

  await waitFor(() => {
    const call = mocks.fetchAdminWithAuth.mock.calls.find(([input]) =>
      String(input).includes("/catalog/backfill"),
    );
    expect(call).toBeTruthy();
    expect(JSON.parse(String((call?.[1] as RequestInit).body))).toMatchObject({
      backfill_scope: "full_history",
      allow_inline_dev_fallback: true,
      execution_preference: "prefer_local_inline",
    });
  });
});
```

- [ ] **Step 2: Run the app runtime test and confirm it fails**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "sends explicit local TikTok backfill preference when retry locally is clicked"`

Expected: FAIL because the page has no “Retry Locally” control and `CatalogBackfillRequest` does not include `execution_preference`

- [ ] **Step 3: Implement the app contract and button**

```ts
export type CatalogBackfillRequest = {
  date_start?: string | null;
  date_end?: string | null;
  backfill_scope: "full_history" | "bounded_window";
  allow_inline_dev_fallback?: boolean;
  execution_preference?: "auto" | "prefer_local_inline";
};
```

```tsx
const canRetryTikTokLocally =
  platform === "tiktok" &&
  catalogProgress?.last_error_code === "tiktok_discovery_empty_first_page";

...

{canRetryTikTokLocally ? (
  <button
    type="button"
    onClick={() =>
      runCatalogAction("backfill", {
        backfill_scope: "full_history",
        allow_inline_dev_fallback: true,
        execution_preference: "prefer_local_inline",
      })
    }
  >
    Retry Locally
  </button>
) : null}
```

- [ ] **Step 4: Re-run the app runtime test**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "sends explicit local TikTok backfill preference when retry locally is clicked"`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
git add apps/web/src/lib/admin/social-account-profile.ts apps/web/src/components/admin/SocialAccountProfilePage.tsx apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "feat(admin): add local retry control for TikTok empty-body backfill failures"
```

### Task 5: Operator Docs and End-to-End Verification

**Files:**
- Modify: `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`

- [ ] **Step 1: Add the failing-or-missing-doc coverage item to the runbook**

```md
## TikTok Empty-Body Backfill Recovery

- Symptom: `tiktok_discovery_empty_first_page`
- Diagnostic shape:
  - `fetch_posts.http_status = 200`
  - `fetch_posts.content_length = 0`
  - `fetch_posts.failure_reason = non_json_response`
- Automatic recovery:
  - backend enqueues `single_runner_fallback` once for the same run
  - the fallback path uses `TikTokScraper.scrape(... scrape_mode="auto")`
- Manual recovery in dev:
  - use the admin page `Retry Locally` action
  - this starts an inline run with `execution_preference=prefer_local_inline`
```

- [ ] **Step 2: Verify the docs change renders cleanly and the targeted checks still pass**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "tiktok_empty_body_transport_failure or single_runner_fallback" -q && python -m pytest tests/api/routers/test_socials_season_analytics.py -k "prefers_local_inline_when_explicitly_requested_for_tiktok_in_dev" -q && ruff check trr_backend/repositories/social_season_analytics.py api/routers/socials.py tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py`

Expected: PASS

- [ ] **Step 3: Run the app-side verification**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "sends explicit local TikTok backfill preference when retry locally is clicked"`

Expected: PASS

- [ ] **Step 4: Run one real verification cycle**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python scripts/modal/verify_modal_readiness.py --json
```

Then:

1. Start a normal TikTok backfill for `@bravowwhl`.
2. Confirm that an empty-body discovery failure enqueues one `single_runner_fallback` posts job instead of leaving the run at `0 / 3277`.
3. If the same executor still cannot recover, use the admin page `Retry Locally` button.
4. Confirm the local inline run stores `runner_strategy = single_runner_fallback` and either ingests posts or fails with a materially narrower transport error than discovery-only failure.

Expected: the run no longer ends at discovery-only failure without a recovery path

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add docs/runbooks/social_worker_queue_ops.md
git commit -m "docs(tiktok): document empty-body backfill recovery flow"
```

## Self-Review

### Spec Coverage

- Fake-200 TikTok API empty-body diagnosis: covered by Task 1.
- Reuse of existing yt-dlp-capable `single_runner_fallback` path: covered by Tasks 2 and 3.
- Local execution option: covered by Tasks 3 and 4.
- Admin/operator clarity: covered by Tasks 4 and 5.

### Explicit Non-Goals

- Residential proxy support is not implemented here.
- Cookie/auth rotation changes are not implemented here.
- Modal deployment mechanics are verified operationally in Task 5 but not redesigned.

### Placeholder Scan

- No `TODO`, `TBD`, or “similar to above” placeholders remain.
- Every task includes exact file paths, code snippets, commands, and expected outcomes.

### Type Consistency

- New request field name is `execution_preference` everywhere.
- New explicit local enum value is `prefer_local_inline` everywhere.
- Recovery reason string is `tiktok_empty_body_transport_failure` everywhere.

