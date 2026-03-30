# Social runtime warning and closeout cleanup

Last updated: 2026-03-27

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-27
  current_phase: "complete"
  next_action: "If runtime warnings reappear, start from the social account and auth-bypass test mocks before changing app code."
  detail: self
```

- `TRR-APP`
  - Removed the remaining `prefetch={false}` warning from runtime tests by updating `next/link` mocks to strip the Next-only `prefetch` prop before rendering raw anchors.
  - Removed the remaining React `act(...)` warning in the social account profile polling tests by wrapping the polling wait windows in `act(...)`.
  - Applied the same `next/link` mock cleanup to the other test files using raw anchor shims so future runtime reruns stay quiet.
- `user config`
  - Repaired user-level Codex config drift in `~/.codex/config.toml` so workspace validation and `handoff-lifecycle.sh closeout` use the expected plugin and disabled-skill policy state again.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/social-account-hashtag-timeline.runtime.test.tsx --reporter=verbose`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/profile-page.test.tsx tests/trr-shows-page-covered-shows-loading.test.tsx tests/admin-social-page-auth-bypass.test.tsx tests/social-account-profile-auth-bypass.test.tsx --reporter=verbose`
  - `cd /Users/thomashulihan/Projects/TRR && bash scripts/codex-config-sync.sh validate`
- Notes:
  - The runtime test reruns completed without the prior `act(...)` and `prefetch={false}` warnings.
  - The direct `bash scripts/codex-config-sync.sh bootstrap` path was blocked in this shell environment, so the validated bootstrap state was applied directly to `~/.codex/config.toml`.
