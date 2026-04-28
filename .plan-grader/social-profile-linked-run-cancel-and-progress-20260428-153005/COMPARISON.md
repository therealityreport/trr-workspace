# Comparison

## Summary

The prior revised plan fixed the active-lane/cancel/summary-count problem. This revision makes all prior suggestions required and adds the user's final account reset and fresh backfill proof loop.

## Score Delta

| Area | Prior revised | New revised | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| Final score | 94 | 96 | +2 | Better operational diagnostics and cleaner final validation. |
| Risk handling | Strong | Stronger | + | Destructive reset has explicit confirmation and scope controls. |
| Verification | Excellent | Excellent | + | Adds zero-state UI proof before fresh backfill. |
| Scope | Strong | Strong | 0 | More work, but still account-scoped and phase-gated. |

## Required Additions

| Addition | Prior status | New status |
| --- | --- | --- |
| Run timeline drawer | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Cancel all active lanes | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| One-account run-state CLI | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Debug JSON button | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Freshness badge | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| DB pressure hint | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Shared run-state fixtures | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Cancel audit event table | Optional, conditional | Required conditional task |
| Remote invocation status refresh | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Canary account verification | Optional | Required under `ADDITIONAL SUGGESTIONS` |
| Clear `@thetraitorsus` Instagram post-derived rows | Missing | Final phase with action-time confirmation |
| Browser Use zero-state and backfill launch | Missing | Final phase requirement |

## Execution Impact

The recommended handoff stays `orchestrate-subagents`, but the final reset/backfill must be owned by one operator session because it includes a destructive Supabase action followed by Browser Use verification and launch.
