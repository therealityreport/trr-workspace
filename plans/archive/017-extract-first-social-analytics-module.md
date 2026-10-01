# Plan 017: Extract the first stable slice from social season analytics

> **Executor instructions**: This is an incremental extraction plan, not a
> rewrite. Preserve import compatibility.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/social_season_analytics_impl.py api/routers/admin_person_images.py api/routers/socials/__init__.py`

## Status

- **Priority**: P3
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

`social_season_analytics_impl.py` is 68,027 lines and has compatibility imports
from older paths. Large edits in this file are hard to review and easy to
regress. The lazy first step is to extract one cohesive, low-churn helper group
behind re-export shims.

## Current state

- `trr_backend/socials/social_season_analytics_impl.py` is 68,027 lines.
- Its docstring says the legacy repository import path aliases this module while
  ownership moves under `trr_backend.socials`.
- `api/routers/admin_person_images.py` is 17,207 lines.
- `api/routers/socials/__init__.py` is 9,365 lines.

## Scope

**In scope**:
- one extracted module under `trr_backend/socials/`
- import/re-export shims in `social_season_analytics_impl.py`
- focused tests for the extracted symbols

**Out of scope**:
- Moving route handlers.
- Renaming public functions.
- Multiple extraction slices.

## Steps

1. Use `git log --stat` and `rg "^def |^class "` to pick one low-churn,
   cohesive helper group. Prefer pure helpers with tests or easy tests.
2. Move only that group into a new module.
3. Re-export through `social_season_analytics_impl.py` so importers keep working.
4. Add/adjust focused tests for the moved helpers.
5. Run import and API tests to catch circular imports.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -c "import api.main"
.venv/bin/python -m pytest tests/api -q
ruff check trr_backend/socials/social_season_analytics_impl.py trr_backend/socials
```

## Done criteria

- One cohesive helper group lives outside the god module.
- Existing import paths still work.
- Import gate, API tests, and lint pass.
