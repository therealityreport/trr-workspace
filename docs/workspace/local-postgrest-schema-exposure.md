# Local PostgREST Schema Exposure Decision

Decision date: 2026-04-27

Status: keep current local exposure pending live RLS/grants evidence.

`TRR-Backend/supabase/config.toml` currently exposes these schemas through the
local Supabase/PostgREST API:

```text
public, graphql_public, core, admin
```

This workspace slice does not change backend config. The decision is to keep
the current local exposure for compatibility while making the risk explicit:

- `public` and `graphql_public` stay as Supabase defaults.
- `core` stays exposed locally because TRR admin/dev tooling may inspect shared
  read models during local Supabase runs.
- `admin` stays exposed locally only as a dev compatibility surface until the
  RLS/grants review proves whether it should remain exposed or move behind
  backend-service-only access.

## Evidence Required Before Changing Exposure

Run the workspace snapshot target and fill the review doc:

```bash
cd /Users/thomashulihan/Projects/TRR
make rls-grants-snapshot
```

Then review `docs/workspace/supabase-rls-grants-review.md` for:

- RLS enabled/forced state for `public`, `core`, `admin`,
  `firebase_surveys`, and `social`;
- grants to `anon`, `authenticated`, and `service_role`;
- any intentionally public reads and their product rationale;
- any missing RLS policy or accidental grant that needs a backend migration.

## Removal Gate

Remove `admin` from local PostgREST exposure only after:

- a backend owner confirms local admin pages and scripts do not require direct
  PostgREST access to `admin`;
- the RLS/grants snapshot is captured;
- affected local Supabase tests or runbooks are updated;
- the decision is reflected in `docs/workspace/env-contract-inventory.md` and
  this file.
