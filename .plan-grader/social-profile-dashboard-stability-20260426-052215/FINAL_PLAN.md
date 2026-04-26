# Social Profile Dashboard Stability Final Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`. The main session must orchestrate subagents in the current repo checkout only. Track every task with checkbox syntax.

## Goal

Make the social account profile initial render resilient by replacing app-side summary/progress stitching with one backend-owned dashboard payload, while preserving the existing app `/snapshot` compatibility route and its stale-if-error behavior.

## Non-Goals

- Do not add a production materialized/read-model table in this pass.
- Do not move SocialBlade landing-page direct DB reads in this pass.
- Do not remove `/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot`.
- Do not rewrite `SocialAccountProfilePage.tsx` into multiple components in this pass.

## Current Repo Corrections

- App social profile types live at `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`.
- App tests must be placed under `TRR-APP/apps/web/tests/` because `vitest.config.ts` includes only `tests/**/*.test.ts` and `tests/**/*.test.tsx`.
- `SocialAccountProfilePage` is a default export.
- The snapshot route must use existing modules:
  - `@/lib/server/admin/admin-snapshot-cache`
  - `@/lib/server/admin/admin-snapshot-route`
- Backend app route tests should use `/api/v1/admin/socials/...` when they go through `api.main.app`.
- `get_social_account_catalog_run_progress` requires `platform`, `account_handle`, and `run_id`.
- Dashboard service errors must propagate to the app proxy/cache layer so stale last-good snapshots remain usable.

## Implementation Mode

- Use the current branch and current worktree only.
- Do not create or switch branches.
- Do not create git worktrees.
- Do not run `git branch`, `git checkout -b`, `git switch -c`, `git worktree add`, or equivalent branch/worktree setup commands.
- The main session is the orchestrator. It assigns bounded, disjoint file scopes to subagents and integrates their results into the current checkout.
- Subagents help implement the plan; they do not own separate branch strategy, merge strategy, or release strategy.
- If a subagent environment is internally isolated by the agent platform, the subagent must report changed paths and implementation details back to the main session for integration into this current worktree.

## Subagent Split

- Subagent A owns backend files:
  - `TRR-Backend/trr_backend/socials/__init__.py`
  - `TRR-Backend/trr_backend/socials/profile_dashboard.py`
  - `TRR-Backend/trr_backend/socials/profile_dashboard_schema.py`
  - `TRR-Backend/api/routers/socials.py`
  - `TRR-Backend/trr_backend/middleware/request_timeout.py`
  - backend tests
- Subagent B owns app proxy/types/tests:
  - snapshot route
  - `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
  - app fixtures and app route tests
- Subagent C owns React page behavior and polling:
  - `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
  - runtime page tests
  - `TRR-APP/apps/web/src/lib/admin/shared-live-resource.ts` only if a missing test hook is needed
- Subagent D owns docs and operator artifacts:
  - `TRR Workspace Brain/api-contract.md`
  - `docs/workspace/social-profile-dashboard.md`
  - `docs/workspace/dev-commands.md`
  - optional query-plan helper script

Subagents are not alone in the codebase. Do not revert unrelated edits, and coordinate through the file ownership above.

## Phase 1: Backend Dashboard Contract

- [ ] Add `TRR-Backend/trr_backend/socials/__init__.py`.

```python
"""Social account dashboard service helpers."""
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

ACTIVE_CATALOG_RUN_STATUSES = {
    "queued",
    "pending",
    "running",
    "retrying",
    "cancelling",
    "attached",
    "in_progress",
    "processing",
}


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _active_run_id_from_summary(summary: dict[str, Any]) -> str | None:
    for run in summary.get("catalog_recent_runs") or []:
        status = str(run.get("status") or run.get("run_status") or "").strip().lower()
        run_id = run.get("run_id") or run.get("id")
        if run_id and status in ACTIVE_CATALOG_RUN_STATUSES:
            return str(run_id)
    return None


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
    normalized_detail = "full" if detail == "full" else "lite"
    summary = analytics_repo.get_social_account_profile_summary(
        platform=platform,
        account_handle=account_handle,
        detail=normalized_detail,
        include_post_embeddings=False,
    )
    progress_run_id = run_id or _active_run_id_from_summary(summary)
    progress = None
    if progress_run_id:
        progress = analytics_repo.get_social_account_catalog_run_progress(
            platform,
            account_handle,
            progress_run_id,
            recent_log_limit=recent_log_limit,
        )

    payload = {
        "data": {
            "summary": summary,
            "catalog_run_progress": progress,
        },
        "freshness": {
            "status": "fresh",
            "source": "live",
            "generated_at": generated_at.isoformat(),
            "age_seconds": 0,
        },
        "operational_alerts": summary.get("operational_alerts") or [],
    }
    logger.info(
        "social_profile_dashboard_loaded",
        extra={
            "route": "social_profile_dashboard",
            "platform": platform,
            "handle": account_handle,
            "duration_ms": round((perf_counter() - started) * 1000),
            "freshness_status": "fresh",
            "has_progress": progress is not None,
        },
    )
    return payload
```

- [ ] Add backend unit tests in `TRR-Backend/tests/socials/test_profile_dashboard.py`.

Required assertions:

- active `catalog_recent_runs` status fetches progress;
- terminal status does not fetch progress;
- explicit `run_id` overrides inferred active run;
- progress call receives `platform`, `account_handle`, `run_id`, and bounded `recent_log_limit`;
- summary exceptions are not swallowed.

- [ ] Add backend route tests in `TRR-Backend/tests/api/routers/test_social_account_profile_dashboard.py`.

Use the existing `api.main.app` and JWT helper pattern from `tests/api/routers/test_social_account_profile_hashtag_timeline.py`. Requests should hit:

```text
/api/v1/admin/socials/profiles/instagram/thetraitorsus/dashboard?detail=lite&recent_log_limit=12
```

Required assertions:

- status 200 with dashboard payload;
- service receives `detail="lite"`;
- `recent_log_limit=500` is capped to 100;
- invalid non-integer `recent_log_limit` returns FastAPI validation error rather than silently using an unsafe value.

- [ ] Add the route in `TRR-Backend/api/routers/socials.py` near the existing summary route.

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

## Phase 2: App Snapshot Route Compatibility Proxy

- [ ] Add `TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts`.

Use Vitest syntax (`vi`, not `jest`) and mock:

- `@/lib/server/auth`
- `@/lib/server/trr-api/social-admin-proxy`

Required assertions:

- one call to `fetchSocialBackendJson`;
- backend path is `/profiles/instagram/thetraitorsus/dashboard`;
- query string carries `detail`, `run_id`, and `recent_log_limit`;
- `refresh=1` is used only for the snapshot cache and is not forwarded to the backend;
- stale fallback response maps to `dashboard_freshness.status === "stale"` and `dashboard_freshness.source === "cache"`.

- [ ] Replace the internals of `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`.

Preserve current imports from:

```ts
import { requireAdmin, toVerifiedAdminContext } from "@/lib/server/auth";
import {
  buildAdminAuthPartition,
  buildAdminSnapshotCacheKey,
  getOrCreateAdminSnapshot,
} from "@/lib/server/admin/admin-snapshot-cache";
import { buildSnapshotResponse } from "@/lib/server/admin/admin-snapshot-route";
```

Add a local normalizer so the compatibility route still returns the page's current snapshot shape:

```ts
type BackendDashboardPayload = {
  data?: {
    summary?: Record<string, unknown> | null;
    catalog_run_progress?: Record<string, unknown> | null;
  } | null;
  freshness?: Record<string, unknown> | null;
  operational_alerts?: unknown[];
};

const normalizeDashboardSnapshot = (dashboard: BackendDashboardPayload) => ({
  summary: dashboard.data?.summary ?? null,
  catalog_run_progress: dashboard.data?.catalog_run_progress ?? null,
  dashboard_freshness: dashboard.freshness ?? null,
  operational_alerts: Array.isArray(dashboard.operational_alerts) ? dashboard.operational_alerts : [],
});
```

After `getOrCreateAdminSnapshot`, derive the final first-class freshness from snapshot metadata before calling `buildSnapshotResponse`:

```ts
const responseData = {
  ...snapshot.data,
  dashboard_freshness: {
    ...(snapshot.data.dashboard_freshness && typeof snapshot.data.dashboard_freshness === "object"
      ? snapshot.data.dashboard_freshness
      : {}),
    status: snapshot.meta.stale ? "stale" : "fresh",
    source: snapshot.meta.stale ? "cache" : "live",
    generated_at: snapshot.meta.generatedAt,
    age_seconds: Math.round(snapshot.meta.cacheAgeMs / 1000),
  },
};
```

The route must still use:

```ts
fetchSocialBackendJson(`/profiles/${encodeURIComponent(platform)}/${encodeURIComponent(handle)}/dashboard`, {
  adminContext,
  fallbackError: "Failed to fetch social account profile dashboard",
  queryString: backendParams.toString(),
  retries: 0,
  timeoutMs: SOCIAL_PROXY_DEFAULT_TIMEOUT_MS,
})
```

## Phase 3: App Types and Page Initial Budget

- [ ] Update `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`.

Add:

```ts
export type SocialAccountDashboardFreshnessStatus = "fresh" | "stale" | "missing" | "error";
export type SocialAccountDashboardFreshnessSource = "live" | "cache" | "materialized";

export type SocialAccountDashboardFreshness = {
  status: SocialAccountDashboardFreshnessStatus;
  generated_at: string | null;
  age_seconds: number | null;
  source: SocialAccountDashboardFreshnessSource;
};
```

Extend `SocialAccountProfileSnapshot` with:

```ts
dashboard_freshness?: SocialAccountDashboardFreshness | null;
operational_alerts?: SocialAccountOperationalAlert[];
```

- [ ] Update `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`.

Required behavior:

- keep using the existing default export;
- parse `payload.dashboard_freshness`;
- store dashboard freshness in component state;
- render stale/error/missing copy using existing card/callout styling already used for operational alerts;
- render `summary` when present even if dashboard freshness is stale or error;
- do not call `refreshSummary()` on initial mount after a dashboard snapshot summary succeeds;
- keep manual refresh actions able to call summary directly after user action;
- keep terminal-run hydration for completed catalog jobs, but do not start direct progress polling on initial load unless an active run exists.

- [ ] Add or modify `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`.

Required tests:

- initial render calls only one `/snapshot` request and no `/summary`, `/posts`, `/comments`, `/hashtags`, or `/gap-analysis` requests;
- a stale dashboard snapshot still renders the profile summary;
- an error freshness state with a cached summary shows degraded copy but not the generic failed-summary page.

## Phase 4: Polling Budget

- [ ] Update the `useSharedPollingResource` call in `SocialAccountProfilePage.tsx`.

Use a local `shouldRunLiveProfileSnapshot` boolean:

```ts
const shouldRunLiveProfileSnapshot =
  !checking &&
  Boolean(user) &&
  hasAccess &&
  supportsCatalog &&
  Boolean(backgroundCatalogRunId) &&
  isActiveCatalogRunStatus(catalogRunProgress?.run_status ?? activeCatalogRun?.status ?? null) &&
  selectedTab === "catalog";
```

Pass it to:

```ts
useSharedPollingResource({
  key: `social-account-profile-snapshot:${platform}:${handle}:${backgroundCatalogRunId ?? "none"}:${catalogProgressRequestNonce}`,
  shouldRun: shouldRunLiveProfileSnapshot,
  intervalMs: CATALOG_PROGRESS_POLL_INTERVAL_MS,
  fetchData: ...
});
```

Rely on `shared-live-resource.ts` for hidden-tab shutdown because it already checks `document.visibilityState`.

- [ ] Ensure gap analysis polling starts only when:

```ts
selectedTab === "catalog" && diagnosticsPanelOpen && Boolean(activeGapAnalysisRunId)
```

If the diagnostics panel state does not exist, add the smallest state needed to distinguish "catalog tab opened" from "diagnostics requested".

## Phase 5: Timeout and Bounds Guardrails

- [ ] Remove generic timeout exemptions for social profile read routes in `TRR-Backend/trr_backend/middleware/request_timeout.py`:

```python
re.compile(r"^/api/v1/admin/socials/profiles/[^/]+/[^/]+/posts$"),
re.compile(r"^/api/v1/admin/socials/profiles/[^/]+/[^/]+/summary$"),
re.compile(r"^/api/v1/admin/socials/profiles/[^/]+/[^/]+/catalog/runs/[^/]+/progress$"),
```

Keep action-route exemptions for backfill, comments scrape, and SocialBlade refresh.

- [ ] Update `TRR-Backend/tests/middleware/test_request_timeout.py`.

Replace the existing posts exemption test with a timeout test for a social profile read path. Also add direct `_is_exempt` assertions for summary, posts, progress, and dashboard.

## Phase 6: Contract Documentation

- [ ] Update `TRR Workspace Brain/api-contract.md` with:

```md
## Social Profile Dashboard Contract

Backend route: `GET /api/v1/admin/socials/profiles/{platform}/{handle}/dashboard`

App compatibility route: `GET /api/admin/trr-api/social/profiles/{platform}/{handle}/snapshot`

The backend owns dashboard composition. The app compatibility route proxies the backend dashboard endpoint and normalizes it into the existing snapshot envelope consumed by `SocialAccountProfilePage`.

Initial page-load budget:

- One `/snapshot` request.
- No `/summary` request after a successful dashboard summary.
- No posts, comments, hashtags, SocialBlade, gap-analysis, or freshness diagnostics until the user opens the relevant tab or panel.

Stale behavior:

- Backend read failures must throw through the app snapshot fetcher.
- The app snapshot cache may serve last-good data inside the stale-if-error window.
- The UI treats stale data as degraded but usable.
```

## Phase 7: ADDITIONAL SUGGESTIONS

- [ ] Suggestion 1: Add a dashboard payload fixture.

Create `TRR-APP/apps/web/tests/fixtures/social-account-dashboard.ts`.

The fixture should export:

```ts
import type { SocialAccountProfileSummary } from "@/lib/admin/social-account-profile";

export const makeSocialAccountSummary = (
  overrides: Partial<SocialAccountProfileSummary> = {},
): SocialAccountProfileSummary => ({
  summary_detail: "lite",
  platform: "instagram",
  account_handle: "thetraitorsus",
  display_name: "The Traitors US",
  profile_url: "https://www.instagram.com/thetraitorsus/",
  total_posts: 123,
  total_engagement: 4567,
  total_views: 8901,
  catalog_recent_runs: [],
  per_show_counts: [],
  per_season_counts: [],
  top_hashtags: [],
  top_collaborators: [],
  top_tags: [],
  source_status: [],
  ...overrides,
});

export const makeSocialAccountDashboardPayload = (
  overrides: Record<string, unknown> = {},
) => ({
  data: {
    summary: makeSocialAccountSummary(),
    catalog_run_progress: null,
  },
  freshness: {
    status: "fresh",
    source: "live",
    generated_at: "2026-04-26T12:03:00.000Z",
    age_seconds: 0,
  },
  operational_alerts: [],
  ...overrides,
});
```

Then update:

- `TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

Required verification:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm test -- --runInBand tests/social-account-profile-snapshot-route.test.ts tests/social-account-profile-page.runtime.test.tsx
```

- [ ] Suggestion 2: Add a backend dashboard schema model.

Create `TRR-Backend/trr_backend/socials/profile_dashboard_schema.py`.

Use Pydantic models that validate the stable dashboard envelope while allowing existing summary/progress payloads to evolve:

```python
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class SocialAccountDashboardFreshness(BaseModel):
    status: Literal["fresh", "stale", "missing", "error"]
    source: Literal["live", "cache", "materialized"]
    generated_at: str | None = None
    age_seconds: int | None = Field(default=None, ge=0)


class SocialAccountDashboardData(BaseModel):
    model_config = ConfigDict(extra="allow")

    summary: dict[str, Any]
    catalog_run_progress: dict[str, Any] | None = None


class SocialAccountDashboardPayload(BaseModel):
    model_config = ConfigDict(extra="allow")

    data: SocialAccountDashboardData
    freshness: SocialAccountDashboardFreshness
    operational_alerts: list[dict[str, Any]] = Field(default_factory=list)
```

Then update `TRR-Backend/api/routers/socials.py`:

```python
from trr_backend.socials.profile_dashboard_schema import SocialAccountDashboardPayload


@router.get(
    "/profiles/{platform}/{account_handle}/dashboard",
    response_model=SocialAccountDashboardPayload,
)
def get_social_account_profile_dashboard_route(...):
    ...
```

Required tests:

- route returns the same JSON shape;
- `app.openapi()` includes the dashboard response schema;
- invalid route-service output fails loudly in the backend test instead of drifting silently.

- [ ] Suggestion 3: Emit `x-trr-dashboard-freshness`.

Update `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`.

After `buildSnapshotResponse`, set headers from normalized dashboard freshness:

```ts
const response = buildSnapshotResponse({
  data: responseData,
  cacheStatus: snapshot.meta.cacheStatus,
  generatedAt: snapshot.meta.generatedAt,
  cacheAgeMs: snapshot.meta.cacheAgeMs,
  stale: snapshot.meta.stale,
});

response.headers.set("x-trr-dashboard-freshness", String(responseData.dashboard_freshness.status));
response.headers.set("x-trr-dashboard-source", String(responseData.dashboard_freshness.source));
return response;
```

Update `TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts`.

Required assertions:

- fresh response has `x-trr-dashboard-freshness: fresh`;
- stale cache fallback has `x-trr-dashboard-freshness: stale`;
- source header is `live` or `cache`.

- [ ] Suggestion 4: Add a one-page operator runbook.

Create `docs/workspace/social-profile-dashboard.md`.

The runbook must include:

- dashboard route and app compatibility route;
- meaning of `fresh`, `stale`, `missing`, and `error`;
- what admins should expect when stale data is shown;
- when diagnostics should be opened;
- which requests are allowed on initial render;
- how to verify the page is not dogpiling backend reads;
- rollback note pointing to the app snapshot route.

Add a link to this runbook in `docs/workspace/dev-commands.md` near existing local admin or social debugging commands.

Required verification:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "social-profile-dashboard|Social Profile Dashboard|x-trr-dashboard-freshness" docs/workspace "TRR Workspace Brain/api-contract.md"
```

- [ ] Suggestion 5: Add request-count telemetry.

Update the app snapshot route to emit structured log data for the initial dashboard proxy call. Keep the telemetry local to the route so it does not overcount lazy tab requests.

Add a small helper in the snapshot route:

```ts
const logSocialProfileDashboardBudget = (input: {
  platform: string;
  handle: string;
  cacheStatus: string;
  freshnessStatus: string;
  initialRequestCount: number;
}) => {
  console.info("social_profile_dashboard_budget", input);
};
```

Call it once after the dashboard snapshot response is built:

```ts
logSocialProfileDashboardBudget({
  platform,
  handle,
  cacheStatus: snapshot.meta.cacheStatus,
  freshnessStatus: String(responseData.dashboard_freshness.status),
  initialRequestCount: 1,
});
```

Update the snapshot route test to spy on `console.info` and assert:

- exactly one `social_profile_dashboard_budget` log per route call;
- `initialRequestCount` equals `1`;
- cache status and freshness status are included.

- [ ] Suggestion 6: Add a live EXPLAIN capture script for later index work.

Create `TRR-Backend/scripts/db/social_profile_dashboard_explain.py`.

The script should:

- accept `--platform`, `--handle`, and optional `--run-id`;
- connect through existing backend DB helpers or environment-backed database URL patterns already used by scripts;
- run `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` for the exact summary/detail queries that power dashboard, posts, comments, hashtags, and catalog progress reads where practical;
- write JSON output to `TRR-Backend/tmp/social-profile-dashboard-explain/<platform>-<handle>-<timestamp>.json`;
- exit nonzero if an inspected plan contains an obvious sequential scan on a large social table.

If a direct query helper cannot be reused safely, create the script with a dry-run SQL rendering mode first:

```bash
python scripts/db/social_profile_dashboard_explain.py --platform instagram --handle thetraitorsus --dry-run
```

Document in the script header that index migrations are intentionally not part of this phase; this script prepares the next query-plan-backed indexing phase.

- [ ] Suggestion 7: Add a dashboard endpoint smoke command.

Update `docs/workspace/dev-commands.md` with a backend smoke command that hits the dashboard endpoint.

Use the existing local auth pattern from the workspace docs if one is already documented. If no token command exists in that file, add a placeholder-free command that assumes `TRR_ADMIN_BEARER_TOKEN` is set:

```bash
curl -sS \
  -H "Authorization: Bearer ${TRR_ADMIN_BEARER_TOKEN}" \
  "http://localhost:8000/api/v1/admin/socials/profiles/instagram/thetraitorsus/dashboard?detail=lite" \
  | jq '{freshness, has_summary: (.data.summary != null), has_progress: (.data.catalog_run_progress != null)}'
```

Required verification:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "dashboard\\?detail=lite|TRR_ADMIN_BEARER_TOKEN|has_summary" docs/workspace/dev-commands.md
```

- [ ] Suggestion 8: Track stale-cache hit rate.

Extend the app snapshot route telemetry from Suggestion 5.

Add fields:

```ts
stale: snapshot.meta.stale,
cacheAgeMs: snapshot.meta.cacheAgeMs,
staleCacheHit: snapshot.meta.stale && snapshot.meta.cacheStatus === "hit",
```

Update the route test to simulate a stale fallback and assert:

- `staleCacheHit` is `true`;
- `cacheAgeMs` is present;
- freshness source is `cache`.

If a metrics helper already exists for admin read proxy observability, record a counter there instead of only logging. If not, keep the log-only implementation and document it in the runbook.

- [ ] Suggestion 9: Add a hidden-tab polling regression test.

Add or update an app test for `TRR-APP/apps/web/src/lib/admin/shared-live-resource.ts`.

If no shared-resource test exists, create `TRR-APP/apps/web/tests/shared-live-resource-polling.test.tsx`.

Required behavior:

- install fake timers with Vitest;
- render a tiny test component that calls `useSharedPollingResource`;
- assert the fetcher runs while `document.visibilityState` is `visible`;
- override `document.visibilityState` to `hidden` and dispatch `visibilitychange`;
- advance timers and assert no new fetch occurs while hidden;
- restore visibility and assert polling resumes only when `shouldRun` is true.

Required verification:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm test -- --runInBand tests/shared-live-resource-polling.test.tsx
```

- [ ] Suggestion 10: Add a dashboard read-model decision stub.

Update `TRR Workspace Brain/api-contract.md`.

Add a short decision stub under the dashboard contract:

```md
### Future Read-Model Decision Stub

This phase keeps dashboard data live behind a backend-owned contract. A later phase may back the same contract with a materialized `social_profile_summaries` table or equivalent read model after dashboard shape, freshness states, and initial request budget are verified in the app.

The read-model phase should begin with live query-plan evidence from `TRR-Backend/scripts/db/social_profile_dashboard_explain.py`, not index guesses.
```

Required verification:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "Future Read-Model Decision Stub|social_profile_summaries|social_profile_dashboard_explain" "TRR Workspace Brain/api-contract.md"
```

## Verification

Backend:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/socials/test_profile_dashboard.py tests/api/routers/test_social_account_profile_dashboard.py tests/middleware/test_request_timeout.py
```

App:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm test -- --runInBand tests/social-account-profile-snapshot-route.test.ts tests/social-account-profile-page.runtime.test.tsx tests/shared-live-resource-polling.test.tsx
pnpm typecheck
pnpm lint
```

Docs and suggestions:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "Social Profile Dashboard|x-trr-dashboard-freshness|dashboard\\?detail=lite|Future Read-Model Decision Stub" docs/workspace "TRR Workspace Brain/api-contract.md"
```

Browser:

```text
Open http://admin.localhost:3000/social/instagram/thetraitorsus.
Verify initial network traffic has exactly one /snapshot request and zero initial /summary, /posts, /comments, /hashtags, /gap-analysis requests.
Verify the /snapshot response includes x-trr-dashboard-freshness and x-trr-dashboard-source headers.
Verify a stale snapshot renders summary data plus degraded copy.
Verify catalog progress polling starts only from a visible catalog diagnostics surface for an active run.
Verify hidden-tab polling pauses and resumes when visible.
```

## Rollback

- Revert the app snapshot route to the previous summary-plus-progress stitching if the dashboard endpoint causes production breakage.
- Keep backend dashboard route in place during rollback if it is unused; it is additive.
- Restore removed timeout exemptions only if targeted tests prove a bounded read route cannot complete inside the configured wall-clock timeout.
- Leave docs and fixtures in place during rollback unless they describe behavior that is no longer reachable.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
