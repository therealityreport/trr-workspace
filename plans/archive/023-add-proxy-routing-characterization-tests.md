# Plan 023: Add characterization tests for Next proxy routing

> **Executor instructions**: Add tests first. Do not refactor `proxy.ts` in this
> plan unless a tiny export is needed to make behavior testable.
>
> **Drift check**: `git -C TRR-APP diff --stat 83778e5c..HEAD -- apps/web/src/proxy.ts apps/web/tests`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: TRR-APP `83778e5c`, 2026-07-07

## Why this matters

`src/proxy.ts` is the active Next.js 16 middleware and routes every request
through host isolation, admin rewrites, screenalytics aliases, show routes, and
social paths. It has high blast radius but limited route characterization.

## Current state

- `apps/web/src/proxy.ts:1` says this is the active Next.js 16 middleware.
- `apps/web/src/proxy.ts:3` states it performs host isolation and routing only.
- The file defines reserved root route segments and multiple admin/social/show
  rewrite maps near the top.
- Existing tests cover some host/middleware behavior, but not the full route
  matrix for screenalytics, brand, social, fandom, and show rewrites.

## Scope

**In scope**:
- `apps/web/tests/proxy-routing.test.ts` or the nearest existing proxy test file
- `apps/web/src/proxy.ts` only for testable exports if unavoidable

**Out of scope**:
- Behavior changes.
- Auth changes.
- Large proxy refactor.

## Steps

1. Inventory current exported `proxy`/`config` behavior.
2. Add table-driven tests for representative routes:
   - admin host canonical admin route
   - `screenalytics` aliases
   - show root route and reserved segment
   - social week/platform route
   - brand/fandom route if currently rewritten
3. Assert status/rewrite/redirect destination, not implementation details.
4. If a test exposes current broken behavior, stop and report; do not silently
   change routing in a characterization plan.

## Commands

Run from `TRR-APP/`:

```bash
pnpm -C apps/web exec vitest run tests/proxy-routing.test.ts tests/admin-host-middleware.test.ts
pnpm -C apps/web run typecheck
pnpm -C apps/web run lint
```

## Done criteria

- Route matrix tests exist for the listed route families.
- `proxy.ts` behavior is unchanged.
- Focused tests, typecheck, and lint pass.
