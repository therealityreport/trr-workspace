# Social Profile Dashboard Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a backend-owned social profile dashboard contract that replaces app-side snapshot stitching, formalizes stale freshness, keeps heavy diagnostics out of initial load, and enforces social profile request budgets.

**Architecture:** TRR-APP keeps the existing canonical UI route and `/snapshot` compatibility route, but the route becomes a thin proxy to a new TRR-Backend `/admin/socials/profiles/{platform}/{handle}/dashboard` endpoint. TRR-Backend owns summary composition, active-run progress inclusion, freshness metadata, and operational alerts. Heavy tabs and diagnostics remain separate bounded endpoints and are only requested after the user opens the relevant surface.

**Tech Stack:** FastAPI-style backend router in `TRR-Backend/api/routers/socials.py`, backend social analytics repository in `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, Next.js app route handlers in `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]`, React client page in `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`, TypeScript social profile contracts in `TRR-APP/apps/web/src/types/admin/social-account-profile.ts`.

---

## Scope

This plan covers Strong Agree changes 1-6:

- Backend ownership of social profile dashboard data.
- Replacing app-side snapshot stitching with a backend dashboard endpoint.
- One initial page-load dashboard request.
- Separation of initial page data from diagnostics and heavy tab data.
- Stale data as a first-class payload state.
- Polling and request-budget controls that prevent dogpiling.

This plan deliberately does not add a materialized/read-model table. That belongs in the next phase after the live dashboard contract is stable and measured.

---

## File Map

Create:

- `TRR-Backend/trr_backend/socials/__init__.py`
- `TRR-Backend/trr_backend/socials/profile_dashboard.py`
- `TRR-Backend/tests/socials/test_profile_dashboard.py`
- `TRR-Backend/tests/api/routers/test_social_account_profile_dashboard.py`
- `TRR-APP/apps/web/src/components/admin/__tests__/SocialAccountProfilePage.initial-budget.test.tsx`

Modify:

- `TRR-Backend/api/routers/socials.py`
- `TRR-Backend/trr_backend/middleware/request_timeout.py`
- `TRR-Backend/tests/middleware/test_request_timeout.py`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/__tests__/route.test.ts`
- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/src/types/admin/social-account-profile.ts`
- `TRR-APP/apps/web/src/lib/admin/shared-live-resource.ts`
- `TRR Workspace Brain/api-contract.md`

---

## Step 1: Add Backend Dashboard Service With Failing Unit Tests

- [ ] Add `TRR-Backend/tests/socials/test_profile_dashboard.py` first.

```python
from __future__ import annotations

from datetime import UTC, datetime

import pytest


def test_dashboard_returns_summary_progress_and_freshness(monkeypatch):
    from trr_backend.socials import profile_dashboard

    summary_payload = {
        "platform": "instagram",
        "account_handle": "thetraitorsus",
        "total_posts": 123,
        "catalog_recent_runs": [
            {
                "run_id": "run-active",
                "status": "running",
                "started_at": "2026-04-26T12:00:00Z",
            }
        ],
        "operational_alerts": [{"level": "info", "code": "catalog_running"}],
    }
    progress_payload = {
        "run_id": "run-active",
        "run_status": "running",
        "processed_posts": 40,
        "total_posts": 100,
    }

    def fake_summary(*, platform, account_handle, detail, include_post_embeddings=False):
        assert platform == "instagram"
        assert account_handle == "thetraitorsus"
        assert detail == "lite"
        assert include_post_embeddings is False
        return summary_payload

    def fake_progress(*, run_id, recent_log_limit):
        assert run_id == "run-active"
        assert recent_log_limit == 25
        return progress_payload

    monkeypatch.setattr(profile_dashboard.analytics_repo, "get_social_account_profile_summary", fake_summary)
    monkeypatch.setattr(profile_dashboard.analytics_repo, "get_social_account_catalog_run_progress", fake_progress)
    monkeypatch.setattr(
        profile_dashboard,
        "_utc_now",
        lambda: datetime(2026, 4, 26, 12, 3, tzinfo=UTC),
    )

    dashboard = profile_dashboard.build_social_account_profile_dashboard(
        platform="instagram",
        account_handle="thetraitorsus",
        detail="lite",
        run_id=None,
        recent_log_limit=25,
    )

    assert dashboard["data"]["summary"] == summary_payload
    assert dashboard["data"]["catalog_run_progress"] == progress_payload
    assert dashboard["freshness"]["status"] == "fresh"
    assert dashboard["freshness"]["source"] == "live"
    assert dashboard["freshness"]["generated_at"] == "2026-04-26T12:03:00+00:00"
    assert dashboard["operational_alerts"] == summary_payload["operational_alerts"]


def test_dashboard_does_not_fetch_progress_without_active_run(monkeypatch):
    from trr_backend.socials import profile_dashboard

    def fake_summary(*, platform, account_handle, detail, include_post_embeddings=False):
        return {
            "platform": platform,
            "account_handle": account_handle,
            "catalog_recent_runs": [{"run_id": "run-done", "status": "completed"}],
            "operational_alerts": [],
        }

    def fake_progress(*, run_id, recent_log_limit):
        raise AssertionError("progress should not be fetched for terminal runs")

    monkeypatch.setattr(profile_dashboard.analytics_repo, "get_social_account_profile_summary", fake_summary)
    monkeypatch.setattr(profile_dashboard.analytics_repo, "get_social_account_catalog_run_progress", fake_progress)

    dashboard = profile_dashboard.build_social_account_profile_dashboard(
        platform="instagram",
        account_handle="thetraitorsus",
        detail="lite",
        run_id=None,
        recent_log_limit=25,
    )

    assert dashboard["data"]["catalog_run_progress"] is None
    assert dashboard["freshness"]["status"] == "fresh"


def test_dashboard_marks_backend_errors_without_discarding_shape(monkeypatch):
    from trr_backend.socials import profile_dashboard

    def fake_summary(*, platform, account_handle, detail, include_post_embeddings=False):
        raise RuntimeError("database timeout")

    monkeypatch.setattr(profile_dashboard.analytics_repo, "get_social_account_profile_summary", fake_summary)

    dashboard = profile_dashboard.build_social_account_profile_dashboard(
        platform="instagram",
        account_handle="thetraitorsus",
        detail="lite",
        run_id=None,
        recent_log_limit=25,
    )

    assert dashboard["data"] is None
    assert dashboard["freshness"]["status"] == "error"
    assert dashboard["freshness"]["source"] == "live"
    assert dashboard["operational_alerts"][0]["code"] == "dashboard_unavailable"
```

- [ ] Add `TRR-Backend/trr_backend/socials/__init__.py`.

```python
"""Social account service helpers."""
```

- [ ] Add `TRR-Backend/trr_backend/socials/profile_dashboard.py`.

```python
from __future__ import annotations

from datetime import UTC, datetime
import logging
from time import perf_counter
from typing import Any

from trr_backend.repositories import social_season_analytics as analytics_repo

logger = logging.getLogger(__name__)

ACTIVE_CATALOG_RUN_STATUSES = {"queued", "running", "in_progress", "processing"}


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _active_run_id_from_summary(summary: dict[str, Any]) -> str | None:
    for run in summary.get("catalog_recent_runs") or []:
        status = str(run.get("status") or run.get("run_status") or "").lower()
        run_id = run.get("run_id") or run.get("id")
        if run_id and status in ACTIVE_CATALOG_RUN_STATUSES:
            return str(run_id)
    return None


def _freshness(status: str, *, source: str, generated_at: datetime) -> dict[str, Any]:
    return {
        "status": status,
        "source": source,
        "generated_at": generated_at.isoformat(),
        "age_seconds": 0,
    }


def build_social_account_profile_dashboard(
    *,
    platform: str,
    account_handle: str,
    detail: str,
    run_id: str | None,
    recent_log_limit: int,
) -> dict[str, Any]:
    started = perf_counter()
    generated_at = _utc_now()
    normalized_detail = "lite" if detail not in {"lite", "full"} else detail

    try:
        summary = analytics_repo.get_social_account_profile_summary(
            platform=platform,
            account_handle=account_handle,
            detail=normalized_detail,
            include_post_embeddings=False,
        )
        progress_run_id = run_id or _active_run_id_from_summary(summary)
        catalog_run_progress = None
        if progress_run_id:
            catalog_run_progress = analytics_repo.get_social_account_catalog_run_progress(
                run_id=progress_run_id,
                recent_log_limit=recent_log_limit,
            )

        payload = {
            "data": {
                "summary": summary,
                "catalog_run_progress": catalog_run_progress,
            },
            "freshness": _freshness("fresh", source="live", generated_at=generated_at),
            "operational_alerts": summary.get("operational_alerts") or [],
        }
        logger.info(
            "social_profile_dashboard_loaded",
            extra={
                "platform": platform,
                "handle": account_handle,
                "duration_ms": round((perf_counter() - started) * 1000),
                "freshness_status": payload["freshness"]["status"],
                "has_progress": catalog_run_progress is not None,
            },
        )
        return payload
    except Exception as exc:
        logger.warning(
            "social_profile_dashboard_failed",
            extra={
                "platform": platform,
                "handle": account_handle,
                "duration_ms": round((perf_counter() - started) * 1000),
                "error_code": exc.__class__.__name__,
                "retryable": True,
            },
            exc_info=True,
        )
        return {
            "data": None,
            "freshness": _freshness("error", source="live", generated_at=generated_at),
            "operational_alerts": [
                {
                    "level": "error",
                    "code": "dashboard_unavailable",
                    "message": "Social profile dashboard is temporarily unavailable.",
                    "retryable": True,
                }
            ],
        }
```

- [ ] Run the backend unit test and confirm it fails before implementation, then passes after implementation.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/socials/test_profile_dashboard.py
```

---

## Step 2: Add Backend Dashboard Endpoint

- [ ] Add `TRR-Backend/tests/api/routers/test_social_account_profile_dashboard.py`.

```python
from __future__ import annotations

from fastapi.testclient import TestClient


def test_social_account_profile_dashboard_route_returns_service_payload(monkeypatch, app):
    from api.routers import socials

    captured = {}

    def fake_build_dashboard(**kwargs):
        captured.update(kwargs)
        return {
            "data": {
                "summary": {"platform": "instagram", "account_handle": "thetraitorsus"},
                "catalog_run_progress": None,
            },
            "freshness": {
                "status": "fresh",
                "source": "live",
                "generated_at": "2026-04-26T12:03:00+00:00",
                "age_seconds": 0,
            },
            "operational_alerts": [],
        }

    monkeypatch.setattr(socials, "build_social_account_profile_dashboard", fake_build_dashboard)

    client = TestClient(app)
    response = client.get(
        "/admin/socials/profiles/instagram/thetraitorsus/dashboard?detail=lite&recent_log_limit=12"
    )

    assert response.status_code == 200
    assert response.json()["freshness"]["status"] == "fresh"
    assert captured == {
        "platform": "instagram",
        "account_handle": "thetraitorsus",
        "detail": "lite",
        "run_id": None,
        "recent_log_limit": 12,
    }


def test_social_account_profile_dashboard_route_caps_recent_log_limit(monkeypatch, app):
    from api.routers import socials

    captured = {}

    def fake_build_dashboard(**kwargs):
        captured.update(kwargs)
        return {"data": None, "freshness": {"status": "error"}, "operational_alerts": []}

    monkeypatch.setattr(socials, "build_social_account_profile_dashboard", fake_build_dashboard)

    client = TestClient(app)
    response = client.get(
        "/admin/socials/profiles/instagram/thetraitorsus/dashboard?recent_log_limit=500"
    )

    assert response.status_code == 200
    assert captured["recent_log_limit"] == 100
```

- [ ] Modify `TRR-Backend/api/routers/socials.py` to import the dashboard service near the existing repository imports.

```python
from trr_backend.socials.profile_dashboard import build_social_account_profile_dashboard
```

- [ ] Add the route near the existing `/profiles/{platform}/{account_handle}/summary` route.

```python
@router.get("/profiles/{platform}/{account_handle}/dashboard")
def get_social_account_profile_dashboard_route(
    platform: str,
    account_handle: str,
    detail: str = "lite",
    run_id: str | None = None,
    recent_log_limit: int = 25,
) -> dict[str, Any]:
    bounded_recent_log_limit = max(1, min(recent_log_limit, 100))
    return build_social_account_profile_dashboard(
        platform=platform,
        account_handle=account_handle,
        detail=detail,
        run_id=run_id,
        recent_log_limit=bounded_recent_log_limit,
    )
```

- [ ] Run the targeted route tests.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/api/routers/test_social_account_profile_dashboard.py
```

---

## Step 3: Convert App Snapshot Route Into a Thin Dashboard Proxy

- [ ] Update the app snapshot route test first. In `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/__tests__/route.test.ts`, remove mocks that call the summary route and progress route directly. Mock `fetchSocialBackendJson` and assert the backend dashboard path.

```ts
import { GET } from "../route";
import { fetchSocialBackendJson } from "@/lib/server/trr-api/social-admin-proxy";

jest.mock("@/lib/server/trr-api/social-admin-proxy", () => ({
  fetchSocialBackendJson: jest.fn(),
  socialProxyErrorResponse: jest.fn((error) => Response.json({ error: String(error) }, { status: 502 })),
}));

const mockFetchSocialBackendJson = fetchSocialBackendJson as jest.MockedFunction<typeof fetchSocialBackendJson>;

describe("social profile snapshot route", () => {
  beforeEach(() => {
    mockFetchSocialBackendJson.mockReset();
  });

  it("proxies one backend dashboard request", async () => {
    mockFetchSocialBackendJson.mockResolvedValue({
      data: {
        summary: { platform: "instagram", account_handle: "thetraitorsus" },
        catalog_run_progress: null,
      },
      freshness: {
        status: "fresh",
        source: "live",
        generated_at: "2026-04-26T12:03:00.000Z",
        age_seconds: 0,
      },
      operational_alerts: [],
    });

    const request = new Request(
      "http://localhost/api/admin/trr-api/social/profiles/instagram/thetraitorsus/snapshot?detail=lite"
    );
    const response = await GET(request as never, {
      params: Promise.resolve({ platform: "instagram", handle: "thetraitorsus" }),
    });

    expect(response.status).toBe(200);
    expect(mockFetchSocialBackendJson).toHaveBeenCalledTimes(1);
    expect(mockFetchSocialBackendJson.mock.calls[0][0]).toBe(
      "/profiles/instagram/thetraitorsus/dashboard"
    );
    expect(String(mockFetchSocialBackendJson.mock.calls[0][1]?.queryString)).toContain("detail=lite");
  });
});
```

- [ ] Replace `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts` so it no longer imports or calls `summary/route.ts` or `catalog/runs/[runId]/progress/route.ts`.

```ts
import { NextRequest } from "next/server";

import { getOrCreateAdminSnapshot, buildSnapshotResponse } from "@/lib/server/admin-route-cache";
import { requireAdmin } from "@/lib/server/auth";
import {
  fetchSocialBackendJson,
  socialProxyErrorResponse,
  SOCIAL_PROXY_DEFAULT_TIMEOUT_MS,
} from "@/lib/server/trr-api/social-admin-proxy";

export const dynamic = "force-dynamic";

const LIVE_TTL_MS = 30_000;
const STALE_TTL_MS = 5 * 60_000;

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ platform: string; handle: string }> },
) {
  try {
    await requireAdmin(request);
    const { platform, handle } = await context.params;
    const searchParams = request.nextUrl.searchParams;
    const backendParams = new URLSearchParams();
    backendParams.set("detail", searchParams.get("detail") === "full" ? "full" : "lite");
    const runId = searchParams.get("run_id");
    if (runId) {
      backendParams.set("run_id", runId);
    }
    const recentLogLimit = searchParams.get("recent_log_limit");
    if (recentLogLimit) {
      backendParams.set("recent_log_limit", recentLogLimit);
    }

    const cacheKey = `social-profile-dashboard:${platform}:${handle}:${backendParams.toString()}`;
    const snapshot = await getOrCreateAdminSnapshot({
      key: cacheKey,
      ttlMs: LIVE_TTL_MS,
      staleTtlMs: STALE_TTL_MS,
      fetcher: () =>
        fetchSocialBackendJson(`/profiles/${platform}/${handle}/dashboard`, {
          queryString: backendParams.toString(),
          timeoutMs: SOCIAL_PROXY_DEFAULT_TIMEOUT_MS,
        }),
    });

    return buildSnapshotResponse(snapshot);
  } catch (error) {
    return socialProxyErrorResponse(error, "social-profile-dashboard");
  }
}
```

- [ ] Run the snapshot route test.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm test -- --runInBand "snapshot/__tests__/route.test.ts"
```

---

## Step 4: Enforce the Initial Page-Load Request Budget

- [ ] Add `TRR-APP/apps/web/src/components/admin/__tests__/SocialAccountProfilePage.initial-budget.test.tsx`.

```tsx
import { render, screen, waitFor } from "@testing-library/react";

import { SocialAccountProfilePage } from "../SocialAccountProfilePage";

const fetchMock = jest.fn();

beforeEach(() => {
  fetchMock.mockReset();
  global.fetch = fetchMock as never;
});

it("loads the profile shell with one dashboard snapshot request and no diagnostics", async () => {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const url = String(input);
    if (url.includes("/snapshot")) {
      return Promise.resolve(
        new Response(
          JSON.stringify({
            data: {
              summary: {
                platform: "instagram",
                account_handle: "thetraitorsus",
                profile: { display_name: "The Traitors US" },
                total_posts: 123,
                catalog_recent_runs: [],
                operational_alerts: [],
              },
              catalog_run_progress: null,
            },
            freshness: {
              status: "fresh",
              source: "live",
              generated_at: "2026-04-26T12:03:00.000Z",
              age_seconds: 0,
            },
            operational_alerts: [],
          }),
          { status: 200 },
        ),
      );
    }
    return Promise.reject(new Error(`unexpected fetch ${url}`));
  });

  render(<SocialAccountProfilePage platform="instagram" handle="thetraitorsus" />);

  await screen.findByText(/The Traitors US/i);

  await waitFor(() => {
    const urls = fetchMock.mock.calls.map(([input]) => String(input));
    expect(urls.filter((url) => url.includes("/snapshot"))).toHaveLength(1);
    expect(urls.some((url) => url.includes("/summary"))).toBe(false);
    expect(urls.some((url) => url.includes("/gap-analysis"))).toBe(false);
    expect(urls.some((url) => url.includes("/posts"))).toBe(false);
    expect(urls.some((url) => url.includes("/comments"))).toBe(false);
    expect(urls.some((url) => url.includes("/hashtags"))).toBe(false);
  });
});
```

- [ ] Update `SocialAccountProfilePage.tsx` so the mount path calls `fetchProfileSnapshot` once and treats the dashboard payload as the source of summary and active progress.

Implementation notes:

- Keep lazy effects for posts, catalog posts, hashtags, timeline, review queue, collaborators, comments, gap analysis, cookies health, and SocialBlade behind their current selected-tab or user-action checks.
- Remove initial render calls to `refreshSummary` when a dashboard snapshot has already loaded a summary.
- Remove direct initial render calls to `fetchCatalogRunProgressSnapshot`; progress should enter through dashboard snapshot unless the shared live poller is active for a running catalog job.
- Keep compatibility with manual refresh buttons by allowing `refreshSummary` and direct progress fetches after explicit user action.

- [ ] Run the new test.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm test -- --runInBand "SocialAccountProfilePage.initial-budget.test.tsx"
```

---

## Step 5: Add Freshness and Degraded-State Types to the App Contract

- [ ] Modify `TRR-APP/apps/web/src/types/admin/social-account-profile.ts`.

```ts
export type SocialAccountDashboardFreshnessStatus = "fresh" | "stale" | "missing" | "error";
export type SocialAccountDashboardFreshnessSource = "live" | "cache" | "materialized";

export interface SocialAccountDashboardFreshness {
  status: SocialAccountDashboardFreshnessStatus;
  generated_at: string | null;
  age_seconds: number | null;
  source: SocialAccountDashboardFreshnessSource;
}

export interface SocialAccountDashboardPayload {
  data: {
    summary: SocialAccountProfileSummary;
    catalog_run_progress: SocialAccountCatalogRunProgress | null;
  } | null;
  freshness: SocialAccountDashboardFreshness;
  operational_alerts: SocialAccountOperationalAlert[];
}
```

- [ ] Update the snapshot fetch parser in `SocialAccountProfilePage.tsx` to consume `SocialAccountDashboardPayload`.

```ts
function isDashboardPayload(value: unknown): value is SocialAccountDashboardPayload {
  if (!value || typeof value !== "object") {
    return false;
  }
  const candidate = value as Partial<SocialAccountDashboardPayload>;
  return Boolean(candidate.freshness && typeof candidate.freshness.status === "string");
}
```

- [ ] Add a single degraded-state banner location near the profile shell status area. The banner should render for `stale`, `missing`, and `error`, while still rendering any available `data.summary`.

```tsx
{dashboardFreshness?.status === "stale" ? (
  <StatusCallout tone="warning">
    Showing cached data from {formatRelativeAge(dashboardFreshness.age_seconds)}.
  </StatusCallout>
) : null}
{dashboardFreshness?.status === "error" && summary ? (
  <StatusCallout tone="warning">
    Backend dashboard refresh failed. Showing the last successful profile data.
  </StatusCallout>
) : null}
{dashboardFreshness?.status === "missing" ? (
  <StatusCallout tone="neutral">
    No profile dashboard snapshot has been generated yet.
  </StatusCallout>
) : null}
```

- [ ] Add or reuse a small formatter that accepts `number | null` and returns `"moments ago"` when age is unavailable.

```ts
function formatRelativeAge(ageSeconds: number | null): string {
  if (ageSeconds == null || Number.isNaN(ageSeconds)) {
    return "moments ago";
  }
  if (ageSeconds < 60) {
    return `${Math.max(0, Math.round(ageSeconds))} seconds ago`;
  }
  const minutes = Math.round(ageSeconds / 60);
  return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
}
```

---

## Step 6: Stop Polling When It Cannot Improve the Page

- [ ] In `SocialAccountProfilePage.tsx`, make the catalog progress shared poller depend on all of these conditions:

```ts
const shouldPollCatalogProgress =
  Boolean(backgroundCatalogRunId) &&
  supportsCatalog &&
  isActiveCatalogRunStatus(catalogRunProgress?.run_status ?? activeCatalogRun?.status ?? null) &&
  selectedTab === "catalog" &&
  documentVisibilityState === "visible";
```

- [ ] Pass `shouldPollCatalogProgress` into `useSharedPollingResource`.

```ts
const catalogProgressResource = useSharedPollingResource({
  key: catalogProgressPollingKey,
  intervalMs: CATALOG_PROGRESS_POLL_INTERVAL_MS,
  shouldRun: shouldPollCatalogProgress,
  fetcher: fetchCatalogRunProgressSnapshot,
});
```

- [ ] Ensure gap analysis polling already requires catalog tab visibility. If any effect still starts gap analysis on initial mount, move it behind `selectedTab === "catalog"` and a user-opened diagnostics panel state.

```ts
const shouldPollGapAnalysis =
  selectedTab === "catalog" &&
  diagnosticsPanelOpen &&
  documentVisibilityState === "visible" &&
  Boolean(activeGapAnalysisRunId);
```

- [ ] Update `TRR-APP/apps/web/src/lib/admin/shared-live-resource.ts` tests or add a focused test that proves hidden tabs stop the leader poll tick. Use existing visibility helper conventions in that file.

---

## Step 7: Backend Timeouts, Bounds, and Observability Guardrails

- [ ] Remove social profile read-route exemptions from `TRR-Backend/trr_backend/middleware/request_timeout.py` for:

```python
"/admin/socials/profiles/.*/posts",
"/admin/socials/profiles/.*/summary",
"/admin/socials/profiles/.*/catalog/runs/.*/progress",
```

Keep long-running action exemptions only for action routes that return or manage jobs, such as catalog backfill, comments scrape, and SocialBlade refresh.

- [ ] Update `TRR-Backend/tests/middleware/test_request_timeout.py` so social read routes are covered by the timeout middleware.

```python
def test_social_profile_summary_is_not_timeout_exempt():
    assert not is_timeout_exempt("/admin/socials/profiles/instagram/thetraitorsus/summary")


def test_social_profile_posts_is_not_timeout_exempt():
    assert not is_timeout_exempt("/admin/socials/profiles/instagram/thetraitorsus/posts")


def test_social_profile_progress_is_not_timeout_exempt():
    assert not is_timeout_exempt(
        "/admin/socials/profiles/instagram/thetraitorsus/catalog/runs/run-123/progress"
    )
```

- [ ] Verify existing backend repository caps stay in place:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
rg -n "_SOCIAL_ACCOUNT_PROFILE_MAX_PAGE_SIZE|recent_log_limit|LIMIT %s|LIMIT \\$" trr_backend/repositories/social_season_analytics.py
```

- [ ] Add structured route-level logging to the new dashboard service from Step 1. Confirm logs include:

```text
route name
platform
handle
duration_ms
freshness_status
has_progress
error_code
retryable
```

- [ ] Run backend timeout tests.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/middleware/test_request_timeout.py
```

---

## Step 8: Contract Documentation and Cross-Repo Verification

- [ ] Update `TRR Workspace Brain/api-contract.md` with the new dashboard endpoint.

````md
## Social Profile Dashboard Contract

`GET /admin/socials/profiles/{platform}/{handle}/dashboard`

TRR-BACKEND owns dashboard composition for the social profile page. TRR-APP may proxy this endpoint through its existing `/snapshot` route for compatibility, but TRR-APP must not compose the initial dashboard from separate summary, progress, diagnostics, posts, comments, hashtags, or SocialBlade reads.

Response shape:

```json
{
  "data": {
    "summary": {},
    "catalog_run_progress": null
  },
  "freshness": {
    "status": "fresh",
    "generated_at": "2026-04-26T12:03:00Z",
    "age_seconds": 0,
    "source": "live"
  },
  "operational_alerts": []
}
```

Initial page-load budget:

- One dashboard snapshot request.
- No gap analysis.
- No comments load.
- No full posts load.
- No hashtag timeline load.
- Progress is included only when an active run exists.
````

- [ ] Run all targeted checks.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/socials/test_profile_dashboard.py tests/api/routers/test_social_account_profile_dashboard.py tests/middleware/test_request_timeout.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm test -- --runInBand "snapshot/__tests__/route.test.ts" "SocialAccountProfilePage.initial-budget.test.tsx"
pnpm lint
```

- [ ] Start the local stack if it is not already running.

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

- [ ] Open `http://admin.localhost:3000/social/instagram/thetraitorsus` and verify browser network behavior:

```text
Initial render issues exactly one /snapshot request.
Initial render issues zero /summary requests.
Initial render issues zero /posts requests.
Initial render issues zero /comments requests.
Initial render issues zero /hashtags requests.
Initial render issues zero /gap-analysis requests.
Catalog progress polling starts only after opening the catalog diagnostics surface for an active run.
Polling stops when the tab is hidden.
Stale or error freshness still renders the last available summary.
```

---

## Implementation Notes

- Keep `/snapshot` as an app compatibility route. Replace its internals; do not remove it.
- Keep canonical UI routing under `/social/[platform]/[handle]`.
- Keep backend changes first, then app follow-through in the same session.
- Avoid adding a read-model table in this phase. The dashboard endpoint should make the later materialized table a private backend implementation detail.
- Treat stale dashboard data as usable UI data. Only a missing `data.summary` should block profile stats rendering.
- Do not move SocialBlade landing analytics in this phase; that is a separate backend-ownership cleanup.

---

## Completion Criteria

- Backend exposes `/admin/socials/profiles/{platform}/{handle}/dashboard`.
- App `/snapshot` route calls exactly one backend dashboard endpoint.
- Initial social profile page render performs one dashboard snapshot request and no diagnostics/detail requests.
- Stale/error freshness states render consistently and do not erase existing summary UI.
- Polling is active only when it can update a visible, relevant panel.
- Social profile read routes are covered by timeout middleware.
- Targeted backend tests, app route tests, initial-budget test, and app lint pass.
