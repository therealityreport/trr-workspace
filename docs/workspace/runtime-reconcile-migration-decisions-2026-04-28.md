# Runtime Reconcile Migration Decisions - 2026-04-28

Direct DB identity must pass before any apply or history repair action:

- project ref: `vwxfvzutyufrkhfgoeaa`
- host: `db.vwxfvzutyufrkhfgoeaa.supabase.co`
- database: `postgres`
- server version: visible in reconcile `db_identity.server_version`
- current database: visible in reconcile `db_identity.database`
- current user: visible in reconcile `db_identity.current_user`

Do not paste or store the direct DB URL in this file.

Latest inspection and repair: `make preflight` on 2026-04-28 reached runtime reconcile, validated the direct DB identity above, and blocked with `pending_not_allowlisted`. A follow-up read-only direct inspection found all five migration versions missing from `supabase_migrations.schema_migrations` while their expected live-state signals were already present. Each version was then repaired in migration history one at a time, with reconcile rerun after each repair.

## Pending Decisions

### 20260427140000_quarantine_typography_runtime_ddl.sql

- migration file: `TRR-Backend/supabase/migrations/20260427140000_quarantine_typography_runtime_ddl.sql`
- live-state verdict: already_applied
- action: repair_history
- rollback or forward-fix note: no rollback planned; repair history only after owner confirms the live typography tables/function/triggers are the intended durable state.
- owner evidence: migration history missing; live DB has `public.site_typography_sets`, `public.site_typography_assignments`, `public.set_site_typography_updated_at()`, and both updated-at triggers.
- post-action reconcile result: blocked; remaining pending versions were `20260428110000`, `20260428111000`, `20260428112000`, `20260428113000`

### 20260428110000_security_hotfix_public_migrations_rpc_exec.sql

- migration file: `TRR-Backend/supabase/migrations/20260428110000_security_hotfix_public_migrations_rpc_exec.sql`
- live-state verdict: already_applied
- action: repair_history
- rollback or forward-fix note: no rollback planned; repair history only after owner confirms the SECURITY DEFINER RPC access changes are intended.
- owner evidence: migration history missing; live DB has `public.__migrations_no_api_access`, no anon/authenticated execute grants on the eight checked RPC functions, and service-role execute remains present.
- post-action reconcile result: blocked; remaining pending versions were `20260428111000`, `20260428112000`, `20260428113000`

### 20260428111000_advisor_rls_policy_cleanup.sql

- migration file: `TRR-Backend/supabase/migrations/20260428111000_advisor_rls_policy_cleanup.sql`
- live-state verdict: already_applied
- action: repair_history
- rollback or forward-fix note: no rollback planned; repair history only after owner confirms the advisor RLS cleanup matrix.
- owner evidence: migration history missing; live DB has 21 expected replacement service-role policies, zero checked legacy broad service-role policies, and zero checked legacy firebase survey policies.
- post-action reconcile result: blocked; remaining pending versions were `20260428112000`, `20260428113000`

### 20260428112000_advisor_external_id_conflicts_primary_key.sql

- migration file: `TRR-Backend/supabase/migrations/20260428112000_advisor_external_id_conflicts_primary_key.sql`
- live-state verdict: already_applied
- action: repair_history
- rollback or forward-fix note: no rollback planned; repair history only after owner confirms `core.external_id_conflicts.id` is the intended primary key.
- owner evidence: migration history missing; live DB has `core.external_id_conflicts.id`, `not null`, `gen_random_uuid()` default, and `external_id_conflicts_pkey`.
- post-action reconcile result: blocked; remaining pending version was `20260428113000`

### 20260428113000_remove_flashback_gameplay_write_path.sql

- migration file: `TRR-Backend/supabase/migrations/20260428113000_remove_flashback_gameplay_write_path.sql`
- live-state verdict: already_applied
- action: repair_history
- rollback or forward-fix note: no rollback planned; repair history only after owner confirms disabled Flashback gameplay should keep the write path removed.
- owner evidence: migration history missing; live DB no longer has `public.flashback_get_or_create_session(text, uuid)`, `public.flashback_save_placement(uuid, jsonb, integer, integer, boolean)`, `public.flashback_update_user_stats(text, integer, boolean)`, `public.flashback_user_stats`, or `public.flashback_sessions`.
- post-action reconcile result: ok; no pending local migrations remained

## Action Rules

- `not_applied`: apply that migration only, then run runtime reconcile before the next migration.
- `already_applied`: repair migration history only after live state matches the migration.
- `partially_applied`: stop and write a forward-fix or rollback note before touching history.
- `skip_with_reason`: allowed only when owner evidence says the migration must remain manual and startup should still block.
