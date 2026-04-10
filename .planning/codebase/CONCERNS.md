# Codebase Concerns

**Analysis Date:** 2026-04-09

## Tech Debt

**TRR-Backend social and admin monoliths:**
- Issue: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` identifies itself as a "Legacy social control-plane monolith and temporary compatibility surface" and is 52,805 lines with roughly 1,030 top-level defs. Admin router modules such as `TRR-Backend/api/routers/admin_person_images.py` (16,999 lines), `TRR-Backend/api/routers/admin_show_links.py` (8,268 lines), `TRR-Backend/api/routers/socials.py` (7,206 lines), and `TRR-Backend/api/routers/admin_show_sync.py` (5,883 lines) are similarly oversized.
- Files: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, `TRR-Backend/api/routers/admin_person_images.py`, `TRR-Backend/api/routers/admin_show_links.py`, `TRR-Backend/api/routers/socials.py`, `TRR-Backend/api/routers/admin_show_sync.py`
- Impact: Small behavior changes carry a high regression radius, code review becomes slow, and shared constants or helper changes can affect unrelated admin and social workflows.
- Fix approach: Split by bounded capability first. Move queue/recovery policy, analytics refresh, media mirror, and platform-specific orchestration out of `social_season_analytics.py`; split admin routers by resource and background-job boundary; keep compatibility shims thin.

**screenalytics mixed package layout and monolithic pipeline/UI files:**
- Issue: `screenalytics/tools/episode_run.py` manually rewrites `sys.path` to prefer `screenalytics/packages/py-screenalytics/src` over the legacy `screenalytics/py_screenalytics/` namespace. Core workflow files are also very large: `screenalytics/tools/episode_run.py` (23,480 lines), `screenalytics/apps/api/routers/episodes.py` (10,914 lines), `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py` (12,852 lines), and `screenalytics/apps/api/services/run_export.py` (8,404 lines).
- Files: `screenalytics/tools/episode_run.py`, `screenalytics/packages/py-screenalytics/src`, `screenalytics/py_screenalytics`, `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py`, `screenalytics/apps/api/services/run_export.py`
- Impact: Import behavior depends on execution context, local tooling can import the wrong package tree, and the main episode workflow is difficult to test or refactor in isolation.
- Fix approach: Finish the package migration so one canonical import root exists, then carve episode execution into stage modules with typed handoff objects rather than a single CLI/router/UI control surface.

**TRR-APP admin surface concentration:**
- Issue: Major admin screens and repositories are concentrated into a few very large files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` (17,083 lines), `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx` (12,717 lines), `TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx` (9,796 lines), `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx` (9,290 lines), and `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts` (5,934 lines).
- Files: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx`, `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`, `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
- Impact: UI and data-access changes accumulate in the same files, increasing merge conflicts, editor/typecheck latency, and the odds of accidental coupling between unrelated admin features.
- Fix approach: Split large pages into route-level loaders plus focused client sections, and split `trr-shows-repository.ts` by entity or query domain so tests and reviews can target narrower contracts.

**Workspace orchestration and environment sprawl:**
- Issue: Workspace startup and browser orchestration are encoded in large shell scripts with many toggles and generated documentation. `scripts/dev-workspace.sh` is 1,685 lines, `scripts/codex-chrome-devtools-mcp.sh` is 1,396 lines, and `docs/workspace/env-contract.md` documents dozens of runtime flags. `scripts/check-workspace-contract.sh` only spot-checks selected keys across `scripts/dev-workspace.sh`, `profiles/default.env`, `docs/workspace/env-contract.md`, and repo `.env.example` files.
- Files: `scripts/dev-workspace.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `scripts/chrome-devtools-mcp-status.sh`, `scripts/check-workspace-contract.sh`, `docs/workspace/env-contract.md`, `Makefile`
- Impact: Local setup failures are hard to reason about, and contract drift between scripts, docs, and examples can break onboarding or produce repo-specific environment mismatches.
- Fix approach: Move high-value config into typed data or a smaller shared runtime layer, generate more of the shell-facing docs/checks from source, and keep shell wrappers focused on process orchestration only.

## Known Bugs

**screenalytics MCP server returns placeholder data instead of real persistence:**
- Symptoms: `list_low_confidence()` returns `{"items": []}`, `assign_identity()` returns success without persistence, and `export_screen_time()` returns a demo row.
- Files: `screenalytics/mcps/screenalytics/server.py`, `screenalytics/tests/mcps/test_screenalytics_cli.py`
- Trigger: Any MCP caller invoking `list_low_confidence` or `assign_identity` expects live database-backed behavior.
- Workaround: Use the API or direct DB-oriented tooling instead of the MCP surface for real work. Treat the current MCP server as a scaffold only.

**Audio queue modes silently degrade to sync/local behavior:**
- Symptoms: `transcribe_only`, `diarize_only`, and related audio handlers document queue mode but state "not yet implemented" and fall back to local or synchronous execution. Smart Split auto-assign logs that NeMo embedding extraction is unavailable and assigns segments back to the original cluster.
- Files: `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/api/routers/grouping.py`
- Trigger: Callers request `run_mode="queue"` or rely on auto-assignment during Smart Split while Celery or Redis are missing or the feature path is incomplete.
- Workaround: Run these operations explicitly in local mode and treat queue-mode responses as best-effort rather than durable background execution.

## Security Considerations

**Admin error payloads expose backend origin details:**
- Risk: Multiple Next.js admin proxy routes include `TRR_API_URL` or a derived backend URL directly in user-visible error JSON. This leaks internal hostnames, ports, or staging origins to any authenticated caller and increases operational metadata exposure.
- Files: `TRR-APP/apps/web/src/app/api/admin/trr-api/cast-photos/[photoId]/mirror/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/google-news/sync/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Current mitigation: Admin routes still require auth before reaching these handlers, and development-only warnings exist for remote backend hosts.
- Recommendations: Return generic connectivity hints to clients, log concrete backend origins server-side only, and audit other admin proxy routes for similar environment leakage.

**Secret material is distributed across repo-local env files and key storage:**
- Risk: The workspace contains multiple `.env*` files and a dedicated key directory, which raises accidental copy, local misconfiguration, and rotation-audit risk even when values are not committed. The workspace startup path also derives local shared secrets automatically, which makes it easy to blur the line between disposable local auth and explicit credential management.
- Files: `TRR-Backend/.env*`, `TRR-APP/apps/web/.env*`, `screenalytics/.env*`, `TRR-Backend/keys/`, `scripts/dev-workspace.sh`
- Current mitigation: Workspace policy forbids printing secret values, and the managed startup scripts can synthesize local-only shared secrets for development.
- Recommendations: Keep one authoritative secret source per environment, keep `TRR-Backend/keys/` empty by default outside explicit local use, and add a preflight audit that fails when unmanaged secret files are present unexpectedly.

## Performance Bottlenecks

**Heavy screenalytics jobs run inside request/worker processes when async infra is absent:**
- Problem: Async endpoints in `screenalytics/apps/api/routers/grouping.py` explicitly fall back to synchronous execution when Celery or Redis are unavailable, and audio rerun endpoints in `screenalytics/apps/api/routers/audio.py` run heavy local subprocesses or synchronous compute paths. This moves expensive grouping, diarization, and export work onto request-serving processes.
- Files: `screenalytics/apps/api/routers/grouping.py`, `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/api/tasks.py`
- Cause: Queue mode is partial, and fallback behavior prioritizes completing work over preserving API worker capacity.
- Improvement path: Make async capability explicit in the contract, fail fast when the requested execution backend is unavailable, and reserve local fallback for CLI or operator-only flows.

**Developer throughput is constrained by giant generated and hand-authored TypeScript modules:**
- Problem: `TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts` is 21,682 lines and the main admin pages/components are also very large. These files increase editor latency, test startup time, and TypeScript/Vitest work for unrelated changes.
- Files: `TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`
- Cause: Large inventories and broad UI/data concerns are bundled into single modules rather than partitioned by domain or route.
- Improvement path: Shard generated inventories by domain with a checked-in index, and split the largest admin screens into loader/query modules plus smaller display components.

## Fragile Areas

**Cross-repo backend URL and version contract:**
- Files: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/cast-photos/[photoId]/mirror/route.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/google-news/sync/route.ts`, `TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts`, `TRR-APP/apps/web/tests/admin-api-references-generator.test.ts`
- Why fragile: The app normalizes `TRR_API_URL` by auto-appending `/api/v1`, and the checked-in API inventory carries static-scan output plus `unverified_manual` edges. Backend path, version, or proxy changes therefore require coordinated edits across runtime URL helpers, generated inventories, and test fixtures.
- Safe modification: Change route prefixes and backend-version assumptions only in the same session across `TRR-Backend` and `TRR-APP`, then regenerate and re-run the admin API reference tests.
- Test coverage: `TRR-APP/apps/web/tests/admin-api-references-generator.test.ts` keeps the checked-in artifact consistent with the generator, but it does not prove that the inventory matches the live backend implementation.

**Workspace browser and process management wrappers:**
- Files: `scripts/dev-workspace.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `scripts/chrome-devtools-mcp-status.sh`, `scripts/check-workspace-contract.sh`, `Makefile`
- Why fragile: These scripts coordinate PID files, port locks, browser modes, watchdogs, and remote-worker flags through shell logic and environment variables. Small edits can destabilize only one runtime path and remain invisible until a specific local profile is used.
- Safe modification: Change one orchestration layer at a time, then run `make preflight`, `make workspace-contract-check`, and the Chrome status commands before touching dependent scripts.
- Test coverage: Contract checks are partial and script-unit coverage is limited; there is no full matrix test for cloud vs `local_docker`, headless/shared browser modes, and remote-worker toggle combinations.

## Scaling Limits

**Social and remote-job throughput policy is spread across shell defaults and backend constants:**
- Current capacity: The workspace defines dispatch and concurrency defaults such as `WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=25` and `WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=64`, while `TRR-Backend/trr_backend/repositories/social_season_analytics.py` maintains many queue, heartbeat, stale-recovery, and batch-size constants in code.
- Limit: Throughput tuning requires coordinated changes in shell defaults, generated docs, and backend code, which makes scaling experiments slow and raises the risk of configuration skew between local, operator, and production-like environments.
- Scaling path: Move job-plane capacity and recovery policy into one typed configuration surface with runtime introspection, and let workspace scripts consume that config instead of owning parallel defaults.

## Dependencies at Risk

**Not detected from the current workspace scan:**
- Risk: No single third-party package emerged as the dominant short-term adoption blocker during this pass.
- Impact: Current risk concentration is higher in local monolith size, contract drift, and workflow coupling than in one specific library choice.
- Migration plan: Re-evaluate dependencies after the monolith splits and queue contracts are stabilized, because those changes will make third-party replacement costs easier to measure.

## Missing Critical Features

**screenalytics MCP write/read implementation is still scaffold-level:**
- Problem: The MCP surface exists, but key tools do not query or write durable state yet.
- Blocks: Reliable agent-driven identity assignment and low-confidence review workflows through the MCP interface.

**Queue-backed audio reruns and Smart Split auto-assignment are incomplete:**
- Problem: Audio rerun endpoints still document queue mode as not implemented, and Smart Split auto-assignment is disabled pending NeMo embedding work.
- Blocks: Predictable non-blocking audio remediation flows and trustworthy semi-automated speaker reassignment.

## Test Coverage Gaps

**screenalytics MCP persistence and auth side effects:**
- What's not tested: Real database-backed `list_low_confidence` and `assign_identity` behavior, including write persistence and auth-sensitive failure modes.
- Files: `screenalytics/mcps/screenalytics/server.py`, `screenalytics/tests/mcps/test_screenalytics_cli.py`
- Risk: Agents can appear to succeed while no durable state changes occur.
- Priority: High

**Audio and grouping fallback-heavy branches:**
- What's not tested: Queue-mode fallbacks, synchronous degradation paths, and Smart Split's disabled auto-assign branch. Current API tests mainly cover legacy job creation/status and prerequisite endpoints.
- Files: `screenalytics/apps/api/routers/audio.py`, `screenalytics/apps/api/routers/grouping.py`, `screenalytics/tests/api/test_audio_endpoints.py`
- Risk: Production-like load or operator flows can take untested branches that block workers or silently behave differently from the advertised API contract.
- Priority: High

**Workspace orchestration behavior across runtime profiles:**
- What's not tested: Full startup, restart, cleanup, and browser session flows across the canonical cloud path, the explicit `local_docker` fallback, and remote-worker/browser mode combinations.
- Files: `scripts/dev-workspace.sh`, `scripts/codex-chrome-devtools-mcp.sh`, `Makefile`
- Risk: Local development regressions surface late and are hard to reproduce because only one profile may fail.
- Priority: Medium

---

*Concerns audit: 2026-04-09*
