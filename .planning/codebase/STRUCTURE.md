# Codebase Structure

**Analysis Date:** 2026-04-09

## Directory Layout

```text
TRR/
├── `TRR-Backend/`       # Canonical backend API, domain code, and Supabase migrations
├── `screenalytics/`     # ML pipeline, Screenalytics API, operator UIs, and pipeline packages
├── `TRR-APP/`           # Next.js product/admin app plus small secondary Vue app
├── `docs/`              # Workspace-wide workflow, env, governance, and handoff docs
├── `scripts/`           # Workspace launchers, validation scripts, Chrome/MCP wrappers
├── `.planning/codebase/`# Generated codebase maps used by GSD planning/execution
└── `apps/web/`          # Workspace-level stub directory; not the main TRR web app
```

## Directory Purposes

**Workspace Root:**
- Purpose: coordinate multi-repo work and shared developer workflows.
- Contains: `Makefile`, `docs/`, `scripts/`, `.planning/`, repo directories.
- Key files: `Makefile`, `docs/cross-collab/WORKFLOW.md`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`

**`TRR-Backend/api/`:**
- Purpose: FastAPI request surface.
- Contains: `main.py`, auth/deps modules, realtime helpers, and router modules under `TRR-Backend/api/routers/`
- Key files: `TRR-Backend/api/main.py`, `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`

**`TRR-Backend/trr_backend/`:**
- Purpose: backend implementation layer.
- Contains: `db/`, `repositories/`, `services/`, `integrations/`, `socials/`, `media/`, `security/`, `middleware/`
- Key files: `TRR-Backend/trr_backend/db/connection.py`, `TRR-Backend/trr_backend/job_plane.py`, `TRR-Backend/trr_backend/modal_dispatch.py`, `TRR-Backend/trr_backend/security/internal_admin.py`

**`TRR-Backend/supabase/`:**
- Purpose: database ownership boundary.
- Contains: additive SQL migrations and Supabase config.
- Key files: `TRR-Backend/supabase/config.toml`, `TRR-Backend/supabase/migrations/`

**`TRR-Backend/scripts/`:**
- Purpose: backend-only operations and maintenance tooling.
- Contains: sync, import, backfill, media, socials, verify, modal, and db helper scripts.
- Key files: `TRR-Backend/scripts/reload_postgrest_schema.sh`, `TRR-Backend/scripts/sync/`, `TRR-Backend/scripts/socials/`, `TRR-Backend/scripts/verify/`

**`screenalytics/apps/api/`:**
- Purpose: Screenalytics API surface.
- Contains: `main.py`, routers, schemas, config, tasks, and service modules.
- Key files: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/api/services/`

**`screenalytics/apps/workspace-ui/`:**
- Purpose: Streamlit-based operator UI.
- Contains: `streamlit_app.py`, numbered `pages/`, UI components, and session helpers.
- Key files: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/`

**`screenalytics/py_screenalytics/` and `screenalytics/packages/py-screenalytics/`:**
- Purpose: reusable pipeline and library code outside HTTP/router concerns.
- Contains: pipeline config, run layout, artifacts, backend helpers, and shared runtime logic.
- Key files: `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_config.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`

**`screenalytics/config/`:**
- Purpose: runtime and pipeline configuration.
- Contains: `pipeline/`, env config, model config, and cast-screentime golden data.
- Key files: `screenalytics/config/pipeline/`, `screenalytics/config/env/`

**`screenalytics/tests/`:**
- Purpose: screenalytics coverage by API, ML, integration, UI, and tooling areas.
- Contains: `unit/`, `ml/`, `integration/`, `api/`, `ui/`, `helpers/`
- Key files: `screenalytics/tests/unit/`, `screenalytics/tests/ml/`, `screenalytics/tests/integration/`

**`screenalytics/web/`:**
- Purpose: optional Next.js prototype for Screenalytics itself.
- Contains: app routes, generated API schema client, and web-only components.
- Key files: `screenalytics/web/package.json`, `screenalytics/web/api/`, `screenalytics/web/app/`

**`TRR-APP/apps/web/`:**
- Purpose: primary Next.js app deployed to Vercel.
- Contains: `src/app/` routes, `src/lib/` helpers, `src/components/`, tests, and scripts.
- Key files: `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/src/proxy.ts`

**`TRR-APP/apps/web/src/app/`:**
- Purpose: App Router entrypoints for public pages, admin pages, and route handlers.
- Contains: public routes, admin routes, and API handlers under `TRR-APP/apps/web/src/app/api/`
- Key files: `TRR-APP/apps/web/src/app/admin/`, `TRR-APP/apps/web/src/app/api/admin/`, `TRR-APP/apps/web/src/app/[showId]/`

**`TRR-APP/apps/web/src/lib/server/`:**
- Purpose: server-only app logic and BFF integration layer.
- Contains: admin repositories, auth, survey repositories, backend proxy helpers, and validation helpers.
- Key files: `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/lib/server/admin/`, `TRR-APP/apps/web/src/lib/server/trr-api/`

**`TRR-APP/apps/web/scripts/`:**
- Purpose: app-local generation and maintenance scripts.
- Contains: design-docs tooling, font tooling, admin reference generation, and app-local DB helper scripts.
- Key files: `TRR-APP/apps/web/scripts/design-docs/`, `TRR-APP/apps/web/scripts/generate-admin-api-references.mjs`, `TRR-APP/apps/web/scripts/cast-smoke-preflight.mjs`

**`TRR-APP/apps/vue-wordle/`:**
- Purpose: secondary Vue app with isolated maintenance workflow.
- Contains: Vite/Vue source and its own `npm` lockfile.
- Key files: `TRR-APP/apps/vue-wordle/package.json`, `TRR-APP/apps/vue-wordle/src/`

**`docs/`:**
- Purpose: workspace-level policies and implementation continuity.
- Contains: `workspace/`, `cross-collab/`, `agent-governance/`, `ai/`, plans, diagrams, and proposals.
- Key files: `docs/workspace/dev-commands.md`, `docs/workspace/chrome-devtools.md`, `docs/cross-collab/WORKFLOW.md`, `docs/ai/HANDOFF_WORKFLOW.md`

**`scripts/`:**
- Purpose: workspace-wide automation.
- Contains: dev startup, test runners, policy checks, browser/MCP wrappers, handoff sync, and status helpers.
- Key files: `scripts/dev-workspace.sh`, `scripts/status-workspace.sh`, `scripts/handoff-lifecycle.sh`, `scripts/new-cross-collab-task.sh`, `scripts/codex-chrome-devtools-mcp.sh`

## Key File Locations

**Entry Points:**
- `Makefile`: workspace command contract for startup, tests, health, and policy checks.
- `scripts/dev-workspace.sh`: canonical cross-repo process launcher.
- `TRR-Backend/api/main.py`: backend FastAPI app entry point.
- `TRR-Backend/start-api.sh`: backend launcher used outside the workspace wrapper.
- `screenalytics/apps/api/main.py`: Screenalytics FastAPI entry point.
- `screenalytics/apps/workspace-ui/streamlit_app.py`: Streamlit UI entry point.
- `screenalytics/scripts/dev.sh`: repo-local Screenalytics dev launcher.
- `TRR-APP/apps/web/src/app/layout.tsx`: App Router root for the main TRR web app.
- `TRR-APP/apps/web/src/proxy.ts`: host/path normalization layer for TRR-APP.

**Configuration:**
- `docs/workspace/env-contract.md`: workspace runtime env reference.
- `profiles/*.env`: workspace startup profiles loaded by `scripts/dev-workspace.sh`.
- `TRR-Backend/supabase/config.toml`: backend Supabase project config.
- `screenalytics/config/pipeline/`: Screenalytics stage and profile tuning.
- `TRR-APP/pnpm-workspace.yaml`: app repo workspace package layout.

**Core Logic:**
- `TRR-Backend/trr_backend/repositories/`: backend SQL and data access modules.
- `TRR-Backend/trr_backend/services/`: backend orchestration and service helpers.
- `TRR-Backend/trr_backend/socials/`: platform-specific social ingestion/runtime code.
- `screenalytics/apps/api/services/`: Screenalytics orchestration, storage, runtime, and sync helpers.
- `screenalytics/py_screenalytics/` and `screenalytics/packages/py-screenalytics/`: reusable pipeline implementation.
- `TRR-APP/apps/web/src/lib/server/admin/`: admin-oriented server repositories and caches.
- `TRR-APP/apps/web/src/lib/server/trr-api/`: backend URL/auth/proxy helpers for TRR contracts.

**Testing:**
- `TRR-Backend/tests/`: backend tests split by API, repositories, integrations, socials, services, and migrations.
- `screenalytics/tests/`: Screenalytics tests split by `unit`, `ml`, `integration`, `api`, and `ui`.
- `TRR-APP/apps/web/tests/`: Vitest-heavy route/component/server helper coverage for the Next.js app.

## Important Modules

**Backend HTTP Surface:**
- `TRR-Backend/api/routers/socials.py`: large social/admin router; central social ingestion and analytics entry point.
- `TRR-Backend/api/routers/admin_*.py`: admin feature surfaces grouped by domain.
- `TRR-Backend/api/routers/screenalytics.py`: narrow bridge endpoints for Screenalytics bootstrap reads.

**Backend Runtime Infrastructure:**
- `TRR-Backend/trr_backend/db/connection.py`: canonical DB URL and lane resolution.
- `TRR-Backend/trr_backend/job_plane.py`: local vs remote long-job execution selection.
- `TRR-Backend/trr_backend/modal_dispatch.py`: Modal integration for remote job execution.

**Screenalytics Pipeline Surface:**
- `screenalytics/apps/api/routers/episodes.py`: central episode/pipeline router and the largest Screenalytics entry module.
- `screenalytics/apps/api/services/pipeline_orchestration.py`: ordered stage orchestration.
- `screenalytics/apps/api/services/episodes_trr_sync.py`: TRR metadata sync for Screenalytics episode/cast workflows.

**TRR-APP BFF Surface:**
- `TRR-APP/apps/web/src/lib/server/auth.ts`: admin/user auth gate, allowlists, and provider switching.
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`: standard backend read proxy and timeout normalization.
- `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`: specialized proxy for social/admin flows.
- `TRR-APP/apps/web/src/lib/server/admin/`: page-level repositories that prepare data for admin pages and route handlers.

## Naming Conventions

**Files:**
- Python backend and Screenalytics modules use `snake_case.py`: `TRR-Backend/api/routers/admin_show_news.py`, `screenalytics/apps/api/services/run_state.py`
- Next.js route files use App Router conventions: `page.tsx`, `layout.tsx`, `route.ts`, `loading.tsx`, `error.tsx`
- Dynamic route segments use bracket syntax: `TRR-APP/apps/web/src/app/[showId]/`, `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/route.ts`
- SQL migrations are strictly additive and numerically ordered in `TRR-Backend/supabase/migrations/`

**Directories:**
- Backend and Screenalytics organize by technical layer first: `routers/`, `services/`, `repositories/`, `integrations/`
- TRR-APP organizes UI by route surface first under `TRR-APP/apps/web/src/app/`, then by helper domain under `TRR-APP/apps/web/src/lib/`
- Streamlit pages are prefixed numerically in `screenalytics/apps/workspace-ui/pages/` to control sidebar order.

## Cross-Repo Navigation Guidance

**Find the source of truth first:**
- Schema or DB contract questions start in `TRR-Backend/supabase/migrations/` and then move to `TRR-Backend/trr_backend/repositories/`.
- Shared API contract questions start in `TRR-Backend/api/routers/` and only then move to downstream consumers.
- Screenalytics pipeline behavior starts in `screenalytics/apps/api/routers/` plus `screenalytics/apps/api/services/`, then in reusable pipeline code under `screenalytics/packages/py-screenalytics/`.
- TRR-APP admin/UI behavior starts in `TRR-APP/apps/web/src/app/` and then drops into `TRR-APP/apps/web/src/lib/server/`.

**Follow cross-repo request paths in this order:**
1. `TRR-APP/apps/web/src/app/api/admin/...` or `TRR-APP/apps/web/src/lib/server/...`
2. `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and proxy/auth helpers
3. `TRR-Backend/api/routers/...`
4. `TRR-Backend/trr_backend/repositories/...` or `screenalytics/apps/api/services/...`
5. `TRR-Backend/supabase/migrations/...` if data shape is involved

**Avoid common workspace confusion:**
- The main TRR web app is `TRR-APP/apps/web/`, not the workspace root stub at `apps/web/`.
- `screenalytics/web/` is a Screenalytics-specific prototype app, not the same app as `TRR-APP/apps/web/`.
- Workspace policy and handoff flow live in root `docs/` and `scripts/`; repo-local `AGENTS.md` files refine behavior inside each repo.

## Where to Add New Code

**New Backend Endpoint:**
- Primary code: `TRR-Backend/api/routers/<domain>.py`
- Domain/data helpers: `TRR-Backend/trr_backend/repositories/` or `TRR-Backend/trr_backend/services/`
- Tests: `TRR-Backend/tests/api/routers/` plus the matching domain test area

**New Database Schema or View:**
- Primary code: `TRR-Backend/supabase/migrations/<next_migration>.sql`
- Verification helpers: `TRR-Backend/scripts/db/` or `TRR-Backend/scripts/verify/`

**New Screenalytics API Feature:**
- HTTP surface: `screenalytics/apps/api/routers/<domain>.py`
- Service logic: `screenalytics/apps/api/services/<domain>.py`
- Pipeline/package logic: `screenalytics/py_screenalytics/` or `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Tests: `screenalytics/tests/unit/`, `screenalytics/tests/api/`, or `screenalytics/tests/ml/` based on scope

**New Screenalytics Operator UI Page:**
- Implementation: `screenalytics/apps/workspace-ui/pages/<N>_<Name>.py`
- Shared UI pieces: `screenalytics/apps/workspace-ui/components/`

**New TRR-APP Page or Route:**
- Public/admin page: `TRR-APP/apps/web/src/app/.../page.tsx`
- Route handler/BFF endpoint: `TRR-APP/apps/web/src/app/api/.../route.ts`
- Server-side integration helper: `TRR-APP/apps/web/src/lib/server/admin/` or `TRR-APP/apps/web/src/lib/server/trr-api/`
- Tests: `TRR-APP/apps/web/tests/`

**New Workspace Automation or Process Doc:**
- Script: `scripts/`
- Workflow/env/policy doc: `docs/workspace/`, `docs/cross-collab/`, or `docs/agent-governance/`
- Planning artifact: `.planning/`

## Special Directories

**`.planning/codebase/`:**
- Purpose: generated codebase maps used by GSD planning and execution.
- Generated: Yes
- Committed: Yes

**`docs/ai/local-status/`:**
- Purpose: canonical local continuity notes that feed generated handoff output.
- Generated: No
- Committed: Yes

**`TRR-APP/apps/web/.next/`:**
- Purpose: Next.js build/dev output for the main app.
- Generated: Yes
- Committed: No

**`screenalytics/data/`:**
- Purpose: local runtime artifacts, manifests, embeds, media, and pipeline outputs.
- Generated: Yes
- Committed: No

**`TRR-Backend/supabase/migrations/`:**
- Purpose: additive database history owned by the backend repo.
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-09*
