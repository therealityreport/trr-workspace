# Direct DB Lane for Local `make dev`

## Summary

Change TRR workspace startup so `make dev` is local-process-first: local TRR-APP, local TRR-Backend, direct DB lane, Modal disabled, and remote workers disabled. Move the current cloud/remote-worker behavior to explicit `make dev-cloud`, resolve the `pending_not_allowlisted` blocker one migration at a time, and keep the direct DB URI secret/local-only.

## Project Context

- Workspace: `/Users/thomashulihan/Projects/TRR`.
- Current `Makefile` still describes `make dev` as cloud-first and treats `make dev-cloud` as a deprecated alias.
- Current `scripts/dev-workspace.sh` defaults the job plane to `remote`, Modal to enabled, and remote executor to Modal unless the direct source branch overrides them later.
- Current `scripts/lib/runtime-db-env.sh` resolves direct candidates first but silently falls through to session-pooler values.
- Current local env inventory shows `TRR_DB_DIRECT_URL` absent and `TRR_DB_URL` present as a session-pooler value.
- Runtime reconcile currently blocks on `pending_not_allowlisted`.
- Direct local lane must use operator-provided `TRR_DB_DIRECT_URL` for project ref `vwxfvzutyufrkhfgoeaa`. The full URL/password must never be committed, logged, printed, or generated into docs.

## Assumptions

- The operator will provide `TRR_DB_DIRECT_URL` in the shell or an ignored local env file before running `make dev`.
- Direct DB means hosted Supabase direct Postgres host `db.vwxfvzutyufrkhfgoeaa.supabase.co:5432`, not local Docker Postgres.
- `make dev-cloud` owns cloud/remote behavior and keeps session/pooler DB behavior unless separately reviewed.
- `TRR_DB_URL` may be set to the direct URI only inside tightly scoped local TRR-APP/TRR-Backend child envs if legacy code still requires it.
- The implementation must preserve unrelated dirty worktree edits.

## Goals

- `make dev` starts local app/backend on the direct DB lane and disables Modal/remote workers by default.
- `make dev-cloud` starts the explicit cloud/remote worker mode and does not inherit local direct DB settings.
- Runtime reconcile validates direct DB identity before any migration apply or history repair.
- Each pending migration gets an individual live-state verdict and action record.
- Startup prints only sanitized lane/source/status fields:

```txt
Workspace mode: local
DB lane: direct
DB source: TRR_DB_DIRECT_URL
Remote workers: disabled
Modal dispatch: disabled
Runtime reconcile: ok
```

## Non-Goals

- Do not commit, print, or persist the direct DB URL in tracked files.
- Do not silently fall back to the session pooler when direct DB is unreachable.
- Do not pass direct DB settings to Modal, Render, Cloud Run, Vercel, or remote workers.
- Do not bulk-apply the five pending migrations as one blob.
- Do not weaken deployed/runtime tests that reject local-only direct DB behavior.

## Phased Implementation

### Phase 0 - Dirty Worktree and Contract Preflight

- Run `git status --short` and inspect diffs for startup/env surfaces before editing.
- Treat existing edits in `Makefile`, `scripts/dev-workspace.sh`, `scripts/lib/runtime-db-env.sh`, `scripts/preflight.sh`, docs, profiles, and tests as potentially user-owned until inspected.
- Confirm current branch. If not `main`, record it and continue only if the branch is intentionally active.
- Confirm no tracked file contains a full direct DB URL or password.
- Commit boundary: none; inspection only.

### Phase 1 - Split Local and Cloud Workspace Modes

- Update `Makefile`:
  - `make dev` runs `WORKSPACE_DEV_MODE=local` preflight and launches `scripts/dev-workspace.sh` with `WORKSPACE_DEV_MODE=local`.
  - `make dev-cloud` runs `WORKSPACE_DEV_MODE=cloud` preflight and launches `scripts/dev-workspace.sh` with `WORKSPACE_DEV_MODE=cloud`.
  - Keep deprecated aliases explicit: `dev-lite`, `dev-local`, and `dev-full` should say which supported target they forward to.
- Update `scripts/dev-workspace.sh`:
  - Replace "cloud-first" default wording with local-process-first wording.
  - Default local mode values:
    - `WORKSPACE_TRR_JOB_PLANE_MODE=local`
    - `WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=0`
    - `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=0`
    - `WORKSPACE_TRR_MODAL_ENABLED=0`
  - Cloud mode values may keep remote/Modal defaults.
- Update profiles:
  - `profiles/default.env` becomes local/direct compatible.
  - `profiles/local-cloud.env` is renamed or documented as cloud compatibility only if it remains.
  - `profiles/social-debug.env` must not re-enable Modal/remote workers unless it is explicitly a cloud profile.
- Commit boundary: launcher/profile mode split.

### Phase 2 - Direct Resolver and Secret-Safe Projection

- Update `scripts/lib/runtime-db-env.sh` with explicit local mode resolution:
  1. exported or env-file `TRR_DB_DIRECT_URL`;
  2. derived direct URI only when the source is a Supabase pooler URL for project ref `vwxfvzutyufrkhfgoeaa`;
  3. fail closed with instructions to set `TRR_DB_DIRECT_URL`;
  4. session fallback only when `WORKSPACE_TRR_DB_LANE=session` is explicitly set.
- Add helper behavior:
  - `trr_runtime_db_resolve_local_app_url "$ROOT" local` returns direct-only unless the explicit session escape hatch is set.
  - `trr_runtime_db_resolve_local_app_source` returns `TRR_DB_DIRECT_URL`, `derived:TRR_DB_DIRECT_URL`, or explicit session source labels without secrets.
  - A sanitizer renders only `host_class`, `project_ref`, `database`, and source label.
- In `scripts/dev-workspace.sh`, project the direct value only into local TRR-APP and TRR-Backend child envs:
  - pass `TRR_DB_DIRECT_URL`;
  - pass `TRR_DB_URL` as the direct URI only inside those child command env blocks if needed for compatibility;
  - do not export the direct URI globally for the parent launcher after resolution.
- Ensure remote worker launch blocks and Modal-related command construction receive blank/unset `TRR_DB_DIRECT_URL` in local mode.
- Commit boundary: resolver/projection.

### Phase 3 - Local/Cloud Preflight and Runtime Reconcile

- Update `scripts/preflight.sh` so `WORKSPACE_DEV_MODE=local` is valid and distinct from `cloud`.
- Local preflight behavior:
  - requires direct lane or explicit session escape hatch;
  - runs DB runtime reconcile;
  - does not auto-deploy Modal;
  - treats Render/Decodo as advisory or skips remote readiness if they are irrelevant to local mode;
  - emits sanitized one-line runtime reconcile summary.
- Cloud preflight behavior:
  - preserves session/pooler lane;
  - permits Modal/remote readiness checks;
  - must not inherit `TRR_DB_DIRECT_URL` from local ignored env files unless a future reviewed cloud direct-lane feature is added.
- Update `scripts/workspace_runtime_reconcile.py` and backend helpers only as needed to pass mode context safely.
- Commit boundary: preflight/reconcile mode split.

### Phase 4 - Direct DB Identity Gate

- Add a backend-owned identity helper in `TRR-Backend/scripts/dev/reconcile_runtime_db.py` or a small adjacent module.
- Before any migration apply or history repair, validate the selected DB:
  - host is `db.vwxfvzutyufrkhfgoeaa.supabase.co`;
  - project ref is `vwxfvzutyufrkhfgoeaa`;
  - database is `postgres`;
  - `select version()` succeeds;
  - `select current_database()` returns `postgres`;
  - `select current_user` succeeds.
- Return only sanitized identity fields in JSON.
- Fail closed on missing, unreachable, malformed, or wrong-project direct DB.
- Ensure `run_supabase_db_push` receives the resolved direct URL from the validated identity path, not raw env precedence.
- Commit boundary: identity gate and direct push plumbing.

### Phase 5 - Per-Migration Reconcile Decisions

- Create `docs/workspace/runtime-reconcile-migration-decisions-2026-04-28.md`.
- For each pending migration, run identity validation first, inspect live state, choose one action, execute only that action, then rerun reconcile before moving to the next.
- Required record for each migration:

```txt
migration file:
live-state verdict: not_applied / already_applied / partially_applied
action: apply / repair_history / skip_with_reason
rollback or forward-fix note:
owner evidence:
post-action reconcile result:
```

- Migration order:
  1. `20260427140000_quarantine_typography_runtime_ddl.sql`
  2. `20260428110000_security_hotfix_public_migrations_rpc_exec.sql`
  3. `20260428111000_advisor_rls_policy_cleanup.sql`
  4. `20260428112000_advisor_external_id_conflicts_primary_key.sql`
  5. `20260428113000_remove_flashback_gameplay_write_path.sql`
- Action rules:
  - `not_applied`: apply that migration only, then verify expected objects/policies.
  - `already_applied`: repair migration history only after proving live state matches the migration.
  - `partially_applied`: stop and write a forward-fix or rollback note before touching history.
  - `skip_with_reason`: allowed only when owner evidence says the migration must remain manual and startup should still block.
- Do not add manual migrations to the startup auto-apply allowlist unless the decision record explicitly approves startup auto-apply.
- Commit boundary: migration decision artifact plus any allowlist comment updates; live DB actions remain operator-controlled unless explicitly approved in the execution turn.

### Phase 6 - Tests, Docs, and Secret Scanning

- Update/add tests:
  - `scripts/test_runtime_db_env.py`: direct-first, derived-direct validation, fail-closed, explicit session escape hatch, sanitizer output.
  - `scripts/test_workspace_app_env_projection.py`: `make dev` local mode disables Modal/remote workers and does not pass direct env to remote worker blocks.
  - `TRR-Backend/tests/scripts/test_reconcile_runtime_db.py`: direct identity success/failure, sanitized JSON, one-migration-at-a-time behavior, direct URL passed to push.
  - `TRR-Backend/tests/db/test_connection_resolution.py` and `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`: deployed runtime still rejects `TRR_DB_DIRECT_URL`.
- Update generated docs and command docs without secrets:
  - `docs/workspace/dev-commands.md`
  - `docs/workspace/env-contract.md`
  - `docs/workspace/env-contract-inventory.md`
  - `docs/workspace/shared-env-manifest.json`
  - `docs/workspace/redacted-env-inventory.md`
- Add or run a no-secret check that fails if tracked files include `postgresql://postgres:` with the project host or any URL containing a password.
- Commit boundary: tests/docs.

## Architecture Impact

- Local development becomes local-process-first.
- Cloud/remote execution remains available but explicit through `make dev-cloud`.
- Runtime reconcile remains the startup gate, but direct DB identity becomes mandatory before DB mutation in local mode.
- Direct DB settings stay local-only and must not cross into remote execution surfaces.

## Data or API Impact

- No public API shape changes.
- Schema impact is limited to individually applying or repairing the five pending backend-owned migrations.
- Env contract changes redefine default local startup and clarify `TRR_DB_DIRECT_URL` precedence.

## Validation Plan

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 -m pytest scripts/test_runtime_db_env.py scripts/test_workspace_app_env_projection.py

cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/scripts/test_reconcile_runtime_db.py tests/db/test_connection_resolution.py tests/api/test_startup_validation.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run -c vitest.config.ts tests/postgres-connection-string-resolution.test.ts --reporter=dot

cd /Users/thomashulihan/Projects/TRR
make preflight
make dev
make dev-cloud
```

Expected:

- `make preflight` exits 0 in the default local mode.
- `make dev` reaches workspace launch.
- `make dev` banner shows local/direct/disabled remote surfaces.
- `make dev-cloud` keeps cloud/remote behavior explicit and uses session/pooler DB lane.
- No full DB URL appears in logs, docs, test output, generated artifacts, or tracked files.

## Acceptance Criteria

- `make dev` uses `TRR_DB_DIRECT_URL` for local TRR-APP and TRR-Backend.
- `make dev` does not enable Modal or remote workers by default.
- `make dev-cloud` owns cloud/remote behavior.
- Direct DB identity is validated before migration apply/repair.
- Each pending migration has a separate verdict/action record.
- Deployed/runtime tests still reject local-only direct DB behavior.
- No secrets are committed or logged.

## Risks and Stop Rules

- Stop if the direct DB host is unreachable or does not match `vwxfvzutyufrkhfgoeaa`.
- Stop if any migration is partially applied.
- Stop if a direct URL appears in tracked docs, logs, or test output.
- Stop if cloud mode inherits `TRR_DB_DIRECT_URL`.
- Stop if dirty worktree diffs overlap with unrelated user changes that cannot be preserved cleanly.

## Follow-Up Improvements

- Add a `make status` field for sanitized `workspace_mode`, `db_lane`, and `db_source`.
- Add a dedicated `make runtime-db-identity` diagnostic that prints only sanitized identity fields.
- Add a future reviewed path for direct-lane cloud testing if ever needed.

## Recommended Next Step After Approval

Use inline/sequential execution. The work is tightly ordered around launcher mode, resolver behavior, identity validation, and per-migration decisions.

Commit message:

```txt
chore: use direct db lane for local make dev
```

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

## Ready For Execution

Yes, after the user approves this revised plan.
