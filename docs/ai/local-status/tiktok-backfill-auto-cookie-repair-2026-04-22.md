# TikTok Backfill Auto Cookie Repair

Last updated: 2026-04-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-22
  current_phase: "implemented and validated"
  next_action: "optional live admin verification against a TikTok account with refreshable unhealthy cookies"
  detail: self
```

## Scope

- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
- `TRR-Backend/api/routers/socials.py`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/socials/tiktok/scraper.py`
- `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- `TRR-Backend/tests/socials/test_comment_scraper_fixes.py`

## What Landed

- TikTok `Backfill Posts` now always launches with `post_details`, `comments`, and `media`.
- TikTok backfill launch now auto-repairs unhealthy-but-refreshable cookies before starting the catalog run.
- Run-progress contracts now support `repair_action: "cookie_refresh"` in addition to Instagram repair.
- TikTok stays on a truthful single-run model:
  - `comments_run_id = null`
  - `selected_tasks` and `effective_selected_tasks` persist on the catalog run
- TikTok shared-account ingest now explicitly enables details, comments, and media follow-up within the same backfill workflow.
- TikTok direct-comment API access can be enabled for this workflow only via a scoped override.
- The workflow override can be disabled independently with `SOCIAL_TIKTOK_CATALOG_BACKFILL_COMMENT_OVERRIDE_ENABLED`.

## Validation Run

- Passed:
  - `pnpm -C TRR-APP/apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx`
  - `pytest TRR-Backend/tests/api/routers/test_socials_season_analytics.py -q`
  - `pytest TRR-Backend/tests/repositories/test_social_season_analytics.py -q`
  - `pytest TRR-Backend/tests/socials/test_comment_scraper_fixes.py -q`
  - `pnpm -C TRR-APP/apps/web run lint`
  - `pnpm -C TRR-APP/apps/web exec next build --webpack`
  - `pnpm -C TRR-APP/apps/web run test:ci`
- Additional follow-up fixes validated in the same pass:
  - regenerated `apps/web/src/lib/admin/api-references/generated/inventory.ts`
  - stabilized `apps/web/tests/admin-social-page-auth-bypass.test.tsx`

## Remaining Notes

- Backend repo-wide Ruff validation is still red on unrelated baseline issues outside this change area.
- Live browser verification against a real unhealthy TikTok cookie state was not run in this pass.
