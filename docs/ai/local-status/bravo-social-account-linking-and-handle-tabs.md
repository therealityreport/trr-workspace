# Bravo social account linking and handle tabs

Last updated: 2026-03-17

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-17
  current_phase: "complete"
  next_action: "Monitor the Bravo social admin pages and only backfill persisted season target rows if downstream tooling needs the stored accounts to match the read-time enforced defaults"
  detail: self
```

- `TRR-Backend` now enforces the requested Bravo defaults across season social targets: `bravowwhl` is included for Instagram, TikTok, Threads, X/Twitter, and YouTube (`wwhl` on YouTube), and `bravodailydish` is included on Instagram.
- `TRR-Backend` social account profile summaries now expose `avatar_url`, preferring the hosted avatar when one exists.
- `TRR-APP` show social pages now show per-platform linked-handle counts in the platform tab labels and render a second linked-handle row for the selected platform with an `ALL` pill plus per-handle pills showing avatar/initials and username.
- The linked-handle row is intentionally suppressed on the overview tab.
- Validation:
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'default_targets or get_targets or target_accounts_by_platform or social_account_profile_summary'`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/show-social-subnav-wiring.test.ts tests/season-social-analytics-section.test.tsx`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run lint` was attempted, but the local run stayed busy traversing generated `.next-turbo-smoke` artifacts and only emitted Babel deoptimization notices under local Node `v22.18.0` instead of the repo's `24.x` baseline.
