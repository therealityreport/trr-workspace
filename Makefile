.PHONY: \
	dev dev-lite dev-cloud dev-hybrid dev-hybrid-bg dev-hybrid-social-safe dev-portless dev-local dev-full dev-redis \
	preflight preflight-local preflight-cloud preflight-hybrid preflight-strict preflight-diagnostics env-contract env-contract-report env-hygiene check-policy codex-check handoff-check handoff-sync smoke browser-smoke-admin-details status status-json backend-restart-diagnose stop logs logs-prune cleanup-disk help \
	app-direct-sql-inventory redacted-env-inventory vercel-project-guard migration-ownership-lint rls-grants-snapshot db-pressure-rehearsal supabase-mcp-access supabase-advisor-snapshot \
	bootstrap doctor doctor-json app-check app-validate-quick test test-fast test-full test-changed test-env-sensitive \
	workspace-contract-check workspace-hygiene-report workspace-hygiene-clean-dry-run \
	cast-screentime-gap-check cast-screentime-live-check \
	redis-up redis-down down chrome-devtools-mcp-status chrome-devtools-mcp-clean-stale chrome-devtools-mcp-stop-conflicts node-repl-mcp-clean-stale codex-browser-transport-reset \
	context7-repair mcp-clean chrome-dock-clean \
	workspace-pr-agent \
	getty-server getty-tunnel getty-remote modal-instagram-auth-status modal-instagram-auth-repair \
	instagram-backfill-preflight instagram-posts-smoke instagram-posts-benchmark

DOCKER_COMPOSE ?= docker compose
REDIS_COMPOSE_FILE ?= docker-compose.redis.yml
REDIS_COMPOSE_PROJECT ?= trr-local-redis

# Daily default: `make dev` runs local TRR-APP + local TRR-Backend on the direct DB lane.
# Remote workers and Modal dispatch are disabled unless an explicit cloud/hybrid target is used.
# To override the default profile explicitly:
# PROFILE=default make dev
# make dev-cloud                      # explicit cloud/remote worker mode
# make dev-hybrid                     # local direct app/backend plus remote social-safe workers on session/pooler
# make dev-portless                   # app and API through stable Portless HTTPS names
# PROFILE=local-cloud make dev-cloud  # deprecated compatibility alias
# PROFILE=local-docker make dev-local # deprecated compatibility alias
# PROFILE=local-full make dev-local   # deprecated compatibility alias
# Startup tuning:
# WORKSPACE_CLEAN_NEXT_CACHE=1 make dev  # force clean Next.js cache
# WORKSPACE_TRR_APP_DEV_BUNDLER=webpack make dev  # force the webpack fallback if Turbopack regresses
# WORKSPACE_OPEN_BROWSER=1 make dev      # opt in to browser tab reuse/open on startup
# WORKSPACE_BACKEND_AUTO_RESTART=0 make dev  # disable backend process watchdog auto-restart (liveness-based; default profile enables it)
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reuse_no_reload make dev  # browser sync strategy when enabled
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_first make dev     # reload only the first matching tab
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_all make dev       # legacy behavior: reload every matching tab
# TRR_BACKEND_RELOAD=0 make dev          # opt out of backend hot-reload when you need non-reload stability
# TRR_ADMIN_ROUTE_CACHE_DISABLED=0 make dev  # re-enable local admin route caching if you want production-like staleness locally
dev:
	@$(MAKE) --no-print-directory preflight
	@PROFILE="$${PROFILE:-default}" WORKSPACE_DEV_MODE=local bash scripts/dev-workspace.sh

dev-redis:
	@$(MAKE) --no-print-directory redis-up
	@$(MAKE) --no-print-directory dev PROFILE=local-redis

# Compatibility alias for the canonical default path.
dev-lite:
	@echo "[workspace] NOTE: 'make dev-lite' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Explicit cloud/remote path.
dev-cloud:
	@$(MAKE) --no-print-directory preflight-cloud
	@PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=cloud bash scripts/dev-workspace.sh

# Explicit hybrid path: local app/backend use direct DB; Modal/remote workers use session/pooler.
# Social scraping is enabled with conservative post discovery and downstream fan-out.
dev-hybrid:
	@$(MAKE) --no-print-directory preflight-hybrid
	@WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
	WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
	WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8 \
	SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
	SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
	WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1 \
	PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=hybrid bash scripts/dev-workspace.sh

# Detached hybrid launcher for keeping the Modal-capable workspace alive after the shell exits.
dev-hybrid-bg:
	@mkdir -p .logs/workspace; \
	if [ -f .logs/workspace/pids.env ]; then \
		. .logs/workspace/pids.env; \
		if [ -n "$${WORKSPACE_MANAGER_PID:-}" ] && kill -0 "$${WORKSPACE_MANAGER_PID}" >/dev/null 2>&1; then \
			echo "[workspace] dev-hybrid already appears to be running (manager pid=$${WORKSPACE_MANAGER_PID})."; \
			make --no-print-directory status; \
			exit 0; \
		fi; \
	fi; \
	log_file=".logs/workspace/dev-hybrid-background.log"; \
	pid_file=".logs/workspace/dev-hybrid-background.pid"; \
	echo "[workspace] Starting detached make dev-hybrid in the background with Modal updates/workers allowed..."; \
	bg_pid="$$(/usr/bin/python3 scripts/dev-hybrid-bg-launch.py --log-file "$$log_file" --pid-file "$$pid_file" --cwd "$(CURDIR)")"; \
	echo "[workspace] Background pid=$$bg_pid"; \
	echo "[workspace] Log: $$log_file"; \
	echo "[workspace] Status: make status"; \
	echo "[workspace] Stop: make stop"

# Stable local HTTPS names through Portless. This target intentionally skips the
# workspace process manager because Portless owns the public local route names.
dev-portless:
	@bash -lc 'set -euo pipefail; export PATH="/opt/homebrew/bin:$$PATH"; if ! command -v portless >/dev/null 2>&1; then echo "[workspace] portless CLI was not found. Install/start Portless, then rerun make dev-portless." >&2; exit 127; fi; source "$(CURDIR)/scripts/lib/node-baseline.sh"; cd "$(CURDIR)/TRR-APP"; trr_pnpm "$(CURDIR)/TRR-APP" run dev:portless:all'

modal-instagram-auth-status:
	@cd TRR-Backend && \
	account_args=""; \
	if [ -n "$${ACCOUNT_HANDLE:-}" ]; then \
		account_handle="$$(printf '%s' "$${ACCOUNT_HANDLE}" | sed 's/^@//')"; \
		account_args="--probe-instagram-posts-auth=$$account_handle --probe-instagram-comments-auth=$$account_handle"; \
	fi; \
	env_arg=""; \
	if [ -n "$${MODAL_ENVIRONMENT:-}" ]; then env_arg="--env=$${MODAL_ENVIRONMENT}"; fi; \
	remote_probe_timeout="$${REMOTE_PROBE_TIMEOUT_SECONDS:-$${MODAL_INSTAGRAM_AUTH_STATUS_TIMEOUT_SECONDS:-45}}"; \
	modal_lookup_timeout="$${MODAL_LOOKUP_TIMEOUT_SECONDS:-$${MODAL_INSTAGRAM_AUTH_LOOKUP_TIMEOUT_SECONDS:-30}}"; \
	echo "[workspace] Instagram Modal auth status timeouts: modal_lookup=$$modal_lookup_timeout seconds, remote_probe=$$remote_probe_timeout seconds" >&2; \
	./.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram --remote-probe-timeout-seconds "$$remote_probe_timeout" --modal-lookup-timeout-seconds "$$modal_lookup_timeout" $$account_args $$env_arg

modal-instagram-auth-repair:
	@backend_dir="$${TRR_MODAL_BACKEND_DIR:-$(CURDIR)/TRR-Backend}"; \
	python_cmd="$${TRR_BACKEND_PYTHON:-$(CURDIR)/TRR-Backend/.venv/bin/python}"; \
	source_env="$${TRR_MODAL_SOURCE_ENV:-$$backend_dir/.env}"; \
	TRR_MODAL_BACKEND_DIR="$$backend_dir" TRR_MODAL_SOURCE_ENV="$$source_env" bash ./scripts/modal-billing-guardrail.sh; \
	cd "$$backend_dir" && \
	account_arg=""; \
	if [ -n "$${ACCOUNT_HANDLE:-}" ]; then account_arg="--account-handle=$${ACCOUNT_HANDLE}"; fi; \
	env_arg=""; \
	if [ -n "$${MODAL_ENVIRONMENT:-}" ]; then env_arg="--modal-environment=$${MODAL_ENVIRONMENT}"; fi; \
	dry_run_arg=""; \
	if [ "$${DRY_RUN:-0}" = "1" ]; then dry_run_arg="--dry-run"; fi; \
	echo "[workspace] Instagram Modal auth repair timeouts: validate=120s, refresh=420s, apply=180s, deploy=900s, verify=120s" >&2; \
	"$$python_cmd" scripts/modal/repair_instagram_auth.py --json $$account_arg $$env_arg $$dry_run_arg

instagram-backfill-preflight:
	@if [ -z "$${ACCOUNT_HANDLE:-}" ]; then echo "ERROR: set ACCOUNT_HANDLE=<instagram-handle>" >&2; exit 2; fi; \
	account_handle="$$(printf '%s' "$${ACCOUNT_HANDLE}" | sed 's/^@//' | tr '[:upper:]' '[:lower:]')"; \
	tmp_file="$$(mktemp)"; \
	trap 'rm -f "$$tmp_file"' EXIT; \
	remote_probe_timeout="$${REMOTE_PROBE_TIMEOUT_SECONDS:-$${MODAL_INSTAGRAM_AUTH_STATUS_TIMEOUT_SECONDS:-45}}"; \
	modal_lookup_timeout="$${MODAL_LOOKUP_TIMEOUT_SECONDS:-$${MODAL_INSTAGRAM_AUTH_LOOKUP_TIMEOUT_SECONDS:-30}}"; \
	echo "[workspace] Instagram Backfill Posts preflight for @$$account_handle" >&2; \
	echo "[workspace] Probing Modal readiness, posts auth, and comments auth separately." >&2; \
	cd TRR-Backend && \
	set +e; \
	./.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-instagram-posts-auth="$$account_handle" --probe-instagram-comments-auth="$$account_handle" --remote-probe-timeout-seconds "$$remote_probe_timeout" --modal-lookup-timeout-seconds "$$modal_lookup_timeout" > "$$tmp_file"; \
	verify_exit="$$?"; \
	set -e; \
	cat "$$tmp_file"; \
	python3 -c "import json, sys; data=json.load(open(sys.argv[1])); account=sys.argv[2]; posts=data.get('instagram_posts_auth_probe') or {}; comments=data.get('instagram_comments_auth_probe') or {}; core=[]; core += [] if data.get('app_found') else ['app_not_found']; core += ['missing_secret:' + str(x) for x in data.get('missing_secrets') or []]; core += ['missing_function:' + str(x) for x in data.get('missing_functions') or []]; core += ['missing_required_social_function:' + str(x) for x in data.get('missing_required_social_functions') or []]; core += ['missing_web_endpoint:' + str(x) for x in data.get('missing_web_endpoints') or []]; core += ['app_lookup_error:' + str(data.get('app_lookup_error'))] if data.get('app_lookup_error') else []; print('[workspace] Preflight summary: account=@' + account); print('[workspace] posts_auth: ' + ('ready' if posts.get('ready') else 'not_ready') + ' (' + str(posts.get('reason') or 'ok') + ')'); print('[workspace] comments_auth: ' + ('ready' if comments.get('ready') else 'not_ready') + ' (' + str(comments.get('reason') or 'ok') + ')'); (print('[workspace] BLOCKED: ' + ', '.join(core)) or sys.exit(1)) if core else None; (print('[workspace] BLOCKED: posts auth is not ready; do not launch Backfill Posts.') or sys.exit(1)) if not posts.get('ready') else None; (print('[workspace] WARNING: comments auth is blocked, but posts auth is ready. Posts listing may launch; comments follow-up is blocked until repaired.') or sys.exit(0)) if comments and not comments.get('ready') else None; print('[workspace] OK: posts auth is ready; comments auth is ready or not requested.')" "$$tmp_file" "$$account_handle"

instagram-posts-smoke:
	@if [ -z "$${ACCOUNT_HANDLE:-}" ]; then echo "ERROR: set ACCOUNT_HANDLE=<instagram-handle>" >&2; exit 2; fi; \
	account_handle="$$(printf '%s' "$${ACCOUNT_HANDLE}" | sed 's/^@//' | tr '[:upper:]' '[:lower:]')"; \
	max_pages="$${MAX_PAGES:-1}"; \
	fast_arg=""; \
	if [ "$${FAST:-0}" = "1" ]; then fast_arg="--fast"; fi; \
	echo "[workspace] Running bounded Instagram posts smoke for @$$account_handle (MAX_PAGES=$$max_pages)." >&2; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/instagram/smoke_posts_scrapling.py --account "$$account_handle" --max-pages "$$max_pages" $$fast_arg

instagram-posts-benchmark:
	@if [ -z "$${ACCOUNT_HANDLE:-}" ]; then echo "ERROR: set ACCOUNT_HANDLE=<instagram-handle>" >&2; exit 2; fi; \
	account_handle="$$(printf '%s' "$${ACCOUNT_HANDLE}" | sed 's/^@//' | tr '[:upper:]' '[:lower:]')"; \
	mode="$${MODE:-listing-only}"; \
	max_pages="$${MAX_PAGES:-3}"; \
	run_arg=""; \
	if [ -n "$${RUN_ID:-}" ]; then run_arg="--run-id $${RUN_ID}"; fi; \
	job_arg=""; \
	if [ -n "$${JOB_ID:-}" ]; then job_arg="--job-id $${JOB_ID}"; fi; \
	echo "[workspace] Emitting Instagram posts benchmark payload for @$$account_handle (MODE=$$mode, MAX_PAGES=$$max_pages)." >&2; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/instagram/benchmark_posts_backfill.py --account "$$account_handle" --mode "$$mode" --max-pages "$$max_pages" $$run_arg $$job_arg

# Compatibility alias for older social-safe muscle memory.
dev-hybrid-social-safe:
	@echo "[workspace] NOTE: 'make dev-hybrid-social-safe' is now an alias for 'make dev-hybrid'."
	@$(MAKE) --no-print-directory dev-hybrid PROFILE="$${PROFILE:-local-cloud}"

# Deprecated compatibility alias retained for older local muscle memory.
dev-local:
	@echo "[workspace] NOTE: 'make dev-local' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Deprecated compatibility alias retained for older local muscle memory.
dev-full:
	@echo "[workspace] NOTE: 'make dev-full' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

preflight:
	@WORKSPACE_DEV_MODE=local bash scripts/preflight.sh

preflight-local:
	@WORKSPACE_DEV_MODE=local bash scripts/preflight.sh

preflight-cloud:
	@WORKSPACE_DEV_MODE=cloud bash scripts/preflight.sh

preflight-hybrid:
	@WORKSPACE_DEV_MODE=hybrid bash scripts/preflight.sh

preflight-strict:
	@WORKSPACE_DEV_MODE=local WORKSPACE_PREFLIGHT_STRICT=1 WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 bash scripts/preflight.sh

preflight-diagnostics:
	@WORKSPACE_DEV_MODE=local WORKSPACE_PREFLIGHT_DIAGNOSTICS=1 bash scripts/preflight.sh

env-contract:
	@bash scripts/workspace-env-contract.sh --generate

env-contract-report:
	@python3 scripts/env_contract_report.py write

app-direct-sql-inventory:
	@python3 scripts/app-direct-sql-inventory.py --output docs/workspace/app-direct-sql-inventory.md

redacted-env-inventory:
	@python3 scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md

env-hygiene:
	@WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT=1 python3 scripts/workspace/env_hygiene.py --check

vercel-project-guard:
	@python3 scripts/vercel-project-guard.py --project-dir TRR-APP

migration-ownership-lint:
	@python3 scripts/migration-ownership-lint.py

rls-grants-snapshot:
	@cd TRR-Backend && ./.venv/bin/python scripts/db/rls_grants_snapshot.py --output ../docs/workspace/supabase-rls-grants-review.md

db-pressure-rehearsal:
	@bash scripts/db-pressure-rehearsal.sh

supabase-mcp-access:
	@python3 scripts/check-supabase-mcp-access.py

supabase-advisor-snapshot:
	@python3 scripts/capture-supabase-advisor-snapshot.py

check-policy:
	@bash scripts/check-policy.sh

codex-check:
	@bash scripts/check-codex.sh

handoff-check:
	@python3 scripts/sync-handoffs.py --check

handoff-sync:
	@python3 scripts/sync-handoffs.py --write
	@python3 scripts/sync-handoffs.py --check

smoke:
	@bash scripts/smoke.sh

browser-smoke-admin-details:
	@bash scripts/browser-smoke-admin-detail-routes.sh

# Workspace status snapshot (PIDs, ports, health).
STATUS_ARGS ?=
status:
	@bash scripts/status-workspace.sh $(STATUS_ARGS)

status-json:
	@bash scripts/status-workspace.sh --json

backend-restart-diagnose:
	@bash scripts/backend-restart-diagnose.sh

# Local Getty scraper server (residential IP). Required for Getty image scraping
# since Getty blocks cloud/datacenter IPs.  The admin UI calls this automatically
# when you click Get Images (Getty / NBCUMV).
# Usage: make getty-server  (default port 3456)
#        GETTY_PORT=8765 make getty-server
getty-server:
	@GETTY_PORT="$${GETTY_PORT:-3456}"; \
	if lsof -iTCP:"$$GETTY_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then \
		EXISTING_PID=$$(lsof -iTCP:"$$GETTY_PORT" -sTCP:LISTEN -t 2>/dev/null | head -1); \
		echo "[getty-server] Port $$GETTY_PORT already in use by PID $$EXISTING_PID — server is already running."; \
		echo "[getty-server] To restart: kill $$EXISTING_PID && make getty-server"; \
		echo "[getty-server] To use a different port: GETTY_PORT=8765 make getty-server"; \
	else \
		cd TRR-Backend && ./.venv/bin/python scripts/getty_local_server.py --port "$$GETTY_PORT"; \
	fi

# Cloudflare Tunnel — exposes the local Getty scraper at scraper.thereality.report.
# Run this alongside `make getty-server` to allow cloud/Vercel to reach the scraper.
# First-time setup:
#   brew install cloudflared && cloudflared tunnel login
#   cloudflared tunnel create getty-scraper
#   cloudflared tunnel route dns getty-scraper scraper.thereality.report
getty-tunnel:
	@cloudflared tunnel --config TRR-Backend/scripts/cloudflared-tunnel-config.yml run getty-scraper

# Starts both the Getty server and the Cloudflare Tunnel in parallel.
# If the server is already running, only the tunnel starts.
getty-remote:
	@$(MAKE) getty-server & $(MAKE) getty-tunnel & wait

# Stops workspace-managed processes only (from make dev).
stop:
	@bash scripts/stop-workspace.sh

logs:
	@bash scripts/logs-workspace.sh

logs-prune:
	@bash scripts/logs-prune.sh

cleanup-disk:
	@python3 scripts/cleanup-workspace-disk.py --dry-run

workspace-hygiene-report:
	@bash scripts/workspace/hygiene_report.sh

workspace-hygiene-clean-dry-run:
	@bash scripts/workspace/hygiene_clean.sh --dry-run

bootstrap:
	@bash scripts/bootstrap.sh

doctor:
	@bash scripts/doctor.sh $(DOCTOR_ARGS)

doctor-json:
	@bash scripts/doctor.sh --json

app-check:
	@bash scripts/app-check.sh

app-validate-quick:
	@bash -c 'set -euo pipefail; ROOT="$(CURDIR)"; source "$$ROOT/scripts/lib/node-baseline.sh"; trr_ensure_node_baseline_or_exit "app-validate-quick" "$$ROOT"; cd "$$ROOT/TRR-APP"; trr_pnpm "$$ROOT/TRR-APP" run web:validate:quick'

test:
	@bash scripts/test-full.sh

test-fast:
	@bash scripts/test-fast.sh

test-full:
	@bash scripts/test-full.sh

test-changed:
	@bash scripts/test-changed.sh

# Environment-sensitive regression gate across repos.
test-env-sensitive:
	@bash scripts/test-env-sensitive.sh

workspace-contract-check:
	@bash scripts/check-workspace-contract.sh

cast-screentime-gap-check:
	@bash scripts/cast-screentime-gap-check.sh

cast-screentime-live-check:
	@bash scripts/cast-screentime-live-check.sh

# Legacy no-op retained so older cleanup muscle memory does not fail.
down:
	@echo "[workspace] NOTE: local screenalytics infra is retired; nothing to tear down."

redis-up:
	@$(DOCKER_COMPOSE) -p "$(REDIS_COMPOSE_PROJECT)" -f "$(REDIS_COMPOSE_FILE)" up -d

redis-down:
	@$(DOCKER_COMPOSE) -p "$(REDIS_COMPOSE_PROJECT)" -f "$(REDIS_COMPOSE_FILE)" down

help:
	@echo "Workspace commands:"
	@echo "  make dev          - local TRR-APP + local TRR-Backend, direct DB lane, remote workers disabled"
	@echo "  make status       - workspace health and PID snapshot (STATUS_ARGS=--json for JSON)"
	@echo "  make status-json  - workspace health and PID snapshot as JSON"
	@echo "  make dev-redis    - start local Redis, then run make dev with PROFILE=local-redis"
	@echo "  make dev-cloud    - explicit cloud/remote worker path using session/pooler DB"
	@echo "  make dev-hybrid   - hybrid social mode: dispatch=8, concurrency=8, posts=1, comments=8, media=1, comment media=1"
	@echo "  make dev-hybrid-bg - starts Modal-capable make dev-hybrid detached, writing .logs/workspace/dev-hybrid-background.log"
	@echo "  make dev-hybrid-social-safe - alias for make dev-hybrid"
	@echo "  make dev-portless - app and API through stable Portless HTTPS names"
	@echo "  make modal-instagram-auth-status - bounded Instagram Modal auth probe (ACCOUNT_HANDLE=... adds posts/comments probes)"
	@echo "  make modal-instagram-auth-repair - bounded Instagram auth repair, secret refresh, deploy, and remote verify (DRY_RUN=1 plans only)"
	@echo "  make instagram-backfill-preflight - account-scoped posts/comments auth preflight (ACCOUNT_HANDLE=...)"
	@echo "  make instagram-posts-smoke - bounded live posts smoke (ACCOUNT_HANDLE=... MAX_PAGES=1; not a dry run)"
	@echo "  make instagram-posts-benchmark - emit bounded benchmark payload (ACCOUNT_HANDLE=... MODE=listing-only)"
	@echo "  make dev-local    - deprecated alias for make dev"
	@echo "  make preflight    - validates the local/direct workspace path"
	@echo "  make preflight-cloud - validates the explicit cloud/session path"
	@echo "  make preflight-hybrid - validates direct local plus session remote separation"
	@echo "  make env-contract - refresh docs/workspace/env-contract.md"
	@echo "  make env-contract-report - refresh env contract inventory/deprecation review docs"
	@echo "  make env-hygiene - validate env file authority classes without printing values"
	@echo "  make app-validate-quick - run the approved lightweight TRR-APP validation path"
	@echo "  make codex-check  - validates tracked Codex config, rules, and user bootstrap state"
	@echo "  make doctor-json  - plugin registry doctor output as JSON"
	@echo "  make context7-repair - repair Context7 MCP wrapper config, reload stale connector processes, and smoke test"
	@echo "  make browser-smoke-admin-details - smoke test social account and show detail routes in a browser"
	@echo "  make codex-browser-transport-reset - clean stale Codex Browser transport state"
	@echo "  make supabase-advisor-snapshot - capture dated Supabase advisor JSON artifacts"
	@echo "  make backend-restart-diagnose - prints backend restart/watchdog attribution state"
	@echo "  make redis-up     - start local Redis via docker-compose.redis.yml"
	@echo "  make redis-down   - stop local Redis via docker-compose.redis.yml"
	@echo "  make down         - deprecated no-op retained for compatibility"
	@echo "  make chrome-dock-clean - remove Google Chrome entries from macOS Dock recents"
	@echo "Legacy aliases:"
	@echo "  make dev-full     - deprecated alias for make dev"

chrome-devtools-mcp-status:
	@bash scripts/chrome-devtools-mcp-status.sh

chrome-devtools-mcp-clean-stale:
	@bash scripts/chrome-devtools-mcp-clean-stale.sh

node-repl-mcp-clean-stale:
	@NODE_REPL_CLEAN_PROJECT_OWNED=1 NODE_REPL_PROJECT_ROOT="$(CURDIR)" bash scripts/node-repl-mcp-clean-stale.sh

codex-browser-transport-reset:
	@bash scripts/codex-browser-transport-reset.sh

chrome-devtools-mcp-stop-conflicts:
	@bash scripts/chrome-devtools-mcp-stop-conflicts.sh

context7-repair:
	@bash scripts/context7-repair.sh

mcp-clean:
	@bash scripts/mcp-clean.sh

chrome-dock-clean:
	@bash scripts/cleanup-chrome-dock-recents.sh

# Repo commit/PR/review/merge automation agent for one repo or a repo set.
# Optional env overrides:
# WORKSPACE_PR_AGENT_REVISION_COMMAND='...'   # default uses scripts/workspace-pr-agent-revision.py
# WORKSPACE_PR_AGENT_REVISION_USE_CODEX=0     # disable Codex-assist within revision script
# WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=0   # default is 1 (MCP-preferred Codex prompt)
# WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1   # fail revision assist if GitHub MCP auth is missing
# WORKSPACE_PR_AGENT_REVISION_USE_VERCEL_MCP=0   # disable Vercel deployment-context lookup in revision assist
# WORKSPACE_PR_AGENT_DRY_RUN=1
# WORKSPACE_PR_AGENT_REPOS='TRR-APP' or 'TRR-Backend,TRR-APP'   # optional scope override; default auto-discovers workspace root + child repos
workspace-pr-agent:
	@bash scripts/workspace-pr-agent.sh
