# Social Backfill Runtime Method Comparison

## Scope

- Account: `thetraitorsus`
- Platforms checked: Instagram, TikTok, X/Twitter, Facebook where the admin profile and configured runtime method are available.
- Candidate methods: Scrapling and Crawlee.
- Browser evidence tool: `@browser-use` in-app browser backend.

## Decision Rule

The default method must satisfy all gates:
- At least 98 percent post completeness for the tested account/platform.
- No missing media class that the competing method saved.
- No increase in DB pool errors compared with the competing method.
- No long-lived `live-status/stream` or profile summary timeout during the trial.
- Browser-use evidence is present for the run status/progress page.

If both methods pass, choose the higher benchmark score from `scripts/socials/benchmark_backfill_runtime_methods.py`.

## Scrapling Trial

- Browser evidence: not captured for an equivalent Scrapling-vs-Crawlee trial in this branch.
- Run ids: none.
- Runtime seconds: n/a.
- Posts saved / expected: n/a.
- Media saved: n/a.
- Comments saved: n/a.
- DB pool errors: n/a.
- Modal invocations: n/a.
- Modal invocation IDs: n/a.
- Failure reason: `unsupported_by_current_code_or_not_measured`.

## Crawlee Trial

- Browser evidence: not captured for an equivalent Scrapling-vs-Crawlee trial in this branch.
- Run ids: none.
- Runtime seconds: n/a.
- Posts saved / expected: n/a.
- Media saved: n/a.
- Comments saved: n/a.
- DB pool errors: n/a.
- Modal invocations: n/a.
- Modal invocation IDs: n/a.
- Failure reason: `unsupported_by_current_code_or_not_measured`.

## Typed JSON Evidence

- Path: `docs/ai/benchmarks/social_backfill_method_comparison.json`
- Winner method: none.
- Candidate count: 0.
- Modal invocation IDs present for every Modal-backed candidate: false.
- Browser evidence present for every default-eligible candidate: false.

## Selected Default

- Method: no change.
- Why this method won: no candidate met the browser-use evidence and 98 percent completeness gates.
- Platforms where default changes: none.
- Platforms where default stays unchanged: Instagram, TikTok, X/Twitter, Facebook.

## Rollback

To roll back, revert the runtime default change in `TRR-Backend/trr_backend/socials/crawlee_runtime/config.py` and `TRR-Backend/trr_backend/socials/control_plane/dispatch.py`, then restart `make dev`.
