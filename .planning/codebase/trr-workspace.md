# TRR Workspace Map

Generated: 2026-06-23

Root: `/Users/thomashulihan/Projects/TRR`

## Practical Shape

The root workspace is the control plane for local development and agent policy. It wires together two nested repos, `TRR-Backend` and `TRR-APP`, but it is not the primary implementation owner for backend APIs or Next.js app code.

The root owns:

- Workspace startup and shutdown through `Makefile` and `scripts/dev-workspace.sh`.
- Shared agent/project policy through `AGENTS.md` and `.codex/rules/trr-project.md`.
- Cross-repo contracts under `docs/workspace/`, `docs/agent-governance/`, and `docs/cross-collab/`.
- Runtime profiles in `profiles/`.
- Browser, MCP, Supabase, Modal, Vercel, Portless, and validation wrapper commands.

## Repo Boundaries

- `TRR-Backend/` is a nested Git repo and owns backend implementation.
- `TRR-APP/` is a nested Git repo and owns app implementation.
- The root repo is also dirty. Existing unrelated edits were preserved.
- `BRAVOTV/`, `.external/`, `data/`, runtime logs, artifacts, caches, and worktrees are adjacent or runtime/evidence state unless a task explicitly targets them.

## Main Command Surface

From the root `Makefile`:

- `make dev` starts the default local path: local app, local backend, direct DB lane, remote workers disabled, Modal dispatch disabled.
- `make dev-cloud` selects explicit cloud/remote-worker behavior on the session/pooler DB lane.
- `make dev-hybrid` runs local app/backend while enabling remote social workers and Modal lanes.
- `make dev-portless` starts app, API, and Wordle through stable Portless HTTPS names.
- `make stop`, `make status`, and `make status-json` manage or inspect workspace runtime state.
- `make app-validate-quick` is the lightweight app validation gate.
- `make preflight` is the normal startup gate.
- `make git-branch-report` is the branch cleanup/read-only report before branch-ref changes.
- `make chrome-repair`, `make chrome-devtools-mcp-status`, and related targets handle managed browser automation health.
- `make supabase-mcp-access`, `make supabase-advisor-snapshot`, and `make supabase-preview-branch-cleanup` own Supabase operator checks.
- `make modal-instagram-auth-status` and `make modal-instagram-auth-repair` own Modal Instagram auth readiness and repair workflows.

## Runtime Contract

The current shared env contract in `docs/workspace/env-contract.md` says:

- `make dev` is local-process-first.
- `make dev-cloud` is explicit remote/cloud mode.
- `make dev-hybrid` keeps local app/backend on the direct DB lane while remote workers use session/pooler lanes.
- Direct DB URLs are local-only and must not be pushed into Modal, Render, Cloud Run, or Vercel.
- Redis is ephemeral realtime fanout only; durable state remains in Postgres/Supabase.
- Modal owns long-running remote jobs when remote execution is enabled.

## Browser And MCP Policy

Current workspace browser policy:

- Browser verification defaults to `make dev-hybrid` when browser inspection is needed.
- Use the `TRR` Chrome profile for normal TRR/admin work.
- The managed `openai-agent` Chrome profile is an automation clone, not the real Codex profile.
- Use the real `Codex` Chrome profile only when explicitly requested.
- `chrome-devtools` is browser/DevTools verification only.

Current MCP policy:

- User-global MCPs remain inherited by default.
- TRR-local MCPs are additive and live in project config.
- `supabase` is for TRR Supabase schema/data/runtime contract checks.
- `modal-ops` is for TRR Modal readiness/log/status work.
- `next-devtools` is for Next.js dev diagnostics once the app is running.

## Validation And Build Safety

Root validation paths:

- `make preflight` is the main startup gate.
- `make app-validate-quick` runs lightweight generated-contract and safe-build-wrapper checks.
- `make test-fast`, `make test`, `make test-full`, and `make test-changed` route increasingly broad checks.
- Full TRR-APP production build commands are blocked by project rule unless the user approves them in the current chat.

## Confusing Ownership Points

- Root startup scripts project env into both nested repos; changing env behavior often requires root docs plus nested app/backend updates.
- Browser profile names matter. Do not substitute `openai-agent` when the user asks for `TRR` or `Codex`.
- `TRR-Backend/.locks/`, `.logs/`, `.artifacts/`, `.next/`, and similar paths are runtime/evidence state, not source ownership by default.
- `TRR-APP` build behavior is controlled both by workspace rules and app-local `safe-next-build.mjs`.
- Modal-related backend/runtime changes require Modal follow-through unless the user explicitly asks for local-only work.

## Evidence Files Read

- `AGENTS.md`
- `.codex/rules/trr-project.md`
- `Makefile`
- `docs/workspace/env-contract.md`
- `docs/workspace/dev-commands.md`
- `docs/workspace/chrome-devtools.md`
- `docs/workspace/browser-debug.md`
- `docs/agent-governance/mcp_inventory.md`
- live filesystem and Git status output
