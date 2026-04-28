# Supabase Capacity Budget

Last reviewed: 2026-04-27

Sizing reference for TRR Supabase Postgres usage. Read this before changing
`POSTGRES_POOL_MAX`, `POSTGRES_MAX_CONCURRENT_OPERATIONS`,
`TRR_DB_POOL_MAXCONN`, named backend pool caps, Supavisor pool size, or
deployment instance/concurrency caps.

Related operator docs:

- `docs/workspace/supabase-glossary.md`
- `docs/workspace/db-pressure-runbook.md`
- `docs/workspace/supabase-dashboard-evidence-template.md`

## Core Rule

Local workspace holder math is not a production capacity model.

Production rollout requires multiplying per-process pool caps by every process
that can exist at the same time:

```text
total_possible_sessions =
  app_instances * app_pool_max
+ backend_replicas * (
    default_pool_max
  + social_profile_pool_max
  + social_control_pool_max
  + health_pool_max
  )
+ screenalytics_instances * screenalytics_pool_max
+ other scripts/workers
+ Supabase internal/services
```

For Vercel/serverless-style deployment, a pool max of `2` is not two total
connections if many function instances can be warm concurrently.

## Current Local Budget

The checked-in local workspace defaults now distinguish direct local Postgres
from Supavisor session-pooler modes. Default `make dev` uses the direct lane, so
the backend general pool can be higher without consuming Supavisor slots:

| Holder class | Local default max |
|---|---:|
| TRR-APP direct SQL pool | 1 |
| TRR-Backend default pool | 6 |
| TRR-Backend social profile pool | 4 |
| TRR-Backend social control pool | 2 |
| TRR-Backend health pool | 1 |
| Screenalytics DB pool | 0 |
| **Projected local direct holder budget** | **14** |

For session/pooler modes, keep the conservative cloud profile values and let
`scripts/dev-workspace.sh` warn when the projected holder budget exceeds
`WORKSPACE_SUPAVISOR_SESSION_POOL_SIZE - 5`. Contract/CI mode can set
`WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1` so this becomes a hard failure.

## Supavisor And Postgres Caps

TRR uses Supavisor session mode on port `5432`. In session mode, each pooled
client occupies a Supavisor session slot and a backend Postgres connection while
the client is held.

Effective capacity is therefore constrained by both:

```text
effective_app_capacity = min(
  Supavisor session pool_size for the user/database/mode,
  Postgres max_connections minus reserved/internal/operator headroom
)
```

Do not raise production Supavisor pool size until all of these are recorded:

- current Supavisor pool size
- `SHOW max_connections`
- Supabase internal/service usage from live activity
- app deployment max instances/concurrency
- backend replica/worker count
- every process using `TRR_DB_SESSION_URL`, `TRR_DB_URL`, or a scoped `TRR_DB_TRANSACTION_URL` flight test
- rollback target, rollback time, and owner

## Supabase Auth DB Allocation

Phase 4 advisor item: `auth_db_connections_absolute`.

Current decision as of 2026-04-28: completed through the Supabase Management
API with `TRR_SUPABASE_ACCESS_TOKEN` as a narrow Phase 4 Advisor remediation.
This did not raise capacity. It switched Auth from an absolute cap of
`10 connections` to `17 percent`, which preserves the same approximate
allocation against the current `SHOW max_connections = 60`.

Evidence captured:

- Before: `db_max_pool_size=10`, `db_max_pool_size_unit=connections`.
- Postgres capacity at change time: `SHOW max_connections = 60`.
- After: `db_max_pool_size=17`, `db_max_pool_size_unit=percent`.
- Post-change Performance Advisor: `auth_db_connections_absolute` no longer
  appears; remaining performance findings are `unused_index=369`.

Rollback target:

```json
{"db_max_pool_size":10,"db_max_pool_size_unit":"connections"}
```

Rollback path: patch the Auth config endpoint with the JSON above, then rerun
the Performance Advisor and record the result. Do not persist full Auth config
responses because they can include provider, SMTP, hook, and SMS secret fields.

Approved API path when credentials are available:

- Read: `GET https://api.supabase.com/v1/projects/vwxfvzutyufrkhfgoeaa/config/auth`
- Patch: `PATCH https://api.supabase.com/v1/projects/vwxfvzutyufrkhfgoeaa/config/auth`
- Required token route: `TRR_SUPABASE_ACCESS_TOKEN`, not generic
  `SUPABASE_ACCESS_TOKEN`.
- Redacted fields to capture before mutation: `db_max_pool_size` and
  `db_max_pool_size_unit` only.

Supabase's Management API documents `db_max_pool_size` and
`db_max_pool_size_unit` on the project Auth config endpoint. The accepted unit
enum observed from the live API is `connections` or `percent`.

CLI status checked 2026-04-28: installed Supabase CLI `2.84.2` exposes
`supabase config push` but no granular `config get` or `config update` command
for Auth DB pool allocation. Treat CLI mutation as not approved for this item
unless a later CLI version is proven to support a narrow, redacted Auth config
read and patch path.

The broader production pool-size gate below remains `not approved`. The Phase 4
Auth allocation change is recorded separately because it preserves the current
effective Auth allocation instead of increasing Supavisor or Postgres capacity.

## Required Live Evidence

Before increasing Supavisor pool size, capture DB-side holder evidence. The
Supabase Dashboard role counts are useful but not real-time enough by
themselves.

```sql
SELECT
  application_name,
  usename,
  client_addr,
  state,
  count(*) AS connections,
  max(now() - backend_start) AS oldest_connection_age,
  max(now() - state_change) AS oldest_state_age
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY application_name, usename, client_addr, state
ORDER BY connections DESC, oldest_connection_age DESC;
```

Also capture:

- Supabase Dashboard or Grafana connection snapshot
- active user/database/mode combinations in Supavisor
- current app/backend/worker deployment concurrency caps

## Application Names

Every runtime pool must set an explicit `application_name` so the query above is
actionable:

| Runtime | Default application_name |
|---|---|
| TRR-APP | `trr-app:web` |
| TRR-Backend default pool | `trr-backend:default` |
| TRR-Backend social profile pool | `trr-backend:social_profile` |
| TRR-Backend social control pool | `trr-backend:social_control` |
| TRR-Backend health pool | `trr-backend:health` |
| Screenalytics API | `screenalytics:api` |

`TRR_DB_APPLICATION_NAME`, `POSTGRES_APPLICATION_NAME`, and
`SCREENALYTICS_DB_APPLICATION_NAME` must be non-secret labels. Do not use URLs,
tokens, passwords, or keys as application names.

## Production Capacity Task

Before any production rollout that changes DB usage, fill in this table from
live platform settings. Empty cells are not allowed; use `verified`, `pending`,
or `blocked` plus the source/date.

| Field | Value | Source/date |
|---|---|---|
| Supavisor session pool size | pending | Supabase Dashboard Database/Pooler; required before any pool-size change. |
| Postgres `max_connections` | pending | SQL `SHOW max_connections`; required before any pool-size change. |
| Supabase internal/service current usage | pending | `pg_stat_activity` grouped by `application_name` / role / state. |
| TRR-APP max instances/concurrency | pending | Vercel project settings or Observability snapshot. |
| TRR-APP session pool max | verified repo default: `2` production, `1` preview/local | `TRR-APP/apps/web/src/lib/server/postgres.ts`, reviewed 2026-04-27. |
| TRR-Backend replicas | pending | Render/backend deployment settings. |
| TRR-Backend workers per replica | pending | Render/backend deployment settings or runtime env. |
| TRR-Backend default pool max | verified repo default: `2` | Workspace capacity contract, reviewed 2026-04-27; production override still pending. |
| TRR-Backend social profile pool max | verified local profile default: `4`; production pending | Workspace capacity contract, reviewed 2026-04-27. |
| TRR-Backend social control pool max | verified local profile default: `2`; production pending | Workspace capacity contract, reviewed 2026-04-27. |
| TRR-Backend health pool max | verified local profile default: `1`; production pending | Workspace capacity contract, reviewed 2026-04-27. |
| Screenalytics instances | pending | Deployment settings. |
| Screenalytics pool max | verified default disabled unless `SCREENALYTICS_DB_ENABLED=1`; production pending | Workspace capacity contract, reviewed 2026-04-27. |
| Scripts/workers reserve | pending | Modal/backfill concurrency review. |
| Operator headroom | pending | Operations decision; record target before rollout. |

Then compute both:

- expected-case session demand
- worst-case session demand

Set deployment-level instance/concurrency caps if worst-case demand exceeds the
effective capacity target.

## Pool-Size Change Evidence Gate

Current gate status: `not approved`. A Supavisor pool-size increase from `15`
to `25` or `30` is not allowed until every row below is `verified`.

| Requirement | Status | Owner | Evidence / rollback |
|---|---|---|---|
| Current Supavisor pool size captured | pending | workspace-ops | Dashboard Database/Pooler snapshot. |
| Postgres `max_connections` captured | pending | workspace-ops | `SHOW max_connections`. |
| Dashboard/Grafana connection snapshot captured | pending | workspace-ops | Shape-only screenshot or dated note; no secrets. |
| `pg_stat_activity` holder snapshot captured | pending | workspace-ops | Query in Required Live Evidence section. |
| Expected and worst-case holder math completed | pending | workspace-ops | Use the Production Capacity Task table above. |
| Change owner assigned | pending | pending | Name the human/operator accountable for the change. |
| Rollback target recorded | pending | pending | Record the exact previous pool size before the change. |
| Rollback time and path recorded | pending | pending | Include Dashboard path or CLI/runbook path. |
| Code/env changes separated from pool-size change | pending | workspace-ops | Pool-size changes happen as a distinct operations event. |
| Auth DB allocation current value captured | blocked | workspace-ops | Requires `TRR_SUPABASE_ACCESS_TOKEN`; capture only `db_max_pool_size` and `db_max_pool_size_unit` from the Management API Auth config endpoint. |
| Auth DB allocation owner assigned | pending | pending | Name the human/operator accountable for switching from absolute connections to percentage. |
| Auth DB allocation rollback recorded | pending | pending | Record previous `db_max_pool_size` and `db_max_pool_size_unit`, rollback time, and Management API or dashboard rollback path before any patch. |

## Current Code Defaults

| Surface | Session-mode default |
|---|---|
| TRR-APP local | `POSTGRES_POOL_MAX=1`, `POSTGRES_MAX_CONCURRENT_OPERATIONS=1` |
| TRR-APP preview | `POSTGRES_POOL_MAX=1`, `POSTGRES_MAX_CONCURRENT_OPERATIONS=1` |
| TRR-APP production | `POSTGRES_POOL_MAX=2`, `POSTGRES_MAX_CONCURRENT_OPERATIONS=1` |
| TRR-Backend default direct local pool | `TRR_DB_POOL_MINCONN=1`, `TRR_DB_POOL_MAXCONN=6` |
| TRR-Backend default session pool | `TRR_DB_POOL_MINCONN=1`, `TRR_DB_POOL_MAXCONN=2` |
| TRR-Backend local social profile pool | `1/4` via workspace profiles |
| TRR-Backend local social control pool | `1/2` via workspace profiles |
| TRR-Backend local health pool | `1/1` via workspace profiles |
| Screenalytics DB | disabled unless `SCREENALYTICS_DB_ENABLED=1` |

The backend named pools are lazy, but once initialized their idle clients still
occupy session slots. The `minconn=1` named-pool defaults are an intentional
latency tradeoff; lower them only after confirming psycopg2 pool behavior and
readiness probes remain stable.

## Diagnostics

Safe public endpoint:

- `GET /health/db-pressure`: status and reason only, no topology.

Protected details:

- `GET /admin/health/db-pressure`: backend named-pool details, requires
  internal/admin auth.
- `GET /api/admin/health/app-db-pressure`: app process pool details, requires
  TRR-APP admin auth.

Use these with the `pg_stat_activity` query above. Backend pool state alone does
not prove global Supavisor holder ownership.

Local rehearsal:

```bash
make db-pressure-rehearsal
```

The rehearsal command writes redacted local artifacts under `.logs/workspace/`
and samples status/log signals before and after a lightweight pressure check.

## Rollback Rules

Keep production Supavisor pool-size changes separate from code changes.

Do not raise production pool size until:

- `pg_stat_activity` snapshot is captured
- Postgres `max_connections` is known
- Supabase internal service usage is reviewed
- rollback target and time are recorded
- owner is assigned

If `MaxClientsInSessionMode` appears again, prefer this order:

1. Stop/restart local dev and backend processes to release stuck sessions.
2. Lower local/app/backend pool holders and polling fan-out.
3. Move direct TRR-APP SQL into TRR-Backend APIs.
4. Temporarily raise Supavisor pool size only after the evidence gate above.
5. Upgrade Supabase compute tier if effective capacity is genuinely too small.
