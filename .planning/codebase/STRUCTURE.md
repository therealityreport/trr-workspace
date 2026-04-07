# TRR Workspace Structure

## Scope

This document maps the visible directory layout and the main places where work tends to land across the TRR workspace.

Primary roots:

- `TRR-Backend/`
- `TRR-APP/`
- `screenalytics/`
- `docs/`
- `scripts/`
- `.planning/`

## Workspace Root Layout

### Coordination and Policy

- Cross-repo policy: `AGENTS.md`
- Workspace orchestration: `Makefile`
- Shared docs: `docs/workspace/`, `docs/cross-collab/`, `docs/ai/`
- Shared scripts: `scripts/`
- Planning artifacts: `.planning/`

The root is not just a container directory. It carries shared workflow, environment, browser, and handoff behavior that the child repos depend on.

## `TRR-Backend/` Layout

### Top-Level Purpose

- `api/` - FastAPI app, auth, dependencies, realtime support, route modules
- `trr_backend/` - domain logic, repositories, integrations, jobs, media/storage helpers
- `supabase/` - config and migration history
- `tests/` - pytest suites
- `scripts/` - repo-local operational helpers

### Key Subtrees

- API entrypoint: `TRR-Backend/api/main.py`
- Dependency/auth helpers: `TRR-Backend/api/deps.py`, `TRR-Backend/api/auth.py`
- Router directory: `TRR-Backend/api/routers/`
- Realtime support: `TRR-Backend/api/realtime/`
- DB code: `TRR-Backend/trr_backend/db/`
- Media/storage code: `TRR-Backend/trr_backend/media/`
- External integrations: `TRR-Backend/trr_backend/integrations/`
- Social ingestion and refresh code: `TRR-Backend/trr_backend/socials/`
- Modal job plane: `TRR-Backend/trr_backend/modal_jobs.py`, `TRR-Backend/trr_backend/modal_dispatch.py`
- Supabase migrations: `TRR-Backend/supabase/migrations/`

### Structure Observations

- Feature modules are long-lived and colocate route handlers with domain-specific behavior
- `api/routers/` contains both public and admin surfaces
- `trr_backend/` is the real application core; `api/` is mostly boundary and transport
- Migration history is extensive and sequential, indicating schema-first evolution over time

## `TRR-APP/` Layout

### Top-Level Purpose

- `apps/web/` - primary Next.js web app
- `apps/vue-wordle/` - smaller Vue/Vite app
- `docs/` - repo-local plans and documentation
- `scripts/` - repo-local helper commands
- `.github/workflows/` - CI and validation

### `apps/web/` Key Layout

- Route tree: `TRR-APP/apps/web/src/app/`
- Shared components: `TRR-APP/apps/web/src/components/`
- Server-only logic: `TRR-APP/apps/web/src/lib/server/`
- General client/shared logic: `TRR-APP/apps/web/src/lib/`
- Tests: `TRR-APP/apps/web/tests/`
- Build/runtime config: `TRR-APP/apps/web/next.config.ts`, `TRR-APP/apps/web/vitest.config.ts`, `TRR-APP/apps/web/playwright.config.ts`

### Important Route Clusters

- Admin UI: `TRR-APP/apps/web/src/app/admin/`
- App-side admin proxy routes: `TRR-APP/apps/web/src/app/api/admin/trr-api/`
- Public show routes: `TRR-APP/apps/web/src/app/[showId]/`, `TRR-APP/apps/web/src/app/shows/`
- Survey routes: `TRR-APP/apps/web/src/app/surveys/`
- Design docs/admin reference surfaces: `TRR-APP/apps/web/src/app/admin/design-docs/`, `TRR-APP/apps/web/src/app/design-system/`

### Structure Observations

- `src/app/` is very large and route-oriented
- Admin and public surfaces coexist in one App Router tree
- Server logic is intentionally separated under `src/lib/server/`
- Tests sit close to app concerns but live in a dedicated `tests/` root rather than colocated next to source files

## `screenalytics/` Layout

### Top-Level Purpose

- `apps/api/` - FastAPI API
- `apps/workspace-ui/` - Streamlit operator UI
- `packages/py-screenalytics/` - reusable package code
- `config/pipeline/` - pipeline stage and performance configs
- `tests/` - extensive pytest coverage across API, ML, audio, integration, and tooling
- `tools/` - helper scripts and standalone commands

### `apps/api/` Key Layout

- API entrypoint: `screenalytics/apps/api/main.py`
- Routers: `screenalytics/apps/api/routers/`
- Schemas: `screenalytics/apps/api/schemas/`
- Services: `screenalytics/apps/api/services/`
- Optional Celery worker: `screenalytics/apps/api/celery_app.py`

### `apps/workspace-ui/` Key Layout

- Streamlit shell: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Multipage screens: `screenalytics/apps/workspace-ui/pages/`
- Shared UI helpers/components: `screenalytics/apps/workspace-ui/components/`
- UI-specific tests: `screenalytics/apps/workspace-ui/tests/`

### Package and Config Layout

- Installable package source: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Pipeline configs: `screenalytics/config/pipeline/`
- Infra compose fallback: `screenalytics/infra/docker/compose.yaml`

### Structure Observations

- This repo is a mixed API + ML + operator-UI codebase
- `apps/api/services/` is the main coordination layer
- Package code under `packages/py-screenalytics/` appears to hold reusable pipeline primitives
- Tests are partitioned by concern rather than only by source directory

## Shared Docs and Script Structure

### `docs/`

Useful workspace anchors:

- Env contract: `docs/workspace/env-contract.md`
- Workspace commands: `docs/workspace/dev-commands.md`
- Chrome/browser policy: `docs/workspace/chrome-devtools.md`
- Shared workflow: `docs/cross-collab/WORKFLOW.md`
- Handoff guidance: `docs/ai/HANDOFF_WORKFLOW.md`

### `scripts/`

The workspace script directory centralizes cross-repo operations such as:

- dev startup and health checks
- environment synthesis and contract checking
- browser orchestration and managed Chrome wrappers
- MCP session helpers

Examples:

- `scripts/dev-workspace.sh`
- `scripts/preflight.sh`
- `scripts/status-workspace.sh`
- `scripts/check-workspace-contract.sh`
- `scripts/codex-chrome-devtools-mcp.sh`

## Naming and Layout Patterns

Observed patterns:

- Python repos prefer explicit domain folders like `routers/`, `services/`, `repositories/`, `integrations/`
- Next.js routes follow App Router naming with `page.tsx`, `layout.tsx`, and nested dynamic segments
- Admin surfaces are grouped under `/admin` consistently in both route names and backend API prefixes
- Test file names are descriptive and end with `.test.ts`, `.test.tsx`, or `test_*.py`
- Generated or machine-oriented artifacts are often kept under `docs/`, `artifacts/`, or `.planning/` rather than mixed into source trees

## Where To Look First

For common task types:

- Shared contract or schema issue: `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/migrations/`
- Admin UI or route issue: `TRR-APP/apps/web/src/app/admin/`, `TRR-APP/apps/web/src/app/api/admin/trr-api/`, `TRR-APP/apps/web/src/lib/server/`
- Screenalytics API or pipeline issue: `screenalytics/apps/api/routers/`, `screenalytics/apps/api/services/`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Workspace startup/env/browser issue: `Makefile`, `scripts/`, `docs/workspace/`

## Structure Read

The workspace structure is organized around operational ownership more than strict layering:

- backend core behavior in `TRR-Backend`
- UI and app-server mediation in `TRR-APP`
- heavy pipeline and review tooling in `screenalytics`
- shared coordination at the workspace root

That structure makes repo ownership clear, but it also means cross-repo changes require careful navigation of root-level docs and scripts in addition to repo-local code.
