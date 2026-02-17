# Local Worktree Reconciliation (Post-Merge)

Date: February 17, 2026
Policy: non-destructive reconciliation only (no force-reset)

## Current Local State

- `TRR-Backend`: clean on branch `codex/plan-remediation-backend`
- `screenalytics`: 172 local changes on branch `codex/plan-remediation-screenalytics`
- `TRR-APP`: 24 local changes on branch `codex/auth-cutover-phase9`

## Safe Reconciliation Procedure

1. Snapshot local branch pointers:
- `git rev-parse --abbrev-ref HEAD`
- `git rev-parse HEAD`

2. Save a local patch backup before any cleanup:
- `git diff > /tmp/<repo>-post-remediation.patch`
- `git diff --staged > /tmp/<repo>-post-remediation-staged.patch`

3. Create a safety branch for uncommitted work:
- `git switch -c codex/local-wip-<date>`

4. Stage by intent and commit in logical slices (do not squash unrelated work).

5. Rebase safety branch onto `origin/main` and resolve conflicts deliberately.

6. Only after successful validation, decide whether to keep or archive residual WIP branches.

## Deferred by Design

`make bootstrap` / `make dev` full local rerun is left to operator timing (user requested manual rerun after this closeout).
