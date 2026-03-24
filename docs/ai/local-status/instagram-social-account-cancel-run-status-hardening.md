# Instagram Social Account Cancel Run Status Hardening

Date: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "cancel flow and shared-account run status hardening shipped"
  next_action: "reload the shared-account Instagram admin page and verify active runs now show a consistent status banner and cancel optimistically without surfacing summary timeout noise"
  detail: self
```

## Scope
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

## Problem
- The shared-account Instagram admin page could show contradictory run states because recent-run summaries were sourced from a representative job row instead of the scrape run row.
- Cancelling a run could appear to fail when the cancel request succeeded but the follow-up summary refresh timed out.
- A cancelled run could still be reported as `running` in progress snapshots if stale job rows remained active long enough to win status derivation.

## Changes
- Recent catalog runs now prefer scrape-run status and timestamps over representative job-row status in the backend summary query.
- Run-progress status derivation now treats stored `cancelled` status as authoritative.
- Shared-run cancellation now invalidates queue-status cache after recomputing summary.
- The admin page now uses fresher polled progress status for the action banner when it has it.
- The cancel action now targets the freshest active/displayed run, updates local page state optimistically, and preserves success messaging if summary refresh retries fail.
- Backfill, sync-recent, and dismiss actions now keep their success messages even when the follow-up summary refresh is flaky.

## Validation
- `pytest -q /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'catalog_recent_runs or cancel_shared_run_invalidates_queue_status_cache or derive_run_progress_status_respects_cancelled_run_status'`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx`
