# Patches

These are plan patches, not code patches.

## Patch 1 - Add Summary Timeout As A First-Class Failure

Original draft treated the page mainly as a stale card plus hidden comments run. The revised plan adds browser-use evidence that the page can show `Comments Saved: Unavailable`, `Media Saved: Unavailable`, `Posts 0 / 0`, and the summary timeout message while DB jobs are still active.

Changed sections:

- `project_context`
- `goals`
- `Phase 1`
- `Phase 4`
- `acceptance_criteria`

## Patch 2 - Make Active Lanes Independent Of Full Summary

Original draft allowed extending snapshot/dashboard payload but did not make the active-lane contract explicitly independent of heavyweight summary work. The revised plan adds a preferred bounded route and payload shape for `runs/active`.

Changed sections:

- `summary`
- `Phase 1`
- `architecture_impact`
- `data_or_api_impact`

## Patch 3 - Strengthen Cancel Semantics

Original draft said cancel should be durable and lane-aware but still left room for background finalization. The revised plan requires durable request-path status writes, cache invalidation, comments cancel, lane rules, and cancel response shape.

Changed sections:

- `Phase 2`
- `Phase 3`
- `risks_edge_cases_open_questions`

## Patch 4 - Add `cancelling` Worker Stop Semantics

Original draft mentioned cooperative worker cancellation but did not make the current `_abort_claimed_job_if_cancelled(...)` gap explicit. The revised plan requires `cancelling` and `cancelled` to stop long-running workers.

Changed sections:

- `project_context`
- `Phase 3`
- `acceptance_criteria`

## Patch 5 - Tighten Comments Saved Semantics

Original draft added a comments-tile phase but did not fully specify unavailable/stale/progress-overlaid states or denominator metadata. The revised plan defines numerator, denominator source, freshness metadata, and unavailable behavior.

Changed sections:

- `Phase 5`
- `ux_admin_ops_considerations`
- `validation_plan`

## Patch 6 - Change Execution Handoff

Original draft recommended `orchestrate-plan-execution`. The revised plan recommends `orchestrate-subagents` with strict ownership because backend, app, and QA verification can parallelize after the Phase 1 payload shape is settled.

Changed sections:

- `recommended_next_step_after_approval`
- `result.json`

## Patch 7 - Preserve Cleanup Contract

The revised plan includes the required Plan Grader cleanup note verbatim near the end.

Changed sections:

- `Cleanup Note`
