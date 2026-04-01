# Workspace Dev Commands

Use these commands from `/Users/thomashulihan/Projects/TRR`.

## Daily Commands
- `make dev` — recommended default workspace startup
- `make status` — workspace health and PID snapshot
- `make stop` — stop workspace-managed processes
- `make test-fast`
- `make test-full`
- `make test-changed`
- `make codex-check`
- `make mcp-clean`
- `make help`

## Additional Commands
- `make dev-local` — local Docker-backed screenalytics mode
- `make down` — tear down local Docker infra used by `make dev-local`
- `make bootstrap` — one-time dependency setup
- `bash scripts/codex-config-sync.sh bootstrap` — bootstrap minimal user-level `~/.codex` files without reapplying TRR project config there

## Quick URLs
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000`
- screenalytics API: `http://127.0.0.1:8001`

The default `make dev` profile keeps the screenalytics API on but leaves the Streamlit and Web UIs disabled. Re-enable them with `WORKSPACE_SCREENALYTICS_STREAMLIT_ENABLED=1` and/or `WORKSPACE_SCREENALYTICS_WEB_ENABLED=1`.

The same default profile now runs TRR long jobs on the remote Modal executor by default. Shared-account Instagram `Sync Recent`, `Resume Tail`, and `Backfill Posts` should use Modal-owned dispatch unless you explicitly override the workspace profile for rollback/debug.

For startup tuning and env overrides, see `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`.
