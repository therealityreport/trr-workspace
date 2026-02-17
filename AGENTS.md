# AGENTS — TRR Workspace (Canonical Cross-Repo Rules)

This file is the canonical cross-repo operating policy for agents in this workspace.
Repo-specific rules in each repo's `AGENTS.md` and `CLAUDE.md` are mandatory and additive.

Repos in this workspace:
- `TRR-Backend/` (FastAPI + Supabase-first pipeline)
- `TRR-APP/` (Next.js + Firebase)
- `screenalytics/` (FastAPI + Streamlit + ML pipeline)

## One-Command Dev (Workspace)
Run from `/Users/thomashulihan/Projects/TRR`:
- `make bootstrap` (one-time dependency setup)
- `make dev` (run workspace services)
- `make stop` (stop only services started by `make dev`)
- `make logs` (tail workspace logs)

Default URLs:
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000` (routes under `/api/v1/*`)
- screenalytics API: `http://127.0.0.1:8001`
- screenalytics Streamlit: `http://127.0.0.1:8501`
- screenalytics Web: `http://127.0.0.1:8080`

## Start-of-Session Checklist
1. Read `/Users/thomashulihan/Projects/TRR/CLAUDE.md`.
2. Read the touched repo's `CLAUDE.md` and `AGENTS.md`.
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
- API base from `TRR_API_URL`, normalized to `/api/v1` in
  `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Do not break response shapes without same-session consumer updates in TRR-APP.

TRR-Backend <-> screenalytics:
- TRR-Backend calls screenalytics via `SCREENALYTICS_API_URL`.
- screenalytics reads TRR metadata via `TRR_DB_URL` (preferred) or `SUPABASE_DB_URL` (legacy).
- If schema/views change, update TRR-Backend first, then screenalytics.

Shared secrets:
- `TRR_INTERNAL_ADMIN_SHARED_SECRET`: shared between TRR-APP and TRR-Backend (internal admin proxy).
- `SCREENALYTICS_SERVICE_TOKEN`: service-to-service access to TRR-Backend `/api/v1/screenalytics/*`.

## Validation and Handoff (Required)
After changes:
1. Run fast checks in each touched repo.
2. Update `docs/ai/HANDOFF.md` in each touched repo.
3. If cross-repo task folder exists, keep these aligned when present:
   - `PLAN.md`
   - `OTHER_PROJECTS.md`
   - `STATUS.md`

See `docs/cross-collab/WORKFLOW.md` for lifecycle/templates.

## Skill Routing (Workspace)
Use the smallest set of skills that fully covers the task.

Installed paths:
- `/Users/thomashulihan/.codex/skills/figma-frontend-design-engineer`
- `/Users/thomashulihan/.codex/skills/senior-architect`
- `/Users/thomashulihan/.codex/skills/senior-frontend`
- `/Users/thomashulihan/.codex/skills/senior-backend`
- `/Users/thomashulihan/.codex/skills/senior-fullstack`
- `/Users/thomashulihan/.codex/skills/senior-qa`
- `/Users/thomashulihan/.codex/skills/senior-devops`
- `/Users/thomashulihan/.codex/skills/code-reviewer`
- `/Users/thomashulihan/.codex/skills/tdd-guide`
- `/Users/thomashulihan/.codex/skills/tech-stack-evaluator`
- `/Users/thomashulihan/.codex/skills/aws-solution-architect`

### Skill Triggers
- `figma-frontend-design-engineer`
  - Trigger: Figma URL/node-driven UI implementation, parity audits, and design-system mapped frontend delivery.
  - Primary repo: `TRR-APP`.
- `senior-backend`
  - Trigger: FastAPI endpoints, schema/migrations, API contracts, backend performance/security.
  - Primary repos: `TRR-Backend`, `screenalytics` API surfaces.
- `senior-frontend`
  - Trigger: Next.js App Router/UI/admin UX, bundle/perf/a11y improvements.
  - Primary repo: `TRR-APP`.
- `senior-fullstack`
  - Trigger: coordinated API+UI+data flow changes across repos.
  - Primary scope: cross-repo integration tasks.
- `senior-qa`
  - Trigger: test additions/fixes, coverage hardening, release verification.
  - Primary scope: touched repos with behavior changes.
- `code-reviewer`
  - Trigger: review requests, risk scanning, PR/file prioritization.
- `tdd-guide`
  - Trigger: test-first implementation, red-green-refactor workflow.
- `senior-devops`
  - Trigger: CI pipelines, deployment readiness, Terraform/module checks.
- `senior-architect`
  - Trigger: architecture decisions, dependency/layer analysis, ADR support, baseline-vs-current diffing.
- `tech-stack-evaluator`
  - Trigger: stack/tool comparisons, TCO, migration risk/effort analysis.
- `aws-solution-architect`
  - Trigger: AWS-specific architecture/IaC/cost optimization only.

### Skill Sequencing by Task Type
- Backend-first cross-repo feature:
  1. `senior-architect` (if design/contract tradeoff)
  2. `senior-backend`
  3. `senior-fullstack` (if integration implications)
  4. `senior-frontend`
  5. `senior-qa`
- Review/refactor request:
  1. `code-reviewer`
  2. `tdd-guide` (if implementing fixes test-first)
  3. `senior-qa`
- Release/deployment hardening:
  1. `senior-devops`
  2. `senior-qa`
  3. `aws-solution-architect` only if AWS is in scope.
- Figma-driven UI implementation:
  1. `figma-frontend-design-engineer`
  2. `senior-qa`
  3. `code-reviewer`

### Guardrails
- Prefer `figma-frontend-design-engineer` over separate Figma/frontend skills when a concrete Figma source is provided.
- Do not use `aws-solution-architect` for non-AWS deployments unless AWS migration/options are explicitly requested.
- Do not use `tech-stack-evaluator` for routine implementation tasks when stack choice is already fixed by repo conventions.
- Do not violate cross-repo order: backend contract/schema first, downstream consumers second, UI last.
