# Admin Rollout Closeout — 2026-04-07

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: archived
  last_updated: 2026-04-07
  current_phase: "closeout complete"
  next_action: "none — all items landed"
  detail: self
```

## Completed

- Confirmed the canonical admin show route remains `/${showSlug}/...`.
  - `/admin/[showId]` and `/admin/[showId]/[...rest]` stay as alias redirects only.
- Finished the TRR-APP person-page decomposition.
  - Extracted profile load/controller and settings controller ownership into `apps/web/src/lib/admin/person-page/`.
  - Removed duplicate settings-tab fetch ownership from `PersonPageClient.tsx`.
- Closed the dependency hygiene pass in `TRR-APP`.
  - Root `firebase-tools` bumped to `15.13.0`.
  - Added `pnpm.overrides` so the lockfile and installed tree no longer use:
    - `glob@10.5.0`
    - `json-ptr@3.1.1`
    - `node-domexception@1.0.0`
  - Replacement resolved versions:
    - `glob@10.4.5`
    - `json-ptr@3.1.0`
    - `node-domexception@2.0.2`
- Added a focused shared env manifest at `docs/workspace/shared-env-manifest.json`.
  - Canonical keys:
    - `TRR_API_URL`
    - `TRR_DB_URL`
    - `TRR_DB_FALLBACK_URL`
    - `TRR_INTERNAL_ADMIN_SHARED_SECRET`
  - Transitional keys:
    - `SCREENALYTICS_SERVICE_TOKEN`
    - `SCREENALYTICS_API_URL`
- Wired repo-level validation to that manifest:
  - `TRR-Backend/tests/test_startup_config.py`
  - `screenalytics/tests/unit/test_startup_config.py`
  - `TRR-APP/apps/web/tests/shared-env-contract.test.ts`
- Added backend Stage 6 backfill tooling:
  - `TRR-Backend/scripts/backfill/backfill_screenalytics_stage6.py`
  - Supports `--run-id`, `--show-id`, `--all-pending`, `--limit`, `--apply`, `--verbose`
  - Uses the same Stage 6 bundle validation rule as the pipeline stage.

## Validation

- Targeted backend validation passed:
  - `pytest -q tests/test_startup_config.py tests/pipeline/test_stages.py tests/scripts/test_backfill_screenalytics_stage6.py`
  - targeted `ruff check` / `ruff format --check` on touched backend files
- Targeted screenalytics validation passed:
  - `pytest -q tests/unit/test_startup_config.py`
- Targeted TRR-APP validation passed:
  - `pnpm -C apps/web exec tsc --noEmit`
  - targeted `eslint` on the person-page files
  - `pnpm -C apps/web exec vitest run tests/shared-env-contract.test.ts tests/people-page-tabs-runtime.test.tsx --pool=forks --poolOptions.forks.singleFork`
- Full repo checks:
  - `screenalytics`: full `pytest -q` passed
  - `TRR-Backend`: full `ruff check .` is still blocked by pre-existing unrelated repo violations outside this rollout
  - `TRR-APP`: `lint` and `next build --webpack` completed, but full `test:ci` surfaced unrelated failing suites outside this rollout

## Known Residuals

- `TRR-APP/apps/web/tests/person-page-settings-controller.test.tsx` still hangs in isolation under Vitest even though the runtime page suite passes.
- Full `TRR-APP test:ci` currently has unrelated failures outside the touched route/person/env files.
- Full `TRR-Backend ruff check .` still fails on unrelated baseline issues outside the touched Stage 6/env files.
