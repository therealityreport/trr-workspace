# Supabase Advisor Performance Closeout - 2026-04-28

Project: `trr-core` (`vwxfvzutyufrkhfgoeaa`)

Status: complete for the 2026-04-28 remediation cycle.

## Source Artifacts

- Original snapshot: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-snapshot-2026-04-27.md`
- Recheck log: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-recheck-2026-04-28.md`
- Unused-index live report: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`
- Owner packets: `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/`
- Canonical execution plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`

## Phase Results

| phase | status | result |
| --- | --- | --- |
| Phase 0 | complete | Live policy, grant, owner, RLS, and before-state evidence captured. |
| Safety hotfix gate | complete | `public.__migrations` and exposed `SECURITY DEFINER` RPC execution remediated for this plan's scope. |
| Phase 1 | complete | RLS initplan and duplicate permissive policy findings cleared. |
| Phase 2 | complete | Live unused-index evidence report and owner packets generated. |
| Phase 3 | complete for this cycle | Three approved batches were dropped and verified; remaining unapproved candidates are deferred. |
| Phase 4 | complete | `core.external_id_conflicts` primary key and Auth DB allocation singleton findings cleared. |
| Phase 5 | complete | Advisor counts and deferred residuals are recorded here. |

## Performance Advisor Counts

| finding | original 2026-04-27 | closeout 2026-04-28 | status |
| --- | ---: | ---: | --- |
| `auth_rls_initplan` | 7 | 0 | resolved |
| `multiple_permissive_policies` | 91 | 0 | resolved |
| `unindexed_foreign_keys` | 17 | 0 | resolved after removing stray non-TRR `thb_bbl` schema and flashback gameplay cleanup |
| `no_primary_key` | 1 | 0 | resolved |
| `auth_db_connections_absolute` | 1 | 0 | resolved |
| `unused_index` | 415 | 350 | partially remediated; remaining candidates deferred |
| total performance findings | 532 | 350 | residual is unused-index only |

Fresh Phase 5 Supabase Advisor recheck was run through the Supabase MCP Performance Advisor tool. The full saved API response used for the count comparison remains `/tmp/trr-performance-advisor-after-phase3-flashback-gameplay-removal-20260428.json`; `jq` confirms the closeout response category count is `unused_index=350`.

## Phase 3 Completed Scope

Approved index drops were intentionally narrow:

- Pipeline owner: `4` approved indexes dropped and verified absent.
- Admin tooling owner: `12` approved indexes dropped and verified absent.
- Survey/public flashback gameplay: `2` approved indexes dropped; empty `public.flashback_sessions`, empty `public.flashback_user_stats`, and three gameplay RPC helpers removed after owner direction that flashback gameplay is not set up.

Representative post-drop checks stayed healthy:

- Pipeline list and SocialBlade lookups still used retained indexes.
- Admin checks still used retained brand target, network entity, cast tag, person-cover primary key, discovery-state primary key, and survey unique-prefix access paths.
- Flashback cleanup targeted validation passed in backend and app tests.

## Deferred Index Candidates

The remaining owner review is intentionally skipped for this cycle. The residual `258` `drop_review_required` rows are deferred, not approved.

| owner | deferred count | reason |
| --- | ---: | --- |
| admin tooling owner | 6 | Active route filters, runtime-created indexes, FK helper paths, reddit filters, or owner-grouping paths need a future owner decision. |
| catalog/media owner | 68 | Catalog/media indexes require route and workload owner review before any destructive DDL. |
| screenalytics/ml owner | 47 | ML/screenalytics workloads require explicit workload owner approval and representative plan checks. |
| social data/backfill owner | 100 | Social ingest/backfill indexes sit on high-volume write/read paths and require separate review windows. |
| survey/public app owner | 37 | Survey/public indexes support active app/backend query surfaces, FK helpers, response-table filters, or Supabase-auth survey RPC support. |

Future work may reopen these packets, but no additional `DROP INDEX` work should be run from this cycle without explicit owner approval, rollback SQL, route/job review evidence, and post-drop advisor/EXPLAIN/soak notes.

## Security Boundary

This is a Performance Advisor closeout. Broader Security Advisor residuals remain out of scope except for the safety hotfix items already handled by this plan. The latest security recheck still has separate posture findings and should be handled by a dedicated security pass.

## Validation

- Supabase MCP Performance Advisor recheck: completed on 2026-04-28.
- Cached closeout count check: `jq -r '.lints | group_by(.name) | map([.[0].name, length] | @tsv)[]' /tmp/trr-performance-advisor-after-phase3-flashback-gameplay-removal-20260428.json` returned `unused_index	350`.
- `python3 scripts/migration-ownership-lint.py`: passed.
- `make preflight`: blocked at runtime reconcile with `pending_not_allowlisted`.

The preflight blocker is not a new advisor failure. Runtime reconcile reports pending local backend migrations that are intentionally not approved for startup auto-apply:

- `20260427140000`
- `20260428110000`
- `20260428111000`
- `20260428112000`
- `20260428113000`

The advisor-related entries correspond to manually controlled production DDL from this remediation cycle. They should stay out of startup auto-apply unless a separate migration reconciliation decision records them as safe to apply automatically or marks the live migration ledger accordingly.
