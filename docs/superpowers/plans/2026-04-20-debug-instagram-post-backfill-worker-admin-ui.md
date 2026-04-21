# Debug the Instagram Post Backfill Worker (Admin UI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Backfill Posts` for Instagram reliably launch the correct full-history worker path, automatically supersede stale runtime-pinned runs without duplicate replacements, and show the right remediation state in the admin UI.

**Architecture:** Build on the current in-progress backend/runtime convergence work instead of re-specifying it. First lock in the Instagram full-history kickoff path so `Backfill Posts` never falls back into `details_refresh`. Then finish authoritative Modal runtime publication plus locked, idempotent runtime supersession on stale runs. Finally extend the existing admin UI remediation flow to pivot from superseded runs to their replacements and keep the manual fallback button visible only when automatic replacement did not clearly succeed.

**Tech Stack:** FastAPI, Supabase/Postgres, Modal, Next.js 16 App Router, pytest, Vitest

---

## Summary

This revision replaces the older three-phase debug/remediation plan with an implementation plan that matches the current repo state:

1. The Instagram full-history kickoff regression is already understood: `catalog_action=backfill` plus `catalog_action_scope=full_history` must not launch `details_refresh`.
2. Runtime drift and remediation plumbing already exist in-progress in the backend and app, so the remaining work is to finish authoritative remote runtime stamping, durable single-fire supersession, and the superseded-run UI flow.
3. The admin UI already has a `Cancel + Requeue clean run` button for `no_eligible_worker_for_required_runtime`; this plan extends that path rather than replacing it.

## File Structure

### Backend

| Path | Responsibility |
|---|---|
| `TRR-Backend/trr_backend/repositories/social_season_analytics.py` | Canonical catalog kickoff, runtime identity, claim filtering, stale-run supersession, run-progress payloads |
| `TRR-Backend/trr_backend/modal_dispatch.py` | Modal dispatcher heartbeat publication |
| `TRR-Backend/scripts/socials/worker.py` | Real worker heartbeat publication |
| `TRR-Backend/api/routers/socials.py` | Existing admin routes for `Backfill Posts` and `catalog/remediate-drift` |
| `TRR-Backend/tests/repositories/test_social_season_analytics.py` | Repository-level runtime, kickoff, and supersession regressions |
| `TRR-Backend/tests/api/routers/test_socials_season_analytics.py` | Route-level remediation and backfill coverage |

### App

| Path | Responsibility |
|---|---|
| `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts` | Run-progress and remediation response types |
| `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx` | Catalog Run Progress UI, alert rendering, auto-pivot logic, manual remediation |
| `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/remediate-drift/route.ts` | Existing app proxy route for remediation |
| `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx` | Runtime UI regressions for stale-run alerting and pivot behavior |

### Docs

| Path | Responsibility |
|---|---|
| `TRR-Backend/docs/runbooks/social_worker_queue_ops.md` | Operator contract for runtime drift, supersession, and manual remediation |
| `TRR-Backend/docs/ai/local-status/instagram-backfill-speed-recovery.md` | Current-state local status only if wording becomes inaccurate |

---

### Task 1: Lock In Instagram Full-History Kickoff

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Extend the failing repository tests for Instagram full-history kickoff**

```python
def test_start_social_account_catalog_backfill_auto_resumes_instagram_full_history_frontier(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    ingest_calls: list[dict[str, Any]] = []

    monkeypatch.setattr(social_repo.pg, "db_connection", lambda **_kwargs: nullcontext(object()))
    monkeypatch.setattr(social_repo.pg, "db_cursor", lambda conn=None, **_kwargs: nullcontext(object()))
    monkeypatch.setattr(social_repo.pg, "fetch_one_with_cursor", lambda *_args, **_kwargs: {"locked": True})
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: [{}])
    monkeypatch.setattr(social_repo, "get_active_social_account_catalog_run", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(social_repo, "is_queue_enabled", lambda: False)
    monkeypatch.setattr(
        social_repo,
        "_latest_account_frontier",
        lambda *_args, **_kwargs: {
            "id": "frontier-1",
            "run_id": "old-run",
            "next_cursor": "cursor-123",
            "total_posts": 80,
            "posts_checked": 40,
            "posts_saved": 38,
            "pages_scanned": 4,
            "last_transport": "authenticated",
            "exhausted": False,
        },
    )
    monkeypatch.setattr(
        social_repo,
        "ingest_shared_accounts",
        lambda **kwargs: ingest_calls.append(dict(kwargs)) or {"run_id": "new-run", "status": "queued"},
    )

    payload = social_repo.start_social_account_catalog_backfill(
        "instagram",
        "bravotv",
        catalog_action="backfill",
        catalog_action_scope="full_history",
    )

    assert payload["run_id"] == "new-run"
    assert ingest_calls[0]["catalog_action"] == "backfill"
    assert ingest_calls[0]["catalog_action_scope"] == "full_history"
    assert ingest_calls[0]["social_account_post_details_only"] is False
```

- [ ] **Step 2: Extend the failing app runtime test that `Backfill Posts` still posts `full_history`**

```tsx
it("queues Instagram Backfill Posts as full_history from the admin page", async () => {
  const backfillBodies: Array<Record<string, unknown>> = [];

  mocks.fetchAdminWithAuth.mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.includes("/summary")) {
      return jsonResponse(baseSummary);
    }
    if (url.includes("/catalog/backfill")) {
      backfillBodies.push(JSON.parse(String(init?.body || "{}")));
      return jsonResponse({ run_id: "run-backfill-1", status: "queued" });
    }
    if (url.includes("/catalog/posts")) {
      return jsonResponse({ items: [], pagination: { page: 1, page_size: 25, total: 0, total_pages: 1 } });
    }
    if (url.includes("/catalog/review-queue")) {
      return jsonResponse({ items: [] });
    }
    throw new Error(`Unhandled request: ${url}`);
  });

  render(<SocialAccountProfilePage platform="instagram" handle="bravotv" activeTab="catalog" />);

  fireEvent.click(await screen.findByRole("button", { name: "Backfill Posts" }));

  await waitFor(() => {
    expect(backfillBodies).toEqual([{ source_scope: "bravo", backfill_scope: "full_history" }]);
  });
});
```

- [ ] **Step 3: Run the targeted tests to verify the kickoff contract is covered**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "start_social_account_catalog_backfill_auto_resumes_instagram_full_history_frontier or start_social_account_catalog_backfill_non_instagram_full_history_keeps_existing_catalog_flow or remediate_social_account_catalog_strategy_drift_cancels_details_refresh_full_history_runs"
```

Expected: PASS for the existing kickoff/remediation regressions, or FAIL only if the current WIP regressed the full-history path.

- [ ] **Step 4: Patch the kickoff path only if the targeted tests fail**

```python
skip_implicit_frontier_resume = (
    normalized_platform == "instagram"
    and normalized_catalog_action == "backfill"
    and normalized_catalog_action_scope == "full_history"
)

result = ingest_shared_accounts(
    platforms=[normalized_platform],
    source_scope=source_scope,
    accounts_override=[normalized_account],
    date_start=normalized_date_start,
    date_end=normalized_date_end,
    pipeline_ingest_mode=SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE,
    initiated_by=initiated_by,
    inline_worker_id=inline_worker_id,
    allow_local_dev_inline_bypass=allow_local_dev_inline_bypass,
    execution_preference=normalized_execution_preference,
    resume_frontier_cursor=normalized_resume_cursor,
    resume_frontier_snapshot=normalized_resume_snapshot,
    catalog_action=normalized_catalog_action,
    catalog_action_scope=normalized_catalog_action_scope,
    social_account_post_details_only=False,
)
```

- [ ] **Step 5: Run the focused backend and app tests again**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "start_social_account_catalog_backfill or remediate_social_account_catalog_strategy_drift"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run test:ci -- social-account-profile-page.runtime.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "fix(instagram): preserve full-history kickoff for admin backfill"
```

### Task 2: Publish Authoritative Modal Runtime Heartbeats

**Files:**
- Modify: `TRR-Backend/trr_backend/modal_dispatch.py`
- Modify: `TRR-Backend/scripts/socials/worker.py`
- Verify and adjust only if needed: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing tests for authoritative runtime heartbeats**

```python
def test_resolve_authoritative_catalog_runtime_version_uses_fresh_modal_worker_heartbeat(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        social_repo,
        "_query_worker_health",
        lambda: {
            "workers": [
                {
                    "worker_id": "modal:social-dispatcher",
                    "is_fresh": True,
                    "is_healthy": True,
                    "last_seen_at": "2026-04-20T18:00:00+00:00",
                    "metadata": {
                        "execution_backend_canonical": "modal",
                        "runtime_version": {
                            "execution_backend": "modal",
                            "modal_image": "im-AAA",
                            "commit_sha": "abc123",
                            "label": "modal:main · im-AAA",
                        },
                    },
                }
            ]
        },
    )

    runtime = social_repo._resolve_authoritative_catalog_runtime_version(required_execution_backend="modal")

    assert runtime["modal_image"] == "im-AAA"
    assert runtime["execution_backend"] == "modal"


def test_resolve_authoritative_catalog_runtime_version_returns_unknown_without_fresh_modal_heartbeats(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(social_repo, "_query_worker_health", lambda: {"workers": []})
    monkeypatch.setattr(
        social_repo,
        "_resolve_runtime_version_stamp",
        lambda: {"execution_backend": "local", "commit_sha": "api-only", "label": "local"},
    )

    runtime = social_repo._resolve_authoritative_catalog_runtime_version(required_execution_backend="modal")

    assert runtime == {}
```

- [ ] **Step 2: Run the targeted authoritative-runtime slice and verify current failures**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "authoritative_catalog_runtime or no_authoritative_runtime"
```

Expected: FAIL until the real Modal heartbeat publishers include `metadata.runtime_version`.

- [ ] **Step 3: Patch the Modal dispatcher heartbeat publisher**

```python
metadata = {
    "dispatcher_name": dispatcher_name,
    "execution_backend_canonical": _MODAL_EXECUTION_BACKEND,
    "execution_mode_canonical": _REMOTE_EXECUTION_MODE,
    "runtime_version": dict(_resolve_runtime_version_stamp()),
    **(metadata_updates or {}),
}
```

- [ ] **Step 4: Patch the real worker heartbeat publisher**

```python
metadata = {
    "auth_capabilities": get_worker_auth_capabilities(),
    "hostname": socket.gethostname(),
    "pid": os.getpid(),
    "worker_lane": _worker_lane_from_env(),
    "worker_script": _worker_script_label(),
    "runtime_version": dict(_resolve_runtime_version_stamp()),
}
```

- [ ] **Step 5: Re-run the targeted authoritative-runtime slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "authoritative_catalog_runtime or no_authoritative_runtime"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/modal_dispatch.py \
  TRR-Backend/scripts/socials/worker.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "feat(runtime): publish authoritative modal runtime heartbeats"
```

### Task 3: Finish Semantic Runtime Matching And Single-Fire Supersession

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify only if helper wiring changes: `TRR-Backend/api/routers/socials.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Test: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`

- [ ] **Step 1: Write the failing unit tests for semantic matching and single-fire supersession**

```python
def test_runtime_versions_equivalent_prefers_modal_image_over_label() -> None:
    left = {"execution_backend": "modal", "modal_image": "im-AAA", "label": "modal:main · im-AAA"}
    right = {"execution_backend": "modal", "modal_image": "im-AAA", "label": "modal:main · im-OTHER-LABEL"}

    assert social_repo._runtime_versions_equivalent(left, right) is True


def test_runtime_supersession_returns_existing_replacement_when_already_handled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        social_repo,
        "_load_social_account_catalog_run_row",
        lambda **_kwargs: {
            "id": "old-run",
            "config": {
                "replacement_run_id": "new-run",
                "supersession_handled": True,
                "auto_requeue_status": "queued",
            },
        },
    )

    payload = social_repo.remediate_social_account_catalog_runtime_supersession(
        platform="instagram",
        account_handle="bravotv",
        run_id="old-run",
        initiated_by="codex@test",
    )

    assert payload["replacement_run_id"] == "new-run"
    assert payload["created_replacement"] is False
```

- [ ] **Step 2: Write the failing concurrency contract test**

```python
def test_runtime_supersession_marks_original_run_before_requeue_success(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    updates: list[dict[str, Any]] = []

    monkeypatch.setattr(
        social_repo,
        "_merge_catalog_run_config",
        lambda *, run_id, metadata_updates: updates.append({"run_id": run_id, **metadata_updates}),
    )
    monkeypatch.setattr(
        social_repo,
        "start_social_account_catalog_backfill",
        lambda **_kwargs: {"run_id": "replacement-run", "status": "queued"},
    )

    social_repo._record_runtime_supersession_state(
        stale_run_id="stale-run",
        superseded_by_runtime_version={"execution_backend": "modal", "modal_image": "im-AAA"},
        replacement_run_id="replacement-run",
        auto_requeue_status="queued",
    )

    assert any(update.get("cancel_reason") == "runtime_superseded" for update in updates)
    assert any(update.get("replacement_run_id") == "replacement-run" for update in updates)
```

- [ ] **Step 3: Run the targeted runtime slice to capture current failures**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "semantic_runtime_match or runtime_supersession or duplicate_replacement or supersession_handled"
```

Expected: FAIL until the write-side supersession helper and lock semantics are implemented.

- [ ] **Step 4: Introduce one write-side supersession helper behind the existing route**

```python
def remediate_social_account_catalog_runtime_supersession(
    *,
    platform: str,
    account_handle: str,
    run_id: str,
    initiated_by: str | None = None,
) -> dict[str, Any]:
    with _catalog_run_supersession_lock(run_id):
        run_row = _load_social_account_catalog_run_row(
            platform=platform,
            account_handle=account_handle,
            run_id=run_id,
        )
        run_config = _metadata_dict(run_row.get("config"))
        replacement_run_id = str(run_config.get("replacement_run_id") or "").strip() or None
        if replacement_run_id or bool(run_config.get("supersession_handled")):
            return {
                "run_id": run_id,
                "replacement_run_id": replacement_run_id,
                "created_replacement": False,
                "auto_requeue_status": str(run_config.get("auto_requeue_status") or "").strip().lower() or None,
            }

        current_runtime = _resolve_authoritative_catalog_runtime_version(required_execution_backend="modal")
        _merge_catalog_run_config(
            run_id=run_id,
            metadata_updates={
                "cancel_reason": "runtime_superseded",
                "supersession_handled": True,
                "superseded_by_runtime_version": current_runtime or None,
                "auto_requeue_status": "creating",
            },
        )
        cancel_social_account_catalog_run(
            platform=platform,
            account_handle=account_handle,
            run_id=run_id,
            cancelled_by=initiated_by,
        )
        replacement = start_social_account_catalog_backfill(
            platform=platform,
            account_handle=account_handle,
            source_scope="bravo",
            initiated_by=initiated_by,
            catalog_action="backfill",
            catalog_action_scope="full_history",
        )
        _merge_catalog_run_config(
            run_id=run_id,
            metadata_updates={
                "replacement_run_id": replacement["run_id"],
                "auto_requeue_status": "queued",
            },
        )
        _merge_catalog_run_config(
            run_id=replacement["run_id"],
            metadata_updates={"superseded_run_id": run_id},
        )
        return {
            "run_id": run_id,
            "replacement_run_id": replacement["run_id"],
            "created_replacement": True,
            "auto_requeue_status": "queued",
        }
```

- [ ] **Step 5: Keep the existing route and remediation response shape compatible**

```python
@router.post("/profiles/{platform}/{account_handle}/catalog/remediate-drift")
async def post_social_account_catalog_remediate_drift_route(
    platform: str,
    account_handle: str,
    payload: CatalogRemediateDriftRequest,
    user: InternalAdminUser,
) -> dict[str, Any]:
    from trr_backend.repositories.social_season_analytics import (
        remediate_social_account_catalog_strategy_drift,
    )

    initiated_by = (user or {}).get("email")
    return remediate_social_account_catalog_strategy_drift(
        platform=platform,
        account_handle=account_handle,
        requeue_canary=payload.requeue_canary,
        source_scope=payload.source_scope,
        initiated_by=initiated_by,
        cancelled_by=initiated_by,
    )
```

- [ ] **Step 6: Run the focused repository and route suites**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "runtime_supersession or duplicate_replacement or supersession_handled or runtime_version_drift"
pytest -q tests/api/routers/test_socials_season_analytics.py -k "remediate_drift"
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/api/routers/socials.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  TRR-Backend/tests/api/routers/test_socials_season_analytics.py
git commit -m "feat(runtime): add idempotent instagram catalog supersession"
```

### Task 4: Extend The Admin UI For Superseded Runs

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Extend the frontend run-progress types for superseded-run state**

```ts
export type SocialAccountCatalogRunProgressSnapshot = {
  operational_state?:
    | "blocked_auth"
    | "runtime_superseded"
    | "discovering"
    | "fetching"
    | "recovering"
    | "classifying"
    | "completed"
    | "failed"
    | "cancelled";
  worker_runtime?: {
    runtime_version_drift?: boolean;
    replacement_run_id?: string | null;
    auto_requeue_status?: string | null;
    runtime_superseded?: boolean;
    superseded_by_runtime_version?: Record<string, unknown> | null;
  };
};
```

- [ ] **Step 2: Write the failing runtime tests for auto-pivot and manual fallback visibility**

```tsx
it("auto-pivots from a superseded displayed run to its replacement run", async () => {
  let progressRequestCount = 0;

  mocks.fetchAdminWithAuth.mockImplementation(async (input: RequestInfo | URL) => {
    const url = String(input);
    if (url.includes("/summary")) {
      return jsonResponse({
        ...baseSummary,
        catalog_recent_runs: [
          { run_id: "old-run", status: "cancelled", created_at: "2026-04-20T17:00:00.000Z" },
          { run_id: "new-run", status: "queued", created_at: "2026-04-20T17:05:00.000Z" },
        ],
      });
    }
    if (url.includes("/catalog/runs/old-run/progress")) {
      progressRequestCount += 1;
      return jsonResponse({
        run_id: "old-run",
        run_status: "cancelled",
        operational_state: "runtime_superseded",
        worker_runtime: {
          replacement_run_id: "new-run",
          auto_requeue_status: "queued",
          runtime_superseded: true,
        },
        alerts: [
          {
            code: "runtime_superseded",
            severity: "warning",
            message: "This run was superseded by a replacement run on the current worker runtime.",
            replacement_run_id: "new-run",
            auto_requeue_status: "queued",
          },
        ],
        stages: {},
        per_handle: [],
        recent_log: [],
      });
    }
    if (url.includes("/catalog/runs/new-run/progress")) {
      return jsonResponse({
        run_id: "new-run",
        run_status: "queued",
        operational_state: "discovering",
        alerts: [],
        stages: {},
        per_handle: [],
        recent_log: [],
      });
    }
    if (url.includes("/catalog/posts")) {
      return jsonResponse({ items: [], pagination: { page: 1, page_size: 25, total: 0, total_pages: 1 } });
    }
    if (url.includes("/catalog/review-queue")) {
      return jsonResponse({ items: [] });
    }
    throw new Error(`Unhandled request: ${url}`);
  });

  render(<SocialAccountProfilePage platform="instagram" handle="bravotv" activeTab="catalog" />);

  await waitFor(() => {
    expect(progressRequestCount).toBeGreaterThan(0);
    expect(screen.getByText(/run new-run/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Run the focused app runtime test slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run test:ci -- social-account-profile-page.runtime.test.tsx
```

Expected: FAIL until the superseded-run UI logic is implemented.

- [ ] **Step 4: Add the auto-pivot and button visibility logic to the existing page**

```tsx
useEffect(() => {
  const replacementRunId = String(catalogRunProgress?.worker_runtime?.replacement_run_id || "").trim();
  const autoRequeueStatus = String(catalogRunProgress?.worker_runtime?.auto_requeue_status || "").trim().toLowerCase();
  const isSuperseded = String(catalogRunProgress?.operational_state || "").trim().toLowerCase() === "runtime_superseded";

  if (!isSuperseded) return;
  if (!replacementRunId) return;
  if ((displayedCatalogRunId || "").trim() !== (catalogRunProgress?.run_id || "").trim()) return;
  if (!["queued", "running"].includes(autoRequeueStatus)) return;

  setCatalogProgressRunId(replacementRunId);
}, [catalogRunProgress, displayedCatalogRunId]);

const hideManualRuntimeRemediation =
  Boolean(catalogRunProgress?.worker_runtime?.replacement_run_id) &&
  ["queued", "running"].includes(
    String(catalogRunProgress?.worker_runtime?.auto_requeue_status || "").trim().toLowerCase(),
  );
```

- [ ] **Step 5: Keep the manual remediation button visible when auto-requeue is absent or failed**

```tsx
{alert.code === "no_eligible_worker_for_required_runtime" && !hideManualRuntimeRemediation ? (
  <button
    type="button"
    onClick={() => void runCatalogRemediateDrift({ requeue_canary: true })}
    disabled={runningCatalogAction === "remediate_drift"}
    className="mt-2 inline-flex rounded-lg border border-amber-300 bg-white px-3 py-1.5 text-xs font-semibold text-amber-900 disabled:cursor-not-allowed disabled:opacity-50"
  >
    {runningCatalogAction === "remediate_drift" ? "Cancelling + requeuing…" : "Cancel + Requeue clean run"}
  </button>
) : null}
```

- [ ] **Step 6: Re-run the focused app runtime suite**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run test:ci -- social-account-profile-page.runtime.test.tsx
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-APP/apps/web/src/lib/admin/social-account-profile.ts \
  TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx \
  TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "feat(admin): pivot superseded instagram runs to replacement progress"
```

### Task 5: Document The Operator Contract And Validate Everything

**Files:**
- Modify: `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
- Modify only if wording is stale: `TRR-Backend/docs/ai/local-status/instagram-backfill-speed-recovery.md`

- [ ] **Step 1: Update the runtime-convergence and operator runbook wording**

```md
## Instagram Catalog Runtime States

- `runtime_version_drift`: one run observed more than one semantically distinct runtime.
- `runtime_superseded`: a stale run was cancelled and replaced by a fresh-runtime run; operators should follow the replacement run.
- `no_eligible_worker_for_required_runtime`: no healthy worker currently matches the pinned runtime and automatic replacement has not completed successfully.

Modal-required catalog runs treat missing fresh healthy Modal heartbeat stamps as unknown, not current.
Manual `Cancel + Requeue clean run` remediation is fallback-only when automatic replacement did not finish successfully.
```

- [ ] **Step 2: Run the targeted runtime and UI suites first**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "runtime or start_social_account_catalog_backfill or remediate_social_account_catalog_strategy_drift"
pytest -q tests/api/routers/test_socials_season_analytics.py -k "remediate_drift"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run test:ci -- social-account-profile-page.runtime.test.tsx
```

Expected: PASS.

- [ ] **Step 3: Run the touched-repo validation contract**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
ruff check .
ruff format --check .
pytest -q

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run lint
pnpm -C apps/web exec next build --webpack
pnpm -C apps/web run test:ci
```

Expected: PASS, or unrelated baseline failures documented separately while all targeted runtime suites stay green.

- [ ] **Step 4: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/docs/runbooks/social_worker_queue_ops.md \
  TRR-Backend/docs/ai/local-status/instagram-backfill-speed-recovery.md
git commit -m "docs(instagram): document runtime supersession and admin remediation"
```

---

## Acceptance Criteria

- `Backfill Posts` for Instagram always queues a `full_history` catalog run and does not relaunch `details_refresh`.
- Modal-required catalog logic never infers the current remote runtime from the API host when fresh healthy Modal heartbeats are missing.
- Real Modal dispatcher and worker heartbeats publish `metadata.runtime_version`.
- Equivalent runtime stamps with different labels do not trigger `runtime_version_drift`.
- Runtime supersession is single-fire and idempotent per stale run.
- Concurrent or repeated remediation attempts on the same stale run return the same replacement run instead of creating duplicates.
- The admin UI auto-pivots only from the superseded run to its replacement and keeps manual remediation visible unless automatic replacement clearly succeeded.

## Assumptions

- Scope remains limited to shared-account catalog runs in `SHARED_ACCOUNT_CATALOG_BACKFILL_INGEST_MODE`.
- No schema migration is introduced; supersession linkage remains stored on existing run `config` and surfaced through the existing progress payload.
- Cancellation of already-running work remains checkpoint-based and eventual, not immediate mid-request interruption.
- Planned save path for this plan is `docs/superpowers/plans/2026-04-20-debug-instagram-post-backfill-worker-admin-ui.md`.
