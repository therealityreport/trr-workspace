# Plan Patches

## Required Patch 1: Preserve Stale Fallback

Original issue: backend service caught all exceptions and returned HTTP 200 with `data: null`.

Patch: dashboard service must let summary/progress failures throw. The app snapshot cache then serves last-good data through `staleIfErrorTtlMs`. The app route derives `dashboard_freshness.status = "stale"` from snapshot metadata when fallback data is served.

## Required Patch 2: Fix Backend Progress Call Signature

Original issue:

```python
analytics_repo.get_social_account_catalog_run_progress(
    run_id=progress_run_id,
    recent_log_limit=recent_log_limit,
)
```

Patch:

```python
analytics_repo.get_social_account_catalog_run_progress(
    platform,
    account_handle,
    progress_run_id,
    recent_log_limit=recent_log_limit,
)
```

## Required Patch 3: Fix App Type and Test Paths

Original issue:

```text
TRR-APP/apps/web/src/types/admin/social-account-profile.ts
TRR-APP/apps/web/src/components/admin/__tests__/SocialAccountProfilePage.initial-budget.test.tsx
```

Patch:

```text
TRR-APP/apps/web/src/lib/admin/social-account-profile.ts
TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
TRR-APP/apps/web/tests/social-account-profile-snapshot-route.test.ts
```

## Required Patch 4: Use Vitest and Default Component Export

Original issue: the plan used Jest globals and a named component import.

Patch: use `vi` from Vitest and import:

```ts
import SocialAccountProfilePage from "@/components/admin/SocialAccountProfilePage";
```

## Required Patch 5: Use Existing Snapshot Cache Modules

Original issue:

```ts
import { getOrCreateAdminSnapshot, buildSnapshotResponse } from "@/lib/server/admin-route-cache";
```

Patch:

```ts
import {
  buildAdminAuthPartition,
  buildAdminSnapshotCacheKey,
  getOrCreateAdminSnapshot,
} from "@/lib/server/admin/admin-snapshot-cache";
import { buildSnapshotResponse } from "@/lib/server/admin/admin-snapshot-route";
```

## Required Patch 6: Normalize Backend Dashboard Into Current Snapshot Shape

Original issue: returning the backend dashboard payload directly would nest `data.summary` under `snapshot.payload.data.summary`, while the page currently reads `snapshot.payload.summary`.

Patch: app `/snapshot` normalizes backend dashboard into:

```ts
{
  summary,
  catalog_run_progress,
  dashboard_freshness,
  operational_alerts
}
```

## Required Patch 7: Correct Backend Test Route Prefix

Original issue: TestClient examples used `/admin/socials/...`.

Patch: app-level backend tests use `/api/v1/admin/socials/...`.

