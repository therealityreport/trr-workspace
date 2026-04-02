# Supabase Unified Hardening — Combined Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate backend timeout blind spots, standardize the Supabase/Postgres env contract across all three repos, and restore the browser-side Supabase path for Flashback — in one coordinated pass.

**Architecture:** Three phases following workspace policy (TRR-Backend → screenalytics → TRR-APP). Phase 1 cleans up the backend's legacy env paths and adds timeout hardening. Phase 2 aligns screenalytics messaging. Phase 3 standardizes the frontend env contract, tightens proxy timeouts, and fixes the missing Flashback browser env. Each task is independently testable and produces a commit.

**Tech Stack:** Python 3.11 / FastAPI / psycopg2 / httpx (TRR-Backend), Python 3.11 / PyTorch (screenalytics), TypeScript / Next.js / node-postgres / Supabase JS (TRR-APP), Supabase Postgres 17, Supavisor session-mode pooling.

---

## File Structure

### Phase 1 — TRR-Backend

| File | Action | Responsibility |
|------|--------|----------------|
| `TRR-Backend/trr_backend/db/connection.py` | Modify | Remove legacy runtime envs; keep them in tooling-only path |
| `TRR-Backend/trr_backend/db/pg.py` | Modify | Add `connect_timeout`, `statement_timeout`, statement-timeout detection helper |
| `TRR-Backend/trr_backend/db/preflight.py` | Modify | Remove `DATABASE_URL` from runtime resolution |
| `TRR-Backend/trr_backend/middleware/__init__.py` | Create | Package init |
| `TRR-Backend/trr_backend/middleware/request_timeout.py` | Create | FastAPI request wall-clock timeout middleware |
| `TRR-Backend/api/main.py` | Modify | Mount timeout middleware, enhance `/health` with DB check, tighten startup validation |
| `TRR-Backend/supabase/config.toml` | Modify | Enable local pooler in session mode |
| `TRR-Backend/.env.example` | Modify | Document new env vars, remove deprecated ones |
| `TRR-Backend/tests/middleware/__init__.py` | Create | Package init |
| `TRR-Backend/tests/middleware/test_request_timeout.py` | Create | Middleware tests |
| `TRR-Backend/tests/db/test_pg_timeout_settings.py` | Create | Pool timeout config tests |
| `TRR-Backend/tests/db/test_pg_pool.py` | Modify | Update options-format assertions |
| `TRR-Backend/tests/db/test_connection_resolution.py` | Modify | Remove legacy env acceptance tests |
| `TRR-Backend/tests/api/test_health_check.py` | Create | Health check tests |

### Phase 2 — screenalytics

| File | Action | Responsibility |
|------|--------|----------------|
| `screenalytics/scripts/migrate_legacy_db_to_supabase.py` | Modify | Remove `SUPABASE_DB_URL` alias |

### Phase 3 — TRR-APP

| File | Action | Responsibility |
|------|--------|----------------|
| `TRR-APP/apps/web/src/lib/server/postgres.ts` | Modify | Rename direct-fallback env to shared name, reject `:6543` at runtime |
| `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts` | Modify | Tighten proxy timeout defaults |
| `TRR-APP/apps/web/.env.local` | Modify | Add `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts` | Modify | Update direct-fallback env name in tests |
| `TRR-APP/apps/web/tests/flashback-supabase-bootstrap.test.ts` | Create | Flashback regression test |

---

# Phase 1 — TRR-Backend

---

## Task 1: Remove Legacy Runtime Envs from Connection Resolution

**Why:** `connection.py` still accepts `SUPABASE_DB_URL` and `DATABASE_URL` as runtime candidates. Plan 2 requires persistent services to accept only `TRR_DB_URL` → `TRR_DB_FALLBACK_URL`. Legacy envs stay in tooling-only helpers (`preflight.py`, scripts).

**Files:**
- Modify: `TRR-Backend/trr_backend/db/connection.py` (lines 23, 133, 185-200)
- Modify: `TRR-Backend/tests/db/test_connection_resolution.py`

- [ ] **Step 1: Write the failing test that proves legacy envs are rejected**

In `TRR-Backend/tests/db/test_connection_resolution.py`, add a new test class:

```python
class TestLegacyEnvsRejected:
    """Legacy runtime envs must NOT appear in runtime candidates."""

    def test_supabase_db_url_ignored_at_runtime(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _clear_all_db_envs(monkeypatch)
        monkeypatch.setenv("SUPABASE_DB_URL", "postgresql://legacy:pw@pooler.supabase.com:5432/postgres")
        candidates = resolve_database_url_candidate_details(allow_local_fallback=False)
        sources = [c["source"] for c in candidates]
        assert "SUPABASE_DB_URL" not in sources
        assert len(candidates) == 0

    def test_database_url_ignored_at_runtime(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _clear_all_db_envs(monkeypatch)
        monkeypatch.setenv("DATABASE_URL", "postgresql://legacy:pw@pooler.supabase.com:5432/postgres")
        candidates = resolve_database_url_candidate_details(allow_local_fallback=False)
        sources = [c["source"] for c in candidates]
        assert "DATABASE_URL" not in sources
        assert len(candidates) == 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TRR-Backend && python -m pytest tests/db/test_connection_resolution.py::TestLegacyEnvsRejected -v`
Expected: FAIL — legacy envs still produce candidates.

- [ ] **Step 3: Remove legacy envs from runtime resolution**

In `TRR-Backend/trr_backend/db/connection.py`:

Remove the `LEGACY_RUNTIME_DB_ENVS` constant (line 23):
```python
# DELETE this line:
# LEGACY_RUNTIME_DB_ENVS = ("SUPABASE_DB_URL", "DATABASE_URL")
```

In `resolve_database_url_candidate_details` (lines 187-188), remove the legacy env loop:
```python
# DELETE these lines:
#     for legacy_env in LEGACY_RUNTIME_DB_ENVS:
#         _append_candidate_with_optional_direct_fallback(os.getenv(legacy_env), source=legacy_env)
```

Update the docstring (line 133) to remove items 3 and 5:
```python
    """
    Resolve candidate database URLs in priority order.

    Priority order:
    1. TRR_DB_URL
    2. TRR_DB_FALLBACK_URL (optional operator-provided fallback)
    3. (Optional) Auto-derived Supabase direct host fallback when explicitly enabled
    4. (Local only) `supabase status --output env` DB_URL — tooling convenience only
    """
```

- [ ] **Step 4: Update existing tests that encoded legacy env acceptance**

In `TRR-Backend/tests/db/test_connection_resolution.py`:

The test at line 23 clears all envs including `SUPABASE_DB_URL` and `DATABASE_URL` — update the `_clear_all_db_envs` helper to only clear canonical envs:
```python
def _clear_all_db_envs(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("TRR_DB_URL", "TRR_DB_FALLBACK_URL", "TRR_DB_ENABLE_DIRECT_FALLBACK"):
        monkeypatch.delenv(name, raising=False)
```

Remove or update the test at line 117 that sets `SUPABASE_DB_URL` and expects it in candidates — replace it with the `TestLegacyEnvsRejected` tests from Step 1.

In `TRR-Backend/tests/db/test_pg_pool.py` (line 262), if a test sets `SUPABASE_DB_URL` as a source, update it to use `TRR_DB_URL`.

- [ ] **Step 5: Run all connection resolution tests**

Run: `cd TRR-Backend && python -m pytest tests/db/test_connection_resolution.py tests/db/test_pg_pool.py -v`
Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
cd TRR-Backend
git add trr_backend/db/connection.py tests/db/test_connection_resolution.py tests/db/test_pg_pool.py
git commit -m "feat: remove legacy SUPABASE_DB_URL and DATABASE_URL from runtime resolution"
```

---

## Task 2: Add `connect_timeout` and `statement_timeout` to psycopg2 Pool

**Why:** Without `connect_timeout`, pool creation blocks for ~2 minutes (OS TCP default) when the DB is unreachable. Without `statement_timeout`, any query can run indefinitely. The existing `social_season_analytics.py` uses `SET LOCAL statement_timeout = '5000'` which correctly overrides the session default for those specific queries.

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py` (lines 32-40, 231-250)
- Modify: `TRR-Backend/tests/db/test_pg_pool.py` (lines 543, 563)
- Create: `TRR-Backend/tests/db/test_pg_timeout_settings.py`
- Modify: `TRR-Backend/.env.example`

- [ ] **Step 1: Write the failing test**

```python
# TRR-Backend/tests/db/test_pg_timeout_settings.py
"""Tests for psycopg2 pool timeout configuration."""

from __future__ import annotations

import pytest

from trr_backend.db.pg import _build_pool_for_url, DEFAULT_IDLE_IN_TX_TIMEOUT_MS


class TestConnectTimeout:
    def test_connect_timeout_as_kwarg(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """connect_timeout must be a top-level DSN kwarg, not in options."""
        monkeypatch.setenv("TRR_DB_POOL_MINCONN", "1")
        monkeypatch.setenv("TRR_DB_POOL_MAXCONN", "1")

        captured_kwargs = {}
        import psycopg2.pool

        def capturing_init(self, minconn, maxconn, **kwargs):
            captured_kwargs.update(kwargs)
            raise ConnectionError("intentional — just capturing kwargs")

        monkeypatch.setattr(psycopg2.pool.ThreadedConnectionPool, "__init__", capturing_init)

        with pytest.raises(ConnectionError, match="intentional"):
            _build_pool_for_url("postgresql://user:pass@localhost:5432/testdb")

        options = captured_kwargs.get("options", "")
        assert "connect_timeout" not in options, "connect_timeout goes in DSN kwargs, not options"
        assert captured_kwargs.get("connect_timeout") == 10

    def test_connect_timeout_env_override(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("TRR_DB_CONNECT_TIMEOUT_SECONDS", "5")
        monkeypatch.setenv("TRR_DB_POOL_MINCONN", "1")
        monkeypatch.setenv("TRR_DB_POOL_MAXCONN", "1")

        captured_kwargs = {}
        import psycopg2.pool

        def capturing_init(self, minconn, maxconn, **kwargs):
            captured_kwargs.update(kwargs)
            raise ConnectionError("intentional")

        monkeypatch.setattr(psycopg2.pool.ThreadedConnectionPool, "__init__", capturing_init)

        with pytest.raises(ConnectionError, match="intentional"):
            _build_pool_for_url("postgresql://user:pass@remotehost:5432/testdb")

        assert captured_kwargs.get("connect_timeout") == 5


class TestStatementTimeout:
    def test_idle_in_transaction_timeout_in_options(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("TRR_DB_POOL_MINCONN", "1")
        monkeypatch.setenv("TRR_DB_POOL_MAXCONN", "1")

        captured_kwargs = {}
        import psycopg2.pool

        def capturing_init(self, minconn, maxconn, **kwargs):
            captured_kwargs.update(kwargs)
            raise ConnectionError("intentional")

        monkeypatch.setattr(psycopg2.pool.ThreadedConnectionPool, "__init__", capturing_init)

        with pytest.raises(ConnectionError, match="intentional"):
            _build_pool_for_url("postgresql://user:pass@localhost:5432/testdb")

        options = captured_kwargs.get("options", "")
        assert f"idle_in_transaction_session_timeout={DEFAULT_IDLE_IN_TX_TIMEOUT_MS}" in options

    def test_statement_timeout_in_options(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("TRR_DB_POOL_MINCONN", "1")
        monkeypatch.setenv("TRR_DB_POOL_MAXCONN", "1")

        captured_kwargs = {}
        import psycopg2.pool

        def capturing_init(self, minconn, maxconn, **kwargs):
            captured_kwargs.update(kwargs)
            raise ConnectionError("intentional")

        monkeypatch.setattr(psycopg2.pool.ThreadedConnectionPool, "__init__", capturing_init)

        with pytest.raises(ConnectionError, match="intentional"):
            _build_pool_for_url("postgresql://user:pass@localhost:5432/testdb")

        options = captured_kwargs.get("options", "")
        assert "statement_timeout=" in options
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TRR-Backend && python -m pytest tests/db/test_pg_timeout_settings.py -v`
Expected: FAIL — `connect_timeout` and `statement_timeout` not present.

- [ ] **Step 3: Implement connect_timeout and statement_timeout in pool builder**

In `TRR-Backend/trr_backend/db/pg.py`, add constants near line 40:

```python
DEFAULT_CONNECT_TIMEOUT_SECONDS = 10
DEFAULT_STATEMENT_TIMEOUT_MS = 30000  # 30 seconds
```

Replace the `_build_pool_for_url` function (line 231) with:

```python
def _build_pool_for_url(url: str) -> ThreadedConnectionPool:
    sizing = _resolve_pool_sizing(url)
    minconn = int(sizing["minconn"])
    maxconn = int(sizing["maxconn"])
    app_name = _resolve_application_name()

    sslmode = _sslmode_for_url(url)
    connect_kwargs: dict[str, Any] = {"dsn": url}
    connect_kwargs["application_name"] = app_name["application_name"]
    if sslmode:
        connect_kwargs["sslmode"] = sslmode

    # TCP-level connect timeout (seconds) — prevents 2-min OS TCP hangs
    connect_timeout = _env_int(
        "TRR_DB_CONNECT_TIMEOUT_SECONDS",
        DEFAULT_CONNECT_TIMEOUT_SECONDS,
        minimum=1,
    )
    connect_kwargs["connect_timeout"] = connect_timeout

    # Session-level Postgres options
    option_parts: list[str] = []

    idle_in_tx_timeout_ms = _env_int(
        "TRR_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS",
        DEFAULT_IDLE_IN_TX_TIMEOUT_MS,
        minimum=1000,
    )
    if idle_in_tx_timeout_ms > 0:
        option_parts.append(f"idle_in_transaction_session_timeout={idle_in_tx_timeout_ms}")

    statement_timeout_ms = _env_int(
        "TRR_DB_STATEMENT_TIMEOUT_MS",
        DEFAULT_STATEMENT_TIMEOUT_MS,
        minimum=1000,
    )
    if statement_timeout_ms > 0:
        option_parts.append(f"statement_timeout={statement_timeout_ms}")

    if option_parts:
        connect_kwargs["options"] = " ".join(f"-c {part}" for part in option_parts)

    return ThreadedConnectionPool(minconn=minconn, maxconn=maxconn, **connect_kwargs)
```

- [ ] **Step 4: Run new timeout tests**

Run: `cd TRR-Backend && python -m pytest tests/db/test_pg_timeout_settings.py -v`
Expected: All PASS.

- [ ] **Step 5: Update existing pool tests that assert the old options format**

In `TRR-Backend/tests/db/test_pg_pool.py`, lines 543 and 563 assert:
```python
assert captured["options"] == "-c idle_in_transaction_session_timeout=60000"
```

Replace both with:
```python
options = captured["options"]
assert "-c idle_in_transaction_session_timeout=60000" in options
assert "-c statement_timeout=30000" in options
assert captured.get("connect_timeout") == 10
```

- [ ] **Step 6: Run all db tests for regressions**

Run: `cd TRR-Backend && python -m pytest tests/db/ -v`
Expected: All PASS.

- [ ] **Step 7: Document new env vars in .env.example**

Add to `TRR-Backend/.env.example`:

```env
# --- Connection Timeout ---
# TCP-level connect timeout in seconds. Prevents 2-minute OS hangs when DB is unreachable.
# Default: 10 seconds.
# TRR_DB_CONNECT_TIMEOUT_SECONDS=10

# --- Statement Timeout ---
# Default statement_timeout for all queries (milliseconds). Prevents runaway queries.
# Individual endpoints can override with SET LOCAL statement_timeout.
# Default: 30000 (30 seconds).
# TRR_DB_STATEMENT_TIMEOUT_MS=30000
```

- [ ] **Step 8: Commit**

```bash
cd TRR-Backend
git add trr_backend/db/pg.py tests/db/test_pg_timeout_settings.py tests/db/test_pg_pool.py .env.example
git commit -m "feat: add connect_timeout (10s) and statement_timeout (30s) to psycopg2 pool"
```

---

## Task 3: Add FastAPI Request Timeout Middleware

**Why:** If a database query or external HTTP call hangs, the request hangs forever. No wall-clock guard exists. This middleware cancels any request exceeding a configurable limit.

**Files:**
- Create: `TRR-Backend/trr_backend/middleware/__init__.py`
- Create: `TRR-Backend/trr_backend/middleware/request_timeout.py`
- Create: `TRR-Backend/tests/middleware/__init__.py`
- Create: `TRR-Backend/tests/middleware/test_request_timeout.py`
- Modify: `TRR-Backend/api/main.py`
- Modify: `TRR-Backend/.env.example`

- [ ] **Step 1: Create package inits**

```python
# TRR-Backend/trr_backend/middleware/__init__.py
# (empty)
```

```python
# TRR-Backend/tests/middleware/__init__.py
# (empty)
```

- [ ] **Step 2: Write the failing test**

```python
# TRR-Backend/tests/middleware/test_request_timeout.py
"""Tests for request timeout middleware."""

from __future__ import annotations

import asyncio

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from trr_backend.middleware.request_timeout import RequestTimeoutMiddleware


def _make_app(timeout_seconds: float) -> FastAPI:
    app = FastAPI()
    app.add_middleware(RequestTimeoutMiddleware, timeout_seconds=timeout_seconds)

    @app.get("/fast")
    async def fast_endpoint():
        return {"ok": True}

    @app.get("/slow")
    async def slow_endpoint():
        await asyncio.sleep(10)
        return {"ok": True}

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    return app


class TestRequestTimeoutMiddleware:
    def test_fast_request_succeeds(self) -> None:
        app = _make_app(timeout_seconds=5.0)
        client = TestClient(app)
        response = client.get("/fast")
        assert response.status_code == 200
        assert response.json() == {"ok": True}

    def test_slow_request_times_out(self) -> None:
        app = _make_app(timeout_seconds=0.1)
        client = TestClient(app)
        response = client.get("/slow")
        assert response.status_code == 504
        body = response.json()
        assert body["code"] == "REQUEST_TIMEOUT"

    def test_health_endpoint_exempt(self) -> None:
        app = _make_app(timeout_seconds=0.1)
        client = TestClient(app)
        response = client.get("/health")
        assert response.status_code == 200

    def test_default_timeout_from_env(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("TRR_REQUEST_TIMEOUT_SECONDS", "42")
        from trr_backend.middleware.request_timeout import _parse_timeout_from_env
        assert _parse_timeout_from_env() == 42.0
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd TRR-Backend && python -m pytest tests/middleware/test_request_timeout.py -v`
Expected: FAIL — `ModuleNotFoundError`.

- [ ] **Step 4: Write the middleware**

```python
# TRR-Backend/trr_backend/middleware/request_timeout.py
"""Middleware that enforces a wall-clock timeout on every HTTP request."""

from __future__ import annotations

import asyncio
import logging
import os

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

logger = logging.getLogger(__name__)

DEFAULT_TIMEOUT_SECONDS = 30.0
EXEMPT_PATHS = frozenset({"/", "/health", "/metrics"})


def _parse_timeout_from_env() -> float:
    raw = (os.getenv("TRR_REQUEST_TIMEOUT_SECONDS") or "").strip()
    if not raw:
        return DEFAULT_TIMEOUT_SECONDS
    try:
        value = float(raw)
        return value if value > 0 else DEFAULT_TIMEOUT_SECONDS
    except ValueError:
        return DEFAULT_TIMEOUT_SECONDS


class RequestTimeoutMiddleware(BaseHTTPMiddleware):
    """Cancel requests exceeding a wall-clock limit.

    Health/metrics endpoints are exempt so monitoring probes never time out.
    """

    def __init__(self, app, *, timeout_seconds: float | None = None) -> None:
        super().__init__(app)
        self.timeout_seconds = timeout_seconds if timeout_seconds is not None else _parse_timeout_from_env()

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)

        try:
            return await asyncio.wait_for(call_next(request), timeout=self.timeout_seconds)
        except asyncio.TimeoutError:
            logger.warning(
                "[request-timeout] path=%s method=%s timeout_seconds=%s",
                request.url.path,
                request.method,
                self.timeout_seconds,
            )
            return JSONResponse(
                status_code=504,
                content={
                    "code": "REQUEST_TIMEOUT",
                    "message": f"Request timed out after {self.timeout_seconds}s",
                    "retryable": True,
                },
            )
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd TRR-Backend && python -m pytest tests/middleware/test_request_timeout.py -v`
Expected: All 4 PASS.

- [ ] **Step 6: Mount middleware in main.py**

In `TRR-Backend/api/main.py`, add import and mount **before** CORSMiddleware:

```python
from trr_backend.middleware.request_timeout import RequestTimeoutMiddleware

# Add BEFORE CORSMiddleware
app.add_middleware(RequestTimeoutMiddleware)
```

- [ ] **Step 7: Document in .env.example**

```env
# --- Request Timeout ---
# Wall-clock timeout for HTTP requests (excludes /health, /metrics).
# Default: 30 seconds.
# TRR_REQUEST_TIMEOUT_SECONDS=30
```

- [ ] **Step 8: Commit**

```bash
cd TRR-Backend
git add trr_backend/middleware/ tests/middleware/ api/main.py .env.example
git commit -m "feat: add FastAPI request timeout middleware (30s default)"
```

---

## Task 4: Add DB-Aware Health Check

**Why:** The current `/health` returns 200 even when the database is unreachable. Deployment orchestrators need to know when the backend can serve requests.

**Files:**
- Modify: `TRR-Backend/api/main.py`
- Create: `TRR-Backend/tests/api/test_health_check.py`

- [ ] **Step 1: Write the failing test**

```python
# TRR-Backend/tests/api/test_health_check.py
"""Tests for the health check endpoint."""

from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


class TestHealthCheck:
    def test_health_returns_ok_when_db_available(self) -> None:
        with patch("api.main.fetch_one", return_value={"ok": 1}):
            from api.main import app
            client = TestClient(app)
            response = client.get("/health")
            assert response.status_code == 200
            body = response.json()
            assert body["status"] == "ok"
            assert body["database"] == "connected"

    def test_health_returns_degraded_when_db_unavailable(self) -> None:
        with patch("api.main.fetch_one", side_effect=Exception("connection refused")):
            from api.main import app
            client = TestClient(app)
            response = client.get("/health")
            assert response.status_code == 503
            body = response.json()
            assert body["status"] == "degraded"
            assert body["database"] == "unreachable"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TRR-Backend && python -m pytest tests/api/test_health_check.py -v`
Expected: FAIL — current health endpoint doesn't check DB.

- [ ] **Step 3: Implement DB-aware health check**

In `TRR-Backend/api/main.py`, add import:

```python
from trr_backend.db.pg import fetch_one
```

Replace the existing health endpoint:

```python
@app.get("/health")
async def health_check():
    """Health check with database connectivity validation."""
    db_status = "connected"
    http_status = 200
    try:
        fetch_one("SELECT 1 AS ok")
    except Exception:
        db_status = "unreachable"
        http_status = 503

    return JSONResponse(
        status_code=http_status,
        content={
            "status": "ok" if http_status == 200 else "degraded",
            "database": db_status,
        },
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd TRR-Backend && python -m pytest tests/api/test_health_check.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd TRR-Backend
git add api/main.py tests/api/test_health_check.py
git commit -m "feat: add DB-aware health check endpoint"
```

---

## Task 5: Enable Local Supabase Pooler + Session Mode

**Why:** Local config has `[db.pooler] enabled = false` and `pool_mode = "transaction"`. This means dev never exercises pooling, and the mode doesn't match production (session mode via Supavisor). Hides pooler bugs.

**Files:**
- Modify: `TRR-Backend/supabase/config.toml` (lines 36-46)

- [ ] **Step 1: Update the pooler section**

In `TRR-Backend/supabase/config.toml`, replace the `[db.pooler]` section:

```toml
[db.pooler]
enabled = true
port = 54329
pool_mode = "session"
default_pool_size = 10
max_client_conn = 50
```

Changes: `enabled` false→true, `pool_mode` "transaction"→"session", `default_pool_size` 20→10, `max_client_conn` 100→50.

- [ ] **Step 2: Verify local Supabase starts cleanly**

Run: `cd TRR-Backend && supabase stop && supabase start`
Expected: Pooler URL shown on port 54329.

- [ ] **Step 3: Commit**

```bash
cd TRR-Backend
git add supabase/config.toml
git commit -m "feat: enable local Supabase pooler in session mode for dev/prod parity"
```

---

## Task 6: Add Statement Timeout Observability

**Why:** Once timeouts are in place, you need to know when they fire. A `statement_timeout` cancellation is NOT transient (retrying hits the same timeout), so it must be detected and logged separately from transport errors.

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py`

- [ ] **Step 1: Add statement_timeout detection helper**

In `TRR-Backend/trr_backend/db/pg.py`, after `_is_transient_transport_error` (line ~191):

```python
def _is_statement_timeout_error(error: Exception) -> bool:
    """Check if the error is a Postgres statement_timeout cancellation."""
    message = _error_message(error)
    return "canceling statement due to statement timeout" in message
```

- [ ] **Step 2: Add timeout logging in db_connection**

In the `db_connection` context manager (line ~607), enhance the except block:

```python
@contextmanager
def db_connection(*, label: str = "write"):
    pool, conn, checkout_id = _get_connection_with_retry(label=label)
    try:
        yield conn
        conn.commit()
    except Exception as error:
        if _is_statement_timeout_error(error):
            logger.warning(
                "[db-pool] statement_timeout label=%s checkout_id=%s error=%s",
                label,
                checkout_id,
                error,
            )
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        should_close = _is_connection_closed(conn) or not _ensure_connection_idle(
            conn,
            label=label,
            phase="return",
        )
        if should_close:
            try:
                _log_return(pool=pool, conn=conn, checkout_id=checkout_id, label=label)
                pool.putconn(conn, close=True)
            except Exception:
                logger.exception("[db-pool] discard_failed label=%s phase=return", label)
        else:
            try:
                _log_return(pool=pool, conn=conn, checkout_id=checkout_id, label=label)
                pool.putconn(conn)
            except PoolError as error:
                if "pool is closed" not in _error_message(error):
                    raise
```

Do the same for `db_read_connection` — add the `_is_statement_timeout_error` check in the `try:` block before the `finally:`.

- [ ] **Step 3: Run full backend test suite**

Run: `cd TRR-Backend && python -m pytest tests/ -v --timeout=60`
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
cd TRR-Backend
git add trr_backend/db/pg.py
git commit -m "feat: add statement_timeout detection and structured logging"
```

---

## Task 7: Clean Up Backend .env.example and Tooling References

**Why:** `.env.example` and inline error messages still reference deprecated env vars. Plan 2 requires all persistent-service docs to advertise only the canonical contract.

**Files:**
- Modify: `TRR-Backend/.env.example`
- Modify: `TRR-Backend/trr_backend/db/preflight.py` (line 108)

- [ ] **Step 1: Remove DATABASE_URL from preflight runtime resolution**

In `TRR-Backend/trr_backend/db/preflight.py`, line 108, change:

```python
# FROM:
db_url = (os.getenv("TRR_DB_URL") or os.getenv("TRR_DB_FALLBACK_URL") or os.getenv("DATABASE_URL") or "").strip()
# TO:
db_url = (os.getenv("TRR_DB_URL") or os.getenv("TRR_DB_FALLBACK_URL") or "").strip()
```

And line 113, change:
```python
# FROM:
"or DATABASE_URL only for tool-specific migration flows."
# TO:
"For tool-specific migration flows, set DATABASE_URL separately via scripts/_db_url.py."
```

- [ ] **Step 2: Audit .env.example for deprecated env names**

In `TRR-Backend/.env.example`, find any lines referencing `SUPABASE_DB_URL` or `DATABASE_URL` as runtime candidates and either remove them or mark as "tooling-only, not read at runtime."

- [ ] **Step 3: Run linter and formatter**

Run: `cd TRR-Backend && ruff check . && ruff format --check .`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd TRR-Backend
git add trr_backend/db/preflight.py .env.example
git commit -m "chore: remove deprecated env refs from preflight and .env.example"
```

---

## Phase 1 Verification Gate

Run: `cd TRR-Backend && ruff check . && ruff format --check . && python -m pytest -q`
Expected: All checks PASS before moving to Phase 2.

---

# Phase 2 — screenalytics

---

## Task 8: Remove Legacy Env Alias from screenalytics Migration Script

**Why:** `screenalytics/scripts/migrate_legacy_db_to_supabase.py` still defines `TRR_DB_URL_ALIAS = "SUPABASE_DB_URL"`. This is the only deprecated reference in screenalytics — the runtime code already uses the canonical contract correctly.

**Files:**
- Modify: `screenalytics/scripts/migrate_legacy_db_to_supabase.py` (line 39)

- [ ] **Step 1: Remove the alias**

In `screenalytics/scripts/migrate_legacy_db_to_supabase.py`, line 39:

```python
# DELETE or comment out:
# TRR_DB_URL_ALIAS = "SUPABASE_DB_URL"
```

Then find any references to `TRR_DB_URL_ALIAS` in that file and replace with inline `"TRR_DB_URL"` or remove the fallback entirely.

- [ ] **Step 2: Run screenalytics tests**

Run: `cd screenalytics && pytest -q`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
cd screenalytics
git add scripts/migrate_legacy_db_to_supabase.py
git commit -m "chore: remove deprecated SUPABASE_DB_URL alias from migration script"
```

---

## Phase 2 Verification Gate

Run: `cd screenalytics && pytest -q`
Expected: PASS.

---

# Phase 3 — TRR-APP

---

## Task 9: Standardize Direct-Fallback Env Name in Frontend Postgres

**Why:** `postgres.ts` reads `POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK` and `POSTGRES_ENABLE_DIRECT_FALLBACK`. Plan 2 requires the shared name `TRR_DB_ENABLE_DIRECT_FALLBACK`. The TRR-APP runtime also needs to reject transaction-pooler (`:6543`) connections.

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/postgres.ts` (lines 131-134)
- Modify: `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts` (line 45)

- [ ] **Step 1: Update the direct-fallback env check**

In `TRR-APP/apps/web/src/lib/server/postgres.ts`, line 131-134, change:

```typescript
// FROM:
const isSupabaseDirectFallbackEnabled = (env: EnvLike = process.env): boolean => {
  const value =
    env.POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK ?? env.POSTGRES_ENABLE_DIRECT_FALLBACK ?? "";
  return ["1", "true", "yes", "on"].includes(value.trim().toLowerCase());
};

// TO:
const isSupabaseDirectFallbackEnabled = (env: EnvLike = process.env): boolean => {
  const value = env.TRR_DB_ENABLE_DIRECT_FALLBACK ?? "";
  return ["1", "true", "yes", "on"].includes(value.trim().toLowerCase());
};
```

- [ ] **Step 2: Add transaction-pooler rejection**

After the `resolvePostgresConnectionCandidateDetails` function, add a runtime guard in `resolvePostgresConnectionString` (around line 173). After resolving the winning candidate, check if it's a `:6543` transaction-pooler and reject it:

```typescript
export const resolvePostgresConnectionString = (env: EnvLike = process.env): string => {
  const candidates = resolvePostgresConnectionCandidates(env);
  const connectionString = candidates[0];
  if (!connectionString) {
    throw new Error(
      "No database connection string is set. Configure TRR_DB_URL or TRR_DB_FALLBACK_URL.",
    );
  }
  if (classifyConnectionClass(connectionString) === "transaction") {
    throw new Error(
      "Transaction-mode pooler (:6543) is not supported for persistent app runtime. " +
      "Use session-mode pooler (:5432) via TRR_DB_URL.",
    );
  }
  return connectionString;
};
```

- [ ] **Step 3: Update test**

In `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`, line 45, change:

```typescript
// FROM:
POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK: "true",
// TO:
TRR_DB_ENABLE_DIRECT_FALLBACK: "true",
```

Add a new test for transaction-pooler rejection:

```typescript
it("rejects transaction-mode pooler URLs at runtime", () => {
  expect(() =>
    resolvePostgresConnectionString({
      TRR_DB_URL:
        "postgresql://postgres.ref:secret@aws-1-us-east-1.pooler.supabase.com:6543/postgres",
    }),
  ).toThrow("Transaction-mode pooler (:6543) is not supported");
});
```

- [ ] **Step 4: Run tests**

Run: `cd TRR-APP && pnpm -C apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
cd TRR-APP
git add apps/web/src/lib/server/postgres.ts apps/web/tests/postgres-connection-string-resolution.test.ts
git commit -m "feat: standardize direct-fallback env to TRR_DB_ENABLE_DIRECT_FALLBACK, reject :6543"
```

---

## Task 10: Tighten Social Proxy Timeout Defaults

**Why:** Defaults are 25/45/90s. On Vercel serverless, each burns function time. Most social API calls complete in under 15s.

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts` (lines 86-88)

- [ ] **Step 1: Update defaults**

In `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`, lines 86-88:

```typescript
// FROM:
export const SOCIAL_PROXY_SHORT_TIMEOUT_MS = readPositiveIntEnv("TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS", 25_000);
export const SOCIAL_PROXY_DEFAULT_TIMEOUT_MS = readPositiveIntEnv("TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS", 45_000);
export const SOCIAL_PROXY_LONG_TIMEOUT_MS = readPositiveIntEnv("TRR_SOCIAL_PROXY_LONG_TIMEOUT_MS", 90_000);

// TO:
export const SOCIAL_PROXY_SHORT_TIMEOUT_MS = readPositiveIntEnv("TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS", 10_000);
export const SOCIAL_PROXY_DEFAULT_TIMEOUT_MS = readPositiveIntEnv("TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS", 25_000);
export const SOCIAL_PROXY_LONG_TIMEOUT_MS = readPositiveIntEnv("TRR_SOCIAL_PROXY_LONG_TIMEOUT_MS", 60_000);
```

- [ ] **Step 2: Lint**

Run: `cd TRR-APP && pnpm -C apps/web run lint`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
cd TRR-APP
git add apps/web/src/lib/server/trr-api/social-admin-proxy.ts
git commit -m "feat: tighten social proxy timeout defaults (10/25/60s)"
```

---

## Task 11: Restore Browser Supabase Env for Flashback

**Why:** `.env.local` lacks `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`. The browser Supabase client returns `null`, and Flashback throws "Supabase is not configured." This is a local config drift — the server-side Supabase surface is healthy.

**Files:**
- Modify: `TRR-APP/apps/web/.env.local`
- Create: `TRR-APP/apps/web/tests/flashback-supabase-bootstrap.test.ts`

- [ ] **Step 1: Write the Flashback regression test**

```typescript
// TRR-APP/apps/web/tests/flashback-supabase-bootstrap.test.ts
import { describe, expect, it, vi, beforeEach } from "vitest";

describe("Flashback Supabase bootstrap", () => {
  beforeEach(() => {
    vi.resetModules();
  });

  it("throws a clear error when NEXT_PUBLIC_SUPABASE_URL is missing", async () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "");

    const { getTodaysQuiz } = await import("@/lib/flashback/supabase");
    await expect(getTodaysQuiz()).rejects.toThrow("Supabase is not configured");
  });

  it("creates a client when both NEXT_PUBLIC_SUPABASE_* vars are present", async () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://test.supabase.co");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "test-anon-key");

    const { createClient } = await import("@/lib/supabase/client");
    const client = createClient();
    expect(client).not.toBeNull();
  });
});
```

- [ ] **Step 2: Run the test to verify the failure case works**

Run: `cd TRR-APP && pnpm -C apps/web exec vitest run tests/flashback-supabase-bootstrap.test.ts`
Expected: Both tests PASS (the first proves the error message, the second proves the fix).

- [ ] **Step 3: Add the missing env vars to .env.local**

In `TRR-APP/apps/web/.env.local`, add:

```env
# Browser-side Supabase client (required for Flashback, public game features)
# Use the same project as TRR_CORE_SUPABASE_URL — these are public (anon) credentials.
NEXT_PUBLIC_SUPABASE_URL=<value from TRR_CORE_SUPABASE_URL>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon key from Supabase dashboard>
```

**Important:** The values must come from the same Supabase project as `TRR_CORE_SUPABASE_URL`. The anon key is public — it is safe to commit to `.env.local` if it's gitignored, or inject via Vercel env vars for deployment.

- [ ] **Step 4: Verify Flashback loads locally**

Run: `cd TRR-APP && pnpm -C apps/web run dev`
Then visit `http://localhost:3000/flashback/cover` while signed in.
Expected: No "Supabase is not configured" error.

- [ ] **Step 5: Commit**

```bash
cd TRR-APP
git add apps/web/tests/flashback-supabase-bootstrap.test.ts
# .env.local is gitignored — do NOT commit it. Document the required vars in .env.example instead.
git commit -m "test: add Flashback Supabase bootstrap regression test"
```

---

## Task 12: SSE Proxy Caller Audit

**Why:** The SSE proxy defaults to 3s connection timeout (good) but overall stream timeout is caller-dependent. Verify all callers pass explicit `timeoutMs`.

**Files:**
- Audit: `TRR-APP/apps/web/src/lib/server/sse-proxy.ts` callers

- [ ] **Step 1: Find all SSE proxy callers**

Run: `cd TRR-APP && grep -rn "streamSseProxy\|streamBackendSse\|sseProxy" apps/web/src/lib/server/ --include="*.ts"`

Review each caller. If any omit `timeoutMs`, add a reasonable default (30_000 for admin ops, 60_000 for batch ops).

- [ ] **Step 2: Commit if changes made**

```bash
cd TRR-APP
git add apps/web/src/lib/server/
git commit -m "fix: ensure all SSE proxy callers pass explicit timeoutMs"
```

---

## Phase 3 Verification Gate

Run all three checks:
```bash
cd TRR-APP && pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci
```
Expected: All PASS.

---

# Summary

| # | Task | Repo | What It Fixes |
|---|------|------|---------------|
| 1 | Remove legacy runtime envs | Backend | Contract drift (Plan 2) |
| 2 | Add connect_timeout + statement_timeout | Backend | Runaway queries, TCP hangs (Plan 1) |
| 3 | Request timeout middleware | Backend | Hung HTTP requests (Plan 1) |
| 4 | DB-aware health check | Backend | Blind health endpoint (Plan 1) |
| 5 | Enable local pooler, session mode | Backend | Dev/prod parity (Plans 1+2) |
| 6 | Statement timeout observability | Backend | Missing timeout logging (Plan 1) |
| 7 | Clean up .env.example + preflight | Backend | Deprecated env refs (Plan 2) |
| 8 | Remove screenalytics legacy alias | screenalytics | Contract drift (Plan 2) |
| 9 | Standardize direct-fallback env | TRR-APP | Env name fragmentation (Plan 2) |
| 10 | Tighten social proxy timeouts | TRR-APP | Vercel cost burn (Plan 1) |
| 11 | Restore browser Supabase env | TRR-APP | Flashback broken locally (Plan 3) |
| 12 | SSE proxy caller audit | TRR-APP | Missing explicit timeouts (Plan 1) |

## Env Contract After This Plan

| Env Var | Scope | Status |
|---------|-------|--------|
| `TRR_DB_URL` | All repos, runtime | **Canonical** |
| `TRR_DB_FALLBACK_URL` | All repos, runtime | **Explicit secondary** |
| `TRR_DB_ENABLE_DIRECT_FALLBACK` | All repos, runtime | **Shared override** |
| `TRR_REQUEST_TIMEOUT_SECONDS` | Backend | **New** (default: 30) |
| `TRR_DB_CONNECT_TIMEOUT_SECONDS` | Backend | **New** (default: 10) |
| `TRR_DB_STATEMENT_TIMEOUT_MS` | Backend | **New** (default: 30000) |
| `NEXT_PUBLIC_SUPABASE_URL` | TRR-APP browser | **Required for Flashback** |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | TRR-APP browser | **Required for Flashback** |
| `SUPABASE_DB_URL` | ~~Runtime~~ | **Removed from runtime** |
| `DATABASE_URL` | ~~Runtime~~ | **Removed from runtime** |
| `POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK` | ~~TRR-APP~~ | **Replaced** by `TRR_DB_ENABLE_DIRECT_FALLBACK` |
| `POSTGRES_ENABLE_DIRECT_FALLBACK` | ~~TRR-APP~~ | **Replaced** by `TRR_DB_ENABLE_DIRECT_FALLBACK` |

## Timeout Defense Layers (After This Plan)

| Layer | Guard | Default | Override |
|-------|-------|---------|----------|
| HTTP request | FastAPI middleware | 30s | `TRR_REQUEST_TIMEOUT_SECONDS` |
| Postgres statement | Session `statement_timeout` | 30s | `TRR_DB_STATEMENT_TIMEOUT_MS` |
| TCP connect | psycopg2 `connect_timeout` | 10s | `TRR_DB_CONNECT_TIMEOUT_SECONDS` |
| Idle transaction | Session `idle_in_transaction_session_timeout` | 60s | `TRR_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS` |
| Frontend social proxy | AbortController | 10/25/60s | `TRR_SOCIAL_PROXY_*_TIMEOUT_MS` |

**Note:** Existing `SET LOCAL statement_timeout = '5000'` in `social_season_analytics.py` correctly overrides the 30s session default for those specific fast queries.
