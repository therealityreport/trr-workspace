# TRR Workspace Testing

## Scope

This document maps the current testing setup across the three primary repos and the validation commands that are expected before handoff.

## Workspace-Level Validation Contract

Per `AGENTS.md`, the default fast checks for touched repos are:

- `TRR-Backend`: `ruff check . && ruff format --check . && pytest -q`
- `screenalytics`: `pytest -q`
- `TRR-APP`: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`

For cross-repo work, validation is repo-specific rather than a single top-level test runner.

## `TRR-APP` Testing

### Frameworks

- Unit/component/server tests: Vitest from `TRR-APP/apps/web/vitest.config.ts`
- Browser/e2e tests: Playwright from `TRR-APP/apps/web/playwright.config.ts`
- DOM environment: `jsdom`
- React/component assertions: `@testing-library/react`, `@testing-library/jest-dom`

### Config

- Vitest config: `TRR-APP/apps/web/vitest.config.ts`
- Playwright config: `TRR-APP/apps/web/playwright.config.ts`
- Test setup file: `TRR-APP/apps/web/tests/setup.ts`

### Test Organization

- Main test tree: `TRR-APP/apps/web/tests/`
- E2E tests: `TRR-APP/apps/web/tests/e2e/`
- Test fixtures: `TRR-APP/apps/web/tests/fixtures/`
- Mocks: `TRR-APP/apps/web/tests/mocks/`

### Coverage Shape

Observed emphasis:

- route proxy behavior
- admin auth and access boundaries
- route alias and rewrite stability
- UI components and admin wiring
- integration points with backend admin endpoints
- design-docs tooling and font/media pipelines

The test tree is broad and behavior-oriented, with many route-specific tests protecting URL shape and server-side mediation logic.

## `TRR-Backend` Testing

### Frameworks

- Test runner: pytest via `TRR-Backend/pytest.ini`
- Python import root: `pythonpath = .`
- Test discovery root: `TRR-Backend/tests/`

### Config

- Pytest config: `TRR-Backend/pytest.ini`
- Lint/format config: `TRR-Backend/ruff.toml`

### Test Organization

Representative directories:

- API smoke and contract tests in `TRR-Backend/tests/`
- Media and storage tests in `TRR-Backend/tests/media/`
- Ingestion tests in `TRR-Backend/tests/ingestion/`
- Vision-related tests in `TRR-Backend/tests/vision/`

### Coverage Shape

Observed emphasis:

- media storage and mirroring
- upload/session validation
- ingestion enrichment logic
- API smoke coverage
- fallback and error-path behavior

The backend test strategy looks pragmatic: protect high-risk integration-heavy paths rather than trying to exhaustively unit test every router line.

## `screenalytics` Testing

### Frameworks

- Primary runner: pytest configured in `screenalytics/pyproject.toml`
- Formatting/lint gates: Ruff and Black via `screenalytics/pyproject.toml` and `.pre-commit-config.yaml`

### Config

- Pytest settings: `screenalytics/pyproject.toml`
- Pre-commit hooks: `screenalytics/.pre-commit-config.yaml`
- Optional ML/test gating through env markers such as `RUN_ML_TESTS=1`

### Test Organization

Main trees:

- API tests: `screenalytics/tests/api/`
- Audio tests: `screenalytics/tests/audio/`
- ML tests: `screenalytics/tests/ml/`
- Integration tests: `screenalytics/tests/integration/`
- Feature tests: `screenalytics/tests/FEATURES/`
- Facebank tests: `screenalytics/tests/facebank/`
- MCP/tooling tests: `screenalytics/tests/mcps/`
- Tool/helper tests: `screenalytics/tests/tools/`
- Workspace UI tests: `screenalytics/apps/workspace-ui/tests/`

### Coverage Shape

Observed emphasis:

- run and job state
- artifact storage and recovery
- screentime math and QA
- Celery behavior and controls
- API regressions around episodes, cast, facebank, and grouping
- ML pipeline stage behavior, often behind optional dependencies

This repo has the deepest and most partitioned test surface in the workspace.

## Test Design Patterns

Across repos, several patterns repeat:

- route or endpoint tests for transport boundaries
- regression tests named after the exact feature or failure mode
- explicit skip/feature gating for heavyweight ML or integration dependencies
- mocks and fixtures for server-only or subprocess-heavy code
- emphasis on idempotency, locking, streaming, and recovery for job systems

## What Gets Validated Outside Pure Tests

Not all quality gates are test-runner based:

- Next.js build in `TRR-APP` is part of the required validation path
- Ruff/format checks are part of backend validation
- Streamlit and authenticated browser checks are expected for UI-heavy changes
- managed workspace startup and health scripts provide operational verification at the root level

## Testing Read

The workspace testing posture is strongest around:

- contract and route stability
- media/storage correctness
- long-running job safety
- pipeline and artifact recovery
- admin UI regressions

The weakest areas are likely the places where validation depends on full environment setup, remote services, or manual browser confirmation rather than a fast deterministic local test.
