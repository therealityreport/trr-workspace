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

## Anonymous Instagram comment transport

The backend owns anonymous HTTPX comment retrieval and native cursor evidence.
Fresh public parent pagination uses the verified parent query sequence; resumed
pages retain their recorded query ID and cursor. Parent continuation precedes
pending child hydration. A natively exhausted parent lane can resume pending
children without replaying a parent root.

Native reply counts are nullable. Missing or null is unknown; an explicit zero
is known zero. Unknown counts remain unknown in the scraper DTO and retained
source/checkpoint reconstruction and do not suppress a child probe. Observed
reply rows are a separate lower bound, not a fabricated reported total. Numeric
legacy persistence/topology fields remain compatible; their zero fallback is
not native exhaustion evidence. The app's existing nullable Instagram comment
types remain compatible; this internal repair does not change its saved-row API.

Parent success does not establish child availability. A native child rejection
remains unresolved even if the parent operation succeeds in the same guest
session. Full-history acceptance still requires native parent and child
exhaustion. Deploy/runtime health does not establish source retrieval success.

The alternate child query `36239935742272683` remains first for fresh lanes:
the October 20 exact-thread control returned a real anonymous reply. Saved
query/cursor identities remain pinned; a rejected saved primary query can try
the alternate from its root. `SOCIAL_INSTAGRAM_PUBLIC_CHILD_ALT_DOC_TRUSTED=false`
revokes trust in empty alternate results on parents whose reply counts are unknown.

Native child-only access rejection does not fail parent collection or open the
shared identity cooldown. The attempt stops further child probes after repeated
rejections, retains failure evidence, and records pending reply lanes separately.
After parent exhaustion, those replies stay unresolved and retry on a target-only
5, 10, 20, 40, then 60 minute backoff. HTTP rate limits, authentication failures
and server retry instructions retain their safeguards. Generic public rate
rejections without a server delay use a short increasing pause rather than the
former two-hour default.

Fixed-post validation retains one exclusive request ledger, with no local daily
or per-tranche request-count cap (explicit user decision, October 20). Request
timeouts and the existing 15-minute tranche deadline remain execution safeguards.
The reply-access diagnostic is one-shot, preserves the frozen original run,
and enables its pinned-login arm only after every anonymous comparison arm has
conclusive child-access failure evidence without returning replies. Network or
bootstrap failures remain indeterminate and do not enable login. It is not scheduled and is not an ingestion
completion receipt.

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
