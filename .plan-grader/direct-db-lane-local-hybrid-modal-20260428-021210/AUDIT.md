# Revise Plan Audit - Direct DB Lane with Optional Modal Hybrid

## Verdict

Approved after revision.

The prior revised plan was safe but too restrictive: it treated direct local DB and Modal workers as mutually exclusive for all practical startup modes. That is not necessary. The corrected contract should keep `make dev` local/direct and remote-off by default, but add an explicit hybrid mode where local TRR-APP/TRR-Backend use `TRR_DB_DIRECT_URL` and Modal/remote workers remain enabled on session/pooler DB secrets only.

## Original Score

92 / 100

## Revised Score Estimate

94 / 100

## Current-State Fit

The current repo still has the same relevant surfaces:

- `Makefile` currently treats `make dev-cloud` as a deprecated alias for `make dev`, so adding a real explicit mode target is required.
- `scripts/dev-workspace.sh` already has separate local app/backend child env blocks and a remote worker block, so the plan can require separate DB projection per process type.
- `scripts/lib/runtime-db-env.sh` already centralizes local DB resolution, so the plan can add explicit source/lane helpers there instead of scattering parsing.
- `TRR-Backend/scripts/dev/reconcile_runtime_db.py` owns the startup DB reconcile gate and is the correct place for direct DB identity validation.

## Main Revision

The revised plan adds a supported third mode:

```txt
make dev-hybrid
  local app/backend DB: direct
  remote worker DB: session/pooler
  Modal dispatch: enabled
  TRR_DB_DIRECT_URL: local app/backend only
```

This keeps the default safe while preserving the workflow option the user asked about.

## Approval Decision

Use the new `REVISED_PLAN.md` as the execution source. The plan is ready for sequential implementation after approval.

## Required Safety Invariant

No remote process may receive `TRR_DB_DIRECT_URL`, derived direct URLs, or a direct URI projected through `TRR_DB_URL`. Hybrid mode must prove local and remote DB lanes are separate.
