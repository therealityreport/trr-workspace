# Codebase Concerns

**Analysis Date:** 2026-04-04

## Tech Debt

**Workspace Orchestration Script:**
- Issue: `scripts/dev-workspace.sh` centralizes profile loading, DB lane selection, local secret derivation, process supervision, watchdog state, Modal dispatch wiring, browser sync, and Screenalytics startup in one `1619`-line shell script.
- Files: `scripts/dev-workspace.sh`, `docs/workspace/env-contract.md`
- Impact: Small startup or env-contract changes can break all three repos at once. The script is difficult to review, hard to test, and easy to regress because one file owns the entire local runtime matrix.
- Fix approach: Split the script into sourced modules for env resolution, process lifecycle, health/watchdog logic, and browser automation. Add shell smoke tests around profile parsing, pidfile updates, watchdog restart behavior, and per-repo startup contracts.

**Cross-Repo Auth Contract Overlap:**
- Issue: Screenalytics-to-backend auth accepts either the legacy `SCREENALYTICS_SERVICE_TOKEN` or an internal-admin JWT, while Screenalytics service clients still build bearer auth from `SCREENALYTICS_SERVICE_TOKEN` and the app keeps separate client and server admin allowlists.
- Files: `TRR-Backend/api/screenalytics_auth.py`, `screenalytics/apps/api/services/trr_ingest.py`, `screenalytics/apps/api/services/cast_screentime.py`, `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/lib/admin/client-access.ts`
- Impact: Secret rotation, debugging, and permission analysis stay harder than necessary because there is no single service-to-service auth path. Cross-repo behavior can drift when one caller migrates and another stays on the legacy token contract.
- Fix approach: Pick one service auth contract for cross-repo calls, retire the other, and keep admin allowlists authoritative on the server only.

**Monolithic Domain Files:**
- Issue: Several core files combine routing, data access, orchestration, and UI composition at very large sizes.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` (`49353` lines), `TRR-Backend/api/routers/admin_person_images.py` (`17224` lines), `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` (`17279` lines), `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx` (`9213` lines), `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts` (`5896` lines), `screenalytics/tools/episode_run.py` (`23480` lines), `screenalytics/apps/api/routers/episodes.py` (`11059` lines), `screenalytics/apps/api/services/grouping.py` (`5149` lines)
- Impact: Review time, onboarding time, and change blast radius are all high. Localized fixes become risky because unrelated logic shares the same file and import graph.
- Fix approach: Extract domain slices behind stable façades. Preserve existing route/function signatures, but move storage access, orchestration, and view helpers into narrower modules.

**Tracked Generated Surface Area:**
- Issue: Generated API artifacts are committed and large, but the refresh path is manual.
- Files: `screenalytics/web/openapi.json`, `screenalytics/web/api/schema.ts`, `screenalytics/docs/plans/in_progress/web_app/MIGRATION_ROADMAP.md`
- Impact: Client types and API docs can drift from the running FastAPI surface without an automatic CI failure. Large generated diffs also make review noisier.
- Fix approach: Add a CI check that regenerates the OpenAPI artifacts and fails on drift.

## Known Bugs

**Screenalytics Sync Stage Is Intentionally Skipped:**
- Symptoms: The TRR pipeline never ingests Screenalytics results in stage 6.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`
- Trigger: Any pipeline run that expects Screenalytics output to flow back into TRR state.
- Workaround: None in code. The stage returns `SKIPPED` and prints that it is a stub when verbose mode is enabled.

**TRR Cast Sync Returns Partial Results Only:**
- Symptoms: The Screenalytics cast sync endpoint reports `status="partial"` and `total_trr_cast=0`, with an error message stating that TRR cast tables are not yet populated.
- Files: `screenalytics/apps/api/routers/episodes.py`
- Trigger: Calling the cast sync flow for an episode or trailer.
- Workaround: Facebank image import side effects still run for eligible inputs, but cast record creation and updates do not happen.

**Audio Smart Split Auto-Assign Is Disabled:**
- Symptoms: Smart Split falls back to basic splitting and logs that auto-assign is temporarily unavailable.
- Files: `screenalytics/apps/api/routers/audio.py`
- Trigger: Calling Smart Split with `auto_assign=true`.
- Workaround: Manual follow-up assignment after the split.

**Queued `diarize_only` Mode Falls Back To Sync Execution:**
- Symptoms: Queue mode advertises a Celery path, but the code still executes locally with progress streaming semantics.
- Files: `screenalytics/apps/api/routers/audio.py`
- Trigger: Running the `diarize_only` flow in queue mode.
- Workaround: Use the synchronous path and treat queue mode as not yet implemented.

**Survey Creation UI Is Placeholder-Only:**
- Symptoms: The admin surveys page shows a “coming soon” alert instead of a create flow.
- Files: `TRR-APP/apps/web/src/app/admin/surveys/page.tsx`
- Trigger: Clicking `+ New Survey`.
- Workaround: None in the UI.

## Security Considerations

**Client-Visible Admin Allowlists:**
- Risk: Admin emails, UIDs, and display names can be distributed to the browser through `NEXT_PUBLIC_*` variables and then mirrored into client-side allowlist helpers.
- Files: `TRR-APP/apps/web/src/lib/admin/client-access.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`
- Current mitigation: Server-side auth still exists and host enforcement is on by default.
- Recommendations: Keep allowlists server-only, reduce client-visible admin identity data, and use server responses to indicate admin capability instead of shipping allowlist entries to the browser.

**Deterministic Local Shared Secrets:**
- Risk: Local fallback secrets are derived from `ROOT`, `USER`, and a label rather than generated randomly per session.
- Files: `scripts/dev-workspace.sh`, `docs/workspace/env-contract.md`
- Current mitigation: The derived secrets are meant for local development only.
- Recommendations: Ensure these values never cross into shared environments, rotate to random local secrets when feasible, and document that they are convenience defaults rather than hard security boundaries.

**Local Credential Footprint In Workspace Tree:**
- Risk: Local secret-bearing files exist in common workspace locations, which raises accidental disclosure risk through tooling, screenshots, or ad-hoc scripts.
- Files: `TRR-Backend/keys/`, `TRR-Backend/.env`, `screenalytics/.env`, `.logs/workspace/`
- Current mitigation: `TRR-Backend/.gitignore` ignores `keys/`, and repo `.gitignore` files ignore `.env` files.
- Recommendations: Keep credential files outside repo trees when possible, periodically sweep `.logs/workspace/` and other generated state, and add a secret-scanning check to local verification flows.

## Performance Bottlenecks

**Backend Social Analytics Repository Is Too Large For Fast Iteration:**
- Problem: A single repository module plus a single matching test file absorb a large share of the backend social stack.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Cause: Query logic, queue orchestration, dispatch accounting, provider logic, and status derivation live together.
- Improvement path: Split provider-specific behavior, queue accounting, and analytics read models into separate modules with narrower tests.

**Admin TRR Shows Surface Concentrates Too Much UI State:**
- Problem: The admin show pages and social-week view are large enough that small UI changes carry a high render and regression-review cost.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
- Cause: Route loading, tab composition, state coordination, and action wiring are mixed inside giant page components.
- Improvement path: Extract server loaders, route action handlers, and tab/view components into smaller entry points and keep page files thin.

**Screenalytics Episode Pipeline Work Remains CPU-Heavy And Highly Coupled:**
- Problem: Detection, grouping, export, and run orchestration remain concentrated in a few large Python modules.
- Files: `screenalytics/tools/episode_run.py`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/api/services/grouping.py`, `screenalytics/apps/api/services/run_export.py`
- Cause: Pipeline stages, file I/O, clustering, and API response shaping are still tightly coupled.
- Improvement path: Isolate stage executors, data loaders, and persistence adapters so hot-path optimizations do not require touching the full pipeline file.

## Fragile Areas

**Modal Dispatch And Remote Job Plane:**
- Files: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/modal_dispatch.py`, `TRR-Backend/trr_backend/modal_jobs.py`, `scripts/dev-workspace.sh`
- Why fragile: Runtime behavior depends on many env gates and lane checks across backend and workspace startup. Local, remote, and Modal-owned execution are all valid modes.
- Safe modification: Change one execution mode at a time and verify startup config, dispatch selection, and recovery behavior together.
- Test coverage: `TRR-Backend/tests/test_modal_dispatch.py`, `TRR-Backend/tests/test_modal_jobs.py`, and repository tests cover portions of dispatch logic, but there is no direct automated coverage for the workspace script that wires the env matrix together.

**Admin Host/Auth Enforcement Path:**
- Files: `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/proxy.ts`, `TRR-APP/apps/web/src/lib/admin/client-access.ts`
- Why fragile: Admin host routing, local bypass behavior, server allowlists, and client allowlists all participate in access decisions.
- Safe modification: Treat auth and host-routing changes as cross-cutting changes and verify both browser-facing routes and server route guards.
- Test coverage: `TRR-APP/apps/web/tests/server-auth-adapter.test.ts`, `TRR-APP/apps/web/tests/admin-host-middleware.test.ts`, and `TRR-APP/apps/web/tests/client-admin-access.test.ts` cover parts of the surface, but the duplication itself remains a drift risk.

**Screenalytics Grouping Logic:**
- Files: `screenalytics/apps/api/services/grouping.py`, `screenalytics/tests/api/test_single_track_suggestions.py`, `screenalytics/tests/api/test_cluster_cleanup_progress.py`, `screenalytics/tests/api/test_grouping_legacy_format.py`
- Why fragile: Several tests assert source text or regex patterns in `grouping.py` instead of exercising runtime behavior, which makes refactors fail even when behavior is preserved.
- Safe modification: Replace text-inspection tests with behavior-level fixtures before large refactors.
- Test coverage: There are many grouping tests, but a meaningful slice is structure-based rather than behavior-based.

## Scaling Limits

**Realtime Broker Defaults To In-Memory:**
- Current capacity: One-process or single-instance semantics when `REDIS_URL` is unset.
- Limit: Multi-instance realtime delivery and ephemeral presence state do not scale safely on `InMemoryBroker`.
- Scaling path: Require Redis for any multi-worker or multi-instance realtime deployment and verify the fallback is local-dev-only.
- Files: `TRR-Backend/api/realtime/broker.py`, `TRR-Backend/start-api.sh`

**Screenalytics DB-Backed Features Hard-Fail Without TRR-Compatible Postgres:**
- Current capacity: DB-backed metadata and persistence work only when `TRR_DB_URL` or `TRR_DB_FALLBACK_URL` resolve to a supported lane and `psycopg2` is installed.
- Limit: Startup and feature availability diverge across local and deployed environments; local/dev can boot in a degraded mode where DB-backed features remain unavailable.
- Scaling path: Make DB availability a first-class readiness contract for the features that require it, and reduce the number of mixed degraded/fully-wired runtime modes.
- Files: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/apps/api/services/run_persistence.py`

## Dependencies at Risk

**`psycopg2` As Optional Runtime Dependency In Screenalytics:**
- Risk: Core DB services compile and import without `psycopg2`, but meaningful DB-backed features then fail at runtime.
- Impact: The same codebase behaves differently across developer machines, CI contexts, and deployed environments.
- Migration plan: Make the dependency explicit for runtimes that need Postgres features, or isolate fake/in-memory persistence behind clearer test-only entry points.
- Files: `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/apps/api/services/run_persistence.py`, `screenalytics/apps/api/services/trr_ingest.py`

**Optional Media Conversion Stack In Backend Asset Mirroring:**
- Risk: SVG/PNG conversion silently degrades when `cairosvg` or Pillow are missing or erroring.
- Impact: Media mirroring can succeed partially without guaranteed raster conversion, which makes asset behavior less predictable.
- Migration plan: Promote conversion dependencies to explicit install requirements for the relevant jobs, or log structured failure modes instead of returning `None`.
- Files: `TRR-Backend/trr_backend/media/s3_mirror.py`

## Missing Critical Features

**TRR Ingestion Of Screenalytics Manifests:**
- Problem: The pipeline stage responsible for ingesting Screenalytics output back into TRR is a stub.
- Blocks: End-to-end Screenalytics result synchronization from completed runs into TRR-owned state.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`

**TRR Cast Table-Backed Sync:**
- Problem: Screenalytics expects TRR cast tables that are not populated, so full cast sync stays unavailable.
- Blocks: Reliable episode/season cast synchronization and downstream cast-aware automation.
- Files: `screenalytics/apps/api/routers/episodes.py`

**Audio Queue Completion Paths:**
- Problem: Smart Split auto-assignment and queued `diarize_only` execution both remain unimplemented.
- Blocks: Stable async audio workflows and full parity between synchronous and queued paths.
- Files: `screenalytics/apps/api/routers/audio.py`

## Test Coverage Gaps

**Workspace Runtime Scripts:**
- What's not tested: Direct automation coverage for workspace startup, pidfile/state writing, browser sync state, and watchdog restart behavior.
- Files: `scripts/dev-workspace.sh`, `scripts/status-workspace.sh`, `scripts/stop-workspace.sh`
- Risk: Cross-repo local runtime regressions surface only during manual startup.
- Priority: High

**Screenalytics Service Auth Dependency:**
- What's not tested: Direct tests for `require_screenalytics_service_token` and its dual-mode token/JWT behavior.
- Files: `TRR-Backend/api/screenalytics_auth.py`
- Risk: Auth regressions can slip through while startup config tests continue to pass.
- Priority: High

**Unimplemented Sync Stage:**
- What's not tested: There is no meaningful behavior-level coverage for a completed Screenalytics-to-TRR sync path because the path is still a stub.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`
- Risk: The eventual implementation starts from an uncovered integration boundary.
- Priority: High

**Structure-Based Tests In Place Of Behavior Tests:**
- What's not tested: Runtime behavior for parts of Screenalytics grouping and cleanup logic; several tests instead inspect source strings and regex matches.
- Files: `screenalytics/tests/api/test_single_track_suggestions.py`, `screenalytics/tests/api/test_cluster_cleanup_progress.py`, `screenalytics/tests/api/test_grouping_legacy_format.py`, `screenalytics/apps/api/services/grouping.py`
- Risk: Refactors remain expensive while true behavioral regressions can still hide behind source-shape assertions.
- Priority: Medium

---

*Concerns audit: 2026-04-04*
