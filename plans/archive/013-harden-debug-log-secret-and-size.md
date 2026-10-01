# Plan 013: Harden the debug-log endpoint secret check and body size

> **Executor instructions**: Do not log secret values or raw request bodies in
> tests or failure messages.
>
> **Drift check**: `git -C TRR-APP diff --stat 83778e5c..HEAD -- apps/web/src/app/api/debug-log/route.ts apps/web/src/lib/server/trr-api/internal-admin-auth.ts`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: TRR-APP `83778e5c`, 2026-07-07

## Why this matters

The remote debug-log endpoint has a shared-secret fallback, but compares strings
with `===` and accepts `request.json()` without a clear body-size cap. The route
is flag-gated, but it is still an internal ingestion endpoint.

## Current state

- `apps/web/src/app/api/debug-log/route.ts:45` defines `isAuthorized()`.
- `apps/web/src/app/api/debug-log/route.ts:52` checks
  `providedSecret === sharedSecret`.
- `apps/web/src/app/api/debug-log/route.ts:73` calls `await request.json()`.
- `apps/web/src/lib/server/trr-api/internal-admin-auth.ts` already imports and
  uses Node `timingSafeEqual`.

## Scope

**In scope**:
- `apps/web/src/app/api/debug-log/route.ts`
- a focused route test, create one if no debug-log test exists

**Out of scope**:
- Changing `requireAdmin()`.
- Persisting debug logs anywhere new.

## Steps

1. Add a local constant-time string comparison helper or reuse an existing server
   helper if one is already exported.
2. Reject shared-secret bodies above a small fixed cap before parsing JSON.
3. Keep local-host behavior and `TRR_REMOTE_DEBUG_LOG_ENABLED` behavior intact.
4. Add tests for constant-time path behavior at the API level, oversize body
   rejection, and normal admin auth fallback.

## Commands

Run from `TRR-APP/`:

```bash
pnpm -C apps/web exec vitest run tests/debug-log-route.test.ts
pnpm -C apps/web run typecheck
pnpm -C apps/web run lint
```

## Done criteria

- Secret comparison no longer uses `===`.
- Oversize bodies are rejected before JSON parsing.
- Focused tests, typecheck, and lint pass.
