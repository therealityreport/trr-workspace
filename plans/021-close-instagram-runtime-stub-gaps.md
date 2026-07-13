# Plan 021: Close remaining Instagram runtime stub gaps

> **Executor instructions**: Verify live code first. Some original stub concerns
> are already partly fixed; do not add duplicate guards.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/instagram/runtimes trr_backend/socials/crawlee_runtime tests`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

Experimental Instagram runtimes should fail loudly when unsupported. Silent
protocol satisfaction can route production work into scaffold code.

## Current state

- `browser_use_runtime.py` now raises `RuntimeUnsupported` for steady-state
  profile/posts/detail and `NotImplementedError` for checkpoint recovery.
- `crawl4ai_runtime.py` raises `NotImplementedError` for profile/detail and
  `RuntimeUnsupported` for posts.
- `crawlee_runtime/runtime.py` is a real incremental wrapper, not just a TODO
  stub, but should still have tests around unavailable dependency behavior.

## Scope

**In scope**:
- `trr_backend/socials/instagram/runtimes/browser_use_runtime.py`
- `trr_backend/socials/instagram/runtimes/crawl4ai_runtime.py`
- `trr_backend/socials/crawlee_runtime/runtime.py`
- focused runtime tests

**Out of scope**:
- Implementing browser-use or crawl4ai.
- Changing dispatcher priority.

## Steps

1. Add tests that instantiate each runtime and assert unsupported methods raise
   `RuntimeUnsupported` or `NotImplementedError` as intended.
2. Ensure healthchecks return unavailable when optional packages are absent.
3. If any scaffold method still returns plausible success without implementation,
   replace it with an explicit exception.
4. Keep comments short and factual.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -m pytest tests/socials -q -k "runtime or crawlee or crawl4ai or browser_use"
ruff check trr_backend/socials/instagram/runtimes trr_backend/socials/crawlee_runtime
```

## Done criteria

- Experimental runtimes cannot silently handle production work.
- Tests pin unsupported/unavailable behavior.
- No runtime implementation is added.
