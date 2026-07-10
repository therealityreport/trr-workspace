# Plan 015: Fail closed when production CORS origins are not configured

> **Executor instructions**: Preserve local development ergonomics. This plan is
> about deployed/prod behavior, not breaking localhost.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- api/main.py tests/api/test_health.py tests/test_startup_config.py`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

When `CORS_ALLOW_ORIGINS` is unset, the backend currently configures
`allow_origins=["*"]`. Credentials are disabled in that case, but production
should require explicit origins so a missing env var is visible.

## Current state

- `api/main.py:504` documents CORS env behavior.
- `api/main.py:507` sets `cors_origins = get_cors_origins()`.
- `api/main.py:513` passes `allow_origins=cors_origins if cors_origins else ["*"]`.
- Local app launchers set explicit Portless origins.

## Scope

**In scope**:
- `api/main.py`
- focused startup/config tests
- `.env.example` only if documenting the new prod requirement is necessary

**Out of scope**:
- Changing auth.
- Changing TRR Portless browser URLs.

## Steps

1. Identify the existing env flag that distinguishes local/dev from deployed
   runtime, or add a small helper based on existing config conventions.
2. Keep wildcard CORS only for local development.
3. In production/deployed mode, raise a startup/config error if no explicit CORS
   origins are configured.
4. Add tests for local fallback and production fail-closed behavior.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -m pytest tests/test_startup_config.py tests/api/test_health.py -q
ruff check api/main.py tests/test_startup_config.py tests/api/test_health.py
```

## Done criteria

- Production/deployed startup does not silently allow `*`.
- Local development remains usable without custom CORS env.
- Focused tests and lint pass.
