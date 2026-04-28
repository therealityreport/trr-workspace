# Plan Grader Audit - Direct DB Lane for Local `make dev`

## Verdict

Revise before execution.

The pasted plan is directionally strong and solves the right startup problem, but it still leaves several implementation decisions to the executor: exact mode/env names, where the direct identity check lives, how `make preflight` distinguishes local vs cloud, how migration verdict records are persisted, and how to prove secrets are not leaked. The revised plan in this artifact makes those choices explicit.

## Original Score

82 / 100

## Revised Score Estimate

92 / 100

## Current-State Fit

Evidence from the repo confirms the plan is aimed at real drift:

- `Makefile` still says `make dev` is the canonical cloud-first profile and `dev-cloud` is a deprecated alias.
- `scripts/dev-workspace.sh` still describes the default workspace as cloud-first and defaults `WORKSPACE_TRR_JOB_PLANE_MODE` to `remote` and `WORKSPACE_TRR_MODAL_ENABLED` to `1`.
- `scripts/lib/runtime-db-env.sh` currently falls through from direct URL candidates to session-pooler values and still reports the missing config as a "canonical session DB URL".
- `TRR-Backend/scripts/dev/reconcile_runtime_db.py` currently can derive a direct URL for reads but still passes env precedence directly into `supabase db push`.
- `TRR-Backend/scripts/dev/runtime_reconcile_migration_allowlist.txt` marks four pending migrations as manual and does not list `20260428113000`.

## Blocking Issues

1. **Mode contract is underspecified.** The source plan says `make dev-cloud` should own cloud behavior but does not specify the exact `WORKSPACE_DEV_MODE` values, `Makefile` target behavior, or compatibility alias behavior.

2. **Preflight/local split is incomplete.** `make dev` currently calls `make preflight`, which hardcodes `WORKSPACE_DEV_MODE=cloud`. The source plan does not require a local preflight mode or define whether Modal/Render/Decodo checks are skipped, advisory, or cloud-only under local direct mode.

3. **Migration records need a durable artifact.** The source requires per-migration verdicts but does not name the file, schema, or required redaction rules for those records.

4. **Direct derivation needs a no-secret implementation boundary.** The source allows deriving direct URI from a pooler URL, but it does not require a shared sanitizer/helper or tests for password-bearing derived URLs.

5. **Remote inheritance proof needs concrete surfaces.** The plan asks to prove remote workers do not inherit direct DB settings, but it does not name the exact remote worker launch block, Modal reconcile/secrets surfaces, or pid/status artifact to check.

6. **Dirty worktree risk is high.** The repo already contains many modified and untracked files in the same startup/env surfaces. The plan needs an explicit "read diffs first and preserve unrelated edits" task before implementation.

## Approval Decision

Do not execute the pasted source plan as-is. Execute the revised plan in `REVISED_PLAN.md` after approval.

## Top Fixes in the Revision

- Defines `WORKSPACE_DEV_MODE=local` for `make dev` and `WORKSPACE_DEV_MODE=cloud` for `make dev-cloud`.
- Adds explicit local/cloud preflight behavior.
- Adds concrete helper names for direct resolution, direct identity validation, sanitization, and migration verdict recording.
- Requires a durable migration verdict artifact at `docs/workspace/runtime-reconcile-migration-decisions-2026-04-28.md`.
- Adds tests for no secret leakage, no remote inheritance, and deployed-runtime direct-lane rejection.
- Adds a dirty-worktree preservation gate before edits.
