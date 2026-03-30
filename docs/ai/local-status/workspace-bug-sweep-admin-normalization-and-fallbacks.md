# Workspace bug sweep: admin normalization and fallback hardening

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-30
  current_phase: "archived continuity note"
  next_action: "Refer to newer status notes if follow-up work resumes on this thread."
  detail: self
```

- `TRR-Backend`
  - Restored Getty fallback hosted-field updates for Getty-only cast-photo imports so broad-event and fallback Getty rows keep a usable hosted preview URL after upsert.
  - Hardened social account hashtag payload building so official Bravo-account RHOSLC hashtag inference can still fall back to analysis rows when catalog-backed hashtag items do not carry observed show context.
  - Added a safe fallback path for environments where the shared catalog query layer is unavailable during hashtag-item assembly, instead of hard-failing before the analysis-row fallback can run.
- `TRR-APP`
  - Hardened person external-id normalization and preview URL building for pasted profile URLs across IMDb, Wikidata, Fandom, Facebook, Twitter/X, and multiple YouTube URL shapes.
  - Preserved full query strings when proxying social-account hashtag timeline and catalog verification requests to TRR-Backend, preventing filter/debug params from being silently dropped.
  - Added focused regression coverage for the normalized external-id helper behaviors and the updated social proxy routes.
- Bug-fix coverage landed in this sweep:
  - 18 new app helper regression cases in `tests/person-external-ids.test.ts`
  - 2 social proxy query-forwarding regressions in route tests
  - 2 backend regressions covered by existing failing tests (`test_admin_person_images.py` Getty fallback hosted updates and `test_social_season_analytics.py` RHOSLC inference fallback)
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/ruff check api/routers/admin_person_images.py trr_backend/repositories/social_season_analytics.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/repositories/test_social_season_analytics.py -k 'test_get_social_account_profile_hashtags_infers_rhoslc_assignment_for_official_bravo_handles'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/api/routers/test_admin_person_images.py -k 'test_import_nbcumv_person_media_imports_broad_grouped_events_as_event_bucket'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/api/routers/test_admin_person_images.py tests/repositories/test_social_season_analytics.py -k 'get_social_account_profile_hashtags_infers_rhoslc_assignment_for_official_bravo_handles or import_nbcumv_person_media'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/api/routers/test_admin_bravotv_images.py tests/bravotv/test_run_service.py tests/bravotv/test_get_images_pipeline.py tests/api/routers/test_socials_season_analytics.py tests/repositories/test_social_season_analytics.py tests/socials/test_instagram_scraper_public_graphql.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/lib/admin/person-external-ids.ts 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/hashtags/timeline/route.ts' 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/verification/route.ts' tests/person-external-ids.test.ts tests/social-account-hashtag-timeline-route.test.ts tests/social-account-catalog-verification-route.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/person-external-ids.test.ts tests/person-external-ids-route.test.ts tests/social-account-hashtag-timeline-route.test.ts tests/social-account-catalog-verification-route.test.ts tests/social-account-profile-page.runtime.test.tsx tests/social-account-hashtag-timeline.runtime.test.tsx tests/bravotv-image-runs.test.ts tests/bravotv-image-routes.test.ts tests/bravotv-image-run-panel-wiring.test.ts tests/people-page-tabs-runtime.test.tsx tests/person-credits-route.test.ts tests/person-credits-show-scope-wiring.test.ts tests/person-refresh-request-id-wiring.test.ts tests/photo-metadata.test.ts tests/image-lightbox-metadata.test.tsx tests/show-admin-routes.test.ts --reporter=dot`
- Validation caveat:
  - A long-running fresh invocation of `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/api/routers/test_admin_person_images.py` stopped returning output through the tool session after partial progress, so the fully completed signal for that exact rerun was not captured here. The directly affected Getty fallback case and the broader Getty/NBCUMV subset both passed.

## 2026-03-26 Follow-up
- `TRR-APP`
  - Finished the canonical admin-route cleanup for middleware rewrites, design-doc links, job docs, and leftover back-links that were still emitting legacy `/admin/*` paths.
  - Fixed the stale Getty prefetch callback dependency in the show admin page so cross-show navigation cannot reuse an old `show?.name` closure.
  - Reduced the social week detail startup cost by keeping the full metrics backfill behind truncation detection while preserving the lighter summary backfill path, and added regression coverage for rewrite-query preservation plus route-table parity.
- `TRR-Backend`
  - Kept `trr_backend.clients.computer_use` non-shipping by leaving it unregistered in `api/main.py`, but made the router safe-by-default with `InternalAdminUser` auth, sanitized client errors, optional dependency handling, and bounded response payloads that no longer expose full agent transcripts.
  - Added focused router smoke/auth/response-shape coverage in `tests/clients/test_computer_use.py`.
  - Refreshed `requirements.lock.txt` after the Anthropic dependency pass; `claude-computer-use` could not be locked because it is not resolvable from the configured package registry, so the runtime now fails closed with a configuration error instead of breaking import-time startup.
- `screenalytics`
  - Kept `apps.api.routers.computer_use` unregistered in `apps/api/main.py`, added bearer-token service auth, sanitized error responses, and made the Claude runtime optional/fail-closed like the backend.
  - Hardened `inspect_frame()` by validating the file path, restricting supported image suffixes, and shell-quoting the resolved absolute path before it is embedded in the model prompt.
  - Added focused router/auth/path-sanitization coverage in `tests/api/test_computer_use.py` and refreshed `requirements-core.lock.txt`.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/proxy.ts tests/admin-host-middleware.test.ts tests/admin-route-paths.test.ts tests/week-social-thumbnails.test.tsx`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/admin-host-middleware.test.ts tests/admin-route-paths.test.ts tests/show-admin-routes.test.ts tests/show-route-parity.test.ts tests/week-social-thumbnails.test.tsx`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && uv run ruff check trr_backend/clients/computer_use.py tests/clients/test_computer_use.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/clients/test_computer_use.py -q`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && uv pip compile requirements.in --python-version 3.11 -o requirements.lock.txt`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && python -m py_compile apps/api/routers/computer_use.py tests/api/test_computer_use.py`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && pytest tests/api/test_computer_use.py -q`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && uv pip compile requirements-core.in --python-version 3.11 -o requirements-core.lock.txt`

## 2026-03-26 Earlier Follow-up
- `TRR-Backend`
  - Extended the admin show-seasons read query to include per-season episode aggregates from `core.episodes`: total episode count, first aired episode date, and last aired episode date, alongside the existing aired-episode signal.
- `TRR-APP`
  - Switched the show seasons tab to request `include_episode_signal=true` during the primary season fetch and hydrate season card summaries from that payload instead of depending on a second per-season episode fan-out.
  - Kept the episode fan-out only as a fallback when the aggregate fields are missing, and tightened the season-card date fallback order to prefer `premiere_date` and the last aired episode when available.
  - This fixes the duplicated single-day date ranges on `/[show-slug]/seasons` that were coming from the `core.seasons.air_date` fallback, and restores episode counts on the season cards.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_admin_show_reads_repository.py -k 'show_seasons'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check trr_backend/repositories/admin_show_reads.py tests/repositories/test_admin_show_reads_repository.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run -c vitest.config.ts tests/show-social-load-resilience-wiring.test.ts tests/show-season-cards.runtime.test.tsx tests/show-seasons-route-episode-signal.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec eslint 'src/app/admin/trr-shows/[showId]/page.tsx' 'src/components/admin/show-tabs/ShowSeasonCards.tsx' 'src/components/admin/show-tabs/ShowSeasonsTab.tsx' 'tests/show-social-load-resilience-wiring.test.ts'`
  - ESLint reported one pre-existing warning in `apps/web/src/app/admin/trr-shows/[showId]/page.tsx:3422` for a missing `show?.name` hook dependency; no new lint errors were introduced by this fix.

## 2026-03-22 Follow-up
- `workspace`
  - Normalized the workspace runtime contract around `run_admin_operation_v2`, the non-reload backend default, and the canonical local `8001` screenalytics API port.
  - Added `/Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh` plus a matching `workspace-contract-check` Make target so script/profile/doc drift is caught explicitly.
- `TRR-Backend`
  - Fixed Modal function-call inspection so generic call inspection only depends on the configured Modal app name, not the unrelated social-job function toggle.
  - Reworked Reddit refresh kickoff to create-or-reuse runs before health gating, and to redispatch clearly orphaned queued runs even when they already have attempts recorded.
  - Relaxed orphaned queued-run recovery from the old 45-second grace period to 300 seconds.
  - Made person-profile refresh reporting more truthful by counting actual changed profile fields and successful credit refreshes instead of placeholder counts.
- `screenalytics`
  - Unified DB URL resolution with backend-style precedence and tightened standalone/no-Docker queue guardrails so unusable localhost broker defaults fail fast with a clear API error.
  - Hardened cast-screentime dispatch persistence and duplicate protection, including durable enqueue metadata and self-match avoidance.
  - Stopped `sync_cast_from_trr` from claiming `not_implemented` while mutating state, and honored `black_screen.auto_exclude`.
- `TRR-APP`
  - Preserved `showId` context in person admin URLs, global search links, and admin-host middleware canonicalization for people routes.
  - Corrected Reddit community breadcrumbs back to public/community show routes, fixed brand-logo modal state merges, restored source-first image candidate ordering, and aligned the person “Get Images” flow with the ingest-only source-selection contract.
  - Restored lint signal by ignoring generated `.vercel/**` content and cleaning the remaining app-local warning-only issues uncovered in the design docs.
- Validation:
  - `bash /Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && pytest -q tests/test_modal_dispatch.py tests/api/routers/test_socials_reddit_refresh_routes.py tests/repositories/test_reddit_refresh.py tests/api/routers/test_admin_person_profile.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && source .venv/bin/activate && ruff check trr_backend/modal_dispatch.py api/routers/socials.py trr_backend/repositories/reddit_refresh.py api/routers/admin_person_profile.py tests/test_modal_dispatch.py tests/api/routers/test_socials_reddit_refresh_routes.py tests/repositories/test_reddit_refresh.py tests/api/routers/test_admin_person_profile.py`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && pytest -q tests/api/test_cast_screentime_internal.py tests/api/test_sync_cast_from_trr.py tests/unit/test_trr_ingest.py`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && ruff check apps/api/services/supabase_db.py apps/api/services/trr_metadata_db.py apps/api/services/trr_ingest.py apps/api/services/cast_screentime.py apps/api/routers/cast_screentime.py apps/api/routers/episodes.py apps/api/routers/config.py apps/api/routers/metadata.py apps/api/routers/cast.py tests/api/test_cast_screentime_internal.py tests/api/test_sync_cast_from_trr.py tests/unit/test_trr_ingest.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run typecheck`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/show-admin-routes.test.ts tests/image-url-candidates.test.ts tests/person-gallery-detail-priority.test.ts tests/backend-base.test.ts tests/proxy-person-showid.test.ts tests/reddit-community-view-page.test.tsx tests/brand-logo-options-modal.test.tsx tests/person-refresh-request-id-wiring.test.ts tests/admin-host-middleware.test.ts tests/admin-global-header.test.tsx tests/bravotv-image-run-panel-wiring.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run lint`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run test:ci`
