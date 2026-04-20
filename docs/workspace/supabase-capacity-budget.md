# Supabase Capacity Budget

Last reviewed: 2026-04-17

Sizing reference for the TRR workspace's Supabase Postgres connections. Read
this before changing `POSTGRES_POOL_MAX`, `POSTGRES_MAX_CONCURRENT_OPERATIONS`,
`TRR_DB_POOL_MAXCONN`, or Render/Vercel instance counts.

Holder math in this document is based on checked-in repo config plus explicit
assumptions where platform concurrency is not stored in the repo. The live
Supabase project snapshot below is retained as historical context from the last
MCP refresh; re-verify it before using this doc for a production scale change.

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

- **Budget assumption: production holders = 2.** Rationale: the repo pins a
  small session-pooler pool (`POSTGRES_POOL_MAX=4`) and low deployed
  in-instance concurrency (`POSTGRES_MAX_CONCURRENT_OPERATIONS=2`), but it does
  not store live Vercel concurrency. Budget for one steady-state warm instance
  plus one burst or rolling-deploy instance until Observability proves a
  different p95.
- **Budget assumption: preview holders = 1** if any Preview deployment points at
  the same Supabase project. If Preview uses an isolated DB, set this to `0`
  and reclaim 4 connections.
- **Session-pooler subtotal from assumptions:** `(2 + 1) × 4 = 12` connections.

Subtotal formula: `budgeted_concurrent_holders × 4` = potential open
connections (most will be idle in the pool but still count).

### Render (TRR-Backend)

From `TRR-Backend/render.yaml` + `start-api.sh`:

| Setting | Value | Notes |
|---|---|---|
| Service | `trr-backend-api` | Render Standard plan |
| Region | virginia | |
| Default `TRR_BACKEND_WORKERS` | 1 | Unless overridden in Render env |
| Default `TRR_DB_POOL_MAXCONN` (session pooler) | 2 | `pg.py:35` |
| Default `TRR_DB_POOL_MINCONN` (session pooler) | 1 | `pg.py:34` |

- **Budget assumption: production instance count = 1.** The repo contains one
  Render web service definition (`trr-backend-api`) and no checked-in
  horizontal scaling override.
- **Budget assumption: effective `TRR_BACKEND_WORKERS` = 1.** `start-api.sh`
  defaults to `1`, the workspace env contract defaults to `1`, and multi-worker
  mode requires explicit env changes plus Redis-safe runtime conditions.
- **Persistent cron/worker holders = 0.** The checked-in deploy topology does
  not define extra Render worker or cron services. Modal jobs exist, but they
  are treated as ephemeral consumers in the one-off reserve below rather than
  as always-on holders.
- **Session-pooler subtotal from assumptions:** `1 × 1 × 2 = 2` connections.

Subtotal formula: `instances × workers × 2`.

### One-off / scripts / cron

- Modal jobs (`WORKSPACE_TRR_MODAL_*` envs in `env-contract.md`): open ephemeral
  Supabase connections during social dispatch. Typically sub-minute holds.
- `scripts/` ad-hoc backfills: 1–2 connections for minutes at a time.

Reserve ~5 connections for this class to be safe.

## Math

Repo-config-backed budget with the assumptions above:

```
Vercel_prod   = 2 × 4 = 8
Vercel_preview= 1 × 4 = 4   (set to 0 if Preview uses an isolated DB)
Render_python = 1 × 1 × 2 = 2
Scripts/cron  = 5
Supabase_int  = 10
Superuser     = 3
Operator_head = 5
Total         = 8 + 4 + 2 + 5 + 10 + 3 + 5 = 37
Headroom      = 60 - 37 = 23
```

This leaves `23 / 60 = 38.3%` of the backend ceiling free under the documented
budget assumptions.

### Safe headroom thresholds

- **Fixed reserve before app traffic:** `3 + 10 + 5 + 5 = 23` connections are
  intentionally held back for superuser recovery, Supabase internals, operators,
  and one-off jobs.
- **App-lane budget after fixed reserve:** `60 - 23 = 37`.
- **Render consumes:** `2`, leaving `35` for Vercel holders that use
  `POSTGRES_POOL_MAX=4`.
- **Absolute Vercel ceiling with current Render budget:** `floor(35 / 4) = 8`
  concurrent Vercel holders across Production + Preview, leaving 3 spare
  connections.
- **Comfortable Vercel ceiling with a 10-connection overall safety margin:**
  target `Total ≤ 50`, so app lanes should stay within `27` connections.
  After subtracting Render's `2`, Vercel should stay at `25` or below:
  `floor(25 / 4) = 6` concurrent holders across Production + Preview.

**Working rule:** treat **6 total Vercel holders** as the comfortable cap on
this tier, and **8 total Vercel holders** as the practical failure boundary if
the rest of the repo-configured budget stays unchanged.

### Optional local-workspace note

If an operator points `make dev` at the same hosted Supabase project, the local
workspace can add up to `6` more session-mode connections (`TRR-APP` local pool
`4` + `TRR-Backend` local pool `2`). That does not fit cleanly inside the
`Operator_head = 5` reserve, so local workspace access to production should be
treated as explicit break-glass usage rather than normal operating budget.

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
