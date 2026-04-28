# Supabase Advisor Performance Phase 0 Evidence - 2026-04-28

Status: Phase 0 live inventory captured. Phase 1 artifacts are local-only and staged; no live DDL was deployed from Codex. Live deployment, Phase 2, and Phase 3 remain blocked by the owner-controlled rollout gate, the post-deploy verifier, and required advisor recheck evidence.

Canonical plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`

Phase 1 implementation evidence: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-phase1-implementation-2026-04-28.md`

Source snapshot: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-snapshot-2026-04-27.md`

## Capture Commands

The live SQL inventory was run through the backend SQL runner with `TRR_DB_URL` explicitly exported. The runner masked the connection string in output.

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh /tmp/trr-phase0-evidence.PJdQdE
./scripts/db/run_sql.sh /tmp/trr-phase0-summary.w9Y7FW
```

Raw local outputs for this capture:

- `/tmp/trr-phase0-evidence-output.txt`
- `/tmp/trr-phase0-summary-output.txt`

Supabase MCP Performance Advisor recheck was attempted and blocked:

```text
MCP error -32600: You do not have permission to perform this action
```

## Target Table Presence

All nine Phase 1 target tables exist in the live database.

| Schema | Table | relkind |
| --- | --- | --- |
| core | networks | r |
| core | production_companies | r |
| core | show_watch_providers | r |
| core | watch_providers | r |
| firebase_surveys | answers | r |
| firebase_surveys | responses | r |
| public | flashback_events | r |
| public | flashback_quizzes | r |
| public | show_icons | r |

## Policy Inventory Summary

Live policy count: 22 policies.

| Schema | Table | Command | Count |
| --- | --- | --- | ---: |
| core | networks | ALL | 1 |
| core | networks | SELECT | 1 |
| core | production_companies | ALL | 1 |
| core | production_companies | SELECT | 1 |
| core | show_watch_providers | ALL | 1 |
| core | show_watch_providers | SELECT | 1 |
| core | watch_providers | ALL | 1 |
| core | watch_providers | SELECT | 1 |
| firebase_surveys | answers | ALL | 1 |
| firebase_surveys | answers | INSERT | 1 |
| firebase_surveys | answers | SELECT | 1 |
| firebase_surveys | answers | UPDATE | 1 |
| firebase_surveys | responses | ALL | 1 |
| firebase_surveys | responses | INSERT | 1 |
| firebase_surveys | responses | SELECT | 1 |
| firebase_surveys | responses | UPDATE | 1 |
| public | flashback_events | ALL | 1 |
| public | flashback_events | SELECT | 1 |
| public | flashback_quizzes | ALL | 1 |
| public | flashback_quizzes | SELECT | 1 |
| public | show_icons | ALL | 1 |
| public | show_icons | SELECT | 1 |

### Exact Policy Names And Semantics

| Schema | Table | Policy | Roles | Command | Qual / With Check Summary |
| --- | --- | --- | --- | --- | --- |
| core | networks | core_tmdb_networks_service_role | public | ALL | `auth.role() = 'service_role'`; matching `WITH CHECK` |
| core | networks | core_tmdb_networks_public_read | public | SELECT | `true` |
| core | production_companies | core_tmdb_production_companies_service_role | public | ALL | `auth.role() = 'service_role'`; matching `WITH CHECK` |
| core | production_companies | core_tmdb_production_companies_public_read | public | SELECT | `true` |
| core | show_watch_providers | core_show_watch_providers_service_role | public | ALL | `auth.role() = 'service_role'`; matching `WITH CHECK` |
| core | show_watch_providers | core_show_watch_providers_public_read | public | SELECT | `true` |
| core | watch_providers | core_tmdb_watch_providers_service_role | public | ALL | `auth.role() = 'service_role'`; matching `WITH CHECK` |
| core | watch_providers | core_tmdb_watch_providers_public_read | public | SELECT | `true` |
| firebase_surveys | answers | answers_admin_all | public | ALL | `(select current_setting('app.is_admin', true)) = 'true'` |
| firebase_surveys | answers | answers_insert_own | public | INSERT | parent response exists and response `user_id = (select current_setting('app.firebase_uid', true))` in `WITH CHECK` |
| firebase_surveys | answers | answers_select_own | public | SELECT | parent response exists and response `user_id = (select current_setting('app.firebase_uid', true))` |
| firebase_surveys | answers | answers_update_own | public | UPDATE | parent response exists and response `user_id = (select current_setting('app.firebase_uid', true))` in `USING`; no `WITH CHECK` |
| firebase_surveys | responses | responses_admin_all | public | ALL | `(select current_setting('app.is_admin', true)) = 'true'` |
| firebase_surveys | responses | responses_insert_own | public | INSERT | `user_id = (select current_setting('app.firebase_uid', true))` in `WITH CHECK` |
| firebase_surveys | responses | responses_select_own | public | SELECT | `user_id = (select current_setting('app.firebase_uid', true))` |
| firebase_surveys | responses | responses_update_own | public | UPDATE | `user_id = (select current_setting('app.firebase_uid', true))` in `USING`; no `WITH CHECK` |
| public | flashback_events | Service role full access to events | public | ALL | `auth.role() = 'service_role'`; no `WITH CHECK` |
| public | flashback_events | Events of published quizzes are viewable | public | SELECT | parent quiz exists and `is_published = true` |
| public | flashback_quizzes | Service role full access to quizzes | public | ALL | `auth.role() = 'service_role'`; no `WITH CHECK` |
| public | flashback_quizzes | Published quizzes are viewable by all | public | SELECT | `is_published = true` |
| public | show_icons | Allow service role all on show_icons | public | ALL | `auth.role() = 'service_role'`; matching `WITH CHECK` |
| public | show_icons | Allow public read on show_icons | public | SELECT | `true` |

Phase 1 rollback SQL must restore these policies by name.

## Grant Inventory Summary

Live grant rows captured: 168.

| Scope | Grantee | Privileges and `is_grantable` |
| --- | --- | --- |
| `core.networks`, `core.production_companies`, `core.show_watch_providers`, `core.watch_providers` | anon | `SELECT(NO)` |
| same core tables | authenticated | `SELECT(NO)` |
| same core tables | service_role | `DELETE(NO), INSERT(NO), REFERENCES(NO), SELECT(NO), TRIGGER(NO), TRUNCATE(NO), UPDATE(NO)` |
| same core tables | postgres | `DELETE(YES), INSERT(YES), REFERENCES(YES), SELECT(YES), TRIGGER(YES), TRUNCATE(YES), UPDATE(YES)` |
| `firebase_surveys.responses`, `firebase_surveys.answers` | trr_app | `INSERT(NO), SELECT(NO), UPDATE(NO)` |
| same firebase tables | postgres | `DELETE(YES), INSERT(YES), REFERENCES(YES), SELECT(YES), TRIGGER(YES), TRUNCATE(YES), UPDATE(YES)` |
| `public.show_icons`, `public.flashback_quizzes`, `public.flashback_events` | anon | `DELETE(NO), INSERT(NO), REFERENCES(NO), SELECT(NO), TRIGGER(NO), TRUNCATE(NO), UPDATE(NO)` |
| same public tables | authenticated | `DELETE(NO), INSERT(NO), REFERENCES(NO), SELECT(NO), TRIGGER(NO), TRUNCATE(NO), UPDATE(NO)` |
| same public tables | service_role | `DELETE(NO), INSERT(NO), REFERENCES(NO), SELECT(NO), TRIGGER(NO), TRUNCATE(NO), UPDATE(NO)` |
| same public tables | postgres | `DELETE(YES), INSERT(YES), REFERENCES(YES), SELECT(YES), TRIGGER(YES), TRUNCATE(YES), UPDATE(YES)` |

Do not change these GRANTs in Phase 1 unless explicitly approved. The broad anon/authenticated/public-table grants mean RLS, not GRANTs alone, blocks public writes on the public tables.

## Owner And RLS State

| Schema | Table | Owner | RLS Enabled | Force RLS |
| --- | --- | --- | --- | --- |
| core | networks | postgres | true | false |
| core | production_companies | postgres | true | false |
| core | show_watch_providers | postgres | true | false |
| core | watch_providers | postgres | true | false |
| firebase_surveys | answers | postgres | true | true |
| firebase_surveys | responses | postgres | true | true |
| public | flashback_events | postgres | true | false |
| public | flashback_quizzes | postgres | true | false |
| public | show_icons | postgres | true | false |

## Before-State Permission Matrix Expectations

This is the Phase 0 expected behavior matrix inferred from live policies plus grants. Phase 1 must convert this into executable SQL tests before any policy DDL is applied.

| Table group | Role/context | SELECT | INSERT | UPDATE | DELETE |
| --- | --- | --- | --- | --- | --- |
| core catalog/watch-provider tables | anon | allow | block, no grant | block, no grant | block, no grant |
| core catalog/watch-provider tables | authenticated | allow | block, no grant | block, no grant | block, no grant |
| core catalog/watch-provider tables | service_role | allow | allow through service-role policy | allow through service-role policy | allow through service-role policy |
| core catalog/watch-provider tables | app firebase owner/admin | same as active DB role; no firebase-specific branch | same as active DB role | same as active DB role | same as active DB role |
| public.show_icons | anon/authenticated | allow all rows | block by RLS despite grant | block by RLS despite grant | block by RLS despite grant |
| public.show_icons | service_role | allow | allow through service-role policy | allow through service-role policy | allow through service-role policy |
| public.flashback_quizzes | anon/authenticated | allow published quizzes only | block by RLS despite grant | block by RLS despite grant | block by RLS despite grant |
| public.flashback_quizzes | service_role | allow | allow through service-role policy | allow through service-role policy | allow through service-role policy |
| public.flashback_events | anon/authenticated | allow events whose quiz is published | block by RLS despite grant | block by RLS despite grant | block by RLS despite grant |
| public.flashback_events | service_role | allow | allow through service-role policy | allow through service-role policy | allow through service-role policy |
| firebase_surveys.responses | anon/authenticated/service_role | block, no live grants | block, no live grants | block, no live grants | block, no live grants |
| firebase_surveys.responses | trr_app owner context | own rows only | allow own rows by `WITH CHECK` | allow old own rows; current policy has no `WITH CHECK` for new row | block, no grant |
| firebase_surveys.responses | trr_app admin context | allow through admin policy | allow through admin policy | allow through admin policy | block, no grant |
| firebase_surveys.answers | anon/authenticated/service_role | block, no live grants | block, no live grants | block, no live grants | block, no live grants |
| firebase_surveys.answers | trr_app owner context | answers whose parent response is owned | allow if parent response is owned | allow old answer if parent response is owned; current policy has no `WITH CHECK` for new `response_id` | block, no grant |
| firebase_surveys.answers | trr_app admin context | allow through admin policy | allow through admin policy | allow through admin policy | block, no grant |
| firebase_surveys tables | backend/postgres owner | owner-level access | owner-level access | owner-level access | owner-level access |

Important Phase 1 implications:

- Current service-role policies are `TO public`, not `TO service_role`; Phase 1 must preserve or explicitly replace `TO` roles.
- `firebase_surveys.responses` and `firebase_surveys.answers` have `FORCE ROW LEVEL SECURITY` enabled.
- Current firebase update policies do not include `WITH CHECK`, so Phase 1 must prove the new row remains owner/admin allowed.
- `firebase_surveys.answers` update must stop if an answer can move to a response owned by another user.

## Before-State EXPLAIN Summary

Read-only plain `EXPLAIN` was captured for simple bounded reads on the nine target tables. These are not route-realistic plans; they are a safe before-state baseline for the target tables.

| Query | Plan Shape |
| --- | --- |
| `select * from core.networks limit 20` | Limit -> Seq Scan on `core.networks`; cost `0.00..14.49`, rows `49` |
| `select * from core.production_companies limit 20` | Limit -> Seq Scan on `core.production_companies`; cost `0.00..44.87`, rows `187` |
| `select * from core.watch_providers limit 20` | Limit -> Seq Scan on `core.watch_providers`; cost `0.00..72.85`, rows `185` |
| `select * from core.show_watch_providers limit 20` | Limit -> Seq Scan on `core.show_watch_providers`; cost `0.00..424.21`, rows `12321` |
| `select * from public.show_icons limit 20` | Limit -> Seq Scan on `public.show_icons`; cost `0.00..13.20`, rows `320` |
| `select * from public.flashback_quizzes limit 20` | Limit -> Seq Scan on `public.flashback_quizzes`; cost `0.00..16.30`, rows `630` |
| `select * from public.flashback_events limit 20` | Limit -> Seq Scan on `public.flashback_events`; cost `0.00..1.07`, rows `7` |
| `select * from firebase_surveys.responses limit 20` | Limit -> Seq Scan on `firebase_surveys.responses`; cost `0.00..0.00`, rows `1` |
| `select * from firebase_surveys.answers limit 20` | Limit -> Seq Scan on `firebase_surveys.answers`; cost `0.00..0.00`, rows `1` |

Write-path EXPLAIN was not run against live tables in Phase 0. Phase 1 must use synthetic transactions or SQL tests with rollback to cover insert/update/delete semantics before DDL.

## Phase 0 Stop-Rule Result

- Missing target tables: none.
- Live object-name mismatch: none for the nine target tables.
- Grant/owner/RLS/FORCE RLS capture: complete.
- Fresh Performance Advisor capture: blocked from this Codex session by Supabase MCP permission.
- Phase 1 approval state: local-only artifacts staged; live deployment remains blocked pending owner-controlled DDL rollout, `scripts/db/verify_advisor_remediation_phase1.sql` passing post-deploy, and immediate advisor recheck evidence. Phase 2 and Phase 3 must not start until the advisor recheck is captured or a concrete permission blocker is recorded.
