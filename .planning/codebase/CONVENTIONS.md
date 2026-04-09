# Coding Conventions

**Analysis Date:** 2026-04-08

## Naming Patterns

**Files:**
- Use `snake_case.py` for Python modules, routers, services, and tests in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `TRR-Backend/tests/`, `screenalytics/apps/`, and `screenalytics/tests/`. Examples: `TRR-Backend/api/auth.py`, `TRR-Backend/tests/api/test_health.py`, `screenalytics/apps/api/services/run_validator.py`, `screenalytics/tests/api/test_trr_health.py`.
- Use `kebab-case.ts` and `kebab-case.tsx` for frontend libraries, route handlers, and tests in `TRR-APP/apps/web/src/` and `TRR-APP/apps/web/tests/`. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/validation/identifiers.ts`, `TRR-APP/apps/web/tests/backend-base.test.ts`.
- Use `PascalCase.tsx` for React component files under `TRR-APP/apps/web/src/components/`. Example: `TRR-APP/apps/web/src/components/admin/AdminBreadcrumbs.tsx`.
- Keep Next App Router route filenames as `route.ts` inside feature directories under `TRR-APP/apps/web/src/app/api/`. Example: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/health-dot/route.ts`.

**Functions:**
- Use `snake_case` for Python functions and helpers. Examples: `_validate_startup_config` in `TRR-Backend/api/main.py`, `validate_run_integrity` in `screenalytics/apps/api/services/run_validator.py`.
- Use `camelCase` for TypeScript functions and helpers. Examples: `getBackendApiBase` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `validateUsername` in `TRR-APP/apps/web/src/lib/validation/user.ts`.
- Prefix internal helpers with `_` in Python and with descriptive local constants/helpers in TypeScript. Examples: `_env_flag` in `TRR-Backend/api/auth.py`, `warnOnRemoteBackendBase` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

**Variables:**
- Use `UPPER_SNAKE_CASE` for module constants in Python and TypeScript. Examples: `_LOCAL_RUNTIME_MARKERS` in `TRR-Backend/api/main.py`, `UUID_RE` in `TRR-APP/apps/web/src/lib/server/validation/identifiers.ts`, `_SCENE_DETECTOR_ALIASES` in `screenalytics/apps/api/schemas/job_params.py`.
- Prefer descriptive locals over abbreviations. Examples: `screenalytics_api_url` in `TRR-Backend/api/main.py`, `normalizedPath` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

**Types:**
- Use `PascalCase` for Pydantic/FastAPI models and TypeScript types/interfaces. Examples: `Event` in `TRR-Backend/api/realtime/events.py`, `DetectTrackParams` in `screenalytics/apps/api/schemas/job_params.py`, `AdminBreadcrumbsProps` in `TRR-APP/apps/web/src/components/admin/AdminBreadcrumbs.tsx`.
- Keep response and payload types near the module that consumes them. Examples: `GenericBrandTargetRow` and related payload types in `TRR-APP/apps/web/src/lib/server/admin/brand-profile-repository.ts`.

## Code Style

**Formatting:**
- Python formatting is standardized with Ruff at 120 columns in `TRR-Backend/ruff.toml`, `TRR-APP/ruff.toml`, and `screenalytics/pyproject.toml`.
- Follow double quotes and four-space indentation for Python because the Ruff format settings are explicit in `TRR-Backend/ruff.toml` and `TRR-APP/ruff.toml`.
- TypeScript and TSX do not have a workspace Prettier config. Follow the local file style already present in the file you edit, then rely on ESLint and TypeScript checks for enforcement. Relevant configs: `TRR-APP/apps/web/eslint.config.mjs`, `TRR-APP/apps/web/tsconfig.json`, `screenalytics/web/.eslintrc.json`.

**Linting:**
- Python lint rules are Ruff-first. `TRR-Backend/ruff.toml` enables `E`, `F`, `I`, `N`, `UP`, `B`, and `C4`; `screenalytics/pyproject.toml` keeps Ruff plus Black-style line length and explicitly tolerates `E402`, `F841`, and `E731`.
- Frontend linting is ESLint-first. `TRR-APP/apps/web/eslint.config.mjs` layers `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`, keeps `@next/next/no-img-element` at `error`, and relaxes selected React Hooks rules.
- `screenalytics/web/.eslintrc.json` extends `next/core-web-vitals` and warns on `console` except `console.warn` and `console.error`.

## Import Organization

**Order:**
1. Future imports first in Python modules. Examples: `from __future__ import annotations` in `TRR-Backend/api/main.py` and `screenalytics/apps/api/services/run_validator.py`.
2. Standard library imports next.
3. Third-party packages after standard library.
4. Local repo imports last.

**Path Aliases:**
- Use `@/*` for TRR-APP internal imports because it is declared in `TRR-APP/apps/web/tsconfig.json`.
- Prefer direct repo-relative imports in Python packages. Examples: `from trr_backend.db import pg` in `TRR-Backend/api/main.py`, `from apps.api.services.run_state import run_state_service` in `screenalytics/apps/api/services/run_validator.py`.

**Practical Pattern:**
- Keep type-only imports explicit in TS when helpful. Example: `import type { Route } from "next";` in `TRR-APP/apps/web/src/components/admin/AdminBreadcrumbs.tsx`.
- Keep `"server-only"` imports at the top of server-only modules in TRR-APP. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/admin/brand-profile-repository.ts`.

## Error Handling

**Patterns:**
- Raise `HTTPException` with safe client-facing messages in `TRR-Backend/api/auth.py` and `TRR-Backend/api/deps.py`; log internal details separately with `logger`.
- Centralize API error envelopes in screenalytics via `screenalytics/apps/api/errors.py`. That module converts `HTTPException`, `RequestValidationError`, and unexpected exceptions into `{code, message, details}` payloads.
- In TRR-APP route handlers, catch server-side failures and return a normalized proxy response instead of leaking raw errors. Example: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/health-dot/route.ts` delegates to `socialProxyErrorResponse(...)`.
- Prefer helper wrappers over repeated inline error logic. Examples: `raise_for_supabase_error` and `require_single_result` in `TRR-Backend/api/deps.py`.

## Validation

**Patterns:**
- Use Pydantic models and validators for Screenalytics request payloads. `screenalytics/apps/api/schemas/job_params.py` uses `ConfigDict(extra="forbid")`, `@field_validator`, and `@model_validator` to normalize and clamp job parameters.
- Use FastAPI dependency and JWT helpers for auth validation in backend routes. Examples: `require_user`, `require_admin`, and `require_internal_admin` in `TRR-Backend/api/auth.py`.
- Use focused TypeScript helpers for string and identifier validation in TRR-APP. Examples: `validateEmail`, `validateUsername`, and `validateBirthday` in `TRR-APP/apps/web/src/lib/validation/user.ts`; UUID and integer guards in `TRR-APP/apps/web/src/lib/server/validation/identifiers.ts`.
- Keep validation close to the boundary. Request parsing lives in route or schema modules; repositories and downstream services expect normalized input.

## Logging

**Framework:** Python `logging` in backend and screenalytics, browser/server `console` only in narrow app-side diagnostics.

**Patterns:**
- Initialize a module logger with `logging.getLogger(__name__)`. Examples: `TRR-Backend/api/main.py`, `TRR-Backend/api/deps.py`, `screenalytics/apps/api/services/run_validator.py`.
- Log structured operational context instead of dumping large objects. Examples: startup configuration and pool lane logs in `TRR-Backend/api/main.py`.
- Use warning/error logs for degraded state and keep client error details generic. `screenalytics/apps/api/errors.py` and `TRR-Backend/api/auth.py` follow this split.
- In frontend TypeScript, do not introduce broad `console.log` usage; `screenalytics/web/.eslintrc.json` explicitly warns on it, and TRR-APP test expectations commonly spy on `console.warn` for intentional diagnostics as in `TRR-APP/apps/web/tests/backend-base.test.ts`.

## Comments

**When to Comment:**
- Use short intent comments around environment bootstrap, runtime lanes, and non-obvious guardrails. Examples: startup comments in `screenalytics/apps/api/main.py`, stale-run sweeper notes in `TRR-Backend/api/main.py`.
- Prefer comments that explain why a workaround exists, not what a statement literally does.

**JSDoc/TSDoc:**
- Python uses docstrings heavily for modules, functions, and fixtures. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/errors.py`, `screenalytics/tests/conftest.py`.
- TypeScript uses inline comments sparingly and usually relies on strong type names instead of TSDoc. `TRR-APP/apps/web/src/lib/validation/user.ts` is representative.

## Function Design

**Size:** Favor helper extraction when a boundary function must orchestrate multiple steps. `TRR-Backend/api/main.py` and `TRR-APP/apps/web/src/lib/server/admin/brand-profile-repository.ts` are large orchestration modules, but they still break repeated logic into named helpers.

**Parameters:** 
- Normalize raw external input early and pass typed values deeper into the module. Examples: `normalizeBackendBase(rawUrl: string)` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, validator methods in `screenalytics/apps/api/schemas/job_params.py`.
- Prefer keyword arguments in Python for complex helper calls. Example: `validate_run_integrity(ep_id, run_id, data_root=...)` in `screenalytics/apps/api/services/run_validator.py`.

**Return Values:** 
- Return typed dictionaries or model objects at API boundaries in Python.
- Return `null` in TRR-APP server helpers when an upstream dependency is intentionally optional or unavailable. Example: `fetchBackendJson<T>(...)` in `TRR-APP/apps/web/src/lib/server/admin/brand-profile-repository.ts`.

## Module Design

**Exports:** 
- Default-export React components from their component file when the file represents a single component. Example: `TRR-APP/apps/web/src/components/admin/AdminBreadcrumbs.tsx`.
- Use named exports for utility modules and server helpers. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/validation/identifiers.ts`.
- Keep Python modules cohesive by feature area: routers in `TRR-Backend/api/routers/` and `screenalytics/apps/api/routers/`, services in `screenalytics/apps/api/services/`, shared DB/auth helpers in `TRR-Backend/api/`.

**Barrel Files:** 
- Barrel usage is limited and local to explicit packages. Example: `TRR-APP/apps/web/src/lib/design-system/index.ts`.
- Do not add broad barrels for every folder; the prevailing pattern is direct imports from concrete modules.

## Verification Commands

- Workspace baseline: `make test-fast`, `make test-full`, and `make test-changed` from `/Users/thomashulihan/Projects/TRR/Makefile`.
- Workspace canonical scripts: `scripts/test-fast.sh`, `scripts/test.sh`, `scripts/test-changed.sh`, and `scripts/smoke.sh`.
- Backend fast check: `ruff check . && ruff format --check . && pytest -q` from `docs/cross-collab/WORKFLOW.md` and `AGENTS.md`.
- Screenalytics fast check: `pytest -q` from `docs/cross-collab/WORKFLOW.md` and `AGENTS.md`.
- App fast check: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` from `docs/cross-collab/WORKFLOW.md` and `AGENTS.md`.

---

*Convention analysis: 2026-04-08*
