# Instagram ingestion reliability contract

The maintained account workflow is the v2 Instagram ingestion panel and
`/api/v2/admin/social/profiles/instagram/{handle}/ingestion/*`. The app's local
admin proxy preserves that route family and command idempotency keys.

## Launch and status

- New Instagram UI launches require an enabled capability response. Loading,
  errors, and explicit disablement show their cause and do not select a legacy
  launch. BravoTV full history and resume-tail remain held by the server gate.
- When v2 owns Instagram launches, legacy comments scrape, cursor recovery,
  resume, rebalance, auth repair/follow-up, public recovery, and guarded restart
  return `409` with `instagram_v2_owns_launches`. Read-only preview and existing
  job cancellation remain available.
- Internal comments and catalog new-run helpers enforce the same configured v2
  ownership before probes or persistence, including deferred and CLI callers.
  Already accepted job execution keeps its existing path.
- Progress accepts optional nullable `execution_hold_reason`, a bounded operator
  code. A hold disables actions and remains visible. Diagnostics prioritize
  unresolved targets within the existing 100-record limit and refresh when the
  run generation, lifecycle state, or last committed timestamp changes.
- Resolved lifecycle work includes source-unavailable outcomes. Saved passes,
  exhausted pagination, and resolved counters do not certify complete source
  capture. Count parity requires equal expected and observed totals. Overshoot
  cannot authorize marking other saved comments missing.

## Evidence and media

Retained-audit reuse binds the run, target, generation, checkpoint, parser and
complete canonical-row inventory, including tombstones and duplicate
multiplicity. A later canonical mutation requires a new audit. Reading all
retained pages is separate from a passing integrity result.

Media admission still requires exact agreement between the supporting current
comment receipt and active canonical inventory. Historical replay preserves
saved data but cannot union older roots into current coverage.

`scripts/ingestion/refresh_count_witnesses.py` previews up to five explicit
January posts by default. `--apply` uses the supported public adapter, at most
three sends per target and a maximum 90-second operation plus bounded cleanup.
It retains auxiliary observations in exclusive private artifacts and never
overwrites post clocks, comment settlements or receipts. These observations are
not a January certificate and do not replace the independent deep audit.

## Bounded local worker

The worker rejects a backend already holding the coordinator grant before
acquiring it. Heartbeats verify the original backend and exact database/key
grant. Startup qualification has a 10-second bound; the existing 2-second
heartbeat and 15-second abort cleanup grace remain unchanged.

Optional process-local limits preserve ordinary persistent behavior when unset:

| Variable | Contract |
| --- | --- |
| `TRR_INSTAGRAM_LOCAL_WORKER_RUN_ID` | Exact UUID; reject other runs before seed or partition acknowledgement. |
| `TRR_INSTAGRAM_LOCAL_WORKER_MAX_ACTIVITIES` | `1`, `2`, `4`, or `6`; cap the current durable policy without raising it. |
| `TRR_INSTAGRAM_LOCAL_WORKER_DEADLINE_AT` | Finite future Unix timestamp, no more than one hour away; convert once to monotonic time. |
| `TRR_INSTAGRAM_LOCAL_WORKER_PARENT_PID` | Actual positive parent PID; requires a deadline and stops work on reparenting. |

A handover must observe the old process and grant absent before replacement.
Source readiness, installed code, active ownership, and full-run certification
remain separate acceptance facts. Follow the current deployment record for
runtime identities and outstanding January gaps.
