# Backend Social Route Cleanup Slice

Created: 2026-05-19

This prepares the first backend Module-deepening slice from
`docs/workspace/backend-codebase-cleanup-inventory.md`.

Updated: 2026-05-21

## Practical Result

Make `TRR-Backend/api/routers/socials/__init__.py` easier to change without
renaming routes, moving social implementation code, or changing worker/runtime
behavior.

## Current Slice Status

Status: active; first route-family extraction is validated, and the next narrow
Reddit helper extraction has started.

Current codebase changes that belong to this slice:

- `TRR-Backend/api/routers/socials/_analytics_cache.py` now owns social
  analytics, week-summary, week-detail, live-health, and coverage cache helpers.
- `TRR-Backend/api/routers/socials/_profile_cache.py` now owns account-profile
  cache helpers and profile-progress/freshness cache helpers.
- `TRR-Backend/api/routers/socials/analytics_read.py` owns route-local analytics
  include/path normalization and week-detail pagination/sort payload shaping.
- `TRR-Backend/api/routers/socials/reddit.py` now owns Reddit refresh/backfill
  request payload serialization helpers in addition to route-surface inventory.
- `TRR-Backend/api/routers/socials/__init__.py` still owns the public router and
  remains the compatibility surface for existing route imports and tests.
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` received a
  narrow SQL escaping fix for hosted-media JSON conditions after Browser
  verification exposed a psycopg percent-pattern failure.

Current validation state:

- Focused Ruff passed for `api/routers/socials`,
  `trr_backend/socials/social_season_analytics_impl.py`, and focused tests.
- Focused route-shape, season-analytics route, hosted-media SQL, and repository
  social analytics tests passed.
- `make app-check` passed after the workspace package-manager helper was fixed.
- `make test-fast` passed after the repository blocker was resolved.
- Browser verification used `make dev-hybrid` and reached
  `http://admin.localhost:3000/southern-charm/s11/social`; Playwright visual
  verification confirmed the page no longer shows timeout/degraded analytics
  copy after the analytics timeout-tier fix.

Resolved runtime issues from Browser verification:

- The admin season episodes proxy returned HTTP 500 because the app requested
  `limit=500` and the backend route capped the value lower. The backend route
  now accepts the app request.
- The social week-detail endpoint could time out through the app proxy because
  the backend generic request timeout was lower than the app's operator-facing
  timeout. The backend route now has a bounded route-specific cap.
- The first visual pass still showed `Social analytics snapshot request timed
  out`; this was fixed by aligning the client snapshot timeout with the backend
  request window.

Known blockers outside this route cleanup extraction:

- Static backend dirty-diff review found Instagram auth repair regressions in
  the current dirty backend checkout. Default/manual repair paths no longer
  pass `allow_cookie_refresh=True`, and validation-only failures can write
  cooldown state that blocks a later confirmed repair attempt.
- Keep those auth/ops fixes separate from route organization work.

## Ownership Scope

Allowed implementation scope for the slice:

- `TRR-Backend/api/routers/socials/__init__.py`
- `TRR-Backend/api/routers/socials/_analytics_cache.py`
- `TRR-Backend/api/routers/socials/_profile_cache.py`
- `TRR-Backend/api/routers/socials/analytics_read.py`
- `TRR-Backend/api/routers/socials/_surfaces.py`
- Existing sibling route modules under `TRR-Backend/api/routers/socials/`
- Focused tests under `TRR-Backend/tests/api/routers/`
- Focused repository tests for SQL-only fixes under
  `TRR-Backend/tests/repositories/`

Read-only context:

- `TRR-Backend/trr_backend/socials/api/handlers/*`
- `TRR-Backend/trr_backend/socials/control_plane/*`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`

Out of scope:

- Moving or renaming routes.
- Moving `social_season_analytics_impl.py`.
- Changing migrations, DB lane selection, Modal dispatch, scraper behavior,
  worker claims, or platform adapters.
- Further SQL changes beyond the already scoped hosted-media percent-escaping
  fix, unless a focused repository test proves the current route bug.
- Changing web-app proxy/client routes.

## Current Interface To Preserve

- FastAPI router export from `TRR-Backend/api/routers/socials/__init__.py`.
- All registered `/api/v1/admin/socials/...` and related route paths.
- Existing route names and method/path pairs observed by
  `TRR-Backend/api/routers/socials/_surfaces.py`.
- Existing imports from `trr_backend.repositories.social_season_analytics`.
- Existing social route tests that patch or import route-local helper names.

## First Implementation Step

Start with one route family inside `TRR-Backend/api/routers/socials/__init__.py`
whose behavior is already covered by tests.

Preferred first candidate:

- Social route shape and season analytics route response shaping.

Why this candidate:

- `TRR-Backend/tests/api/routers/test_socials_route_shape.py` can protect
  route inventory.
- `TRR-Backend/tests/api/routers/test_socials_season_analytics.py` can protect
  the route behavior most likely to be touched.
- The slice can introduce a private route-family Module or helper without
  moving the underlying social analytics implementation.

## Implementation Checklist

1. Capture current route inventory from `_surfaces.py`.
2. Identify one cohesive cluster in `api/routers/socials/__init__.py`.
3. Extract only HTTP-facing work:
   - request/search-param normalization
   - route-local response shaping
   - route-local helper functions
4. Keep social analytics and repository behavior behind the existing
   repository Interface.
5. Preserve monkeypatch paths used by existing tests, or update only the
   focused tests in the same slice when the Interface intentionally moves.
6. Run focused tests before any broader cleanup.

## Validation

Minimum commands:

```bash
cd TRR-Backend && ./.venv/bin/ruff check api/routers/socials trr_backend/socials/social_season_analytics_impl.py tests/api/routers tests/repositories
cd TRR-Backend && ./.venv/bin/python -m pytest tests/api/routers/test_socials_route_shape.py tests/api/routers/test_socials_season_analytics.py tests/repositories/test_social_season_analytics.py
```

If `tests/repositories/test_social_hosted_media_sql.py` exists in the dirty
checkout, include it in the focused pytest run.

Add when files move:

```bash
cd TRR-Backend && make repo-map-check
```

Add before completion:

```bash
make test-fast
make app-check
```

Add only if the slice changes runtime, workers, or scraper dispatch:

```bash
cd TRR-Backend && ./.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram
```

## Stop Conditions

Stop and re-scope before editing if:

- the selected route family has no focused test coverage;
- extraction requires changing `social_season_analytics_impl.py`;
- route inventory changes unexpectedly;
- a test relies on a private helper path and preserving it would make the new
  Module shallow;
- implementation crosses into Modal, DB lane, migration, or web-app proxy
  behavior.
- Browser/runtime triage requires changing app proxy behavior, season episodes
  route behavior, or week-detail query strategy. Split that into its own
  runtime-fix slice before continuing cleanup extraction.

## Docs Visibility Note

This workspace currently has local excludes for `docs/` and `.plan-work/` in
`.git/info/exclude`. New cleanup docs exist on disk but do not appear in normal
`git status`. Do not remove the broad `docs/` exclude casually: it would expose
many unrelated untracked planning and status files. Use explicit paths when
reviewing these cleanup docs.
