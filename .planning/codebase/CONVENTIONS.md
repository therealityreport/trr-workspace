# TRR Workspace Conventions

## Scope

This document captures recurring coding, naming, and operational conventions that are visible in the current workspace and reinforced by the checked-in `AGENTS.md` files.

## Cross-Repo Conventions

### Backend-First Shared Contracts

- Shared API, auth, DB, and schema changes land in `TRR-Backend/` first
- `screenalytics/` adapts second
- `TRR-APP/` updates consumers last

This is an explicit workspace rule in `AGENTS.md`, not just a habit.

### Canonical Environment Names

Important shared env names are stable and reused across repos:

- `TRR_DB_URL`
- `TRR_DB_FALLBACK_URL`
- `TRR_API_URL`
- `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `SCREENALYTICS_SERVICE_TOKEN`

The codebase consistently prefers canonical names over ad hoc aliases and validates them early in startup paths.

### Secret Handling

- Secret contracts are referenced by name, not value
- Service auth is enforced through shared headers or tokens rather than inline credentials
- Workspace policy explicitly forbids printing or committing secret values

### File Ownership

- Shared policy and workflow live at the workspace root
- Repo-specific implementation rules live in each repo’s `AGENTS.md`
- `CLAUDE.md` files are intentionally pointer-only

## `TRR-Backend` Conventions

### Python Style

- Ruff is the main linting/formatting contract in `TRR-Backend/ruff.toml`
- Target Python is `py311`
- Line length is `120`
- Double quotes are preferred
- Imports are sorted with Ruff/isort

### Router Patterns

- Admin APIs mostly use `APIRouter` prefixes such as `/admin`, `/admin/shows`, `/admin/brands`, or `/admin/trr-api`
- Public APIs sit under domain-oriented routers like `shows`, `surveys`, `dms`, and `discussions`
- Router modules are feature-heavy and often include validation, orchestration, and response-shaping together

### Startup and Runtime Guardrails

- Startup performs explicit env validation in `TRR-Backend/api/main.py`
- Database connection lanes are validated centrally, not at arbitrary query sites
- Internal admin auth and Screenalytics auth have dedicated modules in `TRR-Backend/api/auth.py` and `TRR-Backend/api/screenalytics_auth.py`

### Migration Discipline

- Existing migrations are additive and sequential in `TRR-Backend/supabase/migrations/`
- Repo policy says not to edit old migrations; add new ones instead

## `TRR-APP` Conventions

### Server vs Client Separation

- Server-only logic is intentionally placed under `TRR-APP/apps/web/src/lib/server/`
- `"use client"` is added only when interaction requires it
- `import "server-only";` is used in sensitive server modules such as `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`

### App Router Structure

- Route files follow App Router naming with `page.tsx`, `layout.tsx`, and `route.ts`
- Dynamic segments are heavily used for public and admin navigation
- Proxy/API routes live under `src/app/api/`

### Auth and Proxy Boundaries

- App code does not invent backend contracts; it follows `TRR_API_URL` and backend admin proxy helpers
- Admin trust is established via `TRR_INTERNAL_ADMIN_SHARED_SECRET` and server-side token/header helpers
- Firebase config is split into client and admin paths

### Frontend Testing and Naming

- Test names are descriptive and concern-focused, for example `admin-route-aliases.test.ts` and `person-refresh-progress.test.ts`
- Route and wiring tests are common, indicating a convention of validating URL shape and server-proxy behavior directly

## `screenalytics` Conventions

### Python Formatting

- Ruff and Black are both configured in `screenalytics/pyproject.toml`
- Line length is `120`
- Some common Python lint rules are intentionally relaxed to accommodate runtime setup and pipeline code

### Runtime Initialization

- `.env` loading happens early in entrypoints such as `screenalytics/apps/api/main.py` and `screenalytics/apps/workspace-ui/streamlit_app.py`
- Global CPU limits are applied before heavy ML imports via `apps.common.cpu_limits`
- Streamlit page config must be the first Streamlit call, and repo policy reinforces that

### Service Layering

- Routers are relatively thin compared with the service layer in `screenalytics/apps/api/services/`
- Storage, observability, locking, pipeline state, and run persistence each have dedicated service modules
- Optional features such as v2 APIs and Celery are feature-gated at startup

### Artifact Safety

- Repo policy discourages silent overwrite of artifacts, embeddings, and facebank data
- Many tests focus on idempotency, locking, progress reporting, and recovery behavior

## Testing Conventions

Observed testing conventions:

- Python repos use pytest
- Frontend/unit tests use Vitest
- Browser flows use Playwright
- Test names describe the route, behavior, or regression being protected
- Specialized tests are separated by concern, for example `tests/api/`, `tests/ml/`, `tests/audio/`, `tests/integration/`

## Operational Conventions

### Validation Commands

Workspace policy standardizes fast checks:

- `TRR-Backend`: `ruff check . && ruff format --check . && pytest -q`
- `screenalytics`: `pytest -q`
- `TRR-APP`: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`

### Browser Validation

- Authenticated UI verification is expected through managed Chrome tooling and `chrome-devtools`
- Browser defaults are centralized in workspace scripts rather than duplicated per repo

### Documentation and Status

- Handoff/status docs belong in workspace-managed docs locations, not ad hoc scratch files
- `.planning/` is used for agent-readable planning state and maps

## Convention Read

The workspace favors explicit guardrails over implicit team norms:

- canonical env names
- strict server/client boundaries
- backend-first contract ownership
- startup validation
- feature-oriented route organization
- testing by user-visible or contract-visible behavior

Those conventions make the codebase easier to reason about, but they also mean changes that bypass the established boundaries usually create drift quickly.
