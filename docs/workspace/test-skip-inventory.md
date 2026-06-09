# Test Skip Inventory

Date: 2026-05-21

This is the Phase 0 disposition table for current skip, skipIf, and xfail-style test declarations under:

- `TRR-Backend/tests`
- `TRR-APP/apps/web/tests`

The exact inventory command from `plan.md` currently finds 18 matches in this checkout. A broader skip scan that also includes `skipif` and Vitest `skipIf` finds 21 skip-style declarations. The earlier "31 skipped/xfail-style tests" review count is stale against the current files, likely because several earlier skipped app tests have already been restored.

No `xfail` declarations were found in the inspected test roots.

## Disposition Table

| File | Test/scope | Current skip reason | Disposition | Priority | Owner/surface | Next action |
| --- | --- | --- | --- | --- | --- | --- |
| `TRR-APP/apps/web/tests/nyt-homepage-preview-route.test.ts` | `serves distinct Watch Today's Videos and More News fragments` | `it.skipIf(!HAS_BUNDLE)` because the NYT source bundle exists in the full workspace but not every standalone app checkout. | Intentionally live-only | P3 | Design-doc preview route | Keep opt-in unless the source bundle becomes a committed app fixture or CI artifact; document `NYT_HOMEPAGE_SOURCE_BUNDLE` dependency near the route docs. |
| `TRR-APP/apps/web/tests/nyt-homepage-preview-route.test.ts` | `resolves the Wirecutter package without falling through to nav labels` | `it.skipIf(!HAS_BUNDLE)` because the NYT source bundle may be absent. | Intentionally live-only | P3 | Design-doc preview route | Same as above: keep bundle-gated, or promote the minimum fixture needed for standalone CI. |
| `TRR-APP/apps/web/tests/nyt-homepage-preview-route.test.ts` | `resolves the Games package as its own homepage module` | `it.skipIf(!HAS_BUNDLE)` because the NYT source bundle may be absent. | Intentionally live-only | P3 | Design-doc preview route | Same as above: keep bundle-gated, or promote the minimum fixture needed for standalone CI. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | Live cast smoke suite gate | `test.skip(!LIVE_ENABLED, "Set E2E_CAST_LIVE=1 to run live cast smoke tests.")` | Intentionally live-only | P2 | Live admin cast smoke tests | Keep opt-in; list the required environment variables in live smoke docs or the Playwright README. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | Live cast smoke base URL gate | `test.skip(!LIVE_BASE_URL, "Set PLAYWRIGHT_BASE_URL for live cast smoke tests.")` | Intentionally live-only | P2 | Live admin cast smoke tests | Keep opt-in; require an explicit admin base URL for this suite. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | Live cast smoke authenticated state gate | `test.skip(!LIVE_STORAGE_STATE, "Set PLAYWRIGHT_STORAGE_STATE for authenticated live cast smoke tests.")` | Intentionally live-only | P2 | Live admin cast smoke tests | Keep opt-in; make the authenticated storage-state setup discoverable. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | Live cast smoke show id gate | `test.skip(!LIVE_SHOW_ID, "Set E2E_CAST_SHOW_ID for live cast smoke tests.")` | Intentionally live-only | P2 | Live admin cast smoke tests | Keep opt-in; require a known show id so the test does not depend on seeded local data. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | `show role-editor deep-link timing behavior` person id gate | `test.skip(!LIVE_PERSON_ID, "Set E2E_CAST_PERSON_ID to validate role-editor deep-link timing.")` | Intentionally live-only | P2 | Live admin cast smoke tests | Keep opt-in; add a stable live smoke fixture/person id before making this part of default E2E. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | `show cast per-person refresh can be canceled` no-control gate | `test.skip(refreshCount === 0, "No cast member refresh controls available for this show.")` | Intentionally live-only | P3 | Live admin cast smoke tests | Keep as data-dependent live guard; choose a show fixture with refresh controls to reduce skips. |
| `TRR-APP/apps/web/tests/e2e/admin-cast-tabs-live-smoke.spec.ts` | `show cast per-person refresh can be canceled` fast-completion gate | `test.skip(!cancelVisible, "Refresh finished too quickly to exercise cancel behavior.")` | Intentionally live-only | P3 | Live admin cast smoke tests | Keep as runtime-timing guard; split cancel behavior into a mocked/local test if this needs deterministic coverage. |
| `TRR-Backend/tests/repositories/test_credits_integration.py` | Module-level DB integration suite; 6 collected tests | `pytest.mark.skipif(..., reason="RUN_DB_TESTS not enabled - set RUN_DB_TESTS=1 to run integration tests")` | Intentionally live-only | P2 | Backend credits integration | Keep opt-in until a seeded local Supabase test database is part of the default gate; document prerequisites already listed in the file. |
| `TRR-Backend/tests/repositories/test_social_account_catalog_backfill_integration.py` | Module-level DB integration test; 1 collected test | `pytest.mark.skipif(..., reason="RUN_DB_TESTS not enabled - set RUN_DB_TESTS=1 to run integration tests")` | Intentionally live-only | P2 | Backend social catalog integration | Keep opt-in; run with `RUN_DB_TESTS=1` only against local Supabase with migrations and cleanup-safe seed data. |
| `TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py` | `test_instagram_comments_post_comment_unique_constraint_exists` fixture fallback | `pytest.skip("live test DB is unavailable in this workspace")` from `live_test_db` fixture | Intentionally live-only | P1 | Backend Instagram comment identity contract | Keep the DB-availability guard; consider moving this one into the explicit `RUN_DB_TESTS` lane so local default runs are less surprising. |
| `TRR-Backend/tests/repositories/test_show_images_dual_write.py` | `test_show_images_dual_write_failure_does_not_break` | `Dual-write not yet implemented in show_images.py - Phase 2 future work` | Future work | P2 | Backend media dual-write | Leave skipped until `ENABLE_MEDIA_DUAL_WRITE` has real implementation; re-enable as part of media dual-write delivery. |
| `TRR-Backend/tests/repositories/test_show_images_dual_write.py` | `test_show_images_dual_write_disabled_by_default` | `Dual-write not yet implemented in show_images.py - Phase 2 future work` | Future work | P2 | Backend media dual-write | Leave skipped until media dual-write exists; then prove the legacy table write remains the default path. |
| `TRR-Backend/tests/repositories/test_credits.py` | `TestCreditsValidationViews`; 2 placeholder tests | `Integration test - requires Supabase with credits tables` | Future work | P2 | Backend credits validation views | Convert placeholders into real DB-backed assertions or delete them in favor of `test_credits_integration.py`; do not keep skipped placeholder coverage long term. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage1_tmdb_list_ingestion_persists_tv_details_into_tmdb_meta` | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite against `core.shows.tmdb_meta` and typed TMDb columns. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage1_tmdb_no_details_avoids_tv_details_fetch` | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite against the current normalized metadata persistence path. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage1_tmdb_details_4xx_is_non_fatal`; 2 parameterized cases | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite as current TMDb detail-fetch failure coverage that does not mention legacy JSONB. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage1_tmdb_external_ids_fill_missing_but_preserve_existing` | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite around current `imdb_id`, `tmdb_id`, metadata, and typed field preservation. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage1_tmdb_details_skips_when_fresh` | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite against the current freshness signal for normalized TMDb metadata. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage2_uses_tmdb_meta_and_does_not_refetch_tv_details` | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite using `core.shows.tmdb_meta` and current enrichment cache behavior. |
| `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py` | `test_stage2_multiple_shows_does_not_refetch_tv_details_when_tmdb_meta_present` | `Legacy test: external_ids JSONB removed in schema normalization` | Obsolete/delete | P1 | Backend TMDb persistence | Delete or rewrite as multi-show normalized metadata cache coverage. |

## Restore-Now Candidates

No current skip declaration is safe to classify as `restore now` without changing tests or product code.

The earlier P1 restore candidates were completed in this Phase 0 implementation slice:

- `TRR-APP/apps/web/tests/system-health-modal.test.tsx` now runs against the current live-status envelope and polling fallback.
- `TRR-APP/apps/web/tests/social-week-detail-wiring.test.ts` now runs the three previously skipped week-detail wiring checks against the current source shape.

## Deferred Items Left Untouched

- The P1 admin live-status and social-week wiring skips were re-enabled in this Phase 0 slice.
- No source code, scripts, branches, or worktrees were changed by this test-skip inventory slice. The broader workspace may contain unrelated dirty changes that require separate review.
- Modal update was not needed because this is documentation-only and does not affect backend, worker, scraper, job, runtime, or Modal secret-preparation code.

## Validation Commands

```bash
rg -n "\\b(describe|it|test)\\.skip\\b|pytest\\.mark\\.(skip|xfail)\\b|@pytest\\.mark\\.(skip|xfail)\\b|\\bskip\\(" TRR-Backend/tests TRR-APP/apps/web/tests -S
```

Result: 18 matches.

```bash
rg -n "skipif|pytestmark|\\.skip\\b|pytest\\.mark\\.(skip|xfail)|pytest\\.skip|test\\.skip|describe\\.skip|it\\.skip" TRR-Backend/tests TRR-APP/apps/web/tests -S
```

Result: 21 matches.
