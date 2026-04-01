# Instagram remote backfill readiness

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-30
  current_phase: "complete"
  next_action: "Use Sync Recent as the first operator canary, then run Resume Tail if a resumable frontier exists, then launch full-history Backfill Posts with Modal worker-health monitoring."
  detail: self
```

## Summary

- Restored the canonical remote job-plane defaults for workspace `make dev` so
  shared-account Instagram work uses Modal by default instead of the legacy
  local worker lane.
- Repaired Modal deployment readiness for `trr-backend-jobs`; the app now
  resolves all required functions including `run_social_job`,
  `sweep_social_dispatch_queue`, and `serve_backend_api`.
- Fixed the Modal secret renderer so file-backed social auth sources are
  materialized into remote-safe inline JSON env vars for named secret
  `trr-social-auth`.
- Extended remote executor heartbeats to publish `auth_capabilities`, then fixed
  backend worker-health persistence so local status reads do not clobber those
  remote capability fields.
- Confirmed the shared Instagram lane can queue and run on real Modal workers
  with fresh dispatcher heartbeat, green remote Instagram auth, and successful
  bounded canaries.

## Main Cause

The failure was operational, not UI routing:

1. the default workspace profile still launched long social jobs in the local
   legacy worker lane
2. the deployed Modal app was missing required functions
3. the Modal social secret dropped file-backed cookie auth used by the backend
4. worker-health reads overwrote the remote dispatcher metadata that should have
   exposed remote Instagram auth readiness

That combination made `Backfill Posts` look unavailable even after the app and
backend routing/auth contract was repaired.

## Repo-Owned Fixes

### Workspace defaults

- `profiles/default.env` now defaults to:
  - `WORKSPACE_TRR_JOB_PLANE_MODE=remote`
  - `WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1`
  - `WORKSPACE_TRR_REMOTE_EXECUTOR=modal`
  - `WORKSPACE_TRR_MODAL_ENABLED=1`
  - `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=1`
- `scripts/check-workspace-contract.sh` now enforces those defaults.
- `docs/workspace/dev-commands.md` and `docs/workspace/env-contract.md` were
  updated to match the new default job-plane contract.

### Backend / Modal

- `TRR-Backend/scripts/modal/prepare_named_secrets.py`
  - now materializes `*_COOKIES_FILE` auth inputs into inline `*_COOKIES_JSON`
    secret values for Modal
  - compacts multiline JSON cookie files into single-line values acceptable to
    `modal secret create --from-dotenv`
- `TRR-Backend/trr_backend/modal_jobs.py`
  - `heartbeat_remote_executors()` now reports remote social auth capabilities
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - worker-health payload now surfaces `remote_auth_capabilities` and
    `shared_account_backfill_readiness`
  - dispatcher-heartbeat touch logic now preserves remote auth metadata instead
    of wiping it during local status reads
- `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
  - updated canary order, readiness contract, and `n8n` control-plane notes
- `TRR-Backend/docs/automation/README.md`
  - now records the checked-in `n8n` template inventory and makes the
    template-versus-live-environment distinction explicit
- `TRR-Backend/docs/architecture/social_ingest_n8n_setup.md`
  - now records that repo-owned `n8n` coverage is template-only and that any
    live external `n8n` environment still requires separate operational review

### App visibility

- `TRR-APP/apps/web/src/components/admin/SystemHealthModal.tsx`
  - now renders remote Instagram auth and shared-account backfill readiness
- `TRR-APP/apps/web/tests/system-health-modal.test.tsx`
  - updated for the new health fields

## Live Validation Evidence

- Modal readiness:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/python scripts/modal/verify_modal_readiness.py --json`
  - result: `ok=true`, all required functions present, API web URL resolved
- Modal deploy:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/python -m modal deploy -m trr_backend.modal_jobs`
- Named secrets:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/python scripts/modal/prepare_named_secrets.py --apply`
  - result: `trr-backend-runtime` and `trr-social-auth` updated successfully
- Remote heartbeat auth:
  - remote `heartbeat_remote_executors` returned
    `social_auth_capabilities.instagram_authenticated=true`
- Worker-health readiness:
  - `GET /api/v1/admin/socials/ingest/worker-health`
  - result after cache expiry:
    - `dispatcher_readiness.resolved=true`
    - `dispatcher_heartbeat_fresh=true`
    - `remote_auth_capabilities.instagram.ready=true`
    - `shared_account_backfill_readiness.ready=true`
- Shared-account canary 1:
  - `POST /api/admin/trr-api/social/profiles/instagram/bravotv/catalog/sync-recent`
  - run id: `9eb35100-6fa2-4334-b42d-986a5282675f`
  - result: queued to Modal, then progressed on worker
    `modal:social:modal:2:42d3e8ab`
- Shared-account canary 2:
  - `POST /api/admin/trr-api/social/profiles/instagram/bravodailydish/catalog/backfill`
    with `backfill_scope=bounded_window`
  - run id: `42548540-73bb-462e-9275-4b2dc25bbd38`
  - progress evidence:
    - `run_status=running`
    - stage `shared_account_posts.jobs_running=1`
    - worker sample `modal:social:modal:2:3900aa45`
    - `latest_dispatch_backend=modal`
    - `latest_dispatch_error=null`
    - no `SOCIAL_MODAL_DISPATCH_UNAVAILABLE`
    - no `SOCIAL_WORKER_UNAVAILABLE`
    - no auth-preflight failure

## n8n Audit Outcome

- Repo-owned `n8n` assets do exist under
  `TRR-Backend/docs/automation/*.json`.
- They are classified as `launches-backfill` control-plane templates:
  they start catalog runs and poll progress to terminal state.
- They correctly target the canonical backend admin endpoints and support
  internal-admin bearer JWT auth.
- No live external `n8n` workflow id, trigger owner, or credential store is
  tracked in this repo.

That means:

- Modal worker readiness is green for the repo-owned execution plane.
- The checked-in `n8n` templates are valid and aligned.
- A real external `n8n` environment still requires separate operator review
  before anyone can claim that environment itself is ready.

## Validation

- Backend:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/python -m pytest -q tests/test_modal_jobs.py tests/scripts/test_prepare_named_secrets.py tests/repositories/test_social_season_analytics.py tests/test_modal_dispatch.py tests/api/routers/test_socials_season_analytics.py -k 'heartbeat_remote_executors_reports_social_auth_capabilities or file_backed_social_auth or remote_instagram_auth_summary or modal_dispatch_unavailable or post_social_account_catalog_backfill or post_social_account_catalog_sync_recent or touch_modal_social_dispatcher_heartbeat_preserves_remote_auth_metadata or build_modal_executor_health_payload_reports_instagram_backfill_readiness'`
- App:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/system-health-modal.test.tsx`
- Workspace:
  - `cd /Users/thomashulihan/Projects/TRR && bash scripts/check-workspace-contract.sh`

## Result

- Remote Instagram backfill is now ready on the repo-owned execution plane.
- `Backfill Posts` and `Sync Recent` can launch against real Modal workers with
  remote Instagram auth available.
- The remaining caution is operational scope, not a broken pipeline:
  a full-history run is expected to be long-lived and should be monitored with
  worker-health and run-progress surfaces rather than treated as an instant
  smoke test.
