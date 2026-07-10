# Plan 020: Move vision-only dependencies out of base backend requirements

> **Executor instructions**: This affects dependency surfaces. Do not remove a
> dependency until import checks prove the lean API still starts.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- requirements.in requirements.lock.txt requirements.modal.vision.in requirements.modal.vision.lock.txt trr_backend/modal_jobs.py`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: deps
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

Base backend installs include heavy vision dependencies even though Modal vision
has its own requirements file. That bloats dev and CI installs.

## Current state

- `requirements.in:13` pins `numpy==1.26.4`.
- `requirements.in:14` pins `sympy==1.13.1`.
- `requirements.in:38` includes `deepface>=0.0.93`.
- `requirements.in:39` pins `opencv-python==4.11.0.86`.
- `requirements.modal.vision.in` already includes `numpy`, `opencv-python`,
  `opencv-python-headless`, and vision packages.
- `trr_backend/modal_jobs.py` binds vision functions to the Modal vision image.

## Scope

**In scope**:
- backend requirement input/lock files
- lazy-import guard fixes if import checks reveal one

**Out of scope**:
- Rewriting vision code.
- Removing dependencies needed by non-vision runtime.

## Steps

1. Confirm which of the listed packages are imported during `python -c "import api.main"`.
2. Move vision-only packages from `requirements.in` to the vision requirements
   surface if not already present.
3. Recompile affected lockfiles with the repo's pinned `uv` command pattern.
4. Add or update an import test if a lazy-import guard is needed.

## Commands

Run from `TRR-Backend/`:

```bash
uv pip compile requirements.in --python-version 3.11 -o requirements.lock.txt
uv pip compile requirements.modal.vision.in --python-platform x86_64-manylinux_2_28 --index-strategy unsafe-best-match -o requirements.modal.vision.lock.txt
.venv/bin/python -c "import api.main"
.venv/bin/python -m pytest tests/api -q
```

## Done criteria

- Base requirements no longer include packages used only by the vision Modal lane.
- API import and API tests pass without vision-only imports.
- Vision lockfile still contains the vision packages.
