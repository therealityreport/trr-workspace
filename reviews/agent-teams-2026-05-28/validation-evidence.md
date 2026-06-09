# Validation Evidence

## Implementation Validation - 2026-05-28

Commands run after the non-admin-auth remediation pass:

```bash
python3 -m pytest -q scripts/test_modal_billing_guardrail.py
```

Result: `6 passed`.

```bash
bash scripts/modal-billing-guardrail.sh
```

Result: guardrail passed with deployed schedules and warm containers off by default.

```bash
cd TRR-Backend && .venv/bin/pytest -q tests/test_modal_jobs.py -k "schedule or maintenance or sweep_social_dispatch_queue" tests/test_startup_config.py -k modal_runtime_scheduler tests/scripts/test_repair_instagram_auth.py -k "cooldown or modal_app_missing or missing_named_secrets or allow_cookie_refresh"
```

Result: `7 passed`, with unrelated tests deselected.

```bash
cd TRR-Backend && .venv/bin/pytest -q tests/repositories/test_social_season_analytics.py -k "comments_scrape_run_progress or rebalance_slow" tests/api/routers/test_admin_show_bravo.py -k "social_sources" tests/api/routers/test_socials_season_analytics.py -k "cookies_refresh or allow_cookie_refresh"
```

Result: `7 passed`, with unrelated tests deselected.

```bash
python3 -m pytest -q scripts/test_env_hygiene.py scripts/test_instagram_auth_freshness.py scripts/test_workspace_app_env_projection.py
```

Result: `35 passed`.

```bash
python3 scripts/workspace/env_hygiene.py --check
```

Result: exit code `0`; retired adjacent env surfaces were excluded by default.

```bash
pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.mts tests/social-growth-route.test.ts tests/social-growth-refresh-route.test.ts tests/social-growth-batch-route.test.ts
```

Result: `12 passed`.

```bash
pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.mts tests/safe-next-build.test.ts
```

Result: `5 passed`.

```bash
pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.mts tests/social-account-profile-page.runtime.test.tsx -t "cookie refresh"
```

Result: `3 passed`, with unrelated tests skipped by filter.

```bash
pnpm -C TRR-APP/apps/web run validate:quick
```

Initial result: failed because `src/lib/admin/api-references/generated/inventory.ts` was stale.  
Action: regenerated the admin API references artifact.  
Final result: `12 passed`.

```bash
bash scripts/test-changed.sh
```

Result: blocked before root tests by existing user-level Codex config mismatch:
`user [mcp_servers.context7] expected args=['-y', '@upstash/context7-mcp'], found ['-y', '@upstash/context7-mcp@1.0.33']`.

## Modal Completion Status

Modal deploy was not run. The safe deploy manifest requires a clean deploy tree
or isolated worktree, and this orchestrated run was constrained to the current
checkout without branch/worktree creation.

Exact deploy command once an approved clean deploy tree exists:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m modal deploy -m trr_backend.modal_jobs
.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram
```

## Local Commands And Checks

From `/Users/thomashulihan/Projects/TRR`:

```bash
sed -n '1,220p' .codex/rules/trr-project.md
```

Result: project rules loaded. Full TRR-APP production build remains approval-gated.

```bash
git status --short --branch
```

Result: branch `main...origin/main`; tree was already dirty before this review, including docs, scripts, Makefile, rules, and untracked `reviews/`.

```bash
rg -n "TRR_MODAL_RUNTIME_SCHEDULER_ENABLED|sweep_social_dispatch_queue|heartbeat_remote_executors|Cron|always_on|min_containers|schedule" TRR-Backend/api/main.py TRR-Backend/trr_backend/modal_jobs.py scripts/modal-billing-guardrail.sh
```

Result: confirmed Modal schedules and API scheduler are both disabled by default, with opt-in flags for both ownership paths.

```bash
rg -n "rebalance_slow|auto_rebalance|comments_scrape_run_progress|allow_cookie_refresh|CookieRefreshRequest|canonical_skipped_conflict" TRR-Backend/api TRR-Backend/trr_backend TRR-Backend/tests
```

Result: confirmed comments progress GET enables auto-rebalance, explicit cookie refresh defaults false, and Bravo conflict path increments conflict while link upsert follows.

```bash
rg -n "debug-log|TRR_REMOTE_DEBUG_LOG_ENABLED|isRequestHostAllowedForAdmin|isDevAdminBypassEnabled|build:turbo|social-growth" TRR-APP/apps/web/src TRR-APP/apps/web/package.json
```

Result: confirmed host-based debug/admin checks, raw `build:turbo`, and hand-rolled SocialBlade proxies.

## Supabase MCP Evidence

Read-only Supabase tools were used:

```text
_get_advisors(type="security")
_get_advisors(type="performance")
_list_migrations()
```

Security advisor result summary:

- `function_search_path_mutable`: `admin.set_updated_at`
- `function_search_path_mutable`: `firebase_surveys.set_updated_at`
- `extension_in_public`: `vector`
- `anon_security_definer_function_executable`: `surveys.submit_response(uuid, jsonb)`
- `authenticated_security_definer_function_executable`: `surveys.submit_response(uuid, jsonb)`

Performance advisor result summary:

- unindexed FKs on `social.instagram_profile_following_snapshots`
- unindexed FKs on `social.instagram_profile_relationship_snapshot_items`
- many unused-index candidates across `social`, `surveys`, `ml`, `screenalytics`, and `public`

Migration list result: live project has migrations through `20260519075042_scrape_runs_catalog_backfill_recent_idx`, plus earlier security/performance hardening migrations including `20260428110000_security_hotfix_public_migrations_rpc_exec`, `20260428111000_advisor_rls_policy_cleanup`, `20260511183000_social_unindexed_fk_advisor_indexes`, and `20260511195828_supabase_security_advisor_default_deny_and_search_path`.

## Subagent Evidence

Agent lanes reported focused validations:

- Backend/API lane ran focused backend tests around Bravo social sources, auth repair, Modal jobs, and startup scheduler; all reported passing.
- Frontend lane ran focused tests for SocialBlade routes, Bravo image routes, and safe build guard; all 19 reported passing.
- Cloud lane reproduced Modal guardrail gaps around `.env` source rendering and mixed-case truthy parsing.

The parent review did not rerun every subagent command because this task produced review artifacts and the repo is already dirty. The review package records findings and patch directions rather than changing runtime code.

## Not Run

- No full TRR-APP production build was run. Project rules require explicit user approval.
- No `make dev-hybrid` browser verification was run. This was a review-artifact task, not a UI/runtime reproduction.
- No Modal deploy/update was run. No Modal-deployed code was changed.
- No Supabase migrations were applied. Supabase usage was read-only advisor and migration inspection.

## Coverage Gaps To Close With Fixes

- Spoofed-host tests for admin auth and debug-log kill switch.
- Backend route test proving comments progress GET is read-only.
- Bravo conflict test proving no approved link is written on canonical handle conflict.
- Cookie refresh tests proving confirmed explicit refresh attempts refresh work.
- Modal guardrail tests for mixed-case truthy inputs and `TRR-Backend/.env` source drift.
- Root `test-changed` coverage for scripts/docs-only changes.
- SocialBlade proxy tests for structured backend `detail` objects and timeout behavior.
