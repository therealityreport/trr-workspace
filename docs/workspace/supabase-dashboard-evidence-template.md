# Supabase Dashboard Evidence Template

Copy this checklist into a dated
`docs/workspace/supabase-advisor-snapshot-YYYY-MM-DD.md` file when a review
requires Dashboard-only evidence. Record statuses and shapes only; never paste
secret values, raw JWTs, cookies, passwords, service-role keys, or full
connection strings.

## Review Header

| Field | Value |
|---|---|
| Review date | YYYY-MM-DD |
| Reviewer | pending |
| Supabase project | pending |
| Environment | local / preview / production |
| Dashboard access | pending / available / blocked |
| MCP access | pending / available / blocked |
| Related plan | pending |

## Advisors

| Evidence | Status | Source | Owner | Next action |
|---|---|---|---|---|
| Security advisor | pending | Supabase Dashboard > Advisors > Security | workspace-ops | Capture finding count and blocker. |
| Performance advisor | pending | Supabase Dashboard > Advisors > Performance | workspace-ops | Capture finding count and blocker. |

## Auth

| Evidence | Status | Source | Owner | Notes |
|---|---|---|---|---|
| Auth provider posture | pending | Dashboard Auth settings | backend-shared-schema | Record enabled providers by name only. |
| Password policy/MFA posture | pending | Dashboard Auth settings | backend-shared-schema | Record shape only. |
| JWT/project-ref validation inputs | pending | Dashboard API/Auth settings | backend-shared-schema | Do not copy secrets. |

## Storage

| Evidence | Status | Source | Owner | Notes |
|---|---|---|---|---|
| Bucket inventory | pending | Dashboard Storage | backend-shared-schema | Bucket names and public/private shape only. |
| Bucket policies | pending | Dashboard Storage policies | backend-shared-schema | Link required migration if drift exists. |
| MIME/size limits | pending | Dashboard Storage settings | backend-shared-schema | Shape only. |

## Email And Edge Services

| Evidence | Status | Source | Owner | Notes |
|---|---|---|---|---|
| SMTP provider | pending | Dashboard Auth email settings | workspace-ops | Provider name/status only. |
| Edge functions | pending | Dashboard Edge Functions | backend-shared-schema | Function names/status only. |

## Capacity

| Evidence | Status | Source | Owner | Notes |
|---|---|---|---|---|
| Supavisor pool size | pending | Dashboard Database/Pooler | workspace-ops | Number only. |
| Postgres `max_connections` | pending | SQL editor or psql `SHOW max_connections` | workspace-ops | Number only. |
| Grouped holders | pending | `pg_stat_activity` grouped by `application_name` | workspace-ops | Use query in `docs/workspace/supabase-capacity-budget.md`. |
| Vercel instance/concurrency assumption | pending | Vercel project settings | workspace-ops | Shape only. |
| Backend replica/worker count | pending | Render/backend deployment settings | backend-shared-schema | Shape only. |
| Remote worker concurrency | pending | Modal settings | backend-shared-schema | Shape only. |

## Pool-Size Change Gate

Do not raise Supavisor pool size unless every row below is complete and the
change is tracked as a separate operations event from code/env changes.

| Gate | Status | Owner | Evidence |
|---|---|---|---|
| Current pool size recorded | pending | workspace-ops | Number and source/date. |
| Proposed pool size recorded | pending | workspace-ops | Number only, for example `25` or `30`. |
| Expected/worst-case holder math recorded | pending | workspace-ops | Link or short reference to `supabase-capacity-budget.md` table. |
| Change owner assigned | pending | pending | Human/operator owner. |
| Rollback target recorded | pending | pending | Previous pool size. |
| Rollback path/time recorded | pending | pending | Dashboard path or command and expected rollback time. |

## Permission Blockers

| Blocker | Owner | Date found | Follow-up date | Notes |
|---|---|---|---|---|
| pending | pending | YYYY-MM-DD | YYYY-MM-DD | pending |
