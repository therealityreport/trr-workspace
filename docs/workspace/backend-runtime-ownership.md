# Backend Runtime Ownership

This document defines where backend runtime behavior belongs in TRR. Use it
when deciding whether a feature should live in FastAPI, Postgres/Supabase,
Modal, Redis, or Next.js.

## Ownership Boundaries

| Owner | Owns | Does not own |
|---|---|---|
| FastAPI | Shared backend contracts, runtime health, realtime broker lifecycle, admin control-plane APIs, and backend-shared schema access. | Long-running job execution, durable state storage, and app-only editor helpers. |
| Postgres/Supabase | Durable state, including jobs, runs, locks, retries, analytics outputs, persisted cache state, auth-backed data, and migration history. | Ephemeral realtime fanout or process-local runtime lifecycle. |
| Modal | Long-running scraping, social, media, vision, scheduled, and remote execution. | Durable ownership of job state or shared API contracts. |
| Redis | Ephemeral realtime fanout, presence/typing state, short TTL state, and cross-instance invalidation signals. | Durable queues, persisted cache-of-record data, job history, retries, or migration state. |
| Next.js | App-local authoring/editor data access, UI-specific server helpers, route handlers, and backend proxy clients. | Backend-shared schema ownership or long-running backend execution. |

## Placement Rules

- Put shared API contracts, admin control-plane routes, health visibility, and
  backend-shared SQL behind FastAPI.
- Store anything that must survive process restarts, retries, deploys, or Redis
  loss in Postgres/Supabase.
- Send long-running work to Modal, while writing job state and outcomes back to
  Postgres/Supabase.
- Use Redis only for short-lived coordination: realtime pub/sub, presence,
  typing indicators, small TTL markers, and invalidation across API instances.
- Keep Next.js direct SQL only when it is truly app-local authoring/editor data
  access. Move backend-shared schema access to FastAPI and track the migration
  in `docs/workspace/api-migration-ledger.md`.

## Instagram Post Details outcomes (contract version 1)

Postgres owns the frozen account/date/task manifest and durable targets in
`social.instagram_detail_run_targets`. FastAPI exposes `detail_contract_version`,
`detail_manifests`, `detail_outcomes`, and `detail_resume_eligible` on account
catalog progress. Next.js displays these fields; it does not query target tables.
Modal executes leased work and commits an owner-bound completion receipt.

The accounting equation is `total = committed + cached_satisfied +
source_unavailable + unresolved`. These are disjoint unique-target counts.
`failed` and `retry_wait` are subsets of unresolved; `attempted` and `requests`
are activity counters and may exceed the number of targets. Only `committed`
means fetched and successfully persisted. Cache satisfaction creates no fetch
timestamp. Unavailable requires evidence from healthy authenticated transport;
authentication, challenge, rate-limit, redirect, timeout and parse failures
remain unresolved. A completed run with unavailable targets says so explicitly.
Successful per-field timestamps advance only for fields fetched successfully.
The manifest freezes the metadata age policy (default 30 days, bounded 1–365),
24-hour mutable-metric TTL, policy version and force selection. Comments/media
keep their independent satisfaction and downstream queue states.

Missing, unsupported, or unbalanced outcome reports are unknown, including
legacy completed jobs. Generic `scraped_at`, saved-row counts and provider call
completion are insufficient success evidence. Failed or cancelled runs retain
their unresolved counts. The UI displays last committed progress and retry time.

Resume binds the original run, normalized account, source scope and manifest
identity. It preserves dates, selected tasks, satisfied targets, cooldowns and
the three-attempt cap. Active work retains ownership and cannot be resumed a
second time. A subsequent new run receives a new manifest. See the
[operator procedure](dev-commands.md#instagram-post-details-recovery).

## Redis Runtime Contract

Local single-process FastAPI may run without Redis by using the in-memory
realtime broker. Multi-worker or multi-instance FastAPI must use Redis for
realtime fanout so WebSocket state is not split across workers.

Redis loss must not lose durable TRR state. If data must be audited, retried,
reported, replayed, or used after a restart, it belongs in Postgres/Supabase
and may only be announced through Redis.

## Migration Ledger Use

When a TRR-APP direct SQL caller moves behind FastAPI, add or update a row in
`docs/workspace/api-migration-ledger.md` with the backend route, app client,
auth context, cacheability, error contract, and focused validation for that
slice.
