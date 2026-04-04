# Codebase Structure

**Analysis Date:** 2026-04-04

## Directory Layout

```text
TRR/
├── Makefile                       # Workspace startup, preflight, tests, status, cleanup
├── AGENTS.md                      # Cross-repo policy and implementation order
├── scripts/                       # Shared orchestration, browser/MCP wrappers, checks, handoffs
├── docs/                          # Workspace workflow, env, governance, and handoff docs
├── profiles/                      # Workspace runtime profiles consumed by `scripts/dev-workspace.sh`
├── .planning/codebase/            # Generated mapper docs consumed by later GSD phases
├── TRR-APP/                       # Next.js application repo
│   ├── apps/web/                  # Main Next.js App Router app
│   ├── apps/vue-wordle/           # Secondary Vue app
│   ├── docs/                      # Repo-local architecture and cross-collab docs
│   └── scripts/                   # Repo-local app automation
├── TRR-Backend/                   # FastAPI + shared backend library + Supabase migrations
│   ├── api/                       # FastAPI entrypoint, auth, routers, realtime
│   ├── trr_backend/               # Shared backend library modules
│   ├── supabase/                  # Migrations and schema docs
│   ├── scripts/                   # Sync, import, verify, ops, and worker scripts
│   └── tests/                     # Backend test suites
└── screenalytics/                 # FastAPI + Streamlit + pipeline repo
    ├── apps/api/                  # Screenalytics API
    ├── apps/workspace-ui/         # Streamlit workspace UI
    ├── packages/py-screenalytics/ # Reusable Python package
    ├── config/                    # Pipeline and runtime config
    ├── tools/                     # CLI tools and helpers
    ├── web/                       # Optional Next.js UI
    ├── docs/                      # Canonical Screenalytics docs
    └── tests/                     # Screenalytics test suites
```

## Directory Purposes

**Workspace Root:**
- Purpose: Coordinate repo startup, policy, workflow, and shared validation.
- Contains: `Makefile`, `AGENTS.md`, `scripts/`, `docs/`, `profiles/`, `.planning/`.
- Key files: `Makefile`, `AGENTS.md`, `docs/workspace/dev-commands.md`, `docs/cross-collab/WORKFLOW.md`, `scripts/dev-workspace.sh`.

**`scripts/`:**
- Purpose: Hold workspace-level automation that spans multiple repos.
- Contains: startup/preflight scripts, browser helpers, MCP wrappers, policy checks, env-contract generation, handoff sync, smoke/test wrappers.
- Key files: `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/status-workspace.sh`, `scripts/check-policy.sh`, `scripts/workspace-env-contract.sh`, `scripts/sync-handoffs.py`, `scripts/codex-chrome-devtools-mcp.sh`.

**`docs/`:**
- Purpose: Hold workspace-level operating contracts and process docs.
- Contains: `docs/workspace/`, `docs/cross-collab/`, `docs/agent-governance/`, `docs/ai/`, `docs/diagrams/`.
- Key files: `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/workspace/chrome-devtools.md`, `docs/cross-collab/WORKFLOW.md`.

**`profiles/`:**
- Purpose: Define workspace startup profiles for cloud-first and local-docker modes.
- Contains: env profile files loaded by workspace scripts.
- Key files: `profiles/default.env`, `profiles/local-docker.env`, `profiles/local-cloud.env`.

**`.planning/codebase/`:**
- Purpose: Store generated codebase reference docs for planning and execution agents.
- Contains: `ARCHITECTURE.md`, `STRUCTURE.md`, `STACK.md`, `INTEGRATIONS.md`, `CONVENTIONS.md`, `TESTING.md`, `CONCERNS.md`.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`.

**`TRR-APP/`:**
- Purpose: Hold the app repo for public/admin UI and BFF logic.
- Contains: `apps/web/`, `apps/vue-wordle/`, repo docs, repo scripts, repo Makefile.
- Key files: `TRR-APP/AGENTS.md`, `TRR-APP/package.json`, `TRR-APP/pnpm-workspace.yaml`, `TRR-APP/Makefile`.

**`TRR-APP/apps/web/`:**
- Purpose: Main Next.js App Router application.
- Contains: `src/app/`, `src/components/`, `src/lib/`, `next.config.ts`, `package.json`, `tsconfig.json`.
- Key files: `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/src/app/page.tsx`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`.

**`TRR-APP/apps/web/src/app/`:**
- Purpose: File-system routed pages, layouts, and API handlers.
- Contains: public routes, admin routes, auth routes, dynamic show/person routes, cron hooks, and API route handlers.
- Key files: `TRR-APP/apps/web/src/app/page.tsx`, `TRR-APP/apps/web/src/app/admin/**/page.tsx`, `TRR-APP/apps/web/src/app/api/**/route.ts`, `TRR-APP/apps/web/src/app/auth/**/page.tsx`.

**`TRR-APP/apps/web/src/components/`:**
- Purpose: Shared React UI components.
- Contains: public components, admin components, survey inputs, typography/runtime helpers, minimal UI primitives.
- Key files: `TRR-APP/apps/web/src/components/admin/`, `TRR-APP/apps/web/src/components/survey/`, `TRR-APP/apps/web/src/components/ui/`.

**`TRR-APP/apps/web/src/lib/server/`:**
- Purpose: Server-only repositories, auth utilities, backend proxies, and DB helpers.
- Contains: `admin/`, `shows/`, `surveys/`, `trr-api/`, validation, postgres helpers.
- Key files: `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-APP/apps/web/src/lib/server/postgres.ts`.

**`TRR-Backend/`:**
- Purpose: Hold the canonical backend repo for API, schema, integrations, and batch scripts.
- Contains: `api/`, `trr_backend/`, `supabase/`, `scripts/`, `tests/`, repo docs.
- Key files: `TRR-Backend/AGENTS.md`, `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/db/connection.py`, `TRR-Backend/supabase/migrations/`.

**`TRR-Backend/api/`:**
- Purpose: Define the backend HTTP boundary.
- Contains: FastAPI entrypoint, auth/deps modules, realtime broker helpers, and routers.
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/api/auth.py`, `TRR-Backend/api/deps.py`, `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/api/routers/*.py`.

**`TRR-Backend/trr_backend/`:**
- Purpose: Hold reusable backend-internal library code outside router modules.
- Contains: `db/`, `repositories/`, `services/`, `clients/`, `security/`, `pipeline/`, `integrations/`, `socials/`, `media/`.
- Key files: `TRR-Backend/trr_backend/db/session.py`, `TRR-Backend/trr_backend/db/pg.py`, `TRR-Backend/trr_backend/repositories/`, `TRR-Backend/trr_backend/pipeline/orchestrator.py`.

**`TRR-Backend/supabase/`:**
- Purpose: Hold backend-owned database artifacts.
- Contains: `migrations/`, `schema_docs/`, branch/temp metadata.
- Key files: `TRR-Backend/supabase/migrations/*`, `TRR-Backend/supabase/schema_docs/`.

**`TRR-Backend/scripts/`:**
- Purpose: Hold backend operational and ingestion scripts.
- Contains: `sync/`, `backfill/`, `verify/`, `ops/`, `workers/`, `supabase/`, `socials/`, `media/`.
- Key files: `TRR-Backend/scripts/sync/`, `TRR-Backend/scripts/backfill/`, `TRR-Backend/scripts/verify/`.

**`screenalytics/`:**
- Purpose: Hold the Screenalytics subsystem: API, operator UI, reusable package, configs, tools, and tests.
- Contains: `apps/`, `packages/`, `config/`, `tools/`, `web/`, `docs/`, `tests/`, `FEATURES/`.
- Key files: `screenalytics/AGENTS.md`, `screenalytics/pyproject.toml`, `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/packages/py-screenalytics/`.

**`screenalytics/apps/api/`:**
- Purpose: Define Screenalytics HTTP routes, API-facing services, and job/task adapters.
- Contains: `routers/`, `services/`, `schemas/`, `config/`, `tasks.py`, `tasks_v2.py`, `celery_app.py`.
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/runs_v2.py`, `screenalytics/apps/api/services/pipeline_orchestration.py`, `screenalytics/apps/api/services/trr_ingest.py`.

**`screenalytics/apps/workspace-ui/`:**
- Purpose: Hold the Streamlit operator workspace.
- Contains: `streamlit_app.py`, `pages/`, `components/`, UI/session helpers, workspace-specific tests.
- Key files: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/0_Upload_Video.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/pages/3_Faces_Review.py`.

**`screenalytics/packages/py-screenalytics/src/py_screenalytics/`:**
- Purpose: Hold reusable Screenalytics runtime code.
- Contains: pipeline stages, artifact contracts, audio modules, reporting, config resolution, run-state helpers, workspace-ui helpers.
- Key files: `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/artifacts.py`.

**`screenalytics/config/`:**
- Purpose: Hold Screenalytics runtime and pipeline configuration.
- Contains: `config/pipeline/`, `config/env/`, model/config subsets.
- Key files: `screenalytics/config/pipeline/detection.yaml`, `screenalytics/config/pipeline/tracking.yaml`, `screenalytics/config/pipeline/clustering.yaml`, `screenalytics/config/pipeline/performance_profiles.yaml`.

**`screenalytics/tools/`:**
- Purpose: Hold ad hoc and operator-facing CLI tooling.
- Contains: `episode_run.py`, experiment helpers, model helpers, smoke tools, storage tools.
- Key files: `screenalytics/tools/episode_run.py`.

**`screenalytics/web/`:**
- Purpose: Hold the optional Next.js Screenalytics UI.
- Contains: `app/`, `components/`, `api/`, `lib/`, Next config, package manifest.
- Key files: `screenalytics/web/app/page.tsx`, `screenalytics/web/app/screenalytics/page.tsx`, `screenalytics/web/api/client.ts`, `screenalytics/web/next.config.mjs`.

## Key File Locations

**Entry Points:**
- `Makefile`: Workspace startup, preflight, status, and shared test commands.
- `TRR-APP/apps/web/src/app/layout.tsx`: Main Next.js root layout.
- `TRR-APP/apps/web/src/app/page.tsx`: Main TRR landing page.
- `TRR-Backend/api/main.py`: FastAPI app entrypoint for TRR-Backend.
- `TRR-Backend/trr_backend/cli/__main__.py`: Backend CLI entrypoint.
- `screenalytics/apps/api/main.py`: FastAPI app entrypoint for Screenalytics.
- `screenalytics/apps/workspace-ui/streamlit_app.py`: Streamlit multipage app entrypoint.
- `screenalytics/tools/episode_run.py`: Direct pipeline CLI entrypoint.
- `screenalytics/web/app/page.tsx`: Next.js web prototype entrypoint.

**Configuration:**
- `docs/workspace/env-contract.md`: Workspace env contract source.
- `profiles/default.env`: Canonical workspace startup profile.
- `TRR-APP/apps/web/next.config.ts`: Next.js app config.
- `TRR-Backend/supabase/migrations/`: Backend schema changes.
- `screenalytics/config/pipeline/*.yaml`: Screenalytics pipeline settings.
- `screenalytics/web/next.config.mjs`: Screenalytics web config.

**Core Logic:**
- `TRR-APP/apps/web/src/lib/server/trr-api/`: Backend proxy and admin-read helpers.
- `TRR-APP/apps/web/src/lib/server/admin/`: Admin repositories and server-only helpers.
- `TRR-Backend/trr_backend/repositories/`: Canonical backend persistence modules.
- `TRR-Backend/trr_backend/services/`: Backend business/service logic.
- `TRR-Backend/trr_backend/pipeline/`: Backend pipeline orchestration.
- `screenalytics/apps/api/services/`: Screenalytics orchestration, storage, ingest, and run state.
- `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline/`: Reusable Screenalytics pipeline engine/stages.

**Testing:**
- `TRR-Backend/tests/`: Backend tests, split by subsystem.
- `screenalytics/tests/`: Screenalytics tests, split by unit/integration/ml/ui.
- `TRR-APP/apps/web`: App-local tests run from the web package; route/component code lives beside test config and scripts.

**Docs and Cross-Collab:**
- `docs/cross-collab/WORKFLOW.md`: Workspace cross-repo execution order.
- `TRR-Backend/docs/Repository/README.md`: Backend repo structure docs.
- `TRR-APP/docs/Repository/README.md`: App repo structure docs.
- `screenalytics/docs/README.md`: Canonical Screenalytics docs index.

## Naming Conventions

**Files:**
- App Router route files use framework-reserved names: `page.tsx`, `layout.tsx`, `route.ts` in `TRR-APP/apps/web/src/app/` and `screenalytics/web/app/`.
- Backend and Screenalytics Python modules are mostly snake_case files such as `TRR-Backend/api/routers/admin_cast_screentime.py` and `screenalytics/apps/api/services/pipeline_orchestration.py`.
- TS/TSX shared components usually use PascalCase filenames such as `TRR-APP/apps/web/src/components/GlobalHeader.tsx`.
- Server-only app helpers use descriptive kebab/snake-ish groupings inside folders such as `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`.

**Directories:**
- Feature/group folders are plural and domain-based: `TRR-Backend/trr_backend/repositories/`, `TRR-APP/apps/web/src/components/admin/`, `screenalytics/apps/api/services/`.
- Streamlit page ordering uses numbered filenames in `screenalytics/apps/workspace-ui/pages/`.
- Config directories are grouped by subsystem rather than by environment alone, for example `screenalytics/config/pipeline/` and `docs/workspace/`.

## Where to Add New Code

**New Workspace-Level Automation:**
- Primary code: `scripts/`
- Docs: `docs/workspace/` or `docs/cross-collab/`
- Use when the change coordinates multiple repos, startup behavior, browser policy, handoffs, or env validation.

**New TRR UI Route or Page:**
- Primary code: `TRR-APP/apps/web/src/app/`
- Shared UI: `TRR-APP/apps/web/src/components/`
- Server helpers: `TRR-APP/apps/web/src/lib/server/`
- Tests: follow the existing `apps/web` test setup and keep route-specific logic near the app package.

**New TRR Admin BFF/Proxy Behavior:**
- Proxy/auth wrappers: `TRR-APP/apps/web/src/lib/server/trr-api/`
- Admin repositories/services: `TRR-APP/apps/web/src/lib/server/admin/`
- Only add browser-facing API route handlers to `TRR-APP/apps/web/src/app/api/**/route.ts` when the browser needs an app-owned endpoint.

**New Backend API Endpoint:**
- HTTP surface: `TRR-Backend/api/routers/`
- Shared dependencies/auth: `TRR-Backend/api/auth.py`, `TRR-Backend/api/deps.py`, `TRR-Backend/api/screenalytics_auth.py`
- Domain logic: `TRR-Backend/trr_backend/services/` or `TRR-Backend/trr_backend/repositories/`
- Put SQL-heavy persistence in `repositories/`; keep routers thin.

**New Backend Schema Change:**
- Migration: `TRR-Backend/supabase/migrations/`
- Supporting docs: `TRR-Backend/supabase/schema_docs/` and repo docs as needed
- Never place schema changes in `screenalytics/` or `TRR-APP/`.

**New Backend Batch/Operator Script:**
- Script entrypoint: `TRR-Backend/scripts/`
- Shared reusable logic: `TRR-Backend/trr_backend/`
- Use `scripts/` for command wrappers and `trr_backend/` for reusable library behavior.

**New Screenalytics API Endpoint or Service:**
- Router: `screenalytics/apps/api/routers/`
- Service/orchestration: `screenalytics/apps/api/services/`
- Shared runtime code: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Keep HTTP-only concerns in `apps/api`; move reusable pipeline code into the package.

**New Screenalytics Streamlit Page or Component:**
- Page: `screenalytics/apps/workspace-ui/pages/`
- Shared widget/helper: `screenalytics/apps/workspace-ui/components/` or a local helper module in `apps/workspace-ui/`
- Ensure page config remains centralized in `screenalytics/apps/workspace-ui/streamlit_app.py`.

**New Screenalytics Pipeline Logic:**
- Reusable stage/runtime code: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Config knobs: `screenalytics/config/pipeline/`
- Tool wrappers or experiments: `screenalytics/tools/`

**New Screenalytics Web UI Feature:**
- Routes: `screenalytics/web/app/`
- React UI: `screenalytics/web/components/`
- API client/data hooks: `screenalytics/web/api/` and `screenalytics/web/lib/`
- Only use this path for the optional Next.js UI, not for the primary Streamlit workspace.

**Shared Utilities:**
- TRR app-only utility: `TRR-APP/apps/web/src/lib/`
- Backend-only utility: `TRR-Backend/trr_backend/utils/`
- Screenalytics-only utility: `screenalytics/packages/py-screenalytics/src/py_screenalytics/` or `screenalytics/apps/common/`
- Do not create a new workspace-wide code library unless the logic truly spans repos and cannot live behind an API boundary.

## Special Directories

**`.planning/codebase/`:**
- Purpose: Generated reference docs for future agents.
- Generated: Yes
- Committed: Yes

**`docs/cross-collab/` and repo-local `docs/cross-collab/`:**
- Purpose: Formal multi-repo task plans and status tracking.
- Generated: No
- Committed: Yes

**`TRR-Backend/supabase/.branches/` and `TRR-Backend/supabase/.temp/`:**
- Purpose: Supabase local/branching metadata.
- Generated: Yes
- Committed: Mixed; treat as tool-managed, not a hand-edit target.

**`screenalytics/packages/py-screenalytics/`:**
- Purpose: Reusable internal package for Screenalytics runtime code.
- Generated: No
- Committed: Yes

**`screenalytics/FEATURES/`:**
- Purpose: Feature-specific implementation and research areas for Screenalytics.
- Generated: No
- Committed: Yes

**`output/`, `artifacts/`, and repo-local `.artifacts/`:**
- Purpose: Generated outputs, screenshots, policy JSON, and runtime artifacts.
- Generated: Yes
- Committed: Mixed; inspect before relying on them as source-of-truth code.

**`apps/` at the workspace root:**
- Purpose: Placeholder/non-primary workspace directory.
- Generated: No
- Committed: Yes
- Do not treat `apps/` as the main TRR app location; the active app repo is `TRR-APP/apps/web/`.

---

*Structure analysis: 2026-04-04*
