# Twitter bravowwhl Dashboard Fix Plan

## summary
Fix the Admin / Social Analytics / Twitter @bravowwhl profile dashboard 500 by repairing the backend dashboard-to-summary contract drift.

## project_context
- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend route: `GET /api/v1/admin/socials/profiles/{platform}/{handle}/dashboard`
- App route: `GET /api/admin/trr-api/social/profiles/{platform}/{handle}/snapshot`
- Observed failure: app snapshot returned `Failed to fetch social account profile dashboard`.
- Backend log showed `TypeError: get_social_account_profile_summary() got an unexpected keyword argument 'include_post_embeddings'`.

## assumptions
- The summary repository signature is the current source of truth: `get_social_account_profile_summary(platform, account_handle, *, detail="full")`.
- The dashboard route should remain platform/handle generic and not special-case `bravowwhl`.
- Existing stale-if-error app snapshot behavior remains unchanged.

## goals
- Remove the stale backend keyword argument causing the route 500.
- Add regression coverage so dashboard summary mocks reject unexpected kwargs.
- Verify backend dashboard composition and app snapshot proxy behavior.

## non_goals
- Change Supabase pool sizing or session-mode capacity.
- Change dashboard payload shape.
- Change Twitter catalog/backfill behavior.

## phased_implementation
1. Reproduce and trace the failure from app proxy to backend route logs.
2. Make the dashboard composer test fake match the real repository signature.
3. Remove the stale `include_post_embeddings` keyword from the dashboard composer.
4. Run focused backend dashboard tests and app snapshot route tests.

## architecture_impact
No boundary change. The backend remains owner of dashboard composition, and the app snapshot route remains a compatibility proxy.

## data_or_api_impact
No schema or API payload change. This is an internal function-call contract fix.

## ux_admin_ops_considerations
The admin profile page should load the dashboard instead of showing the generic failed snapshot banner. Separate pool saturation may still degrade live data reads until connection pressure is resolved.

## validation_plan
- `TRR-Backend`: `.venv/bin/pytest tests/socials/test_profile_dashboard.py tests/api/routers/test_social_account_profile_dashboard.py -q`
- `TRR-APP/apps/web`: `pnpm exec vitest run -c vitest.config.ts tests/social-account-profile-snapshot-route.test.ts`
- Optional live route check when admin allowlist auth and Supabase pool capacity permit it.

## acceptance_criteria
- Dashboard composer calls `get_social_account_profile_summary` only with supported kwargs.
- Regression test fails before the fix and passes after it.
- App snapshot route still proxies exactly one backend dashboard request.

## risks_edge_cases_open_questions
- Live verification can be blocked by current Supabase session-pool saturation or admin allowlist auth.
- If another deployed worker still has stale code, it needs restart/reload after this patch.

## follow_up_improvements
- Add a dashboard route integration test with a strict patched summary callable if this contract drifts again.
- Continue the separate Supavisor session-pool stabilization work already present in workspace docs.

## recommended_next_step_after_approval
Execute sequentially with `orchestrate-plan-execution`; no parallel workstream is needed for this narrow fix.

## ready_for_execution
Implemented in this session.
