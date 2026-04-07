# Codebase Structure

**Analysis Date:** 2026-04-06

## Directory Layout

```text
TRR/
├── TRR-Backend/      # Canonical schema, FastAPI API, services, migrations, backend tests
├── TRR-APP/          # Next.js web app and app-owned server/proxy code
├── screenalytics/    # Analytics API, Streamlit workspace UI, pipeline code, ML tooling
├── scripts/          # Workspace orchestration, handoff, browser, and validation scripts
├── scripts/lib/      # Shared shell helpers used by workspace scripts
├── docs/             # Workspace policy, workflow, env, and handoff documentation
├── profiles/         # Workspace runtime profiles loaded by `scripts/dev-workspace.sh`
├── .planning/        # Workstreams, milestones, research, and codebase mapping docs
├── .logs/            # Workspace runtime logs and handoff-sync logs
├── apps/             # Sparse workspace-side artifacts; not the live TRR app source tree
├── data/             # Shared local data artifacts and inputs
└── artifacts/        # Externalized/generated runtime artifact staging
```

## Directory Purposes

**`TRR-Backend/`:**
- Purpose: Own schema, backend contracts, business logic, and backend verification.
- Contains: `api/` FastAPI surface, `trr_backend/` domain packages, `supabase/migrations/` schema history, `tests/`, backend docs, and scripts.
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/`, `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/migrations/`, `TRR-Backend/Makefile`

**`TRR-APP/`:**
- Purpose: Own the user/admin web app and app-level server proxy and repository code.
- Contains: `apps/web/` Next.js app, `apps/vue-wordle/` secondary Vue app, repo-local scripts/docs, and package manifests.
- Key files: `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`, `TRR-APP/apps/web/src/lib/server/`

**`screenalytics/`:**
- Purpose: Own analytics processing, operator UIs, and screenalytics-side API/tooling.
- Contains: `apps/api/` FastAPI API, `apps/workspace-ui/` Streamlit app, `py_screenalytics/` and `packages/py-screenalytics/` reusable code, `tools/`, `tests/`, `infra/`, and feature incubators.
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/app.py`, `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/tools/episode_run.py`

**`scripts/`:**
- Purpose: Provide the workspace command surface above the nested repos.
- Contains: Startup/shutdown scripts, browser automation wrappers, policy checks, test runners, handoff sync tooling, and helper CLIs.
- Key files: `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/status-workspace.sh`, `scripts/doctor.sh`, `scripts/handoff-lifecycle.sh`, `scripts/check-workspace-contract.sh`

**`scripts/lib/`:**
- Purpose: Hold reusable shell helpers consumed by workspace scripts.
- Contains: Node baseline helpers, runtime DB env resolution, managed Chrome helpers, preflight diagnostics, and Python venv helpers.
- Key files: `scripts/lib/runtime-db-env.sh`, `scripts/lib/node-baseline.sh`, `scripts/lib/chrome-runtime.sh`

**`docs/`:**
- Purpose: Store workspace-level policy and coordination docs rather than repo-owned implementation docs.
- Contains: `docs/workspace/` runtime contracts, `docs/cross-collab/` workflow and task docs, `docs/ai/` handoff policy/status, and governance docs.
- Key files: `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/workspace/chrome-devtools.md`, `docs/cross-collab/WORKFLOW.md`, `docs/ai/HANDOFF_WORKFLOW.md`

**`.planning/`:**
- Purpose: Store GSD planning state and generated codebase references at the workspace root.
- Contains: `PROJECT.md`, `active-workstream`, `workstreams/`, `milestones/`, `research/`, `seeds/`, and `codebase/`.
- Key files: `.planning/PROJECT.md`, `.planning/active-workstream`, `.planning/workstreams/feature-b/STATE.md`, `.planning/codebase/`

**`profiles/`:**
- Purpose: Define named workspace runtime default sets.
- Contains: Shell-style env profiles for default and compatibility modes.
- Key files: `profiles/default.env`, `profiles/local-docker.env`, `profiles/local-cloud.env`

**`apps/`:**
- Purpose: Workspace-side artifact bucket, currently minimal.
- Contains: A sparse `apps/web/src/lib/fonts/brand-fonts/` tree.
- Key files: `apps/web/src/lib/fonts/brand-fonts/glyph-comparison.ts`

## Key File Locations

**Entry Points:**
- `Makefile`: Workspace command surface and default dev/test targets
- `scripts/dev-workspace.sh`: Canonical local startup orchestrator
- `TRR-Backend/api/main.py`: FastAPI application bootstrap for the backend
- `screenalytics/apps/api/main.py`: FastAPI application bootstrap for screenalytics
- `screenalytics/apps/workspace-ui/app.py`: Streamlit workspace shell
- `TRR-APP/apps/web/src/app/layout.tsx`: Top-level Next.js App Router layout

**Configuration:**
- `AGENTS.md`: Workspace-wide cross-repo rules and contracts
- `TRR-Backend/AGENTS.md`: Backend-local rules
- `TRR-APP/AGENTS.md`: App-local rules
- `screenalytics/AGENTS.md`: Screenalytics-local rules
- `profiles/default.env`: Canonical cloud-first workspace profile
- `docs/workspace/env-contract.md`: Generated workspace env contract
- `TRR-Backend/supabase/config.toml`: Supabase CLI project config

**Core Logic:**
- `TRR-Backend/api/routers/`: HTTP route modules by backend domain
- `TRR-Backend/trr_backend/repositories/`: Data-access and persistence logic
- `TRR-Backend/trr_backend/services/`: Orchestration/business services
- `TRR-APP/apps/web/src/app/`: App Router pages, layouts, and route handlers
- `TRR-APP/apps/web/src/lib/server/`: Server-only proxies, repositories, and auth glue
- `screenalytics/apps/api/routers/`: Screenalytics API endpoints
- `screenalytics/py_screenalytics/` and `screenalytics/packages/py-screenalytics/src/py_screenalytics/`: Reusable analytics logic
- `screenalytics/tools/`: Pipeline entry scripts and operational tooling

**Testing:**
- `TRR-Backend/tests/`: Backend tests organized by layer/domain
- `TRR-APP/apps/web/tests/`: Vitest and Playwright coverage for the web app
- `screenalytics/tests/`: Unit, integration, ML, UI, and API coverage
- `scripts/test-fast.sh`, `scripts/test-full.sh`, `scripts/test-env-sensitive.sh`: Workspace test aggregators

## Naming Conventions

**Files:**
- Workspace shell utilities use kebab-case in `scripts/`, such as `scripts/dev-workspace.sh` and `scripts/check-workspace-contract.sh`.
- Backend Python modules use snake_case by domain, such as `TRR-Backend/api/routers/admin_cast_screentime.py` and `TRR-Backend/trr_backend/repositories/cast_screentime.py`.
- Next.js routes use App Router conventions: `page.tsx`, `layout.tsx`, `route.ts`, dynamic folders like `[showId]`, and catch-all folders like `[...path]` in `TRR-APP/apps/web/src/app/`.
- Streamlit pages are numerically prefixed for navigation order, such as `screenalytics/apps/workspace-ui/pages/4_Screentime.py`.
- Schema migrations are zero-padded or timestamp-prefixed SQL files in `TRR-Backend/supabase/migrations/`.

**Directories:**
- Repo roots are product boundaries: `TRR-Backend/`, `TRR-APP/`, and `screenalytics/`.
- Backend code splits transport under `TRR-Backend/api/` from reusable domain code under `TRR-Backend/trr_backend/`.
- App code splits route tree under `TRR-APP/apps/web/src/app/`, UI components under `TRR-APP/apps/web/src/components/`, and server code under `TRR-APP/apps/web/src/lib/server/`.
- Screenalytics splits API/UI surfaces under `screenalytics/apps/`, reusable packages under `screenalytics/py_screenalytics/` and `screenalytics/packages/`, and ad hoc operators/tools under `screenalytics/tools/`.

## Where to Add New Code

**New workspace feature or command:**
- Primary code: `scripts/` for executable entrypoints and `scripts/lib/` for shared shell helpers
- Tests/docs: `docs/workspace/` for operator-facing contract changes, plus existing workspace test scripts if validation needs to aggregate across repos

**New backend API or schema-backed feature:**
- Primary code: `TRR-Backend/api/routers/` for HTTP exposure, `TRR-Backend/trr_backend/services/` and `TRR-Backend/trr_backend/repositories/` for implementation
- Schema: add a new file to `TRR-Backend/supabase/migrations/`; never edit an existing migration
- Tests: matching files under `TRR-Backend/tests/api/`, `TRR-Backend/tests/repositories/`, `TRR-Backend/tests/services/`, or the closest existing backend test area

**New TRR web feature:**
- Primary code: `TRR-APP/apps/web/src/app/` for routes and page shells
- Components: `TRR-APP/apps/web/src/components/` or a nearby domain folder such as `TRR-APP/apps/web/src/components/admin/`
- Server access: `TRR-APP/apps/web/src/lib/server/` or `TRR-APP/apps/web/src/lib/server/trr-api/` when the feature talks to `TRR-Backend/`
- Tests: `TRR-APP/apps/web/tests/`

**New screenalytics API or analytics workflow:**
- API surface: `screenalytics/apps/api/routers/` and `screenalytics/apps/api/services/`
- Operator UI: `screenalytics/apps/workspace-ui/pages/`
- Reusable analytics logic: `screenalytics/py_screenalytics/` or `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Operational entry scripts: `screenalytics/tools/`
- Tests: `screenalytics/tests/` in the matching area (`unit`, `integration`, `ml`, `ui`, `api`)

**New planning or handoff artifacts:**
- Workstream state: `.planning/workstreams/<workstream>/`
- Milestone archives: `.planning/milestones/`
- Workspace-local continuity notes: `docs/ai/local-status/`
- Do not create a root `.planning/STATE.md`; the active selector is `.planning/active-workstream`

**Utilities:**
- Shared workspace helpers: `scripts/lib/`
- Backend-only helpers: `TRR-Backend/trr_backend/utils/`
- App-only helpers: `TRR-APP/apps/web/src/lib/`
- Screenalytics-only helpers: `screenalytics/apps/common/`, `screenalytics/apps/shared/`, or `screenalytics/tools/`

## High-Value Navigation Guide

**Start here for workspace orchestration:**
- `Makefile`
- `scripts/dev-workspace.sh`
- `docs/workspace/dev-commands.md`
- `docs/workspace/env-contract.md`

**Start here for cross-repo policy:**
- `AGENTS.md`
- `docs/cross-collab/WORKFLOW.md`
- `docs/ai/HANDOFF_WORKFLOW.md`

**Start here for backend contract work:**
- `TRR-Backend/api/main.py`
- `TRR-Backend/api/routers/`
- `TRR-Backend/trr_backend/repositories/`
- `TRR-Backend/supabase/migrations/`

**Start here for app-to-backend integration work:**
- `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/`
- `TRR-APP/apps/web/src/lib/server/admin/`

**Start here for screenalytics integration work:**
- `screenalytics/apps/api/main.py`
- `screenalytics/apps/api/services/supabase_db.py`
- `TRR-Backend/api/routers/screenalytics.py`
- `TRR-Backend/api/routers/screenalytics_runs_v2.py`

**Start here for active planning context:**
- `.planning/PROJECT.md`
- `.planning/active-workstream`
- `.planning/workstreams/feature-b/STATE.md`

## Special Directories

**`.planning/codebase/`:**
- Purpose: Generated codebase map documents consumed by later GSD workflows
- Generated: Yes, by mapper agents
- Committed: Yes

**`.planning/workstreams/feature-b/`:**
- Purpose: Archived active-workstream directory for the latest shipped workspace-tooling milestone
- Generated: No
- Committed: Yes

**`TRR-Backend/supabase/migrations/`:**
- Purpose: Canonical database schema history for the shared TRR database
- Generated: No
- Committed: Yes

**`screenalytics/FEATURES/`:**
- Purpose: Feature incubators and deeper subsystem workstreams inside the screenalytics repo
- Generated: No
- Committed: Yes

**`screenalytics/infra/`:**
- Purpose: Deployment templates for hosted screenalytics API/worker infrastructure
- Generated: No
- Committed: Yes

**`apps/web/`:**
- Purpose: Sparse workspace-side artifact area; not the main TRR-APP source tree
- Generated: No
- Committed: Yes

**`.logs/` and `artifacts/`:**
- Purpose: Runtime logs and artifact storage/staging for workspace sessions
- Generated: Yes
- Committed: Mixed; treat as runtime output areas, not primary source directories

---

*Structure analysis: 2026-04-06*
