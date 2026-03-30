# Reddit post sync reliability hardening

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-30
  current_phase: "archived continuity note"
  next_action: "Refer to newer status notes if follow-up work resumes on this thread."
  detail: self
```

## Problem

Season-window Reddit syncs could land in ambiguous states:

- Modal/remote kickoff could accept a run even when dispatch was unavailable.
- Matching queued runs could be reused forever even when they were never claimed.
- Reddit `403` discovery failures poisoned a window as hard `failed` instead of surfacing a partial cached fallback.
- The admin page collapsed all long-running windows into the same generic `Refresh is still running...` timeout.

## Changes

- Hardened `TRR-Backend/api/routers/socials.py` Reddit run kickoff with Modal preflight and dispatch-failure `503` responses that include additive `code`, `execution_mode`, `execution_owner`, and `worker_health` detail.
- Updated `TRR-Backend/trr_backend/repositories/reddit_refresh.py` to recover orphaned unclaimed queued runs, re-dispatch valid reused queued runs, and emit additive `failure_reason_code` / `operator_hint` metadata in run payloads.
- Reclassified Reddit `403` discovery failures to terminal `partial` runs with explicit partial-failure diagnostics instead of bubbling a hard failure for the whole window.
- Updated `TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx` to keep season sync sequential, surface worker-unavailable / stranded / stalled / partial-403 messages directly, and aggregate partial window warnings instead of collapsing them into generic timeout errors.

## Validation

- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_reddit_refresh_routes.py tests/repositories/test_reddit_refresh.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/reddit-sources-manager.test.tsx tests/reddit-community-discover-route.test.ts`

## Deployment

- Modal app redeployed from `TRR-Backend` with:
  - `TRR_MODAL_RUNTIME_SECRET_NAME=trr-backend-runtime`
  - `TRR_MODAL_SOCIAL_SECRET_NAME=trr-social-auth`
  - command: `./.venv/bin/python -m modal deploy -m trr_backend.modal_jobs`
- Deployment completed successfully and refreshed the Modal app `trr-backend-jobs`, including `run_reddit_refresh` and the `serve_backend_api` web function.

## Follow-up Debug Pass

- Added a dedicated Modal runtime probe function, `probe_reddit_refresh_runtime`, and wired `POST /api/v1/admin/socials/reddit/runs` to fail fast with `503 REDDIT_REMOTE_RUNTIME_UNHEALTHY` when the Modal Reddit worker is missing OAuth configuration.
- Added a short-lived runtime-health cache in `trr_backend/modal_dispatch.py` so season-window kickoff does not repeatedly remote-call the probe during a single sync burst.
- Extended `scripts/modal/verify_modal_readiness.py` to expect the new probe function as part of the deployed Modal app contract.
- Added targeted regression coverage for:
  - Modal Reddit runtime probe payloads
  - kickoff rejection when Modal Reddit OAuth is missing
  - readiness expectations including the new probe function

## Live Runtime Findings

- Post-deploy Modal probe result confirms the remote worker is still unhealthy:
  - `healthy = false`
  - `reason = reddit_oauth_missing`
  - `missing_env = [REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET]`
  - `warnings = [REDDIT_USER_AGENT]`
- Safe local searches found no usable source for `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, or `REDDIT_USER_AGENT` in this workspace, shell environment, or nearby dotenv files, so the code-path fix is complete but the secret-content repair remains blocked on the actual credential values.

## Additional Validation

- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_reddit_refresh_routes.py tests/test_modal_jobs.py tests/scripts/test_verify_modal_readiness.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/python - <<'PY' ... modal.Function.from_name('trr-backend-jobs', 'probe_reddit_refresh_runtime').remote() ... PY`

## Secret Repair

- Added Reddit OAuth credentials and an explicit Reddit user agent to the local backend env source, [`.env`](/Users/thomashulihan/Projects/TRR/TRR-Backend/.env), so future `prepare_named_secrets.py --apply` runs will preserve the working config.
- Updated the live Modal runtime secret `trr-backend-runtime` and redeployed `trr_backend.modal_jobs`.
- Post-repair Modal probe now reports healthy Reddit runtime configuration:
  - `healthy = true`
  - `reason = ok`
  - `supports_oauth = true`
  - `user_agent_configured = true`
- Verified the deployed worker’s authenticated Reddit path succeeds end-to-end:
  - `RedditHttpClient._get_oauth_token()` returned a token in the Modal container
  - `RedditHttpClient.get_json('/r/BravoRealHousewives/new.json', ...)` returned 3 children from the deployed worker
- The unauthenticated `www.reddit.com` path still returns `403` from Modal, but the production scraper now takes the OAuth-backed path and succeeds, which is the behavior we needed.
