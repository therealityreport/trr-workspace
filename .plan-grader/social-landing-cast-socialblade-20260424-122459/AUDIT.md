# Social Landing Cast SocialBlade Section Audit

## Verdict

APPROVE WITH CHANGES

The plan is aligned with the current TRR architecture and solves a real operator navigation problem, but it needs tighter data-source, cache, sequencing, and verification details before handing it to an implementation agent.

## Plan Summary

The plan adds a show-first Cast SocialBlade section to `/admin/social`. It should list shows with cast members that have stored SocialBlade data, let an operator select a show such as RHOSLC, then show cast accounts grouped by SocialBlade-capable platform and link to the canonical `/social/[platform]/[handle]` account page.

## Current-State Fit

Status: PARTIAL DRIFT

Why: The plan correctly targets the social landing payload and canonical account routes, but it leaves the actual SocialBlade-row loading path and cast avatar source under-specified against the current repo.

## Benefit Score

Score: 82/100

Improving: operator discovery of scraped cast accounts, route consistency, RHOSLC-style cast workflows

Degrading: social landing payload complexity, cross-repo backend/app coordination, cold landing query cost if not batched/cached

Why: The feature directly addresses the requested navigation gap and reuses existing account pages, but it adds another data join to an already heavy landing payload.

## Plan Errors

1. The plan says to read `pipeline.socialblade_growth_data`, but does not specify whether the app route queries Postgres directly, calls a backend endpoint, or adds a dedicated backend summary endpoint.
2. The plan says to extend bulk cast summary with `photo_url`, but does not name the backend route/model files or tests needed for that contract change.
3. The plan does not mention the social landing localStorage cache key. `SOCIAL_LANDING_CACHE_KEY` is currently `trr-admin-social-landing:v1`; adding a new payload field should either bump this key or explicitly tolerate stale cached payloads.
4. The plan names tests conceptually but does not include concrete commands or expected pass/fail checks.
5. The plan does not include failure behavior for unavailable SocialBlade storage, missing `pipeline.socialblade_growth_data`, or a backend cast-summary error.
6. The plan does not separate backend contract changes from app follow-through in execution order, which matters in this workspace.

## Brilliant Improvements

1. Add a small app-side helper such as `safeLoadCastSocialBladeRows(...)` that returns empty on table/permission failure, preserving the landing page if SocialBlade storage is unavailable.
2. Reuse the current `SOCIAL_ACCOUNT_SOCIALBLADE_ENABLED_PLATFORMS` platform constant so the landing section cannot expose a SocialBlade link for a platform whose account page hides the tab.
3. Include `scraped_at` and platform counts in the show selector so operators can immediately see why a show appears in the section.
4. Add one browser acceptance check for RHOSLC that verifies the link lands on `/social/instagram/[handle]` and that the SocialBlade tab is present.

## Approval Decision

Do not execute the original plan unchanged. Execute the revised plan in `REVISED_PLAN.md`, which preserves the intent but pins the data source, cache behavior, sequence, and validation.
