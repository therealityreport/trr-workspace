# Codebase Concerns

**Analysis Date:** 2026-04-02

## Tech Debt

**Monolithic admin, analytics, and pipeline files:**
- Issue: Core workflows are concentrated in a small set of very large files that mix orchestration, data shaping, debugging, and delivery concerns. Current hotspots include `TRR-Backend/trr_backend/repositories/social_season_analytics.py` (48,471 LOC), `TRR-Backend/api/routers/admin_person_images.py` (17,224 LOC), `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` (17,269 LOC), `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx` (12,976 LOC), `screenalytics/tools/episode_run.py` (23,480 LOC), `screenalytics/apps/api/routers/episodes.py` (11,059 LOC), and `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py` (12,807 LOC).
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/api/routers/admin_person_images.py`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `screenalytics/tools/episode_run.py`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`
- Impact: Changes require broad context, code review becomes slow, merge conflicts stay high, and regression scope is hard to contain.
- Fix approach: Split by capability boundary first. For `social_season_analytics.py`, separate queue management, debug tooling, and analytics reads. For TRR-APP admin pages, extract server loaders and page sections. For screenalytics, separate pipeline stages from API and Streamlit composition.

**Generated environment contract has drifted from runtime defaults:**
- Issue: `docs/workspace/env-contract.md` claims generated authority, but current defaults do not match `scripts/dev-workspace.sh`. Observed mismatches include `WORKSPACE_BACKEND_AUTO_RESTART` (`1` vs script default `0`), `WORKSPACE_SCREENALYTICS_STREAMLIT_ENABLED` (`0` vs `1`), `WORKSPACE_TRR_APP_DEV_BUNDLER` (`webpack` vs `turbopack`), and `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED` (`1` vs `0`).
- Files: `docs/workspace/env-contract.md`, `scripts/dev-workspace.sh`
- Impact: Local setup, incident reproduction, and handoff instructions can be wrong even when engineers follow the documented contract.
- Fix approach: Regenerate `docs/workspace/env-contract.md` from the current script after each runtime change and add an automated parity check so stale generated docs fail fast.

**Canonical cross-repo handoff files contain unresolved placeholders:**
- Issue: active cross-collab documents still contain raw `TODO` markers instead of actual repo snapshots or responsibility alignment, even though `docs/cross-collab/WORKFLOW.md` defines these files as canonical handoff sources.
- Files: `TRR-APP/docs/cross-collab/TASK15/OTHER_PROJECTS.md`, `TRR-APP/docs/cross-collab/TASK21/OTHER_PROJECTS.md`, `TRR-APP/docs/cross-collab/TASK22/OTHER_PROJECTS.md`, `docs/cross-collab/WORKFLOW.md`
- Impact: Shared-work sequencing becomes ambiguous precisely where the workflow expects machine-readable continuity and contract mirroring.
- Fix approach: Fill or archive placeholder task folders and lint active `docs/cross-collab/TASK*/OTHER_PROJECTS.md` files for unresolved `TODO` content.

## Known Bugs

**TRR cast sync remains permanently partial:**
- Symptoms: the sync response reports `status="partial"` and returns zero created, updated, and skipped cast rows even when facebank image import side effects succeed.
- Files: `screenalytics/apps/api/routers/episodes.py`, `screenalytics/tests/api/test_sync_cast_from_trr.py`
- Trigger: running the TRR cast sync flow before upstream `core.cast`, `core.cast_memberships`, and `core.episode_cast` data exists.
- Workaround: use the current facebank import side effect only; do not rely on this endpoint for authoritative cast-table synchronization.

**Stage 6 of the backend pipeline never ingests Screenalytics results:**
- Symptoms: `06_sync_screenalytics` always returns `SKIPPED`, so pipeline runs stop before any manifest-driven ingestion from Screenalytics occurs.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/tests/pipeline/test_stages.py`
- Trigger: running the backend pipeline expecting Screenalytics output ingestion.
- Workaround: none in code. Any Screenalytics-to-backend reconciliation must happen outside this stage.

## Security Considerations

**Admin debug flow can request and apply LLM-generated patches against the backend repo:**
- Risk: `POST /ingest/jobs/{job_id}/debug` reaches `debug_ingest_job_with_openai`, which can call the OpenAI Chat Completions API, validate returned diff paths, and run `git apply` when `apply_patch` and `confirm_apply` are both true and `SOCIAL_DEBUG_PATCH_APPLY_ENABLED` is enabled. `SystemHealthModal` sends `confirm_apply: applyPatch`, so the UI couples confirmation to the same action that requests patch application.
- Files: `TRR-Backend/api/routers/socials.py`, `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/jobs/[jobId]/debug/route.ts`, `TRR-APP/apps/web/src/components/admin/SystemHealthModal.tsx`
- Current mitigation: admin-only routes, patch path allowlist validation, and `SOCIAL_DEBUG_PATCH_APPLY_ENABLED` defaulting to `false`.
- Recommendations: keep patch application disabled outside local development, split "generate patch" from "apply patch" into separate server-side operations, and prefer an offline-only script for any repo mutation.

**Remote auth debug logging can push arbitrary sanitized payloads into production logs:**
- Risk: `AuthDebugger` posts client-side payloads to `/api/debug-log` on non-local hosts when `NEXT_PUBLIC_ENABLE_AUTH_DEBUG_REMOTE=true`. The route redacts only by key pattern and then prints the payload to server logs. Sensitive values nested under non-sensitive keys can still land in logs.
- Files: `TRR-APP/apps/web/src/lib/debug.ts`, `TRR-APP/apps/web/src/app/api/debug-log/route.ts`
- Current mitigation: `requireAdmin` or the shared internal-admin secret is required, values are truncated, and obvious key names are redacted.
- Recommendations: disable this route outside local/dev, replace key-pattern redaction with explicit allowlisted fields, and send debug events to a structured sink instead of `console.log`.

**Dev-admin bypass is spread across many admin call sites:**
- Risk: admin clients frequently request `allowDevAdminBypass: true`, while `requireAdmin` accepts `Bearer dev-admin-bypass` whenever the bypass is enabled. The bypass is not limited to a narrow diagnostics surface.
- Files: `TRR-APP/apps/web/src/lib/admin/client-auth.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/components/admin/SystemHealthModal.tsx`, `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
- Current mitigation: bypass is blocked unless local/non-production rules or explicit dev-bypass settings allow it.
- Recommendations: narrow bypass usage to dedicated development-only routes, reduce call-site sprawl, and audit any non-local environment where dev bypass is active.

## Performance Bottlenecks

**Screenalytics launches heavyweight subprocesses per job:**
- Problem: API job management starts OS subprocesses for `tools/episode_run.py`, writes per-job progress files, and captures stderr logs on disk for each run.
- Files: `screenalytics/apps/api/services/jobs.py`, `screenalytics/tools/episode_run.py`
- Cause: queueing, execution, and progress persistence all share the API host and local filesystem contract.
- Improvement path: move detect, embed, and audio stages behind a durable worker/executor boundary and keep the API layer focused on scheduling and status reads.

**Backend uses a coarse process-wide Screenalytics circuit breaker:**
- Problem: one transient Screenalytics vision failure can mark the dependency unavailable for 300 seconds by default, causing later requests to fail fast after the upstream may already be healthy again.
- Files: `TRR-Backend/trr_backend/clients/screenalytics.py`
- Cause: `_mark_screenalytics_unavailable` stores a global in-process cooldown rather than a granular per-backend health state.
- Improvement path: replace the fixed cooldown with active health checks and shorter, bounded backoff.

**Large admin pages and Streamlit surfaces increase build and review cost:**
- Problem: several high-traffic admin surfaces are five-figure-line files that combine fetching, route state, rendering, modal orchestration, and debug affordances in single modules.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`
- Cause: page-level ownership has accumulated without hard composition boundaries.
- Improvement path: split server loaders, page shells, and client interaction islands so lint, build, and regression work are scoped to smaller modules.

## Fragile Areas

**Social ingest analytics and queue orchestration:**
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`, `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- Why fragile: queue management, debug tooling, scraping state, analytics reads, and admin remediation live in a single repository module with a matching 22,773-line test file. A small edit can affect multiple execution modes.
- Safe modification: change one capability slice at a time and keep route, repository, and worker behavior aligned in the same patch.
- Test coverage: route and repository coverage exists, but most validation stays inside the same module boundary and does not reduce the module’s blast radius.

**Screenalytics episode execution path:**
- Files: `screenalytics/apps/api/services/jobs.py`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/tools/episode_run.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`
- Why fragile: API routes, subprocess launching, pipeline implementation, and workspace UI all depend on the same episode-run contract and artifact layout.
- Safe modification: preserve stage names, progress-file shape, and artifact paths while changing one layer at a time.
- Test coverage: API and UI compile coverage exists in `screenalytics/tests/api/` and `screenalytics/tests/ui/`, but the full end-to-end job lifecycle still depends on local process and filesystem behavior.

**TRR-APP admin show pages:**
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/tests/`
- Why fragile: these pages mix auth headers, route mutations, optimistic state, diagnostics, and admin-specific affordances in giant client/server hybrids.
- Safe modification: isolate route/proxy changes from UI-state changes, and verify with both unit tests and managed-browser checks.
- Test coverage: many route and component tests exist under `TRR-APP/apps/web/tests/`, but the page modules are still broad enough that local state regressions can escape targeted assertions.

## Scaling Limits

**Screenalytics processing is host-bound:**
- Current capacity: one subprocess per job with local progress files and stderr logs.
- Limit: detect, embed, and audio workloads compete on the same API host for CPU, RAM, and filesystem throughput.
- Scaling path: move execution to dedicated workers or engine-backed jobs with durable queue state and host-independent progress reporting.

**Screenalytics dependency availability is process-scoped in TRR-Backend:**
- Current capacity: a single backend process decides whether Screenalytics is unavailable for all later requests until cooldown expiry.
- Limit: transient upstream instability can degrade all image-count operations routed through the same backend process.
- Scaling path: store dependency health in a shorter-lived, probe-driven circuit breaker instead of a fixed global cooldown window.

## Dependencies at Risk

**OpenAI model/version coupling inside admin debug tooling:**
- Risk: the admin debug flow hardcodes OpenAI Chat Completions usage and defaults to `gpt-5.3-codex` with `gpt-5.2-codex` fallback, making the tool sensitive to model availability, naming changes, and API behavior drift.
- Impact: the social ingest debug feature can fail even when the rest of the queue stack is healthy.
- Migration plan: move model selection behind a provider adapter or server config contract, and avoid binding the feature to hardcoded model IDs in repo code.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/.env.example`

## Missing Critical Features

**Manifest-driven Screenalytics ingestion is not implemented:**
- Problem: the backend pipeline includes a named Screenalytics sync stage but the stage body is still a stub.
- Blocks: end-to-end automated ingestion of Screenalytics outputs into TRR without manual or out-of-band reconciliation.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/tests/pipeline/test_stages.py`

**TRR cast-table synchronization is not available yet:**
- Problem: the screenalytics sync endpoint explicitly documents that full sync must wait for upstream TRR cast tables and currently returns partial results only.
- Blocks: authoritative cast alignment between TRR and Screenalytics.
- Files: `screenalytics/apps/api/routers/episodes.py`, `screenalytics/tests/api/test_sync_cast_from_trr.py`

**Screenalytics MCP server is still a skeleton:**
- Problem: MCP tools return demo or empty data and do not query or mutate the real database yet.
- Blocks: reliable agent-driven low-confidence review, assignment, and export workflows over live Screenalytics state.
- Files: `screenalytics/mcps/screenalytics/server.py`, `screenalytics/tests/mcps/test_screenalytics_cli.py`

## Test Coverage Gaps

**Workspace runtime docs have no parity coverage:**
- What's not tested: alignment between `docs/workspace/env-contract.md` and `scripts/dev-workspace.sh`.
- Files: `docs/workspace/env-contract.md`, `scripts/dev-workspace.sh`
- Risk: generated docs drift silently and break onboarding or recovery instructions.
- Priority: High

**Screenalytics ingest is only tested as a stub:**
- What's not tested: any real manifest, outbox, or summary-artifact ingestion path for backend Stage 6.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/tests/pipeline/test_stages.py`
- Risk: the pipeline contract looks complete on paper, but there is no automated safety net for a real implementation because the current suite only asserts `SKIPPED`.
- Priority: High

**MCP coverage does not exercise real read/write behavior:**
- What's not tested: database-backed low-confidence listing and identity assignment semantics for the Screenalytics MCP surface.
- Files: `screenalytics/mcps/screenalytics/server.py`, `screenalytics/tests/mcps/test_screenalytics_cli.py`
- Risk: agent-facing tooling can appear available while still being a demo shell.
- Priority: Medium

---

*Concerns audit: 2026-04-02*
