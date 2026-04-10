# Coding Conventions

**Analysis Date:** 2026-04-09

## Naming Patterns

**Files:**
- Use `snake_case.py` for Python modules across `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `screenalytics/apps/api/`, and `screenalytics/py_screenalytics/`. Representative files: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/utils/env.py`, `screenalytics/apps/api/services/internal_admin_auth.py`.
- Use `test_*.py` for Python tests under `TRR-Backend/tests/` and `screenalytics/tests/`.
- Use `PascalCase.tsx` for React components under `TRR-APP/apps/web/src/components/`. Representative files: `TRR-APP/apps/web/src/components/GlobalHeader.tsx`, `TRR-APP/apps/web/src/components/ErrorBoundary.tsx`.
- Use `kebab-case.ts` or `kebab-case.tsx` for Next.js routes, utilities, and tests under `TRR-APP/apps/web/src/` and `TRR-APP/apps/web/tests/`. Representative files: `TRR-APP/apps/web/src/lib/server/postgres.ts`, `TRR-APP/apps/web/tests/social-ingest-health-dot-route.test.ts`, `TRR-APP/apps/web/tests/show-brand-logos-section.runtime.test.tsx`.
- Use `*.runtime.test.tsx` for DOM/runtime component tests and `*.spec.ts` for Playwright E2E in `TRR-APP/apps/web/tests/e2e/`.

**Functions:**
- Use `snake_case` for Python functions and methods. Prefix internal helpers with `_` when they are module-private. Examples: `TRR-Backend/api/main.py` (`_validate_startup_config`, `_prewarm_database_pool`), `screenalytics/apps/api/services/internal_admin_auth.py` (`_clean`, `_env_flag`).
- Use `camelCase` for TypeScript functions and variables. Use `PascalCase` for React components and exported type names. Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` (`getBackendApiBase`), `TRR-APP/apps/web/src/components/GlobalHeader.tsx` (`GlobalHeader`).
- Use `useX` naming for React hooks under `TRR-APP/apps/web/src/hooks/` and `TRR-APP/apps/web/src/lib/admin/**/`. Examples: `TRR-APP/apps/web/src/hooks/useNormalizedSurvey.ts`, `TRR-APP/apps/web/src/lib/admin/person-page/use-person-profile-controller.ts`.

**Variables:**
- Use `UPPER_SNAKE_CASE` for environment keys and module constants. Examples: `TRR-Backend/api/main.py` (`_LOCAL_RUNTIME_MARKERS`), `screenalytics/apps/api/services/internal_admin_auth.py` (`DEFAULT_INTERNAL_ADMIN_ISSUER`), `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` (`LOOPBACK_BACKEND_HOSTNAMES`).
- Use `is*`, `has*`, `can*`, and `should*` prefixes for booleans. Examples: `screenalytics/apps/api/main.py` (`_is_dev`, `_enable_v2_api`), `TRR-APP/apps/web/src/lib/server/postgres.ts` (`isDeployedRuntime`, `isSupavisorSessionPoolerConnectionString`).

**Types:**
- Use `PascalCase` for Pydantic models, dataclasses, exception classes, and TypeScript types/interfaces. Examples: `TRR-Backend/trr_backend/clients/computer_use.py` (`ComputerUseRequest`), `TRR-Backend/trr_backend/object_storage.py` (`ObjectStorageConfig`), `screenalytics/apps/api/services/validation.py` (multiple `@dataclass` result types), `TRR-APP/apps/web/src/lib/photo-metadata.ts` (`PhotoMetadata`).
- Prefer modern Python type syntax such as `dict[str, Any]`, `Path | None`, and `Literal[...]` in `TRR-Backend/` and `screenalytics/`.
- Prefer explicit TypeScript `type` imports and exported interfaces in `TRR-APP/apps/web/src/`. Example: `TRR-APP/apps/web/src/lib/server/postgres.ts`.

## Code Style

**Formatting:**
- Use Ruff as the formatter and linter for Python in `TRR-Backend/` and the Python support code in `TRR-APP/`. `TRR-Backend/ruff.toml` and `TRR-APP/ruff.toml` both set Python `3.11`, `line-length = 120`, double quotes, and space indentation.
- Use `screenalytics/pyproject.toml` as the Python formatting source of truth in `screenalytics/`. It sets Ruff line length to `120` and mirrors Black line length to `120`.
- No standalone Prettier config was detected in `TRR-APP/` or `screenalytics/web/`. JS/TS formatting follows existing file style plus ESLint and TypeScript constraints.

**Linting:**
- In `TRR-Backend/ruff.toml`, keep Ruff rules `E`, `F`, `I`, `N`, `UP`, `B`, and `C4`. `B008` is intentionally ignored for FastAPI dependency defaults.
- In `screenalytics/pyproject.toml`, keep Ruff ignores `E402`, `F841`, and `E731`. Those ignores support early `sys.path` bootstrapping, retained debug variables, and small lambda helpers.
- In `TRR-APP/apps/web/eslint.config.mjs`, extend `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`. Keep `@next/next/no-img-element` as `error`; exceptions require explicit inline justification.
- In `screenalytics/web/.eslintrc.json`, extend `next/core-web-vitals` and allow only `console.warn` and `console.error`.

## Import Organization

**Order:**
1. `from __future__ import annotations` first in Python files that use it. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`, `TRR-Backend/tests/api/test_health.py`.
2. Standard library imports.
3. Third-party imports.
4. Local package imports.

**Path Aliases:**
- Use `@/*` for `TRR-APP/apps/web/src/*`, defined in `TRR-APP/apps/web/tsconfig.json`.
- Use `server-only` markers for server modules under `TRR-APP/apps/web/src/lib/server/`; tests replace that import with `TRR-APP/apps/web/tests/mocks/server-only.ts` via `TRR-APP/apps/web/vitest.config.ts`.
- `screenalytics/tests/conftest.py` is allowed to mutate `sys.path` early so tests can import `apps/` and `packages/py-screenalytics/src/`.

## Error Handling

**Patterns:**
- Use fail-fast startup validation for high-impact config. `TRR-Backend/api/main.py` raises `RuntimeError` with actionable env guidance when DB or auth lanes are invalid. `screenalytics/apps/api/main.py` delegates startup validation through `runtime_startup.validate_startup_config(...)`.
- Use typed domain exceptions instead of anonymous `Exception` when the caller needs a stable contract. Examples: `screenalytics/apps/api/services/internal_admin_auth.py`, `TRR-Backend/api/deps.py`, `TRR-Backend/trr_backend/services/retained_cast_screentime_dispatch.py`.
- In Screenalytics, route-facing failures should normalize to `{ code, message, details }` envelopes through `screenalytics/apps/api/errors.py`. Prefer `x-error-code` headers when a route needs a stable machine-readable suffix.
- In `TRR-APP/apps/web/src/lib/server/`, reject invalid runtime lanes explicitly instead of silently degrading. Example: `TRR-APP/apps/web/src/lib/server/postgres.ts` throws on non-session and non-local database lanes.
- For cross-repo proxy routes in `TRR-APP/apps/web/src/app/api/**`, preserve backend or proxy-standardized error codes instead of inventing ad hoc payloads. `TRR-APP/apps/web/tests/social-ingest-health-dot-route.test.ts` is the pattern to match.

## Logging

**Framework:** `logging` in Python, minimal `console.warn` in TypeScript.

**Patterns:**
- Instantiate module loggers with `logging.getLogger(__name__)`. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/services/internal_admin_auth.py`.
- Prefer structured log prefixes and compact key/value messages for runtime diagnostics. Examples: `TRR-Backend/api/main.py` logs with prefixes such as `[startup-config]` and `[cast-screentime]`.
- Add trace IDs to responses and error payloads where middleware already supports them. `screenalytics/apps/api/main.py` sets `x-trace-id` and `x-request-id`; `screenalytics/apps/api/errors.py` threads trace IDs into error `details`.
- In `TRR-APP/`, use `console.warn` only for local-dev guardrails, not normal control flow. Example: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

## Comments

**When to Comment:**
- Comment around non-obvious environment ordering, framework quirks, compatibility guards, and operational constraints.
- Keep comments short and local to the risk being explained. Representative files: `screenalytics/apps/api/main.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `TRR-APP/apps/web/eslint.config.mjs`, `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts`.

**JSDoc/TSDoc:**
- Python docstrings are common on public helpers and exception groups. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/errors.py`.
- JSDoc/TSDoc is not a dominant pattern in `TRR-APP/apps/web/src/`; most TS intent is conveyed through types and focused comments.

## Function Design

**Size:** Break complex runtime logic into private normalization helpers and a few exported entrypoints. Examples: `TRR-Backend/api/main.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `screenalytics/apps/api/services/validation.py`.

**Parameters:**
- Use keyword-only flags in Python where call sites benefit from readability. Examples: `TRR-Backend/trr_backend/utils/env.py` (`load_env(*, override=False)`), `screenalytics/apps/api/services/internal_admin_auth.py` (`get_screenalytics_outbound_bearer_token(..., service_token=None)`).
- Prefer typed object arguments in TypeScript for functions with many options. Example: `TRR-APP/apps/web/src/lib/media/content-type.ts` (`resolveCanonicalContentType(input: {...})`).

**Return Values:**
- Return structured dicts, dataclasses, or typed interfaces instead of loose tuples when the payload crosses module boundaries.
- Normalize API-facing error and health payloads rather than returning mixed shapes. Examples: `TRR-Backend/api/main.py`, `screenalytics/apps/api/errors.py`, `screenalytics/apps/api/test_error_envelope_and_events.py`.

## Module Design

**Exports:**
- Python modules typically export direct functions, classes, and router objects. `__init__.py` files exist but are thin.
- TypeScript modules export named functions, constants, interfaces, and types. Default exports are mainly used for React components or framework-required files. Example: `TRR-APP/apps/web/src/components/GlobalHeader.tsx`.

**Barrel Files:**
- Use barrels selectively, not universally. Examples: `TRR-APP/apps/web/src/components/survey/index.ts`, `TRR-APP/apps/web/src/lib/design-system/index.ts`.
- Do not introduce broad workspace-level barrels across repos; keep import boundaries repo-local.

## Environment And Config Patterns

- Use the workspace contract in `docs/workspace/env-contract.md` for shared variables and defaults. Repo code should reference env names from that contract, not invent new aliases without updating docs.
- Keep backend URL resolution centralized in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`. `TRR_API_URL` is normalized to `/api/v1` there and should not be hardcoded elsewhere.
- Keep server-only logic under `TRR-APP/apps/web/src/lib/server/`. Client components should consume server routes or typed helpers, not raw backend env vars.
- For local Python runtime env loading, use repo-root `.env` discovery helpers instead of hand-rolled `dotenv` calls scattered through the codebase. Current patterns are `TRR-Backend/trr_backend/utils/env.py` and `screenalytics/apps/api/main.py`.
- Never print or commit secret values. Shared secret names are defined in `AGENTS.md`, `TRR-Backend/AGENTS.md`, `screenalytics/AGENTS.md`, and `TRR-APP/AGENTS.md`.

## Migration And Review Habits

- Land cross-repo contract work in this order: `TRR-Backend` first, `screenalytics` second, `TRR-APP` last. Source of truth: `AGENTS.md` and `docs/cross-collab/WORKFLOW.md`.
- Never rewrite landed Supabase migrations in `TRR-Backend/supabase/migrations/`. Add a new migration, keep schema docs current, and run `make schema-docs-check` when schema or exposed SQL changes.
- Use repo-local fast validation from each repo’s `AGENTS.md` after implementation, then run workspace-level validation when the change spans repos.
- Update canonical continuity files after material work: `docs/ai/local-status/*.md` or `docs/cross-collab/TASK*/STATUS.md`. `docs/ai/HANDOFF.md` is generated only.
- For formal multi-phase work, run `scripts/handoff-lifecycle.sh pre-plan`, `post-phase`, and `closeout` exactly as described in `docs/ai/HANDOFF_WORKFLOW.md` and `docs/cross-collab/WORKFLOW.md`.
- Keep repository map artifacts synchronized with `make repo-map-check` in each repo when `docs/Repository/generated/` changes.

---

*Convention analysis: 2026-04-09*
