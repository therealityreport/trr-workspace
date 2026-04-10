# Testing Patterns

**Analysis Date:** 2026-04-09

## Test Framework

**Runner:**
- `TRR-Backend`: `pytest` driven by `TRR-Backend/pytest.ini`.
- `screenalytics`: `pytest` configured in `screenalytics/pyproject.toml`.
- `TRR-APP/apps/web`: `vitest` for unit/runtime tests in `TRR-APP/apps/web/vitest.config.ts` and `playwright` for browser tests in `TRR-APP/apps/web/playwright.config.ts`.
- `screenalytics/web`: Not detected. `screenalytics/web/package.json` has build and lint scripts, but no dedicated test runner config was found.

**Assertion Library:**
- Python repos use plain `assert` with `pytest`, plus `fastapi.testclient.TestClient` for HTTP assertions.
- `TRR-APP/apps/web` uses Vitest `expect`, `@testing-library/react`, and `@testing-library/jest-dom/vitest`.
- `TRR-APP/apps/web/tests/e2e/` uses Playwright assertions from `@playwright/test`.

**Run Commands:**
```bash
make test-fast                                  # Workspace fast lane (`scripts/test-fast.sh`)
make test-full                                  # Workspace full lane (`scripts/test.sh`)
make test-changed                               # Changed-repo selective lane

cd TRR-Backend && ruff check . && ruff format --check . && pytest -q
cd TRR-Backend && make schema-docs-check        # When migrations or schema docs change

cd screenalytics && python -m py_compile <touched_files>
cd screenalytics && pytest tests/unit/ -v
cd screenalytics && RUN_ML_TESTS=1 pytest tests/ml/ -v

cd TRR-APP/apps/web && pnpm run lint
cd TRR-APP/apps/web && pnpm exec next build --webpack
cd TRR-APP/apps/web && pnpm run test:ci
cd TRR-APP/apps/web && pnpm run test:e2e
```

## Test File Organization

**Location:**
- `TRR-Backend` keeps tests in a separate top-level `TRR-Backend/tests/` tree grouped by domain: `api/`, `services/`, `repositories/`, `pipeline/`, `socials/`, `media/`, `migrations/`, `security/`, and more.
- `screenalytics` keeps tests in a separate top-level `screenalytics/tests/` tree grouped by scope: `api/`, `unit/`, `integration/`, `ml/`, `ui/`, `tools/`, `audio/`, `mcps/`, `FEATURES/`, and `facebank/`.
- `TRR-APP/apps/web` keeps tests in `TRR-APP/apps/web/tests/` with subfolders `e2e/`, `fixtures/`, `mocks/`, and `surveys/`.

**Naming:**
- Python: `test_*.py`, configured explicitly in `TRR-Backend/pytest.ini`.
- Vitest: `*.test.ts` and `*.test.tsx`, configured explicitly in `TRR-APP/apps/web/vitest.config.ts`.
- Playwright: `*.spec.ts` under `TRR-APP/apps/web/tests/e2e/`.
- Runtime DOM tests in the app often use `.runtime.test.tsx` for UI-heavy rendering behavior. Examples: `TRR-APP/apps/web/tests/show-brand-logos-section.runtime.test.tsx`, `TRR-APP/apps/web/tests/people-home-page.runtime.test.tsx`.

**Structure:**
```text
TRR-Backend/tests/
screenalytics/tests/
TRR-APP/apps/web/tests/
```

## Test Structure

**Suite Organization:**
```python
# TRR-Backend/tests/api/test_health.py
def test_health_connected():
    with patch.object(_real_pg, "db_connection", _fake_db_connection_ok):
        resp = client.get("/health")
    assert resp.status_code == 200
```

```ts
// TRR-APP/apps/web/tests/social-ingest-health-dot-route.test.ts
const { requireAdminMock } = vi.hoisted(() => ({ requireAdminMock: vi.fn() }));
vi.mock("@/lib/server/auth", () => ({ requireAdmin: requireAdminMock }));

describe("social ingest health-dot proxy route", () => {
  it("uses retry-tuned backend proxy options", async () => {
    const response = await GET(request);
    expect(response.status).toBe(200);
  });
});
```

**Patterns:**
- Keep tests close to a single behavior and use descriptive names that read as a regression statement. Examples: `TRR-Backend/tests/services/test_retained_cast_screentime_dispatch.py`, `screenalytics/tests/api/test_error_envelope_and_events.py`, `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`.
- Favor direct function tests for pure helpers and `TestClient` or route-handler tests for HTTP behavior.
- Use shared setup only when a suite needs stable infrastructure behavior. Examples: `screenalytics/tests/conftest.py`, `TRR-Backend/tests/api/routers/conftest.py`, `TRR-APP/apps/web/tests/setup.ts`.

## Mocking

**Framework:** `pytest.monkeypatch`, `unittest.mock`, `fastapi.testclient.TestClient`, `vi.mock`, `vi.fn`, and Playwright route interception.

**Patterns:**
```python
# screenalytics/tests/api/test_screentime_cache.py
monkeypatch.setenv("STORAGE_BACKEND", "s3")
monkeypatch.setattr(episodes_router, "STORAGE", storage)
client = TestClient(app)
```

```python
# TRR-Backend/tests/api/routers/conftest.py
monkeypatch.setattr(admin_ops_repo, "create_or_attach_operation", _create_or_attach_operation)
monkeypatch.setattr(pipeline_admin_operations, "_EVENT_POLL_INTERVAL_SECONDS", 0.01)
```

```ts
// TRR-APP/apps/web/tests/setup.ts
vi.mock("next/image", () => ({ default: (props) => React.createElement("img", props) }));
vi.mock("server-only", () => ({}));
```

```ts
// TRR-APP/apps/web/tests/e2e/admin-fixtures.ts
await page.route("**/api/admin/**", async (route) => {
  await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(body) });
});
```

**What to Mock:**
- Mock external systems, networked storage, env-dependent startup behavior, Celery/Modal imports, and remote backend calls.
- In `screenalytics/tests/conftest.py`, heavy optional dependencies are neutralized up front with lazy `numpy`, a `cv2` stub, and Celery eager mode.
- In `TRR-APP/apps/web`, mock `server-only`, Firebase clients, and route helper dependencies before importing the unit under test.

**What NOT to Mock:**
- Do not bypass the route or component under test entirely. Keep the public entrypoint real and patch only its dependencies.
- For end-to-end admin flows in `TRR-APP/apps/web/tests/e2e/`, keep the browser, page routing, and UI actions real; stub backend responses with `page.route(...)` rather than mocking component internals.

## Fixtures and Factories

**Test Data:**
```python
# TRR-Backend/tests/fixtures/**
TRR-Backend/tests/fixtures/imdb/title_page_sample.html
TRR-Backend/tests/fixtures/tmdb/tv_details_sample.json
```

```ts
// TRR-APP/apps/web/tests/e2e/admin-fixtures.ts
export const buildShowCastMember = (personId: string, name: string, overrides = {}) => ({ ... });
```

**Location:**
- HTML and JSON scraping fixtures live in `TRR-Backend/tests/fixtures/`.
- Screenalytics helper stubs live in `screenalytics/tests/helpers/`, especially `celery_stubs.py`, `subprocess_fakes.py`, and `workspace_ui_source.py`.
- App-side test fixtures live in `TRR-APP/apps/web/tests/fixtures/` and Playwright builders live in `TRR-APP/apps/web/tests/e2e/admin-fixtures.ts`.

## Coverage

**Requirements:** No numeric coverage threshold is enforced in the discovered configs.

**View Coverage:**
```bash
cd TRR-APP/apps/web && pnpm exec vitest run -c vitest.config.ts --coverage
```

- `TRR-APP/apps/web/vitest.config.ts` is the only config that explicitly defines coverage reporters (`text`, `html`, `lcov`) and output directory (`coverage`).
- `TRR-Backend` and `screenalytics` do not declare coverage tooling or minimum thresholds in `pytest.ini`, `pyproject.toml`, or repo validation commands.

## Test Types

**Unit Tests:**
- `TRR-Backend` uses direct function tests and patched collaborators for services, repositories, parsing, and env logic. Representative files: `TRR-Backend/tests/services/test_retained_cast_screentime_dispatch.py`, `TRR-Backend/tests/scraping/test_google_news_parser.py`.
- `screenalytics` has broad unit coverage in `screenalytics/tests/unit/`, `screenalytics/tests/tools/`, and `screenalytics/tests/config/`.
- `TRR-APP/apps/web` uses Vitest for utility, route, and component behavior. Representative files: `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`, `TRR-APP/apps/web/tests/show-brand-logos-section.runtime.test.tsx`.

**Integration Tests:**
- `TRR-Backend` includes integration-style tests under `TRR-Backend/tests/integrations/` and route tests that exercise live FastAPI handlers through `TestClient`.
- `screenalytics` explicitly separates `tests/integration/`, `tests/api/`, `tests/ml/`, and `tests/ui/`.
- `TRR-APP/apps/web` treats many route tests as integration-at-the-module-boundary by importing actual Next route handlers and mocking only transport dependencies.

**E2E Tests:**
- `TRR-APP/apps/web` uses Playwright in `TRR-APP/apps/web/tests/e2e/`.
- `TRR-Backend` and `screenalytics` do not show a dedicated browser E2E framework in the discovered config files.

## Common Patterns

**Async Testing:**
```ts
// TRR-APP/apps/web/tests/social-ingest-health-dot-route.test.ts
const response = await GET(request);
const payload = (await response.json()) as { code?: string };
expect(response.status).toBe(502);
```

```ts
// TRR-APP/apps/web/tests/e2e/admin-cast-tabs-smoke.spec.ts
await page.goto(`/admin/trr-shows/${SHOW_ID}/seasons/${SEASON_NUMBER}?tab=cast`);
await waitForAdminReady(page);
await expect(page.getByRole("button", { name: "Cancel" }).first()).toHaveCount(0);
```

**Error Testing:**
```python
# screenalytics/tests/api/test_error_envelope_and_events.py
resp = client.get("/episodes", params={"limit": -1})
assert resp.status_code == 422
assert resp.json()["code"] == "VALIDATION_ERROR"
```

```python
# TRR-Backend/tests/services/test_retained_cast_screentime_dispatch.py
try:
    retained_cast_screentime_dispatch.start_run("run-123")
except retained_cast_screentime_dispatch.RetainedCastScreentimeDispatchError as exc:
    assert str(exc) == "backend runtime unavailable"
```

## Verification Commands Used In Practice

- Workspace fast lane in `scripts/test-fast.sh` is intentionally shallow:
  - `TRR-Backend`: full Ruff checks plus `tests/api/test_health.py`.
  - `TRR-APP`: `pnpm -C TRR-APP/apps/web run lint`.
  - `screenalytics`: `py_compile` on two entrypoints and optional `tests/api/test_trr_health.py` if present.
- Workspace full lane in `scripts/test.sh` runs:
  - `TRR-Backend`: Ruff + full `pytest`.
  - `TRR-APP`: lint + `next build --webpack` + `test:ci`.
  - `screenalytics`: `py_compile` plus `tests/api/test_trr_health.py`.
- Repo-local `AGENTS.md` files remain the source of truth for per-repo completion criteria.

## Coverage Gaps Visible From Repo Structure

- `screenalytics/web/` has lint and build tooling in `screenalytics/web/package.json`, but no detected unit, integration, or E2E test config. The active test surface is overwhelmingly Python-first.
- `screenalytics/docs/testing/KNOWN_FAILURES.md` documents environment-specific failures and skips, which means ML-heavy regressions need targeted validation, not just baseline `pytest`.
- `TRR-APP/apps/web` has broad Vitest and Playwright coverage, but the repo policy still requires targeted browser validation for admin flows and route behavior; unit tests are not treated as sufficient evidence for those changes.
- Workspace `make test-fast` and `make test-changed` are triage lanes, not release-grade verification. They do not approximate full repo-local validation for Screenalytics or the app.
- No discovered repo enforces coverage percentages or mutation-style checks, so untested paths remain a structural risk where a file has runtime code but no neighboring tests.

---

*Testing analysis: 2026-04-09*
