# Codebase Structure

**Analysis Date:** 2026-04-07

## Directory Layout

```text
TRR/
├── TRR-Backend/        # Canonical FastAPI API, domain services, SQL migrations, backend scripts
├── TRR-APP/            # Next.js public/admin app plus secondary Vue app
├── screenalytics/      # Analytics API, Streamlit workspace, ML package, CLI tooling
├── scripts/            # Workspace-only orchestration, preflight, MCP/browser, handoff helpers
├── docs/               # Workspace workflow, env contracts, governance, diagrams
├── .planning/          # Planning artifacts consumed by GSD workflows
└── apps/               # Workspace-level leftover directory; not an active product repo
```

## Directory Purposes

**`TRR-Backend/`:**
- Purpose: Own the system-of-record API, canonical SQL schema, and shared contracts.
- Contains: `api/` FastAPI entry and routers, `trr_backend/` domain code, `supabase/` migrations and schema docs, `scripts/` operational/backfill tooling, `tests/`.
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/db/connection.py`, `TRR-Backend/trr_backend/clients/screenalytics.py`, `TRR-Backend/supabase/migrations/`.

**`TRR-APP/`:**
- Purpose: Own the user-facing site, admin UI, and Next.js server boundary around backend access.
- Contains: `apps/web/` main Next.js app, `apps/vue-wordle/` secondary Vue app, repo-local scripts, docs, and tests.
- Key files: `TRR-APP/package.json`, `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`.

**`screenalytics/`:**
- Purpose: Own analytics operators’ tooling, episode-processing runtime, and analytics-facing APIs.
- Contains: `apps/api/` FastAPI service, `apps/workspace-ui/` Streamlit UI, `packages/py-screenalytics/` reusable package, `tools/` CLI runners, `config/pipeline/` YAML stage config, `tests/`.
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/tools/episode_run.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline/episode_engine.py`.

**`scripts/`:**
- Purpose: Coordinate the workspace itself rather than any single repo.
- Contains: dev shell wrappers, env checks, Chrome/MCP wrappers, handoff lifecycle helpers, smoke/test runners.
- Key files: `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/handoff-lifecycle.sh`, `scripts/codex-chrome-devtools-mcp.sh`.

**`docs/`:**
- Purpose: Centralize workspace contracts and process docs.
- Contains: workflow docs, env-contract docs, governance docs, diagrams, planning writeups.
- Key files: `docs/cross-collab/WORKFLOW.md`, `docs/workspace/env-contract.md`, `docs/workspace/dev-commands.md`, `docs/ai/HANDOFF_WORKFLOW.md`.

**`.planning/`:**
- Purpose: Hold planning and mapping artifacts consumed by the GSD flow.
- Contains: `codebase/`, `milestones/`, `research/`, `workstreams/`, seeds and plans.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`.

## Key File Locations

**Entry Points:**
- `TRR-Backend/api/main.py`: FastAPI bootstrap for the canonical TRR backend.
- `screenalytics/apps/api/main.py`: FastAPI bootstrap for analytics operations.
- `screenalytics/apps/workspace-ui/streamlit_app.py`: Streamlit multipage workspace entry.
- `screenalytics/tools/episode_run.py`: CLI entry for single-episode pipeline runs.
- `TRR-APP/package.json`: repo-level dev/build entry for the Next.js app and local backend co-start.
- `TRR-APP/apps/web/src/app/layout.tsx`: root App Router layout for the primary web app.
- `screenalytics/web/app/layout.tsx`: root layout for the optional Screenalytics Next.js frontend.

**Configuration:**
- `TRR-Backend/supabase/config.toml`: backend Supabase project config.
- `TRR-Backend/supabase/migrations/*.sql`: canonical schema evolution.
- `screenalytics/config/pipeline/*.yaml`: pipeline stage tuning and execution defaults.
- `TRR-APP/apps/web/next.config.ts`: Next.js routing/runtime config for the main app.
- `screenalytics/web/next.config.mjs`: rewrite config for the optional Screenalytics web frontend.
- `TRR-APP/pnpm-workspace.yaml`: repo-local workspace package layout for frontend apps.

**Core Logic:**
- `TRR-Backend/trr_backend/repositories/`: backend read/write repositories by feature area.
- `TRR-Backend/trr_backend/services/`: backend service modules that coordinate repositories or external systems.
- `TRR-Backend/trr_backend/integrations/`: third-party ingestion and API integrations.
- `screenalytics/apps/api/services/`: analytics API orchestration, persistence, and storage logic.
- `screenalytics/packages/py-screenalytics/src/py_screenalytics/`: reusable ML/audio/pipeline package code.
- `TRR-APP/apps/web/src/lib/server/`: server-only auth, DB, proxy, and repository code for Next.js.
- `TRR-APP/apps/web/src/components/`: reusable React components, including the admin surface.

**Testing:**
- `TRR-Backend/tests/`: backend tests by layer (`api/`, `repositories/`, `services/`, `migrations/`, `socials/`, `vision/`).
- `screenalytics/tests/`: analytics tests by domain (`unit/`, `integration/`, `ml/`, `ui/`, `audio/`, `api/`).
- `TRR-APP/apps/web/tests/`: Next.js tests, E2E specs, fixtures, and mocks.

## Naming Conventions

**Files:**
- Backend and Screenalytics Python modules use snake_case feature names such as `TRR-Backend/api/routers/admin_show_reads.py` and `screenalytics/apps/api/services/pipeline_orchestration.py`.
- Next.js route segments use App Router folder names, including dynamic folders such as `TRR-APP/apps/web/src/app/[showId]/s[seasonNumber]/social/w[weekIndex]`.
- React component files use PascalCase for component-oriented modules such as `TRR-APP/apps/web/src/components/admin/UnifiedBrandsWorkspace.tsx`, while low-level utility or route-cache modules stay kebab/snake/camel mixed based on purpose.
- SQL migrations use monotonically increasing numeric prefixes in `TRR-Backend/supabase/migrations/`.

**Directories:**
- Backend routers and repositories are feature-grouped, not layered by HTTP verb. Add new backend features beside adjacent domain files under `TRR-Backend/api/routers/` and `TRR-Backend/trr_backend/repositories/`.
- Screenalytics keeps runtime interfaces separated: `apps/api/` for HTTP, `apps/workspace-ui/` for Streamlit, `packages/py-screenalytics/` for reusable code, `tools/` for operator CLIs.
- TRR app separates route trees (`src/app/`), reusable UI (`src/components/`), client/shared helpers (`src/lib/`), and server-only modules (`src/lib/server/`).

## Where to Add New Code

**New Backend API Feature:**
- Primary code: `TRR-Backend/api/routers/<feature>.py`
- Domain logic: `TRR-Backend/trr_backend/repositories/<feature>.py` and `TRR-Backend/trr_backend/services/<feature>.py`
- Schema changes: `TRR-Backend/supabase/migrations/<next_number>_<feature>.sql`
- Tests: `TRR-Backend/tests/api/` for route coverage and `TRR-Backend/tests/repositories/` or `TRR-Backend/tests/services/` for domain logic
- Rule: update backend first when the change affects `screenalytics/` or `TRR-APP/`.

**New Screenalytics Pipeline Capability:**
- Package implementation: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- API wiring: `screenalytics/apps/api/routers/` plus `screenalytics/apps/api/services/`
- CLI integration: `screenalytics/tools/episode_run.py` or a sibling file in `screenalytics/tools/`
- Config: `screenalytics/config/pipeline/`
- Tests: `screenalytics/tests/unit/`, `screenalytics/tests/ml/`, or `screenalytics/tests/integration/` depending scope
- Rule: keep reusable stage logic in the package, not directly inside Streamlit pages or route handlers.

**New Screenalytics Workspace Page:**
- Implementation: `screenalytics/apps/workspace-ui/pages/`
- Shared UI helpers: `screenalytics/apps/workspace-ui/components/` and `screenalytics/apps/workspace-ui/ui_helpers.py`
- Rule: keep `st.set_page_config(...)` only in `screenalytics/apps/workspace-ui/streamlit_app.py`.

**New TRR Web Route or Admin Tool:**
- Page or route tree: `TRR-APP/apps/web/src/app/`
- Browser UI: `TRR-APP/apps/web/src/components/`
- Server-only data access: `TRR-APP/apps/web/src/lib/server/`
- Next route handler: `TRR-APP/apps/web/src/app/api/`
- Tests: `TRR-APP/apps/web/tests/`
- Rule: if the browser needs backend data, put the fetch/proxy logic in `src/lib/server/` or `src/app/api/`, not in client components.

**New Workspace Automation or Shared Docs:**
- Scripts: `/Users/thomashulihan/Projects/TRR/scripts/`
- Shared documentation: `/Users/thomashulihan/Projects/TRR/docs/`
- Planning artifacts: `/Users/thomashulihan/Projects/TRR/.planning/`
- Rule: do not place workspace scripts inside one repo unless the workflow is repo-specific.

**What Not to Use For New Product Code:**
- `apps/web/`: current workspace-level directory is not an active application root.
- Generated output directories such as `TRR-APP/apps/web/.next/` or `screenalytics/web/.next/`.

## Special Directories

**`TRR-Backend/supabase/`:**
- Purpose: schema ownership, migration history, schema docs, and local Supabase config
- Generated: mixed
- Committed: yes

**`screenalytics/packages/py-screenalytics/`:**
- Purpose: reusable package shared by API, CLI, and UI runtimes
- Generated: no
- Committed: yes

**`screenalytics/config/pipeline/`:**
- Purpose: YAML defaults and tunables for analytics pipeline stages
- Generated: no
- Committed: yes

**`TRR-APP/apps/web/tests/fixtures/`:**
- Purpose: frontend fixtures and recorded test inputs
- Generated: no
- Committed: yes

**`.planning/codebase/`:**
- Purpose: generated-but-committed codebase reference docs for GSD planners/executors
- Generated: yes
- Committed: yes

---

*Structure analysis: 2026-04-07*
