# Backend Pool Saturation Suggestions

1. **Title:** Add Queue Age To Runtime Snapshot  
   **Type:** Small  
   **Why:** A queue count alone does not show whether work is stuck.  
   **Where it would apply:** `background_task_snapshot()`  
   **How it could improve the plan:** Include oldest queued age so operators can tell saturation from normal launch activity.

2. **Title:** Emit Structured Queue Events  
   **Type:** Small  
   **Why:** Log search is easier when queue events use stable keys.  
   **Where it would apply:** `background_tasks.py`, `socials.py`, `social_season_analytics.py`  
   **How it could improve the plan:** Add fields like `group`, `key`, `state`, and `queue_size`.

3. **Title:** Add Env Contract Follow-Up  
   **Type:** Small  
   **Why:** The new env knobs become operational contract.  
   **Where it would apply:** `docs/workspace/env-contract.md`  
   **How it could improve the plan:** Makes future local-dev debugging less dependent on reading code.

4. **Title:** Add Queue Drain Test  
   **Type:** Medium  
   **Why:** The most important behavior is that accepted queued tasks eventually run.  
   **Where it would apply:** `tests/socials/test_background_tasks.py`  
   **How it could improve the plan:** Protects against regressions where queued work remains in `queued_keys`.

5. **Title:** Add Worker Exception Counter  
   **Type:** Small  
   **Why:** Queue workers catch exceptions, so failures need visibility.  
   **Where it would apply:** `background_task_snapshot()`  
   **How it could improve the plan:** Gives operators a DB-free signal for repeated local control-plane failures.

6. **Title:** Add Modal Executor Saturation Snapshot  
   **Type:** Medium  
   **Why:** SDK timeouts may leave worker threads waiting until the underlying call returns.  
   **Where it would apply:** `modal_dispatch.py`, `/health/runtime`  
   **How it could improve the plan:** Shows whether Modal SDK worker slots are occupied.

7. **Title:** Add Recovery Probe Command  
   **Type:** Small  
   **Why:** Queue-full behavior relies on recoverable pending state.  
   **Where it would apply:** Manual verification section  
   **How it could improve the plan:** Add one SQL or API check for pending catalog launches with `launch_task_resolution_pending=true`.

8. **Title:** Keep Pool-Size Increase As Explicit Non-Goal  
   **Type:** Small  
   **Why:** Pool increases can hide the local fan-out bug.  
   **Where it would apply:** Plan header  
   **How it could improve the plan:** Prevents implementers from "fixing" the symptom by widening `TRR_DB_POOL_MAXCONN`.

9. **Title:** Add Rollback Knob For Queue Use  
   **Type:** Medium  
   **Why:** A new queue can block throughput if misconfigured.  
   **Where it would apply:** `background_tasks.py`  
   **How it could improve the plan:** A temporary env bypass can restore plain threads during emergency local debugging.

10. **Title:** Add Thread Name Assertion In Runtime Check  
    **Type:** Small  
    **Why:** The original diagnosis depended on seeing named blocking threads.  
    **Where it would apply:** Manual verification  
    **How it could improve the plan:** Confirms the new worker naming makes future samples easier to read.
