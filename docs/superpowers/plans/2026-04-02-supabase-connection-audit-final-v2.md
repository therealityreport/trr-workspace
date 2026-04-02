# Final Supabase Connection Audit and Wiring Cleanup (v2)

**Date:** 2026-04-02
**Status:** In Progress

## Summary

Run a repo-by-repo audit in the required order: `TRR-Backend` → `screenalytics` → `TRR-APP`. For each repo, inventory every live, tooling, test, and dead Supabase/Postgres connection path; classify it against the canonical runtime contract; fix only real runtime drift or misleading active docs; and leave Flashback/browser wiring alone unless it is causing an actual build or runtime failure.

## Current Repo Truth

| Repo | Branch | HEAD | Worktree |
|------|--------|------|----------|
| TRR-Backend | `feat/supabase-unified-hardening` | `e0a74c9` `docs: remove stale TRR_DB_ENABLE_DIRECT_FALLBACK references` | Dirty — unrelated edits in `trr_backend/repositories/admin_show_reads.py`, `tests/repositories/test_admin_show_reads_repository.py` |
| screenalytics | `feat/supabase-unified-hardening` | `ec9c764` `fix: close transitional local lane grace period` | Clean |
| TRR-APP | `feat/supabase-unified-hardening` | `7632151` `fix: close local lane grace period` | Dirty — ~14 unrelated app/docs/test changes + 2 untracked files |
| workspace root | `main` | `973da4e` `fix: classify docs/superpowers/plans/ as historical` | Dirty — unrelated script/doc changes |

Existing dirty changes in all repos are unrelated and must not be reverted or committed as part of this task.

## Key Facts Established by Audit

- `screenalytics` has a separate deploy surface: committed deployment artifacts exist (`infra/systemd/*.service`, `docs/ops/deployment/DEPLOYMENT_RENDER.md`). Treat it as deployed, not local-only.
- `TRR-APP` server-admin Supabase access is **active today**: `auth.ts` unconditionally imports `getTrrAdminUrl()` and `getTrrAdminServiceKey()` from `supabase-trr-admin.ts` (line 10). The functions are called inside `verifySupabaseToken()` which executes when `TRR_AUTH_PROVIDER=supabase`, and the catch block returns null gracefully when env vars are missing. These are **required server-auth env vars**, not dormant scaffolding.
- `TRR-APP` browser Supabase is **route-scoped, not app-global**: `client.ts` is only consumed by Flashback code (`lib/flashback/supabase.ts`), and the mounted `/flashback` routes are the only consumers. The app builds and runs without `NEXT_PUBLIC_SUPABASE_*` env vars.

## Audit Classification Rules

| Classification | Criteria |
|---|---|
| `raw_postgres` | Direct psycopg/pg/Pool access to TRR Postgres |
| `supabase_rest_server_admin` | Server-side `@supabase/supabase-js` or REST admin client using service-role credentials |
| `supabase_rest_browser` | Browser/client-side Supabase client |
| `jwt_local_validation` | Local token verification only; never count as a network connection |
| `tooling_only` | Scripts, ops, migration tools — not on any live request path |
| `test_only` | Test code only |
| `dead_code` | Unreachable or explicitly rejected at runtime |
| `correct` | Runtime precedence is `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`, default lane is Supavisor session pooler `:5432`, non-default lanes are rejected or explicitly gated |
| `deprecated` | Legacy env or lane references not on the live runtime path |
| `missing` | Active code requires env/config that is not actually supplied for its intended runtime |
| `misconfigured` | Live/runtime code can silently select `:6543`, `db.<project>.supabase.co`, `SUPABASE_DB_URL`, or `DATABASE_URL` |

Ignore archive/evidence/generated historical docs unless they actively mislead current operators. Active env docs and deploy docs must be corrected.

---

## Audit Matrix

### TRR-Backend

| # | File | Type | Env Vars | Runtime/Tooling/Test | Status | Action |
|---|------|------|----------|---------------------|--------|--------|
| 1 | `trr_backend/db/connection.py` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** | None — canonical resolution, legacy vars explicitly rejected at runtime |
| 2 | `trr_backend/db/pg.py` | raw_postgres (pooled) | `TRR_DB_URL` + pool tuning vars | Runtime | **Correct** | None — ThreadedConnectionPool, 10s connect, 30s statement, 60s idle timeout, session-pooler-aware sizing |
| 3 | `api/main.py` startup | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** | None — rejects transaction/direct/unknown/other/pooler lanes in all environments |
| 4 | `api/main.py` /health | raw_postgres | (via pool) | Runtime | **Correct** | None — SET LOCAL statement_timeout = '3000' in transaction context, logs failures |
| 5 | `trr_backend/security/jwt.py` | jwt_local_validation | `SUPABASE_JWT_SECRET`, project ref env vars | Runtime | **Correct** | None — pure PyJWT verification, no network calls. Docs must not present this as a network dependency. |
| 6 | `trr_backend/db/postgrest_cache.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** | None — non-pooled schema cache reload, canonical resolution |
| 7 | `scripts/_db_url.py` | tooling_only | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, `DATABASE_URL` (opt-in), `SUPABASE_DB_URL` (opt-in) | Tooling | **Correct** | None — legacy aliases explicitly gated behind `allow_*` flags, not default |
| 8 | `trr_backend/db/preflight.py` | tooling_only | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, `DATABASE_URL` | Tooling | **Correct** | None — migration safety checks, `DATABASE_URL` accepted only as tooling fallback |
| 9 | `scripts/ops/*.py` | tooling_only | `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | Tooling | **Correct** | None — smoke tests, not runtime API |
| 10 | `.env.example` | docs | All documented vars | Docs | **Correct** | None — `TRR_DB_ENABLE_DIRECT_FALLBACK` already removed in `e0a74c9` |
| 11 | `README.md` | docs | Referenced vars | Docs | **Correct** | None — direct-fallback guidance already removed in `e0a74c9` |

**Legacy env vars in runtime code:** Zero. `SUPABASE_DB_URL` and `DATABASE_URL` are explicitly tested-and-rejected in `test_connection_resolution.py`.

### screenalytics

| # | File | Type | Env Vars | Runtime/Tooling/Test | Status | Action |
|---|------|------|----------|---------------------|--------|--------|
| 1 | `apps/api/services/supabase_db.py` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** (error wording needs fix) | Fix error messages at lines 63 and 167 to mention both `TRR_DB_URL` and `TRR_DB_FALLBACK_URL` |
| 2 | `apps/api/services/trr_metadata_db.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** | None — read-only metadata, delegates to supabase_db |
| 3 | `apps/api/services/run_persistence.py` | raw_postgres | `TRR_DB_URL` (via get_db_url) | Runtime | **Correct** | None — in-memory fallback when FAKE_DB=1 |
| 4 | `apps/api/services/outbox.py` | raw_postgres | `TRR_DB_URL` (via get_db_url) | Runtime | **Correct** | None — event delivery pattern |
| 5 | `apps/api/services/trr_ingest.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** | None — TRR data import |
| 6 | `apps/api/routers/config.py` | raw_postgres | `TRR_DB_URL` (via resolve) | Runtime | **Correct** | None — /config/db-status health check |
| 7 | `apps/api/main.py` startup | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** | None — lane validation + schema contract check + detailed startup logging |
| 8 | `tools/export_cast_screentime_run_results.py` | tooling_only | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Tooling | **Correct** | None |
| 9 | `scripts/migrate_legacy_db_to_supabase.py` | tooling_only | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` (dest) | Tooling | **Deprecated** | None — one-time historical migration, kept as reference |
| 10 | `tools/test_trr_db*.py` | test_only | `TRR_DB_URL` | Test | **Correct** | None — manual smoke tests |
| 11 | `infra/systemd/*.service` | deploy | Loads from `/opt/screenalytics/.env` | Deploy | **Correct** | None — expects `TRR_DB_URL` in env file |

**Legacy env vars:** Zero instances of `SUPABASE_DB_URL`, `DATABASE_URL`, `:6543`, or direct-host patterns anywhere in the repo.

**Deployment:** Self-managed Linux (systemd + nginx) with infrastructure templates in `infra/`. Separately deployed service.

**No Supabase REST/SDK client.** All DB access is raw psycopg2.

### TRR-APP

| # | File | Type | Env Vars | Runtime/Tooling/Test | Status | Action |
|---|------|------|----------|---------------------|--------|--------|
| 1 | `apps/web/src/lib/server/postgres.ts` | raw_postgres | `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | Runtime | **Correct** | None — canonical resolution, lane validation rejects all non-session/local |
| 2 | `apps/web/src/lib/server/supabase-trr-admin.ts` | supabase_rest_server_admin | `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | Runtime | **Correct** — active auth infrastructure | Document as required server envs for auth; they are not dormant |
| 3 | `apps/web/src/lib/server/auth.ts` | supabase_rest_server_admin (consumer) | `TRR_AUTH_PROVIDER`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | Runtime | **Correct** | None — unconditional import, conditional execution (firebase default), graceful null return if env missing |
| 4 | `apps/web/src/lib/supabase/client.ts` | supabase_rest_browser | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Runtime (browser) | **Route-scoped, needs verification** | Flashback-only. App builds and runs without these. Not a core-app runtime blocker. |
| 5 | `apps/web/src/lib/flashback/supabase.ts` | supabase_rest_browser | (via client.ts) | Runtime (browser) | **Route-scoped, needs verification** | Only consumer of client.ts. Active Flashback pages (`/flashback/cover`, `/flashback/play`) import this. |
| 6 | `.env.local` entries | dead_code | `SUPABASE_DB_URL`, `DATABASE_URL` | Dead | **Dead** — rejected by resolver | Remove from `.env.local` (local file, not tracked) |

**Legacy env vars in runtime code:** Zero. `SUPABASE_DB_URL` and `DATABASE_URL` are explicitly rejected by resolver with actionable error message.

---

## Implementation Changes

### screenalytics — Fix misleading error messages (lines 63, 167)

**File:** `apps/api/services/supabase_db.py`

**Line 63** (lane rejection error): Says "Set TRR_DB_URL to a session-mode pooler URL" but should mention `TRR_DB_FALLBACK_URL` as an alternative.

**Line 167** (`get_db_url` error): Says `f"{TRR_DB_URL_ENV} is not set"` but `TRR_DB_FALLBACK_URL` is also accepted. Should say both.

These are active runtime error messages that operators will see. Fix the wording to match the actual contract.

### TRR-APP — No code changes, documentation-only

Ensure deploy docs (`DEPLOY.md`, `.env.example`) accurately classify:
- `TRR_CORE_SUPABASE_URL` and `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` as **required server-auth envs** (not optional/dormant)
- `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` as **Flashback-scoped browser envs** (route-scoped, not core-app)

### TRR-Backend — No changes

All connections, docs, and env examples are already correct.

### Local cleanup — `.env.local` dead entries

Remove `SUPABASE_DB_URL` and `DATABASE_URL` from `TRR-APP/apps/web/.env.local`. These are rejected by the resolver but still present with credentials. Not a tracked file — operator cleanup.

---

## Env Var Classification

### Runtime-Required (all environments)

| Var | Repo(s) | Purpose |
|-----|---------|---------|
| `TRR_DB_URL` | Backend, screenalytics, TRR-APP | Primary Postgres DSN (session pooler :5432) |
| `SUPABASE_JWT_SECRET` | Backend | Local JWT verification (not a network dependency) |

### Runtime-Required (server auth)

| Var | Repo | Purpose |
|-----|------|---------|
| `TRR_CORE_SUPABASE_URL` | TRR-APP | Admin Supabase REST client for auth token verification. Imported unconditionally by `auth.ts`. Executes when `TRR_AUTH_PROVIDER=supabase`. Graceful null return if missing. |
| `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | TRR-APP | Admin service role key. Same import/execution pattern as above. |

### Runtime-Optional

| Var | Repo(s) | Purpose |
|-----|---------|---------|
| `TRR_DB_FALLBACK_URL` | Backend, screenalytics, TRR-APP | Secondary Postgres DSN (must also be session pooler :5432) |

### Route-Scoped (Flashback only, not core-app)

| Var | Repo | Purpose | Status |
|-----|------|---------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | TRR-APP | Browser Supabase client for Flashback game | **Needs verification** — not configured locally, Flashback degrades gracefully |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | TRR-APP | Browser Supabase anon key for Flashback | Same as above |

### Tooling-Only (not runtime)

| Var | Repo | Purpose |
|-----|------|---------|
| `DATABASE_URL` | Backend (`scripts/` only) | Tooling helper fallback, explicitly gated behind `allow_database_url=True` |
| `SUPABASE_DB_URL` | Backend (`scripts/` only) | Deprecated tooling alias, explicitly gated behind `allow_deprecated_supabase_db_url=True` |
| `SUPABASE_SERVICE_ROLE_KEY` | Backend (`scripts/ops/` only) | Ops smoke tests, not runtime API |

### Dead / Rejected at Runtime

| Var | Where Found | Status |
|-----|-------------|--------|
| `SUPABASE_DB_URL` in `.env.local` | TRR-APP local file (not tracked) | Ignored by resolver. Remove from local file. |
| `DATABASE_URL` in `.env.local` | TRR-APP local file (not tracked) | Ignored by resolver. Remove from local file. |

---

## Verification Plan

| Repo | When | Command |
|------|------|---------|
| screenalytics | After error message wording fix | `cd screenalytics && .venv/bin/pytest tests/unit/ -v -q` |
| TRR-APP | If deploy docs change | `pnpm -C apps/web run lint` |
| TRR-Backend | No changes | No verification needed |

---

## Still Missing (Real Unresolved Gaps)

1. **`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` not configured locally.** Flashback browser routes are the only consumers. The app builds and runs without them; Flashback degrades gracefully (null return). Route-scoped gap, not a core-app runtime blocker. Out of scope unless Flashback is a priority.

2. **No connection pooling in screenalytics.** All runtime services create individual `psycopg2.connect()` calls per operation. Acceptable for current batch/ingest workload. If screenalytics ever handles high-concurrency API traffic, add a `ThreadedConnectionPool`.

3. **`.env.local` dead entries.** `SUPABASE_DB_URL` and `DATABASE_URL` in TRR-APP `.env.local` are rejected by resolver but still present with credentials. Operator cleanup — not tracked by git.

---

## Repo-by-Repo Summary

### TRR-Backend
- **Already correct:** Runtime Postgres resolution (`TRR_DB_URL` → `TRR_DB_FALLBACK_URL`), startup lane validation (rejects all non-session/local), pool sizing/timeouts (session-pooler-aware), JWT local-only verification, health probes (SET LOCAL in transaction), operator docs (.env.example, README)
- **Was wrong:** Nothing remaining — all drift fixed in prior hardening session
- **Changed:** Nothing
- **Intentionally quarantined:** `DATABASE_URL` and `SUPABASE_DB_URL` accepted only in tooling scripts behind explicit opt-in flags. `SUPABASE_SERVICE_ROLE_KEY` in ops scripts only.

### screenalytics
- **Already correct:** All 8 runtime psycopg2 connections use canonical resolution via `resolve_db_url()`/`get_db_url()`, lane validation active in all environments, startup logging identifies source and lane class, no legacy vars, no REST client usage, deployment artifacts present
- **Was wrong:** Error messages in `get_db_url()` (line 167) and `validate_runtime_lane()` (line 63) imply only `TRR_DB_URL` is accepted when `TRR_DB_FALLBACK_URL` is also a valid runtime source
- **To change:** Fix error message wording at lines 63 and 167
- **Intentionally quarantined:** `SCREENALYTICS_FAKE_DB=1` is a test-only override (in-memory fake DB). `scripts/migrate_legacy_db_to_supabase.py` is deprecated one-time tooling.

### TRR-APP
- **Already correct:** Server Postgres canonical (TRR_DB_URL → TRR_DB_FALLBACK_URL), lane validation rejects non-session/local in all environments, `supabase-trr-admin.ts` correctly provides server-auth env helpers with graceful null return, Flashback browser client degrades gracefully
- **Was wrong:** My prior audit incorrectly classified `supabase-trr-admin.ts` as "dormant" — it is active auth infrastructure imported unconditionally by `auth.ts`
- **To change:** Ensure deploy docs classify `TRR_CORE_SUPABASE_*` as required server-auth envs (not dormant). Remove dead `SUPABASE_DB_URL`/`DATABASE_URL` from `.env.local`.
- **Intentionally out of scope:** Flashback browser env vars (`NEXT_PUBLIC_SUPABASE_*`). Route-scoped, not causing build/runtime failure.

## Out of Scope
- Building or wiring Flashback
- Reworking auth architecture
- Replacing Supabase clients with a different pattern
- Large refactors outside connection resolution, validation, env wiring, and documentation
- Archive/evidence/generated historical docs (unless actively misleading operators)
