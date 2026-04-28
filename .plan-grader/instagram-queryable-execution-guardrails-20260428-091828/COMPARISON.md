# COMPARISON: Schema-First Plan vs Execution-Guarded Plan

## Summary

The prior schema-first plan solved the duplicate-storage problem, but still had execution risks. This revision adds operational constraints that make parallel implementation realistic.

## Key Deltas

| Area | Previous Revised Plan | New Revised Plan |
| --- | --- | --- |
| Monolith handling | Mentioned `social_season_analytics.py` as a surface | One writer only; all other workers read-only |
| Phase 0 approval | Decision note written, but no hard review gate | User approval required before Phase 1 or subagent fan-out |
| Profile uniqueness | Described unique constraints conceptually | Uses explicit partial unique indexes |
| Profile ID upgrade | Merge report existed as suggestion | Persistence/backfill must implement merge/update/skip flow |
| Recent migrations | Not named | Search columns and catalog collaborators migrations must be reconciled |
| Parallelism | Recommended after Phase 0 | Still recommended, but bounded by ownership and approval gates |

## Score Delta

| Topic | Previous | New | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| Repo/surface awareness | 8.9 | 9.0 | +0.1 | Adds exact hot-file and migration evidence. |
| Sequencing | 8.8 | 9.0 | +0.2 | Adds user approval checkpoint. |
| Execution specificity | 8.7 | 9.0 | +0.3 | Adds one-writer and ID-upgrade details. |
| Verification | 8.5 | 8.8 | +0.3 | Adds concrete ownership/index/migration checks. |
| Gap coverage | 8.8 | 9.0 | +0.2 | Closes execution and schema traps. |
| Safety | 8.7 | 9.0 | +0.3 | Stronger agent safety and DB integrity. |
| Overall | 94 | 96 | +2 | Better execution reliability. |

## Recommended Execution

Start with Phase 0 only. After the user approves the schema decision note, use `orchestrate-subagents` with one worker owning `social_season_analytics.py`.
