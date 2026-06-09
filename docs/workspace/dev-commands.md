# Workspace Dev Commands

Use these commands from `/Users/thomashulihan/Projects/TRR`.

## Preferred Contract
- `make dev` is local-process-first: local `TRR-APP`, local `TRR-Backend`, direct DB lane, remote workers disabled, Modal dispatch disabled.
- `make dev-cloud` is the explicit cloud/remote-worker path and remains on the session/pooler DB lane.
- `make dev-hybrid` runs local app/backend on the direct DB lane while allowing Modal/remote workers on the session/pooler lane, with the social-safe worker caps applied by default.
- Codex browser verification with `[@Browser](plugin://browser-use@openai-bundled)` defaults to `make dev-hybrid` unless the user specifies another startup target.
- `make dev-portless` starts the app and API through Portless when stable local HTTPS names are more important than the workspace process manager.
- `PROFILE=default` is the canonical profile behind `make dev`. `local-cloud`, `local-lite`, and `local-full` remain compatibility profiles only.

## Daily Commands
- `make dev` — recommended default workspace startup (local app/backend, direct DB lane, Modal/remote disabled)
- `make dev-redis` — start local Redis, then run local app/backend with `PROFILE=local-redis`, `REDIS_URL=redis://127.0.0.1:6379/0`, and two FastAPI workers
- `make redis-up` / `make redis-down` — start or stop only the local Redis container from `docker-compose.redis.yml`
- `make dev-cloud` — explicit cloud/remote worker startup using the session/pooler DB lane
- `make dev-hybrid` — safe Instagram/social hybrid mode; enables remote social workers with `WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1`, comments `8`, Instagram posts/comments platform cap `8`, post media mirror `1`, and comment media mirror `1`
- `make dev-hybrid-social-safe` — compatibility alias for `make dev-hybrid`
- `make dev-portless` — start the Next.js app and FastAPI backend through Portless (`https://trr.localhost`, `https://api.trr.localhost`)
- `PROFILE=social-debug make dev` — tracked low-pressure social-profile validation lane; uses the same launcher but projects reduced app pool settings and lighter social dispatch caps without relying on ignored app-local env files
- Instagram backfill operator runbook: `/Users/thomashulihan/Projects/TRR/docs/workspace/instagram-backfill-runbook.md`
- Social profile dashboard runbook: `/Users/thomashulihan/Projects/TRR/docs/workspace/social-profile-dashboard.md`
- `make preflight` — local startup gate; warns on malformed handoff source docs and stale generated env docs but still blocks on runtime-affecting issues
- `make preflight-strict` — blocking validation path for malformed handoff source docs and env-contract drift
- `make handoff-check` — canonical blocking handoff/status snapshot validator
- `make env-contract` — refresh `docs/workspace/env-contract.md`
- `make env-contract-report` — refresh the env-contract inventory/deprecation review docs intentionally
- `make supabase-advisor-snapshot` — capture dated Supabase Security and Performance Advisor JSON plus a redacted manifest under `docs/workspace/supabase-advisor-snapshots/`; uses `TRR_SUPABASE_ACCESS_TOKEN`
- `cd TRR-Backend && .venv/bin/python scripts/db/index_advisor_social_hot_paths.py --dry-run` — list social/admin hot-path `index_advisor` query labels without connecting to the database
- `make status` — workspace health and PID snapshot
- `make status-json` — workspace health and PID snapshot as JSON
- `make db-pressure-rehearsal` — local-only DB pressure capture; writes redacted before/after artifacts under `.logs/workspace/`
- `make stop` — stop workspace-managed processes
- `make app-validate-quick` — lightweight TRR-APP generated-contract and safe-build-wrapper validation
- `make test-fast`
- `make test-full`
- `make test-changed`
- `make codex-check`
- `make doctor-json`
- `make context7-repair`
- `make mcp-clean`
- `make help`

## Fallback / Specialized Commands
- `make dev-local` — deprecated compatibility alias for `make dev`
- `make down` — retained no-op for old local infra cleanup muscle memory
- `make bootstrap` — one-time dependency setup
- `make app-check` — enforce the Node 24 baseline, then run TRR-APP lint and typecheck from the repo root
- `bash scripts/codex-config-sync.sh bootstrap` — bootstrap minimal user-level `~/.codex` files without reapplying TRR project config there

## Codex Tooling Repair

- `make context7-repair` repairs raw or stale Context7 MCP config, reloads stale Context7 connector processes, verifies the installed plugin, checks installed/cache parity, and removes stale Context7 cache copies only after parity passes.
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
make dev PROFILE=local-redis
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

If your task is ordinary backend/app development or milestone verification without browser-plugin verification, start with the local direct path. Use `make dev-cloud` or `make dev-hybrid` when the task explicitly needs Modal or remote worker behavior, or when Codex browser verification is requested or materially useful under the project rules.

Use `make dev-portless` when you need stable HTTPS local names, cookie/origin behavior tied to `trr.localhost`, or a browser flow that should not depend on changing numeric ports. Portless does not replace `make dev-hybrid` for Modal or remote-worker validation; it is the named-host local route for app/API checks.

## Quick URLs
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000`
- Portless app: `https://trr.localhost`
- Portless backend: `https://api.trr.localhost`

The default `make dev` profile now launches only TRR-APP and TRR-Backend. Screenalytics remains an admin feature label in the app, not a separately managed local runtime.

Flashback live gameplay is currently disabled and `/flashback`, `/flashback/cover`, and `/flashback/play` redirect to `/hub`, so legacy browser-only Flashback envs are not part of the normal `make dev` startup contract.

The backend auto-restart path is now liveness-based. A transient Supabase/DNS issue can still make backend readiness (`/health`) degrade, but the workspace watchdog should only recycle the process when backend liveness (`/health/live`) fails.

If preflight warns about malformed handoff source docs, fix the cited file and rerun `make handoff-check` or `make preflight-strict`. Default local startup intentionally continues so ordinary backend/app work is not blocked by continuity-note formatting mistakes.

If preflight warns that generated env-contract docs are stale, refresh them intentionally with `make env-contract` or `make env-contract-report` and rerun `make preflight` when you want the repo baseline updated. Normal non-strict startup no longer rewrites those tracked docs automatically.

Browser automation warnings now come from the same structured readiness states used by `make chrome-devtools-mcp-status`: `ready`, `degraded`, `recoverable`, and `unavailable`. A missing shared `9422` keeper with working auto-launch remains a recoverable state, not an unavailable one.

The default profile runs TRR long jobs locally. Shared-account Instagram `Sync Recent`, `Resume Tail`, and `Backfill Posts` use Modal-owned dispatch only through `make dev-cloud`, `make dev-hybrid`, or an explicit reviewed override.

For migration or schema validation, prefer an isolated Supabase branch or disposable database target and point `TRR_DB_URL` there before running backend verification commands. Do not aim destructive replay or reset flows at shared persistent databases.

Shared-schema migration ownership is documented in `/Users/thomashulihan/Projects/TRR/docs/workspace/migration-ownership-policy.md`; check new app migrations with `make migration-ownership-lint`.

`make dev` includes a startup runtime-reconcile phase before app/backend launch. It validates direct DB identity before any migration apply or repair decision, can auto-apply only a bounded allowlisted Supabase migration suffix, and does not auto-run `supabase migration repair`, schema-doc checks, Render deploys, or tracked-doc refreshes. Modal auto-deploy behavior belongs to explicit cloud/hybrid modes.

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
