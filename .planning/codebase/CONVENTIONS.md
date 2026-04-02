# Coding Conventions

**Analysis Date:** 2026-04-02

## Naming Patterns

**Files:**
- Use `PascalCase.tsx` for React component files in `TRR-APP/apps/web/src/components/`, for example `TRR-APP/apps/web/src/components/admin/AdminModal.tsx` and `TRR-APP/apps/web/src/components/admin/AdminGlobalHeader.tsx`.
- Use lowercase route and utility filenames in `TRR-APP/apps/web/src/app/` and `TRR-APP/apps/web/src/lib/`, for example `TRR-APP/apps/web/src/app/api/admin/auth/status/route.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Use `snake_case.py` for Python modules in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, and `screenalytics/apps/`, for example `TRR-Backend/api/auth.py`, `TRR-Backend/trr_backend/object_storage.py`, and `screenalytics/apps/api/errors.py`.
- Use `test_*.py` for Python tests and `*.test.ts`, `*.test.tsx`, or `*.spec.ts` for app tests, for example `TRR-Backend/tests/api/test_auth.py`, `screenalytics/tests/api/test_presign_matrix.py`, and `TRR-APP/apps/web/tests/admin-auth-status-route.test.ts`.

**Functions:**
- Use `camelCase` for TypeScript functions and helpers, for example `getBackendApiBase`, `getBackendApiUrl`, and `normalizeBackendBase` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Use `snake_case` for Python functions, fixtures, and helpers, for example `get_bearer_token` in `TRR-Backend/api/auth.py`, `_validate_startup_config` in `TRR-Backend/api/main.py`, and `configure_celery_eager` in `screenalytics/tests/conftest.py`.
- Keep internal helper functions prefixed with `_` in both Python and TypeScript when they are module-private, for example `_env_flag` in `TRR-Backend/api/main.py`, `_json_safe` in `screenalytics/apps/api/errors.py`, and `_make_token` in `TRR-Backend/tests/api/test_auth.py`.

**Variables:**
- Use `UPPER_SNAKE_CASE` for module constants, for example `LOOPBACK_BACKEND_HOSTNAMES` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `_LOCAL_RUNTIME_MARKERS` in `TRR-Backend/api/main.py`, and `_DOTENV_ENV_KEYS` in `screenalytics/apps/api/main.py`.
- Use descriptive suffixes for mocks in tests, for example `requireAdminMock` in `TRR-APP/apps/web/tests/admin-auth-status-route.test.ts` and `fetchMock` in `TRR-APP/apps/web/tests/cast-screentime-proxy-route.test.ts`.

**Types:**
- Use `*Props` for React props types, for example `AdminModalProps` in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.
- Use `BaseModel` classes and response/request suffixes for API contracts in Python, for example `ComputerUseRequest` in `TRR-Backend/trr_backend/clients/computer_use.py`, `EpisodeStatusResponse` in `screenalytics/apps/api/routers/episodes.py`, and `PresignUploadRequest` in `screenalytics/apps/api/routers/video_assets_v2.py`.

## Code Style

**Formatting:**
- `TRR-APP/apps/web` uses ESLint only. `TRR-APP/apps/web/eslint.config.mjs` is present, but no Prettier, Biome, or prettier config was detected in `TRR-APP/`.
- Quote style in `TRR-APP/apps/web` is not globally normalized. Preserve the surrounding file style instead of mass-reformatting. `TRR-APP/apps/web/tests/setup.ts` uses single quotes while `TRR-APP/apps/web/tests/admin-modal.test.tsx` and `TRR-APP/apps/web/src/app/api/admin/auth/status/route.ts` use double quotes.
- `TRR-Backend/ruff.toml` enforces Ruff formatting conventions with `target-version = "py311"`, `line-length = 120`, `quote-style = "double"`, and `indent-style = "space"`.
- `screenalytics/pyproject.toml` sets both Ruff and Black line length to 120. CI uses Ruff, and the checked-in code follows 4-space indentation and `from __future__ import annotations` at the top of modern modules such as `screenalytics/apps/api/main.py` and `screenalytics/apps/api/errors.py`.

**Linting:**
- `TRR-APP/apps/web/eslint.config.mjs` extends `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`. Keep `@next/next/no-img-element` enabled and only bypass it with an inline justification, matching the rule comment in `TRR-APP/apps/web/eslint.config.mjs`.
- Test files in `TRR-APP/apps/web/tests/**/*` may use `@ts-nocheck` only with a description. This is explicitly allowed in `TRR-APP/apps/web/eslint.config.mjs` and used in `TRR-APP/apps/web/tests/validation.test.ts`.
- `TRR-Backend/ruff.toml` selects `E`, `F`, `I`, `N`, `UP`, `B`, and `C4`. Keep FastAPI dependency defaults explicit and accept `# noqa: B008` where needed, matching `TRR-Backend/tests/api/test_auth.py`.
- `screenalytics/pyproject.toml` ignores `E402`, `F841`, and `E731` because some modules intentionally adjust `sys.path`, keep debug placeholders, or use simple lambda assignments. Do not “fix” those patterns blindly without understanding the module bootstrap path.

## Import Organization

**Order:**
1. Side-effect or future imports first when required by runtime: `import "server-only"` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and `from __future__ import annotations` in Python modules such as `TRR-Backend/api/auth.py` and `screenalytics/apps/api/errors.py`.
2. Standard library imports next, then third-party imports, then local project imports. `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py` follow this consistently.
3. In TypeScript route modules, keep framework imports first and project alias imports after a blank line, as in `TRR-APP/apps/web/src/app/api/admin/auth/status/route.ts`.

**Path Aliases:**
- Use the `@` alias for app-local imports in `TRR-APP/apps/web`. `TRR-APP/apps/web/vitest.config.ts` maps `@` to `TRR-APP/apps/web/src`.
- Use the special `server-only` alias in tests to replace the runtime-only import. `TRR-APP/apps/web/vitest.config.ts` maps it to `TRR-APP/apps/web/tests/mocks/server-only.ts`, and `TRR-APP/apps/web/tests/setup.ts` mocks it globally.
- Python repos rely on direct package imports from the repo root. `screenalytics/tests/conftest.py` prepends `screenalytics/` and `screenalytics/packages/py-screenalytics/src` to `sys.path` instead of using package alias tooling.

## Error Handling

**Patterns:**
- In Next.js route handlers, wrap the handler body in `try`/`catch`, log with `console.error`, and return `NextResponse.json` with an explicit status. `TRR-APP/apps/web/src/app/api/admin/auth/status/route.ts` is the reference pattern.
- In backend dependency and auth code, raise `HTTPException` for client-visible failures and attach headers when the caller needs a machine-readable code, as in `TRR-Backend/api/auth.py`.
- In backend startup and infrastructure code, fail fast with `RuntimeError` and log structured context before raising, as in `TRR-Backend/api/main.py` and `TRR-Backend/trr_backend/object_storage.py`.
- In `screenalytics`, standardize API failures through the envelope installed by `screenalytics/apps/api/errors.py`. Prefer `{code, message, details}` responses instead of ad hoc payloads.
- Use Pydantic field constraints and validators before manual runtime checks when the request shape is part of a Python API contract. `screenalytics/apps/api/schemas/job_params.py` and `screenalytics/apps/api/routers/video_assets_v2.py` are the canonical examples.

## Logging

**Framework:** Python uses `logging`; the Next.js app uses `console` in server routes and scripts.

**Patterns:**
- Initialize `logger = logging.getLogger(__name__)` at module scope in Python modules, as in `TRR-Backend/api/auth.py`, `TRR-Backend/api/main.py`, and `screenalytics/apps/api/main.py`.
- Prefer structured message strings with embedded identifiers rather than freeform prose, for example `[startup-config] ...` in `TRR-Backend/api/main.py` and trace-aware envelopes in `screenalytics/apps/api/errors.py`.
- When client-visible failures are sanitized, still log the original exception server-side. `TRR-APP/apps/web/src/app/api/admin/auth/status/route.ts` and `TRR-Backend/trr_backend/clients/computer_use.py` both do this.

## Comments

**When to Comment:**
- Comment the reason for unusual runtime ordering, dependency stubbing, or environment behavior. Strong examples are the startup comments in `screenalytics/apps/api/main.py` and the constrained-env notes in `screenalytics/tests/conftest.py`.
- Add comments for policy or contract edges, not obvious syntax. `TRR-APP/apps/web/eslint.config.mjs` documents the `no-img-element` exception policy and is a good model.

**JSDoc/TSDoc:**
- TypeScript in `TRR-APP/apps/web` uses regular inline comments more often than formal TSDoc. Do not add verbose docblocks unless the file already uses them.
- Python modules commonly use module docstrings and function docstrings where a dependency or contract needs explanation, for example `TRR-Backend/api/auth.py`, `TRR-Backend/api/deps.py`, and `screenalytics/apps/api/errors.py`.

## Function Design

**Size:** Favor small pure helpers around larger boundary modules. Examples include `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-Backend/api/deps.py`, and `screenalytics/apps/api/errors.py`.

**Parameters:** 
- Prefer typed parameter objects or Pydantic models for API-facing inputs, as in `screenalytics/apps/api/routers/video_assets_v2.py` and `screenalytics/apps/api/routers/runs_v2.py`.
- Use explicit booleans and optional params rather than overloaded positional arguments in app helpers, as in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.

**Return Values:**
- Return plain JSON-serializable objects for app routes and helper functions, as in `TRR-APP/apps/web/src/app/api/admin/auth/status/route.ts`.
- Return dictionaries or typed models in Python service layers, then convert failures into `HTTPException` at the router boundary, as in `TRR-Backend/api/deps.py` and `screenalytics/apps/api/routers/runs.py`.

## Module Design

**Exports:**
- In `TRR-APP/apps/web`, default-export React components and pages, but prefer named exports for utilities and server helpers. `TRR-APP/apps/web/src/components/admin/AdminModal.tsx` and `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` show the split.
- In Python repos, expose functions and classes directly from concrete modules. Re-exporting through package `__init__.py` files is minimal.

**Barrel Files:** Limited. `TRR-APP/apps/web/src/components/survey/index.ts` exists, but most modules are imported directly by file path. Prefer direct imports unless the directory already exposes a barrel.

## Repo-Specific Notes

**`TRR-APP/apps/web`:**
- Keep server-only code under `TRR-APP/apps/web/src/lib/server/`, matching the repo contract in `TRR-APP/AGENTS.md`.
- Use `"use client"` only for interactive components, as in `TRR-APP/apps/web/src/components/admin/AdminModal.tsx`.
- Do not invent backend contracts in UI code. App-side server access is expected to flow through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

**`TRR-Backend`:**
- Keep FastAPI dependencies explicit and testable. `TRR-Backend/api/auth.py` and `TRR-Backend/api/deps.py` are the reference patterns.
- Prefer additive API changes and preserve downstream contracts, matching `TRR-Backend/AGENTS.md`.

**`screenalytics`:**
- Preserve bootstrap order in `screenalytics/apps/api/main.py`: env load first, CPU limits second, heavy imports after.
- Keep Streamlit page initialization first when touching `screenalytics/apps/workspace-ui/`, matching `screenalytics/AGENTS.md`.

---

*Convention analysis: 2026-04-02*
