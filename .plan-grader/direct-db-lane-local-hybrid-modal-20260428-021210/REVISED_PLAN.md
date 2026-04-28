# Direct DB Lane for Local `make dev` with Optional Modal Hybrid

## Summary

Change TRR workspace startup so default `make dev` is local-process-first: local TRR-APP, local TRR-Backend, direct DB lane, Modal disabled, and remote workers disabled. Add explicit modes for cloud and hybrid workflows:

```txt
make dev
  workspace mode: local
  local app/backend DB lane: direct
  remote workers: disabled
  Modal dispatch: disabled

make dev-cloud
  workspace mode: cloud
  local app/backend DB lane: session/pooler
  remote workers: enabled as configured
  Modal dispatch: enabled as configured

make dev-hybrid
  workspace mode: hybrid
  local app/backend DB lane: direct
  remote worker DB lane: session/pooler
  remote workers: enabled as configured
  Modal dispatch: enabled as configured
```

Resolve the current `pending_not_allowlisted` blocker one migration at a time. Keep the direct DB URI secret/local-only and never pass it to Modal, Render, Cloud Run, Vercel, or remote worker processes.

## Project Context

- Workspace: `/Users/thomashulihan/Projects/TRR`.
- Current `Makefile` still describes `make dev` as cloud-first and treats `make dev-cloud` as a deprecated alias.
- Current `scripts/dev-workspace.sh` has separate local app/backend child env blocks and a remote worker launch block, so process-specific DB projection is feasible.
- Current `scripts/lib/runtime-db-env.sh` resolves direct candidates first but silently falls through to session-pooler values.
- Current local env inventory shows `TRR_DB_DIRECT_URL` absent and `TRR_DB_URL` present as a session-pooler value.
- Runtime reconcile currently blocks on `pending_not_allowlisted`.
- Direct local lane must use operator-provided `TRR_DB_DIRECT_URL` for project ref `vwxfvzutyufrkhfgoeaa`. The full URL/password must never be committed, logged, printed, or generated into docs.

## Assumptions

- The operator will provide `TRR_DB_DIRECT_URL` in the shell or an ignored local env file before running `make dev` or `make dev-hybrid`.
- Direct DB means hosted Supabase direct Postgres host `db.vwxfvzutyufrkhfgoeaa.supabase.co:5432`, not local Docker Postgres.
- Modal workers and any remote workers must use the existing reviewed session/pooler DB secret or session/pooler env, never the direct URI.
- `TRR_DB_URL` may be set to the direct URI only inside tightly scoped local TRR-APP/TRR-Backend child env blocks in local/hybrid mode if legacy code still requires it.
- The implementation must preserve unrelated dirty worktree edits.

## Goals

- `make dev` starts local app/backend on the direct DB lane and disables Modal/remote workers by default.
- `make dev-cloud` preserves explicit cloud/remote worker behavior and does not inherit local direct DB settings.
- `make dev-hybrid` supports local direct app/backend plus Modal/remote workers on session/pooler DB only.
- Runtime reconcile validates direct DB identity before any migration apply or history repair.
- Each pending migration gets an individual live-state verdict and action record.
- Startup prints sanitized lane/source/status fields with local and remote DB lanes separated.

## Non-Goals

- Do not commit, print, or persist the direct DB URL in tracked files.
- Do not silently fall back to the session pooler when direct DB is unreachable in local or hybrid local-app lanes.
- Do not pass direct DB settings to Modal, Render, Cloud Run, Vercel, or remote workers.
- Do not make hybrid mode the default.
- Do not bulk-apply the five pending migrations as one blob.
- Do not weaken deployed/runtime tests that reject local-only direct DB behavior.

## Phased Implementation

### Phase 0 - Dirty Worktree and Contract Preflight

- Run `git status --short` and inspect diffs for startup/env surfaces before editing.
- Treat existing edits in `Makefile`, `scripts/dev-workspace.sh`, `scripts/lib/runtime-db-env.sh`, `scripts/preflight.sh`, docs, profiles, and tests as potentially user-owned until inspected.
- Confirm current branch. If not `main`, record it and continue only if the branch is intentionally active.
- Confirm no tracked file contains a full direct DB URL or password.
- Commit boundary: none; inspection only.

### Phase 1 - Define Three Workspace Modes

- Update `Makefile`:
  - `make dev` runs `WORKSPACE_DEV_MODE=local` preflight and launches `scripts/dev-workspace.sh` with `WORKSPACE_DEV_MODE=local`.
  - `make dev-cloud` runs `WORKSPACE_DEV_MODE=cloud` preflight and launches `scripts/dev-workspace.sh` with `WORKSPACE_DEV_MODE=cloud`.
  - Add `make dev-hybrid` running `WORKSPACE_DEV_MODE=hybrid` preflight and launch.
  - Keep deprecated aliases explicit: `dev-lite`, `dev-local`, and `dev-full` should say which supported target they forward to.
- Update `scripts/dev-workspace.sh`:
  - Replace "cloud-first" default wording with local-process-first wording.
  - Local mode defaults:
    - `WORKSPACE_TRR_JOB_PLANE_MODE=local`
    - `WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=0`
    - `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=0`
    - `WORKSPACE_TRR_MODAL_ENABLED=0`
  - Cloud mode defaults:
    - preserve existing session/pooler and remote/Modal behavior.
  - Hybrid mode defaults:
    - local app/backend use direct lane;
    - `WORKSPACE_TRR_JOB_PLANE_MODE=remote`;
    - `WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1`;
    - `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=1`;
    - `WORKSPACE_TRR_MODAL_ENABLED=1`;
    - remote DB lane must be session/pooler.
- Update profiles:
  - `profiles/default.env` becomes local/direct compatible.
  - `profiles/local-cloud.env` is documented as cloud compatibility only if it remains.
  - Add or document a hybrid profile only if defaults cannot be expressed cleanly in the launcher.
  - `profiles/social-debug.env` must state whether it is local, cloud, or hybrid and must not accidentally re-enable Modal under default local `make dev`.
- Commit boundary: launcher/profile mode split.

### Phase 2 - Split Local and Remote DB Lane Resolution

- Update `scripts/lib/runtime-db-env.sh` with process-specific resolution helpers:
  - local app/backend lane resolver for `local` and `hybrid`;
  - remote worker lane resolver for `cloud` and `hybrid`;
  - shared sanitizer for source/lane labels.
- Local app/backend resolver order for `local` and `hybrid`:
  1. exported or env-file `TRR_DB_DIRECT_URL`;
  2. derived direct URI only when the source is a Supabase pooler URL for project ref `vwxfvzutyufrkhfgoeaa`;
  3. fail closed with instructions to set `TRR_DB_DIRECT_URL`;
  4. session fallback only when `WORKSPACE_TRR_DB_LANE=session` is explicitly set.
- Remote worker resolver order for `cloud` and `hybrid`:
  1. explicit `TRR_DB_SESSION_URL`;
  2. session/pooler `TRR_DB_URL`;
  3. `TRR_DB_FALLBACK_URL` only if it is session/local and explicitly allowed by existing runtime contract;
  4. fail closed if only `TRR_DB_DIRECT_URL` is available.
- Source labels must be secret-free:
  - `TRR_DB_DIRECT_URL`
  - `derived:TRR_DB_DIRECT_URL`
  - `TRR_DB_SESSION_URL`
  - `TRR_DB_URL`
  - `explicit-session-escape-hatch`
- Commit boundary: resolver and sanitizer helpers.

### Phase 3 - Secret-Safe Env Projection

- In `scripts/dev-workspace.sh`, project direct values only into local TRR-APP and TRR-Backend child command envs in `local` and `hybrid` modes:
  - pass `TRR_DB_DIRECT_URL`;
  - pass `TRR_DB_URL` as the direct URI only inside those child env blocks if needed for compatibility;
  - do not export the direct URI globally in a way remote blocks can inherit it.
- In cloud mode:
  - do not read ignored local `TRR_DB_DIRECT_URL`;
  - fail or unset direct env before launching remote/Modal paths.
- In hybrid mode:
  - local app/backend child blocks receive direct lane;
  - remote worker launch blocks receive only session/pooler lane values;
  - Modal-related reconcile/deploy/secret surfaces never receive `TRR_DB_DIRECT_URL`.
- Add a single sanitized startup summary that separates lanes:

```txt
Workspace mode: hybrid
Local DB lane: direct
Local DB source: TRR_DB_DIRECT_URL
Remote DB lane: session
Remote DB source: TRR_DB_SESSION_URL
Remote workers: enabled
Modal dispatch: enabled
Runtime reconcile: ok
```

- Commit boundary: launcher env projection and banner.

### Phase 4 - Local, Cloud, and Hybrid Preflight

- Update `scripts/preflight.sh` so `WORKSPACE_DEV_MODE=local|cloud|hybrid` is valid.
- Local preflight:
  - requires direct lane or explicit session escape hatch;
  - runs DB runtime reconcile;
  - does not auto-deploy Modal;
  - treats Render/Decodo as advisory or skips remote readiness if irrelevant;
  - emits sanitized one-line runtime reconcile summary.
- Cloud preflight:
  - preserves session/pooler lane;
  - permits Modal/remote readiness checks;
  - must not inherit `TRR_DB_DIRECT_URL`.
- Hybrid preflight:
  - validates local direct DB identity for app/backend;
  - validates remote session/pooler DB source exists for workers;
  - permits Modal/remote readiness checks;
  - fails closed if the remote lane would resolve to direct.
- Update `scripts/workspace_runtime_reconcile.py` and backend helpers only as needed to pass mode and lane context safely.
- Commit boundary: preflight/reconcile mode split.

### Phase 5 - Direct DB Identity Gate

- Add a backend-owned identity helper in `TRR-Backend/scripts/dev/reconcile_runtime_db.py` or a small adjacent module.
- Before any migration apply or history repair, validate the selected direct DB:
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

### Phase 6 - Per-Migration Reconcile Decisions

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

### Phase 7 - Tests, Docs, and Secret Scanning

- Update/add tests:
  - `scripts/test_runtime_db_env.py`: direct-first, derived-direct validation, fail-closed, explicit session escape hatch, remote session resolver, sanitizer output.
  - `scripts/test_workspace_app_env_projection.py`: `make dev` local disables Modal/remote workers; `make dev-hybrid` enables Modal/remote workers while keeping direct env out of remote blocks; `make dev-cloud` ignores local direct env.
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

- Local development becomes local-process-first by default.
- Cloud/remote execution remains available through `make dev-cloud`.
- Hybrid execution is explicit through `make dev-hybrid`, with separate local and remote DB lanes.
- Runtime reconcile remains the startup gate, but direct DB identity becomes mandatory before DB mutation in local/hybrid local-app lanes.
- Direct DB settings stay local-only and must not cross into remote execution surfaces.

## Data or API Impact

- No public API shape changes.
- Schema impact is limited to individually applying or repairing the five pending backend-owned migrations.
- Env contract changes redefine startup modes and clarify local/remote DB lane precedence.

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
make dev-hybrid
```

Expected:

- `make preflight` exits 0 in default local mode.
- `make dev` reaches workspace launch with local/direct and remote disabled.
- `make dev-cloud` uses session/pooler and keeps cloud/remote behavior explicit.
- `make dev-hybrid` reaches workspace launch with local direct lane and remote session lane.
- No full DB URL appears in logs, docs, test output, generated artifacts, or tracked files.

## Acceptance Criteria

- `make dev` uses `TRR_DB_DIRECT_URL` for local TRR-APP and TRR-Backend.
- `make dev` does not enable Modal or remote workers by default.
- `make dev-cloud` owns cloud/remote behavior and does not inherit direct DB.
- `make dev-hybrid` supports Modal/remote workers while proving they use session/pooler DB only.
- Direct DB identity is validated before migration apply/repair.
- Each pending migration has a separate verdict/action record.
- Deployed/runtime tests still reject local-only direct DB behavior.
- No secrets are committed or logged.

## Risks and Stop Rules

- Stop if the direct DB host is unreachable or does not match `vwxfvzutyufrkhfgoeaa`.
- Stop if hybrid remote lane resolves to direct.
- Stop if any migration is partially applied.
- Stop if a direct URL appears in tracked docs, logs, or test output.
- Stop if cloud mode inherits `TRR_DB_DIRECT_URL`.
- Stop if dirty worktree diffs overlap with unrelated user changes that cannot be preserved cleanly.

## Follow-Up Improvements

- Add a `make status` field for sanitized `workspace_mode`, `local_db_lane`, `remote_db_lane`, and source labels.
- Add a dedicated `make runtime-db-identity` diagnostic that prints only sanitized identity fields.
- Add a future reviewed path for direct-lane cloud testing if ever needed.

## Recommended Next Step After Approval

Use inline/sequential execution. The work is tightly ordered around launcher modes, resolver behavior, env projection, identity validation, and per-migration decisions.

Commit message:

```txt
chore: use direct db lane for local make dev
```

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

## Ready For Execution

Yes, after the user approves this revised plan.
