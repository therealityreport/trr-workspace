# Coding Conventions

**Analysis Date:** 2026-04-04

## Scope

This document captures the current coding conventions across the active TRR workspace repos:

- `TRR-Backend/`
- `TRR-APP/`
- `screenalytics/`
- Shared workspace policy and command references in `AGENTS.md` and `docs/workspace/dev-commands.md`

Use repo-local conventions first, then apply workspace rules from `AGENTS.md` when changes cross repo boundaries.

## Naming Patterns

**Files:**
- Python modules use `snake_case.py` under `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `screenalytics/apps/api/`, and `screenalytics/packages/py-screenalytics/src/py_screenalytics/`.
- FastAPI router files are resource-oriented and admin-prefixed where needed, for example `TRR-Backend/api/routers/admin_show_news.py`, `TRR-Backend/api/routers/screenalytics.py`, and `screenalytics/apps/api/routers/jobs.py`.
- Next.js App Router files follow framework naming: `page.tsx`, `layout.tsx`, `route.ts`, nested under route segments such as `TRR-APP/apps/web/src/app/shows/[showId]/page.tsx`.
- React component and utility files are split by concern. Components often use `PascalCase.tsx` in `TRR-APP/apps/web/src/components/`, while utility modules use `kebab-case.ts` in `TRR-APP/apps/web/src/lib/`.
- Test files are descriptive and behavior-oriented rather than mirroring source names exactly, for example `TRR-APP/apps/web/tests/show-refresh-health-center-wiring.test.ts` and `TRR-Backend/tests/repositories/test_social_sync_orchestrator.py`.

**Functions:**
- Python functions use `snake_case`, including private helpers prefixed with `_`, as seen in `TRR-Backend/api/main.py` and `screenalytics/apps/api/services/validation.py`.
- TypeScript/React functions use `camelCase` for helpers and `PascalCase` for components and page functions, as seen in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and `TRR-APP/apps/web/src/app/page.tsx`.
- Route handlers in Next.js export HTTP verb functions directly: `export async function GET(...)` or `POST(...)` in files like `TRR-APP/apps/web/src/app/api/session/login/route.ts`.

**Variables:**
- Module constants use `UPPER_SNAKE_CASE` in both Python and TypeScript, for example `CANONICAL_DB_ENV` in `TRR-Backend/trr_backend/db/connection.py` and `LOOPBACK_BACKEND_HOSTNAMES` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Mutable local variables stay lower-case or `camelCase` and tend to be explicit rather than abbreviated.
- Logger instances are consistently `logger` or `LOGGER`.

**Types:**
- Python dataclasses, exceptions, enums, and typed containers use `PascalCase`, for example `DatabaseConnectionError` in `TRR-Backend/trr_backend/db/connection.py` and `StorageConfigResult` in `screenalytics/apps/api/services/validation.py`.
- TypeScript types and props interfaces use `PascalCase`, for example `UserProfile` in `TRR-APP/apps/web/src/lib/validation/user.ts`.
- Literal unions and typed records are preferred over untyped objects when the module is already strongly typed.

## Code Style

**Formatting:**
- `TRR-Backend/` uses Ruff formatting via `TRR-Backend/ruff.toml`.
- `screenalytics/` declares both Ruff and Black in `screenalytics/pyproject.toml`, with both set to line length `120`.
- `TRR-APP/` does not declare Prettier or Biome. Formatting is implicitly enforced through ESLint, TypeScript strictness, and existing file style in `TRR-APP/apps/web/`.
- Workspace target runtimes are documented in `AGENTS.md` and `.nvmrc`: Node `24` and Python `3.11`.

**Key settings:**
- Python line length is `120` in `TRR-Backend/ruff.toml` and `screenalytics/pyproject.toml`.
- `TRR-Backend/ruff.toml` enables `E`, `F`, `I`, `N`, `UP`, `B`, and `C4`, and explicitly ignores `B008` for FastAPI dependency defaults.
- `screenalytics/pyproject.toml` ignores `E402`, `F841`, and `E731` because this repo intentionally mutates `sys.path`, keeps some debugging variables, and accepts simple lambda assignments.
- `TRR-APP/apps/web/tsconfig.json` runs with `strict: true` and an `@/*` path alias.

**Observed style rules:**
- Python files commonly start with `from __future__ import annotations`.
- Imports are grouped and blank-line separated: stdlib, third-party, then local modules.
- Docstrings are common in Python entrypoints, services, and tests when the behavior is non-trivial.
- TypeScript files use semicolons inconsistently by ecosystem style, but each file remains internally consistent.
- Server-only Next.js modules put `import "server-only";` first, as in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

## Linting

**Python repos:**
- Run `ruff check .` and `ruff format --check .` in `TRR-Backend/`.
- `screenalytics/.github/workflows/ci.yml` uses a narrower CI lint gate: `ruff check --select=E9,F63,F7,F82 --target-version=py311 .`.
- `screenalytics/.github/workflows/ci.yml` also enforces custom scripts: `scripts/check_ruff_policy.py` and `scripts/check_f401_regression.py`.

**TypeScript repo:**
- `TRR-APP/apps/web/eslint.config.mjs` extends `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`.
- `@next/next/no-img-element` is an explicit error; exceptions require inline disable comments with justification per the comment in `TRR-APP/apps/web/eslint.config.mjs`.
- Test files under `TRR-APP/apps/web/tests/**/*` can use `@ts-nocheck` only with a description, and `no-explicit-any` is disabled there.

**Not detected:**
- No root-level monorepo linter config.
- No Prettier config in the active repos.
- No repo-wide mypy config in the active repos.

## Import Organization

**Python order:**
1. `from __future__ import annotations`
2. Standard library imports
3. Third-party imports
4. App-local imports

Use the layout already present in `TRR-Backend/api/main.py`, `TRR-Backend/api/auth.py`, and `screenalytics/apps/api/main.py`.

**TypeScript order:**
1. Framework and package imports
2. `@/` alias imports
3. Relative imports

Use the ordering in `TRR-APP/apps/web/tests/admin-global-header.test.tsx` and `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

**Path aliases:**
- `TRR-APP/apps/web/tsconfig.json` defines `@/* -> ./src/*`.
- Vitest mirrors that alias in `TRR-APP/apps/web/vitest.config.ts`.
- `screenalytics/tests/conftest.py` and `screenalytics/apps/workspace-ui/tests/conftest.py` add `PROJECT_ROOT` and `packages/py-screenalytics/src` to `sys.path`; tests depend on that import setup.

## Repeated Implementation Conventions

**Environment access and normalization:**
- Use focused env helper functions rather than reading raw env vars repeatedly.
- Examples:

```python
def _env_flag(name: str, default: bool) -> bool:
    raw = (os.getenv(name) or "").strip().lower()
    if not raw:
        return default
    return raw not in {"0", "false", "no", "off"}
```

From `TRR-Backend/api/main.py`.

```typescript
export const getBackendApiBase = (): string | null => {
  const raw = process.env.TRR_API_URL?.trim();
  if (!raw) return null;
  return normalizeBackendBase(raw);
};
```

From `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

- In Next.js client config files, env vars are referenced statically so Next can inline them, as in `TRR-APP/apps/web/src/lib/firebase-client-config.ts`.
- In screenalytics, env fallback helpers like `_env_first()` are used to support multiple operator variable names, as in `screenalytics/apps/api/services/storage.py` and `screenalytics/apps/api/services/validation.py`.

**Startup validation and fail-fast checks:**
- Entrypoints validate critical config during startup rather than deferring failures to request time.
- `TRR-Backend/api/main.py` validates DB resolution and auth envs in `_validate_startup_config()`.
- `screenalytics/apps/api/main.py` installs error handlers, applies CPU limits before heavy imports, and conditionally mounts optional routers.

**Server and client boundaries in TRR-APP:**
- Keep backend and secret-aware code under `TRR-APP/apps/web/src/lib/server/`.
- Prefer Server Components and server route handlers; add client boundaries only when stateful interaction is required, per `TRR-APP/AGENTS.md`.
- Use `import "server-only";` in modules that must never cross into the client bundle.

**Streamlit page initialization:**
- Streamlit pages add import paths, import `ui_helpers`, then call `helpers.init_page(...)` before the first `st.*` UI call.
- Follow the pattern in `screenalytics/apps/workspace-ui/pages/0_Shows.py`.

**Status-rich naming for tests and routes:**
- New admin, proxy, and wiring tests should keep the current descriptive naming style used in `TRR-APP/apps/web/tests/`.
- New backend repository or router tests should use `test_<behavior>.py` under the relevant category directory in `TRR-Backend/tests/`.

## Error Handling

**TRR-Backend:**
- Raise `fastapi.HTTPException` for request-level failures, with explicit status codes and short client-safe messages, as in `TRR-Backend/api/auth.py` and `TRR-Backend/api/deps.py`.
- Use `headers={"x-error-code": ...}` when callers need a machine-readable failure code, as in `TRR-Backend/api/auth.py`.
- Log detailed context server-side before raising sanitized errors.
- Wrap external or DB errors in repo-local helpers instead of leaking raw response objects.

**screenalytics:**
- All API errors are normalized through `screenalytics/apps/api/errors.py` into `{code, message, details}` envelopes.
- Preserve trace IDs in error details when present.
- Use safety-net exception handlers to avoid exposing stack traces to clients.
- Storage and pipeline validation functions return typed result objects and log warnings or fallback reasons rather than crashing immediately when degraded local behavior is acceptable.

**TRR-APP:**
- Normalize env and backend URL issues early in helper modules instead of scattering ad hoc checks.
- For server routes and server-side data access, follow backend contracts rather than inventing local response shapes, per `TRR-APP/AGENTS.md`.
- In tests, assert user-visible outcomes rather than internal implementation details; examples are throughout `TRR-APP/apps/web/tests/`.

## Logging

**Framework:** `logging` in Python, `console.warn` only for local dev diagnostics in narrow TypeScript helpers.

**Patterns:**
- Initialize module loggers with `logging.getLogger(__name__)` or `LOGGER = logging.getLogger(__name__)`.
- Prefer structured-ish log messages with stable prefixes, for example `[startup-config]`, `[db-resolution]`, `[storage-config]`, and `[cast-screentime]`.
- Use `logger.exception(...)` or `LOGGER.exception(...)` when preserving stack traces matters.
- Avoid logging secret values. Workspace policy in `AGENTS.md` explicitly prohibits printing shared secrets.
- TypeScript logging is intentionally sparse. `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` warns only in local dev when `TRR_API_URL` resolves to a remote host.

## Comments

**When to comment:**
- Use comments for policy, runtime ordering, or non-obvious operational constraints.
- Good examples:
  - `TRR-APP/apps/web/eslint.config.mjs` documents the no-`<img>` policy and test overrides.
  - `screenalytics/apps/api/main.py` explains why `.env` loading and CPU limits happen before heavy imports.
  - `TRR-Backend/api/main.py` uses short comments to separate startup validation branches.

**JSDoc/TSDoc:**
- Minimal in TypeScript. Most documentation is inline comments or descriptive names.
- Python docstrings are the dominant form of in-file documentation for functions, tests, and modules.

## Function Design

**Size:**
- Utility functions stay small and focused.
- Large files still decompose behavior into private helpers, especially in Python services and startup modules.

**Parameters:**
- Python APIs prefer keyword-only or clearly named parameters in complex helpers, seen in `TRR-Backend/trr_backend/db/connection.py` and `screenalytics/apps/api/services/storage.py`.
- TypeScript helpers prefer explicit parameter typing and narrow return types, seen in `TRR-APP/apps/web/src/lib/firebase-client-config.ts`.

**Return values:**
- Python helpers often return typed dicts, dataclasses, or tuples of structured metadata instead of raw positional data.
- TypeScript helpers frequently return `string | null`, typed objects, or literal-backed booleans rather than truthy/falsy mixed values.

## Module Design

**Exports:**
- Python modules export top-level functions and classes directly; occasional `__all__` appears for narrow security helpers such as `TRR-Backend/trr_backend/security/internal_admin.py`.
- In Next.js, page modules default-export the page component, route modules named-export `GET`/`POST`, and utility modules prefer named exports.

**Barrel files:**
- Not a dominant pattern.
- Narrow index modules exist where a domain benefits from aggregation, for example `TRR-APP/apps/web/src/lib/design-system/index.ts`.

## Configuration Patterns

**Workspace-wide:**
- Shared quality commands live in `docs/workspace/dev-commands.md`.
- Cross-repo validation commands are documented in `AGENTS.md`.
- Environment contract checks run in CI via `scripts/check_env_example.py` in all three repos.

**Repo-local:**
- Keep repo-specific quality settings near the repo root:
  - `TRR-Backend/ruff.toml`
  - `TRR-Backend/pytest.ini`
  - `TRR-APP/apps/web/eslint.config.mjs`
  - `TRR-APP/apps/web/vitest.config.ts`
  - `TRR-APP/apps/web/playwright.config.ts`
  - `screenalytics/pyproject.toml`

**Current rule of thumb:**
- Add new config to the repo that owns the runtime.
- Add shared command or workflow guidance to workspace docs only when more than one repo depends on it.

---

*Convention analysis: 2026-04-04*
