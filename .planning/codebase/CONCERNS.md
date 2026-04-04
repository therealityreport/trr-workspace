# Codebase Concerns

**Analysis Date:** 2026-04-04

## Tech Debt

**Backend social ingest monolith:**
- Issue: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` is `49,158` lines with roughly `969` top-level `def`/`class` declarations and mixes platform adapters, queue coordination, auth preflight, DB writes, caching, and retry logic in one module.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/api/routers/socials.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Impact: small changes carry a large regression radius, import and test time stay high, and queue/auth bugs are hard to isolate from persistence bugs.
- Fix approach: split by responsibility first: ingest orchestration, per-platform fetchers, persistence/reconciliation, and shared read models.

**Screenalytics execution and UI monoliths:**
- Issue: `screenalytics/tools/episode_run.py` is `23,480` lines, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py` is `12,807` lines, and `screenalytics/apps/workspace-ui/ui_helpers.py` is `9,020` lines; these files carry CLI wiring, ML orchestration, UI state, and operational fallbacks together.
- Files: `screenalytics/tools/episode_run.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/ui_helpers.py`
- Impact: startup behavior, pipeline control flow, and Streamlit rendering are tightly coupled; localized fixes are difficult and code review cost is high.
- Fix approach: extract typed service layers for pipeline state, artifact IO, and UI-specific adapters, then shrink the page/CLI entrypoints into composition shells.

**TRR-APP admin page concentration:**
- Issue: several admin surfaces remain page-sized application modules instead of composed feature slices.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`, `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
- Impact: route changes mix data loading, UI state, and mutation plumbing; test coverage exists, but maintenance cost stays high and behavior drifts across pages.
- Fix approach: move route data loaders and mutation adapters into reusable server modules, then break page clients into smaller feature sections with explicit contracts.

## Known Bugs

**Stage 6 Screenalytics sync is still a stub:**
- Symptoms: the pipeline marks Screenalytics sync as `SKIPPED` instead of ingesting results.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/tests/pipeline/test_stages.py`
- Trigger: any run that reaches Stage 6.
- Workaround: none in the pipeline itself; downstream ingestion has to happen out-of-band.

**Audio smart split and queued re-diarization are incomplete:**
- Symptoms: smart split auto-assignment is intentionally disabled during the NeMo migration, and `diarize_only` queue mode still falls back to synchronous behavior.
- Files: `screenalytics/apps/api/routers/audio.py`
- Trigger: Smart Split with `auto_assign`, or queued `diarize_only` flows.
- Workaround: use the synchronous path and manual reassignment.

## Security Considerations

**Public debug endpoint accepts the raw shared admin secret:**
- Risk: `TRR-APP/apps/web/src/app/api/debug-log/route.ts` authorizes either `requireAdmin()` or a raw `x-trr-internal-admin-secret` header, and the accepted secret is the same `TRR_INTERNAL_ADMIN_SHARED_SECRET` used to mint backend internal-admin JWTs.
- Files: `TRR-APP/apps/web/src/app/api/debug-log/route.ts`, `TRR-APP/apps/web/tests/debug-log-route.test.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/trr_backend/security/internal_admin.py`
- Current mitigation: payload redaction and the normal admin-session path still exist.
- Recommendations: remove raw-secret header auth from the app route, use a dedicated debug-only credential if the endpoint must remain, and gate the route behind environment-based disablement plus audit logging.

**Admin proxy routes disclose backend topology in client-visible errors:**
- Risk: multiple admin routes append `TRR_API_URL` to response details; tests assert that behavior today.
- Files: `TRR-APP/apps/web/src/app/api/admin/networks-streaming/sync/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/refresh/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts`, `TRR-APP/apps/web/tests/networks-streaming-sync-proxy-route.test.ts`
- Current mitigation: the routes are admin-facing.
- Recommendations: keep backend URL hints in server logs only, return a correlation/request ID to the UI, and add regression tests that forbid origin leakage.

**Internal admin trust is coupled to one symmetric secret:**
- Risk: `TRR-APP` signs HS256 JWTs with `TRR_INTERNAL_ADMIN_SHARED_SECRET`, and `TRR-Backend` also uses that secret to verify internal admin callers and some Screenalytics compatibility flows.
- Files: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/trr_backend/security/internal_admin.py`, `TRR-Backend/api/screenalytics_auth.py`
- Current mitigation: issuer, audience, scope, and short token TTL (`120` seconds) are validated.
- Recommendations: move to asymmetric signing or per-caller secrets so compromise of one service does not create a workspace-wide trust break.

## Coupling Problems

**TRR-APP duplicates proxy transport logic across many admin routes:**
- Problem: timeout handling, auth header wiring, and backend error formatting are repeated route-by-route instead of going through one hardened proxy utility.
- Files: `TRR-APP/apps/web/src/app/api/admin/networks-streaming/sync/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/refresh/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Impact: fixes for auth, observability, retry, or redaction need to be reimplemented in many places and will drift.
- Fix approach: centralize proxy request/response shaping in one server-only helper and keep routes thin.

**Backend social ingest couples platform fetch, job-plane control, and persistence in one seam:**
- Problem: Modal dispatch, Crawlee auth preflight, and SQL persistence live in the same repository module.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Impact: platform-specific changes can destabilize queue orchestration or database correctness.
- Fix approach: push queue/runtime concerns behind interfaces and keep repository code focused on read/write boundaries.

## Operational Risks

**Cross-repo delivery depends on manual workflow discipline:**
- Risk: the formal process requires task-folder creation, status updates, ordered repo sequencing, and explicit handoff syncing.
- Files: `AGENTS.md`, `docs/cross-collab/WORKFLOW.md`, `scripts/handoff-lifecycle.sh`, `scripts/sync-handoffs.py`
- Impact: repo order or handoff drift can break shared contracts without tooling catching it immediately.
- Fix approach: encode more of the required sequence in CI or scripted release gates rather than relying on documentation and agent memory.

**Workspace validation under-tests the heaviest repo:**
- Risk: the workspace runners only `py_compile` two Screenalytics entrypoints and run `tests/api/test_trr_health.py`, while the repo’s most fragile logic lives in large Streamlit/API/ML modules.
- Files: `scripts/test.sh`, `scripts/test-fast.sh`, `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/tests/`
- Impact: root-level green checks do not mean Screenalytics behavior is safe.
- Fix approach: expand workspace smoke coverage to include a representative Screenalytics unit/UI/API subset instead of health-only validation.

**Workspace-only changes can bypass meaningful runtime checks:**
- Risk: `scripts/test-changed.sh` treats root `docs/`, `scripts/`, and policy changes as workspace-only and may run policy checks or `test-fast` instead of deeper cross-repo verification.
- Files: `scripts/test-changed.sh`, `scripts/test-fast.sh`
- Impact: launcher, handoff, env-contract, and workspace orchestration regressions can slip through with minimal validation.
- Fix approach: add a stronger workspace regression suite for shared scripts and orchestration paths.

## Performance Bottlenecks

**Backend social analytics hot path is oversized before work even starts:**
- Problem: `social_season_analytics.py` is large enough that import cost, review cost, and test setup overhead become part of every change.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Cause: one module owns most season-social behavior across platforms and execution modes.
- Improvement path: isolate hot-path read/write operations and per-platform implementations into smaller modules with narrower imports.

**Screenalytics Streamlit reruns pay for very large page modules:**
- Problem: Streamlit pages and helper modules are large and contain many conditional fallbacks, so reruns and debugging stay expensive.
- Files: `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/pages/3_Episode_Review.py`, `screenalytics/apps/workspace-ui/ui_helpers.py`
- Cause: UI composition, API access, and status calculation live together.
- Improvement path: move state derivation and API calls to smaller services so Streamlit pages mostly render.

**Local artifact sprawl pollutes discovery and analysis tools:**
- Problem: repo-root build and environment artifacts are present inside active repos, including Next build output, local Vercel output, and extra virtualenv content.
- Files: `TRR-APP/apps/web/.next`, `TRR-APP/apps/web/.next-e2e`, `TRR-APP/apps/web/.next-social-debug`, `TRR-APP/apps/web/.vercel`, `screenalytics/.venv-crawl4ai`, `TRR-Backend/tests/__pycache__`, `TRR-Backend/scripts/.DS_Store`
- Cause: local runtime artifacts live inside the workspace tree and generic search/test commands do not always prune them.
- Improvement path: harden ignore/prune rules, move disposable environments outside the repo tree where possible, and add cleanup gates to workspace scripts.

## Fragile Areas

**Screenalytics Streamlit pages use many silent `pass` paths:**
- Files: `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/pages/3_Episode_Review.py`, `screenalytics/apps/workspace-ui/pages/4_Screentime.py`, `screenalytics/apps/workspace-ui/ui_helpers.py`
- Why fragile: failure modes can be swallowed silently, leaving the UI degraded without a clear error signal.
- Safe modification: replace bare `pass` handling with typed exceptions or explicit logging, then pin behavior with focused tests.
- Test coverage: `screenalytics/tests/ui/` and `screenalytics/tests/unit/` are broad, but the workspace runner does not execute that breadth.

**Backend Screenalytics availability state is process-local:**
- Files: `TRR-Backend/trr_backend/clients/screenalytics.py`
- Why fragile: the temporary-unavailable cooldown is stored in module globals, so separate workers disagree about whether Screenalytics is down.
- Safe modification: move availability state and backoff into Redis or the database so workers share one view.
- Test coverage: no workspace-level regression check exercises multi-worker behavior.

**Generated/stubbed contracts can look healthy while still being incomplete:**
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/tests/pipeline/test_stages.py`, `TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts`
- Why fragile: generated or stubbed assets make code paths appear present even when the functional contract is missing.
- Safe modification: treat generated inventories as derived artifacts only and add end-to-end contract tests for the real pipeline stages.
- Test coverage: Stage 6 is explicitly tested only for stub behavior.

## Scaling Limits

**Social ingest defaults are still tuned for low concurrency:**
- Current capacity: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` defaults `DEFAULT_RUNNER_COUNT = 1` and `SOCIAL_JOB_CLAIM_BATCH_SIZE_DEFAULT = 2`.
- Limit: throughput gains rely on manually raising config in a module that also owns core business logic.
- Scaling path: move concurrency policy into dedicated queue/runtime config with per-platform worker pools and observability around claim/backlog pressure.

**Screenalytics unavailability backoff does not scale horizontally:**
- Current capacity: `TRR-Backend/trr_backend/clients/screenalytics.py` uses a default cooldown of `300` seconds, but each process tracks that window independently.
- Limit: horizontal scale produces inconsistent retry storms because each worker rediscovers failure on its own.
- Scaling path: centralize outage/backoff state and record upstream health in shared infra.

## Dependencies at Risk

**Optional runtime dependencies change behavior by environment:**
- Risk: important routes degrade based on whether optional packages are installed instead of a single explicit capability contract.
- Files: `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/ui_helpers.py`
- Impact: local, CI, and deployed environments can exercise different code paths without obvious configuration drift.
- Migration plan: define supported extras explicitly, fail fast for required capabilities, and keep optional features behind visible feature flags.

## Missing Critical Features

**Backend-to-Screenalytics result ingestion is not implemented:**
- Problem: the declared Stage 6 handoff from pipeline execution into persisted Screenalytics results does not exist.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`
- Blocks: a complete in-pipeline closeout for Screenalytics-backed runs.

**Queued audio rediarization is incomplete:**
- Problem: Smart Split auto-assign and queued `diarize_only` Celery execution are both deferred.
- Files: `screenalytics/apps/api/routers/audio.py`
- Blocks: reliable async remediation for audio labeling and speaker-correction workflows.

## Test Coverage Gaps

**Workspace runners do not reflect actual Screenalytics risk surface:**
- What's not tested: the large Screenalytics UI/API/service modules that change most often.
- Files: `scripts/test.sh`, `scripts/test-fast.sh`, `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`
- Risk: workspace-level green status hides regressions in the repo most dependent on optional ML/runtime behavior.
- Priority: High

**Stage 6 contract coverage only verifies the stub stays stubbed:**
- What's not tested: manifest ingestion, artifact parsing, or database upsert behavior for Screenalytics results.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/tests/pipeline/test_stages.py`
- Risk: the pipeline contract appears present in tests while the functional feature is absent.
- Priority: High

**Cross-repo proxy error hygiene is not protected as a security invariant:**
- What's not tested: a shared rule that admin proxy responses must not disclose backend URLs or internal topology.
- Files: `TRR-APP/apps/web/src/app/api/admin/networks-streaming/sync/route.ts`, `TRR-APP/apps/web/tests/networks-streaming-sync-proxy-route.test.ts`
- Risk: the current test suite normalizes information leakage instead of preventing it.
- Priority: Medium

---

*Concerns audit: 2026-04-04*
