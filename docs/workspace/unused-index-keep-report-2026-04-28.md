# Unused Index Keep Report

Status: generated non-destructive guardrail pass.

## Summary

- Keep rows: `1068`
- Pending/manual-review rows: `234`
- Approved-to-drop rows: `0`

## Keep Decisions

| decision | count |
| --- | ---: |
| keep_because_constraint_or_integrity | 676 |
| keep_because_nonzero_usage | 267 |
| keep_current_index | 89 |
| keep_pending_7_day_recheck | 12 |
| keep_pending_product_architecture_decision | 24 |

## Pending Decisions

| decision | count |
| --- | ---: |
| needs_manual_query_review | 234 |

## Notes

- Protected excluded rows stay because primary-key, unique, constraint-backed, FK-hardening, or recent-index status is stronger than zero-scan evidence.
- Nonzero-usage rows stay because the database used them in the current stats window.
- Zero-scan candidates remain pending because this pass did not perform route/job-level proof or owner approval.
