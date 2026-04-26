# Social Profile Dashboard Stability Plan Audit

## Verdict

REVISE BEFORE EXECUTION.

The original plan has the right architecture and high-value target, but several code-level instructions do not fit the current repo. The revised plan is execution-ready after correcting app paths, Vitest conventions, snapshot-cache semantics, and backend progress-call signatures.

## Current-State Fit

The plan correctly identifies that the current app snapshot route composes summary plus catalog progress in `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`, and that TRR-Backend already owns most social profile endpoints in `TRR-Backend/api/routers/socials.py`.

The plan does not fully fit the current repo in these places:

- App types live in `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`, not `TRR-APP/apps/web/src/types/admin/social-account-profile.ts`.
- Vitest includes `TRR-APP/apps/web/tests/**/*.test.ts(x)`, not tests under `src/**/__tests__`.
- `SocialAccountProfilePage` is a default export, so the proposed named import would fail.
- The snapshot route uses `@/lib/server/admin/admin-snapshot-cache` and `@/lib/server/admin/admin-snapshot-route`; `@/lib/server/admin-route-cache` does not exist.
- The backend catalog progress repository function signature is `get_social_account_catalog_run_progress(platform, account_handle, run_id, *, recent_log_limit=...)`; the original service snippet calls it with only `run_id`.
- Returning HTTP 200 with `data: null` on dashboard composition errors would overwrite the app snapshot cache and defeat stale fallback.

## Benefit Score

High. The user-facing benefit is concrete: social profile pages should stop feeling broken when backend reads, diagnostics, or catalog jobs are slow. The plan also reduces initial page fanout and creates a backend-owned contract that can later be backed by read models.

## Biggest Risks

1. Stale fallback regression: a successful null dashboard response can replace the last good snapshot.
2. Test non-execution: tests placed under `src/**/__tests__` will not run under the current Vitest include.
3. Broken app build: wrong import paths and named component import would fail before runtime.
4. Broken backend runtime: the dashboard service would call catalog progress with the wrong arguments.
5. Polling overconstraint: requiring the catalog tab for every live snapshot can hide updates that the stats shell still needs unless manual refresh remains available.

## Approval Decision

Do not execute the original plan literally. Execute `REVISED_PLAN.md` from this artifact package instead.

