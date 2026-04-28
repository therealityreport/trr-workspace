# Unused Index Owner Review Packets

Status: closed for the 2026-04-28 remediation cycle. Pipeline-owner, admin-tooling, and flashback gameplay batches were approved, executed, and verified on 2026-04-28. Remaining packet rows are intentionally deferred and stay blocked unless a future cycle explicitly reopens owner review with rollback and review evidence.

Only rows that remain `approved_to_drop=yes` after owner review and have all required approval fields may be rendered into Phase 3 drop SQL.

Required approval fields: `approved_to_drop`, `approval_reason`, `approved_by`, `reviewed_routes_or_jobs`, `stats_window_checked_at`, `rollback_sql`.

## Inputs

- Current Advisor snapshot: `/tmp/trr-performance-advisor-after-phase3-flashback-gameplay-removal-20260428.json`
- Original owner-packet source snapshot: `/tmp/trr-performance-advisor-phase4-complete-20260428.json`
- Resolved DB host: `db.vwxfvzutyufrkhfgoeaa.supabase.co`
- Candidate source rows: `277`

## Packets

| owner | candidate_count | packet_csv | packet_markdown |
| --- | --- | --- | --- |
| admin tooling owner | 19 | admin-tooling-owner.csv | admin-tooling-owner.md |
| catalog/media owner | 68 | catalog-media-owner.csv | catalog-media-owner.md |
| pipeline owner | 4 | pipeline-owner.csv | pipeline-owner.md |
| screenalytics/ml owner | 47 | screenalytics-ml-owner.csv | screenalytics-ml-owner.md |
| social data/backfill owner | 100 | social-data-backfill-owner.csv | social-data-backfill-owner.md |
| survey/public app owner | 39 | survey-public-app-owner.csv | survey-public-app-owner.md |

## Phase 3 Gate

Render drop SQL with:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/unused_index_evidence_report.py \
  --approval-packet-dir ../docs/workspace/unused-index-owner-review-2026-04-28 \
  --drop-sql-output ../docs/workspace/unused-index-owner-review-2026-04-28/phase3-approved-drops.sql
```

Current execution state:

- Pipeline-owner packet: `4` approved, `4` dropped live on 2026-04-28.
- Admin-tooling packet: `12` approved, `12` dropped live on 2026-04-28; `7` admin rows remain deferred.
- Survey/public packet: `2` flashback gameplay indexes approved, `2` dropped live on 2026-04-28; empty `public.flashback_sessions` and `public.flashback_user_stats` gameplay tables plus RPC helpers removed; backend migration `20260428113000_remove_flashback_gameplay_write_path.sql` preserves that removal; `37` survey/public rows remain deferred.
- Advisor Performance recheck after the flashback gameplay cleanup: `unused_index=350`.
- Fresh live report after the flashback gameplay cleanup: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`.
- Remaining `drop_review_required`: `258`.
- Phase 5 closeout: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`.
- Evidence:
  - `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-pipeline-drop-evidence.md`
  - `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-admin-drop-evidence.md`
  - `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/phase3-flashback-drop-evidence.md`

Remaining owner-review counts after the flashback gameplay cleanup:

| owner | remaining |
| --- | ---: |
| admin tooling owner | 6 |
| catalog/media owner | 68 |
| screenalytics/ml owner | 47 |
| social data/backfill owner | 100 |
| survey/public app owner | 37 |
