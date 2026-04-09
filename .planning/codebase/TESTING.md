# Testing Patterns

**Analysis Date:** 2026-04-08

## Test Framework

**Runner:**
- `pytest` for `TRR-Backend` via `TRR-Backend/pytest.ini`.
- `pytest` for `screenalytics` via `[tool.pytest.ini_options]` in `screenalytics/pyproject.toml`.
- `vitest` for `TRR-APP/apps/web` via `TRR-APP/apps/web/vitest.config.ts`.
- `@playwright/test` for TRR-APP browser coverage via `TRR-APP/apps/web/playwright.config.ts`.

**Assertion Library:**
- Python repos use `pytest` assertions and `unittest.mock` or `monkeypatch`.
- TRR-APP uses Vitest assertions with Testing Library and `@testing-library/jest-dom` from `TRR-APP/apps/web/tests/setup.ts`.
- Accessibility assertions use `vitest-axe` in files such as `TRR-APP/apps/web/tests/admin-breadcrumbs-component.test.tsx`.

**Run Commands:**
```bash
make test-fast                                 # Workspace quick gate from `/Users/thomashulihan/Projects/TRR/Makefile`
make test-full                                 # Workspace full gate from `/Users/thomashulihan/Projects/TRR/Makefile`
make test-changed                              # Changed-scope gate from `/Users/thomashulihan/Projects/TRR/Makefile`
cd TRR-Backend && ruff check . && ruff format --check . && pytest -q
cd screenalytics && pytest -q
cd TRR-APP/apps/web && pnpm run lint && pnpm exec next build --webpack && pnpm run test:ci
cd TRR-APP/apps/web && pnpm run test:e2e
```

## Test File Organization

**Location:**
- `TRR-Backend` keeps tests under `TRR-Backend/tests/`, grouped by boundary: `api/`, `db/`, `repositories/`, `middleware/`, `services/`, `integrations/`, `socials/`, `media/`, and others.
- `screenalytics` keeps tests under `screenalytics/tests/`, grouped by surface: `api/`, `audio/`, `config/`, `facebank/`, `integration/`, `ml/`, `tools/`, `ui/`, `unit/`, plus feature-contract suites in `screenalytics/tests/FEATURES/`.
- `TRR-APP` keeps all tests in `TRR-APP/apps/web/tests/` instead of co-locating beside source. It further separates browser specs into `TRR-APP/apps/web/tests/e2e/`, support mocks into `TRR-APP/apps/web/tests/mocks/`, and data fixtures into `TRR-APP/apps/web/tests/fixtures/`.

**Naming:**
- Python: `test_*.py` as enforced by `TRR-Backend/pytest.ini`.
- TypeScript: `*.test.ts` and `*.test.tsx` as enforced by `TRR-APP/apps/web/vitest.config.ts`.
- Playwright: `*.spec.ts` under `TRR-APP/apps/web/tests/e2e/`.

**Structure:**
```text
TRR-Backend/tests/api/routers/test_<feature>.py
screenalytics/tests/api/test_<feature>.py
TRR-APP/apps/web/tests/<feature>.test.ts
TRR-APP/apps/web/tests/<component>.test.tsx
TRR-APP/apps/web/tests/e2e/<flow>.spec.ts
```

## Test Structure

**Suite Organization:**
```typescript
describe("AdminBreadcrumbs component", () => {
  it("renders clickable ancestors and clickable current crumb", () => {
    render(<AdminBreadcrumbs items={[...]} />);
    expect(screen.getByRole("navigation", { name: "Breadcrumb" })).toBeInTheDocument();
  });
});
```
Source pattern: `TRR-APP/apps/web/tests/admin-breadcrumbs-component.test.tsx`.

```python
def test_health_connected():
    with patch.object(_real_pg, "db_connection", _fake_db_connection_ok):
        resp = client.get("/health")
    assert resp.status_code == 200
```
Source pattern: `TRR-Backend/tests/api/test_health.py`.

**Patterns:**
- Keep one suite focused on one route, service, or component. File names mirror the subject under test: `TRR-Backend/tests/api/routers/test_admin_show_links.py`, `screenalytics/tests/api/test_jobs_screentime.py`, `TRR-APP/apps/web/tests/brand-profile-route.test.ts`.
- Use `beforeEach` and `afterEach` to reset mocks in Vitest. Example: `TRR-APP/apps/web/tests/backend-base.test.ts`.
- Use fixtures and `autouse=True` for broad router/test-environment setup in Python. Examples: `TRR-Backend/tests/api/routers/conftest.py`, `screenalytics/tests/conftest.py`.
- Prefer semantic queries in browser and component tests. Examples: `screen.getByRole(...)` in `TRR-APP/apps/web/tests/admin-breadcrumbs-component.test.tsx`, `page.getByRole(...)` in `TRR-APP/apps/web/tests/e2e/admin-modal-keyboard.spec.ts`.

## Mocking

**Framework:** `unittest.mock.patch`, `pytest.monkeypatch`, `MagicMock`, and Vitest `vi.mock`/`vi.fn`.

**Patterns:**
```typescript
vi.mock("@/lib/server/auth", () => ({
  requireAdmin: requireAdminMock,
}));
```
Source pattern: `TRR-APP/apps/web/tests/social-ingest-health-dot-route.test.ts`.

```python
with patch("apps.api.routers.metadata.ping", return_value=True):
    response = client.get("/metadata/trr/health")
```
Source pattern: `screenalytics/tests/api/test_trr_health.py`.

```python
monkeypatch.setattr(admin_ops_repo, "create_or_attach_operation", _create_or_attach_operation)
```
Source pattern: `TRR-Backend/tests/api/routers/conftest.py`.

**What to Mock:**
- Mock network calls, storage, Celery, external ML dependencies, and DB adapters at the boundary.
- In TRR-APP, mock Next.js-only modules and browser gaps globally in `TRR-APP/apps/web/tests/setup.ts` (`next/image`, `server-only`, Firebase helpers, `matchMedia`, `scrollTo`).
- In screenalytics, use `screenalytics/tests/conftest.py` to install lazy `numpy`, `cv2` stubs, and eager Celery configuration before test bodies run.
- In backend router tests, replace persistent operation stores with in-memory fixtures rather than hitting Postgres. See `TRR-Backend/tests/api/routers/conftest.py`.

**What NOT to Mock:**
- Do not mock FastAPI or Next route handlers themselves; exercise them through `TestClient` or direct route function invocation.
- Do not bypass accessibility or DOM behavior in component tests when Testing Library can assert it directly.
- Do not introduce broad end-to-end network dependencies into unit suites; Playwright fixtures in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts` already provide route stubbing for admin flows.

## Fixtures and Factories

**Test Data:**
```typescript
export const SHOW_ID = "11111111-1111-4111-8111-111111111111";

export const buildShowCastMember = (personId: string, name: string, overrides = {}) => ({
  id: `credit-${personId}`,
  person_id: personId,
  full_name: name,
  ...overrides,
});
```
Source pattern: `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.

```python
@pytest.fixture(autouse=True)
def _clear_social_router_caches() -> None:
    socials_router._clear_account_profile_caches()
```
Source pattern: `TRR-Backend/tests/api/routers/conftest.py`.

**Location:**
- Backend HTML and JSON fixtures live in `TRR-Backend/tests/fixtures/`.
- App fixtures and mocks live in `TRR-APP/apps/web/tests/fixtures/` and `TRR-APP/apps/web/tests/mocks/`.
- Screenalytics shared helper stubs live in `screenalytics/tests/helpers/`.

## Coverage

**Requirements:** No workspace-wide coverage threshold is enforced in the current configs.

**View Coverage:**
```bash
cd TRR-APP/apps/web && pnpm exec vitest run -c vitest.config.ts --coverage
```
- Vitest coverage output is configured in `TRR-APP/apps/web/vitest.config.ts` with `text`, `html`, and `lcov` reporters under `coverage/`.
- Python repos rely on targeted and full `pytest` runs rather than a declared coverage gate.

## Test Types

**Unit Tests:**
- Backend unit tests often target pure helpers or repository logic with `monkeypatch` and direct function calls. Examples: `TRR-Backend/tests/db/test_connection_resolution.py`, `TRR-Backend/tests/repositories/test_pgrst204_retry.py`.
- Screenalytics unit-style tests validate schema normalization and pipeline utilities in isolation. Examples: `screenalytics/tests/config/test_tracking_defaults.py`, `screenalytics/tests/ml/test_cluster_confidence.py`.
- TRR-APP unit tests cover route helpers, repositories, and React components through Vitest. Examples: `TRR-APP/apps/web/tests/backend-base.test.ts`, `TRR-APP/apps/web/tests/brand-profile-repository.test.ts`, `TRR-APP/apps/web/tests/admin-breadcrumbs-component.test.tsx`.

**Integration Tests:**
- Backend integration-style coverage lives in `TRR-Backend/tests/integrations/` and in route tests that use `FastAPI` endpoints with realistic payloads.
- Screenalytics integration coverage lives in `screenalytics/tests/integration/` plus many `tests/api/` files that hit the assembled FastAPI app.
- Workspace targeted integration gates are scripted in `scripts/cast-screentime-gap-check.sh`, `scripts/test-fast.sh`, and `scripts/test.sh`.

**E2E Tests:**
- Browser E2E is only present in TRR-APP with Playwright under `TRR-APP/apps/web/tests/e2e/`.
- `TRR-APP/apps/web/playwright.config.ts` runs one Chromium worker, captures traces/screenshots/videos on failure, and starts a dedicated webpack dev server unless `E2E_CAST_LIVE=1` is set.
- Representative flow: `TRR-APP/apps/web/tests/e2e/admin-modal-keyboard.spec.ts`.

## Common Patterns

**Async Testing:**
```typescript
it("has no basic axe violations", async () => {
  const { container } = render(<AdminBreadcrumbs items={[...]} />);
  const results = await axe(container);
  expect(results.violations).toHaveLength(0);
});
```
Source pattern: `TRR-APP/apps/web/tests/admin-breadcrumbs-component.test.tsx`.

```python
def test_trr_health_returns_connected_when_ping_succeeds(client, monkeypatch):
    with patch("apps.api.routers.metadata.ping", return_value=True):
        response = client.get("/metadata/trr/health")
```
Source pattern: `screenalytics/tests/api/test_trr_health.py`.

**Error Testing:**
```python
resp = client.get("/episodes", params={"limit": -1})
assert resp.status_code == 422
assert resp.json()["code"] == "VALIDATION_ERROR"
```
Source pattern: `screenalytics/tests/api/test_error_envelope_and_events.py`.

```typescript
fetchSocialBackendJsonMock.mockRejectedValueOnce(new Error("fetch failed"));
const response = await GET(request);
expect(response.status).toBe(502);
```
Source pattern: `TRR-APP/apps/web/tests/social-ingest-health-dot-route.test.ts`.

## Verification Commands

- Canonical workspace checks are documented in `docs/cross-collab/WORKFLOW.md` and `AGENTS.md`.
- `scripts/test-fast.sh` is the quickest shared gate:
  - `TRR-Backend`: Ruff plus health-focused `pytest`.
  - `TRR-APP`: `pnpm run lint`.
  - `screenalytics`: `py_compile` plus `tests/api/test_trr_health.py`.
- `scripts/test.sh` is the broader shared gate:
  - `TRR-Backend`: full `pytest`.
  - `TRR-APP`: lint, webpack build, and `test:ci`.
  - `screenalytics`: targeted API health regression.
- `scripts/test-changed.sh` scopes the gate to touched repos and falls back to workspace policy checks for root-only changes.
- `scripts/smoke.sh` is the runtime smoke gate after `make dev`, verifying health endpoints and port listeners across the workspace.

---

*Testing analysis: 2026-04-08*
