# Audit

Verdict: approved after required revisions

Original score: 84 / 100

Revised score estimate: 94 / 100

Approval decision: use the revised plan, not the original draft.

## Current-State Fit

The original plan correctly identified the main architectural bug: the page is catalog-centric while a separate comments run is active. It also named the right backend and app surfaces.

The browser-use refresh changed the severity and scope. The page no longer only showed a stale `13,184 / 105,716` comments card. It degraded to `Comments Saved: Unavailable`, `Media Saved: Unavailable`, `Posts 0 / 0`, and `Summary read timed out before completion. Retry in a moment.` At that same time Supabase showed both catalog and comments jobs still running with fresh heartbeats. The revised plan therefore makes active-lane status independent of the heavyweight summary.

## Required Fixes Added

- Add a bounded active-lane endpoint or additive payload that renders even when summary reads time out.
- Add comments cancel support instead of only catalog cancel.
- Make catalog cancel durable in the request path before any expensive summary reconciliation.
- Treat `cancelling` as a worker stop signal, not only `cancelled`.
- Split app state by catalog/comments lanes and summary availability.
- Make `Comments Saved` explicitly fresh, stale, progress-overlaid, or unavailable.
- Label the denominator as reported/estimated comments with source/freshness.
- Use browser-use and Supabase read-only verification as mandatory final proof.

## Biggest Remaining Risks

- The large backend repository file is a high-conflict surface. Only one writer should own `TRR-Backend/trr_backend/repositories/social_season_analytics.py` at a time.
- The user-observed cancel click does not prove the POST reached the backend. Implementation must test both request failure and accepted-cancel paths.
- Remote Modal execution appears cooperative through DB status; without remote cancellation API support, prompt worker observation of `cancelling` is the critical control.

## Benefit Score

Benefit score: 9 / 10

This is high-value operator-facing work. It prevents duplicate comments syncs, makes cancellation trustworthy, and avoids misleading counts during live ingestion.

## Approval

Approve the revised plan for execution after user approval. Do not execute from the original plan because it underweighted summary timeout and active-lane rendering when summary is unavailable.
