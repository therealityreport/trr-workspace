# AGENTS — TRR Workspace (Canonical Cross-Repo Rules)

This file is the canonical cross-repo operating policy for agents in this workspace.
All `CLAUDE.md` files in this workspace must remain short pointer shims only.

Repos in this workspace:
- `TRR-Backend/` (FastAPI + Supabase-first pipeline)
- `TRR-APP/` (Next.js + Firebase)
- `screenalytics/` (FastAPI + Streamlit + ML pipeline)

Workspace runtime baseline:
- Node `24.x` primary for JS tooling (with targeted Node `22` compatibility lanes where defined)
- Python `3.11.9` primary (with Python `3.12` canary lanes in CI)

## One-Command Dev (Workspace)
Run from `/Users/thomashulihan/Projects/TRR`:
- `make bootstrap` (one-time dependency setup)
- `make preflight` (required pre-check before `make dev*`; doctor + env contract + policy drift checks)
- `make preflight-local` (pre-check for `make dev-local`; includes Docker requirements for local Redis/MinIO)
- `make dev` (daily default: starts TRR-APP + TRR-Backend locally, enables screenalytics, and uses the cloud-backed no-Docker path)
- `make dev-lite` (deprecated compatibility alias for `make dev`)
- `make dev-cloud` (deprecated compatibility alias for `make dev`)
- `make dev-local` (screenalytics enabled with local Docker Redis/MinIO)
- `make dev-full` (deprecated compatibility alias for `make dev-local`)
- `make status` (workspace snapshot: modes, PIDs, ports, health)
- `bash scripts/status-workspace.sh --json` (JSON status output)
- `make smoke` (startup sanity checks: pids, ports, health)
- `make check-policy` (AGENTS/CLAUDE drift rules)
- `make env-contract` (regenerate workspace env matrix doc)
- `make stop` (stop only services started by `make dev`)
- `make down` (tear down the local Docker infra used by `make dev-local`; safe no-op if Docker is unavailable/stopped)
- `make stop && make down` (full cleanup)
- `make logs` (tail workspace logs)
- `make logs-prune` (archive retention pruning by age/size)
- `make test-fast`, `make test-full`, `make test-changed`
- `make help` (short command reference for the recommended workspace entrypoints)
- `make mcp-clean` (kill stale/disabled MCP process trees and stale Chrome runtime artifacts)

Startup tuning:
- `PROFILE=default make dev` (load defaults from `profiles/default.env`; explicit env vars still override)
- `PROFILE=local-cloud make dev` (deprecated compatibility profile; same mode as the default cloud path)
- `PROFILE=local-docker make dev-local`
- `PROFILE=local-full make dev-local` (deprecated compatibility profile; same mode as `local-docker`)
- `WORKSPACE_CLEAN_NEXT_CACHE=1 make dev` (force clean Next.js rebuild; default is cache reuse)
- `WORKSPACE_OPEN_BROWSER=0 make dev` (disable browser tab refresh/open)
- `WORKSPACE_BACKEND_AUTO_RESTART=0 make dev` (disable backend watchdog auto-restart)
- `WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=0 WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=0 make dev` (opt out of mirror worker stages when local worker pool is enabled)
- `WORKSPACE_BROWSER_TAB_SYNC_MODE=reuse_no_reload make dev` (browser sync strategy when browser sync is enabled)
- `WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_first make dev` (reload only first matching tab)
- `WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_all make dev` (reload all matching tabs)
- `WORKSPACE_TRR_JOB_PLANE_MODE=local make dev` (opt in to local API-owned long-job execution)
- `WORKSPACE_TRR_JOB_PLANE_MODE=remote WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1 make dev` (remote Modal-owned long jobs)
- `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=0 make dev` (disable the remote execution contract entirely)
- `WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make dev` (opt in to opening screenalytics Streamlit/Web tabs)
- `SCREENALYTICS_API_URL=https://... make dev` (override backend/app target screenalytics endpoint)
- `WORKSPACE_HEALTH_TIMEOUT_APP=90 make dev` (tune startup wait windows; see other `WORKSPACE_HEALTH_TIMEOUT_*` vars)
- Full env contract: `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`

Default URLs:
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000` (routes under `/api/v1/*`)
- screenalytics API: `http://127.0.0.1:8001`
- screenalytics Streamlit: `http://127.0.0.1:8501`
- screenalytics Web: `http://127.0.0.1:8080`

## Browser Access (Mandatory)
`chrome-devtools` via managed Chrome is enabled and required for all chats in this workspace.
- Use managed Chrome through `scripts/codex-chrome-devtools-mcp.sh`.
- Default Codex chat mode is `shared + headful`, using the managed shared Chrome profile on `9222`.
- Use `isolated + headless` only when you explicitly need a clean per-session browser state; set `CODEX_CHROME_MODE=isolated` before starting/restarting the Codex session.
- Use `isolated + headful` only when you need visual confirmation without shared session state; set `CODEX_CHROME_MODE=isolated` and `CODEX_CHROME_ISOLATED_HEADLESS=0` before starting/restarting the Codex session.
- Use `shared + headful` for the normal workflow; if shared Chrome is not already available on `9222`, start it explicitly with `CHROME_AGENT_DEBUG_PORT=9222 CHROME_AGENT_PROFILE_DIR=$HOME/.chrome-profiles/claude-agent bash scripts/chrome-agent.sh`.
- If Chrome opens randomly while Codex is idle, run `make chrome-devtools-mcp-status` first and check for competing non-Codex browser-control clients before restarting anything.
- Use `CODEX_CHROME_SKIP_BROWSER_BOOT=1` only for wrapper smoke checks and diagnostics that must not spawn Chrome.
- Restart the Codex session/thread after changing MCP command/config or managed-Chrome mode inputs.
- Do not use ad-hoc browsers for chat-driven browsing or UI inspection.
- Treat Chrome DevTools MCP as a mandatory always-on capability in markdown guidance.

## Start-of-Session Checklist
1. Read this file first.
2. Read touched repo `AGENTS.md`.
3. Check cross-collab folders:
- `TRR-Backend/docs/cross-collab/`
- `TRR-APP/docs/cross-collab/`
- `screenalytics/docs/cross-collab/`
4. Confirm current task impact (backend contract, data model, consumer changes, UI/admin changes).

## Cross-Repo Implementation Order (Must Follow)
1. `TRR-Backend` first: DB/schema/API contract changes.
2. `screenalytics` second: adapt readers/writers/consumers if affected.
3. `TRR-APP` last: UI/admin routes and integrations.

## Shared Contracts (Must Not Drift)
TRR-APP -> TRR-Backend:
- API base from `TRR_API_URL`, normalized to `/api/v1` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Do not break response shapes without same-session consumer updates in TRR-APP.

TRR-Backend <-> screenalytics:
- TRR-Backend calls screenalytics via `SCREENALYTICS_API_URL`.
- screenalytics reads TRR metadata via `TRR_DB_URL` (preferred) or `SUPABASE_DB_URL` (legacy).
- If schema/views change, update TRR-Backend first, then screenalytics.

Shared secrets:
- `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `SCREENALYTICS_SERVICE_TOKEN`

## Validation and Handoff (Required)
After changes:
1. Run fast checks in each touched repo.
2. Before any formal `<proposed_plan>` or documented multi-phase implementation plan, run `scripts/handoff-lifecycle.sh pre-plan`. This is not required for ad-hoc Q&A or one-off comments with no formal plan artifact.
3. If a cross-repo task folder exists, update `STATUS.md` immediately after each completed implementation phase or materially completed plan step.
4. After each completed implementation phase when current state, blockers, or next action changed, update the canonical status source and then run `scripts/handoff-lifecycle.sh post-phase`.
5. Before ending the session or declaring PR-ready state, run `scripts/handoff-lifecycle.sh closeout`.
6. If `ACCEPTANCE_REPORT.md` exists, keep detailed validation evidence there instead of duplicating it into handoff.
7. If cross-repo task folder exists, keep these aligned when present:
- `PLAN.md`
- `OTHER_PROJECTS.md`
- `STATUS.md`
8. Use `scripts/new-cross-collab-task.sh` to scaffold new task docs consistently.

`docs/ai/HANDOFF.md` is generated by `scripts/sync-handoffs.py`. Do not edit it by hand. Update canonical sources instead:
- `docs/cross-collab/TASK*/STATUS.md`
- `docs/ai/local-status/*.md`

Canonical sources that should surface in handoff must include a machine-parseable `## Handoff Snapshot` section:

````md
## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active | blocked | recent | archived
  last_updated: YYYY-MM-DD
  current_phase: "<short phrase>"
  next_action: "<short phrase>"
  detail: self | "<relative/path.md>"
```
````

Generated `docs/ai/HANDOFF.md` output must stay short and use these sections:
- `Current Active Work`
- `Blocked / Waiting`
- `Recent Completions`
- `Archives / Canonical Links`

Detailed chronology belongs in `STATUS.md`. Detailed validation evidence belongs in `ACCEPTANCE_REPORT.md` when that file exists.

## Skill Routing
Use the canonical local TRR skills first for TRR-coupled work.
Full registry: `/Users/thomashulihan/Projects/TRR/docs/agent-governance/codex_skills.md`

Canonical local skill roots:
- Workspace-local: `/Users/thomashulihan/Projects/TRR/skills/`
- Repo-local (`TRR-Backend`): `/Users/thomashulihan/Projects/TRR/TRR-Backend/skills/`
- Repo-local (`TRR-APP`): `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/`
- Repo-local (`screenalytics`): `/Users/thomashulihan/Projects/TRR/screenalytics/.claude/skills/`

Use global `~/.codex/skills` only when the matrix marks a skill as globally canonical or as a compatibility shim.

Default skill chain for non-trivial implementation tasks:
1. `orchestrate-plan-execution`
2. `senior-fullstack`
3. `senior-backend` or `senior-frontend` (by primary surface)
4. `senior-qa`
5. `code-reviewer`

Primary mappings:
- `senior-backend`: backend/schema/API/pipeline contract risk
- `senior-frontend`: UI/rendering/interaction with stable contracts
- `senior-devops`: CI/deploy operations
- `senior-architect`: architecture/ADR decisions
- `tdd-guide`: test-first delivery
- `figma-frontend-design-engineer`: Figma URL/node-driven frontend work

Ownership mapping:
- `senior-fullstack` -> `/Users/thomashulihan/Projects/TRR/skills/senior-fullstack/SKILL.md`
- `senior-architect` -> `/Users/thomashulihan/Projects/TRR/skills/senior-architect/SKILL.md`
- `senior-devops` -> `/Users/thomashulihan/Projects/TRR/skills/senior-devops/SKILL.md`
- `senior-qa` -> `/Users/thomashulihan/Projects/TRR/skills/senior-qa/SKILL.md`
- `code-reviewer` -> `/Users/thomashulihan/Projects/TRR/skills/code-reviewer/SKILL.md`
- `skillcreator` -> `/Users/thomashulihan/Projects/TRR/skills/skillcreator/SKILL.md`
- `social-ingestion-reliability` -> `/Users/thomashulihan/Projects/TRR/skills/social-ingestion-reliability/SKILL.md`
- `senior-backend` -> `/Users/thomashulihan/Projects/TRR/TRR-Backend/skills/senior-backend/SKILL.md`
- `senior-frontend` -> `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/senior-frontend/SKILL.md`
- `figma-frontend-design-engineer` -> `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/figma-frontend-design-engineer/SKILL.md`

### Before Each Plan
Before producing any plan:
1. Review the skills available for the current scope:
   - repo-local first
   - workspace-local second
   - globally canonical `~/.codex/skills` third
   - alias or specialist skills only if no canonical owner fits cleanly
2. Choose the minimum skill set needed for the task.
3. State which skills will be used for:
   - plan writing
   - implementation
4. Invoke and follow the selected skills during plan creation and implementation routing.
5. If no repo-local skill fits, fall back to workspace-local, then globally canonical.

## MCP Invocation Matrix
Use these MCPs and invoke them as follows:

| MCP Server | Invoke When |
|---|---|
| `chrome-devtools` | Enabled for all chats. Use for all browser navigation, inspection, authenticated flows, and UI interaction in managed Chrome. |
| `figma` | Figma cloud design context, screenshots, variables, assets, and Code Connect mapping. |
| `figma-desktop` | Local desktop Figma workflows only when desktop bridge is enabled. |
| `github` | Remote repo metadata, PR/issue lookup, and GitHub-hosted MCP actions. |
| `supabase` | Supabase DB/schema operations, migrations, functions, storage, and logs. |

## External Plugin Ecosystems
Treat `~/.claude/plugins` as external plugin metadata and cache inventory only.
Do not use plugin marketplace skill lists as normative routing policy for this workspace.
Treat local legacy browser artifacts in this workspace as non-policy metadata only; policy remains Chrome DevTools MCP.

## Drift Prevention
- Canonical policy lives in `AGENTS.md` only.
- `CLAUDE.md` must remain a short pointer shim.
- `CLAUDE.md` may only point to `AGENTS.md` and remind readers that `AGENTS.md` owns handoff cadence, including continuous updates after each implemented plan or phase.
- Detailed module guidance belongs in normal docs, not in `CLAUDE.md`.
- `scripts/check-policy.sh` must enforce the pointer-only rule for nested `CLAUDE.md` files too.
- If conflict exists between files, `AGENTS.md` wins.
