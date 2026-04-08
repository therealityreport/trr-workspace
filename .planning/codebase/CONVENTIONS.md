# Coding Conventions

**Analysis Date:** 2026-04-07

## Naming Patterns

**Files:**
- Use `snake_case.py` for Python modules, scripts, and tests in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `TRR-Backend/tests/`, `screenalytics/apps/api/`, `screenalytics/tools/`, and `screenalytics/tests/`. Representative files: `TRR-Backend/api/main.py`, `TRR-Backend/tests/test_startup_config.py`, `screenalytics/tests/unit/test_startup_config.py`.
- Use `kebab-case.ts` and `kebab-case.tsx` for TypeScript feature files and tests in `TRR-APP/apps/web/src/` and `TRR-APP/apps/web/tests/`. Representative files: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/tests/admin-operations-health-route.test.ts`.
- Use `PascalCase.tsx` for reusable React components in `TRR-APP/apps/web/src/components/`. Representative file: `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.
- Name Python tests `test_*.py` under feature-specific folders such as `TRR-Backend/tests/api/` and `screenalytics/tests/unit/`.
- Name Vitest files `*.test.ts` or `*.test.tsx` in `TRR-APP/apps/web/tests/`, and Playwright specs `*.spec.ts` in `TRR-APP/apps/web/tests/e2e/`.

**Functions:**
- Use `snake_case` for Python functions and helpers. Internal helpers are prefixed with `_`, as in `_validate_startup_config()` in `TRR-Backend/api/main.py` and `_clear_runtime_env()` in `screenalytics/tests/unit/test_startup_config.py`.
- Use uppercase HTTP verb exports for Next route handlers, for example `GET` in `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts`.
- Use `camelCase` for TypeScript helpers and local utilities, for example `getBackendApiUrl` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Use `PascalCase` for React components and prop types, for example `AdminModal` and `AdminModalProps` in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.

**Variables:**
- Use `snake_case` for Python locals and parameters, with `UPPER_SNAKE_CASE` for constants such as `_LOCAL_RUNTIME_MARKERS` in `TRR-Backend/api/main.py`.
- Use `camelCase` for TypeScript locals and functions, with `UPPER_SNAKE_CASE` for fixed constants such as `MAX_COMPAT_OPERATIONS_HEALTH_LIMIT` in `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts`.

**Types:**
- Use `PascalCase` for TypeScript types and React prop objects, for example `AdminModalProps` in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.
- Use `PascalCase` for Python classes and typed containers, for example `_FakeConnection` in `TRR-Backend/tests/repositories/test_admin_show_reads_repository.py` and `TypedDict` declarations in `screenalytics/apps/api/main.py`.

## Code Style

**Formatting:**
- Use Ruff formatting for Python in `TRR-Backend/ruff.toml` and `TRR-APP/ruff.toml`. Both target Python 3.11, use 120-character lines, double quotes, and space indentation.
- Use Black-compatible formatting in `screenalytics/pyproject.toml`; `tool.black.line-length = 120` matches `tool.ruff.line-length = 120`.
- No Prettier config is detected in `TRR-APP/` or `screenalytics/web/`. Follow the existing TypeScript style already present in `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts` and `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`: two-space indentation, double quotes, semicolons, and trailing commas where multiline objects already use them.

**Linting:**
- Use Ruff as the Python lint gate in `TRR-Backend/ruff.toml` with `E`, `F`, `I`, `N`, `UP`, `B`, and `C4` enabled. Keep FastAPI dependency defaults compatible with the existing `B008` ignore.
- Use the repo-level Ruff config in `TRR-APP/ruff.toml` only for Python helper scripts and generated-doc tooling inside `TRR-APP/`; it is not the frontend TS linter.
- Use `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript` in `TRR-APP/apps/web/eslint.config.mjs`. Preserve the local rule customizations there, especially the enforced `@next/next/no-img-element` policy and the relaxed test-only override for `@typescript-eslint/no-explicit-any`.
- Use `next/core-web-vitals` in `screenalytics/web/.eslintrc.json`; `console.log` is discouraged there because `no-console` only allows `warn` and `error`.
- Treat `screenalytics/.github/workflows/ci.yml` as the actual Python lint bar for `screenalytics`: it runs custom Ruff policy scripts and then `ruff check --select=E9,F63,F7,F82 --target-version=py311 .`. Do not assume import-order or naming rules are CI-enforced there unless you add them explicitly.

## Import Organization

**Order:**
1. Use `from __future__ import annotations` first in Python modules when the file already follows that pattern, as seen in `TRR-Backend/api/main.py`, `TRR-Backend/tests/test_startup_config.py`, and `screenalytics/apps/api/main.py`.
2. Group Python imports as stdlib, then third-party, then repo-local modules. Representative files: `TRR-Backend/api/main.py`, `screenalytics/tests/conftest.py`.
3. Group TypeScript imports as external packages first, then `@/` aliases, then relative imports. Representative files: `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts` and `TRR-APP/apps/web/tests/admin-modal.test.tsx`.

**Path Aliases:**
- Use the `@/*` alias defined in `TRR-APP/apps/web/tsconfig.json` for app-local imports from `TRR-APP/apps/web/src/`.
- Use the Vitest-only alias overrides in `TRR-APP/apps/web/vitest.config.ts` when mocking environment-specific modules such as `server-only`.
- Do not introduce a separate Python alias layer. `TRR-Backend/pytest.ini` relies on `pythonpath = .`, and `screenalytics/tests/conftest.py` explicitly injects `PROJECT_ROOT` and `packages/py-screenalytics/src` into `sys.path`.

## Error Handling

**Patterns:**
- Validate startup/runtime configuration early and fail fast with actionable `RuntimeError` messages in Python entrypoints. Representative files: `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`.
- Catch broad exceptions only at transport boundaries, then translate them into HTTP-safe JSON responses or logged failures. Representative files: `TRR-Backend/api/main.py`, `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts`, `screenalytics/apps/api/main.py`.
- Preserve explicit status mapping for auth and environment errors in Next route handlers, as in `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts`.
- Prefer structured fallback detail over swallowed exceptions. Backend and screenalytics log failures with context, and the app proxy routes return a stable `{ error }` envelope instead of raw exception objects.

## Logging

**Framework:** `logging` in Python, targeted `console.warn` in TypeScript server code

**Patterns:**
- Use `logging.getLogger(__name__)` in Python modules. Representative files: `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`.
- Log structured messages with stable prefixes so tests and operators can identify the subsystem quickly, for example `[startup-config]` in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.
- Keep trace IDs in request middleware rather than in endpoint-local code. Representative files: `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`.
- Use frontend/server `console` calls sparingly. The only acceptable pattern detected in core app code is targeted development warnings such as `console.warn` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

## Comments

**When to Comment:**
- Add comments for policy, runtime ordering, or non-obvious constraints, not for basic control flow. Representative files: `TRR-APP/apps/web/eslint.config.mjs`, `screenalytics/apps/api/main.py`, `TRR-Backend/api/main.py`.
- Use section-divider comments in large tests when setup and assertions would otherwise blend together. Representative file: `TRR-Backend/tests/api/test_health.py`.
- Keep inline comments brief and operational. Current code uses them to explain environment gates, optional dependency guards, or dev-only behavior.

**JSDoc/TSDoc:**
- Not widely used in `TRR-APP/apps/web/`. Prefer descriptive type names and function signatures over large docblocks.
- Use Python docstrings for modules, helpers, fixtures, and tests where context matters. Representative files: `TRR-Backend/api/main.py`, `screenalytics/tests/conftest.py`, `screenalytics/tests/helpers/celery_stubs.py`.

## Function Design

**Size:** Keep boundary handlers relatively thin and move reusable logic into helpers or service modules.
- Next route handlers in `TRR-APP/apps/web/src/app/api/admin/trr-api/**/route.ts` parse request state, enforce auth, then delegate to helpers such as `getBackendApiUrl()` and `getInternalAdminBearerToken()`.
- Python entrypoints keep orchestration in one place but push reusable logic into imported modules, as in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.

**Parameters:** Prefer typed parameters and explicit defaults.
- Python tests and helpers annotate `pytest.MonkeyPatch`, `Path`, and return values in files like `TRR-Backend/tests/test_startup_config.py` and `screenalytics/tests/unit/test_startup_config.py`.
- React props use a dedicated props type, as in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.

**Return Values:** Return stable envelopes at system boundaries.
- Next route handlers return `NextResponse.json(...)` with explicit status codes in `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/health/route.ts`.
- Python APIs return dict/list envelopes with deterministic keys; repository tests assert full payload shape rather than individual fragments in files like `TRR-Backend/tests/repositories/test_admin_show_reads_repository.py`.

## Module Design

**Exports:** Favor feature-local modules with explicit exports.
- Use named exports for Next route handlers and helper functions in `TRR-APP/apps/web/src/app/api/**/route.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Use default exports mainly for React components, as in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.
- Use one Python module per feature area and let `tests/` mirror those boundaries, as seen in `TRR-Backend/tests/api/`, `TRR-Backend/tests/repositories/`, `screenalytics/tests/api/`, and `screenalytics/tests/unit/`.

**Barrel Files:** Not a dominant pattern.
- Do not add barrel files by default in `TRR-APP/apps/web/src/`; direct path imports are the prevailing style.
- Python packages rely on normal package imports rather than re-export hubs.

## Repo-Specific Notes

- In `TRR-Backend/`, treat `TRR-Backend/AGENTS.md` as the contract for validation and shared-schema sequencing. Backend code is expected to land shared API and DB contract changes before downstream repos.
- In `screenalytics/`, preserve the optional-dependency guards and local test harness patterns already centralized in `screenalytics/tests/conftest.py` and `screenalytics/tests/helpers/`.
- In `TRR-APP/`, preserve server/client boundaries described in `TRR-APP/AGENTS.md`. Server-only helpers belong under `TRR-APP/apps/web/src/lib/server/`, and route handlers under `TRR-APP/apps/web/src/app/api/` should continue to proxy backend contracts rather than redefine them.

---

*Convention analysis: 2026-04-07*
