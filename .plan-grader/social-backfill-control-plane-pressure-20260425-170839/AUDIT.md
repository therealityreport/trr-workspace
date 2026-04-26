# Plan Audit

## Verdict

APPROVE WITH CHANGES

## Plan Summary

The plan stabilizes social backfills by reducing Modal pressure, isolating social control-plane DB reads, adding stale run/session cleanup tools, fixing TikTok near-complete fallback behavior, failing Instagram comments warmup early, and adding a browser-use benchmark gate for Scrapling versus Crawlee default selection.

## Current-State Fit

Strong. The plan targets the current repo seams observed in this workspace:

- Social run finalization: `TRR-Backend/trr_backend/socials/control_plane/run_lifecycle.py`
- Run/live status reads: `TRR-Backend/trr_backend/socials/control_plane/run_reads.py` and `shared_status_reads.py`
- DB pool routing: `TRR-Backend/trr_backend/db/pg.py`
- Workspace Modal pressure defaults: `profiles/default.env`, `scripts/dev-workspace.sh`, `scripts/status-workspace.sh`, and `docs/workspace/env-contract.md`
- TikTok shared account fallback: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Instagram comments Scrapling warmup: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py` and `job_runner.py`

## Benefit Score

High. The plan directly addresses observed operator-facing failures: hung backend health, DB pool exhaustion, duplicate active Twitter jobs, live-status timeouts, TikTok near-complete catalog failure, and Instagram zero-cookie warmup churn.

## Required Changes Applied

1. Added a dedicated browser-use benchmark task for Scrapling versus Crawlee.
2. Required separate subagents for method trials, each using the Browser Use plugin.
3. Added a benchmark report artifact and scoring harness.
4. Added a guard that runtime defaults cannot change without browser-use evidence.
5. Added an unsupported-platform path so X/Twitter does not pretend to have a Scrapling lane when current code lacks one.
6. Replaced the hard-coded Crawlee default example with a benchmark-approved defaults map.
7. Renumbered verification to Task 9 and included benchmark evidence in final acceptance criteria.

## Biggest Risks

- The plan is large. Execution should use subagent-driven development or strict task-by-task commits.
- The browser-use benchmark task can become expensive if it tries to cover every platform in one pass. Workers should benchmark equivalent lanes first and record unsupported methods honestly.
- Runtime default changes must be conservative because Twitter currently does not have a Scrapling implementation.

## Approval Decision

Approved with the applied plan patches. Execute only from the revised plan and preserve the benchmark report as evidence before changing defaults.
