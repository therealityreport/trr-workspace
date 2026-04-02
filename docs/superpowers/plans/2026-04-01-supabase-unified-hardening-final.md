# Final Plan — Runtime DB Contract Cleanup, Timeout Hardening, and Local Flashback Stabilization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

- Execute this as one coordinated cross-repo change in workspace order: `TRR-Backend` first, `screenalytics` second, `TRR-APP` last — with a narrow TRR-APP local-only fix allowed first because it does not change the shared Postgres runtime contract.
- The must-do outcome is:
  - persistent runtimes across all three repos accept only `TRR_DB_URL` with optional `TRR_DB_FALLBACK_URL`
  - persistent runtimes reject transaction-pooler `:6543` and direct-host Supabase DSNs; only `session` and `local` lanes are valid
  - backend gains fast-fail DB connection timeouts, default Postgres statement timeouts, DB-aware health/readiness/liveness, and request timeout protection without breaking streams or intentional long-running routes
  - TRR-APP gains node-postgres timeout hardening (`connectionTimeoutMillis`, `statement_timeout`, `query_timeout`, `idle_in_transaction_session_timeout`, pool error handling) in addition to proxy timeout tightening
  - TRR-APP keeps Firebase-primary/Supabase-fallback auth as-is, while restoring the local browser-side Supabase contract needed for Flashback
- Treat `DATABASE_URL`, deprecated `SUPABASE_DB_URL`, derived direct fallback, and `supabase status` discovery as tooling-only behavior, never persistent runtime behavior.

**Tech Stack:** Python 3.11 / FastAPI / psycopg2 / httpx (TRR-Backend), Python 3.11 / PyTorch (screenalytics), TypeScript / Next.js / node-postgres / Supabase JS (TRR-APP), Supabase Postgres 17, Supavisor session-mode pooling.

---

## What this plan does

- Fixes the **local TRR-APP Flashback/browser Supabase config break** without reopening deprecated runtime DB paths.
- Standardizes the **shared runtime DB contract** across persistent services.
- Adds **layered timeout protection** at the HTTP, DB-connect, DB-statement, and app-client layers — both backend (psycopg2) and frontend (node-postgres).
- Makes health checks **deployment-meaningful** with readiness/liveness separation.
- Preserves **Firebase-primary / Supabase-fallback auth**.
- Keeps **screenalytics pooling out of scope** for this pass.
- Avoids breaking legitimate **SSE / streaming** traffic.

---

## Resolved conflicts from prior drafts

1. **Sequencing:** Shared runtime contract cleanup follows Backend → screenalytics → TRR-APP. A narrow TRR-APP local/browser-only fix is allowed first because it does not change the shared Postgres runtime contract.

2. **Request timeout vs SSE:** Do not apply a blanket wall-clock timeout to long-lived streams. Add explicit streaming/SSE exemptions or route opt-outs. Build a route inventory before rollout.

3. **`/health` semantics:** Make `/health` the real readiness endpoint. Add `/health/live` as a process-only liveness endpoint.

4. **Direct fallback flag naming:** Standardize on `TRR_DB_ENABLE_DIRECT_FALLBACK`. In this pass, it is tooling-only, not a normal persistent-runtime path.

5. **Local Supabase browser config:** Fix `apps/web/.env.local` locally. Do not commit secrets or add browser fallback to server-only envs.

6. **Invalid primary handling:** Do not silently skip an invalid primary runtime candidate to a fallback; surface operator drift immediately.

7. **Middleware pattern:** Use pure ASGI middleware for request timeouts, not `BaseHTTPMiddleware`, due to Starlette's documented limitations.

---

## End-state contracts

### Runtime DB contract for persistent services

| Contract                                   | Status                                           |
| ------------------------------------------ | ------------------------------------------------ |
| `TRR_DB_URL`                               | Primary runtime DB source                        |
| `TRR_DB_FALLBACK_URL`                      | Only accepted explicit runtime fallback          |
| `TRR_DB_ENABLE_DIRECT_FALLBACK`            | Standardized name, **tooling-only in this pass** |
| `SUPABASE_DB_URL`                          | Removed from runtime resolution                  |
| runtime `DATABASE_URL`                     | Removed from runtime resolution                  |
| `POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK` | Removed entirely                                 |
| `POSTGRES_ENABLE_DIRECT_FALLBACK`          | Removed entirely                                 |

### Allowed connection lanes

| Lane                                          | Runtime policy                                |
| --------------------------------------------- | --------------------------------------------- |
| Supavisor session mode `:5432`                | Allowed                                       |
| Repo-configured local Supabase session pooler | Allowed                                       |
| Supavisor transaction mode `:6543`            | Rejected for persistent runtime               |
| Direct-host Supabase DSN                      | Rejected by default for persistent runtime    |
| Tooling / migrations / break-glass scripts    | May use direct lane via tooling resolver only |

This policy is the backbone for the timeout work because session-level Postgres timeout controls (`statement_timeout`, `idle_in_transaction_session_timeout`) are compatible with the allowed session lane and not with transaction mode.

### Browser Supabase contract

| Contract                             | Purpose                   |
| ------------------------------------ | ------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`           | Browser client URL        |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY`      | Browser anon key          |
| `TRR_CORE_SUPABASE_URL`              | Server/admin surface only |
| `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | Server/admin surface only |

No browser fallback to server-only envs.

### Default timeout budget

Keep a **layered** budget, not equal budgets:

| Layer                           | Default         |
| ------------------------------- | --------------- |
| DB connect timeout              | 10s             |
| DB statement timeout            | 30s             |
| DB query/client timeout (Node)  | 35s             |
| Backend request timeout         | 35s             |
| Health DB probe                 | 3–5s            |
| Social proxy short/default/long | 10s / 25s / 60s |

Rule: **connect < statement < query/request < platform limit**.

### New backend timeout envs

| Env Var | Default | Purpose |
|---------|---------|---------|
| `TRR_REQUEST_TIMEOUT_SECONDS` | 35 | Wall-clock HTTP request timeout |
| `TRR_DB_CONNECT_TIMEOUT_SECONDS` | 10 | TCP connect timeout for psycopg2 |
| `TRR_DB_STATEMENT_TIMEOUT_MS` | 30000 | Default Postgres statement timeout |
| `TRR_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS` | 60000 | Existing, unchanged |

---

## Implementation order

---

## Phase 0 — TRR-APP local browser Supabase fix

**Objective:** Unblock local Flashback and browser Supabase usage without changing the shared Postgres runtime contract.

**Files**

- `TRR-APP/apps/web/.env.local` **(local only, untracked)**
- `TRR-APP/apps/web/src/lib/supabase/client.ts`
- `TRR-APP/apps/web/src/lib/flashback/supabase.ts`
- `TRR-APP/apps/web/src/lib/flashback/manager.ts`
- `TRR-APP/apps/web/tests/flashback-supabase.test.ts` or equivalent
- `TRR-APP/apps/web/tests/supabase-client.test.ts`
- `TRR-APP/apps/web/tests/supabase-client-env.test.ts`
- `TRR-APP/scripts/dev-workspace.sh` or the existing local startup helper
- app env example / setup docs

- [ ] Add a focused regression test proving Flashback bootstrap fails with the current user-facing configuration error when `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` are missing.
- [ ] Add a focused success-path test proving the browser Supabase client is created when both public envs are present.
- [ ] Restore the local browser env contract in **local** `apps/web/.env.local` using the **same project** as `TRR_CORE_SUPABASE_URL`.
- [ ] Keep `TRR_AUTH_PROVIDER` on the current Firebase-primary / Supabase-fallback path.
- [ ] Add a **dev-only fail-fast guard** in startup validation or an internal diagnostics helper that reports missing `NEXT_PUBLIC_SUPABASE_*` clearly, without exposing secret values.
- [ ] Update the local dev helper script to **validate** the browser contract; do not silently fall back from server-only envs.
- [ ] Update the app's env example / setup docs to document the browser contract explicitly.
- [ ] Manually verify `/flashback/cover` and `/flashback/play` locally after sign-in.

**Acceptance**

- Local Flashback no longer fails with "Supabase is not configured".
- No auth-provider cutover.
- No runtime DB contract broadening.

---

## Phase 1 — Inventory, workflow, and safety gates

**Objective:** Gather the information needed to implement timeout enforcement safely, and run the workspace handoff lifecycle.

- [ ] Run the required workspace handoff lifecycle before code changes: `pre-plan`, then `post-phase` after each repo phase, then `closeout`.
- [ ] Update the canonical status source after each material phase.
- [ ] Build a backend route inventory before implementing request timeout enforcement:
  - normal JSON routes using default timeout
  - SSE/stream routes that must opt out
  - known long-running admin routes that need explicit higher timeout budgets
- [ ] Build a runtime env inventory for active deploy surfaces and checked-in examples so code, docs, and env contracts change together.
- [ ] Do not execute the backend request-timeout rollout until the route inventory and exemptions/overrides are defined.

---

## Phase 2 — TRR-Backend runtime contract enforcement

**Objective:** Make backend runtime DB resolution accept only the canonical shared contract and fail fast on invalid runtime lanes.

**Files**

- `TRR-Backend/trr_backend/db/connection.py`
- `TRR-Backend/api/main.py`
- `TRR-Backend/trr_backend/db/preflight.py`
- `TRR-Backend/scripts/_db_url.py`
- `TRR-Backend/scripts/db/run_sql.sh`
- `TRR-Backend/scripts/verify/verify_media_unification.py`
- `TRR-Backend/scripts/ops/cast_screentime_stale_run_drill.py`
- backend env examples / docs
- backend tests covering resolution and startup validation

- [ ] Add failing backend tests that prove runtime resolution ignores:
  - `SUPABASE_DB_URL`
  - runtime `DATABASE_URL`
  - local `supabase status --output env`

- [ ] Centralize DB URL classification in backend runtime code:
  - source: `TRR_DB_URL` → `TRR_DB_FALLBACK_URL`
  - connection class: `session`, `local_session`, `transaction`, `direct`, `unknown`
  - winner source for logs / diagnostics

- [ ] Remove all legacy runtime candidate reads from `trr_backend/db/connection.py`.

- [ ] Add startup validation in `api/main.py` that **hard-fails** when runtime resolves to:
  - transaction lane
  - direct host lane
  - unknown lane

- [ ] Do not silently skip an invalid primary runtime candidate to a fallback; surface operator drift immediately.

- [ ] Log structured startup fields:
  - `winner_source`
  - `connection_class`
  - `is_local`

- [ ] Keep legacy env support and `supabase status` discovery only in tooling helpers, centered on `scripts/_db_url.py`.

- [ ] Standardize tooling override naming to `TRR_DB_ENABLE_DIRECT_FALLBACK`.

- [ ] Keep `trr_backend/db/preflight.py` tooling-oriented: it may still allow `DATABASE_URL` for migrations or `psql` flows, but its wording must clearly say runtime paths do not use it.

- [ ] Fix remaining helper drift in verification / ops scripts so tooling messages consistently advertise `TRR_DB_URL` and `TRR_DB_FALLBACK_URL`.

- [ ] Update backend docs and `.env.example` to remove deprecated runtime paths.

**Transitional rule**

- Deployed / persistent runtime must hard-fail immediately on remote transaction/direct lanes.
- Local direct runtime may warn only during the brief migration window until the local session pooler task lands.
- After Phase 4, local direct should hard-fail too.

**Acceptance**

- Backend runtime only accepts canonical envs.
- Backend startup logs the winning source and connection class.
- Legacy env names no longer influence service boot.

---

## Phase 3 — TRR-Backend timeout hardening and health/readiness

**Objective:** Eliminate backend hang paths and make health checks meaningful.

**Files**

- `TRR-Backend/trr_backend/middleware/__init__.py`
- `TRR-Backend/trr_backend/middleware/request_timeout.py`
- `TRR-Backend/trr_backend/db/pg.py`
- `TRR-Backend/trr_backend/db/admin.py`
- `TRR-Backend/api/main.py`
- `TRR-Backend/.env.example`
- `TRR-Backend/tests/middleware/test_request_timeout.py`
- `TRR-Backend/tests/db/test_pg_timeout_settings.py`
- `TRR-Backend/tests/api/test_health_check.py`
- updates to existing DB pool tests

### 3A. Request timeout middleware

- [ ] Add request-timeout middleware as **pure ASGI middleware**, not `BaseHTTPMiddleware`.
- [ ] Default to `TRR_REQUEST_TIMEOUT_SECONDS=35`.
- [ ] Require a positive value; do not document "0 disables" unless code intentionally supports that mode.
- [ ] Exempt (based on Phase 1 route inventory):
  - `/`
  - `/metrics`
  - `/health`
  - `/health/live`
  - known SSE / streaming routes from the inventory
- [ ] Add a route-level decorator or dependency-injection escape hatch for legitimate long-lived operations (prefer `Depends(timeout_override(seconds=120))` setting `request.state.timeout_seconds` for idiomatic FastAPI).
- [ ] Mount it before CORS so it wraps the full request lifecycle.
- [ ] Return request-timeout failures using the backend error envelope with HTTP `504`, `detail.code="REQUEST_TIMEOUT"`, `retryable=true`, and normal trace headers.
- [ ] Add structured timeout logs containing request path, method, timeout, and request ID if available.

### 3B. Backend Postgres timeout hardening

- [ ] Add `connect_timeout` to the psycopg2 pool builder with default `10` (top-level DSN kwarg, not in options).
- [ ] Keep `idle_in_transaction_session_timeout` in session options (default `60000`).
- [ ] Add default `statement_timeout` in session options with default `30000`.
- [ ] Use correct multi-option libpq syntax: `-c idle_in_transaction_session_timeout=60000 -c statement_timeout=30000`.
- [ ] Add tests that capture pool kwargs and assert:
  - `connect_timeout` is a top-level kwarg
  - `statement_timeout` appears in `options`
  - `idle_in_transaction_session_timeout` still appears in `options`
- [ ] Update existing pool tests that assumed the older single-option format.
- [ ] Preserve endpoint-level `SET LOCAL statement_timeout` overrides for exceptional long or short queries (e.g., `social_season_analytics.py`'s `SET LOCAL statement_timeout = '5000'`).

### 3C. Distinct timeout observability

- [ ] Add `_is_statement_timeout_error(...)` in `pg.py`.
- [ ] Do **not** classify statement timeouts as transient retryable transport errors.
- [ ] Log statement timeouts distinctly in DB connection context managers (`db_connection`, `db_read_connection`).
- [ ] Keep connection-return / discard logic intact when a timeout leaves a connection in a bad state.

### 3D. Readiness and liveness

- [ ] Convert `/health` into a real **readiness** endpoint that checks DB reachability.
- [ ] Add `/health/live` as a **liveness** endpoint (process-only, no DB check).
- [ ] The readiness DB probe must use a **shorter dedicated budget** (3–5s) than the default statement timeout, so health never waits the full 30s query window.
- [ ] Return:
  - `200` + `{ status: "ok", service: "trr-backend", database: "connected" }` when ready
  - `503` + `{ status: "degraded", service: "trr-backend", database: "unreachable" }` when DB is unavailable
- [ ] Add tests for:
  - readiness success
  - readiness degraded
  - liveness success regardless of DB

### 3E. Outbound HTTP timeout audit

- [ ] Review `trr_backend/db/admin.py` and any other backend `httpx` clients.
- [ ] Ensure each has explicit timeouts shorter than the outer request timeout.
- [ ] Log timeout failures distinctly from generic transport errors.

**Acceptance**

- No backend request can hang indefinitely.
- DB connection attempts fail fast.
- Runaway DB statements are bounded.
- Health endpoints reflect real service readiness.
- Liveness endpoint works even when DB is down.

---

## Phase 4 — Local Supabase pooler parity

**Objective:** Make local development exercise the same session-pooler behavior expected in runtime.

**Files**

- `TRR-Backend/supabase/config.toml`
- local setup docs / scripts
- backend startup validation tests if local-lane rules change

- [ ] Enable the local Supabase pooler in `supabase/config.toml`.
- [ ] Set local pooler mode to **session**.
- [ ] Use local pool sizes appropriate for dev (`default_pool_size=10`, `max_client_conn=50`).
- [ ] Verify `supabase start` exposes the local session pooler lane successfully.
- [ ] Update local docs so developer runtime DSNs use the **local session pooler**, not transaction mode.
- [ ] After this lands, tighten local runtime validation from "warn on local direct" to "hard-fail on local direct".

**Acceptance**

- Local runtime exercises pooling behavior.
- Dev/prod parity improves.
- Local direct DSNs are no longer the default expectation.

---

## Phase 5 — screenalytics contract cleanup and lane enforcement

**Objective:** Align screenalytics with the shared runtime contract, messaging, and lane policy — without introducing pooling.

**Files**

- `screenalytics` runtime startup/env resolution
- `screenalytics/scripts/migrate_legacy_db_to_supabase.py`
- screenalytics tests for messaging / precedence / lane validation

- [ ] Keep screenalytics runtime precedence aligned with the canonical contract (`TRR_DB_URL` → `TRR_DB_FALLBACK_URL`).
- [ ] Upgrade screenalytics from warning-only to the same persistent-runtime lane policy as backend:
  - allowed: `session`, `local`
  - rejected in deployed runtime: `transaction`, `direct`
- [ ] Fail fast in startup validation for invalid deployed runtime lanes; local/dev may still use `local`.
- [ ] Update startup and error messaging so it consistently references `TRR_DB_URL` and `TRR_DB_FALLBACK_URL` and documents session-mode `:5432` as the expected runtime lane.
- [ ] Remove remaining deprecated alias handling from tooling-only code, especially `scripts/migrate_legacy_db_to_supabase.py` (`TRR_DB_URL_ALIAS = "SUPABASE_DB_URL"`).
- [ ] Do **not** add connection pooling or statement timeout management in this pass.
- [ ] Add or update tests to prevent legacy alias regression and validate lane enforcement.

**Acceptance**

- screenalytics uses the shared naming contract.
- screenalytics rejects invalid deployed runtime lanes.
- No new pooling surface is introduced.

---

## Phase 6 — TRR-APP runtime contract cleanup and app-side DB hardening

**Objective:** Finish app runtime contract cleanup and eliminate app-side Postgres hang paths.

**Files**

- `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`
- `TRR-APP/apps/web/src/lib/server/sse-proxy.ts`
- SSE callers
- app env examples / diagnostics
- `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- targeted timeout / proxy tests as needed

### 6A. Runtime DB contract cleanup

- [ ] Add failing Vitest coverage proving only `TRR_DB_URL` and `TRR_DB_FALLBACK_URL` are accepted in runtime resolution.
- [ ] Remove runtime recognition of:
  - `POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK`
  - `POSTGRES_ENABLE_DIRECT_FALLBACK`
  - runtime `DATABASE_URL`
- [ ] Do not replace those flags with a runtime `TRR_DB_ENABLE_DIRECT_FALLBACK` path in the app; persistent app runtime should not derive or select direct-host fallbacks at all. Keep `TRR_DB_ENABLE_DIRECT_FALLBACK` in tooling-compatible code paths only.
- [ ] Reject transaction-lane runtime URLs.
- [ ] Reject direct-host runtime URLs by default.
- [ ] Emit startup/diagnostic metadata mirroring backend:
  - `winner_source`
  - `connection_class`

### 6B. Node Postgres hardening in `postgres.ts`

node-postgres supports the necessary controls natively — use them directly rather than relying only on proxy timeouts.

- [ ] Add `connectionTimeoutMillis` with a fast-fail default (e.g., 10000).
- [ ] Add default query/statement/idle-in-transaction safeguards:
  - `statement_timeout` (e.g., 30000)
  - `query_timeout` (e.g., 35000)
  - `idle_in_transaction_session_timeout` (e.g., 60000)
- [ ] Use pool config and/or `onConnect` consistently with the existing abstraction.
- [ ] Add a `pool.on("error", ...)` listener so idle-client failures do not surface as uncaught runtime crashes.
- [ ] Add tests covering:
  - timeout config is applied
  - invalid runtime lanes are rejected
  - legacy envs no longer participate in resolution

### 6C. Social proxy and SSE

- [ ] Tighten social admin proxy defaults to:
  - short: `10_000`
  - default: `25_000`
  - long: `60_000`
- [ ] Update all sources of truth together:
  - `social-admin-proxy.ts`
  - `apps/web/.env.example`
  - workspace `scripts/dev-workspace.sh`
  - include `TRR_SOCIAL_PROXY_LONG_TIMEOUT_MS` wherever defaults are documented or exported
- [ ] Update both app proxy layers to understand the backend timeout contract:
  - `social-admin-proxy.ts`
  - `admin-read-proxy.ts`
- [ ] Backend-generated `504 REQUEST_TIMEOUT` responses must normalize to retryable timeout handling rather than opaque upstream failures.
- [ ] Audit SSE / streaming callers.
- [ ] Do **not** add a blanket overall timeout to legitimate long-lived SSE streams.
- [ ] For finite admin/ops SSE flows, require explicit caller-provided `timeoutMs`.
- [ ] Add tests or targeted assertions for any changed callers.

### 6D. Browser contract diagnostics

- [ ] Keep the browser Supabase contract explicit.
- [ ] Extend an existing admin-only/internal diagnostics surface, if useful, to report only **presence/absence** of `NEXT_PUBLIC_SUPABASE_*`.
- [ ] Do not expose secret values.
- [ ] Do not add a new public diagnostics route solely for this.

**Acceptance**

- TRR-APP runtime DB resolution matches backend policy.
- App DB calls cannot hang indefinitely on connect or query.
- Social proxy defaults are tighter.
- Backend `504 REQUEST_TIMEOUT` is handled as retryable in both proxy layers.
- Flashback/browser client remains on the explicit public-env contract.

---

## Phase 7 — Docs, deploy surfaces, and cross-repo verification

**Objective:** Remove operator ambiguity and verify the new contract end-to-end.

**Files**

- active `.env.example` files
- setup docs
- deploy docs / runbooks
- status pages / diagnostics docs
- any active operator notes still referencing deprecated runtime paths

- [ ] Audit all active deploy surfaces so persistent services expose only:
  - `TRR_DB_URL`
  - `TRR_DB_FALLBACK_URL`

- [ ] Remove active documentation that presents:
  - `SUPABASE_DB_URL`
  - runtime `DATABASE_URL`
  - `:6543` as a normal persistent runtime lane

- [ ] Document the local browser Supabase requirement for Flashback.

- [ ] Leave archived evidence/handoffs alone unless still used operationally.

- [ ] Add one cross-repo smoke checklist confirming each persistent service reports:
  - `winner_source=TRR_DB_URL` or `TRR_DB_FALLBACK_URL`
  - `connection_class=session` or local session equivalent

- [ ] Confirm timeout events are visible in logs/observability.

- [ ] Close the session with updated status docs and handoff workflow artifacts for all touched repos.

---

## Test plan

### Targeted tests

**TRR-Backend**

- request-timeout middleware tests (pure ASGI)
- route-level timeout override/opt-out tests
- DB pool timeout config tests (connect_timeout, statement_timeout, idle_in_transaction)
- health readiness/liveness tests (including dedicated health probe budget)
- runtime DB resolution / lane validation tests
- startup fail-fast tests for invalid lanes
- existing DB pool tests updated for multi-option syntax
- statement-timeout detection tests (not classified as transient)
- outbound HTTP timeout coverage

**screenalytics**

- canonical env precedence tests
- startup rejects invalid deployed runtime lanes
- updated startup/error messaging tests
- no legacy alias regression

**TRR-APP**

- browser Supabase client present/missing env tests
- Flashback bootstrap failure/success tests
- server auth adapter regression tests
- Postgres runtime resolution tests (only canonical envs accepted)
- Postgres timeout config tests (connectionTimeoutMillis, statement_timeout, query_timeout)
- pool error handler tests
- transaction/direct runtime DSN rejection tests
- social proxy timeout default tests
- backend `504 REQUEST_TIMEOUT` retryable handling in both proxy layers

### Repo validations

- `TRR-Backend`: `ruff check . && ruff format --check . && pytest -q`
- `screenalytics`: `pytest -q`
- `TRR-APP`: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`
- Local Supabase parity: `supabase stop && supabase start` in `TRR-Backend`, verify session pooler starts on configured local port

### Manual smoke checklist

- [ ] Backend startup rejects invalid runtime DSNs.
- [ ] Backend startup logs canonical winner source and session-class lane.
- [ ] `/health/live` returns 200 when process is up.
- [ ] `/health` returns 200 when DB is reachable and 503 when it is not.
- [ ] Health probe completes within 3–5s even when DB is slow.
- [ ] A forced slow backend request returns a structured 504.
- [ ] A forced long DB statement hits the statement-timeout path and logs distinctly.
- [ ] Route-level timeout override works for at least one long-running admin route.
- [ ] At least one SSE/stream route still functions without timeout interruption.
- [ ] Local Flashback loads once public Supabase envs are restored.
- [ ] Representative app pages that use Postgres still load normally.
- [ ] Social admin flows still work under the tighter 10/25/60s proxy defaults.

---

## Explicit non-goals

- No Firebase → Supabase auth cutover.
- No screenalytics pooling rollout.
- No new public diagnostics route.
- No direct-host runtime support for persistent services in this pass.
- No transaction-mode `:6543` runtime allowance for persistent services.
- No schema/RLS/backend migration changes unless a new failing probe proves they are required.
- No blanket SSE kill-switch via request middleware.
- No global SSE timeout rollout.

---

## Assumptions, defaults, and deferred work

- This remains a coordinated multi-repo change and must follow the workspace handoff workflow, including status updates after each material phase.
- Default backend request timeout is `35s` for normal endpoints; long-running and streaming routes must be explicitly classified in Phase 1 before rollout.
- Default backend Postgres hardening values are `connect_timeout=10s`, `statement_timeout=30000ms`, and unchanged `idle_in_transaction_session_timeout=60000ms`.
- Default node-postgres hardening values are `connectionTimeoutMillis=10000`, `statement_timeout=30000`, `query_timeout=35000`, `idle_in_transaction_session_timeout=60000`.
- Social proxy defaults become `10s / 25s / 60s`, and workspace startup defaults must match code or the change is incomplete.
- Flashback stabilization is intentionally local-first; the `.env.local` fix is operational and must not introduce committed secrets.
- Any future direct-host runtime fallback support is deferred to a separate, explicit plan.

---

## Recommended PR/commit slicing

1. **TRR-APP local/browser fix only** (Phase 0)
2. **TRR-Backend runtime contract enforcement** (Phase 2)
3. **TRR-Backend timeout hardening + health** (Phase 3)
4. **Local Supabase pooler parity** (Phase 4)
5. **screenalytics contract cleanup + lane enforcement** (Phase 5)
6. **TRR-APP runtime contract cleanup + DB hardening + proxy tightening** (Phase 6)
7. **Docs/deploy cleanup + smoke checklist** (Phase 7)

This keeps the local unblock small, ships the shared runtime contract before app/server hardening depends on it, and avoids mixing browser-env repair with cross-repo DB policy changes.
