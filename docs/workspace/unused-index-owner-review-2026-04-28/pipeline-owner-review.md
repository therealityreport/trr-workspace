# Pipeline Owner Review

Workload: `pipeline/other`

Status: generated non-destructive full-review packet. No rows are approved to drop in this guardrail pass.

## Summary

| decision | count |
| --- | ---: |
| keep_because_constraint_or_integrity | 7 |
| keep_because_nonzero_usage | 1 |

## Review Posture

Rows that cannot be confidently classified remain `needs_manual_query_review`, `keep_pending_7_day_recheck`, or `keep_pending_product_architecture_decision`. Do not approve rows merely to finish the packet.

## Rows

| schema | table | index | review_status | idx_scan | index_size | table_size | decision | decision_reason | approved_to_drop | approved_by | reviewed_routes_or_jobs | query_pattern_labels | stats_window_checked_at | rollback_sql | drop_sql_if_approved | risk_level | phase3_batch_recommendation | notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pipeline | run_stages | run_stages_pkey | excluded | 0 | 8192 bytes | 24 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint,primary_key_lookup | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX run_stages_pkey ON pipeline.run_stages USING btree (id) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | run_stages | run_stages_run_id_stage_name_key | excluded | 0 | 8192 bytes | 24 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX run_stages_run_id_stage_name_key ON pipeline.run_stages USING btree (run_id, stage_name) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | runs | runs_pkey | excluded | 0 | 8192 bytes | 24 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint,primary_key_lookup | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX runs_pkey ON pipeline.runs USING btree (id) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | runs | runs_pkey | excluded | 0 | 8192 bytes | 24 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint,primary_key_lookup | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX runs_pkey ON pipeline.runs USING btree (id) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | socialblade_growth_data | socialblade_growth_data_pkey | excluded | 0 | 16 kB | 480 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint,primary_key_lookup | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX socialblade_growth_data_pkey ON pipeline.socialblade_growth_data USING btree (id) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | runs | pipeline_runs_created_at_idx | defer:idx_scan_nonzero | 1 | 8192 bytes | 24 kB | keep_because_nonzero_usage | Index has nonzero idx_scan=1 in the current stats window; keep unless later EXPLAIN and code review prove redundancy. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest | 2026-04-28T11:06:08.242170+00:00 | CREATE INDEX pipeline_runs_created_at_idx ON pipeline.runs USING btree (created_at DESC) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | socialblade_growth_data | socialblade_growth_data_platform_account_handle_idx | excluded | 56 | 16 kB | 480 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX socialblade_growth_data_platform_account_handle_idx ON pipeline.socialblade_growth_data USING btree (platform, account_handle) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
| pipeline | socialblade_growth_data | socialblade_growth_data_person_id_instagram_handle_key | excluded | 273 | 16 kB | 480 kB | keep_because_constraint_or_integrity | Protected by primary key, uniqueness, exclusion, or constraint-backed index status; zero-scan evidence is not a drop approval. | no |  | not_reviewed_in_guardrail_pass | backfill_ingest,dedupe_unique,integrity_constraint | 2026-04-28T11:06:08.242170+00:00 | CREATE UNIQUE INDEX socialblade_growth_data_person_id_instagram_handle_key ON pipeline.socialblade_growth_data USING btree (person_id, instagram_handle) |  | low |  | source_universe=1302_current_csv;original_requested_universe=1324_unreconciled |
