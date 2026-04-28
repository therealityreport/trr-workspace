# Patches

## Patch Summary

The source plan was good but needed execution-hardening. The revised plan changes are conceptual patches rather than source-code diffs because the input was pasted plan text.

## Required Plan Changes

### 1. Add dirty-worktree gate

Inserted `Phase 0 - Dirty Worktree and Contract Preflight`.

Reason: current repo already has many modified/untracked files in startup/env surfaces. Execution must inspect and preserve unrelated edits before patching.

### 2. Define exact local/cloud modes

Expanded launcher work to require:

- `make dev` -> `WORKSPACE_DEV_MODE=local`
- `make dev-cloud` -> `WORKSPACE_DEV_MODE=cloud`
- local defaults for job plane, Modal, and remote workers

Reason: the source plan said "preferably make dev-cloud" but left exact mode behavior to the executor.

### 3. Split local and cloud preflight

Added `Phase 3 - Local/Cloud Preflight and Runtime Reconcile`.

Reason: current `make dev` calls `make preflight`, and `make preflight` hardcodes cloud mode. Without this patch, the launcher could be local while preflight remains cloud-shaped.

### 4. Make direct resolver implementation concrete

Added expected helper behavior for:

- direct-only local resolution;
- `derived:TRR_DB_DIRECT_URL` source labels;
- explicit `WORKSPACE_TRR_DB_LANE=session` escape hatch;
- sanitizer output.

Reason: source plan described resolver order but did not specify where labels, derivation, and fail-closed behavior live.

### 5. Add durable migration decision artifact

Added required output:

`docs/workspace/runtime-reconcile-migration-decisions-2026-04-28.md`

Reason: source plan required per-migration records but did not name where they are recorded.

### 6. Add secret-safety validation

Added no-secret scan and explicit expectations for logs, docs, generated artifacts, and tracked files.

Reason: source plan prohibited secret leakage but did not require proof.

### 7. Change execution handoff

Changed recommended execution from `orchestrate-plan-execution` to inline/sequential execution.

Reason: the work is tightly ordered and mostly touches coupled launcher/reconcile surfaces. Parallel subagents would increase conflict risk in an already-dirty worktree.
