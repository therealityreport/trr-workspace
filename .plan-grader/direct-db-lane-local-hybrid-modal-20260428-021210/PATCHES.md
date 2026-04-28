# Patches

## Source

Prior revised plan:

`/Users/thomashulihan/Projects/TRR/.plan-grader/direct-db-lane-local-make-dev-20260428-020627/REVISED_PLAN.md`

## Material Changes

### 1. Added `make dev-hybrid`

The prior plan had only local and cloud modes. The revised plan adds:

```txt
make dev-hybrid
  local app/backend DB lane: direct
  remote worker DB lane: session/pooler
  Modal dispatch: enabled
```

### 2. Split local and remote DB resolvers

The prior plan had one local resolver. The revised plan requires process-specific resolvers:

- local app/backend resolver;
- remote worker resolver;
- shared sanitizer.

### 3. Added remote session lane fail-closed behavior

Hybrid mode must fail if the remote lane would resolve to direct or if only `TRR_DB_DIRECT_URL` is available for remote workers.

### 4. Updated preflight requirements

`scripts/preflight.sh` must accept `local|cloud|hybrid`, and hybrid preflight must validate both local direct identity and remote session availability.

### 5. Updated test matrix

Added tests proving:

- `make dev-hybrid` enables Modal/remote workers;
- hybrid remote blocks do not receive direct env;
- `make dev-cloud` ignores local direct env;
- remote worker resolver fails closed on direct-only config.

### 6. Updated validation commands

Added `make dev-hybrid` to final validation.
