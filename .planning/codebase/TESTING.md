# Testing Patterns

**Analysis Date:** 2026-04-07

## Test Framework

**Runner:**
- `TRR-Backend`: `pytest` configured in `TRR-Backend/pytest.ini`.
- `TRR-APP`: `vitest` `^2.1.9` configured in `TRR-APP/apps/web/vitest.config.ts`.
- `TRR-APP` browser tests: `@playwright/test` `^1.58.2` configured in `TRR-APP/apps/web/playwright.config.ts`.
- `screenalytics`: `pytest` configured via `tool.pytest.ini_options` in `screenalytics/pyproject.toml`.

**Assertion Library:**
- Python repos use bare `assert` plus `pytest.raises`, `monkeypatch`, and `unittest.mock`.
- `TRR-APP` uses Vitest assertions, `@testing-library/react`, `@testing-library/jest-dom`, and `vitest-axe`.
- Playwright tests use `expect` from `@playwright/test`.

**Run Commands:**
```bash
cd TRR-Backend && pytest -q
cd TRR-APP/apps/web && pnpm run test:ci
cd TRR-APP/apps/web && pnpm run test:e2e
cd screenalytics && pytest tests/unit/ -v
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v
```

## Test File Organization

**Location:**
- `TRR-Backend` keeps tests in a dedicated top-level `TRR-Backend/tests/` tree split by subsystem: `tests/api/`, `tests/repositories/`, `tests/scripts/`, `tests/socials/`, `tests/media/`, and more.
- `TRR-APP` keeps Vitest suites in `TRR-APP/apps/web/tests/` and Playwright specs in `TRR-APP/apps/web/tests/e2e/`.
- `screenalytics` keeps tests in a broad `screenalytics/tests/` tree split by test type and domain: `tests/unit/`, `tests/api/`, `tests/ui/`, `tests/ml/`, `tests/integration/`, `tests/mcps/`, `tests/audio/`, and `tests/tools/`.

**Naming:**
- Use `test_*.py` in Python repos, for example `TRR-Backend/tests/api/test_health.py` and `screenalytics/tests/api/test_episode_status.py`.
- Use `*.test.ts` and `*.test.tsx` for Vitest in `TRR-APP/apps/web/tests/`.
- Use `*.spec.ts` for Playwright in `TRR-APP/apps/web/tests/e2e/`, for example `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts`.

**Structure:**
```text
TRR-Backend/tests/
  api/
  repositories/
  scripts/
  fixtures/

TRR-APP/apps/web/tests/
  *.test.ts
  *.test.tsx
  e2e/*.spec.ts
  setup.ts

screenalytics/tests/
  api/
  unit/
  ui/
  ml/
  integration/
  helpers/
```

## Test Structure

**Suite Organization:**
```typescript
// TRR-APP/apps/web/tests/admin-operations-health-route.test.ts
const { requireAdminMock, getBackendApiUrlMock } = vi.hoisted(() => ({
  requireAdminMock: vi.fn(),
  getBackendApiUrlMock: vi.fn(),
}));

vi.mock("@/lib/server/auth", () => ({ requireAdmin: requireAdminMock }));

describe("admin operations health route", () => {
  beforeEach(() => {
    requireAdminMock.mockReset();
    vi.restoreAllMocks();
  });

  it("forwards query params with internal admin auth", async () => {
    const response = await GET(new NextRequest("http://localhost/..."));
    expect(response.status).toBe(200);
  });
});
```

**Patterns:**
- Use explicit setup inside each test file rather than large hidden fixture stacks in `TRR-Backend`. Representative files: `TRR-Backend/tests/api/test_health.py`, `TRR-Backend/tests/repositories/test_admin_show_reads_repository.py`.
- Use `beforeEach` plus hoisted Vitest mocks in `TRR-APP` route/component tests. Representative files: `TRR-APP/apps/web/tests/admin-operations-health-route.test.ts`, `TRR-APP/apps/web/tests/admin-modal.test.tsx`.
- Use `tmp_path`, `monkeypatch`, and small helper writers in `screenalytics` to create realistic file-system state. Representative files: `screenalytics/tests/api/test_episode_status.py`, `screenalytics/tests/unit/test_startup_config.py`.
- Use compile-only tests as guards for UI syntax and import regressions in `screenalytics/apps/workspace-ui/`. Representative files: `screenalytics/tests/ui/test_streamlit_syntax.py`, `screenalytics/tests/ui/test_streamlit_pages_compile.py`.

## Mocking

**Framework:** `pytest.monkeypatch`, `unittest.mock`, `vitest vi.mock`, Playwright `page.route`

**Patterns:**
```python
# TRR-Backend/tests/api/test_health.py
with patch.object(_real_pg, "db_connection", _fake_db_connection_fail):
    resp = client.get("/health")
assert resp.status_code == 503
```

```typescript
// TRR-APP/apps/web/tests/setup.ts
vi.mock("next/image", () => ({
  __esModule: true,
  default: (props) => React.createElement("img", props),
}));

vi.stubGlobal("fetch", fetchMock);
```

```python
# screenalytics/tests/api/test_celery_jobs_local.py
install_celery_stubs(monkeypatch, force=True)
with patch("apps.api.routers.celery_jobs.subprocess.Popen", side_effect=_fake_popen):
    response = api_client.post("/celery_jobs/detect_track", json={...})
```

**What to Mock:**
- Mock network calls, auth guards, subprocesses, DB connectors, and service wrappers at the boundary.
- Stub optional heavy dependencies in `screenalytics` instead of importing real ML stacks for fast suites. Central examples: `screenalytics/tests/conftest.py`, `screenalytics/tests/helpers/celery_stubs.py`, `screenalytics/tests/helpers/subprocess_fakes.py`.
- Mock browser API gaps in `TRR-APP/apps/web/tests/setup.ts`, including `next/image`, `server-only`, Firebase wrappers, and `window.matchMedia`.
- Use Playwright route interception in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts` to simulate backend JSON and SSE without depending on a live backend.

**What NOT to Mock:**
- Do not mock the response envelope you are verifying; construct real `Response`, `NextRequest`, and `TestClient` flows where possible.
- Do not skip file-system state for screenalytics pipeline tests; many tests intentionally write manifests and markers under `tmp_path`.
- Do not replace accessibility assertions with snapshots in UI component tests; `TRR-APP/apps/web/tests/admin-modal.test.tsx` explicitly runs `axe`.

## Fixtures and Factories

**Test Data:**
```python
# TRR-Backend/tests/repositories/test_admin_show_reads_repository.py
monkeypatch.setattr(repo.pg, "fetch_all", lambda query, params=None: [{...}])
rows, query_count = repo.search_shows("Bravo", limit=20, offset=0)
assert rows == [{...}]
```

```typescript
// TRR-APP/apps/web/tests/e2e/admin-fixtures.ts
export const buildShowCastMember = (personId: string, name: string, overrides = {}) => ({
  id: `credit-${personId}`,
  person_id: personId,
  full_name: name,
  ...overrides,
});
```

```python
# screenalytics/tests/api/test_episode_status.py
write_sample_tracks(ep_id, sample_count=6)
write_sample_faces(ep_id, face_count=6)
```

**Location:**
- Static backend fixture payloads live under `TRR-Backend/tests/fixtures/`, especially `tests/fixtures/fandom/`, `tests/fixtures/imdb/`, and `tests/fixtures/tmdb/`.
- Shared Vitest bootstrap lives in `TRR-APP/apps/web/tests/setup.ts`.
- Shared Playwright builders and API interceptors live in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.
- Shared screenalytics helpers live in `screenalytics/tests/helpers/` and `screenalytics/tests/api/_sse_utils.py`.
- Global screenalytics test environment setup lives in `screenalytics/tests/conftest.py`.

## Coverage

**Requirements:** No repo-wide minimum coverage threshold is enforced across the workspace.
- `TRR-APP` emits coverage reports through Vitest but does not define a fail threshold in `TRR-APP/apps/web/vitest.config.ts`.
- `screenalytics/requirements-ci.txt` installs `pytest-cov`, but `screenalytics/.github/workflows/ci.yml` does not run `pytest --cov`.
- `TRR-Backend/.github/workflows/ci.yml` runs a smoke subset and does not collect coverage artifacts.

**View Coverage:**
```bash
cd TRR-APP/apps/web && pnpm run test:ci -- --coverage
open TRR-APP/apps/web/coverage/index.html
```

## CI Validation

- `TRR-Backend/.github/workflows/ci.yml` is intentionally narrow: env-contract validation, lockfile freshness, import gate, and `python -m pytest tests/api -q`. Do not assume repository, script, or integration suites run in CI unless you add them there.
- `TRR-APP/.github/workflows/web-tests.yml` is the strongest automated frontend lane. It runs lint, a targeted `tsc` lane, Vitest with `--coverage` on Node 24, compatibility smoke tests on Node 22, then `next build --webpack`, and uploads the `apps/web/coverage` artifact.
- `screenalytics/.github/workflows/ci.yml` splits validation into lint-and-typecheck, targeted unit/API/ML subsets, smoke dry-run, and a Python 3.12 canary. The workflow validates lockfile freshness and env contracts before tests.
- All three repos include repo-map workflows (`TRR-Backend/.github/workflows/repo_map.yml`, `TRR-APP/.github/workflows/repo_map.yml`, `screenalytics/.github/workflows/repo_map.yml`), but those are documentation automation, not behavioral test suites.

## Test Types

**Unit Tests:**
- `TRR-Backend` unit-style tests dominate repository, service, and utility logic under `TRR-Backend/tests/repositories/`, `TRR-Backend/tests/utils/`, and `TRR-Backend/tests/services/`.
- `TRR-APP` unit/component tests cover route handlers, utilities, and React components in `TRR-APP/apps/web/tests/`.
- `screenalytics` uses `screenalytics/tests/unit/` for pure logic and contract-level checks, often with `tmp_path` and `monkeypatch`.

**Integration Tests:**
- `TRR-Backend` uses domain-specific API and repository tests that exercise FastAPI handlers with `TestClient`.
- `screenalytics` has an explicit `screenalytics/tests/integration/` tree for end-to-end pipeline slices and artifact wiring.
- `TRR-APP` route tests often behave like service-integration tests because they instantiate `NextRequest` and exercise real route code rather than isolated helper functions.

**E2E Tests:**
- Playwright is used only in `TRR-APP`, under `TRR-APP/apps/web/tests/e2e/`.
- No browser E2E framework is detected in `TRR-Backend` or `screenalytics`.

## Common Patterns

**Async Testing:**
```typescript
// TRR-APP/apps/web/tests/admin-operations-health-route.test.ts
const response = await GET(new NextRequest("http://localhost/api/..."));
const payload = await response.json();
expect(response.status).toBe(200);
```

```typescript
// TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts
await page.goto(`/admin/trr-shows/${SHOW_ID}/seasons/${SEASON_NUMBER}?tab=cast`);
await waitForAdminReady(page);
await expect(page.getByRole("button", { name: "Refresh Person" }).first()).toBeVisible();
```

```python
# screenalytics/tests/api/test_episode_status.py
status_resp = client.get(f"/episodes/{ep_id}/status")
assert status_resp.status_code == 200
```

**Error Testing:**
```python
# screenalytics/tests/unit/test_startup_config.py
with pytest.raises(RuntimeError, match="Rejected connection lane 'transaction'"):
    api_main._validate_startup_config()
```

```python
# TRR-Backend/tests/api/test_health.py
with patch.object(_real_pg, "db_connection", _fake_db_connection_fail):
    resp = client.get("/health")
assert resp.status_code == 503
```

## Practical Guidance

- Add backend tests next to the relevant subsystem folder in `TRR-Backend/tests/`; if parsing external HTML or JSON, prefer a checked-in fixture under `TRR-Backend/tests/fixtures/`.
- Add app tests to `TRR-APP/apps/web/tests/` unless the behavior is browser-only, in which case add a Playwright spec under `TRR-APP/apps/web/tests/e2e/`.
- Add screenalytics tests by test type first, then by domain. Pure logic belongs in `screenalytics/tests/unit/`; pipeline, artifact, and API wiring belong in `screenalytics/tests/api/`, `tests/integration/`, or `tests/ml/`.
- When a test needs heavy dependencies in `screenalytics`, first check whether the same behavior can be covered with the existing stubs in `screenalytics/tests/conftest.py` or `screenalytics/tests/helpers/` before adding another custom harness.

---

*Testing analysis: 2026-04-07*
