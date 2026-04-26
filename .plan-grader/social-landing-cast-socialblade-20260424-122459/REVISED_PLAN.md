# Revised Plan: Social Landing Cast SocialBlade Section

## Summary

Add a Cast SocialBlade section to `/admin/social` that lists only shows with at least one cast member matched to stored SocialBlade scrape data. Selecting a show, such as RHOSLC, shows cast members with profile photos grouped by SocialBlade-capable platform. Clicking a platform account opens the canonical `/social/[platform]/[handle]` account page so the existing Backfill, Catalog, Comments, and SocialBlade tab behavior remains the source of truth.

## Key Changes

- Extend `SocialLandingPayload` with `cast_socialblade_shows` and update `coerceLandingPayload` plus the social landing cache key to a new version.
- Build `cast_socialblade_shows` in the social landing repository from existing covered shows, bulk cast summary, effective person social handles, and stored SocialBlade rows.
- Add a narrow SocialBlade row loader that reads `pipeline.socialblade_growth_data` by normalized `(platform, account_handle)` and `person_id`, returns only summary metadata needed for the landing page, and fails closed to an empty list if the table is unavailable.
- Keep supported platforms aligned with `SOCIAL_ACCOUNT_SOCIALBLADE_ENABLED_PLATFORMS`: `instagram`, `youtube`, and `facebook`.
- Extend the backend `/admin/shows/cast-summary` response to include optional `photo_url`, using the same cast photo selection pattern already used by cast role member reads.
- Render a new Cast SocialBlade section on `/admin/social`: show selector first, selected-show member grid second, grouped by platform, with each account link generated through `buildSocialAccountProfileUrl`.

## Execution Order

1. Backend contract: add `photo_url` to the cast-summary response model and query, then add or update backend tests for the response shape.
2. App types and data: add the new landing payload types, SocialBlade summary row loader, matching logic, and cache key bump.
3. App UI: add the show selector and platform-grouped member view, including empty states for no matching scrape rows and per-member photo fallback.
4. Verification: run targeted backend tests, targeted app tests, typecheck/lint for touched app surfaces, then browser-check RHOSLC from `/admin/social`.

## Test Plan

- Backend:
  - Run the targeted admin cast-summary tests and verify `photo_url` remains optional/backward compatible.
  - Add a test proving cast-summary still returns entries when photos are missing.
- App repository:
  - Add tests for `getSocialLandingPayload` proving a show appears when a cast member matches a SocialBlade row by `person_id`.
  - Add tests proving an account-only SocialBlade row matches by normalized platform and handle.
  - Add tests proving unsupported platforms and shows with no SocialBlade scrape rows are omitted from `cast_socialblade_shows`.
- App UI:
  - Add a social landing render test where selecting RHOSLC reveals cast members grouped by Instagram/Facebook/YouTube.
  - Assert the account link points to `/social/instagram/[handle]`, not an external profile URL.
- Manual/browser:
  - Use the in-app browser on `http://admin.localhost:3000/admin/social`.
  - Confirm RHOSLC appears in the Cast SocialBlade show list when test/live data contains a matching scrape.
  - Select RHOSLC, click an Instagram account, and confirm the canonical account page loads with the SocialBlade tab available.

## Assumptions

- The section is scrape-filtered: cast members with social handles but no stored SocialBlade row do not appear.
- The click target is the base canonical account page, not the `/socialblade` sub-route, because the account page is the container for Backfill and SocialBlade workflows.
- This change does not trigger new scrapes or refreshes; it only exposes navigation over stored SocialBlade data.
- If SocialBlade storage is unavailable, the rest of the social landing page should still render and the Cast SocialBlade section should show an empty state.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.
