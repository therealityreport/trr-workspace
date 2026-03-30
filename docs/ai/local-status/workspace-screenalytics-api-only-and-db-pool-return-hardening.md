# Workspace screenalytics API-only default and DB pool return hardening

Date: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "Use make dev normally; default startup now keeps only the screenalytics API on, and admin people photo reads no longer fail behind recycled closed DB connections."
  detail: self
```

## Summary

- Hardened `make dev` so the default `PROFILE=default` startup runs screenalytics in API-only mode.
- Added explicit workspace toggles for the two screenalytics UIs and threaded those flags through the screenalytics launcher, workspace startup, and workspace status output.
- Non-strict preflight now self-heals stale `docs/workspace/env-contract.md` instead of warning and continuing with drift.
- Chrome automation summary output now reports pressure-only issues as warnings instead of mixing `OK` readiness with an `unsafe` verdict.
- Fixed a backend pool-return fault in `TRR-Backend/trr_backend/db/pg.py` where closed read/write connections could still be returned as reusable handles, which surfaced in the app as `Invalid response from backend` on admin people photo requests.

## Files Changed

- Workspace startup and docs:
  - `Makefile`
  - `scripts/preflight.sh`
  - `scripts/dev-workspace.sh`
  - `scripts/status-workspace.sh`
  - `scripts/chrome-devtools-mcp-status.sh`
  - `scripts/workspace-env-contract.sh`
  - `profiles/default.env`
  - `profiles/local-cloud.env`
  - `profiles/local-docker.env`
  - `profiles/local-full.env`
  - `profiles/local-lite.env`
  - `screenalytics/scripts/dev_auto.sh`
  - `docs/workspace/dev-commands.md`
  - `docs/workspace/preflight-doctor.md`
  - `docs/workspace/env-contract.md`
- Backend pool hardening:
  - `TRR-Backend/trr_backend/db/pg.py`
  - `TRR-Backend/tests/db/test_pg_pool.py`

## Validation

- Shell checks:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/preflight.sh`
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/workspace-env-contract.sh`
  - `bash -n /Users/thomashulihan/Projects/TRR/screenalytics/scripts/dev_auto.sh`
- Backend tests:
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/test_pg_pool.py -q`
- App tests:
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/person-gallery-route-cache-dedupe.test.ts tests/person-gallery-broken-filter.test.ts tests/person-resolve-slug-route-parity.test.ts`
- Workspace/runtime smoke:
  - `make preflight`
  - `make dev`
  - `make status`
  - `curl -H 'Host: admin.localhost:3000' -H 'Authorization: Bearer dev-admin-bypass' 'http://127.0.0.1:3000/api/admin/trr-api/people/resolve-slug?slug=mary-cosby'`
  - `curl -H 'Host: admin.localhost:3000' -H 'Authorization: Bearer dev-admin-bypass' 'http://127.0.0.1:3000/api/admin/trr-api/people/584abd04-9dfa-418d-9ef6-2ef00f67073d/photos?limit=25&offset=0'`
  - `lsof -nP -iTCP:8501 -sTCP:LISTEN`
  - `lsof -nP -iTCP:8080 -sTCP:LISTEN`

## Result

- Default `make dev` now starts `TRR-APP`, `TRR-Backend`, and the screenalytics API while leaving Streamlit and the legacy screenalytics web UI off unless explicitly re-enabled.
- Workspace status and startup output now report those disabled UIs truthfully instead of treating them as missing listeners.
- The admin people photo route returns `200` again through the app proxy under the restarted live stack, and the backend log no longer shows the earlier closed-connection/pool-reset failure during that flow.
