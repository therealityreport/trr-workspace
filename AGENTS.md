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
- `make dev` (daily default: canonical remote-first startup for TRR-APP + TRR-Backend with Modal-backed background execution)
- `make dev-lite` (deprecated compatibility alias for `make dev`)
- `make dev-cloud` (screenalytics enabled, Docker bypass mode)
- `make dev-full` (screenalytics enabled with local Docker Redis/MinIO)
- `make status` (workspace snapshot: modes, PIDs, ports, health)
- `bash scripts/status-workspace.sh --json` (JSON status output)
- `make smoke` (startup sanity checks: pids, ports, health)
- `make check-policy` (AGENTS/CLAUDE drift rules)
- `make env-contract` (regenerate workspace env matrix doc)
- `make stop` (stop only services started by `make dev`)
- `make down` (tear down screenalytics docker compose infra; safe no-op if Docker is unavailable/stopped)
- `make stop && make down` (full cleanup)
- `make logs` (tail workspace logs)
- `make logs-prune` (archive retention pruning by age/size)
- `make test-fast`, `make test-full`, `make test-changed`
- `make mcp-aws-status` (show AWS MCP profile state)
- `make mcp-aws-on` (enable AWS MCP profile for AWS tasks)
- `make mcp-aws-off` (disable AWS MCP profile after AWS tasks)

Startup tuning:
- `PROFILE=default make dev` (load defaults from `profiles/default.env`; explicit env vars still override)
- `PROFILE=local-cloud make dev`
- `PROFILE=local-full make dev`
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
- Default Codex chat mode is `isolated + headful` — each session gets its own Chrome instance on a unique port (9333–9399), seeded from `~/.chrome-profiles/claude-agent`. No manual `make chrome-agent*` bootstrap is part of the normal workflow.
- Isolated mode prevents concurrent-session CDP target contention. Do not revert to `shared` unless you have a single active session and need the shared browser state.
- Use `isolated + headless` when you need a clean per-session browser without a visible window; set `CODEX_CHROME_ISOLATED_HEADLESS=1` before starting/restarting the Codex session.
- Use `shared + headful` only for single-session workflows where you need to share login state with a manually-managed Chrome; set `CODEX_CHROME_MODE=shared` before starting/restarting the Codex session.
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
2. Update `docs/ai/HANDOFF.md` in each touched repo.
3. If cross-repo task folder exists, keep these aligned when present:
- `PLAN.md`
- `OTHER_PROJECTS.md`
- `STATUS.md`
4. Use `scripts/new-cross-collab-task.sh` to scaffold new task docs consistently.

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
- `aws-solution-architect`: AWS-only architecture/cost/IaC tasks
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

### AWS Deploy Rule
For deployable AWS/cloud-infra/backend implementation work:
1. Trigger this rule only when the implementation changes running AWS-backed services, workers, infra config, or backend behavior that requires AWS rollout.
2. Do not trigger this rule for docs-only, tests-only, local-only, or non-deployed changes.
3. The selected implementation skills must include:
   - `senior-devops`
   - `aws-solution-architect`
4. Required checks must pass before deploy.
5. Implementation is not complete until the AWS deployment is executed successfully to the primary production target when rollout is required.
6. Handoff must record deploy evidence and post-deploy verification.

## MCP Invocation Matrix
Use these MCPs and invoke them as follows:

| MCP Server | Invoke When |
|---|---|
| `chrome-devtools` | Enabled for all chats. Use for all browser navigation, inspection, authenticated flows, and UI interaction in managed Chrome. |
| `figma` | Figma cloud design context, screenshots, variables, assets, and Code Connect mapping. |
| `figma-desktop` | Local desktop Figma workflows only when desktop bridge is enabled. |
| `github` | Remote repo metadata, PR/issue lookup, and GitHub-hosted MCP actions. |
| `supabase` | Supabase DB/schema operations, migrations, functions, storage, and logs. |
| `awslabs-core` | First step for AWS prompt understanding and intent decomposition. |
| `awslabs-aws-api` | Concrete AWS CLI execution through validated API wrapper. |
| `awslabs-aws-docs` | AWS documentation search/read when behavior is uncertain or source confirmation is needed. |
| `awslabs-pricing` | AWS pricing lookups and cost analysis flows. |
| `awslabs-cloudwatch` | CloudWatch alarms/logs/metrics analysis and incident diagnostics. |
| `awsknowledge` | AWS architecture tie-breakers and service-selection guidance. |
| `awsiac` | IaC best-practice validation and generation hardening checks. |

### AWS MCP Profile Workflow
- For AWS tasks, proactively invoke AWS MCPs in this order: `awslabs-core` -> service MCPs (`awslabs-aws-api`, `awslabs-aws-docs`, `awslabs-cloudwatch`, `awslabs-pricing`, `awsknowledge`, `awsiac`) as needed by the task.
- Before starting AWS-heavy sessions, run `make mcp-aws-on` and restart the Codex session.
- After AWS work is complete, run `make mcp-aws-off` and restart the Codex session.
- If an AWS MCP required by the task is disabled/unavailable, pause and request MCP profile enablement instead of guessing.

## External Plugin Ecosystems
Treat `~/.claude/plugins` as external plugin metadata and cache inventory only.
Do not use plugin marketplace skill lists as normative routing policy for this workspace.
Treat local legacy browser artifacts in this workspace as non-policy metadata only; policy remains Chrome DevTools MCP.

## Drift Prevention
- Canonical policy lives in `AGENTS.md` only.
- `CLAUDE.md` must remain a short pointer shim.
- Detailed module guidance belongs in normal docs, not in `CLAUDE.md`.
- `scripts/check-policy.sh` must enforce the pointer-only rule for nested `CLAUDE.md` files too.
- If conflict exists between files, `AGENTS.md` wins.
