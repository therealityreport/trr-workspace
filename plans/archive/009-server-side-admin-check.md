# Plan 009: Move admin allowlist checks behind a server route

> **Executor instructions**: This is security-sensitive. Do not include real
> admin emails, UIDs, tokens, or secrets in code, tests, logs, or the plan index.
>
> **Drift check**: `git -C TRR-APP diff --stat 83778e5c..HEAD -- apps/web/src/lib/admin/client-access.ts apps/web/src/lib/admin/constants.ts apps/web/src/lib/admin/useAdminGuard.ts apps/web/src/lib/server/auth.ts`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: security
- **Planned at**: TRR-APP `83778e5c`, 2026-07-07

## Why this matters

`NEXT_PUBLIC_ADMIN_EMAILS`, `NEXT_PUBLIC_ADMIN_UIDS`, and
`DEFAULT_ADMIN_UIDS` are bundled into browser code. That exposes admin identity
signals in a public client bundle. Authorization must still be enforced on the
server, but the client guard should ask the server whether the current user is
admin instead of carrying the allowlist itself.

## Current state

- `apps/web/src/lib/admin/client-access.ts:12` reads
  `process.env.NEXT_PUBLIC_ADMIN_EMAILS`.
- `apps/web/src/lib/admin/client-access.ts:16` combines `DEFAULT_ADMIN_UIDS`
  with `NEXT_PUBLIC_ADMIN_UIDS`.
- `apps/web/src/lib/admin/constants.ts:12` hardcodes `DEFAULT_ADMIN_UIDS`.
- `apps/web/src/lib/admin/useAdminGuard.ts` imports `isClientAdmin()` and is the
  shared client guard used by admin UI.
- `apps/web/src/lib/server/auth.ts` already owns server-side admin auth helpers.

## Scope

**In scope**:
- `apps/web/src/app/api/admin/check/route.ts` or the existing equivalent admin
  auth route if one now exists
- `apps/web/src/lib/admin/useAdminGuard.ts`
- `apps/web/src/lib/admin/client-access.ts`
- `apps/web/src/lib/admin/constants.ts`
- focused tests for client guard and server route

**Out of scope**:
- Reworking all admin pages.
- Weakening `requireAdmin` or backend route protection.
- Publishing real identities in tests.

## Steps

1. Add a server route that returns `{ hasAccess: boolean }` after checking the
   current session with existing server auth code.
2. Change `useAdminGuard()` so it fetches that route after Firebase auth state is
   known.
3. Remove public env allowlist reads and the hardcoded UID from client-bundled
   modules.
4. Keep a loading state while the server check is pending.
5. Update tests so a non-admin client cannot grant itself access without a
   positive server response.

## Commands

Run from `TRR-APP/`:

```bash
pnpm -C apps/web exec vitest run tests/client-admin-access.test.ts tests/use-admin-guard-stability.test.tsx
pnpm -C apps/web run typecheck
pnpm -C apps/web run lint
```

Do not run a production build without current-chat approval.

## Done criteria

- No `NEXT_PUBLIC_ADMIN_EMAILS`, `NEXT_PUBLIC_ADMIN_UIDS`, or hardcoded admin UID
  remains in client-bundled code.
- Admin UI access still works through a server-backed check.
- Focused tests, typecheck, and lint pass.
