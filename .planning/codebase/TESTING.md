# Testing Patterns

**Analysis Date:** 2026-04-07

## Test Frameworks

**Primary runners:**
- `pytest` for `TRR-Backend/tests/`
- `vitest` for `TRR-APP/apps/web/tests/`
- `@playwright/test` for `TRR-APP/apps/web/tests/e2e/`
- `pytest` for `screenalytics/tests/`
- Shell aggregators at the workspace root in `scripts/test*.sh`

**Assertions and helpers:**
- Python repos use plain `pytest` assertions with `patch`, `MagicMock`, and `monkeypatch`
- App tests use Vitest, Testing Library, and `vitest-axe`
- Browser tests use Playwright expectations plus route/network stubbing

## Canonical Commands

```bash
make test-fast
make test-full
make test-changed
make test-env-sensitive

cd TRR-Backend && ruff check . && ruff format --check . && pytest -q
cd TRR-APP/apps/web && pnpm run lint && pnpm exec next build --webpack && pnpm run test:ci
cd TRR-APP/apps/web && pnpm run test:e2e
cd screenalytics && pytest -q
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v
```

## Test File Organization

**TRR-Backend:**
- Tests live in a dedicated top-level tree under `TRR-Backend/tests/`
- Major areas include `api/`, `db/`, `repositories/`, `services/`, `pipeline/`, `integrations/`, `media/`, and `socials/`

**TRR-APP:**
- Unit/component/route tests live under `TRR-APP/apps/web/tests/`
- Browser specs live under `TRR-APP/apps/web/tests/e2e/`

**screenalytics:**
- Tests are split across `tests/api/`, `tests/unit/`, `tests/ui/`, `tests/ml/`, `tests/integration/`, `tests/audio/`, and feature-specific trees

**Workspace scripts:**
- Root-level orchestration and policy checks also have Python/shell tests such as `scripts/test_runtime_db_env.py` and `scripts/test_sync_handoffs.py`

## Common Structure

**Python pattern:**
- Autouse fixtures are used heavily for env resets, cache clearing, and dependency isolation
- Route tests often use `TestClient(app)` plus targeted patching of dependencies or DB/storage helpers

**Vitest pattern:**
- Modules are mocked with `vi.mock(...)`
- `beforeEach` resets mocks and test state
- Route handlers are called directly with `NextRequest`

**Playwright pattern:**
- Single-worker Chromium execution
- Trace/screenshots/videos retained on failure
- Can run against either a managed local dev server or an externally supplied base URL

## Mocking Patterns

**What gets mocked:**
- Auth checks
- External HTTP calls
- Database probes or admin clients
- Heavy ML/runtime dependencies
- Browser/network routes for app E2E

**What stays real when practical:**
- Pure normalization/formatting helpers
- Checked-in generated artifacts that are compared against regeneration
- Source-file compilation checks for Streamlit or page modules

## Fixtures and Factories

- Backend keeps static payloads under `TRR-Backend/tests/fixtures/`
- App uses `TRR-APP/apps/web/tests/fixtures/` and E2E factory helpers like `admin-fixtures.ts`
- Screenalytics keeps reusable helpers in `screenalytics/tests/helpers/`

## Coverage and Gating

- `TRR-APP/apps/web/vitest.config.ts` emits `text`, `html`, and `lcov` coverage under `coverage/`
- No hard global coverage threshold is obvious from the inspected configs
- CI gating is more command- and lane-based than percentage-based

## CI Patterns

**TRR-Backend CI highlights:**
- Env contract validation
- Lockfile freshness
- Import gate
- API-focused pytest lanes
- Secret scanning and repo map automation

**TRR-APP CI highlights:**
- Node 24 full lane plus Node 22 compatibility lane
- Lint, targeted typecheck, Vitest CI, and build
- Separate Firestore rules CI

**screenalytics CI highlights:**
- Lockfile freshness for multiple requirements files
- Ruff policy enforcement
- Compile gates for critical modules
- Split unit, smoke, and py312 canary lanes
- Repo-map and Codex review workflows

## Test Types

**Unit tests:**
- Helper normalization, config resolution, parser logic, and isolated service behavior

**API / integration tests:**
- FastAPI route behavior, auth enforcement, storage and DB interactions, queue/job semantics

**UI/component tests:**
- React component rendering and route handler tests in the app
- Streamlit-related source/behavior checks in screenalytics

**Browser E2E:**
- Present primarily in `TRR-APP`

## Gaps Worth Remembering

- Workspace shell orchestration has lighter direct automated coverage than the product repos
- The largest app admin pages are more lightly covered at the full-page orchestration level than their helper modules
- Screenalytics UI and long pipeline/tool flows still depend heavily on targeted, selective testing rather than exhaustive end-to-end automation

---

*Testing analysis refreshed: 2026-04-07*
