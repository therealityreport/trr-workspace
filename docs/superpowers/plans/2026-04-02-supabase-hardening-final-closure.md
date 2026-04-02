# Supabase Hardening — Final Contract Closure

**Date:** 2026-04-02
**Status:** In Progress
**Parent:** 2026-04-01-supabase-unified-hardening-final.md

## Summary

Close the remaining contract drift across TRR-APP, TRR-Backend docs, and workspace preflight. No new architecture — just alignment with the lane policy already enforced in TRR-Backend and screenalytics.

## Changes

### 1. Fix workspace preflight env contract drift (blocking `make dev`)
- Add `"docs/superpowers/plans/"` to `HISTORICAL_PATH_FRAGMENTS` in `scripts/env_contract_report.py`
- Regenerate `docs/workspace/env-deprecations.md`
- **Why:** Plan docs reference deprecated env names (`SUPABASE_DB_URL`, `DATABASE_URL`) historically; the classifier didn't recognize `docs/superpowers/plans/` as a historical path

### 2. Close TRR-APP local lane grace period
- `TRR-APP/apps/web/src/lib/server/postgres.ts`: `validateRuntimeLane()` should throw for all non-session/local lanes regardless of `isDeployed` flag
- `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`: Replace "warns but allows" assertions with hard-fail expectations for `transaction` and `direct` in local dev
- **Why:** Backend (`8106a58`) and screenalytics (`ec9c764`) already hard-fail in all environments; TRR-APP is the last repo with warn-only behavior

### 3. Remove stale direct-fallback guidance from TRR-Backend docs
- `.env.example`: Remove `TRR_DB_ENABLE_DIRECT_FALLBACK` reference
- `README.md`: Remove derived-direct-fallback troubleshooting text; describe only `TRR_DB_URL` + `TRR_DB_FALLBACK_URL` session pooler contract
- **Why:** The env var was removed from runtime in commit `8106a58`; docs still advertise it

## Test Plan
- Workspace: `make dev` preflight passes (validates env contract reports)
- TRR-APP: `pnpm -C apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts`
- TRR-Backend: docs-only changes, no code test expansion needed

## Order
1. Workspace preflight fix (unblocks `make dev` for all subsequent work)
2. TRR-Backend docs cleanup
3. TRR-APP lane policy closure + tests
