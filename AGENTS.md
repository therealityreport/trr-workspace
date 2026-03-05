# AGENTS — TRR Workspace (Canonical Cross-Repo Rules)

This file is the canonical cross-repo operating policy for agents in this workspace.
`CLAUDE.md` files are pointer shims only.

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
- `make dev` (daily default: laptop-safe `local-lite` profile with remote-enforced long jobs)
- `make dev-lite` (TRR-APP + TRR-Backend only; screenalytics disabled)
- `make dev-cloud` (screenalytics enabled, Docker bypass mode)
- `make dev-full` (screenalytics enabled with local Docker Redis/MinIO)
- `make status` (workspace snapshot: modes, PIDs, ports, health)
- `make status` / `bash scripts/status-workspace.sh --json` (human or JSON status output)
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
- `PROFILE=local-lite make dev` (load defaults from `profiles/local-lite.env`; explicit env vars still override)
- `PROFILE=local-cloud make dev`
- `PROFILE=local-full make dev`
- `WORKSPACE_CLEAN_NEXT_CACHE=1 make dev` (force clean Next.js rebuild; default is cache reuse)
- `WORKSPACE_OPEN_BROWSER=0 make dev` (skip browser tab refresh/open)
- `WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=0 WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=0 make dev` (opt out of mirror worker stages when local worker pool is enabled)
- `WORKSPACE_BROWSER_TAB_SYNC_MODE=reuse_no_reload make dev` (default; reuse/focus matching tabs without reload)
- `WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_first make dev` (reload only first matching tab)
- `WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_all make dev` (reload all matching tabs)
- `WORKSPACE_TRR_JOB_PLANE_MODE=local make dev` (opt in to local API-owned long-job execution)
- `WORKSPACE_TRR_JOB_PLANE_MODE=remote WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1 make dev` (remote worker-owned long jobs)
- `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=1 make dev` (start admin/reddit/google-news remote worker loops locally)
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
All web browsing MUST use agent-managed Chrome through `scripts/codex-chrome-devtools-mcp.sh`.
Do not launch ad-hoc browsers outside this management flow.

Commands:
- `make chrome-agent`
- `make chrome-agent-stop`
- `make chrome-agent-stop-all`
- `make chrome-agent-status`
- `make chrome-agent-seed-sync`
- `curl http://localhost:9222/json/version`

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

## Skill Routing (Codex-Only)
Only reference Codex-installed skills as normative policy.
Full registry: `/Users/thomashulihan/Projects/TRR/docs/agent-governance/codex_skills.md`

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

## MCP Invocation Matrix
Use these MCPs and invoke them as follows:

| MCP Server | Invoke When |
|---|---|
| `chrome-devtools` | Any web browsing, authenticated social platform flows, browser inspection, and UI interaction in managed Chrome. |
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
- If conflict exists between files, `AGENTS.md` wins.
