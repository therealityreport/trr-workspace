# Codebase Structure

**Analysis Date:** 2026-04-08

## Directory Layout

```text
[project-root]/
├── TRR-Backend/         # Canonical API, schema, sync scripts, and shared backend library
├── TRR-APP/             # Next.js product and admin UI workspace
├── screenalytics/       # ML pipelines, Screenalytics API, Streamlit UI, optional web app
├── docs/                # Workspace-level policy, handoff, and cross-repo workflow docs
├── scripts/             # Workspace launch, contract, browser, and handoff scripts
├── profiles/            # Workspace startup profiles consumed by `scripts/dev-workspace.sh`
├── .planning/           # GSD planning artifacts, including this codebase map
└── Makefile             # Canonical workspace command surface
```

## Directory Purposes

**`TRR-Backend/`:**
- Purpose: Own the canonical data model, HTTP API, shared backend logic, and schema evolution.
- Contains: `api/`, `trr_backend/`, `supabase/`, `scripts/`, `tests/`, and backend-specific docs under `docs/`
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/start-api.sh`, `TRR-Backend/trr_backend/cli/__main__.py`, `TRR-Backend/supabase/migrations/`, `TRR-Backend/AGENTS.md`

**`TRR-APP/`:**
- Purpose: Own the Next.js user/admin frontend and its server-side integration layer.
- Contains: monorepo root config, `apps/web/` for the main app, `apps/vue-wordle/` for the secondary Vue app, repo docs, and helper scripts.
- Key files: `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/lib/server/`, `TRR-APP/AGENTS.md`

**`screenalytics/`:**
- Purpose: Own the Screenalytics processing stack, API, workspace UI, and optional web prototype.
- Contains: `apps/api/`, `apps/workspace-ui/`, `tools/`, `packages/py-screenalytics/`, `config/pipeline/`, `tests/`, `web/`, and extensive repo docs.
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/tools/episode_run.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/`, `screenalytics/AGENTS.md`

**`docs/`:**
- Purpose: Hold workspace-shared operating contracts that apply across repos.
- Contains: handoff docs in `docs/ai/`, policy docs in `docs/agent-governance/`, workflow docs in `docs/cross-collab/`, and workspace runtime docs in `docs/workspace/`
- Key files: `docs/cross-collab/WORKFLOW.md`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/ai/HANDOFF_WORKFLOW.md`

**`scripts/`:**
- Purpose: Implement the workspace’s executable orchestration layer.
- Contains: startup/stop wrappers, managed Chrome helpers, policy checks, env-contract tools, tests, and handoff sync automation.
- Key files: `scripts/dev-workspace.sh`, `scripts/bootstrap.sh`, `scripts/handoff-lifecycle.sh`, `scripts/check-workspace-contract.sh`, `scripts/sync-handoffs.py`

**`profiles/`:**
- Purpose: Store checked-in workspace startup defaults.
- Contains: environment profiles consumed by `scripts/dev-workspace.sh`
- Key files: `profiles/default.env`

**`.planning/`:**
- Purpose: Store planning-system state and generated workspace maps.
- Contains: milestone state, workstreams, research notes, and codebase docs in `.planning/codebase/`
- Key files: `.planning/PROJECT.md`, `.planning/MILESTONES.md`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`

## Key File Locations

**Entry Points:**
- `Makefile`: Workspace command entry point for startup, testing, policy, and handoff actions.
- `scripts/dev-workspace.sh`: Shared local runtime launcher for `TRR-Backend`, `TRR-APP`, and optional `screenalytics` services.
- `TRR-Backend/start-api.sh`: Backend runtime launcher that wraps `uvicorn api.main:app`.
- `TRR-Backend/api/main.py`: Backend `FastAPI` application composition root.
- `TRR-Backend/trr_backend/cli/__main__.py`: Backend CLI entry point.
- `TRR-APP/apps/web/src/app/layout.tsx`: Next.js App Router root layout.
- `TRR-APP/apps/web/src/app/page.tsx`: Main web landing route.
- `TRR-APP/apps/web/src/app/api/`: App-owned API route tree.
- `screenalytics/apps/api/main.py`: Screenalytics `FastAPI` application composition root.
- `screenalytics/apps/workspace-ui/streamlit_app.py`: Screenalytics Streamlit UI entry point.
- `screenalytics/tools/episode_run.py`: Screenalytics CLI pipeline entry point.

**Configuration:**
- `profiles/default.env`: Canonical `make dev` workspace profile.
- `docs/workspace/env-contract.md`: Generated workspace env contract.
- `TRR-Backend/requirements.txt`: Backend Python dependency lock surface.
- `TRR-APP/package.json`: App workspace root scripts and Node baseline.
- `TRR-APP/apps/web/package.json`: Main Next.js app scripts and dependencies.
- `screenalytics/pyproject.toml`: Screenalytics Python tooling configuration.
- `screenalytics/config/pipeline/`: Pipeline stage YAML configuration.

**Core Logic:**
- `TRR-Backend/trr_backend/`: Shared backend services, repositories, DB code, integrations, and pipeline orchestration.
- `TRR-Backend/api/routers/`: Backend HTTP route modules.
- `TRR-APP/apps/web/src/lib/server/`: Server-only integration logic, DB access, and backend proxy helpers.
- `TRR-APP/apps/web/src/components/`: Shared React component library for public and admin UI.
- `screenalytics/apps/api/services/`: Screenalytics business logic behind HTTP routes.
- `screenalytics/packages/py-screenalytics/src/py_screenalytics/`: Reusable pipeline and artifact library.
- `screenalytics/apps/workspace-ui/pages/`: Streamlit page-level workflows.
- `screenalytics/tools/`: CLI and operational tooling for runs, exports, and diagnostics.

**Testing:**
- `TRR-Backend/tests/`: Backend test tree organized by API, DB, scripts, repositories, services, socials, and security.
- `TRR-APP/apps/web/tests/`: Vitest, Playwright, fixtures, mocks, and survey-specific test assets.
- `screenalytics/tests/`: API, ML, UI, MCP, tools, and unit test coverage.
- `scripts/test-fast.sh`: Workspace-wide fast regression entry point.
- `scripts/test-full.sh`: Workspace-wide full regression entry point.

## Naming Conventions

**Files:**
- Backend Python modules use `snake_case.py`: `TRR-Backend/api/routers/admin_show_sync.py`, `TRR-Backend/trr_backend/clients/screenalytics.py`
- Next.js route modules use framework-reserved names: `page.tsx`, `layout.tsx`, `route.ts`
- Next.js server utilities often use `kebab-case.ts`: `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`
- React component files use `PascalCase.tsx` when they export components: `TRR-APP/apps/web/src/components/admin/UnifiedBrandsWorkspace.tsx`
- Streamlit pages use ordered numeric prefixes to control navigation: `screenalytics/apps/workspace-ui/pages/0_Shows.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`
- Workspace scripts use `kebab-case.sh` or `snake_case.py`: `scripts/dev-workspace.sh`, `scripts/sync-handoffs.py`

**Directories:**
- Repo roots are product names with stable casing: `TRR-Backend/`, `TRR-APP/`, `screenalytics/`
- Backend and screenalytics Python package directories use lower-case names: `trr_backend/`, `py_screenalytics/`, `apps/api/services/`
- Next.js feature directories mirror route segments: `TRR-APP/apps/web/src/app/admin/social/`, `TRR-APP/apps/web/src/app/api/admin/trr-api/`
- Cross-repo work folders use `TASK{N}` numbering under each repo’s `docs/cross-collab/`

## Where to Add New Code

**New Backend API surface:**
- Primary code: add the router in `TRR-Backend/api/routers/` and register it in `TRR-Backend/api/main.py`
- Domain logic: place shared service, repository, or client code under `TRR-Backend/trr_backend/services/`, `TRR-Backend/trr_backend/repositories/`, or `TRR-Backend/trr_backend/clients/`
- Tests: mirror the area in `TRR-Backend/tests/`

**New Backend schema or exposed SQL:**
- Primary code: add a migration under `TRR-Backend/supabase/migrations/`
- Documentation: keep generated or checked schema docs aligned in `TRR-Backend/supabase/schema_docs/` and repo docs under `TRR-Backend/docs/db/`
- Downstream follow-through: update `screenalytics/` readers and `TRR-APP/` consumers in the same session when contracts change

**New TRR-APP page or route:**
- Public page: add to `TRR-APP/apps/web/src/app/`
- Admin page: add to `TRR-APP/apps/web/src/app/admin/`
- API handler: add to `TRR-APP/apps/web/src/app/api/` or `TRR-APP/apps/web/src/app/api/admin/`
- Shared UI: place reusable components in `TRR-APP/apps/web/src/components/`

**New TRR-APP backend-backed admin proxy:**
- Route file: add the HTTP-facing handler under `TRR-APP/apps/web/src/app/api/admin/trr-api/` or another `api/admin/` subtree
- Proxy/helper code: centralize fetch logic in `TRR-APP/apps/web/src/lib/server/trr-api/`
- Server reads: if the feature is read-only and app-owned, prefer `TRR-APP/apps/web/src/lib/server/admin/` or `TRR-APP/apps/web/src/lib/server/surveys/`

**New screenalytics API or metadata read:**
- HTTP route: add under `screenalytics/apps/api/routers/`
- Business logic: add under `screenalytics/apps/api/services/`
- Shared DB reads: keep canonical metadata readers under `screenalytics/apps/api/services/trr_metadata_db.py` or adjacent metadata services

**New screenalytics pipeline stage or tooling:**
- Reusable pipeline logic: add under `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- CLI or operator tool: add under `screenalytics/tools/`
- Config: add or extend YAML under `screenalytics/config/pipeline/`
- UI exposure: wire the workflow into `screenalytics/apps/workspace-ui/pages/` or `screenalytics/apps/api/routers/`

**New shared workspace automation:**
- Executable behavior: add under `scripts/`
- Human-facing contract docs: add under `docs/workspace/` or `docs/cross-collab/`
- Profile defaults: add to `profiles/`
- Avoid placing shared workflow logic inside a single repo when it coordinates multiple repos.

## Special Directories

**`docs/ai/HANDOFF.md`:**
- Purpose: Generated workspace handoff index.
- Generated: Yes
- Committed: Yes

**`docs/ai/local-status/`:**
- Purpose: Canonical per-task status snapshots outside repo-specific `TASK*` folders.
- Generated: No
- Committed: Yes

**`TRR-Backend/docs/cross-collab/`, `TRR-APP/docs/cross-collab/`, `screenalytics/docs/cross-collab/`:**
- Purpose: Repo-local task folders for synchronized multi-repo work.
- Generated: No
- Committed: Yes

**`TRR-Backend/supabase/migrations/`:**
- Purpose: Canonical schema evolution history.
- Generated: No
- Committed: Yes

**`screenalytics/packages/py-screenalytics/`:**
- Purpose: Editable install package used by CLI, API, and tests.
- Generated: No
- Committed: Yes

**`screenalytics/data/`:**
- Purpose: Local artifacts, manifests, embeddings, jobs, and videos for pipeline runs.
- Generated: Yes
- Committed: Mixed; treat as runtime data, not a normal source directory

**`.logs/workspace/`:**
- Purpose: Workspace runtime and handoff logs.
- Generated: Yes
- Committed: No

**`.planning/codebase/`:**
- Purpose: Generated workspace reference docs consumed by later planning and execution steps.
- Generated: Yes
- Committed: Yes

---

*Structure analysis: 2026-04-08*
