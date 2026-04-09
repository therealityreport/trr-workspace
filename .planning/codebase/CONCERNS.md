# Codebase Concerns

**Analysis Date:** 2026-04-08

## Tech Debt

**Backend social analytics control plane is concentrated in one 52k-line repository module:**
- Issue: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` carries ingest scheduling, worker health, remote-auth probing, queue alerting, shard planning, dispatch policy, and platform-specific runtime rules in a single file.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Impact: small changes have wide blast radius across queueing, social ingest, worker health, and dispatch logic; review cost is high and defect isolation is slow.
- Fix approach: split by responsibility first, not by platform. Extract `dispatch/`, `worker_health/`, `shared_account_recovery/`, and `window_sharding/` modules behind a stable repository facade, then pin each extraction with targeted tests instead of growing the single integration-heavy test file.

**Backend admin image workflow is still a single router-sized control plane:**
- Issue: `TRR-Backend/api/routers/admin_person_images.py` is about 17k lines and mixes request models, Getty/Bravo/IMDb ingestion, face-box assignment, crop generation, runtime batching, and operational progress reporting in one route module.
- Files: `TRR-Backend/api/routers/admin_person_images.py`, `TRR-Backend/tests/api/routers/test_admin_person_images.py`, `TRR-Backend/tests/api/routers/test_admin_person_images_auto_count_enrichment.py`
- Impact: regression risk stays high for admin media workflows because route edits can accidentally affect matching, enrichment, batching, and persistence behavior in the same file.
- Fix approach: extract provider adapters and auto-count orchestration into service modules, keep router code limited to request validation and response shaping, and convert provider-specific logic into separately tested units.

**TRR-APP admin surfaces remain large page-level monoliths:**
- Issue: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` is about 17k lines and `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx` is about 12.7k lines, each carrying data shaping, polling, layout composition, and mutation handlers together.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
- Impact: page changes are expensive to reason about, local refactors are risky, and behavioral reuse is limited because the domain logic is page-owned instead of hook/service-owned.
- Fix approach: move normalization, polling controllers, and mutation flows into `src/lib/admin/*` or component-local hooks; keep page files as composition shells.

## Known Bugs

**Show asset gallery has a hard truncation ceiling instead of full result coverage:**
- Symptoms: the show admin page fetches gallery rows in pages, but stops after `GALLERY_ASSET_PAGE_SIZE = 500` and `GALLERY_ASSET_MAX_PAGES = 30`, warning that only the first batch is shown.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/tests/show-gallery-pagination.test.ts`
- Trigger: shows or seasons with more than 15,000 gallery rows.
- Workaround: narrow filters before loading the gallery.

## Security Considerations

**Legacy Screenalytics compatibility routes still accept two auth mechanisms by default:**
- Risk: `TRR-Backend/api/screenalytics_auth.py` accepts either `SCREENALYTICS_SERVICE_TOKEN` or an internal-admin token, and the service-token fallback is enabled by default through `TRR_SCREENALYTICS_ALLOW_SERVICE_TOKEN_FALLBACK`.
- Files: `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/api/routers/screenalytics.py`, `TRR-Backend/api/routers/screenalytics_runs_v2.py`, `TRR-Backend/api/routers/admin_cast_screentime.py`, `screenalytics/apps/api/main.py`, `screenalytics/tests/unit/test_startup_config.py`
- Current mitigation: token comparison uses `hmac.compare_digest`, and internal-admin token verification is available.
- Recommendations: turn fallback off by default, make route families choose one auth mechanism each, and remove `SCREENALYTICS_SERVICE_TOKEN` from deployed runtime once the remaining compatibility callers are retired.

## Performance Bottlenecks

**Large admin pages rely on page-local parsing and orchestration instead of narrower data services:**
- Problem: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` and `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx` perform heavy in-file normalization, derived-state computation, and request orchestration.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/lib/admin/show-page/use-show-identity-load.ts`
- Cause: UI composition and domain logic are tightly coupled, so render code also owns transformation and polling logic.
- Improvement path: extract data adapters and polling managers into hooks/services, then memoize boundaries where data shape changes instead of in the page component.

## Fragile Areas

**Screenalytics startup has side effects before the app is considered ready:**
- Files: `screenalytics/apps/api/main.py`
- Why fragile: `_cleanup_stale_jobs()` rewrites progress files, removes file locks, marks zombie jobs failed, and deletes Redis audio locks during app startup. These mutations happen before normal request handling and do not have dedicated test coverage.
- Safe modification: treat startup cleanup as an operational subsystem. Move cleanup into explicit admin/maintenance jobs or gate it behind a feature flag with test coverage before changing logic.
- Test coverage: no direct tests were found for `_cleanup_stale_jobs()` in `screenalytics/tests/`.

**Screenalytics episode router is a single filesystem/S3/API control plane:**
- Files: `screenalytics/apps/api/routers/episodes.py`, `screenalytics/tests/api/test_episodes_list_and_mirror.py`, `screenalytics/tests/api/test_screentime_qa.py`
- Why fragile: the router owns local path resolution, S3 reads, run scoping, manifest inspection, state derivation, export locks, and request models in one file of about 11k lines.
- Safe modification: extract storage/path helpers and run-state readers into service modules first, then shrink the router to request/response code.
- Test coverage: endpoint coverage exists, but a large share of the file remains helper-heavy and router-coupled.

## Scaling Limits

**Show gallery pagination caps out at 15,000 rows per request path:**
- Current capacity: 500 rows per page times 30 pages.
- Limit: the admin show gallery truncates beyond that and relies on a warning message rather than full retrieval.
- Scaling path: move to cursor-based pagination in the UI and API, or add server-side filter-first queries so the client never attempts broad full-gallery scans.

## Dependencies at Risk

**Screenalytics deploy health depends on optional runtime dependencies and fallback stubs:**
- Risk: `screenalytics/apps/api/main.py` catches missing Celery imports, registers a 503 stub router, and still allows the app to start. The basic `/health` endpoint always returns `{"status":"ok"}`.
- Impact: partial deployments can look healthy to orchestration while background-job capability is missing.
- Migration plan: make required worker dependencies explicit per environment, use `/readyz` for probes, and fail startup when expected background features are unavailable.

## Missing Critical Features

**Screenalytics retirement is documented as active, but compatibility surfaces remain broad and live:**
- Problem: the current ledger marks `TRR-Backend/api/routers/screenalytics.py`, `TRR-Backend/api/routers/screenalytics_runs_v2.py`, `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/trr_backend/clients/screenalytics.py`, `screenalytics/apps/api/main.py`, and `screenalytics/apps/workspace-ui` as transitional, compatibility-only, or archive/delete targets, yet these surfaces are still present in the runtime codebase.
- Blocks: final secret retirement, clean route ownership, and a clear answer to whether Screenalytics is a live service, a donor codebase, or an archive.

## Test Coverage Gaps

**Several TRR-APP admin tests verify source text instead of runtime behavior:**
- What's not tested: actual behavior of large show/person admin surfaces after refactors; many tests assert that specific strings or code fragments still exist.
- Files: `TRR-APP/apps/web/tests/show-bravo-video-thumbnail-wiring.test.ts`, `TRR-APP/apps/web/tests/show-settings-links-fandom-visibility.test.ts`, `TRR-APP/apps/web/tests/show-gallery-pagination.test.ts`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
- Risk: a behavior can break while a source-shape test still passes, or harmless refactors can fail tests without changing user-visible behavior.
- Priority: High

**Startup recovery logic in Screenalytics lacks dedicated tests despite mutating job state:**
- What's not tested: the file-lock cleanup, zombie-job rewrite, and Redis lock deletion path in `_cleanup_stale_jobs()`.
- Files: `screenalytics/apps/api/main.py`
- Risk: a startup change can silently corrupt local job state or hide restart issues without automated detection.
- Priority: High

---

*Concerns audit: 2026-04-08*
