# Plan 022: Add uv caching and remove duplicate backend CI install work

> **Executor instructions**: Keep gate behavior unchanged unless explicitly
> called out. This plan optimizes CI time; it must not hide failures.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- .github/workflows/ci.yml`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx/perf
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

Backend CI installs the same locked dependencies in several jobs without a cache.
The Python 3.12 canary also reruns `tests/api`, duplicating the main blocking
test lane while remaining non-blocking.

## Current state

- `.github/workflows/ci.yml:39` uses `astral-sh/setup-uv@v4` without cache
  configuration.
- `.github/workflows/ci.yml:50` syncs base deps for the main test job.
- `.github/workflows/ci.yml:82` and `:87` repeat setup/sync for the Python 3.12
  canary.
- `.github/workflows/ci.yml:213` defines non-blocking full pytest and repeats
  setup/sync again.

## Scope

**In scope**:
- `TRR-Backend/.github/workflows/ci.yml`

**Out of scope**:
- Changing which jobs are blocking.
- Removing the full-suite non-blocking lane.

## Steps

1. Add uv cache configuration using the lockfiles as cache dependency paths.
2. Keep the main Python 3.11 API test gate blocking.
3. Adjust the Python 3.12 canary only if there is a smaller smoke subset already
   available; otherwise leave the duplicate test command and document why.
4. Use YAML comments sparingly for non-obvious cache choices.

## Commands

Run from `TRR-Backend/`:

```bash
python - <<'PY'
import yaml
yaml.safe_load(open('.github/workflows/ci.yml'))
PY
```

If PyYAML is unavailable, use the existing repo YAML validation command if one
exists; otherwise report that YAML parsing was not run.

## Done criteria

- CI uses uv caching keyed by requirements lockfiles.
- Blocking/non-blocking job semantics are unchanged.
- Workflow YAML parses.
