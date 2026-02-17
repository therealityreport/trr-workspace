# TRR Workspace — Claude/Codex Playbook

Canonical workspace policy: `/Users/thomashulihan/Projects/TRR/AGENTS.md`.
Use this file as the fast execution playbook; when in doubt, follow `AGENTS.md`.

## Start-of-Session Checklist
1. Read this file and `/Users/thomashulihan/Projects/TRR/AGENTS.md`.
2. Read touched repo `CLAUDE.md` and `AGENTS.md`.
3. Check cross-collab task folders in touched repos before implementation.

## Quickstart
From `/Users/thomashulihan/Projects/TRR`:
```bash
make bootstrap
make dev
```

Stop services started by workspace dev mode:
```bash
make stop
```

Tail logs:
```bash
make logs
```

## Default URLs
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000` (routes under `/api/v1/*`)
- screenalytics API: `http://127.0.0.1:8001`
- screenalytics Streamlit: `http://127.0.0.1:8501`
- screenalytics Web: `http://127.0.0.1:8080`

## Mandatory Workflow
1. Follow fixed implementation order:
   - `TRR-Backend` first (schema/API contract)
   - `screenalytics` second (consumers/writers)
   - `TRR-APP` last (UI/admin)
2. Keep shared contracts aligned in same session.
3. Run fast checks in each touched repo.
4. Update `docs/ai/HANDOFF.md` in each touched repo.
5. If cross-collab task folders are in scope, keep `PLAN.md`, `OTHER_PROJECTS.md`, and `STATUS.md` aligned.

## Integration Contracts (Quick Reference)
- TRR-APP -> TRR-Backend API base: `TRR_API_URL`, normalized to `/api/v1` in
  `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- TRR-Backend -> screenalytics URL: `SCREENALYTICS_API_URL`.
- screenalytics DB metadata: `TRR_DB_URL` preferred, `SUPABASE_DB_URL` legacy.
- Shared auth/service secrets:
  - `TRR_INTERNAL_ADMIN_SHARED_SECRET`
  - `SCREENALYTICS_SERVICE_TOKEN`

## Skill Activation (Workspace)
Use skills intentionally by task signal.

- `figma-frontend-design-engineer`: Figma MCP-driven design-to-code implementation with frontend quality gates.
- `senior-backend`: backend routes, schema/migrations, API contract work.
- `senior-frontend`: TRR-APP UI/admin/App Router/perf/a11y.
- `senior-fullstack`: cross-repo integration changes spanning API + UI.
- `senior-qa`: tests, coverage, release verification.
- `code-reviewer`: review/risk scans and prioritized findings.
- `tdd-guide`: test-first/red-green-refactor flows.
- `senior-devops`: CI/deploy readiness/Terraform workflows.
- `senior-architect`: architecture decisions and system-level tradeoffs.
- `tech-stack-evaluator`: stack/tool comparisons, TCO, migration analysis.
- `aws-solution-architect`: AWS-only architecture/IaC/cost tasks.

Skill guardrails:
- Use smallest sufficient skill set.
- Prefer `figma-frontend-design-engineer` when a Figma URL/node is part of the request.
- Do not use AWS skill unless AWS is explicitly in scope.
- Do not run stack evaluator for routine implementation where stack is already fixed.

## Multi-Repo Session Command
```bash
claude --add-dir TRR-Backend --add-dir TRR-APP --add-dir screenalytics
```

If supported by your tool:
```bash
export CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1
```

## Session Continuity
Before ending session:
1. Ensure `docs/ai/HANDOFF.md` is updated in each touched repo.
2. Include commands, key results, files changed, and open blockers.

## Repo Pointers
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/CLAUDE.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/AGENTS.md`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/CLAUDE.md`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/AGENTS.md`
- `/Users/thomashulihan/Projects/TRR/screenalytics/CLAUDE.md`
- `/Users/thomashulihan/Projects/TRR/screenalytics/AGENTS.md`
