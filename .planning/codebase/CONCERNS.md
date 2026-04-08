# Codebase Concerns

**Analysis Date:** 2026-04-07

## Tech Debt

**Cross-repo Screenalytics result ingestion contract:**
- Issue: the backend pipeline owns a `06_sync_screenalytics` stage, but the stage is still a stub and always returns `SKIPPED`; the adjacent Screenalytics cast-sync surface is also still a placeholder contract.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/trr_backend/pipeline/registry.py`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/web/api/schema.ts`
- Impact: backend runs can complete without ingesting Screenalytics outputs, and downstream callers must special-case partial or absent Screenalytics data.
- Fix approach: define one canonical run-manifest/result contract, implement backend stage ingestion against that contract, and remove placeholder responses once TRR cast data is available.

**Backend admin and social monoliths:**
- Issue: large backend modules mix HTTP transport, SQL composition, caching, dispatch logic, and response shaping in single files.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/api/routers/admin_person_images.py`
- Impact: small feature edits touch large regression surfaces and require expensive test runs to gain confidence.
- Fix approach: extract queue health, social analytics reads, media/image orchestration, and source-specific refresh flows into separately owned service modules.

**Screenalytics pipeline and export monoliths:**
- Issue: the pipeline CLI and report/export logic centralize configuration bootstrapping, artifact contracts, ML orchestration, and presentation/reporting in a few huge modules.
- Files: `screenalytics/tools/episode_run.py`, `screenalytics/apps/api/services/run_export.py`, `screenalytics/apps/api/services/jobs.py`, `screenalytics/apps/api/services/locks.py`
- Impact: refactors are expensive, implicit coupling between stages is hard to see, and defects are more likely to spread across unrelated concerns.
- Fix approach: separate bootstrap/config resolution, stage execution, artifact persistence, and report generation into import-safe modules with narrower tests.

**TRR-APP admin client monoliths:**
- Issue: large client components own route parsing, auth-aware fetches, progress orchestration, timers, and rendering in the same files.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`, `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`, `TRR-APP/apps/web/src/components/admin/SystemHealthModal.tsx`
- Impact: UI work is difficult to isolate, client-state bugs are harder to reason about, and a single edit can affect routing, loading, and live-update behavior simultaneously.
- Fix approach: move polling/session logic and route-state helpers into smaller hooks/modules, leaving page files mostly compositional.

## Known Bugs

**Backend Stage 6 never syncs Screenalytics outputs:**
- Symptoms: pipeline stage `06_sync_screenalytics` logs that it is a stub and returns `StageStatus.SKIPPED`.
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`, `TRR-Backend/trr_backend/pipeline/repository.py`
- Trigger: any backend run that expects Screenalytics outputs to become part of the TRR pipeline.
- Workaround: rely on direct Screenalytics v2 persistence flows or manual downstream reconciliation instead of pipeline Stage 6.

**TRR cast sync is intentionally partial and does not populate cast data:**
- Symptoms: `/episodes/{ep_id}/sync_cast_from_trr` returns `status="partial"`, `total_trr_cast=0`, and an error explaining that TRR cast tables are not yet populated.
- Files: `screenalytics/apps/api/routers/episodes.py`, `screenalytics/web/api/schema.ts`
- Trigger: any show or episode cast sync call that expects real TRR cast rows to create or update Screenalytics cast state.
- Workaround: use the endpoint only for facebank import side effects; do not treat it as a complete cast-sync success.

**Audio queue mode can still execute synchronously in-process:**
- Symptoms: queue-shaped audio endpoints fall back to local synchronous work, including explicit TODO comments for missing Celery coverage such as `diarize_only`.
- Files: `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/api/main.py`, `screenalytics/web/api/schema.ts`
- Trigger: queue-mode requests when the route does not have a real Celery implementation or when queue dependencies are absent.
- Workaround: assume local synchronous execution unless Celery/Redis is verified for the specific operation.

**Screenalytics MCP server remains a demo skeleton:**
- Symptoms: MCP tools return empty lists, demo rows, or success acknowledgements without reading or writing the real DB.
- Files: `screenalytics/mcps/screenalytics/server.py`, `screenalytics/tests/mcps/test_screenalytics_cli.py`
- Trigger: any MCP-based low-confidence review, identity assignment, or screentime export flow.
- Workaround: use the FastAPI surfaces or direct DB-backed tools instead of the skeleton MCP server.

## Security Considerations

**Internal-admin shared secret remains a broad fallback auth lane:**
- Risk: the app sends both a signed internal JWT and the raw `TRR_INTERNAL_ADMIN_SHARED_SECRET`, while the backend accepts the header secret as a standalone path in `require_internal_admin`.
- Files: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/api/auth.py`, `TRR-Backend/trr_backend/security/internal_admin.py`
- Current mitigation: JWTs are short-lived and compared with a shared signing secret; header secrets use `hmac.compare_digest`.
- Recommendations: remove header-only auth, split JWT-signing material from any break-glass secret, and require scoped JWT validation for all app-to-backend internal admin traffic.

**Static service-token auth is still active across backend and Screenalytics internals:**
- Risk: long-lived bearer service tokens protect privileged internal routes and coexist with the newer internal-admin JWT lane.
- Files: `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/api/routers/screenalytics.py`, `TRR-Backend/api/routers/screenalytics_runs_v2.py`, `screenalytics/apps/api/routers/cast_screentime.py`, `screenalytics/apps/api/routers/computer_use.py`, `screenalytics/apps/api/routers/celery_jobs.py`
- Current mitigation: token compares use constant-time comparison and startup checks warn when envs are missing.
- Recommendations: replace static service-token access with scoped JWTs or mTLS, rotate secrets per integration boundary, and narrow audiences per route family.

**Runtime behavior depends heavily on env wiring across three repos:**
- Risk: auth mode, DB target, queue availability, and generated routing behavior can change more from env drift than from code drift.
- Files: `TRR-Backend/api/main.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `screenalytics/apps/api/main.py`, `screenalytics/apps/api/services/supabase_db.py`
- Current mitigation: each repo validates part of its own env surface at startup.
- Recommendations: add a workspace-level contract check that validates the combined backend/app/screenalytics env graph before deployment or shared local runs.

## Performance Bottlenecks

**Backend social analytics is a single hot path for queue, worker, and reporting state:**
- Problem: one repository module handles queue snapshots, worker health, scraper reuse, dispatch decisions, caching, and analytics aggregation.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Cause: one large ownership boundary encourages shared mutable caches and broad SQL fan-out rather than smaller bounded services.
- Improvement path: split queue/worker health, ingest orchestration, and reporting queries into separate services with explicit cache invalidation and narrower APIs.

**Screenalytics API still executes heavy work in request-serving processes:**
- Problem: API routes and services can spawn subprocesses or perform long-running synchronous work when queue support is absent or not implemented.
- Files: `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/api/services/jobs.py`, `screenalytics/apps/api/services/run_export.py`
- Cause: fallback-to-sync behavior keeps endpoints available, but it also moves latency spikes and CPU pressure onto API workers.
- Improvement path: make async capability explicit per route, fail closed when the worker plane is unavailable, and reserve local sync mode for clearly dev-only execution paths.

**Admin polling density can multiply backend load:**
- Problem: large admin client components use many `useEffect`, `setTimeout`, and `setInterval` loops for stream monitoring, health checks, and status refreshes.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`, `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`, `TRR-APP/apps/web/src/components/admin/SystemHealthModal.tsx`
- Cause: data orchestration and rendering are colocated, so each screen implements its own live-update lifecycle.
- Improvement path: centralize live-session polling/SSE hooks, dedupe timers, and prefer server-rendered cached reads for non-live data.

## Fragile Areas

**Screenalytics lock and crash-recovery flow assumes local filesystem ownership:**
- Files: `screenalytics/apps/api/services/locks.py`, `screenalytics/apps/api/services/jobs.py`
- Why fragile: lock ownership uses PID and hostname heuristics, remote hosts are assumed alive, and state lives under `SCREENALYTICS_DATA_ROOT`.
- Safe modification: treat lock metadata, heartbeat cadence, and stale-steal rules as a contract; change job runners and recovery logic together.
- Test coverage: API and unit tests cover local job semantics, but there is no distributed or multi-host integration suite.

**Generated contract artifacts can drift from real routes and runtime behavior:**
- Files: `screenalytics/web/api/schema.ts`, `TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts`
- Why fragile: both files are generated, committed, and used as reference surfaces; stale generation produces convincing but outdated type and inventory data.
- Safe modification: change source routes/spec generators first, regenerate in the same commit, and verify embedded metadata such as `generatedAt` and source commit fields change.
- Test coverage: consumers are tested indirectly, but there is no workspace-wide freshness gate covering both generated artifacts.

**Legacy and v2 Screenalytics APIs remain live at the same time:**
- Files: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/api/routers/jobs.py`, `screenalytics/apps/api/routers/celery_jobs.py`, `screenalytics/web/api/schema.ts`
- Why fragile: v2 routers are env-gated, many legacy endpoints remain deprecated-but-available, and the generated schema documents both behaviors.
- Safe modification: remove one compatibility lane at a time and update routes, docs, generated schema, and consumers together.
- Test coverage: deprecated endpoints are covered, but there is no enforcement that active consumers fully migrate away from them.

**Backend Screenalytics availability state is per-process, not shared:**
- Files: `TRR-Backend/trr_backend/clients/screenalytics.py`
- Why fragile: unavailability cooldown and reason state live in process memory, so multiple backend replicas can disagree about Screenalytics health.
- Safe modification: keep the logic stateless or move the state to shared infrastructure before scaling backend replicas.
- Test coverage: client logic is unit-tested; no multi-replica consistency test exists.

## Scaling Limits

**Screenalytics local lock/checkpoint design limits horizontal scale:**
- Current capacity: one host or tightly coupled host set can coordinate through `SCREENALYTICS_DATA_ROOT` plus PID/heartbeat heuristics.
- Limit: multi-host worker pools without shared filesystem semantics cannot safely rely on `screenalytics/apps/api/services/locks.py`.
- Scaling path: move locks, heartbeats, and checkpoints to Redis or Postgres and make job ownership node-agnostic.

**Backend admin/social state uses in-memory caches and cooldowns:**
- Current capacity: hot admin reads are faster in a single-process deployment because queue and analytics snapshots stay in memory.
- Limit: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` and `TRR-Backend/trr_backend/clients/screenalytics.py` do not share state across replicas, which can increase duplicate work and inconsistent health views.
- Scaling path: externalize shared status snapshots and caches to Redis/Postgres with explicit invalidation.

**TRR-APP admin pages scale linearly with open tabs and operators:**
- Current capacity: a few open admin tabs are manageable because each client runs its own timers locally.
- Limit: many simultaneous admin sessions multiply status and health fetches from `page.tsx`, `PersonPageClient.tsx`, `season-social-analytics-section.tsx`, and `WeekDetailPageView.tsx`.
- Scaling path: consolidate live status into shared SSE/WebSocket streams or a single fan-in status endpoint per admin surface.

## Dependencies at Risk

**Optional Celery/Redis installation changes screenalytics behavior materially:**
- Risk: `screenalytics/apps/api/main.py` mounts 503 stubs when Celery dependencies are missing, and some async-shaped routes fall back to synchronous local execution.
- Impact: local, CI, and deployed environments can behave differently even when the application code is identical.
- Migration plan: make worker capability part of hard startup validation and stop advertising async queue behavior when the worker plane is unavailable.

**Deprecated transitive npm packages remain in the app lockfile:**
- Risk: `glob@10.5.0`, `json-ptr@3.1.1`, and `node-domexception@1.0.0` are flagged as deprecated in `TRR-APP/pnpm-lock.yaml`.
- Impact: dependency audit gates and future install policy changes can fail unexpectedly, especially on clean CI or new developer machines.
- Migration plan: refresh top-level dependencies that pull these packages and re-lock under the workspace Node `24.x` baseline.

## Missing Critical Features

**No canonical end-to-end Screenalytics result ingestion path in the backend pipeline:**
- Problem: backend run persistence and Screenalytics v2 routes exist, but the pipeline stage that should ingest final Screenalytics outputs is still a stub.
- Blocks: reliable automatic promotion of Screenalytics results into TRR pipeline completion semantics.

**No real TRR cast sync into Screenalytics identity/cast state:**
- Problem: Screenalytics exposes a cast-sync endpoint, but it explicitly reports that required TRR cast tables are not populated for the real flow.
- Blocks: deterministic cast-aware identity reconciliation and complete TRR-to-Screenalytics cast bootstrap.

**No production-ready Screenalytics MCP surface for operator workflows:**
- Problem: `screenalytics/mcps/screenalytics/server.py` is still a skeleton rather than a DB-backed tool surface.
- Blocks: agent-native review and identity-assignment workflows that should not require direct API or DB handling.

## Test Coverage Gaps

**Backend Stage 6 has no direct regression coverage:**
- What's not tested: actual end-to-end behavior for `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`
- Files: `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py`
- Risk: the stage can remain permanently skipped without a failing test.
- Priority: High

**Cross-repo internal auth chain lacks a workspace e2e contract test:**
- What's not tested: `TRR-APP` internal proxy -> `TRR-Backend` internal admin verification -> Screenalytics/internal worker auth as one flow.
- Files: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`, `screenalytics/apps/api/routers/cast_screentime.py`
- Risk: one repo can change headers or token semantics and only runtime integration reveals the break.
- Priority: High

**Screenalytics has no browser or end-to-end suite for operator UI flows:**
- What's not tested: operator behavior across `screenalytics/apps/workspace-ui/` and its interaction with the FastAPI surface.
- Files: `screenalytics/apps/workspace-ui/`, `screenalytics/tests/ui/`, `screenalytics/tests/api/`
- Risk: orchestration and operator experience regressions can pass API and helper tests.
- Priority: Medium

**Coverage reporting is present or partial, but threshold enforcement is weak across repos:**
- What's not tested: a minimum coverage floor for backend, Screenalytics, and app-critical admin code.
- Files: `TRR-Backend/pytest.ini`, `screenalytics/pyproject.toml`, `TRR-APP/apps/web/vitest.config.ts`
- Risk: large modules can continue to accrete behavior faster than meaningful coverage grows.
- Priority: Medium

---

*Concerns audit: 2026-04-07*
