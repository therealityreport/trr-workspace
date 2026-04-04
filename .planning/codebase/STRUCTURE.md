# Codebase Structure

**Analysis Date:** 2026-04-04

## Directory Layout

```text
TRR/
├── Makefile                    # Workspace entrypoint for dev, preflight, tests, and shared ops
├── AGENTS.md                   # Cross-repo workspace policy and contract order
├── scripts/                    # Shared orchestration, browser/MCP wrappers, policy checks, handoff sync
├── docs/                       # Workspace-level workflow, env, handoff, and governance docs
├── profiles/                   # Workspace startup profiles loaded by `scripts/dev-workspace.sh`
├── TRR-APP/                    # Next.js frontend + BFF repo
├── TRR-Backend/                # FastAPI + Supabase-backed backend repo
├── screenalytics/              # FastAPI + Streamlit + pipeline repo
└── .planning/codebase/         # Generated mapper outputs for future planning/execution
```

## Directory Purposes

**Workspace Root (`/Users/thomashulihan/Projects/TRR`):**
- Purpose: Coordinate the three active repos and hold shared policy, scripts, and generated docs.
- Contains: `Makefile`, `AGENTS.md`, `docs/`, `scripts/`, `profiles/`, `.planning/`.
- Key files: `Makefile`, `AGENTS.md`, `docs/cross-collab/WORKFLOW.md`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`.

**`scripts/`:**
- Purpose: Shared automation for startup, preflight, health checks, browser automation, policy checks, and handoff generation.
- Contains: bash/python scripts plus helper libraries under `scripts/lib/`.
- Key files: `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/status-workspace.sh`, `scripts/check-policy.sh`, `scripts/sync-handoffs.py`, `scripts/codex-chrome-devtools-mcp.sh`.

**`docs/`:**
- Purpose: Store workspace-wide operational contracts and process documentation.
- Contains: `docs/workspace/`, `docs/cross-collab/`, `docs/agent-governance/`, `docs/ai/`.
- Key files: `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/cross-collab/WORKFLOW.md`.

**`TRR-APP/`:**
- Purpose: Host the Next.js application and its BFF/proxy logic.
- Contains: monorepo metadata, `apps/web/`, `apps/vue-wordle/`, repo-local docs and scripts.
- Key files: `TRR-APP/package.json`, `TRR-APP/pnpm-workspace.yaml`, `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/next.config.ts`, `TRR-APP/apps/web/tsconfig.json`.

**`TRR-APP/apps/web/src/app/`:**
- Purpose: File-system routed pages, layouts, and route handlers for the main app.
- Contains: public routes, admin routes, auth routes, and `/api` handlers.
- Key files: `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/src/app/page.tsx`, `TRR-APP/apps/web/src/app/api/**/route.ts`, `TRR-APP/apps/web/src/app/admin/**/page.tsx`.

**`TRR-APP/apps/web/src/lib/server/`:**
- Purpose: Server-only code for backend access, admin proxies, auth, and repositories.
- Contains: `trr-api/`, `admin/`, `surveys/`, `shows/`, validation and DB helpers.
- Key files: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-APP/apps/web/src/lib/server/admin/*.ts`.

**`TRR-Backend/`:**
- Purpose: Host the canonical TRR API, domain repositories/services, and database migrations/schema docs.
- Contains: `api/`, `trr_backend/`, `supabase/`, `tests/`, repo scripts/docs.
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/*.py`, `TRR-Backend/trr_backend/db/*.py`, `TRR-Backend/supabase/migrations/`.

**`TRR-Backend/api/`:**
- Purpose: HTTP boundary for the backend.
- Contains: FastAPI entrypoint, auth dependencies, realtime helpers, and router modules.
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/api/routers/screenalytics.py`, `TRR-Backend/api/routers/screenalytics_runs_v2.py`.

**`TRR-Backend/trr_backend/`:**
- Purpose: Internal backend library for persistence, services, integrations, security, and media/social runtimes.
- Contains: `db/`, `repositories/`, `services/`, `clients/`, `security/`, `socials/`, `integrations/`.
- Key files: `TRR-Backend/trr_backend/db/session.py`, `TRR-Backend/trr_backend/repositories/*.py`, `TRR-Backend/trr_backend/clients/screenalytics.py`.

**`TRR-Backend/supabase/`:**
- Purpose: Database-source-of-truth artifacts for backend-owned schema.
- Contains: SQL migrations, generated schema docs, branch/temp metadata.
- Key files: `TRR-Backend/supabase/migrations/*`, `TRR-Backend/supabase/schema_docs/`.

**`screenalytics/`:**
- Purpose: Host Screenalytics API, operator UI, processing package, configs, tools, and tests.
- Contains: `apps/`, `packages/py-screenalytics/`, `config/`, `tools/`, `tests/`, `FEATURES/`.
- Key files: `screenalytics/pyproject.toml`, `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/`.

**`screenalytics/apps/api/`:**
- Purpose: API boundary, job/task definitions, and service layer for Screenalytics.
- Contains: router modules, service modules, Celery setup, API schemas, config helpers.
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/*.py`, `screenalytics/apps/api/services/*.py`, `screenalytics/apps/api/tasks.py`, `screenalytics/apps/api/tasks_v2.py`.

**`screenalytics/apps/workspace-ui/`:**
- Purpose: Streamlit operator workspace.
- Contains: `streamlit_app.py`, numbered `pages/`, reusable components, session/UI helpers.
- Key files: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/0_Upload_Video.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/pages/4_Cast.py`.

**`screenalytics/packages/py-screenalytics/src/py_screenalytics/`:**
- Purpose: Reusable Python package for processing stages, artifact contracts, run layout, audio, reporting, and workspace support logic.
- Contains: subpackages for `audio/`, `pipeline/`, `reporting/`, `schemas/`, `workspace_ui/`, and core modules such as `run_layout.py` and `pipeline_stages.py`.
- Key files: `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/episode_audio_pipeline.py`.

## Key File Locations

**Entry Points:**
- `Makefile`: Workspace command surface.
- `scripts/dev-workspace.sh`: Workspace process orchestrator.
- `TRR-APP/apps/web/src/app/layout.tsx`: Global Next.js layout entry.
- `TRR-APP/apps/web/src/app/page.tsx`: Main landing page entry.
- `TRR-Backend/api/main.py`: FastAPI app entry for TRR backend.
- `screenalytics/apps/api/main.py`: FastAPI app entry for Screenalytics API.
- `screenalytics/apps/workspace-ui/streamlit_app.py`: Streamlit workspace entry.

**Configuration:**
- `docs/workspace/env-contract.md`: Generated workspace env contract.
- `profiles/*.env`: Workspace runtime profiles loaded by root scripts.
- `TRR-APP/apps/web/next.config.ts`: Next.js build/dev routing config.
- `TRR-APP/apps/web/tsconfig.json`: TypeScript alias/base config.
- `TRR-Backend/supabase/migrations/`: Backend schema evolution.
- `screenalytics/config/pipeline/*.yaml`: Pipeline defaults and stage configuration.
- `screenalytics/pyproject.toml`: Ruff/Black/Pytest config for Screenalytics.

**Core Logic:**
- `TRR-APP/apps/web/src/lib/server/trr-api/`: App-to-backend bridge and caches.
- `TRR-APP/apps/web/src/lib/server/admin/`: App-side admin repositories and utilities.
- `TRR-Backend/trr_backend/repositories/`: Backend persistence layer.
- `TRR-Backend/trr_backend/services/`: Backend feature services.
- `screenalytics/apps/api/services/`: Screenalytics service layer.
- `screenalytics/packages/py-screenalytics/src/py_screenalytics/`: Shared processing/runtime package.

**Testing:**
- `TRR-APP/apps/web/tests/` and config files such as `TRR-APP/apps/web/vitest.config.ts` and `TRR-APP/apps/web/playwright.config.ts`.
- `TRR-Backend/tests/`: backend API, DB, service, integration, and migration tests.
- `screenalytics/tests/`: API, unit, integration, ML, UI, and helper tests.

## Naming Conventions

**Files:**
- Next App Router route segments use framework naming in `TRR-APP/apps/web/src/app/`: `page.tsx`, `layout.tsx`, `route.ts`, `loading.tsx`, `error.tsx`.
- Dynamic route folders in `TRR-APP/apps/web/src/app/` use bracket syntax such as `[showId]`, `[personId]`, and `[[...rest]]`.
- Season-specific route folders encode the season in the directory name, for example `TRR-APP/apps/web/src/app/[showId]/s[seasonNumber]/`.
- TypeScript utility/repository files use kebab-case or descriptive lower-case names, for example `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`.
- Python backend and Screenalytics modules use snake_case, for example `TRR-Backend/api/routers/admin_show_reads.py` and `screenalytics/apps/api/services/run_state.py`.
- Streamlit pages are numbered with a leading ordinal to control nav order, for example `screenalytics/apps/workspace-ui/pages/0_Upload_Video.py` and `screenalytics/apps/workspace-ui/pages/4_Screentime.py`.

**Directories:**
- Repo roots use product/repo names: `TRR-APP/`, `TRR-Backend/`, `screenalytics/`.
- Backend HTTP boundary is always under `api/`; backend internal library code is under `trr_backend/`.
- Screenalytics splits runtime surfaces under `apps/` and reusable package code under `packages/py-screenalytics/src/py_screenalytics/`.
- Shared workspace automation stays at the root in `scripts/` and `docs/`, not inside repo-local folders.

## Where to Add New Code

**New TRR Public or Admin Page:**
- Primary code: `TRR-APP/apps/web/src/app/` in the matching route subtree.
- Shared UI pieces: `TRR-APP/apps/web/src/components/` or `TRR-APP/apps/web/src/components/admin/`.
- Server-side data access: `TRR-APP/apps/web/src/lib/server/` or `TRR-APP/apps/web/src/app/api/**/route.ts`.
- Tests: co-locate app tests under `TRR-APP/apps/web/tests/` or route/component-specific test files per repo convention.

**New TRR Backend Endpoint:**
- Router: `TRR-Backend/api/routers/`.
- Auth/dependency wiring: `TRR-Backend/api/auth.py`, `TRR-Backend/api/deps.py`, or `TRR-Backend/api/screenalytics_auth.py` when relevant.
- Persistence/service code: `TRR-Backend/trr_backend/repositories/` and `TRR-Backend/trr_backend/services/`.
- Schema changes: add a new file in `TRR-Backend/supabase/migrations/`; do not edit existing migrations.
- Tests: `TRR-Backend/tests/api/` plus any matching repository/service test directory.

**New Screenalytics API Capability:**
- Router: `screenalytics/apps/api/routers/`.
- Business logic: `screenalytics/apps/api/services/`.
- Job/task wiring: `screenalytics/apps/api/tasks*.py` or `screenalytics/apps/api/services/pipeline_orchestration.py`.
- Shared package logic: `screenalytics/packages/py-screenalytics/src/py_screenalytics/` if the code should be reusable by tools/tests/API.
- Tests: `screenalytics/tests/api/`, `screenalytics/tests/unit/`, or `screenalytics/tests/integration/` depending on scope.

**New Screenalytics Pipeline Stage or Artifact Contract:**
- Implementation: `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline/` or another focused package subdirectory.
- Stage naming/ordering: `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`.
- Config: `screenalytics/config/pipeline/*.yaml`.
- Tooling/CLI entrypoints: `screenalytics/tools/`.

**New Screenalytics Streamlit Page or Operator Tool:**
- Page module: `screenalytics/apps/workspace-ui/pages/`.
- Shared component/helper: `screenalytics/apps/workspace-ui/components/` or `screenalytics/apps/workspace-ui/*.py`.
- Reusable status logic: `screenalytics/packages/py-screenalytics/src/py_screenalytics/workspace_ui/`.

**Workspace-Level Automation or Policy:**
- Scripts: `scripts/`.
- Shared docs/contracts: `docs/workspace/`, `docs/cross-collab/`, or `AGENTS.md`.
- Generated planning artifacts: `.planning/`.

**Utilities:**
- TRR app shared TS helpers: `TRR-APP/apps/web/src/lib/`.
- Backend shared Python helpers: `TRR-Backend/trr_backend/utils/`.
- Screenalytics shared API helpers: `screenalytics/apps/api/services/` if API-owned, or `screenalytics/packages/py-screenalytics/src/py_screenalytics/` if reusable outside the API.

## Special Directories

**`.planning/codebase/`:**
- Purpose: Generated codebase maps for planning/execution agents.
- Generated: Yes.
- Committed: Yes, when the workflow expects updated mapper outputs.

**`docs/ai/`:**
- Purpose: Canonical status sources and generated handoff outputs referenced by the workspace workflow.
- Generated: Mixed; `HANDOFF.md` is generated while `local-status/*.md` is canonical.
- Committed: Yes.

**`TRR-Backend/supabase/schema_docs/`:**
- Purpose: Generated schema documentation tied to backend migrations.
- Generated: Yes.
- Committed: Yes.

**`screenalytics/config/pipeline/`:**
- Purpose: Declarative processing defaults for Screenalytics stages.
- Generated: No.
- Committed: Yes.

**`screenalytics/packages/py-screenalytics/src/py_screenalytics/`:**
- Purpose: Packaged runtime library imported by API services, tools, and tests.
- Generated: No.
- Committed: Yes.

**`apps/web/` at workspace root:**
- Purpose: Placeholder/non-runtime directory in the current workspace; the active Next.js app lives in `TRR-APP/apps/web/`.
- Generated: No.
- Committed: Yes.

---

*Structure analysis: 2026-04-04*
