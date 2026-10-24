# Reddit capture contract v2

Implementation authority: the approved six-release plan in the current chat.
Scope: future runs only; legacy repair/cleanup require an explicit operator action.
Schedules and AI analysis ship disabled. Existing routes and manual assignments remain.

## Ownership and interfaces

Postgres owns manifests, targets, claims, retry schedules, dispatch and analysis.
FastAPI owns admin contracts; Modal executes; Next.js only proxies and renders.

`reddit_capture.py` owns the core persistence boundary. `reddit_transport.py` owns
HTTP and comments; `reddit_workflows.py` owns schedules, lifecycle, reclassification
and analysis. Existing `reddit_refresh.py` remains the compatibility facade.

Core tables: `social.reddit_run_manifests`, `reddit_work_targets`,
`reddit_capture_state`, `reddit_assets`, `reddit_asset_links`,
`reddit_dispatch_outbox`, `reddit_request_budgets`, `reddit_request_leases`.
Run columns: `contract_version` (legacy 1, new 2), `config_hash`,
`control_state` (active/paused/cancel_requested/cancelled), `parent_run_id`, `priority`.

Target states: pending/running/retry_wait/committed/source_unavailable/failed/cancelled.
Satisfied = committed + source_unavailable. Unresolved = every other state.
Run completion requires zero unresolved required targets and no known coverage gap.
Legacy capture evidence is unknown, never inferred from old completed flags.

Core public functions (keyword arguments unless shown):
- `enabled() -> bool`: REDDIT_PIPELINE_V2_ENABLED; off by default; enabled in the verified 2026-10-21 rollout.
- `manifest_for_run(run_id) -> dict | None`.
- `assert_owner(run_id, claim_token, conn=None)`: row-lock and verify current
  running, active owner and lease; raises LostClaim or RunPaused/RunCancelled.
- `ensure_target(run_id, kind, target_key, post_id=None, checkpoint=None, conn=None) -> dict`.
- `start_target(run_id, kind, target_key, claim_token) -> dict | None`: None for
  satisfied/not-due/exhausted targets; increments attempts only for due work.
- `finish_target(run_id, kind, target_key, claim_token, state, result=None,
  checkpoint=None, error=None, retry_after=None, conn=None)`; owner checked.
- `capture_due(post_ids, phase, policy='missing', stale_after_seconds=86400) -> set[str]`.
- `record_capture(post_id, phase, state, run_id, source_revision=None,
  evidence=None, conn=None)`; successful timestamps advance only on commit.
- `run_contract(run_id) -> dict`: contract_version, control_state, outcomes,
  requested/satisfied/unresolved, coverage, retry_at; legacy returns unknown.
- `control_run(run_id, action) -> dict`: pause/resume/cancel; retry uses a linked new run.
- `list_targets(run_id, limit=100, offset=0) -> list[dict]`.
- `request_guard(identity, lane='default')` context manager; distributed limiter.
- `observe_response(identity, status, headers)` records provider cooldown/limits.

App API base is `/api/admin/reddit`, backend `/api/v1/admin/socials/reddit`.
Existing run creation gains refresh_policy missing/stale/force, selected_post_ids,
requested_phases (discovery/comments/media), force_rescrape alias. Server hashes all
normalized inputs. Unknown legacy state remains readable.

New operator endpoints under backend base:
- GET runs/{id}/targets; POST runs/{id}/control {action:pause|resume|cancel|retry}.
- GET communities/{id}/coverage?season_id=; GET runs/{id}/compare?baseline_id=.
- POST communities/{id}/reclassify {season_id, apply:false|true, preview_id?}.
- GET/PATCH communities/{id}/settings?season_id= (schedule and analysis settings).
- GET communities/{id}/legacy-inventory?season_id=.
- POST communities/{id}/lifecycle {season_id, legacy:false|true, post_ids?}.
- POST communities/{id}/analysis {season_id, kind:deterministic|ai, post_ids?}.
- GET jobs/{id} for workflow/analysis results.

Settings require exact airtime/timezone for scheduling. AI requires explicit model,
per_run_token_cap, daily_token_budget and enabled=true. Defaults are disabled.
Neither settings reads nor inventory reads enqueue any work.

## Validation and rollout

Each owner runs focused tests. Lead owns integration, source checks, review,
target-specific live verification and final acceptance. No live requests in unit tests.
Do not apply migrations, activate flags, run paid analysis or deploy from a helper.
Default target is Supabase vwxfvzutyufrkhfgoeaa; Modal admin-56995/main/trr-backend-jobs;
verify live identity before mutation. Full app production build requires approval.

Canonical response models: `TRR-Backend/trr_backend/repositories/reddit_contract.py`.
The app consumes generated OpenAPI types from `reddit-capture.openapi.json` and
`reddit-capture.d.ts`; use `generate:reddit-capture-contract` to refresh them.

Deployment evidence and operator procedures:
- [Rollout record](../../TRR-Backend/docs/deploy/2026-10-21-reddit-capture-v2.md)
- [Operator guide](../../TRR-Backend/docs/reddit-capture-v2-operations.md)


## Window discovery coverage

Window status is derived from discovery evidence for the effective date ranges
shown to the operator. A missing window-specific run is not proof of stale data.
Season-wide runs with arbitrary period keys may establish coverage of several
windows. Comments-only jobs and selected-post jobs cannot establish interval
discovery coverage.

Accept only same-community, same-season v2 manifests that record complete window
coverage with a proven chronological boundary, valid requested bounds and
committed required discovery targets. Use requested bounds rather than the oldest
or newest observed post. Combine valid overlapping intervals without filling gaps.
A later failed retry does not erase earlier qualifying evidence.

The summary accepts a bounded, validated optional set of effective canonical
window ranges from the app and returns normalized bounds and provenance. This
preserves displayed overrides instead of silently using different date cutovers.
Coverage distinguishes covered, partial, uncovered, upcoming and unknown states.
Upcoming windows do not count as recovered or stale. Partial windows show the
proven cutoff; they do not imply coverage through the present. Historical failure
diagnostics remain separate from discovery proof. Reads enqueue no work and do
not change schedules, AI settings, period memberships or run history.


## Period metadata loading

The Reddit operator loads canonical calendar metadata from backend
`GET /api/v1/admin/socials/seasons/{season_id}/analytics/periods`, through app
`GET /api/admin/trr-api/shows/{showId}/seasons/{seasonNumber}/social/analytics/periods`.
The response contains `season_id`, `timezone`, `source_scope` and `weekly` rows
with `week_index`, `label`, `week_type`, `episode_number`, `start` and `end`.
It uses the analytics calendar provider and preserves its inclusive end bounds.
This endpoint does not aggregate posts or comments, run sentiment, or enqueue jobs.

Coverage waits for period metadata and episode context. Same-season metadata
may be reused, but a different season or a fabricated fallback date cannot establish
coverage. A failed metadata read shows a retry warning. Existing episode date
cutovers remain authoritative. Stored-window primary content reads have a scoped
25-second backend timeout to allow cold starts; small polling reads keep their
existing budgets. Both reads require administrator authorization and change no
schedule or AI settings.


## Independent post and comment lifecycle

An explicit post deletion/removal redacts only the post and its post-level media.
It retains public comments, their IDs, parent/depth relationships, author fields,
and comment-level media. Comment deletion/removal requires an explicit observation
for that comment; it retains the canonical record and a tombstone while clearing
its content and identity. A deleted parent is not comment-deletion evidence and
does not block saving public comments. Nested reply copies and diagnostic snapshots
are cleared to prevent reintroducing separately deleted content.

Existing enrolled threads continue lifecycle checks after parent deletion/removal
so their surviving comments still receive independent checks. The parent remains
marked deleted/removed. This does not enable capture schedules or AI. Historical
blanket tombstones require a separately authorized, exact-ID recovery from fresh
public source evidence; they are not automatically removed.
