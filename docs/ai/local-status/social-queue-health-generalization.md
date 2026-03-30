# Social queue health generalization

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "If any social admin page still shows blocked or likely stuck work, verify the dispatcher runtime with TRR-Backend/scripts/modal/verify_modal_readiness.py and inspect the queue health modal for Dispatch Blocked vs Likely Stuck separation."
  detail: self
```

- `TRR-Backend`
  - Generalized social queue hardening so dispatch-blocked handling is platform-agnostic instead of Instagram-specific.
  - `dispatch_due_social_jobs(...)` now performs a real Modal-resolution preflight before dispatching remote work, records dispatcher-level blocked reasons, and auto-fails no-progress queued or retrying jobs after the configured blocked threshold.
  - Shared-account catalog runs no longer get force-marked `completed` while `post_classify` or other downstream jobs are still non-terminal; active run status now reflects actual child-job state across all supported social platforms.
  - Queue status now exposes additive dispatch-blocked operator data:
    - `dispatch_blocked_jobs`
    - `dispatch_blocked_jobs_total`
    - `dispatch_blocked_by_reason`
    - `waiting_for_claim_jobs_total`
    - `retrying_dispatch_jobs_total`
  - Added `POST /api/v1/admin/socials/ingest/dispatch-blocked-jobs/cancel` so blocked pre-claim jobs can be cleared independently from stale claimed jobs.
  - Queue-status caches are invalidated when jobs or runs move to terminal states so dead blocked/stuck rows disappear on the next refresh.
- `TRR-APP`
  - Updated `SystemHealthModal` so all social admin pages show `Dispatch Blocked` separately from `Likely Stuck Jobs`.
  - The modal now treats dispatcher readiness failures as active attention, exposes blocked counts in the top cards, and keeps the existing stuck-job cancel controls scoped to stale claimed work only.
  - Added independent cancel actions for dispatch-blocked rows and bulk clearing for blocked work.
- `workspace`
  - Reused the existing Modal verifier as the canonical non-mutating readiness check:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python3.11 scripts/modal/verify_modal_readiness.py --json`
  - No additional workspace env mutations were required for the generalized social-page fix.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k 'dispatch_due_social_jobs or dispatch_blocked or queue_status or active_social_account_catalog_run or catalog_recent_runs_marks or finalize_run_status'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_season_analytics.py -k 'queue_status_endpoint or cancel_stuck_jobs_endpoint or cancel_dispatch_blocked_jobs_endpoint'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/test_modal_dispatch.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/system-health-modal.test.tsx`
- Notes:
  - A targeted `ruff check` over the touched backend files still reports pre-existing long-line and one stale `f-string` issue in `test_social_season_analytics.py` and `social_season_analytics.py` outside the queue-health changes completed here.
