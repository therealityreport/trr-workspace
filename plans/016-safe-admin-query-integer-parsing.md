# Plan 016: Add safe integer parsing for admin route query params

> **Executor instructions**: Fix the shared pattern once and migrate only the
> obvious affected admin routes in this plan.
>
> **Drift check**: `git -C TRR-APP diff --stat 83778e5c..HEAD -- apps/web/src/app/api/admin/trr-api apps/web/tests`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: correctness
- **Planned at**: TRR-APP `83778e5c`, 2026-07-07

## Why this matters

Several admin route handlers parse `limit` and `offset` with `parseInt`, then
clamp with `Math.min(Math.max(...))`. `NaN` survives that clamp and can produce
500s instead of a clean 400 or default.

## Current state

- `apps/web/src/app/api/admin/trr-api/people/route.ts:26` parses `limit`.
- `apps/web/src/app/api/admin/trr-api/people/route.ts:27` parses `offset`.
- `apps/web/src/app/api/admin/trr-api/people/route.ts:38` clamps only `limit`.
- Similar parse sites exist under shows, seasons, cast, photos, and episodes
  routes.

## Scope

**In scope**:
- a small helper under `apps/web/src/lib/server/trr-api/` or nearby existing
  server route helper location
- affected admin route handlers using `limit`/`offset`
- focused route tests

**Out of scope**:
- Rewriting route factories.
- Changing successful pagination response shapes.

## Steps

1. Add a helper like `parseBoundedIntegerParam(value, { defaultValue, min, max })`.
2. Return defaults for missing params.
3. Reject malformed explicit params with 400 where the route already has an
   error-response pattern; otherwise default safely and add a comment in tests.
4. Migrate the `people` route first, then the small set of matching
   `limit`/`offset` routes identified by grep.
5. Add tests for `limit=abc`, `offset=abc`, too-low, and too-high values.

## Commands

Run from `TRR-APP/`:

```bash
pnpm -C apps/web exec vitest run tests/admin-people-route.test.ts tests/admin-shows-route.test.ts
pnpm -C apps/web run typecheck
pnpm -C apps/web run lint
```

Adjust the focused test filenames to the live route test names if they differ.

## Done criteria

- Malformed explicit numeric query params no longer reach repository calls as
  `NaN`.
- Shared helper is used by the migrated routes.
- Focused route tests, typecheck, and lint pass.
