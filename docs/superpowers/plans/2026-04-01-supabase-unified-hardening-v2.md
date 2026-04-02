# Revised Plan — Runtime DB Contract Cleanup, Timeout Hardening, and Local Flashback Stabilization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary
- Execute this as one coordinated cross-repo change in workspace order: `TRR-Backend` first, `screenalytics` second, `TRR-APP` last.
- The must-do outcome is:
  - persistent runtimes across all three repos accept only `TRR_DB_URL` with optional `TRR_DB_FALLBACK_URL`
  - persistent runtimes reject transaction-pooler `:6543` and direct-host Supabase DSNs; only `session` and `local` lanes are valid
  - backend gains fast-fail DB connection timeouts, default Postgres statement timeouts, DB-aware health, and request timeout protection without breaking streams or intentional long-running routes
  - TRR-APP keeps Firebase-primary/Supabase-fallback auth as-is, while restoring the local browser-side Supabase contract needed for Flashback
- Treat `DATABASE_URL`, deprecated `SUPABASE_DB_URL`, derived direct fallback, and `supabase status` discovery as tooling-only behavior, never persistent runtime behavior.

**Tech Stack:** Python 3.11 / FastAPI / psycopg2 / httpx (TRR-Backend), Python 3.11 / PyTorch (screenalytics), TypeScript / Next.js / node-postgres / Supabase JS (TRR-APP), Supabase Postgres 17, Supavisor session-mode pooling.

---

## Phased Implementation

### Phase 0 — Inventory, workflow, and safety gates

- Run the required workspace handoff lifecycle before code changes: `pre-plan`, then `post-phase` after each repo phase, then `closeout`.
- Update the canonical status source after each material phase.
- Build a backend route inventory before implementing request timeout enforcement:
  - normal JSON routes using default timeout
  - SSE/stream routes that must opt out
  - known long-running admin routes that need explicit higher timeout budgets
- Build a runtime env inventory for active deploy surfaces and checked-in examples so code, docs, and env contracts change together.
- Do not execute the backend request-timeout rollout until the route inventory and exemptions/overrides are defined.

---

### Phase 1 — `TRR-Backend`

- Refactor `trr_backend/db/connection.py` so runtime candidate resolution uses only `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`.
- Remove runtime support for `SUPABASE_DB_URL`, runtime `DATABASE_URL`, derived direct-host fallback, and local `supabase status` discovery from backend service resolution.
- Tighten `api/main.py` startup validation from warning-only to fail-fast when the runtime winner is:
  - a legacy runtime env
  - `transaction` on `pooler.supabase.com:6543`
  - `direct` on `db.<project>.supabase.co`
- Do not silently skip an invalid primary runtime candidate to a fallback; surface operator drift immediately.
- Keep tooling-only compatibility in backend helpers such as `scripts/_db_url.py`, `scripts/db/run_sql.sh`, and other explicit CLI/migration utilities.
- Keep `trr_backend/db/preflight.py` tooling-oriented: it may still allow `DATABASE_URL` for migrations or `psql` flows, but its wording must clearly say runtime paths do not use it.
- Add psycopg2 pool hardening in `trr_backend/db/pg.py`:
  - `connect_timeout=10`
  - `idle_in_transaction_session_timeout=60000`
  - `statement_timeout=30000`
  - multi-`-c` libpq options formatting
- Keep session-level `statement_timeout` as the default guard, then audit existing backend code that already uses `SET LOCAL statement_timeout` and preserve those targeted overrides.
- Add explicit statement-timeout detection/logging, but do not mark it as a transient transport error.
- Add request timeout support with route metadata or decorators, not path-only exemptions.
- Apply default `TRR_REQUEST_TIMEOUT_SECONDS=30` only to standard request/response endpoints.
- Explicitly opt out SSE/stream endpoints and explicitly mark known long-running admin operations with a larger timeout or opt-out.
- Return request-timeout failures using the backend error envelope with HTTP `504`, `detail.code="REQUEST_TIMEOUT"`, `retryable=true`, and normal trace headers.
- Replace `/health` with a DB-backed lightweight probe through the real pool:
  - healthy: `200` with additive fields including `status`, `service`, `database="connected"`
  - degraded: `503` with additive fields including `status="degraded"`, `database="unreachable"`
- Keep `/metrics` unchanged.
- Enable the local Supabase pooler in `supabase/config.toml` using `session` mode and smaller local sizing.
- Verify local Supabase still starts cleanly with the pooler enabled before moving to downstream repos.
- Update backend checked-in env examples, active docs, and runbooks so they reflect:
  - canonical runtime envs only
  - session-mode `:5432` as the default runtime lane
  - conservative pool defaults
  - `TRR_DB_ENABLE_DIRECT_FALLBACK` no longer advertised as a runtime feature

---

### Phase 2 — `screenalytics`

- Keep runtime precedence `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`; do not add pooling or broader timeout hardening in this pass.
- Upgrade `screenalytics` from warning-only to the same persistent-runtime lane policy as backend:
  - allowed: `session`, `local`
  - rejected in deployed runtime: `transaction`, `direct`
- Fail fast in startup validation for invalid deployed runtime lanes; local/dev may still use `local`.
- Keep the existing small `connect_timeout` behavior; do not add statement timeout or pool management here.
- Remove the remaining deprecated alias support from tooling-only code, especially `scripts/migrate_legacy_db_to_supabase.py`.
- Align startup, health, and operator-facing messaging so they consistently reference `TRR_DB_URL` and `TRR_DB_FALLBACK_URL` and document session-mode `:5432` as the expected runtime lane.
- Update tests so screenalytics contract enforcement matches backend/app policy.

---

### Phase 3 — `TRR-APP`

- Refactor `apps/web/src/lib/server/postgres.ts` so runtime resolution accepts only `TRR_DB_URL` and `TRR_DB_FALLBACK_URL`.
- Remove runtime support for `POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK` and `POSTGRES_ENABLE_DIRECT_FALLBACK`.
- Do not replace those flags with a runtime `TRR_DB_ENABLE_DIRECT_FALLBACK` path in the app; persistent app runtime should not derive or select direct-host fallbacks at all.
- Enforce the same persistent runtime lane policy as backend and screenalytics:
  - allowed: `session`, `local`
  - rejected: `transaction`, `direct`
- Keep `DATABASE_URL` as a tooling adapter only for scripts that require that exact name, and document `DATABASE_URL="$TRR_DB_URL"` instead of treating it as runtime input.
- Lower social proxy defaults to `10_000 / 25_000 / 60_000`.
- Update all sources of truth together:
  - `social-admin-proxy.ts`
  - `apps/web/.env.example`
  - workspace `scripts/dev-workspace.sh`
  - include `TRR_SOCIAL_PROXY_LONG_TIMEOUT_MS` wherever defaults are documented or exported
- Do not add a global SSE stream timeout.
- Preserve current long-lived stream behavior and existing health-preflight patterns.
- Audit stream callers only to confirm explicit `timeoutMs` is already passed where required.
- Update both app proxy layers to understand the backend timeout contract:
  - `social-admin-proxy.ts`
  - `admin-read-proxy.ts`
- Backend-generated `504 REQUEST_TIMEOUT` responses must normalize to retryable timeout handling rather than opaque upstream failures.

---

### Phase 4 — Local Flashback stabilization

- Keep `TRR_AUTH_PROVIDER=firebase` as the default and preserve the existing Firebase-primary/Supabase-fallback auth adapter.
- Do not add browser fallback to server-only Supabase envs.
- Treat the current Flashback issue as local browser-env drift:
  - restore `NEXT_PUBLIC_SUPABASE_URL`
  - restore `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - keep them pointed at the same Supabase project already used by `TRR_CORE_SUPABASE_URL`
- Treat the `.env.local` fix as an operational local step, not a checked-in secret change.
- Add a local dev guard outside the browser client, preferably in `scripts/dev-workspace.sh` and optionally an existing internal/admin diagnostics surface, that warns clearly when `NEXT_PUBLIC_SUPABASE_*` is missing.
- The guard must be secret-free and must not auto-copy service-role credentials into browser envs.
- Do not change Flashback to use server-only admin credentials and do not introduce a second Supabase project.

---

### Phase 5 — Docs, deploy surfaces, and closeout

- Audit active deploy/env surfaces so persistent services expose only canonical runtime envs and valid session-mode DSNs.
- Remove active documentation that still treats `SUPABASE_DB_URL`, runtime `DATABASE_URL`, or `:6543` as a normal persistent-service path.
- Leave archived evidence and historical handoffs unchanged unless an active runbook still points to them.
- Close the session with updated status docs and handoff workflow artifacts for all touched repos.

---

## Public Interfaces / Contracts

- Persistent runtime DB contract: `TRR_DB_URL` primary, `TRR_DB_FALLBACK_URL` explicit secondary.
- Tooling-only compatibility surface: `DATABASE_URL`, deprecated `SUPABASE_DB_URL`, local `supabase status`, and optional `TRR_DB_ENABLE_DIRECT_FALLBACK`.
- Allowed persistent runtime connection classes: `session` on `pooler.supabase.com:5432` and `local`.
- Rejected persistent runtime connection classes: `transaction` on `:6543` and direct-host Supabase DSNs.
- New backend timeout envs:
  - `TRR_REQUEST_TIMEOUT_SECONDS`
  - `TRR_DB_CONNECT_TIMEOUT_SECONDS`
  - `TRR_DB_STATEMENT_TIMEOUT_MS`
- Existing idle-in-transaction env remains valid: `TRR_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS`.
- Backend timeout responses standardize on HTTP `504` with backend error envelope and `REQUEST_TIMEOUT`.
- Backend `/health` becomes DB-aware but remains additive and compatible for callers that only care about `200` vs `503`.
- Browser Supabase contract remains `NEXT_PUBLIC_SUPABASE_URL` plus `NEXT_PUBLIC_SUPABASE_ANON_KEY` only.

---

## Env Contract After This Plan

| Env Var | Scope | Status |
|---------|-------|--------|
| `TRR_DB_URL` | All repos, runtime | **Canonical** |
| `TRR_DB_FALLBACK_URL` | All repos, runtime | **Explicit secondary** |
| `TRR_REQUEST_TIMEOUT_SECONDS` | Backend | **New** (default: 30) |
| `TRR_DB_CONNECT_TIMEOUT_SECONDS` | Backend | **New** (default: 10) |
| `TRR_DB_STATEMENT_TIMEOUT_MS` | Backend | **New** (default: 30000) |
| `TRR_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS` | Backend | **Existing** (default: 60000) |
| `NEXT_PUBLIC_SUPABASE_URL` | TRR-APP browser | **Required for Flashback** |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | TRR-APP browser | **Required for Flashback** |
| `SUPABASE_DB_URL` | ~~Runtime~~ | **Removed from runtime** (tooling-only) |
| `DATABASE_URL` | ~~Runtime~~ | **Removed from runtime** (tooling-only) |
| `POSTGRES_ENABLE_SUPABASE_DIRECT_FALLBACK` | ~~TRR-APP~~ | **Removed entirely** |
| `POSTGRES_ENABLE_DIRECT_FALLBACK` | ~~TRR-APP~~ | **Removed entirely** |
| `TRR_DB_ENABLE_DIRECT_FALLBACK` | ~~Runtime~~ | **Not added to app runtime** (tooling-only if needed) |

## Timeout Defense Layers (After This Plan)

| Layer | Guard | Default | Override |
|-------|-------|---------|----------|
| HTTP request | FastAPI middleware (route-metadata-aware) | 30s | `TRR_REQUEST_TIMEOUT_SECONDS` / per-route decorator |
| Postgres statement | Session `statement_timeout` | 30s | `TRR_DB_STATEMENT_TIMEOUT_MS` / `SET LOCAL` per-query |
| TCP connect | psycopg2 `connect_timeout` | 10s | `TRR_DB_CONNECT_TIMEOUT_SECONDS` |
| Idle transaction | Session `idle_in_transaction_session_timeout` | 60s | `TRR_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS` |
| Frontend social proxy | AbortController | 10/25/60s | `TRR_SOCIAL_PROXY_*_TIMEOUT_MS` |

**Note:** Existing `SET LOCAL statement_timeout = '5000'` in `social_season_analytics.py` correctly overrides the 30s session default for those specific fast queries.

## Allowed Runtime Lane Policy

| Connection Class | Port | Persistent Runtime | Tooling |
|-----------------|------|-------------------|---------|
| `session` | `:5432` (Supavisor) | **Allowed** | Allowed |
| `local` | varies | **Allowed** | Allowed |
| `transaction` | `:6543` | **Rejected (fail-fast)** | Allowed |
| `direct` | `db.<ref>.supabase.co` | **Rejected (fail-fast)** | Allowed |

---

## Test Plan / Acceptance Criteria

### Backend tests cover:
- [ ] runtime resolution ignores legacy envs and local `supabase status`
- [ ] startup rejects legacy, transaction, and direct runtime winners
- [ ] request timeout default behavior
- [ ] route metadata timeout opt-out / explicit override
- [ ] stream/SSE exemption
- [ ] `connect_timeout` propagation
- [ ] `statement_timeout` and idle-timeout option formatting
- [ ] `/health` healthy vs degraded behavior

### Backend regression tests verify:
- [ ] valid fallback candidates still work for transient connection failure
- [ ] statement-timeout failures log distinctly and do not enter transient retry classification
- [ ] existing `SET LOCAL statement_timeout` overrides still win
- [ ] at least one long-running admin route and one stream route still function

### Screenalytics tests cover:
- [ ] canonical precedence unchanged
- [ ] startup rejects invalid deployed runtime lanes
- [ ] updated startup/health messaging
- [ ] tooling-only removal of the deprecated alias in the migration helper

### App Vitest coverage covers:
- [ ] runtime connection resolution accepts only canonical envs
- [ ] transaction/direct runtime DSNs are rejected
- [ ] social proxy defaults are `10s / 25s / 60s`
- [ ] backend `504 REQUEST_TIMEOUT` maps to retryable timeout handling in both proxy layers
- [ ] browser Supabase client builds only when both `NEXT_PUBLIC_SUPABASE_*` vars exist
- [ ] Flashback bootstrap failure messaging when browser Supabase envs are missing
- [ ] auth adapter fallback and shadow-mode behavior remain unchanged

### Manual verification covers:
- [ ] backend `/health` with DB available and intentionally unavailable
- [ ] representative admin pages using Postgres still load
- [ ] at least one long-running admin stream route still works
- [ ] `/flashback/cover` and `/flashback/play` load locally without the configuration error after the local env contract is restored

### Repo validations after each repo phase:
- [ ] `TRR-Backend`: `ruff check . && ruff format --check . && pytest -q`
- [ ] `screenalytics`: `pytest -q`
- [ ] `TRR-APP`: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`
- [ ] Local Supabase parity: `supabase stop && supabase start` in `TRR-Backend`, verify session pooler starts on configured local port

---

## Assumptions, Defaults, and Deferred Work

- This remains a coordinated multi-repo change and must follow the workspace handoff workflow, including status updates after each material phase.
- Default backend request timeout is `30s` for normal endpoints; long-running and streaming routes must be explicitly classified before rollout.
- Default backend Postgres hardening values are `connect_timeout=10s`, `statement_timeout=30000ms`, and unchanged `idle_in_transaction_session_timeout=60000ms`.
- Social proxy defaults become `10s / 25s / 60s`, and workspace startup defaults must match code or the change is incomplete.
- Flashback stabilization is intentionally local-first; the `.env.local` fix is operational and must not introduce committed secrets.
- No auth-provider cutover, schema migration, RLS change, or screenalytics pooling rollout is part of this pass.
- No global SSE timeout rollout is part of this pass.
- Any future direct-host runtime fallback support is deferred to a separate, explicit plan.
