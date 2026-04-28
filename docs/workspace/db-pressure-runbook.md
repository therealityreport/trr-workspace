# DB Pressure Operator Runbook

Use this when an admin page times out, `EMAXCONNSESSION` appears, or local
Supabase-backed admin browsing feels slower than normal. Do not paste raw DB
URLs, keys, JWTs, cookies, or Dashboard secrets into committed docs.

## Local Dev Flow

1. Confirm the workspace contract:

```bash
cd /Users/thomashulihan/Projects/TRR
WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 make preflight
```

2. Capture the current process and mode snapshot:

```bash
make status
bash scripts/status-workspace.sh --json > .logs/workspace/status-db-pressure.json
```

3. Inspect recent pressure signals:

```bash
rg -n "EMAXCONNSESSION|MaxClientsInSessionMode|UPSTREAM_TIMEOUT|DATABASE_SERVICE_UNAVAILABLE|postgres_pool_queue_depth|pool_capacity|connection pool exhausted" .logs/workspace
```

4. Check the safe backend pressure endpoint if the backend is running:

```bash
curl -fsS http://127.0.0.1:8000/health/db-pressure
```

5. Rehearse the full local capture when you need an artifact:

```bash
make db-pressure-rehearsal
```

Decision points:

- If strict preflight fails on env drift, fix the cited profile or ignored env
  override before restarting the stack.
- If only the app pool is saturated, keep `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1`
  for normal local browsing and reduce app fanout before raising holders.
- If backend named pools are saturated, identify the lane (`default`,
  `social_profile`, `social_control`, or `health`) before changing caps.
- If local worker mode is adding pressure, return to the default remote Modal
  lane or disable local workers for admin browsing.
- If sessions look stuck, run `make stop`, confirm listeners are gone, and start
  again with `make dev`.

## Production Or Preview Evidence

Do not mutate Vercel envs, Supavisor pool size, Supabase settings, or remote
migrations while diagnosing pressure. Capture evidence first:

```bash
python3 scripts/vercel-project-guard.py --project-dir TRR-APP
python3 scripts/vercel-project-guard.py --project-dir TRR-APP/apps/web # expected non-zero sandbox/stale block
python3 scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md
```

Then fill the Dashboard checklist in
`docs/workspace/supabase-dashboard-evidence-template.md` or a dated
`docs/workspace/supabase-advisor-snapshot-YYYY-MM-DD.md`.

Escalate only after these are recorded:

- grouped `pg_stat_activity` by `application_name`;
- Supavisor pool size and Postgres `max_connections`;
- Vercel app instance/concurrency assumptions;
- backend replica/worker count;
- remote worker concurrency;
- rollback target, owner, and rollback time.

Capacity valve rule:

- A Supavisor pool-size increase is not approved while the capacity table has
  `pending` or `blocked` rows.
- The change owner, previous pool size, rollback path, and rollback time must be
  recorded before the Dashboard value changes.
- Pool-size changes must be a separate operations event from code, env, or
  migration changes.
