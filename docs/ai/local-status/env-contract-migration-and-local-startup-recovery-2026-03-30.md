# Env contract migration and local startup recovery

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-30
  current_phase: "complete"
  next_action: "Use docs/workspace/vercel-env-review.md as the reviewed live-env source of truth; survey cutover may resume from the Vercel env-governance standpoint because no unknown-blocking entries remain."
  detail: self
```

## Summary

- Restored the `make dev` baseline by making the workspace launcher export `TRR_LOCAL_DEV=1` and by forcing launcher-owned local service URLs for managed child processes.
- Re-locked runtime env ownership across `TRR-Backend`, `screenalytics`, and `TRR-APP` around canonical names:
  - runtime DB: `TRR_DB_URL`, optional `TRR_DB_FALLBACK_URL`
  - backend base: `TRR_API_URL`
  - app server/admin Supabase: `TRR_CORE_SUPABASE_*`
  - browser Supabase: `NEXT_PUBLIC_SUPABASE_*`
- Added focused regression coverage for backend and screenalytics startup classification so deployed-only secrets are still enforced outside local workspace runs.
- Added `scripts/env_contract_report.py` plus generated `docs/workspace/env-contract-inventory.md`, `docs/workspace/env-deprecations.md`, and `docs/workspace/vercel-env-review.md`, and wired that validation into `scripts/preflight.sh`.
- Updated cross-repo task records:
  - `TRR-Backend/docs/cross-collab/TASK19/*`
  - `screenalytics/docs/cross-collab/TASK11/*`
  - `TRR-APP/docs/cross-collab/TASK18/*`

## Live Runtime Inventory Outcome

- Render:
  - Captured backend env inventory and confirmed canonical `TRR_DB_URL` / `TRR_API_URL` usage on the live API service.
- Modal:
  - Captured secret-name inventory only (`trr-backend-runtime`, `trr-social-auth`).
  - Did not mutate secret payloads because this session did not have rollback-safe value snapshots.
- Vercel:
  - Confirmed the active app project is root `TRR-APP/.vercel/project.json` (`trr-app`), not the nested `apps/web/.vercel/project.json` surface.
  - Confirmed preview and production both expose canonical app vars such as `TRR_API_URL`, `TRR_DB_URL`, `NEXT_PUBLIC_SUPABASE_*`, and `TRR_CORE_SUPABASE_*`.
  - Completed the explicit review pass for the active `trr-app` surface:
    - `DATABASE_URL`, production `POSTGRES_*`, production `SUPABASE_*`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, and pull-only platform/build vars are documented as retained.
    - `FIREBASE_SERVICE_ACCOUNT` is documented as a canonical app-owned secret, not deprecated-runtime drift.
  - `docs/workspace/vercel-env-review.md` is now the reviewed source of truth for this live env surface and leaves no `unknown-blocking` entries behind.

## Rollback Note

- During validation, preview `TRR_API_URL` on the root `trr-app` project was mistakenly removed while testing Vercel CLI behavior.
- It was restored immediately through the interactive `vercel env add TRR_API_URL preview` flow with the original value and an empty Git-branch selection for all preview branches.
- Post-restore verification confirmed preview `TRR_API_URL` is present again and the live app still returns `200`.

## Validation

- Backend:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/test_startup_config.py tests/db/test_connection_resolution.py tests/scripts/test_prepare_named_secrets.py`
- screenalytics:
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && pytest -q tests/unit/test_startup_config.py tests/unit/test_supabase_db.py`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && python scripts/check_env_example.py --file .env.example --required TRR_DB_URL GEMINI_MODEL --allow-hyphen GEMINI-MODEL`
- TRR-APP:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest run tests/backend-base.test.ts tests/trr-api-backend-base.test.ts tests/postgres-connection-string-resolution.test.ts tests/supabase-client.test.ts tests/supabase-client-env.test.ts`
- Workspace:
  - `cd /Users/thomashulihan/Projects/TRR && ./scripts/preflight.sh`
  - `cd /Users/thomashulihan/Projects/TRR && make dev`
  - `curl -fsS http://127.0.0.1:8000/health`
  - `curl -I -fsS http://127.0.0.1:3000/`
- Handoff closeout:
  - `cd /Users/thomashulihan/Projects/TRR && ./scripts/handoff-lifecycle.sh post-phase`
  - `cd /Users/thomashulihan/Projects/TRR && ./scripts/handoff-lifecycle.sh closeout`

## Result

- Local workspace startup is healthy again and no longer depends on deployed-only secret material.
- Managed local app/backend routing now prefers launcher-owned loopback URLs over stale inherited shell values.
- Repo-level env contracts and validator/reporting now reflect the canonical ownership model.
- Live env cleanup and review were performed safely: inventory first, no blind deletions, immediate rollback on the one mistaken preview removal, and explicit retained classifications for the reviewed Vercel env surface.
- Survey cutover is no longer blocked by the Vercel env review surface because the retained live vars are now documented explicitly.
