# Supabase Hardening Closeout Plan

Last reviewed: 2026-04-09

## Summary
This document replaces the earlier implementation plan for Supabase hardening.

The original hardening work is already landed in the current codebase. The remaining work is closeout-only:
- confirm active backend docs still match the live contract
- remove stale browser-Supabase env examples from `TRR-APP`
- confirm `screenalytics` runtime code is already canonical
- run a focused verification pass that proves the current state

This is not a plan to re-implement backend timeout hardening, runtime DB env resolution, or Flashback browser Supabase access.

## Current Repo Truth

### TRR-Backend
- Runtime DB resolution is already `TRR_DB_URL` then optional `TRR_DB_FALLBACK_URL`.
- Runtime code no longer accepts `SUPABASE_DB_URL` or `DATABASE_URL` as startup candidates.
- The psycopg2 pool already applies:
  - `connect_timeout`
  - `statement_timeout`
  - `idle_in_transaction_session_timeout`
- Request-timeout middleware is already implemented and mounted.
- `/health` is already DB-aware.
- Local Supabase config already enables session-mode pooling.

### screenalytics
- Runtime code already uses `TRR_DB_URL` with optional `TRR_DB_FALLBACK_URL`.
- No repo-tracked runtime path needs legacy `SUPABASE_DB_URL` or `DATABASE_URL`.
- Local ignored env files such as `screenalytics/.env` are operational state and are outside repo scope for this closeout.

### TRR-APP
- Server Postgres access already uses the canonical `TRR_DB_URL` then `TRR_DB_FALLBACK_URL` contract.
- Active app source no longer uses browser-side `NEXT_PUBLIC_SUPABASE_URL` or `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
- Flashback public gameplay is disabled, so restoring browser Supabase is obsolete and out of scope.
- Server-only Supabase usage remains valid for auth/admin support paths.

## Remaining Work

### Phase 1: Replace the stale plan with a current-state closeout
- Keep this file concise and implementation-ready.
- Remove the old build-style checklist for code that is already present.
- Preserve the repo order of record for cross-repo work:
  1. `TRR-Backend`
  2. `screenalytics`
  3. `TRR-APP`
- Treat this plan as a closeout artifact, not a source of new runtime requirements.

### Phase 2: Backend active-doc confirmation pass
Review only these active backend files:
- `TRR-Backend/.env.example`
- `TRR-Backend/README.md`
- `TRR-Backend/docs/deploy/cloud_run.md`

Confirm they consistently describe:
- runtime envs:
  - `TRR_DB_URL`
  - `TRR_DB_FALLBACK_URL`
- tooling-only compatibility envs:
  - `DATABASE_URL`
  - `SUPABASE_DB_URL`
- timeout/runtime controls:
  - `TRR_DB_CONNECT_TIMEOUT_SECONDS`
  - `TRR_DB_STATEMENT_TIMEOUT_MS`
  - `TRR_REQUEST_TIMEOUT_SECONDS`

Current status:
- `.env.example` already documents `TRR_DB_CONNECT_TIMEOUT_SECONDS` and `TRR_DB_STATEMENT_TIMEOUT_MS`
- `README.md` already documents the canonical runtime DB contract
- `docs/deploy/cloud_run.md` already documents `TRR_DB_URL` and `TRR_DB_FALLBACK_URL` correctly
- no backend doc changes are required unless a fresh verification pass finds drift

Do not edit archive, handoff, or historical backend docs as part of this closeout.

### Phase 3: TRR-APP tracked env-example cleanup
- Remove `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` from `TRR-APP/apps/web/.env.example`.
- Remove the adjacent comment block that still says those vars are required for `/flashback/cover` and `/flashback/play`.
- Do not replace them with commented retired placeholders.
- Preserve the active server-only Supabase contract:
  - `TRR_CORE_SUPABASE_URL`
  - `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- Treat hosted env cleanup and local `.env.local` cleanup as operational follow-up, not repo work for this pass.

### Phase 4: Confirmation-only pass for existing app task docs
Review these documents for contradiction only:
- `TRR-APP/docs/cross-collab/TASK23/PLAN.md`
- `TRR-APP/docs/cross-collab/TASK24/PLAN.md`

Current expectation:
- `TASK23` should already match the current post-hardening server contract
- `TASK24` may describe the retired Flashback browser envs as historical context, but should not be rewritten unless it contradicts current repo truth in a way that would mislead active work

Only edit these files if they are materially inconsistent with current code. If they are already aligned, leave them unchanged and record that they were confirmed.

### Phase 5: screenalytics contract confirmation
- Confirm runtime code paths still use only `TRR_DB_URL` and `TRR_DB_FALLBACK_URL`.
- Do not modify `screenalytics` unless a repo-tracked runtime/documentation file contradicts the canonical contract.
- Treat `screenalytics/.env` as ignored local state, outside repo scope.

## Contracts

### Runtime DB contract
- `TRR_DB_URL`
- `TRR_DB_FALLBACK_URL`

### Tooling-only compatibility
- `DATABASE_URL`
- `SUPABASE_DB_URL`

### Backend timeout/runtime controls
- `TRR_DB_CONNECT_TIMEOUT_SECONDS`
- `TRR_DB_STATEMENT_TIMEOUT_MS`
- `TRR_REQUEST_TIMEOUT_SECONDS`

### App server-only Supabase contract
- `TRR_CORE_SUPABASE_URL`
- `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`

### Retired app browser envs
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## Verification Commands

### Backend verification
```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/db/test_connection_resolution.py tests/db/test_pg_timeout_settings.py tests/middleware/test_request_timeout.py -q
```

### App verification
```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts tests/flashback-disabled-routes.test.ts tests/admin-games-config.test.ts
```

### Contract confirmation
```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "SUPABASE_DB_URL|DATABASE_URL" TRR-Backend/trr_backend TRR-APP/apps/web/src screenalytics/apps/api screenalytics/tools
rg -n "NEXT_PUBLIC_SUPABASE_URL|NEXT_PUBLIC_SUPABASE_ANON_KEY" TRR-APP/apps/web/src TRR-APP/apps/web/tests
rg -n "TRR_DB_URL|TRR_DB_FALLBACK_URL" screenalytics/apps/api screenalytics/tools
```

Run touched-repo standard validation only for repos whose tracked files actually change.

## Acceptance Criteria
- This plan file no longer proposes already-landed hardening work as future implementation.
- `TRR-APP/apps/web/.env.example` no longer advertises retired browser Supabase envs.
- Backend active docs are either confirmed correct or updated if drift is found.
- `screenalytics` is confirmed canonical without unnecessary repo edits.
- Focused verification passes with fresh command output.

## Out of Scope
- Re-implementing backend hardening already present in code
- Restoring Flashback browser Supabase or public gameplay
- Editing archive, handoff, or historical documentation
- Cleaning local ignored env files such as `screenalytics/.env` or `TRR-APP/apps/web/.env.local`
- Hosted secret rotation or Vercel/runtime env cleanup outside repo-tracked files

## Assumptions
- The source of truth is the current codebase, not the earlier plan draft.
- `screenalytics/.env` is local ignored state and should not drive repo-scoped edits.
- Backend doc work is confirmation-first; edits happen only if a fresh review finds drift.
- `TASK23` and `TASK24` are expected to be mostly current and should only be edited if a contradiction is found.
