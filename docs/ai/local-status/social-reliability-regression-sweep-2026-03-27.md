# Social reliability regression sweep

Last updated: 2026-03-27

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-27
  current_phase: "complete"
  next_action: "Continue from broader social backend/app validation if new queue, mirror, or proxy regressions appear."
  detail: self
```

- `TRR-Backend`
  - Re-ran broader social reliability slices after the all-platform queue/health hardening to catch follow-on regressions in mirror repair and sync orchestration coverage.
  - Updated the mirror-repair tests so they reflect the current repair model:
    - TikTok comment media uses the hosted-repair helpers before deciding a row is truly up to date.
    - Instagram asset-manifest refresh can persist asset meta even when the media is already mirrored, so the test now isolates the mirror result and asserts the asset-meta write path.
- `TRR-APP`
  - Updated the social account profile runtime expectation for the current catalog helper copy:
    - `Backfill Posts`
    - `Sync Newer`
    - `Resume Tail`
    - `Sync Recent`
  - Kept the runtime tests aligned with the current operator copy rather than the earlier shorter string.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_mirror_repairs.py tests/repositories/test_social_account_profile_hashtag_timeline.py tests/repositories/test_social_comment_media_coverage.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/test_modal_jobs.py tests/test_modal_dispatch.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_sync_orchestrator.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/social-account-hashtag-timeline.runtime.test.tsx tests/social-admin-proxy.test.ts tests/social-sync-sessions-routes.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/social-worker-health-route.test.ts tests/social-run-cancel-route.test.ts tests/social-run-scope-wiring.test.ts tests/social-season-hint-routes.test.ts`
- Notes:
  - The social account runtime suite still emits pre-existing React `act(...)` warnings in polling tests and a `prefetch={false}` warning in the test environment; those warnings did not fail the suite and were not introduced by this pass.
