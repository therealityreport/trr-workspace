# Query Plan Evidence Runbook

Purpose: make hot-path query tuning repeatable before anyone adds or removes indexes. This runbook covers evidence collection only. New indexes require a separate migration task with route/query justification and RLS/grants review; index removals require live usage evidence, owner review, rollback SQL, and a soak/recheck window.

## Scope

The current harness lives in:

- `TRR-Backend/scripts/db/hot_path_explain/hot_path_explain.sql`
- `TRR-Backend/scripts/db/hot_path_explain/README.md`

It includes labeled EXPLAIN sections for:

- Social landing summary: covered shows, reddit dashboard, SocialBlade rows.
- Social profile dashboard: shared account source lookup and recent catalog jobs.
- Season/week analytics: season targets and bounded week live-health buckets.
- Shared ingest/review: recent runs and open shared review queue.
- Reddit sources/window reads: communities with threads, stored window posts, post comments.
- Survey admin: normalized survey definition, responses, survey palette reads.
- Brand/media/gallery: brand logo assets, brand family rules, entity media links.
- Admin recent-show reads: show search/recent list path.

## Safe Collection

Use plain `EXPLAIN` first:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
PGAPPNAME=trr-hot-path-explain \
psql "$TRR_DB_URL" \
  -v explain_analyze=false \
  -v show_id=<uuid> \
  -v season_id=<uuid> \
  -v account_platform=instagram \
  -v account_handle=<handle> \
  -v statement_timeout=8s \
  -f scripts/db/hot_path_explain/hot_path_explain.sql \
  -o /tmp/trr-hot-path-explain.txt
```

Use `explain_analyze=true` only when the route owner agrees the selected parameters are bounded and representative. Keep `statement_timeout` low, use dev/staging first, and avoid production during active traffic unless this is an incident investigation.

## Evidence Record

For every candidate index or query rewrite, record:

| Field | Required content |
| --- | --- |
| Route/UI | Exact backend route, app route, and admin page if applicable |
| SQL label | The `hot_path=... label=...` marker from the harness |
| Parameters | Redacted IDs/handles, limit/offset, time window, and dataset scope |
| Plan artifact | Plain EXPLAIN output path; ANALYZE output path if safely captured |
| Finding | Scan, sort, join shape, row-estimate miss, buffer read, or repeated execution issue |
| Proposal | Candidate index or query rewrite, with columns/predicate/order |
| Write cost | Expected write amplification and affected ingest/admin writes |
| RLS/grants | Tables touched, current policies/grants reviewed, no privilege broadening |
| Owner | Backend/app owner and follow-up migration/test plan |

## Index Gate

Do not create an index unless all of these are true:

- The route and SQL label are named.
- The plan artifact shows the current bottleneck.
- The proposed index matches the filter, join, sort, or partial predicate in the hot query.
- Write overhead is acceptable for the tables involved.
- RLS/grants review is complete for every affected schema/table.
- Migration ownership and rollback are defined in the follow-up task.

## Index Removal Gate

Do not drop an index from Supabase Advisor output alone. Generate the unused-index evidence report first:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/unused_index_evidence_report.py \
  --advisor-snapshot /Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-snapshot-2026-04-27.md \
  --output /Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-27.md
```

The report uses live `pg_stat_user_indexes` and marks every row `approved_to_drop=no` by default. A drop candidate can move forward only when all of these are true:

- The saved advisor snapshot names the index and live stats show `idx_scan = 0`.
- The index is not primary, unique, exclusion, constraint-backed, FK-hardening, or recently introduced by a discoverable migration.
- A route/workload owner confirms no current hot-path read, admin filter, ordering, or future replay path depends on it.
- Plain EXPLAIN evidence exists for representative reads that might have used the index.
- Rollback SQL exists and uses `CREATE INDEX CONCURRENTLY` with the original definition.
- Production drops have a 7-day recheck unless the owner records an explicit urgent-removal exception.

This phase intentionally does not edit migration files, runtime code, API ledgers, or RLS review docs.
