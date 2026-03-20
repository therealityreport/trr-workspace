# Bravo social account linking and handle tabs

Last updated: 2026-03-18

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-18
  current_phase: "complete"
  next_action: "Use the season cast comparison tab with the refreshed RHOSLC Season 6 SocialBlade rows; if another cast member is missing, attach the Instagram handle to core.people.external_ids and rerun the local cast-comparison refresh path"
  detail: self
```

- `TRR-Backend` now enforces the requested Bravo defaults across season social targets: `bravowwhl` is included for Instagram, TikTok, Threads, X/Twitter, and YouTube (`wwhl` on YouTube), and `bravodailydish` is included on Instagram.
- `TRR-Backend` social account profile summaries now expose `avatar_url`, preferring the hosted avatar when one exists.
- `TRR-APP` show social pages now show per-platform linked-handle counts in the platform tab labels and render a second linked-handle row for the selected platform with an `ALL` pill plus per-handle pills showing avatar/initials and username.
- The linked-handle row is intentionally suppressed on the overview tab.
- `TRR-Backend` `cast-role-members` now honors the existing `exclude_zero_episode_members=1` query flag on season-scoped requests, so the season social cast comparison no longer keeps zero-episode rows alive after scoped episode recomputation.
- `TRR-Backend` SocialBlade batch refreshes for `source=cast_comparison` now use the working local shared-browser scrape path instead of the broken remote-only Modal path. `season_run` keeps the async dispatch behavior.
- `TRR-APP` cast SocialBlade comparison now filters to actual cast-role members with Instagram handles, which removes non-cast Instagram rows like Andy Cohen or Daisy Kelliher from the season cast comparison chips/charts.
- `TRR-APP` show-social routing now treats `cast-content` as an internal view key and `cast-comparison` as the canonical URL slug, so cast-comparison navigation from `/rhoslc/social/s6` now resolves to `/rhoslc/social/s6/cast-comparison` instead of falling back to official analytics.
- `TRR-APP` cast SocialBlade comparison now renders the first chart as a cumulative followers-gained line chart over the season window, using the earliest preseason day as a zero baseline and extending through the final postseason day when the season analytics window is available.
- RHOSLC Season 6 data has been backfilled in the database for the core cast comparison set:
  - Attached missing Instagram handles in `core.people.external_ids` for `Angie Katsanevas`, `Bronwyn Newport`, and `Britani Bateman`.
  - Corrected `Heather Gay` Instagram handle from `heathergay29` to `heathergay` in `core.people.external_ids`.
  - Refreshed SocialBlade rows for the RHOSLC Season 6 principal comparison set: `Lisa Barlow`, `Meredith Marks`, `Whitney Rose`, `Heather Gay`, `Mary Cosby`, `Angie Katsanevas`, `Bronwyn Newport`, and `Britani Bateman`.
  - Verified final DB state: `principal_with_handles=8` for RHOSLC Season 6, and all 8 rows now exist in `pipeline.socialblade_growth_data`.
- Validation:
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'default_targets or get_targets or target_accounts_by_platform or social_account_profile_summary'`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/show-social-subnav-wiring.test.ts tests/season-social-analytics-section.test.tsx`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run lint` was attempted, but the local run stayed busy traversing generated `.next-turbo-smoke` artifacts and only emitted Babel deoptimization notices under local Node `v22.18.0` instead of the repo's `24.x` baseline.
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && .venv/bin/python -m pytest -q tests/api/test_admin_socialblade.py tests/api/routers/test_admin_show_roles.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && .venv/bin/python -m ruff check api/routers/admin_socialblade.py api/routers/admin_show_roles.py tests/api/test_admin_socialblade.py tests/api/routers/test_admin_show_roles.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/social-growth-batch-route.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/show-admin-routes.test.ts -t 'builds canonical show URLs'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/show-admin-routes.test.ts -t 'parses social analytics view from canonical show and season paths'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/show-admin-routes.test.ts -t 'parses social path filters with official account grammar and legacy aliases'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/cast-socialblade-charting.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && python3 - <<'PY' ... subprocess.run(['pnpm', 'exec', 'tsc', '--noEmit'], timeout=60) ... PY` -> `EXIT=0`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/lib/admin/show-admin-routes.ts tests/show-admin-routes.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/components/admin/cast-socialblade-comparison.tsx src/components/admin/cast-content-section.tsx src/components/admin/season-social-analytics-section.tsx src/lib/admin/cast-socialblade-charting.ts tests/cast-socialblade-charting.test.ts`
  - A fresh `pnpm exec tsc --noEmit` attempt for the charting change did not produce a result in this shell before handoff; the last known successful app typecheck in this session was the earlier route fix.
  - The full `tests/show-admin-routes.test.ts` file still has one pre-existing failing assertion in `buildSeasonSocialWeekUrl`, which expects `/s4/social/w3/details` while the current helper returns `/social/s4/w3`; this was left untouched because it is outside the cast-comparison route fix.
  - Browser smoke via Chrome DevTools MCP could not be completed in-thread because the DevTools transport was closed.
