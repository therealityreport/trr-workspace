# TRR Supabase Advisor Performance Remediation Plan

Date: 2026-04-28
Source snapshot: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-snapshot-2026-04-27.md`
Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`
Status: complete for the 2026-04-28 remediation cycle. Phase 1 and Phase 4 live DDL/config changes are deployed and verified. Supabase Advisor recheck passed with `TRR_SUPABASE_ACCESS_TOKEN`. The stray non-TRR `thb_bbl` schema from the original snapshot was removed from the TRR Supabase project on 2026-04-28. The corrected Phase 2 unused-index report and owner-specific review packets are generated. Phase 3 completed the approved drop scope: four pipeline-owner indexes, twelve admin-tooling indexes, and two flashback gameplay indexes dropped; empty flashback gameplay tables/RPC helpers were also removed and preserved in migration `20260428113000_remove_flashback_gameplay_write_path.sql`. Phase 5 closeout is recorded in `docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`. Advisor now reports only `unused_index=350`.
Cycle decision: do not continue the remaining owner review in this cycle. The remaining `258` `drop_review_required` candidates are explicitly deferred. Do not run additional Phase 3 index drops unless a future cycle reopens owner review from `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/` and each packet row has explicit owner approval, rollback SQL, and soak/recheck evidence.

## summary

Address the Supabase Performance Advisor findings from the 2026-04-27 `trr-core` snapshot while treating the most urgent Security Advisor items as a parallel hotfix gate. Performance work must not defer `public.__migrations` RLS exposure or exposed `SECURITY DEFINER` RPC execution until after index cleanup.

The priority is the overlapping RLS performance issue: seven `auth_rls_initplan` findings and duplicate permissive policies on hot `core`, `public`, and `firebase_surveys` tables. These are high leverage because they reduce repeated per-row policy work without changing the data model or requiring broad route rewrites.

Unused indexes come second. The corrected Advisor recheck now reports 350 unused indexes after the approved pipeline-owner, admin-tooling, and flashback gameplay batches, but that is not an instruction to bulk-drop. Index retirement requires live `pg_stat_user_indexes`, query-plan evidence, route owner review, rollback SQL, and batch soak. Singleton posture items remain lower priority after the high-fan-out RLS and index-evidence work.

## saved_path

`/Users/thomashulihan/Projects/TRR/.plan-grader/supabase-advisor-performance-remediation-20260428-000000/REVISED_PLAN.md`

## canonical_execution_source

The canonical execution plan must live under `/Users/thomashulihan/Projects/TRR/docs/codex/plans/`. This `.plan-grader` copy is temporary evidence only and must not be treated as the execution source of truth after the canonical plan is updated.

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Supabase project in snapshot: `trr-core` (`vwxfvzutyufrkhfgoeaa`), Postgres `17.6.1.062`, region `us-east-1`.
- Original Performance Advisor totals from the source snapshot: `532` findings: `98` WARN and `434` INFO.
- Current Performance Advisor counts after Phase 1 and stray schema removal:
  - `unused_index`: `350`
  - `multiple_permissive_policies`: `0`
  - `unindexed_foreign_keys`: `0`
  - `auth_rls_initplan`: `0`
  - `no_primary_key`: `0`
  - `auth_db_connections_absolute`: `0`
  - total lints: `350`
- Shared-schema changes are backend-owned under `TRR-Backend/supabase/migrations`.
- App historical migration `TRR-APP/apps/web/db/migrations/016_create_rls_policies.sql` is a legacy source of policy definitions, but new shared-schema fixes should not be added as app migrations.
- Current repo evidence confirms the TMDB table rename path:
  - `TRR-Backend/supabase/migrations/0048_create_tmdb_entities_and_watch_providers.sql` creates `core.tmdb_*` tables and policies.
  - `TRR-Backend/supabase/migrations/0049_rename_tmdb_dimension_tables.sql` renames them to `core.networks`, `core.production_companies`, and `core.watch_providers`.
- Existing evidence and rollout helpers:
  - `TRR-Backend/scripts/db/run_sql.sh`
  - `TRR-Backend/scripts/db/hot_path_explain/hot_path_explain.sql`
  - `docs/workspace/query-plan-evidence-runbook.md`
  - `docs/workspace/migration-ownership-policy.md`
  - `docs/workspace/supabase-capacity-budget.md`

## assumptions

1. The 2026-04-27 advisor snapshot is valid enough to plan from, but live policy/table names must be verified before DDL.
2. Broad Security Advisor remediation is out of scope, but the parallel safety hotfix gate is a prerequisite or same-time workstream for Phase 1 and must not wait behind index cleanup.
3. RLS changes must preserve current effective access by role and command.
4. Index drops are potentially destructive performance work and require explicit evidence and rollback.
5. Concurrent index DDL cannot run inside a normal transaction-wrapped migration.
6. Production operations settings such as Auth DB connection allocation remain gated by `docs/workspace/supabase-capacity-budget.md`.
7. Subagents may accelerate local implementation only when each has a disjoint file/surface ownership scope and the main session preserves phase gates, validates returned work, and performs final integration.

## goals

1. Resolve or materially reduce the seven `auth_rls_initplan` findings.
2. Collapse duplicate permissive policy combinations on hot tables without changing intended access behavior.
3. Preserve public SELECT behavior where it exists while keeping service-role writes service-role-only.
4. Build an unused-index evidence gate before any index retirement.
5. Retire confirmed-dead indexes in small, reversible batches.
6. Produce a before/after advisor closeout with measurable counts and named residual blockers.
7. Use multiple subagents for independent local workstreams without letting any subagent bypass the security, rollout, or advisor-recheck gates.

## non_goals

- No broad Security Advisor remediation in this plan, except the required parallel safety hotfix gate for `public.__migrations` and exposed `SECURITY DEFINER` RPC execution.
- No bulk index drops from the advisor list.
- No new TRR-APP shared-schema migrations.
- No Supabase compute upgrade decision.
- No Auth DB connection allocation change before the capacity evidence gate is complete.
- No intentional access-model change.
- No branch or worktree creation for subagent orchestration; all subagents work in the current checkout and must not revert edits made by other agents or the user.

## subagent_orchestration

Execution mode after approval: `orchestrate-subagents`.

The main session remains the orchestrator. It owns branch/preflight checks, the dependency map, integration review, final validation, and the decision to stop or proceed between waves. Subagents must receive bounded prompts with explicit ownership, out-of-scope items, validation commands, and the warning that they are not alone in the codebase and must not revert or overwrite edits by others.

Preflight before dispatch:

- Confirm current branch with `git branch --show-current`; stop if it is not `main` unless the user explicitly approves continuing.
- Run `git status --short` and classify existing dirty files as plan-owned, user-owned, or unrelated.
- Confirm the canonical plan path is `docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`.
- Confirm live DDL remains owner-controlled and no subagent is allowed to deploy production changes.
- Confirm Phase 2 live index report generation and all Phase 3 index drops are blocked until Phase 1 deploy verification and Performance Advisor recheck are complete.

Parallel workstream roster:

| Workstream | Subagent type | Ownership scope | May edit | Must not edit | Acceptance signal |
|---|---|---|---|---|---|
| Safety hotfix DDL | worker | `public.__migrations` lock-down and exposed `SECURITY DEFINER` execute grants | `TRR-Backend/supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql`, related rollout notes | RLS cleanup migration, app code, index tooling | Migration is idempotent where needed, skips missing `public.__migrations`, revokes only approved functions, grants `service_role`, and has verifier coverage. |
| RLS cleanup DDL and rollback | worker | Phase 1 RLS policy rewrite and rollback | `TRR-Backend/supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql`, `TRR-Backend/docs/db/advisor-performance/20260428111000_advisor_rls_policy_cleanup_rollback.sql` | Security hotfix migration, Phase 2 index tooling, TRR-APP migrations | Command-specific policies preserve public reads and service-role writes, legacy Firebase survey app policies are disabled, rollback restores Phase 0 policies by name. |
| Verifier and tests | worker | SQL verifier and artifact tests | `TRR-Backend/scripts/db/verify_advisor_remediation_phase1.sql`, `TRR-Backend/tests/db/test_advisor_remediation_sql.py` | Migrations except for review comments requested by orchestrator | Targeted pytest passes and verifier checks security hotfix, policy shape, grants, public reads, and disabled legacy Firebase survey policies. |
| Evidence and runbooks | worker | Phase evidence, rollout notes, dashboard/manual recheck docs | `docs/workspace/supabase-advisor-performance-phase0-evidence-2026-04-28.md`, `docs/workspace/supabase-advisor-performance-phase1-implementation-2026-04-28.md`, `TRR-Backend/docs/db/advisor-performance/20260428110000_20260428111000_phase1_rollout.md`, related workspace docs | DDL files, tests, app/backend runtime code | Docs state local-only vs live-deployed truth, owner-controlled rollout gate, advisor permission blocker, and exact post-deploy evidence required. |
| Phase 2 index evidence scaffolding | worker | Unused-index evidence tooling/report scaffolding only | index evidence scripts/reports under `TRR-Backend/scripts/db/` or `docs/workspace/` if missing or incomplete | Any `DROP INDEX`, `CREATE INDEX`, live report claim, or Phase 3 batch artifact | Produces review-only candidate inventory tooling/report structure that separates advisor-reported from approved-to-drop indexes. |
| Independent review | reviewer | Read-only risk review after workstreams return | Review comments only unless orchestrator explicitly assigns a narrow patch | All implementation files by default | Findings identify policy drift, rollback, security exposure, phase-gate, or test gaps before final integration. |

Parallelization waves:

1. **Wave 0 - Main-session preflight.** Read the plan, classify dirty worktree state, verify branch policy, and decide which existing local artifacts are in scope. No subagent starts before this is complete.
2. **Wave 1 - Independent local artifact work.** Dispatch Safety hotfix DDL, RLS cleanup/rollback, Verifier/tests, and Evidence/runbooks in parallel because their write scopes are disjoint. The main session stays available for blocker resolution and does not duplicate their work.
3. **Wave 2 - Phase 2 scaffolding.** Dispatch index evidence scaffolding only after the main session confirms Phase 1 local artifacts and gates remain intact. This work may prepare tooling but must not claim live report generation or drop approval.
4. **Wave 3 - Review and integration.** Dispatch an independent reviewer after Wave 1 or Wave 2 returns. The main session integrates accepted fixes, resolves conflicts, and runs the targeted validation suite.
5. **Wave 4 - Handoff.** Main session updates plan artifacts and handoff notes with final status, validations run, blocked checks, and remaining owner-controlled rollout requirements.

Orchestration stop rules:

- Stop all implementation subagents if the branch is not `main` and the user has not explicitly approved continuing.
- Stop a subagent if it needs to write outside its assigned scope.
- Stop Phase 2/Phase 3 work if Phase 1 deploy verification or immediate Performance Advisor recheck is missing.
- Stop live or destructive DB work in Codex; only owner-controlled deployment may apply DDL.
- Stop and reconcile if two subagents report overlapping edits to the same file.

Required subagent report format:

```md
STATUS: completed | blocked | needs-review
OWNERSHIP_SCOPE:
FILES_CHANGED:
VALIDATION_RUN:
ACCEPTANCE_CRITERIA_MET:
BLOCKERS_OR_RISKS:
NEXT_INTEGRATION_STEP:
```

## phased_implementation

### Phase 0 - Normalize Advisor Evidence And Live Object Names

Owner: workspace/backend.

Purpose: verify live state before writing DDL.

Tasks:

- Create a dated performance-only evidence note under `docs/workspace/`.
- Query `pg_policies` for:
  - `core.networks`
  - `core.production_companies`
  - `core.show_watch_providers`
  - `core.watch_providers`
  - `public.show_icons`
  - `public.flashback_quizzes`
  - `public.flashback_events`
  - `firebase_surveys.responses`
  - `firebase_surveys.answers`
- Capture policy name, permissive/restrictive mode, roles, command, `qual`, and `with_check`.
- Capture table grant state for all affected tables: `grantee`, `privilege_type`, and `is_grantable`.
- Capture current table owner, whether RLS is enabled, and whether `FORCE ROW LEVEL SECURITY` is enabled.
- Capture exact pre-change policy definitions by name so the Phase 1 rollback SQL can restore the before-state with explicit `drop policy if exists ...; create policy ...;` statements.
- Draft the before-state policy permission matrix for every affected table and role/context so Phase 1 has expected current behavior for `SELECT`, `INSERT`, `UPDATE`, and `DELETE`.
- Confirm live table names after the `0049` rename migration.
- Capture before-state `EXPLAIN` output for representative queries covering network/watch-provider reads, `show_icons`, flashback reads, and survey response/answer access.
- Try a fresh Performance Advisor capture if Supabase MCP permissions allow it. If permissions still fail, record the exact blocker and continue from the saved snapshot.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh -c "
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where (schemaname, tablename) in (
  ('core','networks'),
  ('core','production_companies'),
  ('core','show_watch_providers'),
  ('core','watch_providers'),
  ('public','show_icons'),
  ('public','flashback_quizzes'),
  ('public','flashback_events'),
  ('firebase_surveys','responses'),
  ('firebase_surveys','answers')
)
order by schemaname, tablename, cmd, policyname;"
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh -c "
select *
from information_schema.role_table_grants
where table_schema in ('core', 'public', 'firebase_surveys')
  and table_name in (
    'networks',
    'production_companies',
    'show_watch_providers',
    'watch_providers',
    'show_icons',
    'flashback_quizzes',
    'flashback_events',
    'responses',
    'answers'
  )
order by table_schema, table_name, grantee, privilege_type;"
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh -c "
select
  n.nspname as schema,
  c.relname as table,
  pg_get_userbyid(c.relowner) as owner,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where (n.nspname, c.relname) in (
  ('core','networks'),
  ('core','production_companies'),
  ('core','show_watch_providers'),
  ('core','watch_providers'),
  ('public','show_icons'),
  ('public','flashback_quizzes'),
  ('public','flashback_events'),
  ('firebase_surveys','responses'),
  ('firebase_surveys','answers')
);"
```

Stop rules:

- Stop if any table from the snapshot is missing in live schema.
- Stop if live policies differ materially from both the snapshot and repo migration history.
- Stop if Supabase advisor access reveals a newer snapshot that changes priority ordering.
- Stop if grant, owner, RLS-enabled, or FORCE RLS state cannot be captured for any target table.

Acceptance criteria:

- Live policy inventory exists.
- Live grant, owner, RLS-enabled, and FORCE RLS inventory exists.
- Before-state permission matrix expectations exist for every affected table/role/command combination.
- Before-state EXPLAIN evidence exists or a documented permission/data blocker exists.
- Execution knows the exact live policy names before Phase 1.

Commit boundary:

- Evidence/docs only.

### Parallel Safety Hotfix Gate - Before Or Alongside Phase 1

Owner: backend/security operator.

Purpose: prevent urgent Security Advisor exposure from waiting behind the longer performance/index plan.

Tasks:

- Create a separate security workstream/branch in the normal review flow before or alongside Phase 1.
- Lock down `public.__migrations` so RLS is enabled and the table is not exposed to normal anon/authenticated access.
- Revoke `anon` and `authenticated` `EXECUTE` from exposed `SECURITY DEFINER` RPCs unless each function is explicitly required for those roles and documented with owner approval.
- Document remaining `function_search_path_mutable` and `public.vector` work for the later full security pass.
- Keep this security DDL out of the performance migration unless there is no practical way to separate the rollout.

Stop rules:

- Stop Phase 2+ index work if this hotfix gate has not been executed or explicitly scheduled with an owner and date.
- Stop if the security branch/workstream would leave this session off `main`; current Codex execution must end on `main` per workspace instruction.

Acceptance criteria:

- `public.__migrations` exposure has a concrete hotfix path and owner before Phase 1 starts.
- Exposed `SECURITY DEFINER` RPC execution has revoke SQL or explicit role-by-role exception documentation before Phase 1 starts.
- Remaining search-path/vector findings are handed to the later full security pass and not silently forgotten.

Commit boundary:

- Separate security DDL/docs artifact, not mixed into the Phase 1 performance migration unless separation is impossible and documented.

### Phase 1 - Fix RLS Initplan And Duplicate Permissive Policy Cost

Owner: backend.

Purpose: remove duplicated/per-row RLS policy cost while preserving access semantics.

Tasks:

- Add one backend-owned migration under `TRR-Backend/supabase/migrations/`.
- For `core.networks`, `core.production_companies`, `core.watch_providers`, and `core.show_watch_providers`:
  - preserve the public `FOR SELECT USING (true)` policy if present.
  - drop/replace service-role `FOR ALL` policies that duplicate SELECT evaluation.
  - create service-role command-specific write policies with the exact PostgreSQL policy semantics below.
  - preserve or explicitly replace the existing `TO` roles. Do not rely on default `PUBLIC` unless the Phase 0 inventory proves that is intentionally equivalent.
- Apply the same command-specific write split to `public.show_icons` if live policy inventory confirms public read plus service-role all.
- For `public.flashback_quizzes` and `public.flashback_events`, only change policies that exist live. If service-role full-access policies are present, split them into command-specific service-role writes and wrap auth calls with `(select ...)`.
- For `firebase_surveys.responses` and `firebase_surveys.answers`, disable the legacy Firebase-authenticated app collection lane:
  - drop the Phase 0 owner/admin permissive policies by name.
  - do not create replacement `trr_app` policies.
  - keep rollback SQL capable of restoring the exact Phase 0 policies by name if the legacy lane must be temporarily re-enabled.
  - new survey collection should flow through the Supabase-auth `surveys.*` path, specifically `surveys.submit_response(uuid, jsonb)`.
- Do not convert owner policies to `RESTRICTIVE` in this pass unless access-semantics tests prove equivalence.
- Add comments in the migration stating that this is performance-only advisor remediation.

Command-specific policy DDL template:

```sql
-- INSERT
create policy <name> on <schema>.<table>
for insert
to <role>
with check ((select auth.role()) = 'service_role');

-- UPDATE
create policy <name> on <schema>.<table>
for update
to <role>
using ((select auth.role()) = 'service_role')
with check ((select auth.role()) = 'service_role');

-- DELETE
create policy <name> on <schema>.<table>
for delete
to <role>
using ((select auth.role()) = 'service_role');
```

Policy permission matrix required before and after Phase 1:

| Role/context | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `anon` | expected current behavior | expected current behavior | expected current behavior | expected current behavior |
| `authenticated` | expected current behavior | expected current behavior | expected current behavior | expected current behavior |
| `service_role` / backend role | expected current behavior | expected current behavior | expected current behavior | expected current behavior |
| legacy Firebase app owner context | blocked after disable | blocked after disable | blocked after disable | blocked after disable |
| legacy Firebase app admin context | blocked after disable | blocked after disable | blocked after disable | blocked after disable |

The matrix must be generated per affected table. It must include GRANT state, not just RLS policies, because table privileges are part of the effective access model. PostgreSQL combines permissive policies with `OR`, restrictive policies with `AND`, and command-specific policies can interact across `SELECT`, `INSERT`, `UPDATE`, and `DELETE`; do not infer equivalence from policy count alone.

Rollback requirement:

- A rollback migration or rollback SQL artifact must capture the exact pre-change policies from Phase 0 and restore them by name.
- Because normal policy DDL does not provide safe `CREATE OR REPLACE POLICY` semantics for this use, rollback must explicitly `drop policy if exists ...; create policy ...;` using the captured before-state.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/db/test_connection_resolution.py tests/api/test_startup_validation.py
PGAPPNAME=trr-hot-path-explain \
psql "$TRR_DB_URL" \
  -v explain_analyze=false \
  -v statement_timeout=8s \
  -f scripts/db/hot_path_explain/hot_path_explain.sql \
  -o /tmp/trr-hot-path-explain.txt
```

Add and run an RLS access-semantics test that compares the before/after permission matrix for every affected table and each role/context across `SELECT`, `INSERT`, `UPDATE`, and `DELETE`. Startup/connection tests are not sufficient proof of RLS equivalence.

Manual checks:

```sql
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where (schemaname, tablename) in (
  ('core','networks'),
  ('core','production_companies'),
  ('core','show_watch_providers'),
  ('core','watch_providers'),
  ('public','show_icons'),
  ('public','flashback_quizzes'),
  ('public','flashback_events'),
  ('firebase_surveys','responses'),
  ('firebase_surveys','answers')
)
order by schemaname, tablename, cmd, policyname;
```

Generate a diff between this Phase 1 after-state and the Phase 0 policy inventory. The diff must show that command coverage, role coverage, `qual`, and `with_check` changed only where expected.

Immediately after Phase 1 deployment, rerun Supabase Performance Advisor or manually verify the seven `auth_rls_initplan` findings are resolved before starting Phase 2. Do not start index work until the RLS performance fix is proven.

Stop rules:

- Stop if a proposed policy would make a write operation available to `anon`, `authenticated`, or `public` when it was service-role-only before.
- Stop if a public SELECT policy is accidentally removed from an existing public-read table.
- Stop if any `firebase_surveys.responses` or `firebase_surveys.answers` app RLS policy remains after the disable migration.
- Stop if the migration relies on a public SELECT policy for service-role read access but the live policy is not actually `TO public` or `TO service_role`.
- Stop if any INSERT policy incorrectly uses `USING` instead of `WITH CHECK`.
- Stop if any UPDATE policy lacks either `USING` or `WITH CHECK`.
- Stop if any DELETE policy lacks `USING`.
- Stop if the migration changes table GRANTs unless explicitly approved.
- Stop if `surveys.submit_response(uuid, jsonb)` is absent when the legacy Firebase survey lane is disabled.

Acceptance criteria:

- The seven `auth_rls_initplan` findings disappear or have named residual blockers after advisor recheck.
- Duplicate permissive policy combinations are removed for the targeted hot tables.
- Before/after `pg_policies` output proves command/role semantics are preserved.
- Before/after permission matrix tests prove access semantics for each affected table and role/context, including blocked legacy Firebase survey app access.
- Phase 1 rollback SQL restores the exact Phase 0 policies by name.
- No shared-schema migration is added under TRR-APP.

Commit boundary:

- One backend migration, one rollback SQL artifact, and evidence/docs updates.

### Phase 2 - Build Unused-Index Evidence Gate

Owner: backend/workspace.

Purpose: prevent blind index drops.

Tasks:

- Add or update a DB evidence script that exports candidate indexes with:
  - schema/table/index name
  - `pg_stat_user_indexes.idx_scan`
  - `idx_tup_read`
  - `idx_tup_fetch`
  - index size and table size
  - constraint backing status
  - recent migration source when discoverable
  - route/workload owner when known
  - advisor lint match
- Exclude primary keys, unique indexes, exclusion constraints, constraint-backed indexes, and recently created FK-hardening indexes by default.
- Produce a review report grouped by schema and workload:
  - social write-heavy candidates
  - core catalog/media candidates
  - public/survey candidates
  - admin candidates
  - ml/screenalytics candidates
- Require a 7-day recheck for production drop candidates unless the owner explicitly approves urgent removal.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh -c "
select schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from pg_stat_user_indexes
where schemaname in ('social','core','public','admin','ml','screenalytics','firebase_surveys','surveys','pipeline')
order by idx_scan asc, schemaname, relname, indexrelname;"
```

Stop rules:

- Stop if live stats are unavailable.
- Stop if an index is constraint-backed.
- Stop if the only evidence is advisor output.

Acceptance criteria:

- Generated report separates "advisor reported" from "approved to drop."
- Every approved candidate has owner, reason, rollback SQL, and evidence timestamp.

Commit boundary:

- Tooling/report only.

### Phase 3 - Retire Confirmed Dead Indexes In Batches

Owner: DB/operator with backend review.

Purpose: reduce write amplification only after Phase 2 proves safety.

Status: complete for the 2026-04-28 cycle. Three approved batches were executed and verified:

- Pipeline owner: `4` approved indexes dropped.
- Admin tooling owner: `12` approved indexes dropped.
- Survey/public flashback gameplay: `2` approved indexes dropped, followed by removal of the empty flashback gameplay write path.

The remaining `258` `drop_review_required` candidates are deferred by cycle decision. This is a deliberate closeout state, not approval to drop them. Future index retirement must reopen owner review and satisfy the same approval, rollback, EXPLAIN, advisor-recheck, and soak gates.

Tasks:

- Start with social write-heavy tables only after evidence review:
  - `social.twitter_tweets`
  - `social.facebook_posts`
  - `social.reddit_period_post_matches`
  - `social.tiktok_posts`
  - `social.youtube_videos`
  - `social.meta_threads_posts`
- Use `DROP INDEX CONCURRENTLY` for production-scale drops.
- Execute concurrent drops through a reviewed operator runbook or a script that runs one statement per transaction.
- Keep batches small:
  - Batch 1: 10-20 social indexes.
  - Batch 2: remaining confirmed social indexes.
  - Batch 3: confirmed core/media indexes.
  - Batch 4: public/admin/survey indexes.
  - Batch 5: ml/screenalytics only after workload owner approval.
- After each batch, rerun representative EXPLAIN checks and record a soak note.
- Recheck `pg_stat_user_indexes` after 7 days and again after 14 days for high-risk workloads.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh -c "select now(), count(*) from pg_stat_activity;"
PGAPPNAME=trr-hot-path-explain \
psql "$TRR_DB_URL" \
  -v explain_analyze=false \
  -v statement_timeout=8s \
  -f scripts/db/hot_path_explain/hot_path_explain.sql \
  -o /tmp/trr-hot-path-explain.txt
```

Stop rules:

- Stop if any route owner objects to a drop candidate.
- Stop if EXPLAIN shows a route relying on the candidate index.
- Stop if rollback SQL is missing.

Acceptance criteria:

- Each dropped index has batch ID, reason, evidence, owner, rollback SQL, and soak result.
- Advisor `unused_index` count decreases only for reviewed candidates.
- No route loses expected plan quality.
- Remaining unapproved candidates are recorded as deferred with owner and reason in the Phase 5 closeout.

Commit boundary:

- One index batch per operator artifact/commit.

### Phase 4 - Handle Lower-Priority Singleton Findings

Owner: backend/workspace/operator.

Purpose: close residual performance lints after hot work.

Status: complete on 2026-04-28. `core.external_id_conflicts` now has a surrogate primary key, and Supabase Auth DB allocation now uses `17 percent` instead of `10 connections`.

Tasks:

- `no_primary_key`:
  - inspect `core.external_id_conflicts` for row count and uniqueness.
  - add a surrogate identity primary key only if no better key exists.
  - validate inserts from `0073_backfill_external_ids.sql`.
- `auth_db_connections_absolute`:
  - keep under `docs/workspace/supabase-capacity-budget.md`.
  - change only after production capacity rows are filled and rollback owner is named.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api/test_startup_validation.py
./scripts/db/run_sql.sh -c "\\d+ core.external_id_conflicts"
```

Acceptance criteria:

- `core.external_id_conflicts` has a documented primary-key decision.
- Auth allocation has evidence, rollback target, and owner before any change.

Commit boundary:

- Separate commits/artifacts for primary key and Auth ops setting.

### Phase 5 - Advisor Recheck And Closeout

Owner: workspace.

Purpose: prove measurable improvement and document residual risk.

Status: complete on 2026-04-28. Closeout artifact: `docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`.

Tasks:

- Rerun Supabase Performance Advisor.
- Compare before/after counts for:
  - `auth_rls_initplan`
  - `multiple_permissive_policies`
  - `unused_index`
  - `no_primary_key`
  - `auth_db_connections_absolute`
- Add a closeout doc or closeout section to the dated advisor snapshot.
- Record deferred items with reason, owner, and next review date.
- Keep Security Advisor findings explicitly out of this closeout except for the handoff to the later safety plan.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
make preflight
```

Acceptance criteria:

- RLS performance lint counts are resolved or have named blockers.
- Index count reduction is evidence-backed, not bulk cleanup.
- The remaining unused-index candidates are intentionally deferred for a future owner-review cycle.
- Safety/security work is handed off separately.

Commit boundary:

- Closeout docs/evidence only.

## architecture_impact

- Backend remains source of truth for shared-schema DDL.
- TRR-APP does not gain new shared-schema migrations.
- RLS policy changes affect database execution cost for app direct-SQL and backend callers.
- Index cleanup affects write amplification, especially social backfill/control-plane tables.
- Auth allocation remains an operations setting outside normal migration flow.
- Subagent orchestration changes execution workflow only; it does not change database ownership, rollout authority, API shape, or app/backend contracts.

## data_or_api_impact

- No API shape changes are expected.
- Phase 1 changes policy implementation, not intended access semantics.
- Phase 3 changes query plans and write cost, not data shape.
- Phase 4 added a surrogate `id` primary key to `core.external_id_conflicts`; live smoke inserts and schema docs were checked after deployment.

## ux_admin_ops_considerations

- Operators should see less DB pressure from high-fan-out admin/catalog/survey reads after Phase 1.
- Index-drop batches should avoid peak ingest/backfill windows.
- Evidence artifacts must be redacted.
- Production DB operations need operator-facing rollout and rollback notes.

## validation_plan

Required checks:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
make preflight
```

Backend checks:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api/test_startup_validation.py tests/db/test_connection_resolution.py
PGAPPNAME=trr-hot-path-explain \
psql "$TRR_DB_URL" \
  -v explain_analyze=false \
  -v statement_timeout=8s \
  -f scripts/db/hot_path_explain/hot_path_explain.sql \
  -o /tmp/trr-hot-path-explain.txt
```

App checks if survey/flashback/direct-SQL behavior changes:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run -c vitest.config.ts --reporter=dot
```

Manual checks:

- `pg_policies` before/after for every affected table.
- GRANT, owner, RLS-enabled, and FORCE RLS inventory for every affected table.
- Per-table permission matrix tests for `anon`, `authenticated`, `service_role`/backend, app firebase owner, and app admin contexts across `SELECT`, `INSERT`, `UPDATE`, and `DELETE`.
- Generated diff between Phase 0 and Phase 1 `pg_policies` inventories.
- Representative EXPLAIN before/after.
- Supabase Performance Advisor immediately after Phase 1 and again at closeout.
- `pg_stat_user_indexes` before and after each index batch, plus 7-day and 14-day rechecks for production drops.

Orchestration checks:

- Main session records branch, dirty-worktree classification, subagents used, ownership scopes, validations run, blocked checks, and remaining risks before handoff.
- Each subagent reports files changed and validation run in the required report format.
- Main session verifies no subagent created branches/worktrees or edited outside its assigned scope.
- Main session reruns targeted validation after integrating subagent work instead of trusting subagent-local success alone.

## acceptance_criteria

- Phase 1 removes or explains all seven `auth_rls_initplan` findings.
- Phase 1 is not started until the parallel safety hotfix gate is executed or has an explicit owner/date.
- Duplicate permissive policy combinations on hot tables are collapsed or split without access drift.
- `firebase_surveys.responses` and `firebase_surveys.answers` have no active app RLS policies after disable.
- `surveys.submit_response(uuid, jsonb)` remains available for Supabase-auth survey collection.
- RLS rollback SQL can restore the exact Phase 0 policy state by name.
- No new shared-schema migration appears under TRR-APP.
- No index is dropped without live evidence, route review, rollback SQL, owner, and soak note.
- Performance Advisor recheck records before/after counts.
- Security hotfix findings are handled through the parallel gate; remaining lower-priority security findings are deferred to the later full safety pass.
- Subagent implementation uses disjoint ownership scopes, preserves phase gates, and ends with main-session integration and validation.

## risks_edge_cases_open_questions

- Live object names may differ from migration history.
- RLS policy rewrites can accidentally change access semantics because GRANTs, permissive/restrictive policy combination, command-specific policy rules, and old/new row checks all contribute to effective access.
- `idx_scan = 0` may reflect stats reset or dormant seasonal workloads.
- Social index drops can improve writes but hurt rare admin filters.
- Supabase MCP access may remain permission-blocked; Dashboard/manual capture may be required.
- Subagent speed can create false confidence if ownership scopes overlap or if the main session skips final integration validation.

## follow_up_improvements

- Write the later full Safety Advisor plan for remaining search-path/vector/security posture work after the hotfix gate is handled.
- Add an advisor-diff helper.
- Add reusable RLS policy semantics tests.
- Add a "do not drop" index registry.
- Add route-owner labels to index review reports.

## recommended_next_step_after_approval

No further execution is approved for this remediation cycle. Phase 1, Phase 2, the approved Phase 3 batches, Phase 4, and Phase 5 closeout are complete. A future cycle may reopen owner-review packets, but additional Phase 3 index drops remain blocked until packet rows are explicitly approved with owner, rollback, and soak/recheck evidence.

Implementation note: the legacy `firebase_surveys` app policy lane is intentionally disabled instead of behaviorally preserved. Survey collection should move through the Supabase-auth `surveys.*` path, and the rollback SQL remains the emergency path for temporarily restoring the old Firebase policies by name.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

## ready_for_execution

Closed for the 2026-04-28 remediation cycle. Phase 1 live DDL is deployed and verified. The corrected Phase 2 live unused-index report and owner packets are generated. Phase 3 pipeline-owner, admin-tooling, and flashback gameplay batches are complete. Phase 5 closeout is recorded in `docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`; further Phase 3 index work remains blocked until a future cycle reopens owner review.
