# TRR Workspace / Dev-Contract Map

## Scope
- Workspace root: `/Users/thomashulihan/Projects/TRR`
- Purpose: map the live dev-contract layer, not implementation details.
- Sources used: repo files only, especially [AGENTS.md](/Users/thomashulihan/Projects/TRR/AGENTS.md), [`.codex/rules/trr-project.md`](/Users/thomashulihan/Projects/TRR/.codex/rules/trr-project.md), [Makefile](/Users/thomashulihan/Projects/TRR/Makefile), and the workspace docs under [`docs/workspace/`](/Users/thomashulihan/Projects/TRR/docs/workspace/).

## Workspace Layout
- [Makefile](/Users/thomashulihan/Projects/TRR/Makefile): single root command surface for dev, health, validation, and policy checks.
- [scripts/](/Users/thomashulihan/Projects/TRR/scripts/): launcher, contract, browser, Supabase, and test glue.
- [TRR-APP/](/Users/thomashulihan/Projects/TRR/TRR-APP): frontend repo, managed with pnpm.
- [TRR-Backend/](/Users/thomashulihan/Projects/TRR/TRR-Backend): backend repo, managed with Python `3.11.9`, `.venv`, and requirements lockfiles.
- [docs/workspace/](/Users/thomashulihan/Projects/TRR/docs/workspace/): generated env contract, browser policy, and operational runbooks.
- [.codex/](/Users/thomashulihan/Projects/TRR/.codex/): workspace-specific Codex config, rules, and agent routing.
- [.planning/codebase/](/Users/thomashulihan/Projects/TRR/.planning/codebase/): planning-only maps and notes.

## Package Managers and Version Pins
- Root Node baseline: [`.nvmrc`](/Users/thomashulihan/Projects/TRR/.nvmrc) pins `24`.
- App Node baseline: [`TRR-APP/.nvmrc`](/Users/thomashulihan/Projects/TRR/TRR-APP/.nvmrc) also pins `24`.
- App package manager: [`TRR-APP/package.json`](/Users/thomashulihan/Projects/TRR/TRR-APP/package.json) uses `pnpm@10.15.0`.
- App web package: [`TRR-APP/apps/web/package.json`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/package.json) is the main Next.js workspace.
- Backend Python baseline: [`TRR-Backend/.python-version`](/Users/thomashulihan/Projects/TRR/TRR-Backend/.python-version) pins `3.11.9`.
- Backend dependency contract: [`TRR-Backend/requirements.txt`](/Users/thomashulihan/Projects/TRR/TRR-Backend/requirements.txt) plus lockfiles under `TRR-Backend/`.

## Dev Commands
- Default local workspace: `make dev`
- Explicit cloud / remote worker lane: `make dev-cloud`
- Local app/backend with remote worker lane: `make dev-hybrid`
- Background hybrid launcher: `make dev-hybrid-bg`
- Preflight gates: `make preflight`, `make preflight-strict`, `make preflight-cloud`, `make preflight-hybrid`
- Status and stop: `make status`, `make stop`, `make logs`
- Validation: `make app-check`, `make test-fast`, `make test-full`, `make test-changed`, `make test-env-sensitive`
- Policy / contract refresh: `make env-contract`, `make env-contract-report`, `make check-policy`, `make codex-check`, `make handoff-check`
- Browser/MCP maintenance: `make mcp-clean`, `make chrome-devtools-mcp-status`, `make chrome-devtools-mcp-clean-stale`, `make chrome-devtools-mcp-stop-conflicts`
- Supabase checks: `make supabase-mcp-access`, `make supabase-advisor-snapshot`

## App Scripts
- Root app orchestration: [`TRR-APP/package.json`](/Users/thomashulihan/Projects/TRR/TRR-APP/package.json)
  - `pnpm run dev` can start backend + web together.
  - `pnpm run web:dev`, `web:build`, `web:validate:quick`, `web:start`, `web:clean` are the main app-only entrypoints.
  - `pnpm run emulators` and `pnpm run dev:local` are Firebase emulator paths.
- Main web app scripts: [`TRR-APP/apps/web/package.json`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/package.json)
  - `dev`, `dev:turbo`, `dev:webpack`, `dev:stable`
  - `build` uses `scripts/safe-next-build.mjs`
  - `validate:quick` is the lightweight gate required before any full production build ask
  - `lint`, `typecheck`, `test`, `test:e2e`, `smoke:admin-detail-routes`

## Backend Scripts
- Backend workspace Makefile: [`TRR-Backend/Makefile`](/Users/thomashulihan/Projects/TRR/TRR-Backend/Makefile)
  - `dev`, `stop`, `logs` delegate to the root workspace contract.
  - `doctor`, `schema-docs`, `schema-docs-check`, `schema-docs-reset-check`, `ci-local`
  - `repo-map`, `repo-map-check`
  - `pipeline-run`, `pipeline-status`, `pipeline-list`
- Backend runtime baseline comes from [`TRR-Backend/.venv`](/Users/thomashulihan/Projects/TRR/TRR-Backend/.venv) when present; otherwise `python3`.

## Workspace Launch and Health Flow
- Canonical launcher: [`scripts/dev-workspace.sh`](/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh)
  - loads `profiles/*.env`
  - applies local/cloud/hybrid defaults
  - reconciles runtime contracts before launch
  - starts the app/backend stack and writes state under [`.logs/workspace/`](/Users/thomashulihan/Projects/TRR/.logs/workspace/)
- Preflight: [`scripts/preflight.sh`](/Users/thomashulihan/Projects/TRR/scripts/preflight.sh)
  - combines node baseline, env-contract, handoff, browser attention, and runtime reconcile checks
- Status: [`scripts/status-workspace.sh`](/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh)
  - reads the pidfile/watchdog state and reports app/backend/browser/remote-worker status
- Smoke: [`scripts/smoke.sh`](/Users/thomashulihan/Projects/TRR/scripts/smoke.sh)
  - verifies backend health, app health, and listeners after startup
- Stop / logs: [`scripts/stop-workspace.sh`](/Users/thomashulihan/Projects/TRR/scripts/stop-workspace.sh), [`scripts/logs-workspace.sh`](/Users/thomashulihan/Projects/TRR/scripts/logs-workspace.sh)

## Env Contract Docs
- Generated runtime contract: [`docs/workspace/env-contract.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md)
- Generator: [`scripts/workspace-env-contract.sh`](/Users/thomashulihan/Projects/TRR/scripts/workspace-env-contract.sh)
- Inventory and deprecation review: [`docs/workspace/env-contract-inventory.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract-inventory.md), [`docs/workspace/env-deprecations.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/env-deprecations.md)
- Shared env manifest: [`docs/workspace/shared-env-manifest.json`](/Users/thomashulihan/Projects/TRR/docs/workspace/shared-env-manifest.json)
- Env hygiene and drift helpers: [`scripts/workspace/env_hygiene.py`](/Users/thomashulihan/Projects/TRR/scripts/workspace/env_hygiene.py), [`scripts/lib/preflight-env-contract.sh`](/Users/thomashulihan/Projects/TRR/scripts/lib/preflight-env-contract.sh), [`scripts/lib/preflight-env-drift.sh`](/Users/thomashulihan/Projects/TRR/scripts/lib/preflight-env-drift.sh)

## MCP, Browser, and Supabase Routing
- Project MCP inventory: [`docs/agent-governance/mcp_inventory.md`](/Users/thomashulihan/Projects/TRR/docs/agent-governance/mcp_inventory.md)
- Browser policy: [`docs/workspace/chrome-devtools.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/chrome-devtools.md)
- Root Codex config: [`.codex/config.toml`](/Users/thomashulihan/Projects/TRR/.codex/config.toml)
  - declares the trusted project-local Supabase MCP endpoint for project `vwxfvzutyufrkhfgoeaa`
  - keeps browser defaults inherited from the user-global Codex config
- Browser runtime helpers: [`scripts/lib/mcp-runtime.sh`](/Users/thomashulihan/Projects/TRR/scripts/lib/mcp-runtime.sh), [`scripts/codex-mcp-http-bridge.sh`](/Users/thomashulihan/Projects/TRR/scripts/codex-mcp-http-bridge.sh), [`scripts/codex-chrome-devtools-mcp.sh`](/Users/thomashulihan/Projects/TRR/scripts/codex-chrome-devtools-mcp.sh)
- Supabase access helper: [`scripts/check-supabase-mcp-access.py`](/Users/thomashulihan/Projects/TRR/scripts/check-supabase-mcp-access.py)
- Browser status/cleanup helpers: [`scripts/chrome-devtools-mcp-status.sh`](/Users/thomashulihan/Projects/TRR/scripts/chrome-devtools-mcp-status.sh), [`scripts/chrome-devtools-mcp-clean-stale.sh`](/Users/thomashulihan/Projects/TRR/scripts/chrome-devtools-mcp-clean-stale.sh), [`scripts/chrome-devtools-mcp-stop-conflicts.sh`](/Users/thomashulihan/Projects/TRR/scripts/chrome-devtools-mcp-stop-conflicts.sh)

## Validation and Test Entrypoints
- Root validation: [`scripts/app-check.sh`](/Users/thomashulihan/Projects/TRR/scripts/app-check.sh), [`scripts/test-fast.sh`](/Users/thomashulihan/Projects/TRR/scripts/test-fast.sh), [`scripts/test.sh`](/Users/thomashulihan/Projects/TRR/scripts/test.sh), [`scripts/test-changed.sh`](/Users/thomashulihan/Projects/TRR/scripts/test-changed.sh)
- Workspace policy validation: [`scripts/check-policy.sh`](/Users/thomashulihan/Projects/TRR/scripts/check-policy.sh), [`scripts/check-workspace-contract.sh`](/Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh), [`scripts/check-codex.sh`](/Users/thomashulihan/Projects/TRR/scripts/check-codex.sh)
- Workspace hygiene validation: [`scripts/workspace/hygiene_report.sh`](/Users/thomashulihan/Projects/TRR/scripts/workspace/hygiene_report.sh), [`scripts/workspace/hygiene_clean.sh`](/Users/thomashulihan/Projects/TRR/scripts/workspace/hygiene_clean.sh)
- App-local validation: `pnpm -C TRR-APP/apps/web run validate:quick`, `lint`, `typecheck`, `test`, `test:e2e`
- Backend validation: `TRR-Backend/Makefile` `doctor`, `schema-docs-check`, `ci-local`, plus repo pytest/ruff lanes

## Operational Boundaries
- `make dev` is the local-process-first baseline: local app, local backend, direct DB lane, remote workers disabled, Modal dispatch disabled.
- `make dev-cloud` is the explicit cloud/remote-worker path on the session/pooler lane.
- `make dev-hybrid` keeps local app/backend direct while enabling remote workers and the conservative social-safe caps.
- Browser verification defaults to `make dev-hybrid` unless a different target is explicitly requested.
- Full production builds are blocked by project rules unless explicitly approved; the lightweight app gate is `pnpm -C TRR-APP/apps/web run validate:quick`.
- Workspace runtime DB routing is lane-based, not one-size-fits-all: direct, session/pooler, transaction, and fallback URLs are treated differently in [`docs/workspace/env-contract.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md) and [`scripts/lib/runtime-db-env.sh`](/Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh).
- Secret-bearing values must not be repurposed as non-secret labels such as `application_name`.
- The workspace scripts treat repo-local docs and generated contracts as authoritative only when refreshed through the documented targets.

## Dependency Chain
- [`AGENTS.md`](/Users/thomashulihan/Projects/TRR/AGENTS.md) and [`.codex/rules/trr-project.md`](/Users/thomashulihan/Projects/TRR/.codex/rules/trr-project.md) set the workspace rules.
- [`Makefile`](/Users/thomashulihan/Projects/TRR/Makefile) fans out into [`scripts/dev-workspace.sh`](/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh), validation scripts, and doc-generation targets.
- [`scripts/dev-workspace.sh`](/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh) consumes profiles and env-contract helpers, then launches app/backend processes.
- [`docs/workspace/env-contract.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md) and the env-contract generator stay in sync through [`make env-contract`](/Users/thomashulihan/Projects/TRR/Makefile) and [`scripts/check-workspace-contract.sh`](/Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh).
- Browser and MCP behavior is owned by [`docs/workspace/chrome-devtools.md`](/Users/thomashulihan/Projects/TRR/docs/workspace/chrome-devtools.md), [`docs/agent-governance/mcp_inventory.md`](/Users/thomashulihan/Projects/TRR/docs/agent-governance/mcp_inventory.md), and [`scripts/check-codex.sh`](/Users/thomashulihan/Projects/TRR/scripts/check-codex.sh).

