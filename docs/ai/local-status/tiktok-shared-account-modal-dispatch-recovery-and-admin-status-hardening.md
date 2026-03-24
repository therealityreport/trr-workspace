# TikTok Shared-Account Modal Dispatch Recovery And Admin Status Hardening

Date: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "shared-account Modal dispatch recovery and admin status hardening shipped"
  next_action: "reload the TikTok and Instagram shared-account admin pages, start a fresh backfill, and verify queued runs now surface waiting/retrying/failure dispatch states instead of appearing stuck"
  detail: self
```

## Summary
- Fixed shared-account catalog runs that could stay `queued` forever after a Modal dispatch was created but never claimed.
- Added backend recovery for stale unclaimed Modal dispatch leases, with automatic retry and eventual terminal failure after the configured retry cap.
- Updated shared social profile admin UI to show `Waiting for Modal worker`, `Retrying remote dispatch`, and explicit stale-dispatch failure copy.
- Hardened queued-versus-running status handling so shared-account catalog runs only present as `running` when a job is actually claimed.

## Backend
- Added stale unclaimed Modal dispatch recovery in `TRR-Backend/trr_backend/repositories/social_season_analytics.py`.
- Recovery now:
  - detects queued/pending/retrying jobs whose Modal lease expired before claim
  - records dispatch recovery metadata in-place
  - requeues for retry with backoff until the stale-dispatch retry cap is reached
  - fails with `stale_modal_dispatch_unclaimed` after the cap is exhausted
- `dispatch_due_social_jobs(...)` now performs stale unclaimed dispatch recovery before dispatching fresh work.
- `recover_and_dispatch_due_social_jobs(...)` now reports both stale running-job recovery and stale unclaimed dispatch recovery.
- `get_social_account_catalog_run_progress(...)` now performs run/account-scoped stale dispatch recovery before building the payload and includes `dispatch_health`.
- Run/progress status derivation now keeps runs `queued` when no job has actually entered `running`.
- `get_active_social_account_catalog_run(...)` now derives activeness from normalized recent-run status rather than trusting stale run rows.

## Frontend
- Extended `SocialAccountCatalogRunProgressSnapshot` with `dispatch_health`.
- Updated `SocialAccountProfilePage.tsx` to surface:
  - waiting-for-worker copy for dispatched-but-unclaimed jobs
  - retrying-remote-dispatch copy while the backend recovers stale Modal leases
  - explicit stale-dispatch failure guidance instead of a misleading in-progress state
- Action-banner copy now uses the new dispatch-health context while preserving `Backfill Posts`, `Sync Recent`, and `Cancel Run`.

## Validation
- `pytest -q /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'stale_unclaimed or dispatch_due_social_jobs or get_active_social_account_catalog_run or derive_run_progress_status or waiting_modal_dispatch or cancel_shared_run_invalidates_queue_status_cache'`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx`
