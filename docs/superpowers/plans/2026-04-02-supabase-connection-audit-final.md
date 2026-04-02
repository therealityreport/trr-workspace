# Final Supabase Connection Audit & Remaining Wiring Cleanup

**Date:** 2026-04-02
**Status:** Complete (audit-only — no code changes required)

## Repo State at Audit Time

| Repo | Branch | HEAD |
|------|--------|------|
| TRR-Backend | `feat/supabase-unified-hardening` | `e0a74c9` docs: remove stale TRR_DB_ENABLE_DIRECT_FALLBACK references |
| screenalytics | `feat/supabase-unified-hardening` | `ec9c764` fix: close transitional local lane grace period |
| TRR-APP | `feat/supabase-unified-hardening` | `7632151` fix: close local lane grace period |
| workspace root | `main` | `973da4e` fix: classify docs/superpowers/plans/ as historical |

---

## Primary Question Answered

> What Supabase/Postgres connections are still actually missing, miswired, deprecated, or drifting in live/runtime paths?

**None.** All runtime connection paths across all three repos are correctly canonicalized. The hardening work completed in the prior session closed every gap. What remains is one local-file cleanup (`.env.local` dead entries) and two intentionally dormant features (admin Supabase REST, Flashback browser client).

---

## Final Audit Matrix

### TRR-Backend (6 connection paths — all correct)

| # | File | Type | Env Vars | Runtime? | Status |
|---|------|------|----------|----------|--------|
| 1 | `trr_backend/db/connection.py` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** — canonical resolution, legacy vars explicitly rejected |
| 2 | `trr_backend/db/pg.py` | raw_postgres (pooled) | `TRR_DB_URL` + pool tuning vars | Runtime | **Correct** — ThreadedConnectionPool, 10s connect, 30s statement, 60s idle timeout |
| 3 | `api/main.py` startup | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** — rejects transaction/direct/unknown/other lanes in all environments |
| 4 | `api/main.py` /health | raw_postgres | (via pool) | Runtime | **Correct** — SET LOCAL statement_timeout = '3000' in transaction context |
| 5 | `trr_backend/security/jwt.py` | jwt_local_validation | `SUPABASE_JWT_SECRET` | Runtime | **Correct** — pure PyJWT verification, no network calls |
| 6 | `trr_backend/db/postgrest_cache.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** — non-pooled schema cache reload, uses canonical resolution |

**Tooling-only (not runtime):**
- `scripts/_db_url.py` — allows `DATABASE_URL` and deprecated `SUPABASE_DB_URL` behind explicit opt-in flags. Correct for tooling.
- `trr_backend/db/preflight.py` — migration safety checks, accepts `DATABASE_URL` as tooling fallback. Correct.
- `SUPABASE_SERVICE_ROLE_KEY` — referenced only in `scripts/ops/` smoke tests and `.env.example`. Not used by runtime API.

**Legacy env vars in runtime code:** Zero. `SUPABASE_DB_URL` and `DATABASE_URL` are explicitly tested-and-rejected.

### screenalytics (8 connection paths — all correct)

| # | File | Type | Env Vars | Runtime? | Status |
|---|------|------|----------|----------|--------|
| 1 | `apps/api/services/supabase_db.py` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** — canonical resolution + lane validation |
| 2 | `apps/api/services/trr_metadata_db.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** — read-only metadata, delegates to supabase_db |
| 3 | `apps/api/services/run_persistence.py` | raw_postgres | `TRR_DB_URL` (via get_db_url) | Runtime | **Correct** — in-memory fallback when FAKE_DB=1 |
| 4 | `apps/api/services/outbox.py` | raw_postgres | `TRR_DB_URL` (via get_db_url) | Runtime | **Correct** — event delivery pattern |
| 5 | `apps/api/services/trr_ingest.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** — TRR data import |
| 6 | `apps/api/routers/config.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** — /config/db-status health check |
| 7 | `apps/api/main.py` startup | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** — lane validation + schema contract check |
| 8 | `tools/export_cast_screentime_run_results.py` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Tooling | **Correct** |

**Legacy env vars:** Zero instances of `SUPABASE_DB_URL`, `DATABASE_URL`, `:6543`, or direct-host patterns in runtime or tooling code.

**Deployment:** Self-managed Linux (systemd + nginx). Infrastructure templates in `infra/`. Not SaaS-deployed.

**No Supabase REST client usage.** All DB access is raw psycopg2.

### TRR-APP (4 connection paths)

| # | File | Type | Env Vars | Runtime? | Status |
|---|------|------|----------|----------|--------|
| 1 | `apps/web/src/lib/server/postgres.ts` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** — canonical resolution, lane validation rejects all non-session/local |
| 2 | `apps/web/src/lib/server/supabase-trr-admin.ts` | supabase_rest_server_admin | `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | **Dormant** | Only called when `TRR_AUTH_PROVIDER=supabase` (default is `firebase`) |
| 3 | `apps/web/src/lib/supabase/client.ts` | supabase_rest_browser | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Runtime (browser) | **Active but gracefully degraded** — Flashback game. Returns null if env vars unset. App builds and runs without them. |
| 4 | `apps/web/src/lib/flashback/supabase.ts` | supabase_rest_browser | (via client.ts) | Runtime (browser) | **Active** — imported by Flashback pages (`/flashback/cover`, `/flashback/play`) |

**Legacy env vars in runtime code:** Zero. `SUPABASE_DB_URL` and `DATABASE_URL` are explicitly rejected by resolver with error message.

**`.env.local` dead entries:** `SUPABASE_DB_URL` and `DATABASE_URL` are set in `.env.local` but rejected by resolver. Harmless but confusing — should be removed from local file.

---

## Classification of All Supabase-Related Env Vars

### Runtime-Required (all repos)

| Var | Repo | Purpose |
|-----|------|---------|
| `TRR_DB_URL` | Backend, screenalytics, TRR-APP | Primary Postgres DSN (session pooler :5432) |
| `SUPABASE_JWT_SECRET` | Backend | Local JWT verification |

### Runtime-Optional (active features)

| Var | Repo | Purpose |
|-----|------|---------|
| `TRR_DB_FALLBACK_URL` | Backend, screenalytics, TRR-APP | Secondary Postgres DSN (must also be session pooler) |
| `NEXT_PUBLIC_SUPABASE_URL` | TRR-APP | Browser Supabase client for Flashback. App runs without it; game is degraded. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | TRR-APP | Browser Supabase anon key for Flashback. Same as above. |

### Dormant (code exists, not active by default)

| Var | Repo | Purpose | Activates When |
|-----|------|---------|----------------|
| `TRR_CORE_SUPABASE_URL` | TRR-APP | Admin Supabase REST client | `TRR_AUTH_PROVIDER=supabase` |
| `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | TRR-APP | Admin Supabase service role | `TRR_AUTH_PROVIDER=supabase` |

### Tooling-Only (not runtime)

| Var | Repo | Purpose |
|-----|------|---------|
| `DATABASE_URL` | Backend (scripts only) | Tooling helper fallback, explicitly gated |
| `SUPABASE_DB_URL` | Backend (scripts only) | Deprecated tooling alias, explicitly gated |
| `SUPABASE_SERVICE_ROLE_KEY` | Backend (scripts only) | Ops smoke tests |

### Dead / Rejected at Runtime

| Var | Where Found | Status |
|-----|-------------|--------|
| `SUPABASE_DB_URL` in `.env.local` | TRR-APP local file | Ignored by resolver. Should remove from local file. |
| `DATABASE_URL` in `.env.local` | TRR-APP local file | Ignored by resolver. Should remove from local file. |

---

## Still Missing (Real Unresolved Gaps)

1. **`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` not configured locally.** Flashback browser game is degraded without them. This is intentionally out of scope per the plan constraints — Flashback wiring is not a priority unless it breaks build/runtime, and it doesn't (graceful null return).

2. **No connection pooling in screenalytics.** All 5 runtime services create individual `psycopg2.connect()` calls per operation. For current workload (batch/ingest, low concurrency) this is fine. If screenalytics ever handles high-concurrency API traffic, a ThreadedConnectionPool like TRR-Backend would be the fix.

3. **`.env.local` dead entries.** `SUPABASE_DB_URL` and `DATABASE_URL` in TRR-APP's `.env.local` are rejected by the resolver but still present with credentials. Operator cleanup — remove them from the local file.

**That's it. No code changes required.**

---

## Repo-by-Repo Summary

### TRR-Backend
- **Already correct:** Runtime Postgres resolution (`TRR_DB_URL` → `TRR_DB_FALLBACK_URL`), startup lane validation, pool sizing/timeouts, JWT local-only, health probes, docs
- **Was wrong:** Nothing remaining (all drift fixed in prior session)
- **Changed:** Nothing
- **Intentionally dormant:** `SUPABASE_SERVICE_ROLE_KEY` in ops scripts (tooling-only, not runtime)

### screenalytics
- **Already correct:** All 8 psycopg2 connections use canonical resolution, lane validation active, no legacy vars, startup logging identifies selected source and class
- **Was wrong:** Nothing remaining
- **Changed:** Nothing
- **Intentionally dormant:** Nothing. `SCREENALYTICS_FAKE_DB=1` is a test-only override, not a dormant feature.
- **Deployment:** Self-managed Linux (systemd + nginx), separately deployed

### TRR-APP
- **Already correct:** Server Postgres canonical, lane validation rejects non-session/local, Flashback browser client gracefully degrades
- **Was wrong:** Nothing in code. `.env.local` has dead `SUPABASE_DB_URL`/`DATABASE_URL` entries (harmless, local file only)
- **Changed:** Nothing
- **Intentionally dormant:** `supabase-trr-admin.ts` (activates only with `TRR_AUTH_PROVIDER=supabase`), Flashback browser env vars (not configured locally)
