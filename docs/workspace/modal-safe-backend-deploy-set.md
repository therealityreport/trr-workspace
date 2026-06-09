# Modal-Safe Backend Deploy Set

Status: index/current pointer. Do not deploy from the current shared checkout.

The current workspace is dirty with unrelated changes. Modal deployment must use
the active deploy-slice handoff below or a clean tree containing only that
slice's approved files.

## Current Active Slice

- Active slice: [Backend model and Modal lock runtime slice](../../modal-deploy-slices/backend-model-lock-runtime.md)
- Patch generator: `scripts/modal-deploy-patch.sh`
- Dirty-checkout blocker: this shared checkout contains unrelated dirty files,
  so direct Modal deploys from here risk shipping work outside the approved
  slice.
- SQL status: no SQL changes, no direct-SQL changes, and no Supabase migration
  changes are part of the active Modal deploy slice.

## Safe Workflow

List the approved files and current dirty-file status:

```bash
scripts/modal-deploy-patch.sh --list
```

Create a patch containing only the approved active slice:

```bash
scripts/modal-deploy-patch.sh --patch /tmp/trr-modal-backend-model-lock-runtime.patch
```

Apply that patch in a clean checkout or clean deploy tree, then follow the
deploy, readiness, and rollback steps in the active slice doc.
