# Comparison

## Summary

The original plan was directionally strong but assumed the summary surface would remain usable enough to show run controls and stale counts. Browser-use showed the current UI can lose summary stats and controls entirely while Supabase still has active jobs. The revised plan moves active-run truth into a bounded backend contract that is independent of the full summary path.

## Score Delta

| Area | Original | Revised | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| Final score | 84 | 94 | +10 | Revision closes timeout, cancel, and count-semantics gaps. |
| Execution readiness | Good | Ready after approval | + | Payload and cancel response shapes are concrete. |
| Verification strength | Strong | Excellent | + | Adds browser-use degraded-state checks and Supabase row agreement. |
| Risk handling | Adequate | Strong | + | Separates POST failure, stale cache, reused run, and cooperative cancellation risks. |

## Changed Topic Table

| Topic | Original | Revised | Change |
| --- | ---: | ---: | --- |
| A.1 Goal clarity | 8 | 9 | Goal now includes summary timeout and unavailable-card behavior. |
| A.2 Surface awareness | 8 | 9 | Adds specific active-lane/proxy endpoint and code facts. |
| A.3 Sequencing | 8 | 9 | Adds evidence freeze before implementation and bounded endpoint before UI work. |
| A.4 Specificity | 7 | 9 | Adds payload shape, cancel response shape, lane rules, and metadata. |
| A.5 Verification | 8 | 9 | Adds current browser-use timeout proof and exact post-implementation browser checks. |
| B Gap coverage | 7 | 9 | Closes summary unavailable and cancel-request ambiguity gaps. |
| C Tooling | 7 | 9 | Uses Browser Use and Supabase as evidence sources, not optional mentions. |
| E Risk | 7 | 8 | Adds Modal cooperative cancellation and request-reached-backend uncertainty. |
| F Scope | 7 | 8 | Keeps work bounded to run/cancel/count truth. |
| H Bonus | 3 | 4 | Adds degraded-state UX and orchestration split. |

## Execution Difference

Original handoff was sequential. Revised handoff is `orchestrate-subagents` after Phase 1 contract shape is settled:

- one backend owner for the large shared repository file,
- one app owner for rendering/proxy/test follow-through,
- one QA owner for Browser Use and Supabase verification.
