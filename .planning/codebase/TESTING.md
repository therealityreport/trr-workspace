# Testing Patterns

**Analysis Date:** 2026-04-06

## Test Framework

**Runner:**
- `TRR-Backend`: `pytest` with config in `TRR-Backend/pytest.ini`.
- `TRR-APP`: `vitest` for unit/component/route tests in `TRR-APP/apps/web/vitest.config.ts`.
- `TRR-APP` browser coverage: `@playwright/test` in `TRR-APP/apps/web/playwright.config.ts`.
- `screenalytics`: `pytest` configured in `screenalytics/pyproject.toml`.
- Workspace orchestration: shell wrappers in `scripts/test-fast.sh`, `scripts/test.sh`, `scripts/test-full.sh`, `scripts/test-changed.sh`, and `scripts/test-env-sensitive.sh`.

**Assertion Library:**
- Python repos use plain `pytest` assertions plus `unittest.mock.patch` / `monkeypatch`.
- `TRR-APP` uses Vitest assertions and Testing Library through `TRR-APP/apps/web/tests/setup.ts`.
- Playwright specs use Playwright `expect(...)`.

**Run Commands:**
```bash
make test-fast                     # Workspace smoke checks across all three repos
make test-full                     # Workspace full wrapper; currently dispatches scripts/test.sh
make test-changed                  # Scope-aware test routing based on git changes
make test-env-sensitive            # Cross-repo env/runtime-sensitive regression gate

cd TRR-Backend && ruff check . && ruff format --check . && pytest -q
cd TRR-APP/apps/web && pnpm run lint && pnpm exec next build --webpack && pnpm run test:ci
cd TRR-APP/apps/web && pnpm run test:e2e
cd screenalytics && pytest -q
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v
```

## Test File Organization

**Location:**
- `TRR-Backend` keeps tests in a dedicated top-level `TRR-Backend/tests/` tree grouped by subsystem: `api/`, `repositories/`, `db/`, `ingestion/`, `integrations/`, `media/`, `pipeline/`, `scripts/`, `services/`, and more.
- `TRR-APP` keeps all unit/component/route tests under `TRR-APP/apps/web/tests/` and browser tests under `TRR-APP/apps/web/tests/e2e/`.
- `screenalytics` keeps tests under `screenalytics/tests/` with explicit layers such as `api/`, `unit/`, `ui/`, `ml/`, `integration/`, `audio/`, `mcps/`, and `FEATURES/`.
- Workspace policy and script tests live at the root in files like `scripts/test_runtime_db_env.py` and `scripts/test_sync_handoffs.py`.

**Naming:**
- Python test files use `test_*.py` and sometimes class-based grouping inside the file. Examples: `TRR-Backend/tests/db/test_connection_resolution.py`, `screenalytics/tests/unit/test_defaults_format.py`.
- Vitest files use `*.test.ts` and `*.test.tsx`. Examples: `TRR-APP/apps/web/tests/admin-fetch.test.ts`, `TRR-APP/apps/web/tests/profile-page.test.tsx`.
- Playwright files use `*.spec.ts`. Examples: `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts`.

**Structure:**
```text
TRR-Backend/tests/{api,repositories,db,integrations,...}/test_*.py
TRR-APP/apps/web/tests/**/*.test.ts(x)
TRR-APP/apps/web/tests/e2e/**/*.spec.ts
screenalytics/tests/{api,unit,ui,ml,integration,...}/test_*.py
scripts/test_*.py
```

## Test Structure

**Suite Organization:**
```python
# Python pattern from TRR-Backend/tests/db/test_connection_resolution.py
@pytest.fixture(autouse=True)
def _clear_resolution_cache() -> None:
    ...

def test_resolve_database_url_candidates_prefers_trr_runtime_envs(...) -> None:
    ...
```

```typescript
// Vitest pattern from TRR-APP/apps/web/tests/people-home-route.test.ts
describe("/api/admin/trr-api/people/home", () => {
  beforeEach(() => {
    ...
  });

  it("returns all five sections from the backend-owned contract", async () => {
    ...
  });
});
```

```typescript
// Playwright pattern from TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts
test.describe("cast + season tabs smoke (mocked)", () => {
  test("season cast sync enters running state and cancels cleanly", async ({ page }) => {
    ...
  });
});
```

**Patterns:**
- Use autouse fixtures aggressively for cache clearing and environment cleanup in Python. Examples: `TRR-Backend/tests/db/test_connection_resolution.py`, `TRR-Backend/tests/api/routers/conftest.py`.
- Prefer scenario-specific helpers over huge global factories.
  - Backend: in-memory operation store fixture in `TRR-Backend/tests/api/routers/conftest.py`.
  - App e2e: fixture builders in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.
  - Screenalytics: helper modules in `screenalytics/tests/helpers/`.
- Keep route tests near contract expectations rather than full-stack boot. `TRR-Backend/tests/api/test_health.py` mounts a tiny FastAPI app just for the route under test.

## Mocking

**Framework:** `pytest` fixtures with `patch` / `patch.object` / `monkeypatch`, Vitest `vi.mock` / `vi.stubGlobal`, and Playwright `page.route`.

**Patterns:**
```python
# Python route/service mocking from screenalytics/tests/api/test_trr_health.py
with patch("apps.api.routers.metadata.ping", return_value=True):
    response = client.get("/metadata/trr/health")
```

```typescript
// Vitest module mocking from TRR-APP/apps/web/tests/people-home-route.test.ts
vi.mock("@/lib/server/auth", () => ({
  requireAdmin: requireAdminMock,
}));
```

```typescript
// Playwright network mocking from TRR-APP/apps/web/tests/e2e/admin-fixtures.ts
await page.route("**/api/admin/**", async (route) => {
  await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(body) });
});
```

**What to Mock:**
- External services, remote HTTP calls, database probes, and auth checks.
  - `TRR-Backend/tests/api/test_health.py` patches DB connection helpers.
  - `screenalytics/tests/api/test_trr_health.py` patches metadata DB probes.
  - `TRR-APP/apps/web/tests/setup.ts` mocks `next/image`, `server-only`, Firebase, and browser APIs.
- Heavy or optional runtime dependencies in `screenalytics`.
  - `screenalytics/tests/conftest.py` puts Celery into eager mode, lazily imports NumPy, and installs a `cv2` stub when OpenCV is absent.

**What NOT to Mock:**
- Pure formatting, normalization, and contract logic when it can run locally.
  - Examples: `TRR-Backend/tests/db/test_connection_resolution.py`, `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`, `screenalytics/tests/unit/test_defaults_format.py`.
- Streamlit source compilation checks do not mock the source text itself; `screenalytics/tests/ui/test_streamlit_pages_compile.py` reads real page files through `screenalytics/tests/helpers/workspace_ui_source.py`.

## Fixtures and Factories

**Test Data:**
```typescript
// Factory pattern from TRR-APP/apps/web/tests/e2e/admin-fixtures.ts
export const buildShowCastMember = (personId: string, name: string, overrides = {}) => ({
  person_id: personId,
  full_name: name,
  ...overrides,
});
```

```python
# Autouse fixture pattern from TRR-Backend/tests/api/routers/conftest.py
@pytest.fixture(autouse=True)
def _in_memory_admin_operation_store(monkeypatch: pytest.MonkeyPatch) -> None:
    ...
```

**Location:**
- Static backend fixture payloads live in `TRR-Backend/tests/fixtures/`.
- App fixture files live in `TRR-APP/apps/web/tests/fixtures/` and `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.
- Screenalytics helpers live in `screenalytics/tests/helpers/`.

## Coverage

**Requirements:** No enforced global percentage threshold detected.
- `TRR-APP/apps/web/vitest.config.ts` generates `text`, `html`, and `lcov` reports under `TRR-APP/apps/web/coverage`, but no threshold gate is configured.
- `screenalytics/requirements-ci.txt` includes `pytest-cov`, but no repository-level coverage threshold or report command is wired in the files inspected.
- `TRR-Backend` has no repo-level coverage config in `pytest.ini` or `ruff.toml`.

**View Coverage:**
```bash
cd TRR-APP/apps/web && pnpm run test
open TRR-APP/apps/web/coverage/index.html
```

## Test Types

**Unit Tests:**
- `TRR-Backend` unit-style tests focus on repository helpers, DB resolution, and parser logic. Examples: `TRR-Backend/tests/db/test_connection_resolution.py`, `TRR-Backend/tests/repositories/test_admin_operations.py`.
- `screenalytics/tests/unit/` is the main pure-logic layer for config resolution, runtime defaults, artifact contracts, and runner behavior.
- `TRR-APP/apps/web/tests/` mixes pure helper tests, route-handler tests, and isolated component tests under Vitest.

**Integration Tests:**
- `TRR-Backend/tests/integrations/` and parts of `tests/repositories/` exercise parsing and persistence semantics with realistic payloads and fixtures.
- `screenalytics/tests/integration/`, `tests/api/`, `tests/audio/`, and `tests/ml/` cover cross-module behavior. ML tests are intentionally segregated and sometimes gated by `RUN_ML_TESTS=1`.
- Workspace integration and policy checks live in `scripts/test_sync_handoffs.py`, `scripts/test_runtime_db_env.py`, `scripts/check-policy.sh`, and `scripts/check-workspace-contract.sh`.

**E2E Tests:**
- `TRR-APP` is the only repo with browser E2E in the inspected workspace, using Playwright from `TRR-APP/apps/web/playwright.config.ts`.
- The Playwright config runs a single Chromium worker, records traces/screenshots/videos on failure, and can either boot a local webpack dev server or hit an externally supplied base URL.
- `screenalytics` and `TRR-Backend` rely on API and script-level integration tests rather than browser E2E.

## Verification Commands

- Workspace-wide fast lane:
  - `make test-fast`
  - Runs `ruff` plus a backend health test, app lint only, and screenalytics `py_compile` plus `tests/api/test_trr_health.py` via `scripts/test-fast.sh`.
- Workspace-wide full lane:
  - `make test-full`
  - Dispatches `scripts/test.sh`, which is still intentionally lighter than each repo’s deepest suite. It runs the full backend pytest suite, app lint/build/Vitest CI, and only a narrow screenalytics smoke lane.
- Change-scoped lane:
  - `make test-changed`
  - Uses git diff to decide between per-repo `test-fast` lanes and workspace policy checks.
- Env-sensitive lane:
  - `make test-env-sensitive`
  - Exercises one backend env-sensitive regression, the full `screenalytics/tests/unit` suite, and app lint/typecheck/Vitest CI.
- Repo-local fast checks required by policy:
  - `TRR-Backend/AGENTS.md`
  - `TRR-APP/AGENTS.md`
  - `screenalytics/AGENTS.md`
  - `docs/cross-collab/WORKFLOW.md`
- UI verification after admin or route changes should include targeted managed-Chrome or `chrome-devtools` validation per `AGENTS.md` and `TRR-APP/AGENTS.md`, even when automated tests pass.

## Common Patterns

**Async Testing:**
```typescript
// TRR-APP async pattern from TRR-APP/apps/web/tests/admin-fetch.test.ts
await expect(fetchWithTimeout("/api/test", {}, 5)).rejects.toMatchObject({
  name: "AbortError",
});
```

```python
# Screenalytics service test pattern from screenalytics/tests/api/test_trr_health.py
with patch("apps.api.routers.metadata.ping", return_value=False):
    response = client.get("/metadata/trr/health")
```

**Error Testing:**
```python
# Backend error-path assertion from TRR-Backend/tests/api/test_health.py
assert resp.status_code == 503
assert body["status"] == "degraded"
```

```typescript
// Runtime contract assertion from TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts
expect(() => resolvePostgresConnectionString({})).toThrow(
  "No database connection string is set. Configure TRR_DB_URL ..."
);
```

## Practical Boundaries

- Put new backend tests beside the layer they protect in `TRR-Backend/tests/`.
  - Router contract or status-code behavior: `tests/api/`
  - DB/runtime env contract: `tests/db/`
  - repository semantics: `tests/repositories/`
- Put new app tests in `TRR-APP/apps/web/tests/` unless the behavior truly requires a browser; then use `TRR-APP/apps/web/tests/e2e/`.
- Put new screenalytics tests in the narrowest existing bucket:
  - pure logic in `screenalytics/tests/unit/`
  - API route behavior in `screenalytics/tests/api/`
  - Streamlit compilation and UI helpers in `screenalytics/tests/ui/`
  - ML/runtime-heavy behavior in `screenalytics/tests/ml/`
- If a change touches workspace scripts, policy, or handoff generation, add or update focused root-level tests under `scripts/` instead of hiding that behavior in a repo-local suite.

---

*Testing analysis: 2026-04-06*
