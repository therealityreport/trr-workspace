# Consolidated Findings

## Implementation Status - 2026-05-28

Resolved or decision-gated in the non-admin-auth remediation pass:

- `HI-002`: Modal maintenance owner validation added for zero-owner and duplicate-owner states; Modal deploy remains blocked by safe deploy-tree requirements.
- `HI-003` / `ME-001`: Modal billing guardrail now checks the same source env used for named-secret rendering and blocks mixed-case truthy values unless break-glass is explicit.
- `HI-004`: Comments progress `GET` now calls progress with `auto_rebalance_slow_shards=False`.
- `HI-005`: Bravo canonical social conflicts now skip approved link upsert.
- `HI-006`: Explicit cookie refresh defaults to `allow_cookie_refresh=true`; passive/catalog repair remains conservative.
- `HI-008` / `ME-004`: SocialBlade proxies preserve structured backend details and return typed `504` timeout payloads.
- `HI-009` / `ME-005`: root script contract tests are centralized and wired into full, fast, and changed-file validation.
- `ME-002`: infrastructure auth-repair failures remain retryable and do not write cooldown.
- `ME-006`: adjacent/retired env surfaces are opt-in via `WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT=1`.
- `ME-007`: Instagram auth freshness resolves env-configured cookie files before defaults and does not silently fall back for missing configured files.
- `ME-008`: `build:turbo` routes through `safe-next-build.mjs --turbopack`.
- `ME-009`: current Supabase advisor output was captured in `docs/workspace/supabase-advisor-recheck-2026-05-28.md`; no DDL was applied.
- `LO-001` / `LO-002`: dev-hybrid docs and draft plan validation commands were corrected.

Intentionally deferred by user scope:

- `CR-001`: admin dev-bypass host trust.
- `HI-001`: debug-log host trust.
- `ME-003`: Bravo image proxy human attribution.

## Critical

### CR-001 - Admin Dev Bypass Trusts Spoofable Host Data

Location: `TRR-APP/apps/web/src/lib/server/auth.ts:560`, `TRR-APP/apps/web/src/lib/server/auth.ts:570`

Dimension: security / auth

Impact: admin host enforcement and the dev-admin bypass both read request-controlled host data. On a reachable dev deployment or proxy path, a request with a localhost-looking `Host` can satisfy the local-host check and reach dev bypass behavior without real auth.

Fix: derive local/dev eligibility from trusted server state only. Keep bypass behind an explicit env gate and require loopback binding or trusted platform metadata, not request host headers.

## High

### HI-001 - Debug-Log Remote Kill Switch Is Host-Bypassable

Location: `TRR-APP/apps/web/src/app/api/debug-log/route.ts:24`

Dimension: security / debug logging

Impact: `/api/debug-log` treats localhost-looking request URLs as local and ignores `TRR_REMOTE_DEBUG_LOG_ENABLED`. A proxy or spoofed host can re-enable remote debug writes despite the documented kill switch.

Fix: decide remote/local eligibility from trusted runtime state, such as `NODE_ENV`, explicit server env, or deployment metadata. Do not key the kill switch off request hostnames.

### HI-002 - Modal Maintenance Has No Safe Default Owner

Location: `TRR-Backend/api/main.py:147`, `TRR-Backend/api/main.py:394`, `TRR-Backend/trr_backend/modal_jobs.py:373`, `TRR-Backend/trr_backend/modal_jobs.py:1001`, `TRR-Backend/trr_backend/modal_jobs.py:1033`, `TRR-Backend/docs/runbooks/social_worker_queue_ops.md:73`

Dimension: cloud infra / runtime availability

Impact: the runbook says the default owner is Modal singleton maintenance, but Modal cron schedules are disabled by default and the API runtime scheduler is disabled by default. Default deploys can have zero owners for recovery, heartbeat, and stale-worker cleanup. If the API fallback is enabled across multiple API replicas, it can also become multi-owner.

Fix: choose one steady-state owner and enforce it in runtime config. Restore Modal singleton schedules as the default owner, or enable exactly one dedicated API/worker owner with a lease/startup guard. Update the runbook to match the shipped default.

### HI-003 - Modal Billing Guardrail Misses Named-Secret Source Env

Location: `scripts/modal-billing-guardrail.sh:32`, `TRR-Backend/scripts/modal/prepare_named_secrets.py:288`

Dimension: cloud infra / cost safety

Impact: the guardrail checks shell variables and code defaults, but named-secret rendering preserves `TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED`, `TRR_MODAL_API_MIN_CONTAINERS`, and `TRR_MODAL_ADMIN_KEEP_WARM` from `TRR-Backend/.env`. Preflight can pass while a later secret apply keeps always-on billing values.

Fix: validate the same source env file used by `prepare_named_secrets.py`, and/or force these keys to safe values in `_apply_runtime_overrides` unless a break-glass flag is set.

### HI-004 - Comments Progress GET Mutates Live Runs

Location: `TRR-Backend/api/routers/socials/__init__.py:4367`, `TRR-Backend/api/routers/socials/__init__.py:4389`, `TRR-Backend/trr_backend/socials/pipelines/comments/instagram.py:2268`, `TRR-Backend/trr_backend/socials/pipelines/comments/instagram.py:2975`

Dimension: API contract / scraper concurrency

Impact: the progress read route calls `rebalance_slow_instagram_comments_shards()` with `auto_rebalance_slow_shards=True`. Dashboard polling can cancel a running shard and enqueue replacements.

Fix: keep progress reads read-only. Move slow-shard rebalance to an explicit `POST` admin action or maintenance loop.

### HI-005 - Bravo Social Conflict Still Writes Approved Entity Link

Location: `TRR-Backend/api/routers/admin_show_bravo.py:1821`, `TRR-Backend/api/routers/admin_show_bravo.py:1866`, `TRR-Backend/tests/api/routers/test_admin_show_bravo.py:2151`

Dimension: backend data integrity

Impact: `_persist_bravo_profile_social_sources()` detects that a handle belongs to another person and increments `canonical_skipped_conflict`, then still writes an approved social `entity_links` row for the current person.

Fix: skip the link upsert when the canonical handle conflicts, or write a review-needed link. Add a conflict test that asserts no approved link is written.

### HI-006 - Explicit Cookie Refresh Defaults To No Refresh

Location: `TRR-Backend/api/routers/socials/__init__.py:5424`, `TRR-Backend/api/routers/socials/__init__.py:5641`, `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:6436`, `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py:8874`, `TRR-Backend/scripts/modal/repair_instagram_auth.py:624`

Dimension: auth / operator workflow

Impact: explicit `/cookies/refresh` calls send or default `allow_cookie_refresh=false`. For Instagram, the confirmed refresh can still take the skipped/manual-auth branch instead of attempting the refresh operators requested.

Fix: default the explicit refresh route to `allow_cookie_refresh=true` once confirmation is present, or remove the flag from that route. Keep the false default for broader auth-repair flows.

### HI-007 - Supabase Survey RPC Is SECURITY DEFINER And Publicly Executable

Location: `TRR-Backend/supabase/migrations/0090_survey_submit_response_rpc.sql:7`, `TRR-Backend/supabase/migrations/0090_survey_submit_response_rpc.sql:70`, `TRR-Backend/api/routers/surveys.py:302`

Dimension: Supabase security

Impact: live Supabase advisors report `surveys.submit_response(uuid, jsonb)` as a `SECURITY DEFINER` function executable by `anon` and `authenticated`. That may be intentional for public surveys, but it bypasses normal invoker privileges and remains an external-facing warning.

Fix: decide whether public anonymous survey submission must stay RPC-based. If yes, constrain the function body and grants tightly and document the exception. If no, revoke `anon`/`authenticated` execute and move submission through the backend/admin-controlled path or `SECURITY INVOKER`.

### HI-008 - SocialBlade Proxy Errors Drop Structured Backend Details

Location: `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/social-growth/route.ts:61`, `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/social-growth/refresh/route.ts:65`, `TRR-APP/apps/web/src/app/api/admin/trr-api/social-growth/refresh-batch/route.ts:58`

Dimension: frontend/API contract

Impact: these proxies assign `data.detail` directly to `error`. When the backend returns `{ detail: { message, code } }`, UI callers that expect string errors show only generic `HTTP 5xx` failures.

Fix: normalize upstream failures into string `error` values using `detail.message`, `detail.code`, and fallback text, or migrate these routes to the shared admin proxy helper.

### HI-009 - Root-Only Changes Can False-Green In `test-changed`

Location: `scripts/test-changed.sh:55`

Dimension: validation correctness

Impact: when only root, docs, scripts, or policy files change, `test-changed` exits after policy/workspace checks and does not run the root script pytest lane. Regressions in `scripts/instagram_auth_freshness.py`, `scripts/workspace/env_hygiene.py`, or modal guardrail scripts can pass.

Fix: make `run_workspace_checks` run the maintained root script pytest lane, or route root-only changes through a dedicated workspace-scripts mode.

## Medium

### ME-001 - Modal Billing Guardrail Has Mixed-Case Truthy Bypass

Location: `scripts/modal-billing-guardrail.sh:11`

Impact: `True`, `Yes`, or `On` are truthy in backend parsers but not blocked by the shell guardrail. A mixed-case value can re-enable Modal cron schedules without failing the guardrail.

Fix: lowercase before matching, or share the backend truthy semantics. Add tests for mixed-case truthy values.

### ME-002 - Instagram Auth Cooldowns Are Written For Pre-Refresh Or Infra Failures

Location: `TRR-Backend/scripts/modal/repair_instagram_auth.py:234`, `TRR-Backend/scripts/modal/repair_instagram_auth.py:621`, `TRR-Backend/scripts/modal/repair_instagram_auth.py:793`, `TRR-Backend/scripts/modal/repair_instagram_auth.py:830`

Impact: cooldown state can be written before an actual refresh attempt or for Modal/runtime failures such as missing app/secrets. Operators can be locked out for an hour and pointed toward manual auth for infrastructure problems.

Fix: write cooldown only for real auth, checkpoint, refresh-risk, or post-refresh failures. Keep infra failures retryable and report the infrastructure cause.

### ME-003 - Bravo Image Proxy Routes Lose Human Admin Attribution

Location: `TRR-APP/apps/web/src/app/api/admin/trr-api/bravotv/images/runs/[runId]/backfill/route.ts:17`, `TRR-APP/apps/web/src/app/api/admin/trr-api/bravotv/images/people/[personId]/stream/route.ts:24`

Impact: the routes call `requireAdmin()` locally, then forward a bare internal-admin bearer token. Backend Bravo routes receive machine identity instead of signed admin UID/email for `initiated_by`/audit fields.

Fix: use `requireAdminContext()` plus `buildInternalAdminHeaders(context, ...)`, or move the routes to `createAdminBackendProxyRoute`.

### ME-004 - SocialBlade Proxies Have No Upstream Timeout

Location: `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/social-growth/route.ts:57`, `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/social-growth/refresh/route.ts:56`, `TRR-APP/apps/web/src/app/api/admin/trr-api/social-growth/refresh-batch/route.ts:44`

Impact: bare `fetch()` calls can leave the admin UI stuck until platform-level timeout.

Fix: use shared timeout-safe backend fetch helpers and return typed 504 responses.

### ME-005 - Standard Root-Script Test Lane Is Too Narrow

Location: `scripts/test.sh:14`, `scripts/test-fast.sh:40`

Impact: standard validation covers four root script tests while the repo has a larger `scripts/test_*.py` surface. Tests for preflight, runtime DB, health, handoff, Chrome status, and workspace runtime helpers are not part of normal validation.

Fix: centralize the maintained root-script test set and call it from full, fast, and changed-file validation.

### ME-006 - Env Hygiene Reads Adjacent `screenalytics/.env` By Default

Location: `docs/workspace/shared-env-manifest.json:46`, `scripts/workspace/env_hygiene.py:211`, `docs/workspace/workspace-hygiene.md:30`

Impact: governance says `screenalytics/` is adjacent/report-only, but env hygiene scans `screenalytics/.env` by default. Warnings and cleanup advice can depend on sibling workspace secrets.

Fix: remove `screenalytics/.env` from default local-secret adapters, or require an explicit adjacent-workspace opt-in.

### ME-007 - Instagram Auth Freshness Ignores Env-Configured Cookie Files

Location: `scripts/instagram_auth_freshness.py:14`, `docs/workspace/instagram-scrapling-runtime-canary.md:35`

Impact: strict preflight can warn/fail on stale defaults even when `SOCIAL_INSTAGRAM_COOKIES_FILE` or `INSTAGRAM_COOKIES_FILE` points to the active valid cookie file.

Fix: resolve cookie candidates from env first, then fall back to defaults. Add tests for env-driven paths.

### ME-008 - `build:turbo` Bypasses Safe Build Guard

Location: `TRR-APP/apps/web/package.json:12`, `TRR-APP/apps/web/package.json:13`, `TRR-APP/apps/web/scripts/safe-next-build.mjs:65`

Impact: `build` uses the safe wrapper, but `build:turbo` runs raw `next build --turbopack`, bypassing memory/swap and explicit-approval checks.

Fix: route `build:turbo` through `safe-next-build.mjs` with a mode flag.

### ME-009 - Supabase Advisor Residuals Still Need Owner Decisions

Location: live Supabase advisor output; related docs under `docs/workspace/supabase-rls-grants-review.md`

Impact: security advisors currently report mutable search paths for `admin.set_updated_at` and `firebase_surveys.set_updated_at`, `vector` installed in `public`, and the public survey RPC warnings. Performance advisors report new unindexed FKs on Instagram relationship/following snapshot tables plus many unused-index candidates.

Fix: create a dated advisor delta and owner decisions before applying DDL. Prioritize `SECURITY DEFINER` grants and search-path hardening before unused-index cleanup.

## Low

### LO-001 - `dev-hybrid` Docs Have Stale Social Caps

Location: `docs/workspace/dev-commands.md:15`, `Makefile:53`

Impact: docs say comments/platform cap `3`, but `make dev-hybrid` now uses comments `8` and Instagram platform cap `8`.

Fix: update docs and related operator notes with the current caps.

### LO-002 - Draft Plan Has Wrong App Validation Command After `cd TRR-APP`

Location: `plan.md:135`

Impact: the plan says `cd /Users/thomashulihan/Projects/TRR/TRR-APP` then runs `pnpm -C TRR-APP/apps/web run validate:quick`, which points to a nested non-existent path.

Fix: either keep the workspace-root command, or after `cd TRR-APP` use `pnpm -C apps/web run validate:quick`.

## Superseded Prior Review Items

These were present in the earlier review package but are no longer current findings:

- Build-safety commands in `.codex/rules/trr-project.md` now use `TRR-APP/apps/web`.
- `scripts/check-workspace-contract.sh` now runs `bash -n` separately for hygiene scripts.
- `scripts/env_contract_report.py` no longer uses `--no-ignore-vcs` and no longer writes raw matching env lines into `env-deprecations.md`.
- Blocked-auth catalog recovery now routes by `repair_action` through `getCatalogRepairAuthEndpointSegment()`.
