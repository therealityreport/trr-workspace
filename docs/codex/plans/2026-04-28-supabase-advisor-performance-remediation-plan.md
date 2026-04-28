# TRR Supabase Advisor Performance Remediation Plan

Date: 2026-04-28
Snapshot analyzed: `docs/workspace/supabase-advisor-snapshot-2026-04-27.md`
Status: complete for the 2026-04-28 remediation cycle. Phase 1 and Phase 4 live DDL/config changes are deployed and verified. Supabase Advisor recheck passed with `TRR_SUPABASE_ACCESS_TOKEN`. The stray non-TRR `thb_bbl` schema from the original snapshot was removed from the TRR Supabase project on 2026-04-28. The corrected Phase 2 unused-index report and owner-specific review packets are generated. Phase 3 completed the approved drop scope: four pipeline-owner indexes, twelve admin-tooling indexes, and two flashback gameplay indexes dropped; empty flashback gameplay tables/RPC helpers were also removed and preserved in migration `20260428113000_remove_flashback_gameplay_write_path.sql`. Phase 5 closeout is recorded in `docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`. Advisor now reports only `unused_index=350`.
Cycle decision: do not continue the remaining owner review in this cycle. The remaining `258` `drop_review_required` candidates are explicitly deferred. Do not run additional Phase 3 index drops unless a future cycle reopens owner review from `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/` and each packet row has explicit owner approval, rollback SQL, and soak/recheck evidence.

Full unused-index decision-review update: a non-destructive full-review guardrail pass now exists for the current `1,302`-row CSV universe at `docs/workspace/unused-index-decision-matrix-2026-04-28.csv` and `docs/workspace/unused-index-decision-matrix-2026-04-28.md`. The original owner-requested `1,324` row universe remains documented as an unresolved historical mismatch, but the checked-in CSV currently contains `777` excluded rows, `267` nonzero-usage rows, and `258` `drop_review_required` rows. The current full-review matrix approves `0` rows for dropping; every row remains `approved_to_drop=no`. Required guardrails are now `TRR-Backend/scripts/db/validate_unused_index_decision_matrix.py`, `TRR-Backend/scripts/db/scan_no_destructive_sql.py`, `docs/workspace/unused-index-stats-window-2026-04-28.json`, and `docs/workspace/social-hashtag-leaderboard-architecture-2026-04-28.md`. Social hashtag/search indexes remain blocked until the architecture stub is resolved or each index is proven unrelated. Optional post-review Advisor delta evidence was attempted and recorded at `docs/workspace/supabase-advisor-post-review-delta-2026-04-28.md`; the Management API request returned HTTP `404`, so this non-destructive closeout does not depend on it.

## summary

This plan addresses the Supabase Performance Advisor findings from the 2026-04-27 `trr-core` snapshot while treating the most urgent Security Advisor items as a parallel hotfix gate. Performance work must not defer `public.__migrations` RLS exposure or exposed `SECURITY DEFINER` RPC execution until after index cleanup.

The highest-value performance work is not a broad index drop. It is a backend-owned RLS policy cleanup on a small set of high-fan-out tables where Supabase reports both `auth_rls_initplan` and `multiple_permissive_policies`. After that, unused-index cleanup should be evidence-gated and batched because the remaining findings include hot TRR social/core schemas and indexes that may be intentionally retained for write integrity, future query shapes, or FK protection.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`

## canonical_execution_source

This file under `/Users/thomashulihan/Projects/TRR/docs/codex/plans/` is the canonical execution plan. Any `.plan-grader` copy is temporary evidence only and must not be used as the source of truth after this file is updated.

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Source snapshot: `docs/workspace/supabase-advisor-snapshot-2026-04-27.md`
- Supabase project in snapshot: `trr-core` (`vwxfvzutyufrkhfgoeaa`), Postgres `17.6.1.062`, region `us-east-1`.
- Original Performance Advisor totals from the source snapshot: `532` findings: `98` WARN and `434` INFO.
- Current Performance Advisor counts after Phase 1, stray schema removal, Phase 4, and the approved Phase 3 pipeline/admin/flashback batches:
  - `unused_index`: `350`
  - `multiple_permissive_policies`: `0`
  - `unindexed_foreign_keys`: `0`
  - `auth_rls_initplan`: `0`
  - `no_primary_key`: `0`
  - `auth_db_connections_absolute`: `0`
  - total lints: `350`
- Existing contract: shared-schema changes belong in `TRR-Backend/supabase/migrations`, not new app-owned migrations.
- Existing evidence tooling:
  - `TRR-Backend/scripts/db/run_sql.sh`
  - `TRR-Backend/scripts/db/hot_path_explain/hot_path_explain.sql`
  - `docs/workspace/query-plan-evidence-runbook.md`
  - `docs/workspace/migration-ownership-policy.md`
  - `docs/workspace/supabase-capacity-budget.md`
- Supabase documentation supports the core policy optimization: wrapping stable auth/helper functions in `select` lets Postgres cache the value per statement instead of evaluating per row. Supabase also warns that indexes improve reads but add write/storage overhead, so unused-index cleanup must be verified against real query and write patterns.

## assumptions

1. The snapshot is a real production/project advisor capture and is the planning source of truth for this pass.
2. Broad Security Advisor remediation is out of scope, but the parallel safety hotfix gate is a prerequisite or same-time workstream for Phase 1 and must not wait behind index cleanup.
3. Backend-first sequencing applies because the affected TRR tables live in shared schemas: `core`, `public`, `firebase_surveys`, `surveys`, `social`, `admin`, `ml`, `screenalytics`, and `pipeline`.
4. Any policy rewrite must preserve current effective access semantics. Performance cleanup must not silently expand or remove access.
5. `unused_index` does not mean "safe to drop now." Drops require corroborating `pg_stat_user_indexes`, migration-history checks, hot-path query evidence, and a rollback plan.
6. `DROP INDEX CONCURRENTLY` and `CREATE INDEX CONCURRENTLY` cannot run inside a transaction, so concurrent index changes require a dedicated rollout script/runbook rather than a normal transaction-wrapped migration.
7. Subagents may accelerate local implementation only when each has a disjoint file/surface ownership scope and the main session preserves phase gates, validates returned work, and performs final integration.

## goals

1. Remove the high-fan-out RLS per-row auth cost from the seven `auth_rls_initplan` findings.
2. Collapse or split duplicate permissive policy combinations on the same hot tables so each row evaluates fewer policies.
3. Preserve current access behavior while improving policy execution cost.
4. Complete the evidence-backed unused-index retirement workflow for this cycle without bulk-dropping unreviewed indexes.
5. Reduce write amplification on approved pipeline, admin-tooling, and flashback gameplay paths by retiring confirmed-dead indexes in safe batches.
6. Close the low-risk singletons only after the high-fan-out RLS work and index evidence pass are underway.
7. Use multiple subagents for independent local workstreams without letting any subagent bypass the security, rollout, or advisor-recheck gates.

## non_goals

- No broad Security Advisor remediation in this phase, except the required parallel safety hotfix gate for `public.__migrations` and exposed `SECURITY DEFINER` RPC execution.
- No bulk `DROP INDEX` from the advisor list.
- No app-owned migrations for shared schemas.
- No production Supavisor/Auth connection-setting change without the existing capacity evidence gate.
- No changes to public read/write semantics as a side effect of performance policy cleanup.
- No Supabase compute upgrade decision from this advisor snapshot alone.
- No branch or worktree creation for subagent orchestration; all subagents work in the current checkout and must not revert edits made by other agents or the user.

## subagent_orchestration

Execution mode after approval: `orchestrate-subagents`.

The main session remains the orchestrator. It owns branch/preflight checks, the dependency map, integration review, final validation, and the decision to stop or proceed between waves. Subagents must receive bounded prompts with explicit ownership, out-of-scope items, validation commands, and the warning that they are not alone in the codebase and must not revert or overwrite edits by others.

Preflight before dispatch:

- Confirm current branch with `git branch --show-current`; stop if it is not `main` unless the user explicitly approves continuing.
- Run `git status --short` and classify existing dirty files as plan-owned, user-owned, or unrelated.
- Confirm this file remains the canonical execution plan.
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

Purpose: turn the snapshot into an execution inventory that matches live schema names, current migrations, and current policy definitions.

Concrete changes:

- Add a dated execution note under `docs/workspace/supabase-advisor-snapshot-2026-04-27.md` or a sibling evidence file that records this performance-only scope.
- Query `pg_policies` for the affected tables and store a redacted policy inventory:
  - `core.networks`
  - `core.production_companies`
  - `core.show_watch_providers`
  - `core.watch_providers`
  - `public.show_icons`
  - `public.flashback_quizzes`
  - `public.flashback_events`
  - `firebase_surveys.responses`
  - `firebase_surveys.answers`
- Capture table grant state for all affected tables: `grantee`, `privilege_type`, and `is_grantable`.
- Capture current table owner, whether RLS is enabled, and whether `FORCE ROW LEVEL SECURITY` is enabled.
- Capture exact pre-change policy definitions by name so the Phase 1 rollback SQL can restore the before-state with explicit `drop policy if exists ...; create policy ...;` statements.
- Draft the before-state policy permission matrix for every affected table and role/context so Phase 1 has expected current behavior for `SELECT`, `INSERT`, `UPDATE`, and `DELETE`.
- Confirm renamed table lineage from old migrations:
  - `core.tmdb_networks` -> `core.networks`
  - `core.tmdb_production_companies` -> `core.production_companies`
  - `core.tmdb_watch_providers` -> `core.watch_providers`
- Capture before-state query plans for representative reads/writes:
  - network/watch-provider admin reads
  - show watch-provider reads
  - app shell `show_icons` reads
  - flashback quiz/event reads
  - survey response and answer reads/writes
- Capture a fresh performance advisor run after inventory if access is available; if not, record the permission blocker and continue from the saved snapshot.

Affected files/surfaces:

- `docs/workspace/supabase-advisor-snapshot-2026-04-27.md`
- `docs/workspace/query-plan-evidence-runbook.md`
- `TRR-Backend/scripts/db/hot_path_explain/hot_path_explain.sql`
- Optional new evidence artifact under `docs/workspace/`

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

- Live table names and policy names are confirmed before any migration is written.
- Live grant, owner, RLS-enabled, and FORCE RLS inventory exists.
- Before-state permission matrix expectations exist for every affected table/role/command combination.
- Before-state evidence exists for each hot policy group.
- Any mismatch between advisor object names and repo migration names is documented, not guessed around.

Commit boundary:

- Evidence/docs only.

### Parallel Safety Hotfix Gate - Before Or Alongside Phase 1

Purpose: prevent urgent Security Advisor exposure from waiting behind the longer performance/index plan.

Concrete changes:

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

Purpose: land the highest-leverage performance fix first with backend-owned DDL.

Concrete changes:

- Create one backend-owned migration under `TRR-Backend/supabase/migrations/`.
- For the renamed TMDB/catalog tables, preserve public SELECT behavior while removing the duplicate service-role SELECT evaluation:
  - keep or recreate the public read policy as `FOR SELECT USING (true)` for the existing public-read surface.
  - replace each `FOR ALL USING (auth.role() = 'service_role') WITH CHECK (...)` policy with command-specific service-role write policies for `INSERT`, `UPDATE`, and `DELETE` using the exact PostgreSQL policy semantics below.
  - preserve or explicitly replace the existing `TO` roles. Do not rely on default `PUBLIC` unless the Phase 0 inventory proves that is intentionally equivalent.
  - affected tables: `core.networks`, `core.production_companies`, `core.watch_providers`, `core.show_watch_providers`.
- Apply the same shape to `public.show_icons` if it has both public read and service-role all policies.
- For `public.flashback_quizzes` and `public.flashback_events`, inspect live policies first. If the live database has service-role full-access policies not visible in the current migration history, split those into command-specific write policies and wrap auth calls in `(select ...)`.
- For `firebase_surveys.responses` and `firebase_surveys.answers`, disable the legacy Firebase-authenticated app collection lane:
  - drop the Phase 0 owner/admin permissive policies by name.
  - do not create replacement `trr_app` policies.
  - keep rollback SQL capable of restoring the exact Phase 0 policies by name if the legacy lane must be temporarily re-enabled.
  - new survey collection should flow through the Supabase-auth `surveys.*` path, specifically `surveys.submit_response(uuid, jsonb)`.
- Add comments in the migration explaining the service-role policy split and the intentional legacy Firebase survey disable.

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

Affected files/surfaces:

- `TRR-Backend/supabase/migrations/<timestamp>_advisor_performance_policy_cleanup.sql`
- `TRR-APP/apps/web/db/migrations/016_create_rls_policies.sql` remains historical; do not edit it for this shared-schema fix unless the app migration allowlist requires a note.
- `docs/workspace/migration-ownership-policy.md`
- `docs/workspace/app-migration-ownership-allowlist.txt` if the legacy app policy file needs a documented ownership note.

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

Manual SQL checks:

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
- Stop if the migration relies on a public SELECT policy for service-role read access but the live policy is not actually `TO public` or `TO service_role`.
- Stop if any INSERT policy incorrectly uses `USING` instead of `WITH CHECK`.
- Stop if any UPDATE policy lacks either `USING` or `WITH CHECK`.
- Stop if any DELETE policy lacks `USING`.
- Stop if the migration changes table GRANTs unless explicitly approved.
- Stop if any `firebase_surveys.responses` or `firebase_surveys.answers` app RLS policy remains after the disable migration.
- Stop if `surveys.submit_response(uuid, jsonb)` is absent when the legacy Firebase survey lane is disabled.

Expected result:

- The seven `auth_rls_initplan` findings disappear or shrink after the next advisor run.
- Duplicate permissive SELECT combinations disappear for the hot catalog/public-read tables.
- `firebase_surveys.responses` and `firebase_surveys.answers` no longer have separate owner/admin permissive policies for the same role/action combinations.
- Existing app/admin survey and flashback flows still pass.

Acceptance criteria:

- Policy count and policy text prove fewer duplicate evaluations.
- Query plans for representative reads/writes show auth/helper functions as initplans rather than per-row calls.
- Before/after permission matrix tests prove access semantics for each affected table and role/context.
- Phase 1 rollback SQL restores the exact Phase 0 policies by name.
- No access behavior is intentionally changed.
- Migration is backend-owned.

Commit boundary:

- One backend migration, one rollback SQL artifact, and focused docs/test updates.

### Phase 2 - Build Unused-Index Evidence Gate

Purpose: make unused-index cleanup auditable before dropping anything.

Concrete changes:

- Add a backend script or SQL file that exports candidate indexes by schema/table/index with:
  - advisor lint presence
  - `pg_stat_user_indexes.idx_scan`
  - `idx_tup_read`
  - `idx_tup_fetch`
  - index size
  - table size
  - last known DDL/migration source when discoverable from repo search
  - whether the index backs a constraint
  - whether a matching FK or hot-path read still needs it
- Include a guard that excludes:
  - primary keys
  - unique indexes
  - exclusion constraints
  - indexes used by constraints
  - indexes created in the last 14 days unless explicitly approved
  - FK-protection indexes from the April 2026 FK hardening waves unless a route owner approves removal
- Add a generated review report under `docs/workspace/` with grouped candidates:
  - social write-heavy candidates
  - core catalog/media candidates
  - public/survey candidates
  - admin candidates
  - ml/screenalytics candidates
- Update `docs/workspace/query-plan-evidence-runbook.md` with the rule that new index additions and index removals both require route/query evidence.

Affected files/surfaces:

- `TRR-Backend/scripts/db/`
- `docs/workspace/query-plan-evidence-runbook.md`
- Optional new `docs/workspace/unused-index-advisor-review-2026-04-27.md`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh -c "
select schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from pg_stat_user_indexes
where schemaname in ('social','core','public','admin','ml','screenalytics','firebase_surveys','surveys','pipeline')
order by idx_scan asc, schemaname, relname, indexrelname;"
```

Acceptance criteria:

- No index drop list can be generated without live stats.
- The report separates "advisor says unused" from "approved to drop."
- Every approved candidate has a rollback statement and an owner.

Commit boundary:

- Tooling and evidence report only.

### Phase 3 - Retire Confirmed Dead Indexes In Batches

Purpose: reduce write amplification after Phase 2 proves which indexes are actually dead.

Status: complete for the 2026-04-28 cycle. Three approved batches were executed and verified:

- Pipeline owner: `4` approved indexes dropped.
- Admin tooling owner: `12` approved indexes dropped.
- Survey/public flashback gameplay: `2` approved indexes dropped, followed by removal of the empty flashback gameplay write path.

The remaining `258` `drop_review_required` candidates are deferred by cycle decision. This is a deliberate closeout state, not approval to drop them. Future index retirement must reopen owner review and satisfy the same approval, rollback, EXPLAIN, advisor-recheck, and soak gates.

Concrete changes:

- Start with the highest write-amplification / lowest read-risk groups:
  - `social.twitter_tweets`
  - `social.facebook_posts`
  - `social.reddit_period_post_matches`
  - `social.tiktok_posts`
  - `social.youtube_videos`
  - `social.meta_threads_posts`
- Do not drop indexes that correspond to current hot-path read plans, FK protection, uniqueness, or route-level ordering.
- Use `DROP INDEX CONCURRENTLY` for production-scale drops.
- Because concurrent drops cannot run inside a transaction, implement rollout as either:
  - a reviewed SQL runbook executed statement-by-statement through the approved DB operator path, or
  - a dedicated script that runs one statement per transaction and records success/failure.
- Keep batches small:
  - Batch 1: 10-20 social indexes maximum.
  - Batch 2: remaining confirmed social indexes.
  - Batch 3: confirmed core/media indexes.
  - Batch 4: public/admin/survey indexes.
  - Batch 5: ml/screenalytics only after workload owner approval.
- After each batch, rerun representative hot-path `EXPLAIN` and watch write/backfill behavior.

Affected files/surfaces:

- `TRR-Backend/docs/db/` or `docs/workspace/` rollout artifacts.
- Optional `TRR-Backend/scripts/db/drop_unused_indexes_<wave>.sql` if implemented as an operator-run script, not a normal transaction-wrapped migration.
- `TRR-Backend/supabase/schema_docs/` if schema docs are regenerated after rollout.

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

Expected result:

- Advisor `unused_index` count decreases only for reviewed candidates.
- Insert/update-heavy social backfill paths perform less index maintenance.
- No route loses an expected index-only or ordered index plan.

Acceptance criteria:

- Each dropped index has a recorded reason, live-stat evidence, rollback SQL, and batch ID.
- No batch mixes unrelated schemas without an owner.
- Each batch has a post-drop soak note.
- Remaining unapproved candidates are recorded as deferred with owner and reason in the Phase 5 closeout.

Commit boundary:

- One batch per commit or operator artifact.

### Phase 4 - Handle Lower-Priority Singleton Findings

Purpose: close the remaining performance lints after hot-path work.

Status: complete on 2026-04-28. `core.external_id_conflicts` now has a surrogate primary key, and Supabase Auth DB allocation now uses `17 percent` instead of `10 connections`.

Concrete changes:

- `no_primary_key`:
  - inspect `core.external_id_conflicts` for existing uniqueness and row count.
  - add a surrogate identity primary key only if no better business key exists.
  - validate inserts from `0073_backfill_external_ids.sql` and any current conflict readers still work.
- `auth_db_connections_absolute`:
  - treat as an operations setting under the existing capacity-budget evidence gate.
  - switch Auth DB allocation from an absolute count to percentage only after the production capacity table is filled.

Affected files/surfaces:

- `TRR-Backend/supabase/migrations/`
- `docs/workspace/supabase-capacity-budget.md`
- `docs/workspace/production-supabase-connection-inventory.md`
- `TRR-Backend/supabase/schema_docs/core.external_id_conflicts.md`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest tests/api/test_startup_validation.py
./scripts/db/run_sql.sh -c "\\d+ core.external_id_conflicts"
```

Acceptance criteria:

- `core.external_id_conflicts` has a documented primary-key decision.
- Auth connection setting is changed only with capacity evidence and rollback notes.

Commit boundary:

- Separate commits for `external_id_conflicts` primary key and Auth operations documentation.

### Phase 5 - Advisor Recheck And Closeout

Purpose: prove the performance advisor count changed and document residual risk.

Status: complete on 2026-04-28. Closeout artifact: `docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`.

Concrete changes:

- Rerun Supabase Performance Advisor.
- Compare before/after counts:
  - `auth_rls_initplan`
  - `multiple_permissive_policies`
  - `unused_index`
  - `no_primary_key`
  - `auth_db_connections_absolute`
- Add a closeout section to the advisor snapshot or a new dated closeout doc.
- Record all deferred items with reason and owner.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
make preflight
```

Acceptance criteria:

- The high-fan-out RLS performance lints are resolved or each residual has a named blocker.
- Unused-index cleanup has reduced only approved dead indexes, not blindly followed the advisor.
- The remaining unused-index candidates are intentionally deferred for a future owner-review cycle.
- Remaining security-only findings are explicitly left for the later safety plan.

Commit boundary:

- Closeout docs and evidence only.

## architecture_impact

- Backend remains the owner of shared-schema performance DDL.
- TRR-APP should not add new app migrations for `core`, `public`, `firebase_surveys`, `social`, or `admin` as part of this plan.
- RLS policy cleanup affects database execution cost for both backend and app direct-SQL callers, especially Vercel/serverless paths that multiply per-row overhead under concurrency.
- Unused-index cleanup primarily affects write amplification and storage, especially social backfill/control-plane tables.
- Operations-only Auth connection allocation remains tied to the existing Supabase capacity budget rather than this migration plan.
- Subagent orchestration changes execution workflow only; it does not change database ownership, rollout authority, API shape, or app/backend contracts.

## data_or_api_impact

- Data shape should not change in Phase 1.
- Policy count and policy expressions change, but intended access semantics should remain stable.
- No API contract changes are expected for the RLS performance migration.
- Index drops can affect query plans but not data contracts.
- `core.external_id_conflicts` gained a surrogate `id` primary key in Phase 4; smoke inserts and schema docs were checked after deployment.

## ux_admin_ops_considerations

- Admin users should see faster and less failure-prone pages indirectly when high-fan-out catalog/watch-provider/icon/survey queries stop paying duplicated RLS cost.
- Operator evidence must be redacted. Do not write DB URLs, JWTs, or secrets into advisor closeout docs.
- Index-drop batches should avoid peak import/backfill windows.
- Production DB operations should be announced as separate operator events if they use concurrent DDL or dashboard-only settings.

## validation_plan

Automated checks:

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

App checks, if survey/flashback/admin direct-SQL behavior is touched:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run -c vitest.config.ts --reporter=dot
```

Manual checks:

- Capture `pg_policies` before/after for all affected tables.
- Capture GRANT, owner, RLS-enabled, and FORCE RLS inventory for every affected table.
- Run per-table permission matrix tests for `anon`, `authenticated`, `service_role`/backend, and disabled legacy Firebase app contexts across `SELECT`, `INSERT`, `UPDATE`, and `DELETE`.
- Generate a diff between Phase 0 and Phase 1 `pg_policies` inventories.
- Compare representative `EXPLAIN` output before/after.
- Rerun Supabase Performance Advisor immediately after Phase 1 and again at closeout.
- For index batches, capture `pg_stat_user_indexes` before drop, immediately after drop, and after soak.

Orchestration checks:

- Main session records branch, dirty-worktree classification, subagents used, ownership scopes, validations run, blocked checks, and remaining risks before handoff.
- Each subagent reports files changed and validation run in the required report format.
- Main session verifies no subagent created branches/worktrees or edited outside its assigned scope.
- Main session reruns targeted validation after integrating subagent work instead of trusting subagent-local success alone.

## acceptance_criteria

- A new backend migration removes the seven high-priority RLS initplan problems without changing intended access behavior.
- Phase 1 is not started until the parallel safety hotfix gate is executed or has an explicit owner/date.
- Duplicate permissive policy combinations on the hot tables are collapsed or split so SELECT rows evaluate fewer policies.
- `firebase_surveys.responses` and `firebase_surveys.answers` have no active app RLS policies after disable.
- `surveys.submit_response(uuid, jsonb)` remains available for Supabase-auth survey collection.
- RLS rollback SQL can restore the exact Phase 0 policy state by name.
- No shared-schema migration is added under TRR-APP.
- No unused index is dropped without live-stat evidence, route/hot-path review, rollback SQL, and batch ownership.
- Performance Advisor recheck shows reduced `auth_rls_initplan` / `multiple_permissive_policies` counts or records a precise blocker.
- Security hotfix findings are handled through the parallel gate; remaining lower-priority security findings are deferred to the later full safety pass.
- Subagent implementation uses disjoint ownership scopes, preserves phase gates, and ends with main-session integration and validation.

## risks_edge_cases_open_questions

- The snapshot object names and migration-history names differ for TMDB tables because the tables were renamed. Live schema verification is mandatory before writing DDL.
- Public-read plus service-role write policies must be split carefully. A naive combined `USING (true OR ...)` SELECT policy may remove the duplicate SELECT lint but does not preserve write semantics by itself.
- RLS policy rewrites can accidentally change access semantics because GRANTs, permissive/restrictive policy combination, command-specific policy rules, and old/new row checks all contribute to effective access.
- App historical migration `016_create_rls_policies.sql` may continue to confuse ownership unless the backend migration and allowlist clearly explain the current owner.
- The legacy Firebase survey RLS path is intentionally disabled rather than preserved; survey collection should use the Supabase-auth `surveys.*` path.
- `unused_index` may include indexes that are unused only because the stats window reset recently or the relevant workload has not run.
- Dropping social indexes can improve writes but hurt admin investigation pages if a rare filter depends on them.
- Subagent speed can create false confidence if ownership scopes overlap or if the main session skips final integration validation.

## follow_up_improvements

- Write the later full Safety Advisor plan for remaining search-path/vector/security posture work after the hotfix gate is handled.
- Add a reusable advisor-diff script that compares saved snapshots and current advisor output.
- Add route-labeled query-plan fixtures for the exact tables in the RLS performance migration.
- Consider a dashboard card that shows last advisor capture date and unresolved performance lint counts.
- Revisit Supabase Auth connection allocation only after the capacity-budget production table is complete.

## recommended_next_step_after_approval

No further execution is approved for this remediation cycle. Phase 1, Phase 2, the approved Phase 3 batches, Phase 4, and Phase 5 closeout are complete. A future cycle may reopen owner-review packets, but additional Phase 3 index drops remain blocked until packet rows are explicitly approved with owner, rollback, and soak/recheck evidence.

Implementation note: the legacy `firebase_surveys` app policy lane is intentionally disabled instead of behaviorally preserved. Survey collection should move through the Supabase-auth `surveys.*` path, and the rollback SQL remains the emergency path for temporarily restoring the old Firebase policies by name.

## ready_for_execution

Closed for the 2026-04-28 remediation cycle. Phase 1 live DDL is deployed and verified. The corrected Phase 2 live unused-index report and owner packets are generated. Phase 3 pipeline-owner, admin-tooling, and flashback gameplay batches are complete. Phase 5 closeout is recorded in `docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`; further Phase 3 index work remains blocked until a future cycle reopens owner review.
