# Supabase Advisor Recheck - 2026-04-28

Project: `trr-core` (`vwxfvzutyufrkhfgoeaa`)

Status: recheck completed through the Supabase Management API with `TRR_SUPABASE_ACCESS_TOKEN`. Follow-up rechecks were run after removing the stray non-TRR `thb_bbl` schema, completing Phase 4 singleton remediation, and executing the approved Phase 3 pipeline-owner, admin-tooling, and flashback gameplay batches. Phase 5 closeout is recorded in `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`.

## Token Routing

The first Management API attempt used generic `SUPABASE_ACCESS_TOKEN` and returned HTTP 403 because that token is scoped to another Supabase project/account. TRR advisor rechecks must use `TRR_SUPABASE_ACCESS_TOKEN`, matching the project-local `.codex/config.toml` Supabase MCP configuration.

## Performance Advisor

Current source response: `/tmp/trr-performance-advisor-after-phase3-flashback-gameplay-removal-20260428.json`

| Finding | Count |
| --- | ---: |
| `auth_rls_initplan` | 0 |
| `multiple_permissive_policies` | 0 |
| `unused_index` | 350 |
| `unindexed_foreign_keys` | 0 |
| `no_primary_key` | 0 |
| `auth_db_connections_absolute` | 0 |
| total | 350 |

Phase 1 result: the targeted RLS performance findings are cleared in the API recheck.

Schema correction result: the 17 `unindexed_foreign_keys` findings were tied to the stray non-TRR `thb_bbl` schema. That schema was backed up to `/tmp/trr-thb-bbl-drop-backup-20260428-002111.sql`, dropped from the TRR project, and verified absent. The follow-up Performance Advisor recheck shows `unindexed_foreign_keys=0`.

Phase 4 result:

- `core.external_id_conflicts` now has `external_id_conflicts_pkey` on defaulted surrogate `id`.
- Supabase Auth DB allocation changed from `10 connections` to `17 percent`, preserving the approximate allocation against current `SHOW max_connections = 60`.
- Follow-up Performance Advisor recheck after Phase 4 reported only `unused_index=369`.

Phase 3 pipeline-owner batch result:

- Four approved pipeline-owner indexes were dropped with `DROP INDEX CONCURRENTLY`.
- `to_regclass(...)` returned null for all four dropped indexes.
- Follow-up Performance Advisor recheck reports only `unused_index=365`.

Phase 3 admin-tooling batch result:

- Twelve approved admin-tooling indexes were dropped with `DROP INDEX CONCURRENTLY`.
- `to_regclass(...)` returned null for all twelve dropped indexes.
- Post-drop targeted backend validation passed: `250 passed in 68.12s`.
- Representative post-drop EXPLAIN checks still used retained target/entity/pkey/unique indexes.
- Follow-up Performance Advisor recheck reports only `unused_index=352`.

Phase 3 flashback gameplay result:

- Two approved `public.flashback_sessions` indexes were dropped with `DROP INDEX CONCURRENTLY`.
- The first recheck showed the expected tradeoff: `unused_index=350` plus one new `unindexed_foreign_keys` finding because the empty session table still had a quiz FK.
- Owner direction was to remove flashback gameplay for now because it is not set up yet. The follow-up DDL removed empty `public.flashback_sessions`, empty `public.flashback_user_stats`, and the three flashback gameplay RPC helpers while retaining `public.flashback_quizzes` and `public.flashback_events`.
- Backend migration `20260428113000_remove_flashback_gameplay_write_path.sql` preserves the live removal for future environments.
- Follow-up Performance Advisor recheck reports only `unused_index=350`.

## Security Advisor

Source response: `/tmp/trr-security-advisor-phase4-complete-20260428.json`

| Finding | Count |
| --- | ---: |
| `rls_enabled_no_policy` | 63 |
| `function_search_path_mutable` | 51 |
| `extension_in_public` | 1 |
| `anon_security_definer_function_executable` | 1 |
| `authenticated_security_definer_function_executable` | 1 |
| total | 117 |

Security residuals remain for the later security pass. The Phase 1 performance remediation did not attempt to close those broader posture findings.

## Phase 2 And Phase 3

The live unused-index evidence report is:

- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.csv`

Report summary after schema correction, Phase 4 completion, Phase 3 pipeline-owner batch, Phase 3 admin-tooling batch, Phase 3 flashback gameplay cleanup, and fresh Advisor JSON input: `1302` rows, `258` `drop_review_required`, `0` `approved_to_drop` in the fresh live report.

Owner-specific review packets were generated under `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/`:

- `admin-tooling-owner.csv` / `.md`: `19` candidates
- `catalog-media-owner.csv` / `.md`: `68` candidates
- `pipeline-owner.csv` / `.md`: `4` candidates
- `screenalytics-ml-owner.csv` / `.md`: `47` candidates
- `social-data-backfill-owner.csv` / `.md`: `100` candidates
- `survey-public-app-owner.csv` / `.md`: `39` candidates

The pipeline-owner packet approved and executed `4` rows. The admin-tooling packet approved and executed `12` rows and leaves `7` admin rows deferred. The survey/public packet approved and executed `2` flashback gameplay rows; `37` survey/public rows remain deferred. Remaining owner-review counts are: admin tooling `6`, catalog/media `68`, screenalytics/ml `47`, social data/backfill `100`, and survey/public `37`.

Phase 5 closeout decision: no further Phase 3 owner review or index drops will run in this remediation cycle. The remaining `258` `drop_review_required` rows are accepted as deferred residual risk. Future Phase 3 work remains blocked until additional packet rows are explicitly approved with route-owner review, rollback SQL, and recheck/soak evidence.
