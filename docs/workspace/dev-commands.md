# Workspace Dev Commands

Use these commands from `/Users/thomashulihan/Projects/TRR`.

## Preferred Contract
- `make dev` is the recommended cloud-first path. Normal `TRR-Backend` and `TRR-APP` development should not require Docker in this workspace.
- Use `make dev-local` only when you intentionally need local Screenalytics-side Docker infrastructure that the normal cloud-first path does not provide.
- `PROFILE=default` is the canonical profile behind `make dev`. `local-cloud`, `local-lite`, and `local-full` remain compatibility profiles only.

## Daily Commands
- `make dev` — recommended default workspace startup (cloud-first; no Docker required for normal backend/app work)
- `make preflight` — local startup gate; warns on malformed handoff source docs and stale generated env docs but still blocks on runtime-affecting issues
- `make preflight-strict` — blocking validation path for malformed handoff source docs and env-contract drift
- `make handoff-check` — canonical blocking handoff/status snapshot validator
- `make env-contract` — refresh `docs/workspace/env-contract.md`
- `make env-contract-report` — refresh the env-contract inventory/deprecation review docs intentionally
- `make status` — workspace health and PID snapshot
- `make stop` — stop workspace-managed processes
- `make test-fast`
- `make test-full`
- `make test-changed`
- `make codex-check`
- `make mcp-clean`
- `make help`

## Fallback / Specialized Commands
- `make dev-local` — explicit Docker-backed fallback for local Screenalytics, Redis, and MinIO work
- `make down` — tear down local Docker infra used by `make dev-local`
- `make bootstrap` — one-time dependency setup
- `bash scripts/codex-config-sync.sh bootstrap` — bootstrap minimal user-level `~/.codex` files without reapplying TRR project config there

## Remaining Docker-Only Cases
- `make dev-local` — local Screenalytics Redis + MinIO fallback when you specifically need local infra parity
- `make down` — teardown companion for that explicit fallback lane
- `TRR-Backend make schema-docs-reset-check` — backend-local replay fallback when an isolated remote validation target does not answer the reset/replay question
- `TRR-Backend make ci-local` — Docker-backed local replay parity lane for intentionally local-only backend verification

If your task is ordinary backend/app development or milestone verification, start with the cloud-first path and only drop to these Docker-backed cases when the question itself is about local infra behavior.

## Quick URLs
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000`

The default `make dev` profile now launches only TRR-APP and TRR-Backend. Screenalytics remains an admin feature label in the app, not a separately managed local runtime.

Flashback live gameplay is currently disabled and `/flashback`, `/flashback/cover`, and `/flashback/play` redirect to `/hub`, so legacy browser-only Flashback envs are not part of the normal `make dev` startup contract.

The backend auto-restart path is now liveness-based. A transient Supabase/DNS issue can still make backend readiness (`/health`) degrade, but the workspace watchdog should only recycle the process when backend liveness (`/health/live`) fails.

If preflight warns about malformed handoff source docs, fix the cited file and rerun `make handoff-check` or `make preflight-strict`. Default local startup intentionally continues so ordinary backend/app work is not blocked by continuity-note formatting mistakes.

If preflight warns that generated env-contract docs are stale, refresh them intentionally with `make env-contract` or `make env-contract-report` and rerun `make preflight` when you want the repo baseline updated. Normal non-strict startup no longer rewrites those tracked docs automatically.

Browser automation warnings now come from the same structured readiness states used by `make chrome-devtools-mcp-status`: `ready`, `degraded`, `recoverable`, and `unavailable`. A missing shared `9422` keeper with working auto-launch remains a recoverable state, not an unavailable one.

The same default profile now runs TRR long jobs on the remote Modal executor by default. Shared-account Instagram `Sync Recent`, `Resume Tail`, and `Backfill Posts` should use Modal-owned dispatch unless you explicitly override the workspace profile for rollback/debug.

For migration or schema validation, prefer an isolated Supabase branch or disposable database target and point `TRR_DB_URL` there before running backend verification commands. Do not aim destructive replay or reset flows at shared persistent databases.

For startup tuning and env overrides, see `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`.
