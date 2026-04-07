# Codebase Structure

**Analysis Date:** 2026-04-07

## Directory Layout

```text
TRR/
├── TRR-Backend/      # Canonical schema, FastAPI API, backend services, migrations, tests
├── TRR-APP/          # Next.js app, Vue side-app, repo-local scripts/docs
├── screenalytics/    # Analytics API, Streamlit UI, pipeline tools, ML/tests
├── scripts/          # Workspace orchestration and policy tooling
├── docs/             # Workspace policy, env, workflow, handoff docs
├── profiles/         # Workspace runtime profiles
├── .planning/        # Workstreams, milestones, research, codebase docs
├── data/             # Shared local data artifacts
├── artifacts/        # Generated/runtime artifact staging
└── apps/             # Sparse workspace-side artifacts, not the main app repo
```

## Directory Purposes

**`TRR-Backend/`:**
- FastAPI surface in `TRR-Backend/api/`
- Domain/repository/service code in `TRR-Backend/trr_backend/`
- Schema ownership in `TRR-Backend/supabase/migrations/`
- Backend tests in `TRR-Backend/tests/`

**`TRR-APP/`:**
- Main app in `TRR-APP/apps/web/`
- Secondary Vue app in `TRR-APP/apps/vue-wordle/`
- Repo-level package management in `TRR-APP/package.json`
- App tests in `TRR-APP/apps/web/tests/`

**`screenalytics/`:**
- API in `screenalytics/apps/api/`
- Streamlit UI in `screenalytics/apps/workspace-ui/`
- Reusable analytics package in `screenalytics/packages/py-screenalytics/`
- Pipeline/tool entrypoints in `screenalytics/tools/`
- Tests in `screenalytics/tests/`

**`scripts/`:**
- Workspace startup, teardown, checks, browser wrappers, handoff sync, and validation helpers

**`docs/`:**
- `docs/workspace/` for runtime contracts and dev commands
- `docs/cross-collab/` for multi-repo workflow and task artifacts
- `docs/ai/` for handoff and local-status coordination

**`.planning/`:**
- Project and milestone planning context
- Generated codebase map docs in `.planning/codebase/`

## Key File Locations

**Workspace entrypoints:**
- `Makefile`
- `scripts/dev-workspace.sh`
- `scripts/preflight.sh`
- `scripts/handoff-lifecycle.sh`

**Backend entrypoints:**
- `TRR-Backend/api/main.py`
- `TRR-Backend/trr_backend/cli/__main__.py`

**App entrypoints:**
- `TRR-APP/apps/web/src/app/layout.tsx`
- `TRR-APP/apps/web/src/app/page.tsx`
- `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`

**Screenalytics entrypoints:**
- `screenalytics/apps/api/main.py`
- `screenalytics/apps/workspace-ui/streamlit_app.py`
- `screenalytics/tools/episode_run.py`

## Naming Conventions

**Files:**
- Python uses `snake_case.py`
- React components use `PascalCase.tsx`
- Next.js route tree uses framework filenames like `page.tsx`, `layout.tsx`, and `route.ts`
- Streamlit pages use numeric prefixes like `screenalytics/apps/workspace-ui/pages/4_Screentime.py`
- Tests use `test_*.py`, `*.test.ts`, `*.test.tsx`, and `*.spec.ts`

**Directories:**
- Repo roots are ownership boundaries
- Backend splits transport (`api/`) from reusable domain logic (`trr_backend/`)
- App splits route tree (`src/app/`) from components and server helpers
- Screenalytics splits API/UI surfaces from reusable package and tools

## Where to Add New Code

**New backend contract or schema work:**
- HTTP route: `TRR-Backend/api/routers/`
- Service or repository logic: `TRR-Backend/trr_backend/services/` or `TRR-Backend/trr_backend/repositories/`
- Schema change: add a new file in `TRR-Backend/supabase/migrations/`

**New app feature:**
- Route/page: `TRR-APP/apps/web/src/app/`
- Shared UI: `TRR-APP/apps/web/src/components/`
- Server helper/proxy: `TRR-APP/apps/web/src/lib/server/`

**New screenalytics workflow:**
- API route/service: `screenalytics/apps/api/routers/` and `screenalytics/apps/api/services/`
- Operator UI page: `screenalytics/apps/workspace-ui/pages/`
- Pipeline/tool logic: `screenalytics/tools/` or `screenalytics/packages/py-screenalytics/src/py_screenalytics/`

**New workspace orchestration or policy:**
- Script entrypoint: `scripts/`
- Shared shell helper: `scripts/lib/`
- Contract or workflow doc: `docs/workspace/` or `docs/cross-collab/`

## Navigation Guide

**Start here for repo coordination:**
- `AGENTS.md`
- `docs/cross-collab/WORKFLOW.md`
- `docs/workspace/env-contract.md`

**Start here for backend contract work:**
- `TRR-Backend/api/main.py`
- `TRR-Backend/api/routers/`
- `TRR-Backend/trr_backend/repositories/`
- `TRR-Backend/supabase/migrations/`

**Start here for app/backend integration:**
- `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- `TRR-APP/apps/web/src/app/api/`
- `TRR-APP/apps/web/src/lib/server/`

**Start here for analytics flows:**
- `screenalytics/apps/api/main.py`
- `screenalytics/apps/api/services/supabase_db.py`
- `screenalytics/tools/episode_run.py`

**Start here for planning state:**
- `.planning/PROJECT.md`
- `.planning/active-workstream`
- `.planning/workstreams/`

## Special Directories

**`.planning/codebase/`:**
- Generated reference docs for later planning/execution
- Committed to the workspace repo

**`TRR-Backend/supabase/migrations/`:**
- Canonical shared database history
- High-risk change area because other repos consume the resulting contract

**`screenalytics/FEATURES/`:**
- Long-running feature incubators and subsystem-focused work

**`apps/`:**
- Workspace-side artifact area only
- Not the authoritative source for the main TRR app

---

*Structure analysis refreshed: 2026-04-07*
