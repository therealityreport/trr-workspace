# TRR Social Ingestion Source of Truth

Use this reference after the main skill triggers. Keep the first response anchored in these files before widening scope.

## Core runtime surfaces
- Runbook: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
- Queue worker entrypoint: `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/socials/worker.py`
- Sync-session orchestration: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py`
- Admin socials router: `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py`
- Operator-facing shared-account diagnostics surface: `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`

## High-signal validation slices
- Worker behavior and preflight tests: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_social_worker.py`
- Sync-session orchestration tests: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_sync_orchestrator.py`
- Queue, dispatch, and `SOCIAL_WORKER_UNAVAILABLE` route coverage:
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`

## Failure class map
| Failure class | Likely layer | First source of truth | Typical validation slice |
|---|---|---|---|
| auth_preflight | Platform credential or cookie assumptions | queue worker metadata and auth-preflight code paths | `test_social_worker.py` plus platform-specific auth tests |
| modal_dispatch | Modal resolution, remote executor readiness, pre-claim dispatch failure | socials router plus queue runbook dispatch sections | `test_socials_season_analytics.py` and `test_social_season_analytics.py` |
| heartbeat_or_queue | Worker availability, heartbeat freshness, queue fairness, claim ownership | queue worker plus queue runbook SQL and health semantics | `test_social_worker.py` and queue-status route coverage |
| sync_orchestration | sync-session pass ordering, shared-account run completion, follow-up pass drift | `social_sync_orchestrator.py` | `test_social_sync_orchestrator.py` |
| operator_diagnostics | misleading operator copy, wrong recovery action, inline-fallback confusion, missing alerts interpretation | queue runbook diagnostics sections plus `SocialAccountProfilePage.tsx` | route or component tests nearest worker-health, catalog-progress, or shared-account profile actions |
| persistence_or_idempotency | upsert, dedupe, partial repair, stale summary truth | backend repositories and storage-facing route handlers | repository tests nearest the failing table or summary path |
| completeness_gap | comment, media, avatar, or details follow-up drift | sync orchestrator snapshot and season analytics repositories | sync-session tests plus season analytics repository tests |

## Triage rule of thumb
1. `TRR-APP` is usually the symptom surface, not the source of truth.
2. When the issue starts with `SOCIAL_WORKER_UNAVAILABLE`, dispatch-blocked jobs, or likely-stuck jobs, start in the runbook and backend queue code.
3. When the issue starts with misleading run or follow-up status, start in `social_sync_orchestrator.py`.
4. When the issue is about what operators are told to do next, read the runbook sections for additive `alerts` arrays, `used_inline_fallback`, `requires_modal_executor`, and the preferred `Sync Recent` -> `Sync Newer` -> `Backfill Posts` canary order before editing UI copy.
