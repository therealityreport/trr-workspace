# Testing Patterns

**Analysis Date:** 2026-04-04

## Test Framework

**Runner:**
- `TRR-Backend/` uses `pytest`, configured in `TRR-Backend/pytest.ini`.
- `TRR-APP/apps/web/` uses `Vitest` for unit and runtime tests via `TRR-APP/apps/web/vitest.config.ts`.
- `TRR-APP/apps/web/` uses `Playwright` for browser smoke and admin-flow coverage via `TRR-APP/apps/web/playwright.config.ts`.
- `screenalytics/` uses `pytest`, configured through `[tool.pytest.ini_options]` in `screenalytics/pyproject.toml`.

**Assertion Library:**
- Python repos use plain `assert` with `pytest`.
- `TRR-APP/apps/web/` uses Vitest `expect` plus React Testing Library and `@testing-library/jest-dom`.

**Run Commands:**

```bash
# Workspace wrappers from `docs/workspace/dev-commands.md`
make test-fast
make test-full
make test-changed

# TRR-Backend
cd TRR-Backend && ruff check . && ruff format --check . && pytest -q

# TRR-APP
cd TRR-APP && pnpm -C apps/web run lint
cd TRR-APP && pnpm -C apps/web exec next build --webpack
cd TRR-APP && pnpm -C apps/web run test:ci
cd TRR-APP && pnpm -C apps/web run test:e2e

# screenalytics
cd screenalytics && pytest -q
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v
```

## Test File Organization

**Location:**
- `TRR-Backend/` keeps tests under `TRR-Backend/tests/`, grouped by subsystem such as `tests/api/`, `tests/repositories/`, `tests/socials/`, `tests/scripts/`, and `tests/integrations/`.
- `TRR-APP/` keeps app tests in a single top-level tree under `TRR-APP/apps/web/tests/`, with `e2e/`, `fixtures/`, `mocks/`, and domain-specific files side by side.
- `screenalytics/` keeps broad repo tests under `screenalytics/tests/`, feature-specific suites under `screenalytics/FEATURES/*/tests/`, and Streamlit test bootstrap in `screenalytics/apps/workspace-ui/tests/`.

**Naming:**
- Python test files follow `test_<behavior>.py`.
- Vitest files use `*.test.ts` and `*.test.tsx`.
- UI runtime-specific tests in `TRR-APP/apps/web/tests/` append `.runtime.test.tsx`.
- Multi-step app flow tests append `.flow.test.tsx`.
- Playwright tests use `*.spec.ts` under `TRR-APP/apps/web/tests/e2e/`.

**Structure:**

```text
TRR-Backend/tests/
  api/
  repositories/
  services/
  socials/
  fixtures/

TRR-APP/apps/web/tests/
  *.test.ts
  *.test.tsx
  e2e/*.spec.ts
  fixtures/
  mocks/

screenalytics/tests/
  api/
  unit/
  ml/
  integration/
  helpers/
screenalytics/FEATURES/*/tests/
```

## Test Structure

**Suite Organization:**

Use small focused suites with fixtures near the top, then behavior-specific test functions. Representative patterns:

```python
@pytest.fixture
def client():
    return TestClient(app)

def test_trr_health_returns_503_when_url_not_set(client, monkeypatch):
    monkeypatch.delenv("TRR_DB_URL", raising=False)
    response = client.get("/metadata/trr/health")
    assert response.status_code == 503
```

From `screenalytics/tests/api/test_trr_health.py`.

```python
def test_require_user_valid_token_returns_user(monkeypatch):
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret-32-bytes-minimum-abcdef")
    client = TestClient(_build_app())
    response = client.get("/auth/required", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
```

From `TRR-Backend/tests/api/test_auth.py`.

```typescript
describe("AdminGlobalHeader", () => {
  beforeEach(() => {
    usePathnameMock.mockReset();
    localStorage.clear();
  });

  it("shows expected menu items and empty recent-shows state", async () => {
    render(<AdminGlobalHeader />);
    fireEvent.click(screen.getByRole("button", { name: "Open admin navigation menu" }));
    await waitFor(() => {
      expect(screen.getByRole("navigation", { name: "Admin navigation" })).toBeInTheDocument();
    });
  });
});
```

From `TRR-APP/apps/web/tests/admin-global-header.test.tsx`.

**Patterns:**
- Setup is explicit and local to the suite unless it truly needs repo-wide behavior.
- State restoration matters. Tests usually reset env vars, dependency overrides, caches, or globals in `afterEach` or fixture teardown.
- Test names describe the business or route behavior, not just the method under test.

## Mocking

**Framework:**
- `pytest` fixtures, `monkeypatch`, and `unittest.mock.patch` dominate in Python.
- `vi.mock`, `vi.stubGlobal`, and hoisted mocks dominate in `TRR-APP/apps/web/tests/`.
- Playwright browser tests use `page.route()` to intercept admin APIs and stream endpoints.

**Patterns:**

**TRR-Backend dependency override pattern**

```python
app.dependency_overrides[deps.get_supabase_client] = lambda: mock_supabase
app.dependency_overrides[deps.get_supabase_admin_client] = lambda: mock_supabase
yield TestClient(app)
app.dependency_overrides.clear()
```

From `TRR-Backend/tests/test_api_smoke.py`.

**TRR-Backend monkeypatch-heavy service pattern**

```python
monkeypatch.setattr(runtime, "load_run_contract", lambda run_id: dict(run_contract, id=run_id))
monkeypatch.setattr(runtime.cast_screentime, "update_run", lambda run_id, payload: ...)
```

From `TRR-Backend/tests/services/test_retained_cast_screentime_runtime.py`.

**TRR-APP Vitest global mock pattern**

```typescript
vi.mock("next/navigation", () => ({
  usePathname: usePathnameMock,
}));

vi.stubGlobal("fetch", fetchMock);
```

From `TRR-APP/apps/web/tests/admin-global-header.test.tsx`.

**TRR-APP shared setup pattern**

```typescript
vi.mock("next/image", () => ({
  __esModule: true,
  default: (...) => React.createElement("img", rest),
}));
```

From `TRR-APP/apps/web/tests/setup.ts`.

**Playwright request interception pattern**

```typescript
await page.route("**/api/admin/**", async (route) => {
  return route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify(body),
  });
});
```

From `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.

**screenalytics Celery eager pattern**

```python
celery_app.conf.update(
    task_always_eager=True,
    task_eager_propagates=True,
    result_backend="cache+memory://",
    broker_url="memory://",
)
```

From `screenalytics/tests/conftest.py`.

**What to Mock:**
- External services, DB clients, background workers, and long-running ML steps.
- Browser API holes in jsdom, such as `matchMedia`, as in `TRR-APP/apps/web/tests/setup.ts`.
- Route-layer HTTP calls in Playwright and Vitest when the UI contract is the thing under test.

**What NOT to Mock:**
- Local pure data transforms and validation helpers.
- React component rendering semantics when DOM assertions are the purpose of the test.
- FastAPI request/response plumbing when `TestClient` can exercise the real route code cheaply.

## Fixtures and Factories

**Test Data:**
- `TRR-Backend/tests/fixtures/` stores HTML and JSON snapshots for Fandom, IMDb, TMDb, scraping, socials, and Wikipedia parsing.
- `TRR-APP/apps/web/tests/fixtures/` stores UI-specific or design-docs inputs such as `TRR-APP/apps/web/tests/fixtures/design-docs-agent/nyt-article.html`.
- `screenalytics/tests/helpers/` stores shared stubs and test-only adapters such as `screenalytics/tests/helpers/celery_stubs.py`.
- Golden-data fixtures for cast screentime live in `screenalytics/config/cast_screentime_golden/fixtures/`.

**Location:**
- Keep parser and scraper fixtures close to the repo that owns the parsing logic.
- Use helper modules for reusable test-only infrastructure:
  - `TRR-Backend/tests/api/routers/conftest.py`
  - `TRR-APP/apps/web/tests/setup.ts`
  - `screenalytics/tests/conftest.py`
  - `screenalytics/tests/helpers/`

## Coverage

**Requirements:** No hard coverage threshold is enforced in the active repos.

**Observed tooling:**
- `TRR-APP/apps/web/vitest.config.ts` enables `v8` coverage and writes `text`, `html`, and `lcov` reports to `coverage/`.
- `TRR-APP/.github/workflows/web-tests.yml` uploads `apps/web/coverage` on the Node 24 full lane.
- `screenalytics/requirements-ci.txt` includes `pytest-cov`, but the checked-in CI workflow does not currently invoke it.
- `TRR-Backend/` does not declare coverage reporting in its default config or CI workflow.

**View Coverage:**

```bash
cd TRR-APP && pnpm -C apps/web run test:ci -- --coverage
cd screenalytics && pytest --cov
cd TRR-Backend && pytest --cov
```

The last two commands are available if local dependencies support them, but they are not the documented default verification path today.

## Test Types

**Unit Tests:**
- `TRR-Backend/tests/utils/`, `TRR-Backend/tests/db/`, `TRR-Backend/tests/pipeline/`, and many `tests/repositories/` files behave as unit or near-unit tests.
- `TRR-APP/apps/web/tests/*.test.ts[x]` covers utilities, components, route handlers, and server helpers in process.
- `screenalytics/tests/unit/` and `screenalytics/tests/ml/` cover library and ML pipeline behavior directly.

**Integration Tests:**
- `TRR-Backend/tests/integrations/` and `TRR-Backend/tests/api/` validate parser, repository, and route contracts.
- `screenalytics/tests/api/` frequently exercises end-to-end FastAPI behavior through `TestClient`.
- `screenalytics/tests/api/test_jobs_smoke.py` is a full API smoke path but is gated behind `RUN_ML_TESTS=1`.

**E2E Tests:**
- `TRR-APP/apps/web/tests/e2e/` uses Playwright for admin navigation, keyboard behavior, deep links, and homepage smoke.
- Playwright runs headless with a single Chromium worker and can boot a local webpack-based Next dev server automatically per `TRR-APP/apps/web/playwright.config.ts`.
- `TRR-Backend/` and `screenalytics/` do not have a browser E2E harness in the active repo roots.

## CI Verification

**Workspace policy:**
- `AGENTS.md` defines the cross-repo fast-check contract:
  - `TRR-Backend`: `ruff check . && ruff format --check . && pytest -q`
  - `TRR-APP`: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`
  - `screenalytics`: `pytest -q`

**Repo CI workflows currently enforce narrower subsets than local guidance:**
- `TRR-Backend/.github/workflows/ci.yml` imports `api.main` and runs only `python -m pytest tests/api -q`.
- `TRR-APP/.github/workflows/web-tests.yml` runs lint, targeted typecheck, Vitest, and build only for `apps/web/**` path changes; it does not run Playwright.
- `screenalytics/.github/workflows/ci.yml` runs curated test lists rather than the full `tests/` tree, plus a smoke dry-run lane and a Python 3.12 canary.

## Common Patterns

**Async Testing:**

Use synchronous test clients where possible, and only poll when the runtime contract itself is asynchronous.

```python
status = _api_request(client, "GET", f"/jobs/{job_id}")
if state in {"succeeded", "failed", "canceled"}:
    return status
time.sleep(poll_interval)
```

From `screenalytics/tests/api/test_jobs_smoke.py`.

```typescript
await waitFor(() => {
  expect(screen.getByRole("navigation", { name: "Admin navigation" })).toBeInTheDocument();
});
```

From `TRR-APP/apps/web/tests/admin-global-header.test.tsx`.

**Error Testing:**

Assert on status code and the user-safe error surface, not private stack traces.

```python
response = client.get("/auth/required")
assert response.status_code == 401
```

From `TRR-Backend/tests/api/test_auth.py`.

```python
response = client.get("/metadata/trr/health")
assert response.status_code == 503
assert "TRR_DB_URL" in response.json().get("reason", "")
```

From `screenalytics/tests/api/test_trr_health.py`.

```typescript
expect(getBackendApiBase()).toBe("http://127.0.0.1:8000/api/v1");
```

From `TRR-APP/apps/web/tests/trr-api-backend-base.test.ts`.

## Coverage Gaps

**TRR-Backend CI only covers API tests:**
- `TRR-Backend/.github/workflows/ci.yml` runs `tests/api` only.
- Large suites under `TRR-Backend/tests/repositories/`, `TRR-Backend/tests/scripts/`, `TRR-Backend/tests/socials/`, and `TRR-Backend/tests/vision/` are not part of the default CI lane.
- Risk: repository logic, long-tail script contracts, and social scraping regressions can miss PR-time detection.

**TRR-APP Playwright is not in default CI:**
- `TRR-APP/.github/workflows/web-tests.yml` does not run `pnpm -C apps/web run test:e2e`.
- Risk: navigation, browser-only interactions, focus management, and visual shell regressions rely on local managed-browser verification or manual invocation.

**TRR-APP compatibility lane is intentionally narrow:**
- The Node 22 lane runs only a few smoke files from `TRR-APP/.github/workflows/web-tests.yml`.
- Risk: compatibility issues outside those smoke files are not broadly sampled.

**screenalytics full test inventory is larger than the curated CI list:**
- `screenalytics/tests/api/`, `screenalytics/tests/unit/`, `screenalytics/tests/ml/`, and `screenalytics/FEATURES/*/tests/` contain far more tests than the workflow’s explicit list.
- Risk: regressions in unlisted test files depend on manual or local repo-wide pytest runs.

**ML-heavy paths are opt-in:**
- `screenalytics/tests/api/test_jobs_smoke.py` and the `tests/ml/` suite require `RUN_ML_TESTS=1` or heavier dependencies.
- Risk: pipeline and performance-sensitive behavior is easy to skip during routine local validation.

## Current Rule of Thumb

- When touching `TRR-Backend/api/` or `TRR-Backend/trr_backend/`, add or update a `pytest` file under the matching `TRR-Backend/tests/<domain>/` directory.
- When touching `TRR-APP/apps/web/src/lib/`, `src/app/`, or `src/components/`, add a Vitest file in `TRR-APP/apps/web/tests/`; add Playwright coverage only if the behavior depends on actual browser routing, focus, or network interception.
- When touching `screenalytics/apps/api/` or `packages/py-screenalytics/src/`, add `pytest` coverage under `screenalytics/tests/api/`, `tests/unit/`, or `tests/ml/` based on whether the behavior is API-facing, pure logic, or ML/runtime heavy.

---

*Testing analysis: 2026-04-04*
