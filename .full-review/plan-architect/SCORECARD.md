# SCORECARD - BravoTV Instagram Backfill Recovery Plan

Target readiness: 97

| Dimension | Before Audit Fix | After Audit Fix | Notes |
| --- | ---: | ---: | --- |
| Current runtime grounding | 8 | 9 | Keeps run IDs/counts but now gates all action behind fresh read-only re-verification. |
| Mutation safety | 5 | 9 | Removes default `recover-stalled` from diagnosis and labels it mutating. |
| Approval-blocker correctness | 4 | 9 | Reframes the blocker around Modal defaults, public mode, `MIN_GAP`, and terminal acceptance. |
| Recovery executability | 6 | 8 | Adds comments-stage stale recovery and failed-job handling; exact terminal-reason persistence still must be checked at execution. |
| Validation rigor | 6 | 9 | Removes dead selector and adds public-mode/auto-auth tests for config/env changes. |
| Deployment safety | 7 | 9 | Dirty backend deploy is now a hard human checkpoint. |
| Completion gates | 7 | 9 | Defines high-volume threshold and accepted terminal reasons. |
| Rollback/abort posture | 5 | 9 | Adds explicit abort procedure. |

## Scores

- Initial raw: 72
- Initial readiness: 59
- Revised raw: 93
- Revised readiness: 97
- Target: 97
- Stop reason: target_met
- Evidence grade: 2

## Readiness Gates

- No active hard blocker remains in the plan text.
- Execution still has required checkpoints, but each is represented as a conservative default or a hard stop.
- No mutating command is recommended before read-only re-verification.
- No deploy is recommended before scoped diff review or explicit human approval.

## Remaining Execution Decisions

- Default: accept sub-`MIN_GAP` residuals as terminal with reason `approval-blocked`.
- Override: lower `MIN_GAP` or permit authenticated fallback only with explicit human approval.
- Verify the terminal-reason persistence field before SQL/data mutation.
