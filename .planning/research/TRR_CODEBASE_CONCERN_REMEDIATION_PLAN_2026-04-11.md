# TRR Codebase Concern Remediation Plan

Last updated: 2026-04-11
Scope: `/Users/thomashulihan/Projects/TRR/TRR-Backend`, `/Users/thomashulihan/Projects/TRR/TRR-APP`
Conditional downstream scope: `/Users/thomashulihan/Projects/TRR/screenalytics` only if shared auth or API contracts move during execution

## Summary

This plan covers the remaining concerns from the backend and app concern maps after three completed backend slices:

1. security artifact cleanup and repo hygiene guardrails
2. admin-auth hardening defaults and compatibility sweep
3. live-status stream hardening and narrowed request-timeout SSE exemptions

The remaining work is dominated by one backend hotspot and three app-level maintainability risks:

1. `TRR-Backend`: decompose the `social_season_analytics.py` monolith without breaking admin queue, sync-session, or dispatch behavior
2. `TRR-APP`: collapse duplicated proxy-route behavior behind stronger shared primitives
3. `TRR-APP`: centralize env/config parsing and feature gates now split across auth, proxy, and client-access paths
4. `TRR-APP`: split the largest admin screens and add browser coverage for the workflows most likely to regress

Recommended execution order follows workspace policy:

1. `TRR-Backend`
2. `screenalytics` only if a shared contract actually changes
3. `TRR-APP`

## Project Context

- Backend concern map: `/Users/thomashulihan/Projects/TRR/TRR-Backend/.planning/codebase/CONCERNS.md`
- App concern map: `/Users/thomashulihan/Projects/TRR/TRR-APP/.planning/codebase/CONCERNS.md`
- Completed backend status notes:
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/security-auth-hygiene-hardening.md`
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/live-status-stream-hardening.md`
- The backend hotspot remains extreme:
  - `trr_backend/repositories/social_season_analytics.py`: 52,902 lines
  - `tests/repositories/test_social_season_analytics.py`: 28,327 lines
- The app hotspot remains concentrated:
  - `apps/web/src/app/admin/trr-shows/[showId]/page.tsx`: 17,083 lines
  - `apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`: 12,717 lines
  - `apps/web/src/components/admin/reddit-sources-manager.tsx`: 9,796 lines
  - `apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`: 9,290 lines
  - `apps/web/src/components/admin/season-social-analytics-section.tsx`: 8,777 lines
- The app proxy surface is still wide:
  - `apps/web/src/app/api/admin/trr-api`: 206 route files
  - repeated `Backend API not configured` and upstream error mapping still exist across many route handlers
- The app config surface is still distributed:
  - server auth: `apps/web/src/lib/server/auth.ts`
  - proxy routing: `apps/web/src/proxy.ts`
  - client auth headers: `apps/web/src/lib/admin/client-auth.ts`
  - client access allowlists: `apps/web/src/lib/admin/client-access.ts`

## Assumptions

1. No backend API version bump is desired for this remediation set.
2. Backend monolith extraction should preserve public response shapes and route contracts while moving implementation behind new module boundaries.
3. `screenalytics` should remain untouched unless backend auth, payload, or client contracts actually change.
4. The large app pages should be decomposed by extracting controllers, route-state helpers, and section components, not by rewriting product behavior.
5. E2E growth should target highest-risk admin workflows only; broad page-by-page coverage is out of scope.
6. Generated artifact churn in `apps/web/src/lib/admin/api-references/generated/inventory.ts` is a workflow problem, not a reason to remove the generated inventory feature.

## Goals

1. Reduce the highest-risk backend hotspot by carving stable seams out of `social_season_analytics.py`.
2. Reduce app-side contract drift by consolidating repeated proxy and error-handling logic.
3. Replace distributed env parsing with typed, centralized config ownership.
4. Decompose the largest admin files into smaller controllers and UI sections with stable interfaces.
5. Add browser-level coverage for the admin workflows most exposed to cross-layer regressions.
6. Preserve existing backend and UI behavior while making future changes cheaper and safer.

## Non-Goals

1. Full rewrite of the backend social ingest control plane.
2. Full rewrite of the TRR admin UI.
3. New product features unrelated to concern-map remediation.
4. Broad screenalytics refactors with no shared-contract driver.
5. Replacing the generated admin API inventory mechanism.

## Preflight Checks

These should be completed before the first execution phase starts.

1. Run workspace pre-plan and task scaffolding.
   - `cd /Users/thomashulihan/Projects/TRR && ./scripts/handoff-lifecycle.sh pre-plan`
   - Create `docs/cross-collab/TASK{N}/` folders for the repos that will participate in the first execution phase.
2. Freeze the hotspot files for opportunistic feature work during remediation.
   - Backend: `trr_backend/repositories/social_season_analytics.py` and `tests/repositories/test_social_season_analytics.py`
   - App: the target admin pages for the active phase
3. Capture caller inventory before moving backend seams.
   - `api/routers/socials.py`
   - any imports of `get_queue_status`, run/sync-session readers, and dispatch functions
   - `trr_backend/clients/screenalytics.py` plus `screenalytics` tests if a shared client surface appears in scope
4. Capture baseline verification before backend extraction.
   - targeted backend tests around live-status, queue status, sync sessions, and admin operations
5. Pick the initial module boundaries before editing.
   - read-path extraction package for backend control-plane reads
   - shared route-helper surface for app proxy routes
   - typed config ownership boundary for server-only versus public env

## Phased Implementation

### Phase 1: Backend read-path seam extraction

Rank: 1
Why first:
- highest-risk, highest-leverage hotspot
- directly touches the live queue and admin health surfaces already hardened operationally
- creates cleaner boundaries for later app proxy simplification

Scope:
- Extract queue-status and admin-operations read logic out of `trr_backend/repositories/social_season_analytics.py` into a dedicated backend package.
- Keep `api/routers/socials.py` and any current callers on stable public functions while moving implementation behind new modules.
- Start with the current live-status, queue-status, and sync-session read paths only.

Recommended decomposition:
- `Phase 1A`: extract queue-status read-model helpers and public `get_queue_status` implementation wrapper
- `Phase 1B`: extract sync-session and run-status read surfaces that share queue-health dependencies
- `Phase 1C`: split matching tests from `tests/repositories/test_social_season_analytics.py` into new focused test modules

Do not combine with:
- dispatch/recovery writes
- worker-claim logic
- media mirror logic
- platform-specific scrape orchestration

Execution notes:
- Preserve the existing import path initially by making `social_season_analytics.py` delegate to new modules.
- Introduce a package boundary such as `trr_backend/socials/control_plane/` or `trr_backend/repositories/social_control_plane/`.
- Move test fixtures and assertions together with the first extracted public function, not later.

Acceptance criteria:
1. `get_queue_status` and related live-status readers execute through extracted modules instead of inline monolith code.
2. `api/routers/socials.py` keeps current response shapes and does not need route-level behavioral rewrites.
3. The first extracted tests no longer live exclusively inside `tests/repositories/test_social_season_analytics.py`.
4. No new queue-status or admin-health logic lands directly in the monolith after the extraction starts.

Validation:
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check .`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff format --check .`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_season_analytics.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/ -k "queue_status or sync_session or live_status or admin_operations"`

Risk notes:
- Largest risk is accidental contract drift while moving logic behind a new package.
- Second risk is extracting too much at once; keep Phase 1 read-only in behavior and narrow in scope.
- If new module boundaries require cross-file state untangling, stop after the first stable seam and re-plan before touching dispatch paths.

### Phase 2: Backend control-plane write and dispatch extraction

Rank: 2
Depends on:
- Phase 1 complete

Scope:
- Extract the write-heavy control-plane paths from `social_season_analytics.py` after the read seam is stable.
- Prioritize dispatch and recovery logic that most frequently changes:
  - due-job dispatch
  - sync-session mutation paths
  - run lifecycle updates
  - stale dispatch recovery

Recommended decomposition:
- `Phase 2A`: sync-session lifecycle mutations and run progress orchestration
- `Phase 2B`: dispatch metadata, due-job dispatch, and stale modal recovery logic
- `Phase 2C`: worker-claim and execution-lane policy extraction only if Phase 2A and 2B stay stable

Can be executed together:
- `Phase 2A` and `Phase 2B` should stay separate
- `Phase 2C` should be deferred unless the earlier slices are clean

Acceptance criteria:
1. Mutation and dispatch code paths have explicit module ownership separate from read models.
2. The monolith remains as a compatibility facade only for unchanged callers.
3. New tests cover extracted write paths outside the legacy repository test file.
4. Existing admin and sync-session endpoints still pass with no contract changes.

Validation:
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check .`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff format --check .`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_season_analytics.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/ -k "dispatch or sync_session or run_progress or modal"`

Risk notes:
- Dispatch and recovery code has the highest operational blast radius in the monolith.
- Avoid mixing worker-lane policy changes with pure extraction unless a bug requires it.
- If backend client contract changes become unavoidable, stop and schedule a small `screenalytics` follow-through slice before app work.

### Phase 3: App proxy route consolidation

Rank: 3
Depends on:
- Phase 1 complete
- Phase 2 only if the backend extraction changes helper inputs or route contracts

Scope:
- Reduce repeated route-layer behavior under `apps/web/src/app/api/admin/trr-api`.
- Centralize shared request construction, timeout selection, backend-unreachable handling, diagnostics, and status mapping.
- Use the existing helpers as the base:
  - `apps/web/src/lib/server/trr-api/backend.ts`
  - `apps/web/src/lib/server/trr-api/admin-read-proxy.ts`
  - `apps/web/src/lib/server/trr-api/social-admin-proxy.ts`

Recommended decomposition:
- `Phase 3A`: introduce shared route primitives for GET and mutation proxy handlers
- `Phase 3B`: migrate the highest-churn social and show-admin routes first
- `Phase 3C`: bulk-migrate the long tail of duplicate handlers in small batches

Can be executed together:
- `Phase 3A` and `Phase 3B`

Should stay separate:
- `Phase 3C` should land as multiple small migration slices, not one giant route sweep

Acceptance criteria:
1. New route files stop hand-rolling `TRR_API_URL`, backend auth, and repeated error mapping.
2. At least the highest-churn proxy groups use the shared primitives.
3. Route responses preserve status codes and error body shape unless an intentional normalization is documented.
4. The app no longer duplicates the same backend availability messaging across the first migrated route groups.

Validation:
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run lint`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec next build --webpack`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run test:ci`
- targeted route tests for migrated proxy handlers

Risk notes:
- Broad route migration is mechanically easy but review-hostile; batch it by feature family.
- Preserve current backend error semantics for the first migration slice to avoid accidental UX drift.

### Phase 4: App config and feature-gate normalization

Rank: 4
Depends on:
- Phase 3A helper boundaries established, because config should feed the proxy layer rather than reintroduce per-file reads

Scope:
- Create a typed config layer that centralizes env parsing and ownership across:
  - `apps/web/src/lib/server/auth.ts`
  - `apps/web/src/proxy.ts`
  - `apps/web/src/lib/admin/client-auth.ts`
  - `apps/web/src/lib/admin/client-access.ts`
- Separate server-only config, public config, and derived routing or allowlist policy.

Recommended decomposition:
- `Phase 4A`: create shared config modules and move pure parsing/helpers first
- `Phase 4B`: update server auth and proxy routing to consume shared config
- `Phase 4C`: update client auth/access code to consume public config only

Can be executed together:
- `Phase 4A` and `Phase 4B`

Should stay separate:
- `Phase 4C` if public env usage requires browser test confirmation

Acceptance criteria:
1. Env parsing is centralized behind typed helpers instead of being spread across auth, proxy, and client-access code.
2. Server-only config never leaks into client modules.
3. Admin host-routing, allowlists, and auth-provider selection have one documented ownership point each.
4. Existing auth and routing behavior remains intact under current env settings.

Validation:
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run lint`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec next build --webpack`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run test:ci`
- targeted auth and proxy tests
- targeted browser validation for admin host routing when those paths change

Risk notes:
- Config normalization can cause production-only regressions if server/public boundaries are blurred.
- Preserve fallback behavior and defaults until explicit env cleanup is separately approved.

### Phase 5: App admin-surface decomposition

Rank: 5
Depends on:
- Phase 3A complete
- Phase 4A complete

Scope:
- Break the largest admin modules into narrower controllers and section components without changing product behavior.
- Prioritize the files with the most mixed responsibilities:
  - `apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
  - `apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
  - `apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
  - follow-on: `reddit-sources-manager.tsx` and `season-social-analytics-section.tsx`

Recommended decomposition:
- `Phase 5A`: show page extraction
  - route-state parsing
  - data/controller hooks
  - tab-scoped UI sections
- `Phase 5B`: person page extraction
  - profile loading and settings controllers
  - refresh/media orchestration sections
  - gallery/detail presentation sections
- `Phase 5C`: social-week page extraction
  - live sync-session orchestration
  - post/detail rendering sections
  - shared media/lightbox helpers
- `Phase 5D`: follow-on extraction for `reddit-sources-manager.tsx` and `season-social-analytics-section.tsx`

Do not execute all of Phase 5 at once.
Execute one hotspot file per slice, with validation after each slice.

Acceptance criteria:
1. Each target file sheds major controller or section responsibilities into named submodules.
2. Route behavior and URL state semantics remain stable.
3. Extracted modules have narrower interfaces and targeted tests where practical.
4. The largest page files shrink materially without changing backend contracts.

Validation:
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run lint`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec next build --webpack`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run test:ci`
- targeted browser validation for the specific page under extraction

Risk notes:
- The failure mode here is cosmetic refactor that does not really reduce ownership complexity.
- Extract route-state and data controllers first; moving JSX alone is low leverage.

### Phase 6: Risk-based browser coverage and generated-artifact controls

Rank: 6
Depends on:
- at least one Phase 5 slice complete

Scope:
- Add or strengthen browser-level coverage for the highest-risk admin workflows:
  - show admin primary tab navigation and critical actions
  - person admin refresh/media flow
  - social-week sync-session and live-status flow
- Stabilize review noise around the generated admin API inventory by tightening regeneration and verification rules.

Recommended decomposition:
- `Phase 6A`: add E2E specs for show, person, and social-week critical flows
- `Phase 6B`: enforce generated inventory consistency in test or lint workflow

Can be executed together:
- `Phase 6A` and `Phase 6B`

Acceptance criteria:
1. Browser tests cover the highest-risk cross-layer admin workflows, not only static smoke navigation.
2. Failures in proxy/config/page decomposition have a browser-level signal.
3. Generated inventory drift is caught deterministically in CI or test workflow.

Validation:
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run lint`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec next build --webpack`
- `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm run test:ci`
- targeted browser validation with `chrome-devtools` or managed Chrome per workspace policy

Risk notes:
- Do not block earlier refactors on a large new E2E suite.
- Keep the new browser specs narrow, stable, and representative of real admin workflows.

## Architecture Impact

- Backend will move from one giant repository module toward a compatibility facade plus extracted control-plane packages.
- App route handling will move from many ad hoc proxy handlers toward shared server-side transport primitives.
- App config ownership will move toward a typed configuration boundary with explicit server/public separation.
- Admin UI files will move toward composition by route-state controller plus section components instead of page-level mega-components.

## Data or API Impact

- Preferred path is no externally visible API contract change.
- If backend extraction reveals inconsistent internal response shapes, normalize behind backend or app helper boundaries without changing public route contracts.
- If any backend auth or client contract must move, update:
  - `trr_backend/clients/screenalytics.py`
  - affected `screenalytics` tests
  - app proxy callers in the same session

## UX / Admin / Ops Considerations

- Preserve current admin route deep-link behavior during page decomposition.
- Preserve existing status codes and retryability semantics in app proxy routes during consolidation.
- Preserve live-status and sync-session observability payloads while extracting backend control-plane code.
- Keep browser verification focused on real admin tasks instead of broad visual smoke checks.

## Dependencies and Blockers

1. Backend seam extraction is the main prerequisite for the remaining high-leverage work.
2. Proxy consolidation should not begin as a broad sweep until the shared route helper surface is locked.
3. Config normalization should not happen before deciding which values are server-only versus public.
4. Browser coverage should follow the first page decomposition slice so tests lock in the new boundaries.
5. `screenalytics` work is blocked unless a backend contract actually changes.

## Acceptance Criteria

The remediation plan is complete when:

1. backend control-plane reads and writes are no longer owned only by `social_season_analytics.py`
2. the legacy repository file is reduced to compatibility exports or narrow orchestration glue
3. the app proxy layer uses shared primitives for the major backend-facing route families
4. env parsing and feature-gate ownership are centralized and typed
5. the largest admin pages have been split into controller and section modules
6. browser tests cover the highest-risk admin flows touched by the refactors
7. all touched repos pass their required fast checks

## Risks, Edge Cases, Open Questions

1. The backend monolith may hide shared mutable state or helper coupling that only surfaces during extraction. Mitigation: keep Phase 1 read-only in behavior and small in scope.
2. Some app route files may intentionally diverge in status mapping. Mitigation: migrate by route family and document intentional exceptions.
3. Admin host-routing and allowlist logic is duplicated between `auth.ts` and `proxy.ts`; centralization can accidentally alter local dev behavior. Mitigation: preserve current defaults and verify with targeted browser checks.
4. Large admin pages may have implicit sequencing between hooks and effects. Mitigation: extract route-state and data controllers before visual sections.
5. The remaining auth follow-up decision from the completed backend hardening slice still exists:
   - either keep env-gated `service_role` escape hatches as the compatibility path
   - or remove them in a future, explicit hardening slice
   This is not on the critical path for the current concern-map remediation plan.

## Follow-Up Improvements

These are worthwhile after the core remediation plan but are not required to close the concern-map items.

1. Decide whether the env-gated backend `service_role` escape hatches remain permanent compatibility flags or should be removed entirely.
2. Revisit non-stream live-status timeout behavior only if backend read extraction reveals additional blocking paths.
3. Add ownership docs for the new backend control-plane modules and app proxy/config primitives once the refactors land.

## Recommended Next Step After Approval

Start with Phase 1A: extract the queue-status and admin-operations read seam out of `trr_backend/repositories/social_season_analytics.py`, while keeping the public `get_queue_status` contract stable.

Why this should go first:

1. It attacks the largest remaining risk concentration directly.
2. It builds a stable backend boundary before app-side proxy and page work.
3. It reduces the cost of every later social-ingest or admin-health change.
4. It can be executed without forcing immediate `screenalytics` or app changes if contracts stay stable.

## Ready for Execution

Yes, with the preflight checks above and backend-first sequencing enforced.
