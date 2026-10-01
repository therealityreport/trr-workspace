# Plan 014: Run the backend container as a non-root user

> **Executor instructions**: Keep this Dockerfile-only unless tests prove a
> permission issue in startup scripts.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- Dockerfile start-api.sh`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

`TRR-Backend/Dockerfile` copies the app and starts it without setting `USER`, so
the container runs as root by default. A non-root user is a standard hardening
step for API containers.

## Current state

- `Dockerfile:1` uses `python:3.11-slim-bookworm`.
- `Dockerfile:6` sets `WORKDIR /app`.
- `Dockerfile:23` runs `COPY . .`.
- `Dockerfile:32` runs `CMD ["./start-api.sh"]`.
- There is no `USER` directive.

## Scope

**In scope**:
- `TRR-Backend/Dockerfile`
- `TRR-Backend/start-api.sh` only if it needs execute/permission handling

**Out of scope**:
- Changing runtime env vars.
- Reworking deployment manifests.

## Steps

1. Add a system user/group after dependency installation.
2. Ensure `/app` is owned by that user after `COPY . .`.
3. Add `USER <non-root-user>` before `CMD`.
4. Keep `PORT`, `TRR_BACKEND_HOST`, and `TRR_BACKEND_RELOAD` unchanged.

## Commands

Run from `TRR-Backend/`:

```bash
docker build -t trr-backend-nonroot-check .
docker run --rm trr-backend-nonroot-check python -c "import os; assert os.geteuid() != 0"
```

If Docker is unavailable, stop and report instead of guessing.

## Done criteria

- Container runtime user is non-root.
- Image still imports `api.main`.
- No repo files outside the Docker/startup surface changed.
