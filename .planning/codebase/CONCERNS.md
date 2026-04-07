# Codebase Concerns

**Analysis Date:** 2026-04-06

## Tech Debt

**Planning state drift across the workspace root and workstreams:**
- Issue: The live workspace marker points at `feature-b`, but that workstream is archived, there is no root `.planning/STATE.md`, and older planning artifacts still reference the missing root state file.
- Files: `.planning/active-workstream`, `.planning/workstreams/feature-b/STATE.md`, `.planning/PROJECT.md`, `.planning/workstreams/milestone/phases/03-backend-execution-port/03-RESEARCH.md`
- Impact: Planning and resume flows can read an archived state as current or fail when older automation expects `.planning/STATE.md`.
- Fix approach: Either start the next milestone and repoint `.planning/active-workstream`, or explicitly retire the marker and scrub remaining root-state references from live planning flows.

**Cross-collab scaffolding does not match the enforced workflow contract:**
- Issue: `scripts/new-cross-collab-task.sh` generates `STATUS.md` files without the required `## Handoff Snapshot` block and fills `OTHER_PROJECTS.md` with literal `TODO` placeholders.
- Files: `scripts/new-cross-collab-task.sh`, `docs/cross-collab/WORKFLOW.md`, `scripts/sync-handoffs.py`
- Impact: Freshly scaffolded cross-repo tasks are invalid handoff sources until manually repaired, which makes the “recommended” workflow path easy to break.
- Fix approach: Update the scaffolder to emit the exact templates from `docs/cross-collab/WORKFLOW.md`, including the fenced YAML handoff block required by `scripts/sync-handoffs.py`.

**Workspace automation is concentrated in a few large shell scripts:**
- Issue: Startup, health checks, browser management, and session cleanup are implemented in large Bash entry points with many branches and environment toggles.
- Files: `scripts/dev-workspace.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `scripts/status-workspace.sh`, `scripts/doctor.sh`, `scripts/preflight.sh`
- Impact: Small behavior changes are hard to reason about, regressions are difficult to localize, and debugging often requires reading shell state instead of using narrow abstractions.
- Fix approach: Split these scripts into smaller sourced modules under `scripts/lib/`, keep each command as a thin entry point, and add targeted smoke tests for profile selection, health gating, and Chrome session ownership.

**DB/env compatibility remains partly centralized and partly quarantined:**
- Issue: Runtime code is standardized on `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`, but tooling helpers still intentionally accept `DATABASE_URL` and `SUPABASE_DB_URL` in some paths.
- Files: `TRR-Backend/trr_backend/db/connection.py`, `TRR-Backend/trr_backend/db/preflight.py`, `TRR-Backend/scripts/_db_url.py`, `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/scripts/migrate_legacy_db_to_supabase.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `docs/workspace/env-deprecations.md`
- Impact: Operators and future automation can still confuse runtime env rules with tooling-only fallbacks, especially during incident response or ad-hoc migrations.
- Fix approach: Keep the fallback adapters only where they are truly required, mark them consistently as tooling-only in code, and remove any remaining permissive resolution from paths that can be mistaken for runtime behavior.

## Known Bugs

**New cross-collab tasks are scaffolded in a form that handoff sync rejects:**
- Symptoms: A newly generated `STATUS.md` lacks the required handoff snapshot, so `scripts/sync-handoffs.py` treats it as an invalid canonical source.
- Files: `scripts/new-cross-collab-task.sh`, `scripts/sync-handoffs.py`, `docs/cross-collab/WORKFLOW.md`
- Trigger: Run `./scripts/new-cross-collab-task.sh ...` and then include the generated `STATUS.md` in a handoff-producing workflow.
- Workaround: Manually add the `## Handoff Snapshot` fenced YAML block and replace the placeholder `TODO` sections before using the generated task docs.

**screenalytics cast sync endpoint is only partially implemented:**
- Symptoms: The route returns `status="partial"` and a message that full cast sync is unavailable because TRR cast tables are not populated.
- Files: `screenalytics/apps/api/routers/episodes.py`
- Trigger: Call the TRR cast sync flow for an episode/show pair.
- Workaround: Use the existing facebank import side effects only; do not assume season-level or episode-level cast synchronization is complete.

**Audio rediarization queue mode is not a real queued implementation:**
- Symptoms: The `diarize_only` path documents queue mode but falls back to sync logic because the Celery task is not implemented.
- Files: `screenalytics/apps/api/routers/audio.py`
- Trigger: Use the `diarize_only` endpoint expecting true queue-backed background execution.
- Workaround: Treat the current behavior as local/synchronous execution and do not build operational expectations around Celery ownership for this endpoint.

## Security Considerations

**Managed browser sessions carry long-lived authenticated state across tasks:**
- Risk: Shared Chrome keepers and profile reuse can leak state across unrelated browser sessions if ownership or cleanup logic regresses.
- Files: `scripts/chrome-agent.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `scripts/codex-mcp-session-reaper.sh`, `docs/workspace/chrome-devtools.md`
- Current mitigation: Profile guards, shared/headful ownership files, tab caps, and the session reaper exist and are part of the default workflow.
- Recommendations: Keep auth work on the managed path only, continue treating profile switching as an explicit override, and add regression checks around stale-owner cleanup and port conflict handling.

**Workspace-local shared secrets are generated deterministically for dev bootstraps:**
- Risk: The local launcher derives fallback values for `TRR_INTERNAL_ADMIN_SHARED_SECRET` and `SCREENALYTICS_SERVICE_TOKEN` when the env is unset.
- Files: `scripts/dev-workspace.sh`, `AGENTS.md`
- Current mitigation: The contract documents these as local workspace runtime values and warns against printing or promoting secret values.
- Recommendations: Keep these values scoped to local dev only, never reuse them in hosted environments, and ensure deploy tooling fails closed when real secrets are missing.

## Performance Bottlenecks

**Backend social analytics pipeline is a single oversized hotspot:**
- Problem: A 49k-line repository module owns queue orchestration, Modal dispatch, caching, platform policies, and summary logic in one file.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Cause: Domain logic, platform-specific behavior, and operational coordination are all accumulated in one repository entry point.
- Improvement path: Split query/read models, dispatch logic, queue-health logic, and platform adapters into separate modules with smaller tests mapped to each slice.

**screenalytics imports heavy pipeline code directly into the API surface:**
- Problem: The API imports `tools.episode_run` directly, and many tests and services depend on that same monolith.
- Files: `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/api/services/jobs.py`, `screenalytics/apps/api/main.py`, `screenalytics/tools/episode_run.py`
- Cause: The CLI/pipeline runtime doubles as a shared application library instead of sitting behind a thinner orchestration facade.
- Improvement path: Introduce a small service layer for pipeline entry points and keep the CLI wrapper thin so the API stops inheriting the full import surface and side effects of `tools/episode_run.py`.

**TRR-APP admin pages carry too much client-side work in page-level components:**
- Problem: Core admin surfaces are implemented as very large client components with routing, fetch, tab state, modal state, and rendering bundled together.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
- Cause: Feature growth is concentrated in page files instead of being pushed into smaller hooks and focused components.
- Improvement path: Extract route state, operation polling, and domain-specific sections into smaller client modules so page renders do less orchestration work and reviews stay tractable.

## Fragile Areas

**Cross-repo admin contract changes remain high-risk because the seams are narrow but strict:**
- Files: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`, `TRR-Backend/trr_backend/clients/screenalytics.py`, `screenalytics/apps/api/services/supabase_db.py`
- Why fragile: `TRR-APP` normalizes `TRR_API_URL` to `/api/v1`, `TRR-Backend` still carries a `screenalytics` client, and `screenalytics` consumes the same DB/runtime contract from the other side. Contract drift in one repo propagates quickly.
- Safe modification: Change shared URLs, auth behavior, and DB/env names in the documented repo order: `TRR-Backend` first, `screenalytics` second, `TRR-APP` last.
- Test coverage: Contract coverage exists in slices, but there is no single end-to-end workspace test that proves all three repos still agree after a shared contract change.

**Legacy compatibility paths are still alive inside the screenalytics episodes router:**
- Files: `screenalytics/apps/api/routers/episodes.py`
- Why fragile: The router preserves deprecated routes, stage aliases, legacy storage fallbacks, and legacy export keys in the same file as canonical behavior.
- Safe modification: Remove or tighten one deprecated surface at a time, add explicit migration coverage for each removal, and keep the deprecation timeline synchronized with downstream callers before deleting aliases.
- Test coverage: The module has broad surrounding tests, but its size makes it easy for one alias/fallback change to miss an unexercised path.

**Workspace handoff generation depends on strict doc shape, not tolerant parsing:**
- Files: `scripts/sync-handoffs.py`, `scripts/handoff-lifecycle.sh`, `docs/cross-collab/WORKFLOW.md`
- Why fragile: The generator requires an exact `## Handoff Snapshot` YAML fence shape and fails fast when canonical sources drift.
- Safe modification: Change the workflow template, scaffolder, and parser together. Do not update only one of those surfaces.
- Test coverage: No dedicated checked-in test suite covers the cross-repo doc scaffolding plus sync path end to end.

## Scaling Limits

**Backend Postgres session-mode runtime is intentionally small:**
- Current capacity: `TRR-Backend/trr_backend/db/pg.py` defaults to `DEFAULT_SESSION_POOLER_MAXCONN = 2`, `DEFAULT_LOCAL_SESSION_POOLER_MAXCONN = 4`, and `DEFAULT_POOL_MAXCONN = 24`.
- Limit: Background jobs or admin bursts can still hit pool exhaustion or session-pool capacity errors if workload expands faster than per-feature concurrency controls.
- Scaling path: Keep session-mode as the runtime lane, but move high-volume operations behind queueing/batching controls and tune pool sizes only after measuring the actual concurrent workload.

**TRR-APP server Postgres concurrency is deliberately narrow for session-pooler safety:**
- Current capacity: `TRR-APP/apps/web/src/lib/server/postgres.ts` resolves to small pool and operation limits for session-pooler connections.
- Limit: Large admin pages that fan out many server-side reads can hit contention or raise latency long before the database itself is saturated.
- Scaling path: Reduce per-request query fan-out first, then raise pool and concurrent-operation limits only if the session pooler budget can support it.

**screenalytics API uses direct psycopg2 connections instead of a shared pool helper:**
- Current capacity: `screenalytics/apps/api/services/supabase_db.py` opens connections directly with `psycopg2.connect(...)`.
- Limit: As API throughput rises, connection churn becomes expensive and can compete poorly with other services sharing the same Supabase session lane.
- Scaling path: Introduce a small pool/shared connection manager for API-side DB access before scaling screenalytics request concurrency.

## Dependencies at Risk

**Modal is part of the active social execution path, not an optional add-on:**
- Risk: Social/admin flows depend on Modal app and function resolution for the preferred remote job plane.
- Impact: If Modal app/function resolution drifts, admin actions can stall, queue, or surface dispatch-blocked states instead of completing work.
- Migration plan: Keep `TRR-Backend` dispatch health checks current, preserve the explicit executor labels in workspace docs, and maintain a tested fallback/rollback path before changing Modal naming or ownership.
- Files: `scripts/dev-workspace.sh`, `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `docs/ai/local-status/instagram-modal-dispatch-profile-hardening.md`

**Managed Chrome control is now operational infrastructure for agent workflows:**
- Risk: The workspace depends on the Chrome wrapper and reaper scripts to keep authenticated browser automation reliable.
- Impact: Browser verification, admin UI repros, and Chrome-backed MCP tasks degrade together if these scripts drift.
- Migration plan: Treat the Chrome scripts as shared infrastructure, keep them versioned with explicit diagnostics, and avoid one-off repo-specific browser workarounds.
- Files: `scripts/chrome-agent.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `scripts/codex-mcp-session-reaper.sh`, `docs/workspace/chrome-devtools.md`

## Missing Critical Features

**screenalytics MCP server is still a skeleton:**
- Problem: Read and write tool handlers return placeholder results and do not perform real DB-backed operations.
- Blocks: Reliable MCP-based screenalytics automation and any workflow that expects agent-side identity assignment or low-confidence review through the MCP server.
- Files: `screenalytics/mcps/screenalytics/server.py`

**TRR cast sync into screenalytics is not fully wired:**
- Problem: The endpoint explicitly states that `core.cast`, `core.cast_memberships`, and `core.episode_cast` support is not populated for full sync behavior.
- Blocks: Fully automated show/episode cast propagation from TRR into screenalytics review flows.
- Files: `screenalytics/apps/api/routers/episodes.py`

**Audio smart-split auto-assignment is disabled after the NeMo migration:**
- Problem: The route logs that auto-assignment is temporarily unavailable and leaves the NeMo TitaNet embedding path unimplemented.
- Blocks: Confident voice-cluster auto-assignment during smart split flows.
- Files: `screenalytics/apps/api/routers/audio.py`

## Test Coverage Gaps

**Workspace shell orchestration has little direct automated coverage:**
- What's not tested: End-to-end behavior of `make dev`, profile loading, Chrome session cleanup, and handoff lifecycle interactions across the root scripts.
- Files: `scripts/dev-workspace.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `scripts/status-workspace.sh`, `scripts/doctor.sh`, `scripts/preflight.sh`, `scripts/handoff-lifecycle.sh`
- Risk: Operational regressions show up during startup or debugging rather than in a fast automated suite.
- Priority: High

**Largest TRR-APP admin pages do not have direct page-level tests:**
- What's not tested: The full behavior of the show admin page and the person admin client page as integrated page units.
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
- Risk: Route-state, modal orchestration, and fetch/polling regressions can slip through while smaller component tests still pass.
- Priority: High

**screenalytics workspace UI orchestration remains under-tested relative to its size:**
- What's not tested: The full Streamlit page behavior of the run-control UI and many stateful review flows that sit on top of pipeline orchestration.
- Files: `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/workspace-ui/pages/3_Episode_Review.py`, `screenalytics/apps/workspace-ui/ui_helpers.py`
- Risk: Session-state regressions, stale-banner behavior, and operator workflow breaks can reach users even when lower-level helper tests pass.
- Priority: High

**The screenalytics MCP stub has no meaningful behavioral coverage:**
- What's not tested: Real auth, DB-backed reads, or write-side safety for the MCP tool surface.
- Files: `screenalytics/mcps/screenalytics/server.py`
- Risk: Future callers can assume a production-ready tool surface that currently does not exist.
- Priority: Medium

---

*Concerns audit: 2026-04-06*
