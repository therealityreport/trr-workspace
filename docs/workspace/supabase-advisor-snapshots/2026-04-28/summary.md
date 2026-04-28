# Supabase Advisor Snapshot - 2026-04-28

Captured at: `2026-04-28T12:12:54Z`
Project ref: `vwxfvzutyufrkhfgoeaa`
Token env: `TRR_SUPABASE_ACCESS_TOKEN`
Source: Supabase Management API

## Artifacts

- Manifest: `docs/workspace/supabase-advisor-snapshots/2026-04-28/manifest.json`
- Performance JSON: `docs/workspace/supabase-advisor-snapshots/2026-04-28/performance.json`
- Security JSON: `docs/workspace/supabase-advisor-snapshots/2026-04-28/security.json`

## Status

| Advisor | Status | Lint Count | Artifact |
|---|---:|---:|---|
| performance | HTTP 200 | 362 | `docs/workspace/supabase-advisor-snapshots/2026-04-28/performance.json` |
| security | HTTP 200 | 119 | `docs/workspace/supabase-advisor-snapshots/2026-04-28/security.json` |

## Reproduction

```bash
make supabase-advisor-snapshot
```

This workflow intentionally uses `TRR_SUPABASE_ACCESS_TOKEN`, not the generic `SUPABASE_ACCESS_TOKEN`.
