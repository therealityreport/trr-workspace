# Testing Patterns

**Analysis Date:** 2026-04-02

## Test Framework

**Runner:**
- `TRR-APP/apps/web`: Vitest `^2.1.9` with config in `TRR-APP/apps/web/vitest.config.ts`.
- `TRR-APP/apps/web`: Playwright `^1.58.2` for browser coverage with config in `TRR-APP/apps/web/playwright.config.ts`.
- `TRR-Backend`: pytest with config in `TRR-Backend/pytest.ini`.
- `screenalytics`: pytest configured in `screenalytics/pyproject.toml`.

**Assertion Library:**
- `TRR-APP/apps/web`: Vitest `expect`, `@testing-library/react`, `@testing-library/jest-dom`, and `vitest-axe`, as shown in `TRR-APP/apps/web/tests/setup.ts` and `TRR-APP/apps/web/tests/admin-modal.test.tsx`.
- `TRR-Backend`: plain pytest assertions with `fastapi.testclient.TestClient`, as shown in `TRR-Backend/tests/api/test_auth.py` and `TRR-Backend/tests/middleware/test_request_timeout.py`.
- `screenalytics`: plain pytest assertions plus `fastapi.testclient.TestClient`, as shown in `screenalytics/tests/api/test_error_envelope_and_events.py` and `screenalytics/tests/api/test_presign_matrix.py`.

**Run Commands:**
```bash
cd TRR-APP/apps/web && pnpm run test                  # Vitest unit/integration suite
cd TRR-APP/apps/web && pnpm run test:ci              # CI Vitest lane
cd TRR-APP/apps/web && pnpm run test:e2e             # Playwright browser tests
cd TRR-Backend && pytest -q                          # Full backend test suite
cd TRR-Backend && pytest tests/api -q                # CI subset from `.github/workflows/ci.yml`
cd screenalytics && pytest tests/unit/ -v            # Repo-local fast validation from `screenalytics/AGENTS.md`
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v
cd screenalytics && python -m py_compile <touched_files>
```

## Test File Organization

**Location:**
- `TRR-APP/apps/web` keeps tests in a separate `tests/` tree, with browser tests in `TRR-APP/apps/web/tests/e2e/`.
- `TRR-Backend` keeps tests in `TRR-Backend/tests/` and mirrors domains such as `tests/api/`, `tests/db/`, `tests/media/`, `tests/repositories/`, and `tests/socials/`.
- `screenalytics` uses a broad matrix: `screenalytics/tests/api/`, `screenalytics/tests/unit/`, `screenalytics/tests/ui/`, `screenalytics/tests/integration/`, `screenalytics/tests/ml/`, `screenalytics/tests/audio/`, `screenalytics/tests/tools/`, and feature-specific suites under `screenalytics/tests/FEATURES/`.

**Naming:**
- Use `*.test.ts` and `*.test.tsx` for Vitest suites, for example `TRR-APP/apps/web/tests/admin-auth-status-route.test.ts`.
- Use `*.spec.ts` for Playwright specs, for example `TRR-APP/apps/web/tests/e2e/admin-modal-keyboard.spec.ts`.
- Use `test_*.py` for pytest modules, for example `TRR-Backend/tests/api/routers/test_admin_asset_batch_jobs.py` and `screenalytics/tests/api/test_presign_matrix.py`.

**Structure:**
```text
TRR-APP/apps/web/tests/
TRR-APP/apps/web/tests/e2e/
TRR-Backend/tests/api/
TRR-Backend/tests/api/routers/
TRR-Backend/tests/db/
screenalytics/tests/api/
screenalytics/tests/unit/
screenalytics/tests/ui/
screenalytics/tests/ml/
screenalytics/tests/integration/
screenalytics/tests/FEATURES/
```

## Test Structure

**Suite Organization:**
```typescript
const { requireAdminMock } = vi.hoisted(() => ({
  requireAdminMock: vi.fn(),
}));

vi.mock("@/lib/server/auth", () => ({
  requireAdmin: requireAdminMock,
}));

describe("/api/admin/auth/status route", () => {
  beforeEach(() => {
    requireAdminMock.mockReset();
  });

  it("returns 401 when request is unauthorized", async () => {
    requireAdminMock.mockRejectedValue(new Error("unauthorized"));
  });
});
```
- Pattern from `TRR-APP/apps/web/tests/admin-auth-status-route.test.ts`.

```python
def test_require_user_valid_token_returns_user(monkeypatch):
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret-32-bytes-minimum-abcdef")
    client = TestClient(_build_app())

    response = client.get("/auth/required", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
```
- Pattern from `TRR-Backend/tests/api/test_auth.py`.

```python
def test_presign_matrix_s3(monkeypatch, tmp_path):
    monkeypatch.setenv("STORAGE_BACKEND", "s3")
    monkeypatch.setattr(episodes_router, "STORAGE", _FakeS3Storage())
    client = TestClient(app)
```
- Pattern from `screenalytics/tests/api/test_presign_matrix.py`.

**Patterns:**
- Reset mocks in `beforeEach` for Vitest route and component tests, as in `TRR-APP/apps/web/tests/admin-auth-status-route.test.ts`.
- Build minimal inline FastAPI apps when testing framework behavior in isolation, as in `TRR-Backend/tests/middleware/test_request_timeout.py`.
- Use `tmp_path`, `monkeypatch`, and in-memory fakes to avoid external storage or ML dependencies in Python tests, as in `screenalytics/tests/api/test_presign_matrix.py` and `screenalytics/tests/unit/test_body_tracking_runner_video_path.py`.

## Mocking

**Framework:** 
- `TRR-APP/apps/web`: `vi.mock`, `vi.fn`, `vi.stubGlobal`, and hoisted mocks.
- `TRR-Backend`: `pytest.monkeypatch`, `unittest.mock.patch`, `MagicMock`, and `app.dependency_overrides`.
- `screenalytics`: `pytest.monkeypatch`, `MagicMock`, module stubs in `sys.modules`, and repo-wide bootstrap fixtures.

**Patterns:**
```typescript
vi.mock("next/image", () => ({
  __esModule: true,
  default: (props) => React.createElement("img", rest),
}));

vi.mock("server-only", () => ({}));
```
- Pattern from `TRR-APP/apps/web/tests/setup.ts`.

```python
app.dependency_overrides[require_admin] = lambda: {
    "id": "service_role:test",
    "role": "service_role",
    "email": None,
}
yield
app.dependency_overrides.pop(require_admin, None)
```
- Pattern from `TRR-Backend/tests/api/routers/test_admin_asset_batch_jobs.py`.

```python
@pytest.fixture(scope="session", autouse=True)
def configure_celery_eager():
    celery_app.conf.update(
        task_always_eager=True,
        task_eager_propagates=True,
        result_backend="cache+memory://",
        broker_url="memory://",
    )
```
- Pattern from `screenalytics/tests/conftest.py`.

**What to Mock:**
- Mock network, storage, auth, and third-party boundaries. Examples: `fetch` and `next/image` in `TRR-APP/apps/web/tests/setup.ts`, Supabase admin clients in `TRR-Backend/tests/api/routers/test_admin_asset_batch_jobs.py`, and storage backends in `screenalytics/tests/api/test_presign_matrix.py`.
- Mock optional heavy dependencies in `screenalytics`, including Celery, `numpy`, `cv2`, and Streamlit, using the guards in `screenalytics/tests/conftest.py` and `screenalytics/tests/ui/test_people_cluster_strips.py`.
- Mock env vars explicitly with `monkeypatch.setenv` or `process.env`-based helpers rather than relying on a shared shell state.

**What NOT to Mock:**
- Do not mock pure normalization and parser helpers when the function itself is the unit under test. Examples include `TRR-APP/apps/web/tests/validation.test.ts`, `TRR-Backend/tests/db/test_connection_resolution.py`, and `screenalytics/tests/unit/test_autorun_timing.py`.
- Do not bypass the standardized error envelope in `screenalytics`; instantiate `TestClient(app)` and assert the real payload shape, as in `screenalytics/tests/api/test_error_envelope_and_events.py`.

## Fixtures and Factories

**Test Data:**
```typescript
export const buildShowCastMember = (
  personId: string,
  name: string,
  overrides: Partial<Record<string, unknown>> = {}
) => ({
  id: `credit-${personId}`,
  person_id: personId,
  full_name: name,
  ...overrides,
});
```
- Pattern from `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.

```python
@pytest.fixture(autouse=True)
def _in_memory_admin_operation_store(monkeypatch: pytest.MonkeyPatch) -> None:
    operations: dict[str, dict[str, Any]] = {}
```
- Pattern from `TRR-Backend/tests/api/routers/conftest.py`.

```python
if importlib.util.find_spec("cv2") is None:
    cv2_stub = types.ModuleType("cv2")
    sys.modules["cv2"] = cv2_stub
```
- Pattern from `screenalytics/tests/conftest.py`.

**Location:**
- `TRR-APP/apps/web/tests/setup.ts` contains shared Vitest environment setup.
- `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts` contains reusable Playwright route fixtures and builders.
- `TRR-Backend/tests/api/routers/conftest.py` contains router-wide autouse fixtures.
- `TRR-Backend/tests/fixtures/` contains captured HTML, JSON, and SQL fixture files.
- `screenalytics/tests/conftest.py` contains global dependency guards and Celery configuration.
- `screenalytics/tests/helpers/` contains reusable test-only loaders and stubs such as `screenalytics/tests/helpers/workspace_ui_source.py`.

## Coverage

**Requirements:** None enforced by threshold configuration. `TRR-APP/apps/web/vitest.config.ts` produces coverage reports, but no branch/function/line thresholds are defined. `TRR-Backend/pytest.ini` and `screenalytics/pyproject.toml` do not configure `pytest-cov`.

**View Coverage:**
```bash
cd TRR-APP/apps/web && pnpm run test:ci -- --coverage
```

## Test Types

**Unit Tests:**
- `TRR-APP/apps/web/tests/*.test.ts[x]` covers route handlers, components, and pure helpers with Vitest and RTL.
- `TRR-Backend/tests/` contains many pure-unit and service-level tests, including `tests/db/`, `tests/media/`, `tests/repositories/`, and `tests/socials/`.
- `screenalytics/tests/unit/` covers utility logic, config resolution, and pipeline helper behavior. `screenalytics/tests/unit/test_autorun_timing.py` is representative.

**Integration Tests:**
- `TRR-APP/apps/web` uses unit-style integration tests against route handlers plus browser specs in `tests/e2e/`.
- `TRR-Backend/tests/api/` and `TRR-Backend/tests/api/routers/` exercise live FastAPI routes with `TestClient`.
- `screenalytics/tests/integration/` covers pipeline and contract wiring, while `screenalytics/tests/api/` exercises the FastAPI app and real error handlers.

**E2E Tests:**
- `TRR-APP/apps/web` uses Playwright in `TRR-APP/apps/web/tests/e2e/`.
- `TRR-Backend`: Not used.
- `screenalytics`: No browser E2E framework detected; validation is done through pytest plus `py_compile` for Streamlit surfaces.

## Common Patterns

**Async Testing:**
```typescript
it("has no basic axe violations", async () => {
  const { container } = render(<AdminModal isOpen={true} onClose={onClose} ariaLabel="Accessible dialog" />);
  const results = await axe(container);
  expect(results.violations).toHaveLength(0);
});
```
- Pattern from `TRR-APP/apps/web/tests/admin-modal.test.tsx`.

```python
@app.get("/slow")
async def slow_endpoint():
    await asyncio.sleep(10)
```
- Pattern from `TRR-Backend/tests/middleware/test_request_timeout.py`.

**Error Testing:**
```python
resp = client.get("/episodes", params={"limit": -1})
assert resp.status_code == 422
payload = resp.json()
assert payload["code"] == "VALIDATION_ERROR"
```
- Pattern from `screenalytics/tests/api/test_error_envelope_and_events.py`.

## CI and Validation Conventions

**`TRR-APP`:**
- `TRR-APP/.github/workflows/web-tests.yml` runs lint on both Node 24 and Node 22, runs `typecheck:fandom` on the full lane, executes `pnpm run test:ci -- --coverage` only on Node 24, and builds with placeholder Firebase env values.
- PR CI does not run Playwright specs from `TRR-APP/apps/web/tests/e2e/`.

**`TRR-Backend`:**
- `TRR-Backend/.github/workflows/ci.yml` validates `.env.example`, checks lock freshness, imports `api.main`, and runs only `pytest tests/api -q`.
- Repo-local validation in `TRR-Backend/AGENTS.md` is stricter than CI because it also requires `ruff check .`, `ruff format --check .`, and full `pytest`.

**`screenalytics`:**
- `screenalytics/.github/workflows/ci.yml` validates env examples, lockfiles, Ruff policy helper scripts, compile gates, selected feature suites, and a curated core test subset.
- The repo-local contract in `screenalytics/AGENTS.md` adds `python -m py_compile <touched_files>` and optional `RUN_ML_TESTS=1 pytest tests/ml/ -v`.

## Notable Coverage Gaps

**`TRR-APP/apps/web`:**
- `TRR-APP/.github/workflows/web-tests.yml` does not run `TRR-APP/apps/web/tests/e2e/*.spec.ts`, so browser regressions depend on manual or targeted local execution.
- Coverage is generated, but no minimum thresholds are enforced in `TRR-APP/apps/web/vitest.config.ts`.

**`TRR-Backend`:**
- CI only runs `tests/api`, so suites under `TRR-Backend/tests/db/`, `TRR-Backend/tests/media/`, `TRR-Backend/tests/repositories/`, `TRR-Backend/tests/socials/`, `TRR-Backend/tests/middleware/`, and other non-API directories are not part of the GitHub Actions gate.
- CI does not run `ruff check .` or `ruff format --check .` even though `TRR-Backend/AGENTS.md` requires them locally.

**`screenalytics`:**
- The checked-in pytest inventory is much larger than the CI subset. Many suites in `screenalytics/tests/ui/`, `screenalytics/tests/audio/`, `screenalytics/tests/integration/`, and `screenalytics/tests/ml/` are not part of the default GitHub Actions path.
- `screenalytics/.github/workflows/ci.yml` runs a narrow Ruff rule set (`E9,F63,F7,F82`) instead of the broader local Ruff config from `screenalytics/pyproject.toml`.
- ML-sensitive tests are frequently gated behind `RUN_ML_TESTS=1` or `-m "not slow"`, so heavy-path regressions need explicit targeted runs.

---

*Testing analysis: 2026-04-02*
