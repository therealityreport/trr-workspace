# Backend Pool Saturation Plan Patches

## Patch 1: Replace Reject-Only Gate With Queue Semantics

Original plan:

```text
try_start_named_background_task(...) returns started=false when the group is busy.
Catalog finalizer logs "finalizer deferred" and does not run target.
```

Revised plan:

```text
submit_named_background_task(...) accepts bounded queued work, de-duplicates active/queued keys, and runs accepted tasks eventually. Queue-full remains possible, but the catalog run stays pending/recoverable and the condition is explicitly logged.
```

Reason: a reserved catalog run must not be silently stranded because one local control-plane worker is already busy.

## Patch 2: Split Runtime Snapshot From Liveness

Original plan:

```text
Add background_tasks directly to /health/live.
```

Revised plan:

```text
Make /health/live async and DB-free first. Add /health/runtime for queue diagnostics.
```

Reason: the watchdog-facing liveness contract should stay minimal; operator diagnostics can use a separate DB-free endpoint.

## Patch 3: Add Finalizer Completion Acceptance

Original plan:

```text
Manual check: /health/live returns and no acquire_failed storm appears.
```

Revised plan:

```text
Manual check: two quick catalog launches are accepted and each run eventually clears launch_task_resolution_pending, reaches terminal failure with explicit metadata, or remains in a documented recoverable pending state.
```

Reason: the fix must preserve catalog launch correctness, not only quiet the pool logs.

## Patch 4: Make Modal Timeout Classification First-Class

Original plan:

```text
Timeout raises TimeoutError and resolve_modal_function may classify it generically.
```

Revised plan:

```text
Timeouts classify as modal_sdk_timeout and heartbeat metadata treats that as a blocked dispatch condition.
```

Reason: operators need to distinguish local Modal SDK stalls from missing apps, missing functions, and generic SDK failures.
