# Backend Social Route Cleanup Slice

Created: 2026-05-19

This prepares the first backend Module-deepening slice from
`docs/workspace/backend-codebase-cleanup-inventory.md`.

## Practical Result

Make `TRR-Backend/api/routers/socials/__init__.py` easier to change without
renaming routes, moving social implementation code, or changing worker/runtime
behavior.

## Ownership Scope

Allowed implementation scope for the slice:

- `TRR-Backend/api/routers/socials/__init__.py`
- `TRR-Backend/api/routers/socials/_surfaces.py`
- Existing sibling route modules under `TRR-Backend/api/routers/socials/`
- Focused tests under `TRR-Backend/tests/api/routers/`

Read-only context:

- `TRR-Backend/trr_backend/socials/api/handlers/*`
- `TRR-Backend/trr_backend/socials/control_plane/*`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`

Out of scope:

- Moving or renaming routes.
- Moving `social_season_analytics_impl.py`.
- Changing SQL, migrations, DB lane selection, Modal dispatch, scraper behavior,
  worker claims, or platform adapters.
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
cd TRR-Backend && ./.venv/bin/ruff check api/routers/socials tests/api/routers/test_socials_route_shape.py tests/api/routers/test_socials_season_analytics.py
cd TRR-Backend && ./.venv/bin/python -m pytest tests/api/routers/test_socials_route_shape.py tests/api/routers/test_socials_season_analytics.py
```

Add when files move:

```bash
cd TRR-Backend && make repo-map-check
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

## Docs Visibility Note

This workspace currently has local excludes for `docs/` and `.plan-work/` in
`.git/info/exclude`. New cleanup docs exist on disk but do not appear in normal
`git status`. Do not remove the broad `docs/` exclude casually: it would expose
many unrelated untracked planning and status files. Use explicit paths when
reviewing these cleanup docs.
