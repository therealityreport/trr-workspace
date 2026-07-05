# Social queue health all-platform hardening

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "If social jobs appear stuck again, check the health modal for Dispatch Blocked vs Likely Stuck before retrying or cancelling work."
  detail: self
```

- `TRR-Backend`
  - Hardened Modal social dispatch across all social queue pages, not just Instagram-specific admin flows.
  - `dispatch_due_social_jobs(...)` now runs a real Modal-resolution preflight through the configured social-job function target before attempting dispatch.
  - Dispatch-blocked jobs are now treated as a first-class queue bucket, with separate totals and reason breakdowns for:
    - `dispatch_blocked_jobs_total`
    - `dispatch_blocked_by_reason`
    - `waiting_for_claim_jobs_total`
    - `retrying_dispatch_jobs_total`
  - Shared-account catalog runs no longer force `run_status = completed` while child jobs remain queued, retrying, or running in later stages.
  - Dispatch-blocked jobs with no worker claim and no remote invocation now auto-fail after bounded no-progress / repeated-hard-failure thresholds instead of sitting indefinitely.
  - Queue-status caches are invalidated immediately when stuck or blocked rows become terminal so they disappear from the operator UI on the next refresh.
  - Added a dedicated admin API action to cancel dispatch-blocked jobs independently of stale claimed jobs.
- `TRR-APP`
  - Updated `SystemHealthModal` to separate `Dispatch Blocked` from `Likely Stuck Jobs`.
  - Added independent operator actions for blocked jobs so `Cancel all likely stuck jobs` stays scoped to stale claimed work.
  - Queue summary cards now surface blocked-dispatch counts and dispatcher readiness instead of collapsing everything into historical failure language.
  - Terminal stuck/blocked rows drop out of the rendered lists as soon as refreshed payloads no longer include them.
- `operator semantics`
  - `Likely Stuck Jobs` now means stale claimed/running work.
  - `Dispatch Blocked` now means pre-claim dispatch/runtime failures, including Modal SDK or function-resolution failures.
  - `completed` run status now means child jobs are actually terminal, not merely that earlier scrape phases finished.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k 'dispatch_due_social_jobs or dispatch_blocked or queue_status or active_social_account_catalog_run or catalog_recent_runs_marks or finalize_run_status'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_season_analytics.py -k 'queue_status_endpoint or cancel_stuck_jobs_endpoint or cancel_dispatch_blocked_jobs_endpoint'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/test_modal_dispatch.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/system-health-modal.test.tsx`
- Notes:
  - `ruff check` on the touched backend files is still noisy because those files already contain pre-existing long-line violations outside this change set.
  - Browser verification was requested after code/test validation; if it is still needed later, start from `http://admin.localhost:3000` and open the `System Jobs Health` modal to confirm the blocked/stuck split against live data.
