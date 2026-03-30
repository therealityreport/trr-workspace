# Instagram Modal dispatch profile hardening

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "If the admin profile still shows queued runs for shared Instagram accounts, check Modal readiness first with scripts/modal/verify_modal_readiness.py before starting another backfill"
  detail: self
```

- `TRR-Backend`
  - Added a real Modal-resolution preflight for Instagram shared-account catalog kickoff in both `catalog/backfill` and `catalog/sync-recent`.
  - The admin routes now return `503 SOCIAL_MODAL_DISPATCH_UNAVAILABLE` with concrete target diagnostics when `TRR_MODAL_APP_NAME.TRR_MODAL_SOCIAL_JOB_FUNCTION` cannot be resolved in the configured Modal environment, instead of enqueueing a doomed queued run.
  - Extended shared-account run progress dispatch metadata so the UI can distinguish plain queued-unclaimed jobs from dispatch-blocked jobs and can surface the latest dispatch backend, dispatch error, dispatch error code, blocked reason, configured app/function, and Modal environment.
  - Tightened Modal error classification so function-missing lookup failures are not mislabeled as app-missing, and dispatch-blocked jobs no longer inflate the generic queued-unclaimed count.
- `TRR-APP`
  - Updated the social account profile progress card to render `Modal dispatch blocked` when the backend reports a pre-claim dispatch failure, including the concrete Modal target.
  - Renamed the primary CTA from `Update Posts` to `Backfill Posts` and added inline helper copy clarifying that `Backfill Posts` is full history while `Sync Recent` runs the same pipeline bounded to the last day.
  - Kept the existing summary render path intact while making the active-run messaging truthful for blocked dispatches.
- `workspace`
  - Audited the checked-in workspace Modal settings for the shared-account path and confirmed the local profiles and env-contract already align on:
    - `TRR_MODAL_ENABLED`
    - `TRR_MODAL_APP_NAME`
    - `TRR_MODAL_SOCIAL_JOB_FUNCTION`
    - `TRR_REMOTE_EXECUTOR`
    - `TRR_JOB_PLANE_MODE`
    - `TRR_LONG_JOB_ENFORCE_REMOTE`
  - Added a startup hint in `scripts/dev-workspace.sh` pointing operators to the canonical non-mutating readiness verifier:
    - `cd TRR-Backend && python3.11 scripts/modal/verify_modal_readiness.py --json`
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python3.11 -m pytest tests/test_modal_dispatch.py tests/api/routers/test_socials_season_analytics.py tests/repositories/test_social_season_analytics.py -k 'resolve_modal_function or modal_dispatch_unavailable or post_social_account_catalog_backfill or post_social_account_catalog_sync_recent or build_run_dispatch_health'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx`
  - `curl -I http://admin.localhost:3000/social/instagram/bravodailydish`
- Notes:
  - The focused app runtime file passed under the current shell despite a Node `24.x` engine warning because the shell is on Node `v22.18.0`.
  - The targeted runtime run still emits pre-existing React test warnings about `act(...)` in unrelated polling tests within the same file; those warnings were not introduced by this change set.
