# Supabase RLS And Grants Review

Status: pending live snapshot

This file is the durable Phase 5 artifact for exposed-schema RLS and grants.
It must not contain secret values.

## Snapshot Commands

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh scripts/db/rls_grants_inventory.sql
./.venv/bin/python scripts/db/rls_grants_snapshot.py --output ../docs/workspace/supabase-rls-grants-review.md
```

## Current Evidence Gap

Supabase MCP advisor/migration/storage reads were blocked by permission during
the audit session. Do not treat this document as a completed RLS review until a
live snapshot has been captured against the intended project.

Local PostgREST exposure decision:

- Current local exposed schemas are documented in
  `docs/workspace/local-postgrest-schema-exposure.md`.
- `admin` remains exposed locally as a compatibility surface until this RLS and
  grants review proves whether it should remain exposed or move behind
  backend-service-only access.

## Review Checklist

- Every table in `public`, `core`, `admin`, `firebase_surveys`, and `social`
  has an RLS enabled/forced decision.
- Every `anon`, `authenticated`, and `service_role` grant is intentional.
- Any intentionally public read is listed with product rationale.
- Any accidental grant or missing RLS policy has a linked backend migration.

## RLS Inventory

Pending live snapshot.

## Role Grants

Pending live snapshot.
