# Backend Codebase Cleanup Inventory

Date: 2026-05-19

Scope:
- `TRR-Backend/api`
- `TRR-Backend/trr_backend`
- `TRR-Backend/tests`

This is an ownership inventory for future backend cleanup. It does not authorize
behavior refactors, route moves, package moves, SQL moves, or test rewrites by
itself. Later slices should deepen Modules behind current Interfaces before any
file reorganization.

## Backend Ownership Map

### API entry and route ownership

- `TRR-Backend/api/main.py`
  - Owns FastAPI app construction, middleware wiring, and router registration.
  - All listed routers are included with the `/api/v1` prefix.
  - This is high-risk for route shape and admin/public contract changes.
- `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`
  - Own request authentication helpers and admin/session dependencies.
  - Treat as Interface Modules for route access control.
- `TRR-Backend/api/deps.py`
  - Owns route dependency helpers such as Supabase client/list-result handling.
  - Keep as a route-layer Adapter surface; do not move DB behavior here.
- `TRR-Backend/api/realtime/*`
  - Owns websocket/realtime broker and event helpers.
  - Safe to reorganize only behind websocket smoke tests.
- `TRR-Backend/api/routers/*.py`
  - Own HTTP request parsing, auth dependency use, response shaping, and route-local orchestration.
  - Routers should not own durable SQL or scraper implementation logic.
  - Oversized routers should first gain route-local private Modules before any domain promotion.
- `TRR-Backend/api/routers/socials/*`
  - Owns the admin/social route surface.
  - `TRR-Backend/api/routers/socials/_surfaces.py` is already a small route-surface test helper and is a useful Seam for route inventory checks.
  - `TRR-Backend/api/routers/socials/__init__.py` remains a high-risk aggregator because tests and web callers depend on many existing paths.

### Domain and infrastructure ownership

- `TRR-Backend/trr_backend/db/*`
  - Owns database connection, execution, pooling, and DB-lane behavior.
  - High-risk because route, repository, test, and runtime contracts depend on these helpers.
- `TRR-Backend/trr_backend/repositories/*`
  - Owns persistence Interfaces and SQL-backed read/write behavior.
  - Keep SQL in repository Modules or DB helpers, not route handlers.
  - `TRR-Backend/trr_backend/repositories/social_season_analytics.py` is a compatibility alias to `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`; callers still treat the repository path as an Interface.
- `TRR-Backend/trr_backend/socials/*`
  - Owns social platform behavior, worker control plane, platform Adapters, scraper runtimes, read models, and social analytics implementation.
  - Platform packages such as `instagram`, `tiktok`, `twitter`, `threads`, `facebook`, `youtube`, and `socialblade` should deepen internally before cross-platform moves.
- `TRR-Backend/trr_backend/media/*`
  - Owns hosted media, S3/object-storage mirroring, image variants, face crops, Getty replacement, and uploads.
  - `TRR-Backend/trr_backend/media/s3_mirror.py` is a shared Adapter-heavy Module used across routers, repositories, pipeline, vision, socials, and tests.
- `TRR-Backend/trr_backend/ingestion/*`, `TRR-Backend/trr_backend/integrations/*`, `TRR-Backend/trr_backend/scraping/*`
  - Own source-specific ingestion, third-party fetch/parsing, and scraper parsing behavior.
  - Useful future cleanup surface when route-local orchestration currently reaches into these Modules directly.
- `TRR-Backend/trr_backend/pipeline/*`
  - Owns admin operation orchestration, operation streams, and refresh stages.
  - Keep as the Seam between routes and longer-running work.
- `TRR-Backend/trr_backend/modal_dispatch.py`, `TRR-Backend/trr_backend/modal_jobs.py`
  - Own Modal dispatch/job integration.
  - Modal-affecting changes require Modal completion work under project rules.
- `TRR-Backend/trr_backend/services/*`
  - Owns domain support Modules such as person image detection/source policy and retained cast screentime helpers.
  - Good target shape for later Module deepening because these files already concentrate behavior behind narrower Interfaces.
- `TRR-Backend/trr_backend/security/*`, `TRR-Backend/trr_backend/middleware/*`, `TRR-Backend/trr_backend/observability.py`, `TRR-Backend/trr_backend/problem.py`
  - Own cross-cutting request safety, error, and observability behavior.
  - High Leverage but high risk when Interfaces change.

### Test ownership

- `TRR-Backend/tests/api/*`
  - Own route shape, auth/dependency, and endpoint behavior tests.
  - Important for router extraction because many tests patch route-local helpers by module path.
- `TRR-Backend/tests/repositories/*`
  - Own repository Interface and persistence behavior tests.
  - Important before moving SQL, DB helpers, or social analytics compatibility surfaces.
- `TRR-Backend/tests/socials/*`
  - Own scraper, platform Adapter, worker, and social pipeline tests.
  - Use these when deepening platform internals.
- `TRR-Backend/tests/media/*`
  - Own media mirror and hosted media behavior tests.
  - Required before reorganizing `TRR-Backend/trr_backend/media/s3_mirror.py`.
- `TRR-Backend/tests/db/*`, `TRR-Backend/tests/migrations/*`
  - Own DB lane and schema-adjacent checks.
  - Required for SQL or migration-adjacent cleanup.

## Module And Interface Inventory

| Ownership area | Current Module shape | Current Interface | Cleanup posture |
| --- | --- | --- | --- |
| `TRR-Backend/api/main.py` | One app Module registers all routers and middleware. | FastAPI app, middleware behavior, `/api/v1` route inclusion. | High-risk. Keep stable unless route registration itself is the slice. |
| `TRR-Backend/api/routers/admin_person_images.py` | Very large route Module with request parsing, response shaping, orchestration, media calls, and identity/source policy work. | Admin person image endpoints plus route-local helper names used in tests. | High-risk but good deepening candidate. Start with route-local private Modules. |
| `TRR-Backend/api/routers/socials/__init__.py` | Very large social route aggregator despite nearby route package files. | Admin/social route paths, route helper names, imports from `trr_backend.repositories.social_season_analytics` and `trr_backend.repositories.reddit_refresh`. | High-risk. Deepen by route family and preserve route inventory tests. |
| `TRR-Backend/api/routers/admin_show_links.py` | Large route Module that mixes show links, Fandom/Wikipedia scraping, operation streams, and repository calls. | Admin show link routes and `fandom_router` registered separately in `api/main.py`. | High-risk. Split only behind current tests and route inventory. |
| `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` | Extremely large social analytics/control-plane implementation. | Compatibility Interface via `TRR-Backend/trr_backend/repositories/social_season_analytics.py`; direct canonical imports also exist. | Highest-risk. Do not move first. Create stable Interface/Adapter seams before extraction. |
| `TRR-Backend/trr_backend/repositories/social_season_analytics.py` | Compatibility alias that replaces its module object with `social_season_analytics_impl`. | Legacy repository import path used by routes, tests, and social workers. | High-risk Interface. Preserve during all Module deepening. |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py` | Large platform fetcher for Instagram comments with Scrapling HTTP utilities, count handling, proxy config, and scraper models. | Fetcher functions/classes used by comments job runner/tests. | Good platform-local deepening candidate after tests pin fetcher Interface. |
| `TRR-Backend/trr_backend/repositories/reddit_refresh.py` | Large repository/worker Module with Reddit fetch, matching, run lifecycle, Modal dispatch, SQL, cache/read helpers, and worker loop behavior. | Repository functions used by admin/social routes, Modal jobs, pipeline operation producers, and tests. | High-risk. Separate pure matching/parsing from run persistence only after Interface tests. |
| `TRR-Backend/trr_backend/media/s3_mirror.py` | Shared media Adapter Module with URL validation, content sniffing, key builders, upload/download, mirror, prune, and logo variant behavior. | Public media functions imported by many routers, media Modules, pipelines, socials, vision, and tests. | High-risk shared utility. Deepen by cohesive sub-Interfaces, not broad file moves. |
| `TRR-Backend/trr_backend/socials/api/handlers/*` | Small social API handler Modules already pulled out of routes. | Handler functions called by social routes. | Safe pattern for future route-local extraction. |
| `TRR-Backend/trr_backend/socials/control_plane/*` | Smaller Modules for social worker health, dispatch, runtime, queue status, run reads/lifecycle, recovery, and windowing. | Internal social control-plane Interfaces. | Good target shape; prefer adding Depth here instead of more route logic. |
| `TRR-Backend/trr_backend/socials/read_models/*` | Read-model Modules for social account profile and season analytics. | Read helpers used by routes and social analytics. | Good candidate for safe reorganization when Interface tests already cover output shape. |
| `TRR-Backend/trr_backend/services/person_images/*` | Focused person image detection/source policy Modules. | Domain helpers imported by `admin_person_images.py` and tests. | Safe model for first route extraction slices. |

## High-Risk Areas

- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`
  - About 61k lines in the current checkout.
  - It owns too many concepts: analytics reads, job/run lifecycle, queue status, platform auth helpers, catalog backfill, media mirror jobs, profile detail reads, and remediation.
  - The repository compatibility alias means the Seam is confusing: callers use `trr_backend.repositories.social_season_analytics`, but implementation lives under `trr_backend.socials`.
  - Risk: moving names too early breaks tests, route imports, workers, and Modal job behavior.
- `TRR-Backend/api/routers/socials/__init__.py`
  - About 8.2k lines and imports many functions from `trr_backend.repositories.social_season_analytics` inside route handlers.
  - Tests already inspect route shape through `TRR-Backend/api/routers/socials/_surfaces.py`.
  - Risk: route grouping or import movement can change route order, path coverage, auth behavior, or monkeypatch locations.
- `TRR-Backend/api/routers/admin_person_images.py`
  - About 17k lines with route logic, operation streams, media mirroring, facebank seed behavior, identity assignment, and source policy calls.
  - Risk: route-local helper extraction can break tests that patch private route helpers.
- `TRR-Backend/api/routers/admin_show_links.py`
  - About 8.2k lines and owns show link reads/writes plus source discovery and Fandom-related operations.
  - Risk: `fandom_router` is registered separately in `api/main.py`, so a cleanup must preserve both router objects.
- `TRR-Backend/trr_backend/repositories/reddit_refresh.py`
  - About 5.9k lines with HTTP fetching, SQL, worker lifecycle, Modal dispatch references, cached read models, and analytics helpers.
  - Risk: behavior spans repository, worker, route, pipeline, and Modal job call paths.
- `TRR-Backend/trr_backend/media/s3_mirror.py`
  - About 2.8k lines but high Leverage and broad import reach.
  - Risk: shared key-building, URL validation, hosted URL, and upload Interfaces are used across many Modules.
- Generated/runtime clutter under scoped paths
  - `.DS_Store`, `__pycache__`, and `.pyc` files exist under `TRR-Backend/api`, `TRR-Backend/trr_backend`, and `TRR-Backend/tests`.
  - This inventory records them only. Removal is outside this backend ownership slice unless a workspace hygiene slice explicitly owns it.

## Safe Later Reorganization Candidates

- Route-local private Modules for oversized routers:
  - `TRR-Backend/api/routers/admin_person_images.py`
  - `TRR-Backend/api/routers/admin_show_links.py`
  - `TRR-Backend/api/routers/socials/__init__.py`
  - Safe condition: preserve public router objects, route paths, dependency behavior, and test monkeypatch paths or update tests in the same focused slice.
- Existing social route handler pattern:
  - `TRR-Backend/trr_backend/socials/api/handlers/live_status.py`
  - `TRR-Backend/trr_backend/socials/api/handlers/profile_reads.py`
  - Safe condition: new handlers hide real behavior behind a small Interface and increase Locality, not just pass through.
- Existing social control-plane Modules:
  - `TRR-Backend/trr_backend/socials/control_plane/run_reads.py`
  - `TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py`
  - `TRR-Backend/trr_backend/socials/control_plane/queue_status.py`
  - `TRR-Backend/trr_backend/socials/control_plane/worker_health.py`
  - Safe condition: callers keep the compatibility Interface until direct route imports are reduced.
- Existing focused person image services:
  - `TRR-Backend/trr_backend/services/person_images/detection.py`
  - `TRR-Backend/trr_backend/services/person_images/source_policy.py`
  - Safe condition: move behavior toward these Modules only when it improves Depth and keeps route Interfaces small.
- Platform-internal social packages:
  - `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/*`
  - `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/*`
  - `TRR-Backend/trr_backend/socials/tiktok/posts_scrapling/*`
  - `TRR-Backend/trr_backend/socials/threads/posts_scrapling/*`
  - Safe condition: keep each platform Adapter stable and run platform-specific tests.

## First Two Module-Deepening Slices

### Slice 1: Social route Interface deepening

Practical result: the largest social route file becomes easier to change without moving route paths or social implementation code.

- Files involved:
  - `TRR-Backend/api/routers/socials/__init__.py`
  - `TRR-Backend/api/routers/socials/_surfaces.py`
  - Existing package siblings under `TRR-Backend/api/routers/socials/`
  - Tests under `TRR-Backend/tests/api/routers/test_socials_route_shape.py`
  - Focused route tests such as `TRR-Backend/tests/api/routers/test_socials_reddit_refresh_routes.py`, `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`, and platform-specific social route tests.
- Current friction:
  - Route handlers import deeply from `trr_backend.repositories.social_season_analytics` and `trr_backend.repositories.reddit_refresh`.
  - The Interface is too wide: callers need route path knowledge, social repository names, worker behavior, auth/Modal details, and response shapes at once.
- Deepening direction:
  - First add route-family helpers or handler Modules within the `api/routers/socials` package.
  - Keep `router` and all route paths registered exactly as they are.
  - Use `route_inventory()` as the route-shape Seam.
  - Do not move `social_season_analytics_impl.py` in this slice.
- Leverage:
  - Route files keep HTTP concerns while social behavior stays behind existing repository/control-plane Interfaces.
  - Future extraction gets better Locality because route response shaping can change without touching worker internals.
- Validation:
  - `cd TRR-Backend && ./.venv/bin/python -m pytest tests/api/routers/test_socials_route_shape.py tests/api/routers/test_socials_reddit_refresh_routes.py tests/api/routers/test_socials_season_analytics.py`
  - Add narrower platform route tests when the touched route family requires them.

### Slice 2: Person image route orchestration deepening

Practical result: the person images admin route keeps the same endpoints while source policy, media mirroring calls, operation stream setup, and response shaping become easier to reason about.

- Files involved:
  - `TRR-Backend/api/routers/admin_person_images.py`
  - `TRR-Backend/trr_backend/services/person_images/detection.py`
  - `TRR-Backend/trr_backend/services/person_images/source_policy.py`
  - `TRR-Backend/trr_backend/media/s3_mirror.py`
  - `TRR-Backend/trr_backend/media/getty_replacement.py`
  - Repository helpers under `TRR-Backend/trr_backend/repositories/identity_assignment.py`, `TRR-Backend/trr_backend/repositories/tagging_references.py`, `TRR-Backend/trr_backend/repositories/face_references.py`, and `TRR-Backend/trr_backend/repositories/media_links.py`
  - Tests under `TRR-Backend/tests/api/routers/test_admin_person_images.py`, `TRR-Backend/tests/api/routers/test_admin_person_images_auto_count_enrichment.py`, and `TRR-Backend/tests/services/test_person_image_detection.py`
- Current friction:
  - The router combines request parsing, operational orchestration, media Adapter calls, identity assignment, source policy, and response shaping.
  - Some helper names are likely part of the test Interface through monkeypatching, so moving them directly is risky.
- Deepening direction:
  - Start with route-local private Modules for response shaping and operation payload assembly.
  - Promote only stable person-image behavior into `trr_backend/services/person_images/*` when tests call the same Interface that routes call.
  - Keep S3/object-storage calls behind `trr_backend/media/s3_mirror.py`; do not move media Adapter code in this slice.
- Leverage:
  - Routes get a smaller Interface with higher Depth: fewer concepts need to be understood to change one endpoint.
  - Locality improves because person image policy and detection behavior live in person image Modules, not mixed with HTTP code.
- Validation:
  - `cd TRR-Backend && ./.venv/bin/python -m pytest tests/api/routers/test_admin_person_images.py tests/api/routers/test_admin_person_images_auto_count_enrichment.py tests/services/test_person_image_detection.py tests/services/test_person_image_source_policy.py`

## Validation Commands

Doc-only inventory validation run for this slice:

- `sed -n '1,240p' /Users/thomashulihan/Projects/TRR/.codex/rules/trr-project.md`
- `sed -n '1,260p' /Users/thomashulihan/Projects/TRR/.plan-work/plan-architect/trr-codebase-cleanup-20260519/REVISED_PLAN.md`
- `sed -n '1,260p' /Users/thomashulihan/Projects/TRR/.plan-work/plan-architect/trr-codebase-cleanup-20260519/HANDOFF.md`
- `sed -n '1,240p' /Users/thomashulihan/Projects/TRR/docs/workspace/dev-commands.md`
- `find /Users/thomashulihan/Projects/TRR/TRR-Backend/api /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend /Users/thomashulihan/Projects/TRR/TRR-Backend/tests -path '*/__pycache__' -prune -o -type f -name '*.py' -print`
- `find /Users/thomashulihan/Projects/TRR/TRR-Backend/api /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend /Users/thomashulihan/Projects/TRR/TRR-Backend/tests -path '*/__pycache__' -prune -o -type f -name '*.py' -print0 | xargs -0 wc -l | sort -nr | head -80`
- `rg -n "include_router|api\\.routers|router =|prefix=|tags=" /Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers`
- `rg -n "social_season_analytics_impl|from trr_backend\\.repositories import social_season_analytics|trr_backend\\.repositories\\.social_season_analytics" /Users/thomashulihan/Projects/TRR/TRR-Backend/api /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend /Users/thomashulihan/Projects/TRR/TRR-Backend/tests`
- `rg -n "from trr_backend\\.media import s3_mirror|trr_backend\\.media\\.s3_mirror|from trr_backend\\.repositories import reddit_refresh|trr_backend\\.repositories\\.reddit_refresh" /Users/thomashulihan/Projects/TRR/TRR-Backend/api /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend /Users/thomashulihan/Projects/TRR/TRR-Backend/tests`
- `find /Users/thomashulihan/Projects/TRR/TRR-Backend/api /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend /Users/thomashulihan/Projects/TRR/TRR-Backend/tests \\( -name '.DS_Store' -o -path '*/__pycache__/*' -o -name '*.pyc' \\) -print`

Future implementation validation:

- Router-only extraction:
  - `cd TRR-Backend && ./.venv/bin/python -m pytest tests/api/routers/<focused-test-file>.py`
- Repository/social extraction:
  - `cd TRR-Backend && ./.venv/bin/python -m pytest tests/repositories tests/socials`
- Media Adapter extraction:
  - `cd TRR-Backend && ./.venv/bin/python -m pytest tests/media tests/api/routers/test_admin_person_images.py`
- File moves:
  - `cd TRR-Backend && make repo-map-check`
- Broader backend cleanup slice:
  - `cd TRR-Backend && ./.venv/bin/python -m pytest tests/api tests/repositories tests/socials`

No code tests are required for this inventory-only document.

## Explicit Out Of Scope

- No backend source file changes.
- No backend test changes.
- No route path, route registration, auth dependency, or response-shape changes.
- No SQL, migration, DB-lane, Supabase, or repository behavior changes.
- No Modal worker, Modal dispatch, scraper runtime, or secret-preparation changes.
- No `TRR-APP`, root `Makefile`, root scripts, profiles, `AGENTS.md`, `.codex` config, or workspace hygiene edits.
- No removal of `.DS_Store`, `__pycache__`, or `.pyc` files in this slice.
- No reorganization of `screenalytics`, `BRAVOTV`, route aliases, or adjacent workspaces.

## Coordination Notes

- This file is the only intended output for the backend ownership inventory slice.
- Existing generated/runtime clutter was observed under the scoped backend paths and left untouched.
- The safest cleanup order is Interface-first: preserve current import paths and route shape, add tests at the intended Seam, then deepen Modules where the new Module has real Depth and improves Leverage and Locality.
