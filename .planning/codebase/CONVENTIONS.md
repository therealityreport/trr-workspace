# Coding Conventions

**Analysis Date:** 2026-04-06

## Naming Patterns

**Files:**
- Use `snake_case.py` for Python implementation and test files in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `screenalytics/apps/api/`, `screenalytics/apps/workspace-ui/`, and `screenalytics/tests/`. Examples: `TRR-Backend/trr_backend/repositories/admin_operations.py`, `screenalytics/apps/api/services/trr_metadata_db.py`, `screenalytics/tests/unit/test_defaults_format.py`.
- Use framework-owned route filenames in Next.js App Router under `TRR-APP/apps/web/src/app/`: `page.tsx`, `layout.tsx`, and `route.ts`. Examples: `TRR-APP/apps/web/src/app/admin/page.tsx`, `TRR-APP/apps/web/src/app/api/debug-log/route.ts`.
- Use `PascalCase.tsx` for React components and `camelCase.ts` or domain-specific kebab-free module names for helpers in `TRR-APP/apps/web/src/components/` and `TRR-APP/apps/web/src/lib/`. Examples: `TRR-APP/apps/web/src/components/admin/AdminGlobalHeader.tsx`, `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts`.
- Keep Streamlit page files numerically prefixed to control menu order in `screenalytics/apps/workspace-ui/pages/`. Examples: `screenalytics/apps/workspace-ui/pages/0_Shows.py`, `screenalytics/apps/workspace-ui/pages/4_Screentime.py`.
- Use `test_*.py` for pytest files in Python repos and `*.test.ts` / `*.test.tsx` / `*.spec.ts` for the app. Examples: `TRR-Backend/tests/db/test_connection_resolution.py`, `TRR-APP/apps/web/tests/people-home-route.test.ts`, `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts`.

**Functions:**
- Use `snake_case` for Python functions, helpers, and fixtures. Examples: `TRR-Backend/api/main.py:_validate_startup_config`, `screenalytics/apps/api/errors.py:install_error_handlers`, `screenalytics/tests/conftest.py:configure_celery_eager`.
- Use `camelCase` for TypeScript functions and hooks, and `PascalCase` for React components. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts:getBackendApiUrl`, `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts:fetchWithTimeout`, `TRR-APP/apps/web/src/components/admin/AdminGlobalHeader.tsx:AdminGlobalHeader`.

**Variables:**
- Use `UPPER_CASE` for constants, environment keys, and immutable config blobs. Examples: `TRR-Backend/api/main.py:_LOCAL_RUNTIME_MARKERS`, `TRR-APP/apps/web/src/app/admin/page.tsx:RECENT_UPDATES`, `screenalytics/apps/api/services/supabase_db.py:TRR_DB_URL_ENV`.
- Use descriptive, domain-specific names instead of generic `data` when shaping boundary payloads. Examples: `operation_stream_response` payloads in `TRR-Backend/api/routers/admin_operations.py`, `AdminNormalizedError` fields in `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts`, and TRR health payload keys in `screenalytics/apps/api/routers/metadata.py`.

**Types:**
- Keep boundary models close to the boundary they validate.
  - FastAPI request and response shapes use Pydantic `BaseModel` in router files such as `TRR-Backend/api/routers/admin_operations.py` and `screenalytics/apps/api/routers/metadata.py`.
  - TypeScript API and UI contracts use exported `type` / `interface` declarations in the module that consumes them, as in `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts` and `TRR-APP/apps/web/src/lib/server/auth.ts`.

## Code Style

**Formatting:**
- `TRR-Backend` uses Ruff formatting with Python 3.11 targeting, 120-column lines, double quotes, and space indentation as configured in `TRR-Backend/ruff.toml`.
- `screenalytics` uses Ruff plus Black-compatible line length at 120 columns from `screenalytics/pyproject.toml`.
- `TRR-APP` does not have Prettier or Biome configured in the workspace files inspected. Follow existing file-local style in `TRR-APP/apps/web/`, which consistently uses semicolons and usually 2-space indentation, while quotes may vary by file.

**Linting:**
- `TRR-Backend` enables Ruff rules `E`, `F`, `I`, `N`, `UP`, `B`, and `C4`, with FastAPI-specific allowance for `B008` in `TRR-Backend/ruff.toml`.
- `screenalytics` keeps broader Python compatibility by explicitly ignoring `E402`, `F841`, and `E731` in `screenalytics/pyproject.toml`, which matches code that adjusts `sys.path` before imports in files like `screenalytics/tests/conftest.py`.
- `TRR-APP/apps/web/eslint.config.mjs` extends Next core-web-vitals and TypeScript presets, forbids raw `<img>` with `@next/next/no-img-element`, and relaxes a few React hook compiler rules for the current codebase.
- `TRR-APP/apps/web/tsconfig.json` runs in `strict` mode. New server and client code should stay type-safe enough to pass `pnpm run typecheck`.

## Import Organization

**Order:**
1. Python files start with `from __future__ import annotations` when the module uses forward refs or modern typing. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`.
2. Group imports by standard library, third-party framework, then local packages. This pattern is visible in `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`, and `TRR-Backend/trr_backend/observability.py`.
3. In the app, import framework/runtime markers first, then framework packages, then alias imports from `@/`, then relative imports. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` begins with `import "server-only";`; `TRR-APP/apps/web/src/app/admin/page.tsx` imports Next modules before `@/components` and `@/lib`.

**Path Aliases:**
- Use the `@/*` alias defined in `TRR-APP/apps/web/tsconfig.json` for app-local imports instead of deep relative paths.
- Python tests in `screenalytics/tests/conftest.py` and `screenalytics/apps/workspace-ui/tests/conftest.py` explicitly add project roots to `sys.path`; follow existing helpers instead of inventing new import hacks.

## Error Handling

**Patterns:**
- `TRR-Backend` route handlers commonly:
  - validate request payloads with Pydantic models or FastAPI `Query` constraints,
  - catch `ValueError` and translate it to `HTTPException(status_code=400, ...)`,
  - log unexpected exceptions with `logger.exception(...)`,
  - rethrow `HTTPException(status_code=500, detail=str(exc))`.
  - Example: `TRR-Backend/api/routers/admin_operations.py`.
- `screenalytics` centralizes API error envelopes through `screenalytics/apps/api/errors.py`. New API routers should rely on `install_error_handlers(app)` from `screenalytics/apps/api/main.py` instead of returning ad hoc error shapes.
- `TRR-APP` server handlers usually return `NextResponse.json(...)` with explicit status codes and minimal leakage. Sensitive payloads are redacted before logging in `TRR-APP/apps/web/src/app/api/debug-log/route.ts`.
- For runtime auth, prefer graceful failure to raw crashes. `TRR-APP/apps/web/src/lib/server/auth.ts` falls back between providers and returns `null` or `403` paths rather than exposing tokens or stack traces.

## Logging

**Framework:** `logging` in Python services, `console` on the Next.js side.

**Patterns:**
- In Python, declare `logger = logging.getLogger(__name__)` or `LOGGER = logging.getLogger(__name__)` near the top of the module. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`, `screenalytics/apps/api/services/supabase_db.py`.
- `TRR-Backend/trr_backend/observability.py` wires structured runtime logging, trace IDs, and optional Better Stack shipping. New backend runtime code should let this layer own handler setup rather than configuring logging ad hoc.
- `screenalytics/apps/api/main.py` binds `x-trace-id` / `x-request-id` in middleware. Preserve these headers in new API work when requests cross service boundaries.
- On the app side, use `console.warn` and `console.error` sparingly for server/runtime diagnostics, never for secrets. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`.

## Comments

**When to Comment:**
- Use comments for contract rules, runtime caveats, or boot-order constraints, not obvious line-by-line narration.
- Good current examples:
  - `TRR-Backend/api/main.py` explains startup lane validation and env safety.
  - `screenalytics/apps/api/main.py` and `screenalytics/apps/workspace-ui/streamlit_app.py` explain why `.env` loading and `st.set_page_config()` must happen before other imports/calls.
  - `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` documents why localhost normalization exists.

**JSDoc/TSDoc:**
- Python docstrings are common and should be preserved for public modules, helpers with policy, and API behavior. See `TRR-Backend/api/main.py`, `screenalytics/apps/api/services/trr_metadata_db.py`, and `screenalytics/apps/api/routers/metadata.py`.
- TypeScript relies more on types and targeted inline comments than full TSDoc. Follow that lighter style unless a module exposes a non-obvious contract.

## Function Design

**Size:** Use thin boundary functions when possible.
- Backend routers in `TRR-Backend/api/routers/` mostly delegate to repository or pipeline helpers.
- Screenalytics routers in `screenalytics/apps/api/routers/` usually delegate to `apps/api/services/`.
- App routes and server helpers in `TRR-APP/apps/web/src/app/api/` and `TRR-APP/apps/web/src/lib/server/` normalize contracts and auth, then defer to backend-facing helpers.

**Parameters:** Favor explicit keyword-style configuration at boundaries.
- Python code commonly takes named-only parameters and typed options, as in `TRR-Backend/trr_backend/repositories/admin_operations.py:create_or_attach_operation`.
- TypeScript request helpers use config objects instead of long positional argument lists, as in `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts`.

**Return Values:** Return structured dictionaries/objects, not tuple soup, unless attach-or-create semantics require it.
- Examples: operation payloads from `TRR-Backend/trr_backend/repositories/admin_operations.py`, `AdminNormalizedError` in `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts`, and TRR metadata responses in `screenalytics/apps/api/routers/metadata.py`.

## Module Design

**Exports:** 
- Use default exports for Next.js page and component modules. Examples: `TRR-APP/apps/web/src/app/admin/page.tsx`, `TRR-APP/apps/web/src/components/admin/AdminGlobalHeader.tsx`.
- Use named exports for utilities, service helpers, and test support modules. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `screenalytics/tests/helpers/workspace_ui_source.py`.

**Barrel Files:** 
- Barrel usage is selective, not global. Keep it that way.
  - Present: `TRR-APP/apps/web/src/components/survey/index.ts`, `TRR-Backend/api/routers/__init__.py`, `screenalytics/apps/api/services/__init__.py`.
  - Most domains import concrete modules directly; prefer direct imports unless a barrel already defines the contract surface.

## Config And Env Practices

- Treat `.env` files as runtime input only. Use tracked examples and generated docs for contract reference:
  - `TRR-Backend/.env.example`
  - `TRR-APP/apps/web/.env.example`
  - `screenalytics/.env.example`
  - `docs/workspace/env-contract.md`
  - `docs/workspace/env-deprecations.md`
- Runtime Postgres precedence is workspace-wide:
  - `TRR_DB_URL`
  - `TRR_DB_FALLBACK_URL`
  - Do not introduce new runtime dependence on `DATABASE_URL` or `SUPABASE_DB_URL`. Existing mentions are quarantined to tooling or compatibility checks, as documented in `docs/workspace/env-deprecations.md` and validated by tests like `TRR-Backend/tests/db/test_connection_resolution.py` and `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`.
- Backend base URLs are shared contracts, not local inventions.
  - `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` normalizes `TRR_API_URL` to `/api/v1`.
  - `SCREENALYTICS_API_URL` remains the screenalytics endpoint contract in tracked env examples and workspace launcher scripts such as `scripts/dev-workspace.sh`.
- Shared secrets stay named, never embedded:
  - `TRR_INTERNAL_ADMIN_SHARED_SECRET`
  - `SCREENALYTICS_SERVICE_TOKEN`
  - `ADMIN_EMAIL_ALLOWLIST`
  - `ADMIN_DISPLAYNAME_ALLOWLIST`
  - See `AGENTS.md`, `TRR-Backend/AGENTS.md`, `TRR-APP/AGENTS.md`, and `screenalytics/AGENTS.md`.
- Workspace startup owns the managed local loopback env surface. Use `make dev` / `scripts/dev-workspace.sh` instead of hand-exporting ad hoc values when reproducing the standard workspace lane.

## Agent Workflow Conventions

- Read instructions in order: workspace `AGENTS.md` first, then the active repo `AGENTS.md`, then any workflow docs they reference.
- For formal multi-phase work, run:
  - `scripts/handoff-lifecycle.sh pre-plan` before planning
  - `scripts/handoff-lifecycle.sh post-phase` after meaningful implementation phases
  - `scripts/handoff-lifecycle.sh closeout` at the end
  - Source: `scripts/handoff-lifecycle.sh`, `docs/cross-collab/WORKFLOW.md`, and `AGENTS.md`.
- Update canonical status sources, not generated handoffs:
  - `docs/cross-collab/TASK*/STATUS.md`
  - `docs/ai/local-status/*.md`
  - `docs/ai/HANDOFF.md` is generated by `scripts/sync-handoffs.py`.
- Cross-repo implementation order is fixed by policy:
  1. `TRR-Backend`
  2. `screenalytics`
  3. `TRR-APP`
  - Source: workspace `AGENTS.md` and `docs/cross-collab/WORKFLOW.md`.
- Verification expectations are part of the coding convention, not an afterthought.
  - `TRR-Backend`: `ruff check . && ruff format --check . && pytest -q`
  - `screenalytics`: `pytest -q` plus targeted `py_compile` / ML lanes
  - `TRR-APP`: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`
- Planning assets currently live under `.planning/workstreams/feature-b/` for the last shipped milestone, and that workstream is archived in `.planning/workstreams/feature-b/STATE.md`. There is no root `.planning/STATE.md` in the current workspace. New milestone work should start from `.planning/PROJECT.md` and the next milestone definition rather than reviving archived state.

---

*Convention analysis: 2026-04-06*
