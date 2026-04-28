# COMPARISON: Previous Revised Plan vs Schema-First Revised Plan

## Summary

The previous revised plan was already approved, but it still risked adding new Instagram-specific post columns and child tables before deciding how those fields relate to the newer `social.social_posts` canonical foundation. This revision changes the execution shape: schema architecture comes first, then additive migrations.

## Key Deltas

| Area | Previous Revised Plan | New Revised Plan |
| --- | --- | --- |
| Schema sequencing | Field inventory then additive schema | Phase 0 storage-map gate before migrations |
| Post storage | Still centered on Instagram-specific canonical/catalog tables | Uses `social.social_posts` family first where fields fit |
| Legacy tables | Could continue expanding | Stable compatibility/source surfaces with bridge columns only when justified |
| Raw payload exposure | Preserved raw data but less explicit on exposure | Raw observations and diff routes are service-role/admin-only |
| Suggestions | Separate optional `SUGGESTIONS.md` | All ten suggestions integrated under `ADDITIONAL SUGGESTIONS` |
| Execution handoff | `orchestrate-subagents` after Phase 0 | Same, with schema decision as required coordination gate |

## Score Delta

| Topic | Previous | New | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| Repo/surface awareness | 8.5 | 8.9 | +0.4 | Adds canonical social post foundation. |
| Sequencing | 8.5 | 8.8 | +0.3 | Migrations are blocked on a storage decision. |
| Execution specificity | 8.3 | 8.7 | +0.4 | Storage rules are explicit. |
| Verification | 8.1 | 8.5 | +0.4 | Adds schema-decision and RLS/grant checks. |
| Gap coverage | 8.3 | 8.8 | +0.5 | Duplicate storage and public raw-data gaps are handled. |
| Safety | 8.1 | 8.7 | +0.6 | Adds raw/private boundary and rollback note. |
| Overall | 91 | 94 | +3 | Better execution safety with no destructive redesign. |

## Recommended Execution

Run `orchestrate-subagents` only after Phase 0 produces the schema decision note. Use that note as the shared contract for worker file ownership.
