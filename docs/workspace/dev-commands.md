# Workspace Dev Commands

Use these commands from `/Users/thomashulihan/Projects/TRR`.

## Preferred Contract
- `make dev` is the default social-scraping runtime: local `TRR-APP` and `TRR-Backend`, Modal/remote social workers enabled, and Portless app/admin/API URLs.
- All workspace `make dev*` launchers publish the app, admin, and API through Portless. `local`, `cloud`, `hybrid`, Redis, and media-safe variants change worker and DB behavior only; they do not create separate portful browser URLs.
- `make dev-local` is the local-only worker escape hatch: local `TRR-APP`, local `TRR-Backend`, direct DB lane, remote workers disabled, Modal dispatch disabled, and the same Portless app/admin/API URLs.
- `make dev-cloud` is the explicit cloud/remote-worker path and remains on the session/pooler DB lane with the same Portless app/admin/API URLs.
- `make dev-hybrid` is the explicit name for the default `make dev` path: local app/backend on the direct DB lane while allowing Modal/remote workers on the session/pooler lane, with the social-safe worker caps applied by default, and app/admin/API exposed through Portless clean URLs.
- Codex browser verification with `[@Browser](plugin://browser-use@openai-bundled)` defaults to `make dev-hybrid` unless the user specifies another startup target.
- `make dev-portless` is only the Wordle/separate-session launcher. It is not the normal TRR dev alternative; `make dev` already uses Portless.
- `make stop-portless` stops the managed Portless app/API/Wordle sessions.
- `make portless-repair` ensures the Portless proxy is in wildcard mode, removes stale static TRR aliases, syncs hosts, and prints the clean routes.
- `make open-admin` opens the clean Portless admin dashboard at `https://admin.trr.localhost`.
- `make next-devtools-mcp-status` checks the TRR-local Next.js DevTools MCP registration. Runtime diagnostics require a running Next.js dev server, normally from `make dev-hybrid` or `make dev-portless`.
- `make vercel-auth-doctor` checks whether the local Vercel CLI account can see the TRR team and `trr-app`.
- `make vercel-cleanup-doctor` scans the TRR app checkout for stale local Vercel links, including the old nested `web` project.
- `make vercel-link-trr` links `TRR-APP` to the `trr-app` Vercel project of record.
- `make vercel-preview-ready` checks the local Vercel project link, checks/enables Web Analytics and Speed Insights, and writes the latest deployment URL for the `trr-app` project without deploying. The local Vercel CLI must be logged into the TRR team scope.
- `local-cloud` is the canonical profile behind `make dev`. `default`, `local-lite`, and `local-full` remain compatibility profiles only.

## Daily Commands
- `make dev` — recommended default workspace startup for social scraping tests with Modal/Scrapling behavior; exposes app/admin/API at `https://trr.localhost`, `https://admin.trr.localhost`, and `https://api.trr.localhost`
- `make dev-local` — local-only app/backend startup with direct DB lane, Modal/remote workers disabled, and app/admin/API exposed through Portless
- `make dev-redis` — start local Redis, then run local-only app/backend with `PROFILE=local-redis`, `REDIS_URL=redis://127.0.0.1:6379/0`, two FastAPI workers, and app/admin/API exposed through Portless
- `make redis-up` / `make redis-down` — start or stop only the local Redis container from `docker-compose.redis.yml`
- `make dev-cloud` — explicit cloud/remote worker startup using the session/pooler DB lane and app/admin/API exposed through Portless
- `make dev-hybrid` — explicit alias for the default hybrid social mode; enables remote social workers with `WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1`, comments `8`, Instagram posts/comments platform cap `8`, post media mirror `1`, and comment media mirror `1`; exposes app/admin/API at `https://trr.localhost`, `https://admin.trr.localhost`, and `https://api.trr.localhost`
- `make dev-hybrid-media-safe` — Portless hybrid mode that blocks startup when stale media claims remain, then starts post media mirror `2` and comment media mirror `2`
- `make dev-hybrid-media-safe-posts` — Portless media-safe startup biased toward post media mirror lanes; uses post media mirror `3` and comment media mirror `1`
- `make dev-hybrid-media-safe-comments` — Portless media-safe startup biased toward comment media mirror lanes; uses post media mirror `1` and comment media mirror `3`
- `make dev-hybrid-media-safe-bravotv` — Portless Bravo pending-media drain preset; blocks on stale media claims, then starts post discovery `0`, comments `2`, post media mirror `4`, and comment media mirror `1`
- `make dev-hybrid-social-safe` — compatibility alias for `make dev-hybrid`
- `make dev-portless` — start the Next.js app, FastAPI backend, and Wordle through separate Portless-managed sessions (`https://trr.localhost`, admin at `https://admin.trr.localhost`, backend at `https://api.trr.localhost`, Wordle at `https://wordle.trr.localhost`)
- `make stop-portless` — stop the managed Portless web/API/Wordle sessions
- `make portless-repair` — repair clean local URL routing by removing stale TRR static aliases and preserving admin routing through Portless wildcard forwarding
- `make open-admin` — open the clean Portless admin dashboard (`https://admin.trr.localhost`)
- `PROFILE=social-debug make dev` — tracked low-pressure social-profile validation lane; uses the same launcher but projects reduced app pool settings and lighter social dispatch caps without relying on ignored app-local env files
- Instagram backfill operator runbook: `/Users/thomashulihan/Projects/TRR/docs/workspace/instagram-backfill-runbook.md`
- Social profile dashboard runbook: `/Users/thomashulihan/Projects/TRR/docs/workspace/social-profile-dashboard.md`
- `make preflight` — local startup gate; warns on malformed handoff source docs and stale generated env docs but still blocks on runtime-affecting issues
- `make preflight-strict` — blocking validation path for malformed handoff source docs and env-contract drift
- `make handoff-check` — canonical blocking handoff/status snapshot validator
- `make env-contract` — refresh `docs/workspace/env-contract.md`
- `make env-contract-report` — refresh the env-contract inventory/deprecation review docs intentionally
- `make supabase-advisor-snapshot` — capture dated Supabase Security and Performance Advisor JSON plus a redacted manifest under `docs/workspace/supabase-advisor-snapshots/`; uses `TRR_SUPABASE_ACCESS_TOKEN`
- `make supabase-preview-branch-cleanup` — dry-run old Supabase preview branch cleanup; use `DELETE=1` only after the candidate list is correct; uses `TRR_SUPABASE_ACCESS_TOKEN`
- `cd TRR-Backend && .venv/bin/python scripts/db/index_advisor_social_hot_paths.py --dry-run` — list social/admin hot-path `index_advisor` query labels without connecting to the database
- Admin performance tools runbook: `/Users/thomashulihan/Projects/TRR/docs/workspace/admin-performance-tools.md`
- Admin performance report template: `/Users/thomashulihan/Projects/TRR/docs/workspace/admin-performance-report-template.md`
- `pnpm -C TRR-APP/apps/web run perf:admin:sitespeed:bravotv` — run sitespeed.io page-load evidence for the Bravo TV admin social profile; writes `.artifacts/perf/sitespeed/<timestamp>/` and updates `.artifacts/perf/sitespeed/latest`
- `pnpm -C TRR-APP/apps/web run perf:admin:sitespeed:cast` — run sitespeed.io page-load evidence for `/cast` and `/summer-house/credits`
- `pnpm -C TRR-APP/apps/web run perf:admin:api -- --preset social-snapshot --max-p95-ms 1000 --max-p99-ms 2000` — run a low-concurrency autocannon benchmark with optional latency threshold exits; writes `.artifacts/perf/autocannon/<timestamp>/` and updates `.artifacts/perf/autocannon/latest`
- `pnpm -C TRR-APP/apps/web run perf:bundle` — run Next.js `experimental-analyze --output`; copies analyzer output to `.artifacts/perf/bundle/<timestamp>/` and updates `.artifacts/perf/bundle/latest`
- `pnpm -C TRR-APP/apps/web run perf:react-scan` — start the local app with dev-only React Scan enabled for client render diagnostics
- `make status` — workspace health and PID snapshot
- `make status-json` — workspace health and PID snapshot as JSON
- `make db-pressure-rehearsal` — local-only DB pressure capture; writes redacted before/after artifacts under `.logs/workspace/`
- `make stop` — stop workspace-managed processes
- `make app-validate-quick` — lightweight TRR-APP generated-contract and safe-build-wrapper validation
- `make test-fast`
- `make test-full`
- `make test-changed`
- `make codex-check`
- `make git-branch-report` — report local/remote branch refs outside `main`; read-only cleanup preflight
- `make vercel-auth-doctor` — check local Vercel CLI access to the TRR team/project
- `make vercel-cleanup-doctor` — scan for stale local Vercel project links such as the old nested `web` project
- `make vercel-link-trr` — link the app checkout to the `trr-app` Vercel project
- `make vercel-preview-ready` — check the local Vercel link, Web Analytics, Speed Insights, and latest deployment URL for preview readiness; requires local Vercel CLI access to the TRR team
- `make doctor-json`
- `make context7-repair`
- `make chrome-repair`
- `make next-devtools-mcp-status` — validate the TRR-local Next.js DevTools MCP registration; runtime diagnostics are available after starting a Next.js dev server
- `make bravo-straggler-recovery` — dry-run or execute the approved Bravo Instagram straggler comments runner from `BRAVO_RECOVERY_ARGS`; accepts `--shortcode` or `--approved-shortcodes-file`
- `make instagram-media-mirror-recovery` — recover stale run-scoped media mirror jobs after reviewing the plan; requires `RUN_ID=...`, and apply mode requires `APPLY=1 CONFIRM_APPLY='RECOVER MEDIA MIRROR JOBS'`
- `make instagram-one-post-media-mirror` — run one exact Instagram post media mirror job locally or on Modal; use `JOB_ID=...`, `POST_ID=...`, `SOURCE_ID=...`, or `SHORTCODE=...`; add `DRY_RUN=1`, `JSON=1`, or `MODAL=1` as needed
- `make social-queue-snapshot` — write a timestamped queue snapshot under `.logs/workspace/social-queue-snapshots/`; use `RUN_ID=... STAGE=media_mirror JSON=1`
- `make mcp-clean`
- `make help`

## Social Media Queue Recovery

Use the Social Analytics Media Queue panel first when the admin app is running. It shows recent media runs, stale media counts, oldest queued media jobs, recovery history for actions from the panel, and links to saved queue snapshots under `.logs/workspace/social-queue-snapshots/`.

CLI recovery flow:
1. Capture the current run/stage queue state:
   ```bash
   RUN_ID=<social.scrape_runs id> STAGE=media_mirror JSON=1 make social-queue-snapshot
   ```
2. Dry-run stale media recovery:
   ```bash
   RUN_ID=<social.scrape_runs id> STAGE=media_mirror make instagram-media-mirror-recovery
   ```
3. Apply only after the dry-run scope is correct:
   ```bash
   RUN_ID=<social.scrape_runs id> STAGE=media_mirror APPLY=1 CONFIRM_APPLY='RECOVER MEDIA MIRROR JOBS' make instagram-media-mirror-recovery
   ```
4. Start the higher-throughput worker preset after stale media claims are clear:
   ```bash
   make dev-hybrid-media-safe
   ```
5. Smoke one exact queued post media job locally:
   ```bash
   JOB_ID=<social.scrape_jobs id> DRY_RUN=1 JSON=1 make instagram-one-post-media-mirror
   JOB_ID=<social.scrape_jobs id> make instagram-one-post-media-mirror
   ```
6. Resolve the same one-post command by post or shortcode:
   ```bash
   POST_ID=<social.instagram_posts id> ACCOUNT_HANDLE=bravotv make instagram-one-post-media-mirror
   SHORTCODE=<instagram-shortcode> ACCOUNT_HANDLE=bravotv make instagram-one-post-media-mirror
   ```
7. Run the exact one-post smoke on deployed Modal:
   ```bash
   JOB_ID=<social.scrape_jobs id> MODAL=1 JSON=1 make instagram-one-post-media-mirror
   ```
8. Drain Bravo pending post-media work after stale media claims are clear:
   ```bash
   make dev-hybrid-media-safe-bravotv
   ```

Use `make dev-hybrid-media-safe-posts` when post media is the bottleneck, or `make dev-hybrid-media-safe-comments` when comment media is the bottleneck. Use the Bravo preset only when the operator is intentionally draining pending Bravo post-media work. Set `ALLOW_STALE_MEDIA=1` only when an operator intentionally wants to bypass the stale-media startup guard.

## Git Branch Cleanup

TRR defaults to one active workspace version at a time. Edit docs, plans, scripts, and implementation files on the currently checked-out branch, normally `main`, unless the user explicitly says: `create a new branch named <branch>`.

Use this read-only report before merge/delete decisions:

```bash
make git-branch-report
```

The report shows:
- extra local branches outside `main`
- extra remote branches outside `origin/main`
- whether each branch has the same file tree as `main`
- whether Git sees the branch as an ancestor of `main`
- a short changed-file sample when the branch tree differs

Cleanup flow:
1. Keep desired content on `main`.
2. Run `make git-branch-report`.
3. Delete redundant local branches after their desired content is on `main`.
4. Delete redundant remote branches after confirming no open work depends on them.
5. Keep docs/plans on `main`; do not create a branch just to edit planning or runbook files.

Common cleanup commands:

```bash
git branch -d <local-branch>
git branch -D <local-branch>   # only after confirming desired content is already on main
git push origin --delete <remote-branch>
git fetch --prune
```

Startup preflight runs the branch report in warning-only mode. Extra branches should be cleaned up, but they do not block normal local startup.

## Supabase Preview Branch Cleanup

Supabase preview branches are separate database environments, not Git branches. Use them for isolated schema or migration checks, then delete them when the check is done. Keep long-lived environments as explicit persistent branches instead of ordinary preview branches.

Naming rule:
- Use `purpose-ticket-or-date`, for example `schema-docs-0199`, `migration-20260617-social-index`, or `rls-policy-20260617`.
- Include the practical purpose first so dashboard cleanup is obvious.
- Do not use `main`, `prod`, `production`, `stage`, or `staging` for disposable preview branches.

Delete a preview branch when:
- its validation task is complete and the desired migration/docs result is already preserved on `main`;
- its migration status is failed and no one needs the branch-specific logs anymore;
- it is older than 30 days and not marked persistent;
- it has no active merge request, app env, worker, or local runbook pointing at the preview project ref.

Do not delete when:
- the branch is the production/default branch;
- the branch is persistent staging or QA infrastructure;
- a current migration investigation needs its logs, schema state, or preview project ref.

Dry-run cleanup command:

```bash
make supabase-preview-branch-cleanup
```

Apply deletion after reviewing the candidate list:

```bash
DELETE=1 make supabase-preview-branch-cleanup
```

Target one branch by name or ID:

```bash
SUPABASE_BRANCH_CLEANUP_ARGS='--name schema-docs-0199' make supabase-preview-branch-cleanup
DELETE=1 SUPABASE_BRANCH_CLEANUP_ARGS='--name schema-docs-0199' make supabase-preview-branch-cleanup
```

The cleanup script intentionally reads `TRR_SUPABASE_ACCESS_TOKEN`. It maps that token into the Supabase CLI subprocess because the CLI expects `SUPABASE_ACCESS_TOKEN`; do not export or document generic `SUPABASE_ACCESS_TOKEN` as the TRR operator contract.

## Fallback / Specialized Commands
- `make dev-local` — local-only app/backend fallback when Modal and remote workers should stay disabled
- `make down` — retained no-op for old local infra cleanup muscle memory
- `make bootstrap` — one-time dependency setup
- `make app-check` — enforce the Node 24 baseline, then run TRR-APP lint and typecheck from the repo root
- `bash scripts/codex-config-sync.sh bootstrap` — bootstrap minimal user-level `~/.codex` files without reapplying TRR project config there

## Vercel Observability And Preview Readiness

TRR's Vercel project of record is `trr-app` under the `the-reality-reports-projects` team. The old nested `web` project is not the production project of record.

Enable or confirm Vercel dashboard observability for the project of record. These commands require local Vercel CLI access to the TRR team scope:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
./scripts/vercel.sh project web-analytics trr-app --scope the-reality-reports-projects --format json
./scripts/vercel.sh project speed-insights trr-app --scope the-reality-reports-projects --format json
```

Check local Vercel auth and link the checkout:

```bash
make vercel-auth-doctor
make vercel-cleanup-doctor
make vercel-link-trr
```

Check preview readiness without deploying; the command writes a timestamped JSON artifact under `.logs/workspace/vercel-preview-ready/`, updates `latest.json`, and includes `latestDeploymentUrl` plus the raw deployment-list command output:

```bash
make vercel-preview-ready
```

If the command reports `classification=missing-project-link`, link the local TRR app to the project of record first:

```bash
make vercel-link-trr
```

If Vercel reports `The specified scope does not exist` or only lists personal projects, run `vercel login` with the account that belongs to `the-reality-reports-projects`, then rerun the setup commands above.

First production data checklist after Web Analytics and Speed Insights are enabled:

- Confirm the latest preview readiness artifact reports Web Analytics `enabled` and Speed Insights `enabled`.
- Ship a production deployment from the `trr-app` project of record, not the old nested `web` project.
- Open the production site and one admin route with the TRR admin account so Vercel receives real pageview and performance samples.
- In the Vercel dashboard, confirm Web Analytics shows production pageviews for `trr-app`.
- In the Vercel dashboard, confirm Speed Insights shows production field data such as LCP, CLS, or INP once Vercel has enough traffic to report it.
- If either dashboard stays empty, check the latest artifact, the production deployment target, the app layout observability components, and Vercel project/team scope before changing code.

Old `web` project cleanup note:

- Run `make vercel-cleanup-doctor` before and after cleanup so stale local links are visible.
- Treat the nested `web` Vercel project as stale unless a live dashboard check proves it still owns a needed domain, env var, integration, or deployment history.
- Do not point TRR-APP deploys, Analytics, Speed Insights, env updates, or preview-readiness checks at `web`.
- Delete or archive the old `web` project only after confirming there are no domains, active integrations, or retained env values that still need migration to `trr-app`.
- If cleanup is approved, remove any stale local `.vercel` links that still identify `web`, then delete/archive the project from the Vercel dashboard or CLI under the correct TRR team scope.

## Bravo Recovery Runner

Use this for approved Bravo Instagram stragglers only. It plans from a shortcode
list or an evidence/markdown shortlist, runs an anchor-scoped post-details/media
follow-up for those exact shortcodes, then runs the public-first comments retry.
It does not run broad account catalog recovery.

Dry-run the plan:

```bash
BRAVO_RECOVERY_ARGS='--approved-shortcodes-file TRR-Backend/docs/ai/evidence/instagram-comments/bravotv_comments_evidence_latest.json --safe-12-workers' \
  make bravo-straggler-recovery
```

Execute only after the dry-run plan is correct:

```bash
BRAVO_RECOVERY_ARGS='--approved-shortcodes-file TRR-Backend/docs/ai/evidence/instagram-comments/bravotv_comments_evidence_latest.json --safe-12-workers --execute --confirm-execute "RUN BRAVO STRAGGLER RECOVERY"' \
  make bravo-straggler-recovery
```

Use repeated inline shortcodes for tiny operator-approved batches:

```bash
BRAVO_RECOVERY_ARGS='--shortcode SHORT_A --shortcode SHORT_B --safe-12-workers' \
  make bravo-straggler-recovery
```

Do not substitute broad `local_catalog_action.py`, `direct_catalog_backfill.py`,
or account-health repair scripts for this runner unless the current task
explicitly approves a wider catalog recovery.

## Codex Tooling Repair

- `make context7-repair` repairs raw or stale Context7 MCP config, reloads stale Context7 connector processes, verifies the installed plugin, checks installed/cache parity, and removes stale Context7 cache copies only after parity passes.
- `make chrome-repair` cleans stale browser MCP process state, starts or confirms the shared Chrome keeper, runs Chrome DevTools status including extension/native-host readiness, and prints the session reload hint for `Transport closed`.
- `bash scripts/doctor.sh` checks Context7 and Browser plugin runtime state without changing files by default.
- `bash scripts/doctor.sh --json` emits the doctor plugin registry as JSON. Each result includes `status`, `label`, `required`, `needs_repair`, `repairable`, `repair_hint`, and live MCP validation fields.
- `make doctor-json` is the Make wrapper for `bash scripts/doctor.sh --json`. `make doctor DOCTOR_ARGS=--json` is also supported.
- `WORKSPACE_DOCTOR_PLUGIN_REPAIR=1 bash scripts/doctor.sh` enables explicit self-heal for repairable plugin runtime issues. Today that covers Context7 wrapper config, Browser/chrome-devtools stale managed runtime artifacts, and safe TRR project MCP config drift for Supabase and Modal.
- `make status-json` and `make status STATUS_ARGS=--json` include Context7 wrapper status, Context7 cache parity, and the full doctor plugin registry under `codex_runtime.plugin_registry`.

New doctor plugin checks should be added to `DOCTOR_PLUGIN_REPAIR_REGISTRY` in `scripts/lib/doctor-plugin-registry.sh` with a matching `doctor_plugin_<name>_check` function. Add a `doctor_plugin_<name>_repair` function only when the fix is deterministic, safe to run without secrets, and gated by `WORKSPACE_DOCTOR_PLUGIN_REPAIR=1`.

Example registry entry:

```bash
DOCTOR_PLUGIN_REPAIR_REGISTRY=(
  context7
  example
)

doctor_plugin_live_mcp_expected_name() {
  case "$1" in
    example) echo "example-mcp" ;;
    *) echo "" ;;
  esac
}

doctor_plugin_example_check() {
  local label
  if label="$(doctor_plugin_enabled_status "example@local-plugins" "$HOME/.codex/plugins/cache/local-plugins/example/*/.codex-plugin/plugin.json")"; then
    DOCTOR_PLUGIN_LABEL="$label"
  else
    DOCTOR_PLUGIN_LABEL="$label"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="enable example@local-plugins in ~/.codex/config.toml"
  fi
}
```

Safe project MCP repair example:

```bash
doctor_plugin_supabase_repair() {
  # Only write known, non-secret config values. Secrets should stay as env var names.
  doctor_plugin_repair_project_mcp_config supabase
}
```

## Codex Service Tier

The installed Codex CLI currently accepts these top-level `service_tier` values in `~/.codex/config.toml`:

| Value | Use |
|---|---|
| `fast` | Preferred default for normal interactive work. |
| `flex` | Lower-priority/flexible execution when latency matters less. |

Do not use `default` or `priority`; the current CLI rejects them during `codex-check`.

For app-only validation, prefer `make app-check` for lint/typecheck and
`make app-validate-quick` for generated-contract and safe-build-wrapper checks.
Both Make targets source the workspace Node baseline helper and activate
`.nvmrc` first; direct `pnpm` commands are valid only after the shell is already
on Node 24.

## TRR-APP Build Safety

Run `make app-validate-quick` before asking for or starting a full TRR-APP
production build. A full production build is required when a change touches
Next.js build behavior, app routing or middleware, server/client component
boundaries, generated app contracts, production env projection, or any app/API
contract that could fail only during `next build`. It is also required whenever
the user explicitly approves or requests production-build evidence for the
current change.

Do not run `pnpm -C TRR-APP/apps/web run build`, `cd TRR-APP && pnpm run
web:build`, `next build`, or an equivalent production build unless the user has
approved it in the current chat. Do not set `TRR_FORCE_BUILD=1` unless the user
explicitly approves that override in the current chat.

## Local Redis Profile

Use this only when you need to exercise Redis-backed FastAPI realtime fanout or local multi-worker behavior. The Redis container is local-only and stores no durable TRR state.

```bash
make redis-up
make dev-local PROFILE=local-redis
```

`make dev-redis` combines those two steps. Stop Redis with `make redis-down` when you are done. The `local-redis` profile sets `REDIS_URL=redis://127.0.0.1:6379/0`, keeps `TRR_BACKEND_RELOAD=0`, and requests `TRR_BACKEND_WORKERS=2` with `TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER=1`.

## Social Profile Dashboard Smoke

Assuming `TRR_ADMIN_BEARER_TOKEN` is set:

```bash
curl -sS \
  -H "Authorization: Bearer ${TRR_ADMIN_BEARER_TOKEN}" \
  "http://localhost:8000/api/v1/admin/socials/profiles/instagram/thetraitorsus/dashboard?detail=lite" \
  | jq '{freshness, has_summary: (.data.summary != null), has_progress: (.data.catalog_run_progress != null)}'
```

## Remaining Docker-Only Cases
- `TRR-Backend make schema-docs-reset-check` — backend-local replay fallback when an isolated remote validation target does not answer the reset/replay question
- `TRR-Backend make ci-local` — Docker-backed local replay parity lane for intentionally local-only backend verification

Use `make dev` for the normal TRR dev loop, especially social scraping tests that need Modal, Scrapling, and clean browser URLs. Use `make dev-local` only when the task explicitly needs local-only worker behavior with remote workers disabled. Use `make dev-cloud` when the task needs the explicit cloud/session path without local direct DB behavior. All of these keep the same Portless app/admin/API URLs.

`make dev-hybrid` remains as the explicit name for the default `make dev` path. Use `make dev-portless` only when Wordle or separate Portless-managed screen sessions are the target; it is not a separate URL mode for normal TRR dev.

Use `/Users/thomashulihan/Projects/TRR/docs/workspace/portless-clean-urls.md` as the shared Portless runbook snippet. It owns the current clean app, admin, API, and repair URLs.

## Quick URLs
- Portless app: `https://trr.localhost`
- Portless admin: `https://admin.trr.localhost`
- Portless backend: `https://api.trr.localhost`
- Portless Wordle: `https://wordle.trr.localhost`

Use subdomain-first admin URLs for browser work: `https://admin.trr.localhost/<slug>`.
Do not use path-first admin URLs such as `https://trr.localhost/admin/<slug>` as
the clean local target. Do not use classic portful app/admin URLs as active
runbook examples for workspace make targets.

The local-only `make dev-local` profile launches only TRR-APP and TRR-Backend. Screenalytics remains an admin feature label in the app, not a separately managed local runtime.

Flashback live gameplay is currently disabled and `/flashback`, `/flashback/cover`, and `/flashback/play` redirect to `/hub`, so legacy browser-only Flashback envs are not part of the normal `make dev` startup contract.

The backend auto-restart path is now liveness-based. A transient Supabase/DNS issue can still make backend readiness (`/health`) degrade, but the workspace watchdog should only recycle the process when backend liveness (`/health/live`) fails.

If preflight warns about malformed handoff source docs, fix the cited file and rerun `make handoff-check` or `make preflight-strict`. Default local startup intentionally continues so ordinary backend/app work is not blocked by continuity-note formatting mistakes.

If preflight warns that generated env-contract docs are stale, refresh them intentionally with `make env-contract` or `make env-contract-report` and rerun `make preflight` when you want the repo baseline updated. Normal non-strict startup no longer rewrites those tracked docs automatically.

Browser automation warnings now come from the same structured readiness states used by `make chrome-devtools-mcp-status`: `ready`, `degraded`, `recoverable`, and `unavailable`. A missing shared `9422` keeper with working auto-launch remains a recoverable state, not an unavailable one.

The default `make dev` path uses Modal-owned dispatch for shared-account Instagram `Sync Recent`, `Resume Tail`, and `Backfill Posts`. Use `make dev-local` only when long jobs should stay local.

For migration or schema validation, prefer an isolated Supabase branch or disposable database target and point `TRR_DB_URL` there before running backend verification commands. Do not aim destructive replay or reset flows at shared persistent databases.

Shared-schema migration ownership is documented in `/Users/thomashulihan/Projects/TRR/docs/workspace/migration-ownership-policy.md`; check new app migrations with `make migration-ownership-lint`.

`make dev` includes a startup runtime-reconcile phase before app/backend launch. It validates direct DB identity before any migration apply or repair decision, can auto-apply only a bounded allowlisted Supabase migration suffix, and does not auto-run `supabase migration repair`, schema-doc checks, Render deploys, or tracked-doc refreshes.

If runtime reconcile blocks on Supabase history drift, use `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/runbooks/supabase_migration_history_repair.md`. If runtime reconcile blocks on Modal, inspect `python TRR-Backend/scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram` for blocking readiness, then add `--probe-getty-remote-access` when you want advisory Getty transport diagnostics. `make status` now surfaces the nested Getty probe under the Modal runtime section. Render and Decodo checks remain advisory-only and are surfaced there as well.

When running Modal readiness from `TRR-Backend`, prefer `.venv/bin/python scripts/modal/verify_modal_readiness.py --json`. The readiness entrypoint also re-execs into `TRR-Backend/.venv/bin/python` when launched with system `python3.11`, so dependency loading stays tied to the repo environment.

For startup tuning and env overrides, see `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`.

For Supabase pressure diagnosis, use `/Users/thomashulihan/Projects/TRR/docs/workspace/db-pressure-runbook.md`. For connection terminology and ownership language, use `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-glossary.md`.

For plan or remediation evidence, use `make supabase-advisor-snapshot` before
claiming current Supabase Advisor state. The exact token/env contract is
documented in `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-snapshot-workflow.md`.

For social/admin index recommendation evidence, use
`cd TRR-Backend && .venv/bin/python scripts/db/index_advisor_social_hot_paths.py --output-date YYYY-MM-DD`
after an approved dated review. The helper uses `TRR_DB_SESSION_URL`, then
`TRR_DB_URL`, then `TRR_DB_FALLBACK_URL`; it writes redacted reports under
`docs/workspace/` and never executes advisor-returned DDL.
