# Unused Index Decision Matrix

Status: generated non-destructive guardrail pass on 2026-04-28.

## Source Universe

- Current CSV rows: `1302`
- Original owner-requested rows: `1,324`
- Reconciliation status: `current_csv_1302_used_for_non_destructive_artifacts; original_1324_unresolved`
- Approved to drop in this pass: `0`
- Live DB connection source: `TRR_DB_DIRECT_URL`
- Resolved DB host: `db.vwxfvzutyufrkhfgoeaa.supabase.co`
- Stats-window evidence: `docs/workspace/unused-index-stats-window-2026-04-28.json`

No live index drops were executed. Existing prior Phase 3 SQL files are historical evidence only.

## By Workload

| workload | count |
| --- | ---: |
| admin tooling | 77 |
| core catalog/media | 439 |
| ml/screenalytics | 192 |
| pipeline/other | 8 |
| public/survey | 138 |
| social data/backfill | 448 |

## By Current Review Status

| status | count |
| --- | ---: |
| defer:idx_scan_nonzero | 267 |
| drop_review_required | 258 |
| excluded | 777 |

## By Decision

| decision | count |
| --- | ---: |
| keep_because_constraint_or_integrity | 676 |
| keep_because_nonzero_usage | 267 |
| keep_current_index | 89 |
| keep_pending_7_day_recheck | 12 |
| keep_pending_product_architecture_decision | 24 |
| needs_manual_query_review | 234 |

## By Risk

| risk | count |
| --- | ---: |
| high | 108 |
| low | 1032 |
| medium | 162 |

## Notes

- All `drop_review_required` rows remain unapproved unless a later owner review supplies route/job evidence, stats-window proof, live rollback SQL, and explicit approval.
- Social hashtag/search rows remain blocked by `docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md`.
- The machine-readable matrix is `docs/workspace/unused-index-decision-matrix-2026-04-28.csv`.
