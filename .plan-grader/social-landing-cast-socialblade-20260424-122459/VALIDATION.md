# Validation Notes

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/social-landing.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/social/page.tsx`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_cast.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/socialblade_growth.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/socialblade/scraper.py`

## Commands Run

- `sed -n '1,260p' /Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`
- `nl -ba TRR-APP/apps/web/src/lib/admin/social-landing.ts | sed -n '1,120p'`
- `nl -ba TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts | sed -n '35,90p;560,690p'`
- `nl -ba TRR-APP/apps/web/src/app/admin/social/page.tsx | sed -n '25,95p;610,740p;1020,1085p'`
- `nl -ba TRR-APP/apps/web/src/lib/admin/social-account-profile.ts | sed -n '1,45p'`
- `sed -n '1,115p' TRR-Backend/api/routers/admin_cast.py`
- `sed -n '28,55p' TRR-Backend/trr_backend/repositories/socialblade_growth.py`
- `sed -n '90,105p' TRR-Backend/trr_backend/socials/socialblade/scraper.py`

## Evidence

- `SocialLandingPayload` currently includes `network_sets`, `show_sets`, `people_profiles`, `person_targets`, `shared_pipeline`, and `reddit_dashboard`, but no cast SocialBlade show grouping.
- The social landing repository already builds `people_profiles` from bulk cast summary plus primary and fallback person handles.
- The social landing page already has a `PEOPLE` section and uses `coerceLandingPayload`, but does not coerce or render a SocialBlade-specific cast section.
- Account SocialBlade support is currently limited to `instagram`, `youtube`, and `facebook`.
- Backend cast summary currently returns only `person_id` and `full_name`.
- Backend SocialBlade storage normalizes platform and account handle in `pipeline.socialblade_growth_data`.

## Missing Evidence

- I did not query the live database for actual RHOSLC SocialBlade rows during this audit.
- I did not run the local app or browser because this was a plan audit, not implementation verification.

## Assumptions

- The app server has acceptable access to query the SocialBlade growth table through existing Postgres helpers, or a narrow backend endpoint will be added if direct app access is not acceptable during implementation.
- The section should be empty-state tolerant rather than page-fatal if SocialBlade storage is unavailable.
