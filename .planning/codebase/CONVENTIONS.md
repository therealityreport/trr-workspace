# TRR Workspace Conventions Map

Updated from workspace scan on 2026-04-07.

## Cross-Repo Conventions

- Read root `AGENTS.md` first, then repo-local `AGENTS.md`
- Backend-first ordering is required for shared schema/API/auth changes
- Shared env contracts are named explicitly and reused across repos instead of aliasing ad hoc
- Secret values are never meant to be logged or embedded in code; workspace policy calls out `TRR_INTERNAL_ADMIN_SHARED_SECRET` and `SCREENALYTICS_SERVICE_TOKEN`

## Python Style Conventions

### TRR-Backend

- Ruff config is in `TRR-Backend/ruff.toml`
- Target version: Python `3.11`
- Line length: `120`
- Enabled rule families include `E`, `F`, `I`, `N`, `UP`, `B`, `C4`
- Formatting preferences in Ruff:
  - double quotes
  - spaces for indentation
- pytest discovery config is in `TRR-Backend/pytest.ini`

Observed code patterns:

- `from __future__ import annotations` is common in Python modules such as `TRR-Backend/api/main.py`
- routers and services favor typed helper functions and explicit env parsing
- UTC timestamps are commonly generated inline with `datetime.now(UTC).isoformat()`
- environment lookups are wrapped in helper functions rather than scattered raw reads

### screenalytics

- `screenalytics/pyproject.toml` defines Ruff, Black, and pytest options
- Line length: `120`
- Ruff ignore policy explicitly allows some pragmatic legacy patterns:
  - `E402`
  - `F841`
  - `E731`
- pytest uses markers like `slow` and `timeout`
- imports often front-load env/bootstrap logic before heavier runtime imports, especially in `apps/api/main.py` and `apps/workspace-ui/streamlit_app.py`

Observed code patterns:

- dotenv loading happens before other imports when runtime configuration matters
- large services sit in `apps/api/services/*.py`
- feature comments are used to explain runtime constraints, especially for tests and optional dependencies
- test environments heavily use `monkeypatch`, `TestClient`, and module stubs

## TypeScript / React Conventions

### TRR-APP

- ESLint config lives in `TRR-APP/apps/web/eslint.config.mjs`
- TypeScript config is strict in `TRR-APP/apps/web/tsconfig.json`
- path alias `@/*` maps to `src/*`
- Next/React conventions:
  - `import "server-only";` for privileged modules such as `TRR-APP/apps/web/src/lib/server/auth.ts`
  - `"use client"` for interactive components and hooks-heavy files
- tests are granted slightly looser TS rules in ESLint for pragmatism

Observed code patterns:

- server adapters are named by role: `*-repository.ts`, `*-service.ts`, `*-cache.ts`, `*-proxy.ts`
- route helpers and repositories are colocated under `src/lib/server/`
- App Router pages often compose with imported shells rather than embedding all logic inline
- auth and admin concerns are explicit modules rather than ambient middleware magic

## Error Handling Conventions

### Backend

- startup validation fails fast for invalid runtime config in `TRR-Backend/api/main.py`
- backend-specific exception types exist, for example DB service availability types from `trr_backend.db.pg`
- service-to-service auth helpers raise explicit runtime errors on missing secrets

### screenalytics

- optional dependencies are guarded with soft-fail imports in `screenalytics/apps/api/main.py`
- readiness endpoints convert dependency failures into structured status instead of hard crashes where possible
- storage validation code in `screenalytics/apps/api/services/validation.py` classifies transient vs configuration problems

### App

- auth code falls back between provider paths in `TRR-APP/apps/web/src/lib/server/auth.ts`
- backend-base normalization emits development warnings when `TRR_API_URL` points to a remote host
- route caches and admin wrappers suggest an emphasis on stable route responses for complex admin pages

## Naming and Module Organization

- Python tests follow `test_*.py`
- TypeScript tests follow `*.test.ts` or `*.test.tsx`
- admin-heavy frontend modules are grouped under `admin/` prefixes
- router names in backend and screenalytics are feature-first, not generic REST-controller names
- generated files are usually called out explicitly with `generated/` in their path

## Configuration Conventions

- env contracts are validated in CI, not just assumed at runtime
- backend and screenalytics both prefer canonical env names and preserve fallback aliases only where documented
- screenalytics tracking and pipeline configuration resolves with a clear precedence model tested in `screenalytics/apps/workspace-ui/tests/config/test_tracking_defaults.py`
- app build behavior is environment-aware in `TRR-APP/apps/web/next.config.ts`

## Testing-by-Design Conventions

- test helpers use dependency injection and monkeypatching instead of requiring live infra for most unit tests
- app Playwright config runs single-worker, deterministic browser checks
- screenalytics `tests/conftest.py` sets Celery eager mode and lazy dependency stubs to keep local/CI tests deterministic

## Practical Planning Rules

- If changing auth, inspect both Firebase and Supabase code paths in `TRR-APP/apps/web/src/lib/server/auth.ts`
- If changing DB contracts, expect updates in all three repos
- If changing object-storage behavior, check backend media paths, screenalytics storage paths, and any frontend operational scripts
