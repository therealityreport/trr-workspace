# Testing Patterns

**Analysis Date:** 2026-04-04

## Test Framework

**Runner:**
- `TRR-Backend` uses `pytest` with `pythonpath = .`, `testpaths = tests`, and `python_files = test_*.py` in `TRR-Backend/pytest.ini`.
- `TRR-APP/apps/web` uses `Vitest` for unit/component/route tests in `TRR-APP/apps/web/vitest.config.ts`.
- `TRR-APP/apps/web` uses `Playwright` for browser smoke and admin flows in `TRR-APP/apps/web/playwright.config.ts`.
- `screenalytics` uses `pytest` configured in `screenalytics/pyproject.toml`, including markers for `slow` and `timeout` plus `--import-mode=importlib`.

**Assertion Library:**
- Python tests use plain `assert`, `pytest`, and `fastapi.testclient.TestClient`: `TRR-Backend/tests/api/test_health.py`, `screenalytics/tests/api/test_trr_health.py`.
- App tests use `expect` from Vitest and DOM assertions from `@testing-library/jest-dom/vitest`: `TRR-APP/apps/web/tests/setup.ts`, `TRR-APP/apps/web/tests/admin-global-header.test.tsx`.
- E2E tests use Playwright `expect` and route interception helpers: `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.

**Run Commands:**
```bash
make test-fast                       # Workspace fast lane from `/Users/thomashulihan/Projects/TRR/Makefile`
make test-full                       # Workspace full lane from `/Users/thomashulihan/Projects/TRR/Makefile`
make smoke                           # Workspace runtime smoke checks from `/Users/thomashulihan/Projects/TRR/Makefile`
cd TRR-Backend && pytest             # Backend full suite per `TRR-Backend/AGENTS.md`
pnpm -C TRR-APP/apps/web run test:ci # App CI Vitest lane from `TRR-APP/apps/web/package.json`
pnpm -C TRR-APP/apps/web run test:e2e # App Playwright lane from `TRR-APP/apps/web/package.json`
cd screenalytics && pytest tests/unit/ -v   # Screenalytics unit lane per `screenalytics/AGENTS.md`
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v  # Screenalytics ML lane per `screenalytics/AGENTS.md`
```

## Test File Organization

**Location:**
- `TRR-Backend` keeps tests in a dedicated top-level `tests/` tree grouped by subsystem: `TRR-Backend/tests/api`, `TRR-Backend/tests/repositories`, `TRR-Backend/tests/services`, `TRR-Backend/tests/socials`, `TRR-Backend/tests/vision`.
- `TRR-APP` keeps tests under `TRR-APP/apps/web/tests`, separate from `src`, with `tests/e2e`, `tests/fixtures`, and `tests/mocks`.
- `screenalytics` keeps most tests under `screenalytics/tests` and also has app-local tests under `screenalytics/apps/workspace-ui/tests`.

**Naming:**
- Python tests follow `test_*.py`: `TRR-Backend/tests/test_api_smoke.py`, `screenalytics/tests/api/test_trr_health.py`.
- Vitest files use `*.test.ts` and `*.test.tsx`: `TRR-APP/apps/web/tests/admin-global-header.test.tsx`, `TRR-APP/apps/web/tests/backend-base.test.ts`.
- Playwright files use `*.spec.ts`: `TRR-APP/apps/web/tests/e2e/admin-modal-keyboard.spec.ts`.

**Structure:**
```text
TRR-Backend/tests/
  api/
  repositories/
  services/
  socials/
  vision/

TRR-APP/apps/web/tests/
  *.test.ts[x]
  e2e/*.spec.ts
  fixtures/
  mocks/

screenalytics/tests/
  api/
  unit/
  integration/
  ml/
  ui/
  mcps/
  FEATURES/
```

## Test Structure

**Suite Organization:**
```python
# `TRR-Backend/tests/test_api_smoke.py`
@pytest.fixture
def client(mock_supabase):
    app.dependency_overrides[...] = lambda: mock_supabase
    yield TestClient(app)
    app.dependency_overrides.clear()

class TestHealthEndpoints:
    def test_root_returns_ok(self, client: TestClient):
        response = client.get("/")
        assert response.status_code == 200
```

```tsx
// `TRR-APP/apps/web/tests/admin-global-header.test.tsx`
describe("AdminGlobalHeader", () => {
  beforeEach(() => {
    usePathnameMock.mockReset();
  });

  it("shows expected menu items", async () => {
    render(<AdminGlobalHeader />);
    fireEvent.click(screen.getByRole("button", { name: "Open admin navigation menu" }));
    await waitFor(() => expect(screen.getByRole("navigation")).toBeInTheDocument());
  });
});
```

```python
# `screenalytics/tests/api/test_trr_health.py`
def test_trr_health_returns_connected_when_ping_succeeds(client, monkeypatch):
    monkeypatch.setenv("TRR_DB_URL", "postgresql://test:test@localhost:5432/test")
    with patch("apps.api.routers.metadata.ping", return_value=True):
        response = client.get("/metadata/trr/health")
    assert response.status_code == 200
```

**Patterns:**
- Backend tests often create one focused fixture per file rather than relying on a large shared `conftest.py`: `TRR-Backend/tests/api/test_health.py`, `TRR-Backend/tests/api/test_admin_recent_people.py`.
- App tests are interaction-driven and use Testing Library primitives (`render`, `screen`, `fireEvent`, `waitFor`) from `TRR-APP/apps/web/tests/admin-global-header.test.tsx`.
- Screenalytics tests commonly use `monkeypatch` plus temporary directories and environment variables to simulate pipeline modes without full external services: `screenalytics/tests/api/test_presign_matrix.py`, `screenalytics/tests/api/test_screentime_math.py`.

## Mocking

**Framework:** `unittest.mock` and `pytest.monkeypatch` in Python; `vi.mock`, `vi.stubGlobal`, and Playwright `page.route` in TypeScript.

**Patterns:**
```python
# `TRR-Backend/tests/api/test_health.py`
with patch.object(_real_pg, "db_connection", _fake_db_connection_ok):
    resp = client.get("/health")
```

```ts
// `TRR-APP/apps/web/tests/setup.ts`
vi.mock("next/image", () => ({ default: (...) => React.createElement("img", rest) }));
vi.mock("server-only", () => ({}));
```

```ts
// `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`
await page.route("**/api/admin/**", async (route) => {
  return json(route, { ...mockBody });
});
```

```python
# `screenalytics/tests/conftest.py`
celery_app.conf.update(
    task_always_eager=True,
    task_eager_propagates=True,
    result_backend="cache+memory://",
    broker_url="memory://",
)
```

**What to Mock:**
- Mock network and database boundaries aggressively: Supabase/PG connections in `TRR-Backend/tests/test_api_smoke.py`, metadata DB calls in `screenalytics/tests/api/test_trr_health.py`, admin API responses in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.
- Mock framework-only modules needed for rendering in jsdom: `next/image`, `server-only`, Firebase bindings in `TRR-APP/apps/web/tests/setup.ts`.
- Mock optional heavy ML/runtime dependencies centrally in Screenalytics when the test target is orchestration rather than model quality: lazy NumPy and `cv2` stubs in `screenalytics/tests/conftest.py`.

**What NOT to Mock:**
- Do not mock pure parsing, normalization, or reducer logic when fixture data is cheap to load. Those tests are written against real helper output in `TRR-Backend/tests/ingestion/*`, `TRR-APP/apps/web/tests/person-photo-utils.test.ts`, and `screenalytics/tests/unit/*`.
- Do not bypass the React DOM for user-facing component behavior; `TRR-APP` tests generally render components and interact through accessible roles rather than calling internals directly.

## Fixtures and Factories

**Test Data:**
```python
# `TRR-Backend/tests/ingestion/test_fandom_person_scraper.py`
def _read_fixture(name: str) -> str:
    return (FIXTURES_DIR / name).read_text(encoding="utf-8")
```

```ts
// `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`
export const buildShowCastMember = (personId: string, name: string, overrides = {}) => ({
  id: `credit-${personId}`,
  person_id: personId,
  full_name: name,
  ...overrides,
});
```

```python
# `screenalytics/tests/conftest.py`
os.environ.setdefault("STORAGE_BACKEND", "local")
```

**Location:**
- Backend HTML/JSON fixture inputs live under `TRR-Backend/tests/fixtures/*`.
- App fixture inputs live under `TRR-APP/apps/web/tests/fixtures` and Playwright scenario builders in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.
- Screenalytics shared helpers live in `screenalytics/tests/helpers`, central session fixtures in `screenalytics/tests/conftest.py`, and Streamlit test stubs in `screenalytics/tests/ui/streamlit_stub.py`.

## Coverage

**Requirements:** No cross-repo coverage threshold is enforced in the detected configs.

**View Coverage:**
```bash
pnpm -C TRR-APP/apps/web exec vitest -c vitest.config.ts --coverage
```

- `TRR-APP/apps/web/vitest.config.ts` is configured for V8 coverage output (`text`, `html`, `lcov`), but no dedicated `coverage` script is wired in `TRR-APP/apps/web/package.json`.
- No pytest coverage configuration or threshold is detected in `TRR-Backend` or `screenalytics`.

## Test Types

**Unit Tests:**
- `TRR-Backend` uses unit-style tests for parser, repository, and utility logic with heavy dependency patching: `TRR-Backend/tests/ingestion/*`, `TRR-Backend/tests/repositories/*`, `TRR-Backend/tests/db/*`.
- `TRR-APP` uses Vitest for components, server helpers, route utilities, and runtime boundary checks: `TRR-APP/apps/web/tests/*.test.ts[x]`.
- `screenalytics` has explicit `tests/unit`, plus many logic-focused tests in `tests/api` where the HTTP layer is thin.

**Integration Tests:**
- Backend integration-style suites exist under `TRR-Backend/tests/integrations` and some repository tests with more realistic payloads.
- Screenalytics keeps dedicated `tests/integration` and `tests/FEATURES` suites for pipeline contract and artifact behavior.
- Workspace fast/full scripts do not run these integration suites by default.

**E2E Tests:**
- `TRR-APP` is the only repo with first-class browser E2E coverage, using Playwright in `TRR-APP/apps/web/tests/e2e`.
- `screenalytics` UI testing is compile/state oriented via pytest, not browser automation: `screenalytics/tests/ui/*`, `screenalytics/apps/workspace-ui/tests/*`.
- No browser E2E runner is detected for `screenalytics/web`.

## Smoke Checks

**Workspace Smoke:**
- `make smoke` runs process, health, and port checks for the workspace in `/Users/thomashulihan/Projects/TRR/scripts/smoke.sh`.
- Required checks currently cover `TRR-Backend` `/health` and `TRR-APP` root, with `screenalytics` API treated as optional in the workspace smoke script.

**Repo Smoke:**
- Backend has route-smoke tests such as `TRR-Backend/tests/test_api_smoke.py`, `TRR-Backend/tests/test_discussions_smoke.py`, and `TRR-Backend/tests/test_dms_smoke.py`.
- App has targeted smoke commands and Playwright smoke specs such as `TRR-APP/apps/web/package.json` `smoke:cast:preflight` and `TRR-APP/apps/web/tests/e2e/homepage-visual-smoke.spec.ts`.
- Screenalytics relies on API health tests and compile checks in workspace scripts more than separate shell smoke scripts.

## Common Patterns

**Async Testing:**
```ts
// `TRR-APP/apps/web/tests/admin-global-header.test.tsx`
await waitFor(() => {
  expect(screen.getByRole("navigation", { name: "Admin navigation" })).toBeInTheDocument();
});
```

```ts
// `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`
await page.route("**/api/admin/**", async (route) => {
  await sleep(options.castRoleMembersDelayMs ?? 0);
  return json(route, options.castRoleMembers ?? []);
});
```

**Error Testing:**
```python
# `TRR-Backend/tests/api/test_health.py`
with patch.object(_real_pg, "db_connection", _fake_db_connection_fail):
    resp = client.get("/health")
assert resp.status_code == 503
```

```python
# `screenalytics/tests/api/test_trr_health.py`
with patch("apps.api.routers.metadata.ping", return_value=False):
    response = client.get("/metadata/trr/health")
assert response.json()["trr_db"] == "error"
```

## Notable Gaps

**`screenalytics/web` test runner gap:**
- No Vitest, Jest, or Playwright config is detected under `screenalytics/web`; the Next.js frontend has `package.json` and `tsconfig.json` but no first-class automated JS test suite.

**Workspace coverage gap for Screenalytics:**
- `/Users/thomashulihan/Projects/TRR/scripts/test-fast.sh` and `/Users/thomashulihan/Projects/TRR/scripts/test.sh` only compile key Screenalytics entrypoints and run `screenalytics/tests/api/test_trr_health.py`. They do not exercise the broader `tests/unit`, `tests/integration`, `tests/ml`, or `tests/ui` trees by default.

**App coverage visibility gap:**
- `TRR-APP/apps/web/vitest.config.ts` defines coverage reporters, but `TRR-APP/apps/web/package.json` does not expose a `coverage` script or enforce a threshold.

**Backend shared-fixture gap:**
- `TRR-Backend` has only a local shared conftest at `TRR-Backend/tests/api/routers/conftest.py`; most other setup is duplicated per file. New backend tests should prefer extracting reusable fixtures when a pattern repeats.

---

*Testing analysis: 2026-04-04*
