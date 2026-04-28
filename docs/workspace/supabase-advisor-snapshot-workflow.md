# Supabase Advisor Snapshot Workflow

Use this workflow when a plan, audit, or remediation needs current Supabase
Security Advisor and Performance Advisor evidence.

## Command

Run from `/Users/thomashulihan/Projects/TRR`:

```bash
make supabase-advisor-snapshot
```

The command writes dated artifacts under:

```text
docs/workspace/supabase-advisor-snapshots/YYYY-MM-DD/
```

Expected files:

- `performance.json` - raw Performance Advisor JSON when the request succeeds.
- `security.json` - raw Security Advisor JSON when the request succeeds.
- `manifest.json` - redacted capture metadata, endpoint status, lint counts, source endpoints, token env name, and artifact paths.
- `summary.md` - human-readable capture summary for plan and handoff references.

The command exits nonzero if either advisor endpoint fails. Partial successes keep
their JSON artifact and the manifest records the failed endpoint status.

## Token Contract

TRR advisor snapshots use the repo-local Supabase Management API token env:

```bash
TRR_SUPABASE_ACCESS_TOKEN
```

Do not use `SUPABASE_ACCESS_TOKEN` for TRR. That generic env can point at another
Supabase project and is intentionally ignored by the TRR MCP/access workflow.

Do not use runtime secrets for this command:

- `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- app anon/publishable keys
- direct/session/transaction Postgres URLs

The project ref is loaded from `.codex/config.toml` and should remain:

```text
vwxfvzutyufrkhfgoeaa
```

Override only for an explicit reviewed test:

```bash
python3 scripts/capture-supabase-advisor-snapshot.py \
  --project-ref vwxfvzutyufrkhfgoeaa \
  --token-env TRR_SUPABASE_ACCESS_TOKEN
```

## Supabase API Contract

The script calls the Supabase Management API:

```text
GET https://api.supabase.com/v1/projects/{ref}/advisors/performance
GET https://api.supabase.com/v1/projects/{ref}/advisors/security
```

Supabase documents these advisor endpoints as experimental/deprecated. Fine-grained
tokens need advisor read permission (`advisors_read`); OAuth flows list
`database:read`. If Supabase changes or removes the endpoint, keep the failed
`manifest.json` as evidence and update this workflow before revising plan claims.

Reference:

- Supabase Management API reference: https://supabase.com/docs/reference/api/introduction

## Diagnostics

Missing token:

```text
[supabase-mcp-access] ERROR: TRR_SUPABASE_ACCESS_TOKEN is not set.
```

Permission blocked:

```text
[supabase-mcp-access] ERROR: TRR_SUPABASE_ACCESS_TOKEN is set but Supabase returned HTTP 401/403.
```

Advisor endpoint failure:

```text
[supabase-advisor-snapshot] performance: ERROR HTTP 404 at ...
```

Treat `401` and `403` as auth/permission blockers. Treat `404` as an endpoint
contract blocker unless Supabase has published a replacement path. Do not convert
failed advisor attempts into remediation claims.
