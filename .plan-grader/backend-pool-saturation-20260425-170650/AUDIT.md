# Backend Pool Saturation Plan Audit

## Verdict

APPROVE AFTER PATCHING.

The source plan targets the right failure mode: the backend listener stays alive while sync execution and local control-plane work saturate, producing repeated DB pool acquisition failures. It correctly avoids treating a larger pool as the primary fix and focuses on liveness, local background-work bounds, Modal SDK timeouts, and targeted verification.

Do not execute the original plan verbatim. The main blocking gap is that the proposed background gate can reject catalog finalizer work without guaranteeing a retry. That risks converting a saturation storm into a stuck `launch_task_resolution_pending` run. Execute the revised plan in `REVISED_PLAN.md`, which replaces reject-only gating with a bounded de-duplicating queue and keeps recovery behavior explicit.

## Current-State Fit

- Correct: `/health/live` is currently a sync FastAPI handler, so it can be blocked by sync worker/threadpool saturation even when the event loop can still serve `/docs` and `/openapi.json`.
- Correct: `_queue_catalog_backfill_finalize_task(...)` currently detaches a plain daemon `Thread`, and `_dispatch_due_social_jobs_in_background(...)` starts another plain daemon thread.
- Correct: Modal dispatch helpers call `modal.Function.from_name(...)`, optional `hydrate()`, and `fn.spawn(...)` directly with no repo-level timeout or bounded SDK-call executor.
- Correct: the plan uses existing test seams: `tests/api/test_health.py`, `tests/test_modal_dispatch.py`, `tests/api/routers/test_socials_season_analytics.py`, and `tests/repositories/test_social_season_analytics.py`.
- Blocking mismatch: rejecting finalizer work when the gate is busy leaves execution dependent on indirect recovery. The plan must preserve eventual launch finalization for every reserved run accepted by the API.
- Material gap: adding diagnostics to `/health/live` changes a watchdog-facing payload and should be treated as optional or carefully scoped after the async liveness fix.

## Benefit Score

High. This targets a repeated operator-blocking TRR local dev failure: admin social backfills continue creating traffic while the backend becomes unable to acquire DB connections or answer health probes. The revised plan should reduce local thread fan-out, contain Modal SDK stalls, and keep liveness useful during active launches.

## Approval Decision

Execute the revised plan, not the original. The revised version keeps the same core architecture but patches the finalizer-loss risk, narrows the health payload change, and adds acceptance checks that directly prove no reserved catalog launch is silently dropped.

## Blocking Fixes

1. Replace reject-only `try_start_named_background_task(...)` semantics with a bounded, de-duplicating background queue that eventually runs accepted catalog finalizers.
2. Add tests proving a second catalog finalizer is queued or explicitly recoverable, not silently dropped.
3. Make `/health/live` async first; keep runtime snapshot as a separate optional `/health/runtime` endpoint or a clearly backward-compatible payload addition.
4. Add a Modal timeout reason code and heartbeat classification so timeout failures are operator-visible and do not masquerade as generic resolution failures.
5. Add a manual verification step that launches two quick catalog backfills and confirms each accepted run leaves `launch_task_resolution_pending=false` or has a documented queued state.

## Non-Blocking Improvements

- Add a small queue snapshot endpoint only after the core liveness behavior is verified.
- Add a task-level rollback note for disabling the new queue via env if it blocks launch throughput.
- Document the local defaults in `docs/workspace/env-contract.md` after the code lands.
