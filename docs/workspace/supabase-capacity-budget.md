# Supabase Capacity Budget

Last reviewed: 2026-04-14

Sizing reference for the TRR workspace's Supabase Postgres connections. Read
this before changing `POSTGRES_POOL_MAX`, `POSTGRES_MAX_CONCURRENT_OPERATIONS`,
`TRR_DB_POOL_MAXCONN`, or Render/Vercel instance counts.

## Supabase project

| Field | Value |
|---|---|
| Project name | `trr-core` |
| Project ref | `vwxfvzutyufrkhfgoeaa` |
| Region | `us-east-1` |
| Postgres version | `17.6.1.062` |
| Status | `ACTIVE_HEALTHY` |

Pulled live via Supabase MCP (`mcp__873f9389-...__get_project`).

## Postgres backend cap

Pulled live via `SHOW`-equivalent against `pg_settings`:

| Setting | Value | Notes |
|---|---|---|
| `max_connections` | **60** | Hard ceiling on concurrent backend connections |
| `superuser_reserved_connections` | 3 | Reserved for superuser recovery |
| `reserved_connections` | 0 | |
| `statement_timeout` | 120000 ms | Server cap; app sets 30s in `pg.py`, so app wins |
| `idle_in_transaction_session_timeout` | 0 | Unlimited at server; app sets 60s in `pg.py` |
| `shared_buffers` | 28672 × 8KB ≈ 224 MB | Consistent with Nano/Micro compute tier |

**Compute tier inference:** `max_connections = 60` + shared_buffers ≈ 224 MB
indicates **Nano** or **Micro** tier (the two tiers share these limits on
Supabase's compute add-on table). Confirm in the Supabase dashboard under
Settings → Compute.

## Usable connection budget

Starting from `max_connections = 60`:

| Subtracted for | Count | Rationale |
|---|---|---|
| `superuser_reserved_connections` | 3 | Not available to app roles |
| Supabase-internal services | ~10 | Realtime, PostgREST, Storage, analytics (approximate; confirm via `pg_stat_activity`) |
| Operator headroom | 5 | Humans running `psql`, Supabase Studio queries, ad-hoc scripts |
| **Available to application lanes** | **≈ 42** | |

Reference snapshot at time of writing (via `pg_stat_activity`):

```
state    | count
---------+------
 idle    | 11
 (null)  |  8
 active  |  1
---------+------
 total   | 20
```

Current utilization: ~20 / 60 = 33%. Plenty of headroom today; budget below
confirms it stays safe under expected scale.

## Supavisor pooler

The workspace uses **session mode** on port 5432 (`:6543` transaction mode is
banned at runtime by `validateRuntimeLane` in `postgres.ts` and the tight
defaults in `pg.py`). In session mode, each app client holds a dedicated
backend connection for its session's lifetime — there is no multiplexing.

**This means the effective cap is `max_connections - reservations`, not
Supavisor's `max_client_conn`.** The Supavisor client limit is only relevant
for transaction-mode pools, which TRR does not use.

## Holder inventory

Holder = any process that can open a Postgres connection. Each holder's ceiling
is its pool's `max` setting.

### Vercel (TRR-APP)

Default sizing in `postgres.ts`:

| Environment | `POSTGRES_POOL_MAX` | `POSTGRES_MAX_CONCURRENT_OPERATIONS` |
|---|---|---|
| Production (session pooler) | 4 | 2 |
| Development (session pooler) | 4 | 4 |
| Local direct | 4 (non-session) | 2 |

Each concurrent Vercel function instance = 1 holder. Reality check in Vercel
dashboard → Observability → Functions → concurrent executions (p95 over 7d).

- **Production p95 concurrent functions:** _TODO: fill in from Vercel dashboard_
- **Preview env (if pointed at same DB):** _TODO_

Subtotal formula: `p95_concurrent × 4` = potential open connections (most will
be idle in the pool but still count).

### Render (TRR-Backend)

From `TRR-Backend/render.yaml` + `start-api.sh`:

| Setting | Value | Notes |
|---|---|---|
| Service | `trr-backend-api` | Render Standard plan |
| Region | virginia | |
| Default `TRR_BACKEND_WORKERS` | 1 | Unless overridden in Render env |
| Default `TRR_DB_POOL_MAXCONN` (session pooler) | 2 | `pg.py:35` |
| Default `TRR_DB_POOL_MINCONN` (session pooler) | 1 | `pg.py:34` |

- **Production instance count:** _TODO: fill in from Render dashboard → Scaling_
- **Effective `TRR_BACKEND_WORKERS` in Render env:** _TODO_
- **Additional cron/worker services holding DB connections:** _TODO_

Subtotal formula: `instances × workers × 2`.

### One-off / scripts / cron

- Modal jobs (`WORKSPACE_TRR_MODAL_*` envs in `env-contract.md`): open ephemeral
  Supabase connections during social dispatch. Typically sub-minute holds.
- `scripts/` ad-hoc backfills: 1–2 connections for minutes at a time.

Reserve ~5 connections for this class to be safe.

## Math

Fill in the TODOs above and compute:

```
Vercel_prod   = p95_concurrent_functions × 4
Vercel_preview= concurrent_preview_fns × 4   (if preview env targets same DB)
Render_python = instances × workers × 2
Scripts/cron  = 5
Supabase_int  = 10
Superuser     = 3
Operator_head = 5
Total         = Vercel_prod + Vercel_preview + Render_python + Scripts_cron
                + Supabase_int + Superuser + Operator_head
```

**Target:** `Total ≤ 60` with comfortable headroom (e.g., `Total ≤ 50`).

**If `Total > 60`:** `MaxClientsInSessionMode` errors are inevitable. Options
in order of preference:
1. Upgrade Supabase compute tier (Small raises `max_connections` to 90,
   Medium to 120).
2. Lower `POSTGRES_POOL_MAX` on Vercel (the largest and most elastic holder
   class) — but watch `emitStructured("postgres_pool_queue_depth", ...)`
   counts before committing.
3. Route non-interactive work (cron, backfills) to a direct (non-pooler)
   connection string provisioned outside the app's pool.

## Observability hooks (added 2026-04-14)

After metrics instrumentation lands, watch these for empirical validation:

**Backend (Prometheus via `trr_backend/observability.py`):**
- `trr_api_postgres_pool_in_use` (Gauge)
- `trr_api_postgres_pool_available` (Gauge)
- `trr_api_postgres_pool_exhausted_total` (Counter, labelled by reason)
- `trr_api_postgres_pool_acquire_duration_seconds` (Histogram)

**Frontend (structured JSON lines via Vercel log drain):**
- `event=postgres_pool_init` at pool creation
- `event=postgres_pool_queue_depth` when requests queue behind
  `acquireOperationSlot`
- `event=postgres_pool_fallback` on transient-error candidate fallback

If `postgres_pool_queue_depth` is non-zero at steady state, you are hitting the
semaphore — consider raising `POSTGRES_MAX_CONCURRENT_OPERATIONS` (but see
total-budget math above before raising `POSTGRES_POOL_MAX`).

## Env vars to tune

Documented in `docs/workspace/env-contract.md`. The relevant knobs:

- **Vercel (per environment):** `POSTGRES_POOL_MAX`, `POSTGRES_MAX_CONCURRENT_OPERATIONS`
- **Render:** `TRR_DB_POOL_MINCONN`, `TRR_DB_POOL_MAXCONN`, `TRR_BACKEND_WORKERS`
- **Both (optional):** `POSTGRES_POOL_CONNECTION_TIMEOUT_MS`,
  `POSTGRES_POOL_IDLE_TIMEOUT_MS`, `TRR_DB_CONNECT_TIMEOUT_SECONDS`

Do not change `isSessionPooler` defaults in code unless this budget proves the
current defaults are systemically wrong for the tier. Env overrides preserve
the intent of "safe defaults + explicit opt-in for scale."

## Refresh cadence

Rerun the Supabase MCP queries quarterly, or whenever:
- Supabase compute tier changes
- Vercel function concurrency shifts (traffic increase, new routes)
- Render instance count or worker count changes
- A `MaxClientsInSessionMode` error appears in logs
