# Codebase Structure

**Analysis Date:** 2026-04-02

## Directory Layout

```text
TRR/
├── TRR-Backend/     # FastAPI backend, shared Python domain library, Supabase migrations
├── screenalytics/   # FastAPI API, Streamlit workspace UI, ML pipeline package, pipeline tools
├── TRR-APP/         # Next.js App Router frontend and app-owned server modules
├── docs/            # Workspace-level process, env, and collaboration documentation
├── scripts/         # Workspace orchestration, validation, browser, and MCP wrappers
├── profiles/        # Workspace startup profile env files consumed by `scripts/dev-workspace.sh`
├── BRAVOTV/         # Source-specific scraping and research utilities for Bravo/NBC assets
├── output/          # Checked-in diagnostic and generated output artifacts; not primary source code
└── .planning/       # Generated planning and codebase-analysis artifacts
```

## Directory Purposes

**`TRR-Backend/`:**
- Purpose: Shared backend contract owner for database schema, FastAPI endpoints, reusable Python runtime code, and ingestion/sync jobs.
- Contains: `api/`, `trr_backend/`, `supabase/`, `scripts/`, `tests/`
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/migrations/`, `TRR-Backend/requirements.txt`, `TRR-Backend/Makefile`

**`TRR-Backend/api/`:**
- Purpose: HTTP and realtime entry surface only.
- Contains: `main.py`, router modules in `TRR-Backend/api/routers/`, realtime broker modules in `TRR-Backend/api/realtime/`
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/shows.py`, `TRR-Backend/api/routers/screenalytics_runs_v2.py`

**`TRR-Backend/trr_backend/`:**
- Purpose: Reusable backend library code that both API and scripts can import.
- Contains: repositories, DB adapters, integrations, media helpers, socials runtimes, pipeline orchestration, CLI entrypoints
- Key files: `TRR-Backend/trr_backend/repositories/shows.py`, `TRR-Backend/trr_backend/db/connection.py`, `TRR-Backend/trr_backend/pipeline/orchestrator.py`, `TRR-Backend/trr_backend/job_plane.py`

**`TRR-Backend/supabase/`:**
- Purpose: Shared schema source of truth.
- Contains: ordered SQL migrations, Supabase config, generated schema docs
- Key files: `TRR-Backend/supabase/config.toml`, `TRR-Backend/supabase/migrations/0001_init.sql`, `TRR-Backend/supabase/migrations/0115_reconcile_screenalytics_v2_tables.sql`

**`screenalytics/`:**
- Purpose: Computer-vision and screen-time subsystem that consumes TRR metadata and writes Screenalytics operational state.
- Contains: `apps/`, `packages/`, `tools/`, `config/`, `tests/`, `FEATURES/`, `infra/`
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/packages/py-screenalytics/pyproject.toml`, `screenalytics/tools/episode_run.py`

**`screenalytics/apps/api/`:**
- Purpose: Screenalytics FastAPI surface plus service layer.
- Contains: `routers/`, `services/`, `schemas/`, task modules, config modules
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/runs_v2.py`, `screenalytics/apps/api/services/runs_v2.py`, `screenalytics/apps/api/services/supabase_db.py`

**`screenalytics/apps/workspace-ui/`:**
- Purpose: Operator-facing Streamlit app.
- Contains: `streamlit_app.py`, numbered `pages/`, reusable `components/`, UI-specific tests
- Key files: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/pages/4_Screentime.py`

**`screenalytics/packages/py-screenalytics/`:**
- Purpose: Installable, reusable pipeline library.
- Contains: `pyproject.toml`, `src/py_screenalytics/` modules for manifests, stages, config, layout, and runtime safety
- Key files: `screenalytics/packages/py-screenalytics/pyproject.toml`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_manifests.py`

**`TRR-APP/`:**
- Purpose: User-facing and admin-facing web application.
- Contains: pnpm workspace config, `apps/web/` Next.js app, `apps/vue-wordle/` secondary Vue app, repo-local docs and scripts
- Key files: `TRR-APP/package.json`, `TRR-APP/pnpm-workspace.yaml`, `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/next.config.ts`

**`TRR-APP/apps/web/src/app/`:**
- Purpose: App Router route tree.
- Contains: public pages, admin pages, API route handlers, auth routes, game pages, brand/design-system pages
- Key files: `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/src/app/api/admin/shows/route.ts`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`

**`TRR-APP/apps/web/src/components/`:**
- Purpose: Shared React UI building blocks.
- Contains: admin components, public components, survey components, typography helpers, generic UI pieces
- Key files: `TRR-APP/apps/web/src/components/admin/`, `TRR-APP/apps/web/src/components/public/`, `TRR-APP/apps/web/src/components/ui/`

**`TRR-APP/apps/web/src/lib/`:**
- Purpose: Shared frontend and server utilities.
- Contains: client-safe helpers in `TRR-APP/apps/web/src/lib/admin/`, `TRR-APP/apps/web/src/lib/media/`, `TRR-APP/apps/web/src/lib/surveys/`; server-only helpers in `TRR-APP/apps/web/src/lib/server/`
- Key files: `TRR-APP/apps/web/src/lib/server/postgres.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`

**`docs/`:**
- Purpose: Workspace-level policies, runbooks, plans, and coordination documents.
- Contains: governance docs, handoff docs, cross-collab workflow docs, environment references, plans
- Key files: `docs/cross-collab/WORKFLOW.md`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`

**`scripts/`:**
- Purpose: Workspace automation shell around the three repos.
- Contains: startup, preflight, test runners, browser helpers, handoff sync, MCP wrappers
- Key files: `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/sync-handoffs.py`, `scripts/codex-chrome-devtools-mcp.sh`

**`profiles/`:**
- Purpose: Environment-profile files loaded by `scripts/dev-workspace.sh`
- Contains: `.env`-style profile defaults for workspace startup modes
- Key files: consumed dynamically by `scripts/dev-workspace.sh`

**`BRAVOTV/`:**
- Purpose: Source-specific experiments, scripts, and source notes for Bravo-related media collection.
- Contains: source notes, scraping scripts, plans
- Key files: `BRAVOTV/README.md`, `BRAVOTV/get_images.py`, `BRAVOTV/sources/getty.md`

## Key File Locations

**Entry Points:**
- `Makefile`: workspace startup, validation, and status command entry
- `scripts/dev-workspace.sh`: canonical multi-repo local runtime bootstrap
- `TRR-Backend/api/main.py`: backend FastAPI app entry
- `TRR-Backend/trr_backend/cli/__main__.py`: backend CLI entry
- `screenalytics/apps/api/main.py`: Screenalytics FastAPI entry
- `screenalytics/apps/workspace-ui/streamlit_app.py`: Screenalytics Streamlit entry
- `screenalytics/tools/episode_run.py`: Screenalytics CLI pipeline entry
- `TRR-APP/apps/web/src/app/layout.tsx`: Next.js root layout entry
- `TRR-APP/apps/web/src/proxy.ts`: request rewrite and host-boundary entry for the web app

**Configuration:**
- `docs/workspace/env-contract.md`: workspace env contract reference
- `TRR-Backend/supabase/config.toml`: Supabase project config
- `TRR-Backend/requirements.txt`: backend Python install entrypoint
- `screenalytics/pyproject.toml`: Screenalytics Python tooling config
- `screenalytics/packages/py-screenalytics/pyproject.toml`: installable pipeline package config
- `screenalytics/config/pipeline/*.yaml`: pipeline stage and runtime tuning
- `TRR-APP/package.json`: repo-level app commands and dev orchestration
- `TRR-APP/apps/web/package.json`: web-app scripts and toolchain
- `TRR-APP/apps/web/next.config.ts`: Next.js runtime config

**Core Logic:**
- `TRR-Backend/trr_backend/repositories/`: backend read/write repositories
- `TRR-Backend/trr_backend/integrations/`: external-source adapters
- `TRR-Backend/trr_backend/pipeline/`: staged backend pipeline orchestration
- `screenalytics/apps/api/services/`: Screenalytics service layer
- `screenalytics/packages/py-screenalytics/src/py_screenalytics/`: reusable pipeline package
- `TRR-APP/apps/web/src/lib/server/`: server-only app repositories, auth, DB, backend proxying
- `TRR-APP/apps/web/src/components/admin/`: admin UI component set
- `TRR-APP/apps/web/src/lib/admin/`: admin routing and UI state helpers

**Testing:**
- `TRR-Backend/tests/`: backend tests
- `screenalytics/tests/`: Screenalytics unit, ML, API, integration, and UI tests
- `TRR-APP/apps/web/tests/`: Vitest coverage for routes, components, and admin flows
- `TRR-APP/apps/web/playwright.config.ts`: e2e test config for the web app

## Naming Conventions

**Files:**
- Python application and library modules use `snake_case.py`. Follow the pattern in `TRR-Backend/trr_backend/repositories/show_images.py`, `screenalytics/apps/api/services/pipeline_state.py`, and `screenalytics/tools/episode_run.py`.
- Next App Router route files use framework-reserved names. Use `page.tsx`, `layout.tsx`, and `route.ts` inside `TRR-APP/apps/web/src/app/`.
- React component files are usually `PascalCase.tsx` when they export a component, especially under `TRR-APP/apps/web/src/components/`. Examples: `TRR-APP/apps/web/src/components/admin/AdminGlobalHeader.tsx`, `TRR-APP/apps/web/src/components/admin/ShowBrandEditor.tsx`.
- App utility modules tend to use `kebab-case.ts` or `kebab-case.tsx` for feature helpers. Examples: `TRR-APP/apps/web/src/lib/admin/show-route-slug.ts`, `TRR-APP/apps/web/src/lib/admin/async-handles.ts`.
- SQL migrations use zero-padded numeric prefixes plus a short description, such as `TRR-Backend/supabase/migrations/0103_screenalytics_video_asset_cast_candidates.sql`.

**Directories:**
- Repo roots are explicit product names: `TRR-Backend/`, `screenalytics/`, `TRR-APP/`.
- Python package/layout directories are role-based and flat near the top: `TRR-Backend/trr_backend/repositories/`, `screenalytics/apps/api/services/`.
- Streamlit page directories keep numbered filenames to control ordering, as in `screenalytics/apps/workspace-ui/pages/0_Shows.py`.
- Next.js route groups follow URL shape, not component type, under `TRR-APP/apps/web/src/app/`.

## Where to Add New Code

**New Shared Database Contract:**
- Primary code: `TRR-Backend/supabase/migrations/`
- Follow-up runtime usage: `TRR-Backend/trr_backend/` and `TRR-Backend/api/`
- Consumer updates after backend: `screenalytics/apps/api/services/` and `TRR-APP/apps/web/src/lib/server/trr-api/`

**New Backend API Endpoint:**
- Router: `TRR-Backend/api/routers/`
- Shared logic: `TRR-Backend/trr_backend/repositories/`, `TRR-Backend/trr_backend/services/`, `TRR-Backend/trr_backend/clients/`
- Avoid: putting reusable data or integration logic directly into `TRR-Backend/api/routers/`

**New Backend Script or Import Workflow:**
- Reusable import/integration code: `TRR-Backend/trr_backend/ingestion/` or `TRR-Backend/trr_backend/integrations/`
- Thin executable wrapper: `TRR-Backend/scripts/`
- Avoid: embedding one-off SQL or API logic only in a script if it will be reused by the API or other jobs

**New Next.js Page or Route:**
- Route surface: `TRR-APP/apps/web/src/app/`
- Shared UI: `TRR-APP/apps/web/src/components/`
- Server-only data access: `TRR-APP/apps/web/src/lib/server/`
- Client-safe helpers: `TRR-APP/apps/web/src/lib/`
- Avoid: calling the backend directly from client components when a server module or route handler can own the secret-bearing call

**New App-Owned Data Repository:**
- Implementation: `TRR-APP/apps/web/src/lib/server/`
- Examples to follow: `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`, `TRR-APP/apps/web/src/lib/server/surveys/repository.ts`
- Use when: the data lives in app-owned tables rather than the backend API contract

**New Backend Proxy or TRR Read Path in the App:**
- Implementation: `TRR-APP/apps/web/src/lib/server/trr-api/`
- Route wrapper if needed: `TRR-APP/apps/web/src/app/api/`
- Examples to follow: `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`

**New Screenalytics API Feature:**
- Router: `screenalytics/apps/api/routers/`
- Service: `screenalytics/apps/api/services/`
- Shared DB/storage helpers: `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/apps/api/services/storage_v2.py`
- Avoid: placing business logic directly in the router file

**New Screenalytics Pipeline Stage or Shared ML Helper:**
- Reusable implementation: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Config: `screenalytics/config/pipeline/`
- CLI entry or local operator workflow: `screenalytics/tools/`
- Avoid: putting reusable pipeline logic only in `screenalytics/tools/episode_run.py`

**Tests:**
- Backend tests: `TRR-Backend/tests/`
- App tests: `TRR-APP/apps/web/tests/`
- Screenalytics tests: `screenalytics/tests/`

## Special Directories

**`TRR-Backend/supabase/migrations/`:**
- Purpose: Source-of-truth shared schema migrations
- Generated: No
- Committed: Yes

**`TRR-Backend/supabase/schema_docs/`:**
- Purpose: Generated schema documentation and diagrams derived from the live schema
- Generated: Yes
- Committed: Yes

**`screenalytics/packages/py-screenalytics/`:**
- Purpose: Installable package boundary for reusable Screenalytics code
- Generated: No
- Committed: Yes

**`screenalytics/config/pipeline/`:**
- Purpose: Runtime tuning for detection, tracking, clustering, alignment, and reports
- Generated: No
- Committed: Yes

**`TRR-APP/apps/vue-wordle/`:**
- Purpose: Secondary Vue app under the TRR-APP pnpm workspace
- Generated: No
- Committed: Yes

**`apps/web/` at workspace root:**
- Purpose: Not an active application root in the current workspace map; current contents are placeholder `.DS_Store` files only
- Generated: No
- Committed: Yes

**`output/`:**
- Purpose: Checked-in debug exports, screenshots, policy JSON, and other run artifacts
- Generated: Mixed, but primarily yes
- Committed: Yes

**`BRAVOTV/`:**
- Purpose: Source-specific research and scraping sandbox, separate from the main three runtime repos
- Generated: No
- Committed: Yes

**`.planning/codebase/`:**
- Purpose: Generated architecture, stack, testing, and concern reference docs for future planning/execution steps
- Generated: Yes
- Committed: Yes

---

*Structure analysis: 2026-04-02*
