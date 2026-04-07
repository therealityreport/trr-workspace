# TRR Workspace Testing Map

Updated from workspace scan on 2026-04-07.

## Workspace-Level Fast Checks

From root `AGENTS.md`:

- `TRR-Backend` -> `ruff check . && ruff format --check . && pytest -q`
- `screenalytics` -> `pytest -q`
- `TRR-APP` -> `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`

These are the baseline validation expectations when a repo is touched.

## TRR-Backend Testing

## Tooling

- pytest configured in `TRR-Backend/pytest.ini`
- Ruff config in `TRR-Backend/ruff.toml`
- CI workflow in `TRR-Backend/.github/workflows/ci.yml`

## CI Coverage Shape

- env contract validation
- lockfile freshness check via `uv pip compile`
- import gate on `api.main`
- API test run through `python -m pytest tests/api -q`
- optional Python `3.12` canary lane

## Local/Repo Commands

- `TRR-Backend/Makefile` includes:
  - `doctor`
  - `schema-docs`
  - `schema-docs-check`
  - `schema-docs-reset-check`
  - `ci-local`

## Test Layout

- API tests: `TRR-Backend/tests/api/`
- DB tests: `TRR-Backend/tests/db/`
- integration/provider tests: `TRR-Backend/tests/integrations/`
- repository tests: `TRR-Backend/tests/repositories/`
- media tests: `TRR-Backend/tests/media/`
- pipeline tests: `TRR-Backend/tests/pipeline/`
- script regression tests: `TRR-Backend/tests/scripts/`

This repo has broad test coverage by module family, not just smoke coverage.

## Typical Testing Style

- focused per-module tests such as `TRR-Backend/tests/repositories/test_social_sync_orchestrator.py`
- heavy use of isolated unit tests and monkeypatched integrations
- explicit DB and migration checks exist alongside pure unit tests

## screenalytics Testing

## Tooling

- pytest configuration in `screenalytics/pyproject.toml`
- CI workflow in `screenalytics/.github/workflows/ci.yml`

## CI Coverage Shape

- env contract validation
- requirements lock freshness checks
- Ruff policy enforcement scripts
- compile/import gates for key API modules
- targeted unit/API/ML subsets rather than one giant blanket run
- smoke dry-run workflow for pipeline execution
- optional `3.12` canary lane

## Local/Repo Commands

- repo-local guidance from `screenalytics/AGENTS.md`:
  - `python -m py_compile <touched_files>`
  - `pytest tests/unit/ -v`
  - `RUN_ML_TESTS=1 pytest tests/ml/ -v`
- `screenalytics/Makefile` also supports repo-map and Crawl4AI verification helpers

## Test Layout

- API tests: `screenalytics/tests/api/`
- audio tests: `screenalytics/tests/audio/`
- facebank tests: `screenalytics/tests/facebank/`
- tools tests: `screenalytics/tests/tools/`
- MCP tests: `screenalytics/tests/mcps/`
- workspace UI tests: `screenalytics/apps/workspace-ui/tests/`

## Typical Testing Style

- `screenalytics/tests/conftest.py` configures Celery eager mode
- optional heavy deps are stubbed or lazily imported for test stability
- FastAPI routes are commonly exercised with `fastapi.testclient.TestClient`
- `monkeypatch` is the dominant approach for env and dependency isolation

## TRR-APP Testing

## Tooling

- ESLint config: `TRR-APP/apps/web/eslint.config.mjs`
- Vitest config: `TRR-APP/apps/web/vitest.config.ts`
- Playwright config: `TRR-APP/apps/web/playwright.config.ts`
- CI workflow: `TRR-APP/.github/workflows/web-tests.yml`

## CI Coverage Shape

- Node `24` full lane
- Node `22` compatibility lane
- lint
- targeted typecheck
- Vitest coverage run
- targeted smoke subsets on compat lane
- `next build --webpack` with placeholder Firebase config and no `DATABASE_URL`

## Test Layout

- unit/integration route and component tests are mostly flat in `TRR-APP/apps/web/tests/`
- end-to-end tests live in `TRR-APP/apps/web/tests/e2e/`
- examples:
  - route tests such as `TRR-APP/apps/web/tests/cast-screentime-proxy-route.test.ts`
  - component tests such as `TRR-APP/apps/web/tests/cast-screentime-page.test.tsx`
  - browser smoke tests such as `TRR-APP/apps/web/tests/e2e/homepage-visual-smoke.spec.ts`

## Typical Testing Style

- jsdom environment
- global Vitest APIs enabled
- alias mapping for `@` and `server-only` mocks in `TRR-APP/apps/web/vitest.config.ts`
- Playwright defaults favor determinism:
  - single worker
  - headless
  - retained trace/screenshot/video on failure

## Gaps and Practical Notes

- Backend CI only runs `tests/api` in the main workflow, so broader suites may rely on local discipline or other workflows
- screenalytics has broad tests but many heavy ML paths are still guarded behind markers, eager mode, or fake/local backends
- app tests are extensive, but the route surface is so large that targeted tests still matter when modifying admin flows or rewrites
