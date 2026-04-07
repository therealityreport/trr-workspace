# Coding Conventions

**Analysis Date:** 2026-04-04

## Naming Patterns

**Files:**
- Use `snake_case` for Python modules and tests in `TRR-Backend` and `screenalytics`: `TRR-Backend/api/routers/admin_recent_people.py`, `TRR-Backend/tests/api/test_health.py`, `screenalytics/apps/api/services/trr_metadata_db.py`, `screenalytics/tests/api/test_trr_health.py`.
- Use Next.js App Router file conventions in `TRR-APP`: `page.tsx`, `layout.tsx`, and `route.ts` under `TRR-APP/apps/web/src/app/...`.
- Use `PascalCase.tsx` for React components and `camelCase.ts` for utilities and hooks: `TRR-APP/apps/web/src/components/GlobalHeader.tsx`, `TRR-APP/apps/web/src/hooks/useNormalizedSurvey.ts`, `screenalytics/web/lib/state/uploadMachine.ts`.

**Functions:**
- Use `snake_case` for Python functions and helpers: `TRR-Backend/api/routers/admin_recent_people.py`, `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py`, `screenalytics/apps/api/services/trr_metadata_db.py`.
- Use `camelCase` for TypeScript functions and reducers: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/validation/user.ts`, `screenalytics/web/api/client.ts`.
- Prefix internal helpers with `_` in Python when they are module-private: `_parse_limit` in `TRR-Backend/api/routers/admin_recent_people.py`, `_cache_get` in `screenalytics/apps/api/services/trr_metadata_db.py`.

**Variables:**
- Use `UPPER_SNAKE_CASE` for module constants and environment-derived defaults: `_DEFAULT_LIMIT` in `TRR-Backend/api/routers/admin_recent_people.py`, `API_BASE` in `screenalytics/web/api/client.ts`, `_DEFAULT_CLIP_TTL_DAYS` in `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py`.
- Use descriptive state names in React and reducer code: `isSettingsOpen`, `settingsMenuRef`, `progress`, `speedBps` in `TRR-APP/apps/web/src/components/GlobalHeader.tsx` and `screenalytics/web/lib/state/uploadMachine.ts`.

**Types:**
- Use `PascalCase` for Python Pydantic models and `TypedDict` names: `RecentPersonViewRequest` in `TRR-Backend/api/routers/admin_recent_people.py`, `_ReadyCheckResult` in `screenalytics/apps/api/main.py`.
- Use `PascalCase` for TypeScript types with semantic suffixes such as `Props`, `State`, `Response`, and `Request`: `SurveyXState` in `TRR-APP/apps/web/src/lib/validation/user.ts`, `UploadState` in `screenalytics/web/lib/state/uploadMachine.ts`.
- Prefer union literals for constrained UI state in TypeScript: `UploadStep` and `UploadMode` in `screenalytics/web/lib/state/uploadMachine.ts`.

## Code Style

**Formatting:**
- Use Ruff as the enforced formatter for Python in `TRR-Backend` and the Python utilities inside `TRR-APP`; the config sets `line-length = 120`, double quotes, and space indentation in `TRR-Backend/ruff.toml` and `TRR-APP/ruff.toml`.
- `screenalytics` keeps Ruff and Black aligned at 120 characters in `screenalytics/pyproject.toml`.
- No Prettier, Biome, or repo-wide TypeScript formatter config is detected in `TRR-APP` or `screenalytics/web`; TypeScript/TSX style is governed by existing file patterns plus ESLint.

**Linting:**
- Use Ruff rule families `E`, `F`, `I`, `N`, `UP`, `B`, and `C4` for backend/app Python code, with FastAPI-specific default-argument allowance via `B008` ignore in `TRR-Backend/ruff.toml`.
- `screenalytics` Ruff keeps a lighter rule surface and explicitly tolerates import-order bootstrapping and debug leftovers via `ignore = ["E402", "F841", "E731"]` in `screenalytics/pyproject.toml`.
- Use Next.js ESLint presets for `TRR-APP/apps/web`, with custom hard enforcement for `@next/next/no-img-element` in `TRR-APP/apps/web/eslint.config.mjs`.
- `TRR-APP` test files relax two TypeScript lint rules only inside `tests/**/*` in `TRR-APP/apps/web/eslint.config.mjs`.
- `screenalytics/web` inherits `next/core-web-vitals` and warns on `console` except `warn` and `error` in `screenalytics/web/.eslintrc.json`.

## Import Organization

**Order:**
1. Python modules follow standard-library, third-party, then local-package imports, which Ruff `I` enforcement expects in `TRR-Backend/ruff.toml` and is visible in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.
2. TypeScript files usually import framework/runtime modules first, then external packages, then alias-based local modules: `TRR-APP/apps/web/src/components/GlobalHeader.tsx`, `TRR-APP/apps/web/tests/admin-global-header.test.tsx`.
3. Type-only imports are separated explicitly in TypeScript where useful: `TRR-APP/apps/web/src/components/GlobalHeader.tsx`, `screenalytics/web/api/client.ts`.

**Path Aliases:**
- Use `@/*` -> `./src/*` in `TRR-APP/apps/web/tsconfig.json`.
- Use `@/*` -> project root in `screenalytics/web/tsconfig.json`.
- Vitest mirrors the app alias and remaps `server-only` for tests in `TRR-APP/apps/web/vitest.config.ts`.

## Error Handling

**Patterns:**
- Use `HTTPException` for request-contract and router-level failures in FastAPI handlers: `TRR-Backend/api/routers/admin_recent_people.py`, `TRR-Backend/api/auth.py`, `screenalytics/apps/api/main.py`.
- Use `RuntimeError` for startup validation, dependency availability, and lower-layer operational failures that should fail fast or be translated at the boundary: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/media/s3_mirror.py`, `screenalytics/apps/api/services/trr_metadata_db.py`.
- `screenalytics` installs a consistent error envelope `{code, message, details}` for all unhandled API errors via `screenalytics/apps/api/errors.py`; prefer that pattern for new Screenalytics API surfaces.
- `TRR-APP` server/client utilities commonly normalize errors into application-specific objects instead of throwing raw values: `screenalytics/web/api/client.ts` shows the pattern explicitly; `TRR-APP` client components more often catch, log, and preserve optimistic UI fallback state in `TRR-APP/apps/web/src/components/GlobalHeader.tsx`.

## Logging

**Framework:** Python `logging`; browser/server `console` in TypeScript.

**Patterns:**
- Use module-scoped Python loggers as `logger = logging.getLogger(__name__)` or `LOGGER = logging.getLogger(__name__)`: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py`, `screenalytics/apps/api/main.py`, `screenalytics/apps/api/services/trr_metadata_db.py`.
- Prefer structured or tagged log messages rather than prose-only strings, especially for startup and worker flows: `"[startup-config]"` in `TRR-Backend/api/main.py`, `"[startup-schema-contract]"` in `screenalytics/apps/api/main.py`.
- `TRR-APP` permits `console.log`, `console.warn`, and `console.error` in production code; examples exist in `TRR-APP/apps/web/src/app/hub/layout.tsx`, `TRR-APP/apps/web/src/app/api/session/login/route.ts`, and many client components. Preserve this only when the log has operational value.

## Comments

**When to Comment:**
- Use module docstrings and high-value function docstrings in Python to explain service ownership or non-obvious runtime behavior: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py`, `screenalytics/apps/api/services/trr_metadata_db.py`.
- Use short targeted comments in TypeScript for policy or testing setup, not line-by-line narration: `TRR-APP/apps/web/eslint.config.mjs`, `TRR-APP/apps/web/tests/setup.ts`.

**JSDoc/TSDoc:**
- TSDoc is selective, usually at file level or for exported helpers rather than every symbol: `TRR-APP/apps/web/src/components/survey/index.ts`.
- Python docstrings are more common than JS docblocks across the workspace.

## Function Design

**Size:** Keep routers thin and delegate heavier work to repositories/services. Current examples: `TRR-Backend/api/routers/admin_recent_people.py` delegates to `trr_backend.repositories.recent_people`; `screenalytics/apps/api/main.py` composes routers and lifecycle helpers rather than embedding business logic.

**Parameters:**
- Prefer typed scalar parameters plus FastAPI `Query`, `Header`, or `Field` metadata at boundaries: `TRR-Backend/api/routers/admin_recent_people.py`.
- Prefer typed object payloads or discriminated unions in TypeScript state/reducer code: `screenalytics/web/lib/state/uploadMachine.ts`.

**Return Values:**
- Backend and Screenalytics router helpers return plain dictionaries/lists or Pydantic-backed payloads, not ORM objects: `TRR-Backend/api/routers/admin_recent_people.py`, `screenalytics/apps/api/services/trr_metadata_db.py`.
- TypeScript utility modules return explicit domain types or `null` instead of implicit falsy values where the caller needs clarity: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/validation/user.ts`.

## Module Design

**Exports:**
- Use default exports for React components and named exports for related types/helpers: `TRR-APP/apps/web/src/components/GlobalHeader.tsx`, `TRR-APP/apps/web/src/components/survey/index.ts`.
- Use barrel files selectively for cohesive UI families, not as a workspace-wide rule: `TRR-APP/apps/web/src/components/survey/index.ts`.
- Python packages are standard package directories with `__init__.py`; imports remain explicit rather than wildcard-based: `TRR-Backend/api/__init__.py`, `TRR-Backend/api/routers/__init__.py`, `screenalytics/apps/api/services/__init__.py`.

**Barrel Files:** Present in focused TypeScript areas only. Use them when a folder is a stable public surface, as in `TRR-APP/apps/web/src/components/survey/index.ts`. Do not add barrels for one-off directories.

## Configuration Patterns

**Environment-First Runtime Config:**
- Validate critical environment before serving traffic. `TRR-Backend/api/main.py` validates DB lane selection and auth envs. `screenalytics/apps/api/main.py` validates runtime DB and schema expectations during startup.
- Never hardcode backend origins or shared service endpoints in app code. `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` derives the backend base from `TRR_API_URL` and appends `/api/v1`.

**TypeScript Compiler Settings:**
- Keep strict TypeScript enabled in both Next.js frontends: `TRR-APP/apps/web/tsconfig.json`, `screenalytics/web/tsconfig.json`.
- `TRR-APP` allows `.js` files in the compiler pipeline (`allowJs: true`), but the dominant convention is still `.ts` and `.tsx`.

**Repo Validation Hooks:**
- Backend quality gate is `ruff check .`, `ruff format --check .`, and `pytest` per `TRR-Backend/AGENTS.md`.
- App quality gate is `pnpm -C apps/web run lint`, `pnpm -C apps/web exec next build --webpack`, and `pnpm -C apps/web run test:ci` per `TRR-APP/AGENTS.md`.
- Screenalytics quality gate is `python -m py_compile <touched_files>`, `pytest tests/unit/ -v`, and `RUN_ML_TESTS=1 pytest tests/ml/ -v` when relevant per `screenalytics/AGENTS.md`.

## Repo and Workspace Conventions

**Cross-Repo Order:**
- For shared contracts, land backend changes before `screenalytics`, then `TRR-APP`, per `/Users/thomashulihan/Projects/TRR/AGENTS.md`, `TRR-Backend/AGENTS.md`, and `screenalytics/AGENTS.md`.

**Runtime Baseline:**
- Node targets `24.x` in `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, and `screenalytics/web/package.json`.
- Python targets `3.11` in `TRR-Backend/ruff.toml`, `TRR-APP/ruff.toml`, and `screenalytics/packages/py-screenalytics/pyproject.toml`.

**Workspace Entry Points:**
- Use workspace `make dev`, `make test-fast`, `make test-full`, and `make smoke` from `/Users/thomashulihan/Projects/TRR/Makefile`.
- Repo `Makefile`s mostly delegate dev/log/stop behavior back to the workspace root: `TRR-Backend/Makefile`, `TRR-APP/Makefile`, `screenalytics/Makefile`.

**Server/Client Boundaries:**
- In `TRR-APP`, keep server-only utilities under `TRR-APP/apps/web/src/lib/server/` and explicitly mark them with `import "server-only"` when needed: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Use `"use client"` only on interactive React entrypoints. The app follows that boundary heavily in `TRR-APP/apps/web/src/components/*.tsx` and `TRR-APP/apps/web/src/app/**/page.tsx`.

---

*Convention analysis: 2026-04-04*
