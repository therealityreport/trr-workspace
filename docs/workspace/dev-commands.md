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
- screenalytics Streamlit: `http://127.0.0.1:8501`
- screenalytics Web: `http://127.0.0.1:8080`

For startup tuning and env overrides, see `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`.
