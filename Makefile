.PHONY: \
	dev dev-lite dev-cloud dev-hybrid dev-architecture-refactor architecture-refactor-check dev-hybrid-bg dev-hybrid-media-safe dev-hybrid-media-safe-posts dev-hybrid-media-safe-comments dev-hybrid-media-safe-bravotv dev-hybrid-social-safe dev-portless stop-portless portless-status portless-repair open-admin dev-local dev-full dev-redis \
	preflight preflight-local preflight-cloud preflight-hybrid preflight-strict preflight-diagnostics env-contract env-contract-report env-hygiene architecture-contracts-check architecture-durable-contracts-check architecture-durable-candidate-check architecture-evidence-hygiene-check architecture-git-roots-check architecture-guard-tests architecture-hotspots-check architecture-release-manifests-check openapi-v2-contract-generate openapi-v2-contract-check runtime-capacity-check deployment-targets-check modal-invocation-check check-policy codex-check git-branch-report handoff-check handoff-sync smoke browser-smoke-admin-details status status-json backend-restart-diagnose stop logs logs-prune cleanup-disk help \
	app-direct-sql-inventory redacted-env-inventory vercel-project-guard vercel-auth-doctor vercel-cleanup-doctor vercel-link-trr vercel-preview-ready migration-ownership-lint rls-grants-snapshot db-pressure-rehearsal supabase-mcp-access supabase-advisor-snapshot supabase-preview-branch-cleanup \
	bootstrap doctor doctor-json app-check app-validate-quick test test-fast test-full test-changed test-env-sensitive \
	workspace-contract-check workspace-hygiene-report workspace-hygiene-clean-dry-run \
	cast-screentime-gap-check cast-screentime-live-check \
	redis-up redis-down down chrome-repair chrome-devtools-mcp-status chrome-devtools-mcp-clean-stale chrome-devtools-mcp-stop-conflicts next-devtools-mcp-status node-repl-mcp-clean-stale codex-browser-transport-reset \
	context7-repair mcp-clean chrome-dock-clean \
	getty-server getty-tunnel getty-remote modal-instagram-auth-status modal-instagram-auth-repair socialblade-auth-repair \
	instagram-backfill-preflight instagram-backfill-progress instagram-backfill-recover-stalled instagram-posts-smoke instagram-posts-benchmark bravo-straggler-recovery instagram-media-mirror-recovery instagram-one-post-media-mirror social-queue-snapshot

DOCKER_COMPOSE ?= docker compose
REDIS_COMPOSE_FILE ?= docker-compose.redis.yml
REDIS_COMPOSE_PROJECT ?= trr-local-redis

# Daily default: `make dev` runs the Modal-capable hybrid workspace with
# Portless app/admin/API URLs for social scraping work.
# To override the default profile explicitly:
# PROFILE=local-cloud make dev
# make dev-local                     # local-only app/backend, remote workers disabled
# make dev-cloud                      # explicit cloud/remote worker mode
# make dev-hybrid                     # local direct app/backend plus remote social-safe workers and Portless app/admin/API URLs
# make dev-hybrid-media-safe          # post-recovery hybrid mode with two media mirror lanes
# make dev-hybrid-media-safe-posts    # post media biased media-safe preset
# make dev-hybrid-media-safe-comments # comment media biased media-safe preset
# make dev-hybrid-media-safe-bravotv  # Bravo pending-media drain preset
# make dev-portless                   # Wordle/separate-session Portless launcher, not the normal TRR dev path
# make stop-portless                  # stop managed Portless app/API/Wordle sessions
# make portless-status                # print read-only Portless proxy, route, and Browser-test readiness
# make portless-repair                # repair Portless proxy state and remove stale static TRR aliases
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
	@$(MAKE) --no-print-directory dev-hybrid PROFILE="$${PROFILE:-local-cloud}"

dev-redis:
	@$(MAKE) --no-print-directory redis-up
	@$(MAKE) --no-print-directory dev-local PROFILE=local-redis

# Compatibility alias for the canonical default path.
dev-lite:
	@echo "[workspace] NOTE: 'make dev-lite' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Explicit cloud/remote path.
dev-cloud:
	@$(MAKE) --no-print-directory preflight-cloud
	@WORKSPACE_USE_PORTLESS_URLS=1 PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=cloud bash scripts/dev-workspace.sh

# Explicit hybrid path: local app/backend use direct DB; Modal/remote workers use session/pooler.
# Social scraping is enabled with conservative post discovery and downstream fan-out.
dev-hybrid:
	@if [ "$${PROFILE:-}" = "architecture-refactor" ]; then \
		$(MAKE) --no-print-directory dev-architecture-refactor; \
	else \
		$(MAKE) --no-print-directory preflight-hybrid && \
		WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
		WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
		WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
		WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1 \
		WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8 \
		SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
		SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
		WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1 \
		WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1 \
		WORKSPACE_USE_PORTLESS_URLS=1 \
		PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=hybrid bash scripts/dev-workspace.sh; \
	fi

dev-architecture-refactor:
	@bash scripts/architecture-refactor-preflight.sh
	@WORKSPACE_USE_PORTLESS_URLS=1 PROFILE=architecture-refactor WORKSPACE_DEV_MODE=local bash scripts/dev-workspace.sh

architecture-refactor-check:
	@bash scripts/architecture-refactor-preflight.sh
	@WORKSPACE_USE_PORTLESS_URLS=1 PROFILE=architecture-refactor WORKSPACE_DEV_MODE=local bash scripts/dev-workspace.sh --assert-no-side-effects

# Post-recovery hybrid path: keeps comments fast and allows two media mirror
# lanes now that stale media claims have been cleared.
dev-hybrid-media-safe:
	@allow_arg=""; \
	if [ "$${ALLOW_STALE_MEDIA:-0}" = "1" ]; then allow_arg="--allow-stale"; fi; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/media_queue_guard.py $$allow_arg
	@$(MAKE) --no-print-directory preflight-hybrid
	@WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
	WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
	WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8 \
	SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
	SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
	WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=2 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=2 \
	WORKSPACE_USE_PORTLESS_URLS=1 \
	PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=hybrid bash scripts/dev-workspace.sh

dev-hybrid-media-safe-posts:
	@allow_arg=""; \
	if [ "$${ALLOW_STALE_MEDIA:-0}" = "1" ]; then allow_arg="--allow-stale"; fi; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/media_queue_guard.py $$allow_arg
	@$(MAKE) --no-print-directory preflight-hybrid
	@WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
	WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
	WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8 \
	SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
	SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
	WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=3 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1 \
	WORKSPACE_USE_PORTLESS_URLS=1 \
	PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=hybrid bash scripts/dev-workspace.sh

dev-hybrid-media-safe-comments:
	@allow_arg=""; \
	if [ "$${ALLOW_STALE_MEDIA:-0}" = "1" ]; then allow_arg="--allow-stale"; fi; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/media_queue_guard.py $$allow_arg
	@$(MAKE) --no-print-directory preflight-hybrid
	@WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
	WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
	WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8 \
	SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
	SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
	WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=3 \
	WORKSPACE_USE_PORTLESS_URLS=1 \
	PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=hybrid bash scripts/dev-workspace.sh

dev-hybrid-media-safe-bravotv:
	@allow_arg=""; \
	if [ "$${ALLOW_STALE_MEDIA:-0}" = "1" ]; then allow_arg="--allow-stale"; fi; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/media_queue_guard.py $$allow_arg
	@$(MAKE) --no-print-directory preflight-hybrid
	@echo "[workspace] Starting Bravo pending-media drain preset: posts=0, comments=2, media=4, comment media=1." >&2
	@WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
	WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
	WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
	WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=0 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=2 \
	SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
	SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
	WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=4 \
	WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1 \
	TRR_SOCIAL_OPERATOR_PRESET=bravotv-pending-media-drain \
	WORKSPACE_USE_PORTLESS_URLS=1 \
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
# Web and API run in separate managed screen sessions so one side exiting does
# not tear down the other.
dev-portless:
	@bash scripts/dev-portless-managed.sh start

stop-portless:
	@bash scripts/dev-portless-managed.sh stop

portless-status:
	@bash scripts/portless-status.sh

portless-repair:
	@bash scripts/portless-repair.sh

open-admin:
	@open "https://admin.trr.localhost/"

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

socialblade-auth-repair:
	@if [ -z "$${ACCOUNT_HANDLE:-$${SOCIALBLADE_VALIDATION_HANDLE:-}}" ]; then echo "ERROR: set ACCOUNT_HANDLE=<real-instagram-handle> for SocialBlade validation" >&2; exit 2; fi
	@backend_dir="$${TRR_MODAL_BACKEND_DIR:-$(CURDIR)/TRR-Backend}"; \
	python_cmd="$${TRR_BACKEND_PYTHON:-$(CURDIR)/TRR-Backend/.venv/bin/python}"; \
	source_env="$${TRR_MODAL_SOURCE_ENV:-$$backend_dir/.env}"; \
	TRR_MODAL_BACKEND_DIR="$$backend_dir" TRR_MODAL_SOURCE_ENV="$$source_env" bash ./scripts/modal-billing-guardrail.sh; \
	cd "$$backend_dir" && \
	apply_arg=""; \
	if [ "$${APPLY_MODAL:-0}" = "1" ]; then apply_arg="--apply-modal"; fi; \
	"$$python_cmd" scripts/socials/repair_socialblade_auth.py --json --source-env "$$source_env" --chrome-profile "$${SOCIAL_AUTH_CHROME_PROFILE:-codex@thereality.report}" --validation-handle "$${ACCOUNT_HANDLE:-$${SOCIALBLADE_VALIDATION_HANDLE}}" $$apply_arg

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

instagram-backfill-progress:
	@if [ -z "$${RUN_ID:-}" ]; then echo "ERROR: set RUN_ID=<social.scrape_runs id>" >&2; exit 2; fi; \
	json_arg=""; \
	if [ "$${JSON:-0}" = "1" ]; then json_arg="--json"; fi; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/instagram/backfill_progress.py --run-id "$${RUN_ID}" $$json_arg

instagram-backfill-recover-stalled:
	@if [ -z "$${RUN_ID:-}" ]; then echo "ERROR: set RUN_ID=<social.scrape_runs id>" >&2; exit 2; fi; \
	json_arg=""; \
	progress_arg=""; \
	recover_arg=""; \
	repair_arg=""; \
	media_normalize_arg=""; \
	frontier_recover_arg=""; \
	dispatch_arg=""; \
	if [ "$${JSON:-0}" = "1" ]; then json_arg="--json"; fi; \
	if [ "$${SKIP_PROGRESS:-0}" = "1" ]; then progress_arg="--skip-progress"; fi; \
	if [ "$${SKIP_RECOVER:-0}" = "1" ]; then recover_arg="--skip-recover"; fi; \
	if [ "$${SKIP_REPAIR:-0}" = "1" ]; then repair_arg="--skip-repair"; fi; \
	if [ "$${SKIP_MEDIA_NORMALIZE:-0}" = "1" ]; then media_normalize_arg="--skip-media-normalize"; fi; \
	if [ "$${SKIP_FRONTIER_RECOVER:-0}" = "1" ]; then frontier_recover_arg="--skip-frontier-recover"; fi; \
	if [ "$${SKIP_DISPATCH:-0}" = "1" ]; then dispatch_arg="--skip-dispatch"; fi; \
	cd TRR-Backend && ./.venv/bin/python scripts/socials/instagram/recover_stalled_backfill.py --run-id "$${RUN_ID}" --stale-after-seconds "$${STALE_AFTER_SECONDS:-900}" --recover-limit "$${RECOVER_LIMIT:-5}" --dispatch-limit "$${DISPATCH_LIMIT:-8}" --media-normalize-batch-size "$${MEDIA_NORMALIZE_BATCH_SIZE:-500}" $$recover_arg $$repair_arg $$media_normalize_arg $$frontier_recover_arg $$dispatch_arg $$progress_arg $$json_arg

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

bravo-straggler-recovery: export BRAVO_RECOVERY_ARGS := $(BRAVO_RECOVERY_ARGS)
bravo-straggler-recovery:
	@cd TRR-Backend && ./.venv/bin/python scripts/socials/instagram/bravo_straggler_recovery.py

instagram-media-mirror-recovery:
	@if [ -z "$${RUN_ID:-}" ]; then echo "ERROR: set RUN_ID=<social.scrape_runs id>" >&2; exit 2; fi; \
	args="--run-id '$${RUN_ID}' --stage '$${STAGE:-media_mirror}' --stale-after-seconds '$${STALE_AFTER_SECONDS:-900}' --recover-limit '$${RECOVER_LIMIT:-5}' --dispatch-limit '$${DISPATCH_LIMIT:-8}'"; \
	if [ -n "$${ACCOUNT_HANDLE:-}" ]; then args="$$args --account '$${ACCOUNT_HANDLE}'"; fi; \
	if [ "$${SKIP_RECOVER:-0}" = "1" ]; then args="$$args --skip-recover"; fi; \
	if [ "$${SKIP_DISPATCH:-0}" = "1" ]; then args="$$args --skip-dispatch"; fi; \
	if [ "$${APPLY:-0}" = "1" ]; then args="$$args --apply"; fi; \
	if [ -n "$${CONFIRM_APPLY:-}" ]; then args="$$args --confirm-apply '$${CONFIRM_APPLY}'"; fi; \
	if [ "$${JSON:-0}" = "1" ]; then args="$$args --json"; fi; \
	cd TRR-Backend && eval ./.venv/bin/python scripts/socials/instagram/media_mirror_recovery.py "$$args"

instagram-one-post-media-mirror:
	@args=""; \
	if [ -n "$${JOB_ID:-}" ]; then args="$$args --job-id '$${JOB_ID}'"; fi; \
	if [ -n "$${POST_ID:-}" ]; then args="$$args --post-id '$${POST_ID}'"; fi; \
	if [ -n "$${SOURCE_ID:-}" ]; then args="$$args --source-id '$${SOURCE_ID}'"; fi; \
	if [ -n "$${SHORTCODE:-}" ]; then args="$$args --source-id '$${SHORTCODE}'"; fi; \
	if [ -z "$$args" ]; then echo "ERROR: set JOB_ID=..., POST_ID=..., SOURCE_ID=..., or SHORTCODE=..." >&2; exit 2; fi; \
	if [ -n "$${ACCOUNT_HANDLE:-}" ]; then args="$$args --account '$${ACCOUNT_HANDLE}'"; fi; \
	if [ -n "$${MODE:-}" ]; then args="$$args --mode '$${MODE}'"; fi; \
	if [ "$${MODAL:-0}" = "1" ]; then args="$$args --mode modal"; fi; \
	if [ "$${DRY_RUN:-0}" = "1" ]; then args="$$args --dry-run"; fi; \
	if [ "$${JSON:-0}" = "1" ]; then args="$$args --json"; fi; \
	cd TRR-Backend && eval ./.venv/bin/python scripts/socials/instagram/one_post_media_mirror.py "$$args"

social-queue-snapshot:
	@if [ -z "$${RUN_ID:-}" ]; then echo "ERROR: set RUN_ID=<social.scrape_runs id>" >&2; exit 2; fi; \
	mkdir -p .logs/workspace/social-queue-snapshots; \
	timestamp="$$(date -u +%Y%m%dT%H%M%SZ)"; \
	log_file=".logs/workspace/social-queue-snapshots/$$timestamp-$${RUN_ID}-$${STAGE:-media_mirror}.json"; \
	args="--run-id '$${RUN_ID}' --platform '$${PLATFORM:-instagram}' --stage '$${STAGE:-media_mirror}' --stale-after-seconds '$${STALE_AFTER_SECONDS:-900}'"; \
	if [ -n "$${ACCOUNT_HANDLE:-}" ]; then args="$$args --account '$${ACCOUNT_HANDLE}'"; fi; \
	if [ "$${JSON:-0}" = "1" ]; then args="$$args --json"; fi; \
	cd TRR-Backend && eval ./.venv/bin/python scripts/socials/queue_snapshot.py "$$args" | tee "../$$log_file"; \
	echo "[workspace] Queue snapshot log: $$log_file" >&2

# Compatibility alias for older social-safe muscle memory.
dev-hybrid-social-safe:
	@echo "[workspace] NOTE: 'make dev-hybrid-social-safe' is now an alias for 'make dev-hybrid'."
	@$(MAKE) --no-print-directory dev-hybrid PROFILE="$${PROFILE:-local-cloud}"

dev-local:
	@$(MAKE) --no-print-directory preflight
	@WORKSPACE_USE_PORTLESS_URLS=1 PROFILE="$${PROFILE:-default}" WORKSPACE_DEV_MODE=local bash scripts/dev-workspace.sh

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

architecture-git-roots-check:
	@python3 scripts/architecture/check-git-roots.py

architecture-contracts-check:
	@$(MAKE) --no-print-directory architecture-git-roots-check
	@$(MAKE) --no-print-directory architecture-durable-contracts-check
	@$(MAKE) --no-print-directory architecture-guard-tests
	@$(MAKE) --no-print-directory architecture-evidence-hygiene-check
	@$(MAKE) --no-print-directory architecture-hotspots-check
	@$(MAKE) --no-print-directory architecture-release-manifests-check
	@$(MAKE) --no-print-directory openapi-v2-contract-check
	@python3 scripts/architecture/check-import-graph.py --check-baseline
	@python3 scripts/app-direct-sql-inventory.py --check --fail-expired
	@$(MAKE) --no-print-directory runtime-capacity-check
	@$(MAKE) --no-print-directory deployment-targets-check
	@$(MAKE) --no-print-directory modal-invocation-check
	@$(MAKE) --no-print-directory vercel-project-guard

architecture-evidence-hygiene-check:
	@python3 scripts/architecture/check-evidence-hygiene.py

architecture-durable-contracts-check:
	@python3 scripts/architecture/check-durable-contracts.py --boundary working-tree

architecture-durable-candidate-check:
	@python3 scripts/architecture/check-durable-contracts.py --boundary candidate

architecture-guard-tests:
	@TRR-Backend/.venv/bin/python -m pytest -q \
		scripts/architecture/tests/test_check_durable_contracts.py \
		scripts/architecture/tests/test_check_evidence_hygiene.py \
		scripts/architecture/tests/test_check_git_roots.py \
		scripts/architecture/tests/test_check_hotspots.py \
		scripts/architecture/tests/test_check_import_graph.py \
		scripts/architecture/tests/test_check_release_manifests.py

architecture-hotspots-check:
	@python3 scripts/architecture/check-hotspots.py --fail-expired

architecture-release-manifests-check:
	@TRR-Backend/.venv/bin/python scripts/architecture/check-release-manifests.py

openapi-v2-contract-generate:
	@cd TRR-Backend && ./.venv/bin/python -m scripts.dev.export_v2_openapi
	@mkdir -p TRR-APP/apps/web/src/lib/server/trr-api/generated
	@cp TRR-Backend/docs/api/openapi.v2.json TRR-APP/apps/web/src/lib/server/trr-api/generated/openapi.v2.json
	@pnpm -C TRR-APP/apps/web run generate:trr-v2-api-types

openapi-v2-contract-check:
	@cd TRR-Backend && ./.venv/bin/python -m scripts.dev.export_v2_openapi --check
	@cmp -s TRR-Backend/docs/api/openapi.v2.json TRR-APP/apps/web/src/lib/server/trr-api/generated/openapi.v2.json || { echo "openapi-v2-contract: ERROR app snapshot differs from backend"; exit 1; }
	@pnpm -C TRR-APP/apps/web run generated:trr-v2-api-types:check

runtime-capacity-check:
	@python3 scripts/runtime_capacity.py check

deployment-targets-check:
	@python3 scripts/deployment_targets.py check

modal-invocation-check:
	@cd TRR-Backend && ./.venv/bin/python scripts/modal/check_invocations.py

vercel-project-guard:
	@python3 scripts/vercel-project-guard.py --project-dir TRR-APP

vercel-auth-doctor:
	@bash TRR-APP/scripts/vercel.sh auth-doctor

vercel-cleanup-doctor:
	@bash TRR-APP/scripts/vercel.sh cleanup-doctor

vercel-link-trr:
	@bash TRR-APP/scripts/vercel.sh link-trr

vercel-preview-ready:
	@bash TRR-APP/scripts/vercel.sh preview-ready

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

SUPABASE_BRANCH_CLEANUP_ARGS ?=
supabase-preview-branch-cleanup:
	@args="$(SUPABASE_BRANCH_CLEANUP_ARGS)"; \
	if [ "$${DELETE:-0}" = "1" ]; then args="$$args --delete"; fi; \
	python3 scripts/supabase-preview-branch-cleanup.py $$args

check-policy:
	@bash scripts/check-policy.sh

codex-check:
	@bash scripts/check-codex.sh

git-branch-report:
	@bash scripts/git-branch-report.sh

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
	@echo "  make dev          - default hybrid social scraping runtime with Modal workers and Portless app/admin/API URLs"
	@echo "  make status       - workspace health and PID snapshot (STATUS_ARGS=--json for JSON)"
	@echo "  make status-json  - workspace health and PID snapshot as JSON"
	@echo "  make dev-local    - local-only TRR-APP + TRR-Backend, direct DB lane, remote workers disabled"
	@echo "  make dev-redis    - start local Redis, then run make dev-local with PROFILE=local-redis"
	@echo "  make dev-cloud    - explicit cloud/remote worker path using session/pooler DB"
	@echo "  make dev-hybrid   - explicit name for make dev"
	@echo "  make dev-hybrid-media-safe - post-recovery hybrid social mode with media=2 and comment media=2"
	@echo "  make dev-hybrid-media-safe-posts - post-recovery hybrid mode biased toward post media lanes"
	@echo "  make dev-hybrid-media-safe-comments - post-recovery hybrid mode biased toward comment media lanes"
	@echo "  make dev-hybrid-media-safe-bravotv - Bravo pending-media drain preset with media=4, posts=0"
	@echo "  make dev-hybrid-bg - starts Modal-capable make dev-hybrid detached, writing .logs/workspace/dev-hybrid-background.log"
	@echo "  make dev-hybrid-social-safe - alias for make dev-hybrid"
	@echo "  make dev-portless - Wordle/separate-session Portless launcher; make dev already uses Portless"
	@echo "  make stop-portless - stop managed Portless app/API/Wordle sessions"
	@echo "  make portless-status - print read-only Portless proxy, route, and Browser-test readiness"
	@echo "  make portless-repair - ensure Portless wildcard routing and remove stale TRR static aliases"
	@echo "  make open-admin   - open the clean Portless admin dashboard"
	@echo "  make modal-instagram-auth-status - bounded Instagram Modal auth probe (ACCOUNT_HANDLE=... adds posts/comments probes)"
	@echo "  make modal-instagram-auth-repair - bounded Instagram auth repair, secret refresh, deploy, and remote verify (DRY_RUN=1 plans only)"
	@echo "  make instagram-backfill-preflight - account-scoped posts/comments auth preflight (ACCOUNT_HANDLE=...)"
	@echo "  make instagram-backfill-progress - compact run progress (RUN_ID=... JSON=1 optional)"
	@echo "  make instagram-backfill-recover-stalled - recover stale Instagram frontier, repair metrics, normalize hosted media, dispatch due jobs (RUN_ID=... SKIP_PROGRESS=1 optional)"
	@echo "  make instagram-posts-smoke - bounded live posts smoke (ACCOUNT_HANDLE=... MAX_PAGES=1; not a dry run)"
	@echo "  make instagram-posts-benchmark - emit bounded benchmark payload (ACCOUNT_HANDLE=... MODE=listing-only)"
	@echo "  make bravo-straggler-recovery - plan or run approved Bravo Instagram straggler recovery (BRAVO_RECOVERY_ARGS='--approved-shortcodes-file ...')"
	@echo "  make instagram-media-mirror-recovery - dry-run or apply stale Instagram media mirror recovery (RUN_ID=... APPLY=1 CONFIRM_APPLY='RECOVER MEDIA MIRROR JOBS' optional)"
	@echo "  make instagram-one-post-media-mirror - run one post media mirror job exactly (JOB_ID=... or POST_ID=...; MODAL=1 optional)"
	@echo "  make social-queue-snapshot - reusable run/stage queue snapshot (RUN_ID=... STAGE=media_mirror JSON=1 optional)"
	@echo "  make preflight    - validates the local/direct workspace path"
	@echo "  make preflight-cloud - validates the explicit cloud/session path"
	@echo "  make preflight-hybrid - validates direct local plus session remote separation"
	@echo "  make env-contract - refresh docs/workspace/env-contract.md"
	@echo "  make env-contract-report - refresh env contract inventory/deprecation review docs"
	@echo "  make env-hygiene - validate env file authority classes without printing values"
	@echo "  make app-validate-quick - run the approved lightweight TRR-APP validation path"
	@echo "  make codex-check  - validates tracked Codex config, rules, and user bootstrap state"
	@echo "  make git-branch-report - report local/remote branch refs outside main"
	@echo "  make doctor-json  - plugin registry doctor output as JSON"
	@echo "  make context7-repair - repair Context7 MCP wrapper config, reload stale connector processes, and smoke test"
	@echo "  make chrome-repair - clean stale browser MCP state, start shared Chrome, and print DevTools readiness"
	@echo "  make next-devtools-mcp-status - validate TRR-local Next.js DevTools MCP registration"
	@echo "  make browser-smoke-admin-details - smoke test social account and show detail routes in a browser"
	@echo "  make codex-browser-transport-reset - clean stale Codex Browser transport state"
	@echo "  make supabase-advisor-snapshot - capture dated Supabase advisor JSON artifacts"
	@echo "  make supabase-preview-branch-cleanup - dry-run old Supabase preview branch cleanup (DELETE=1 applies)"
	@echo "  make vercel-auth-doctor - check local Vercel CLI access to the TRR team/project"
	@echo "  make vercel-cleanup-doctor - find stale local Vercel links such as the old web project"
	@echo "  make vercel-link-trr - link TRR-APP to the trr-app Vercel project of record"
	@echo "  make vercel-preview-ready - check Vercel project link and check/enable Web Analytics plus Speed Insights"
	@echo "  make backend-restart-diagnose - prints backend restart/watchdog attribution state"
	@echo "  make redis-up     - start local Redis via docker-compose.redis.yml"
	@echo "  make redis-down   - stop local Redis via docker-compose.redis.yml"
	@echo "  make down         - deprecated no-op retained for compatibility"
	@echo "  make chrome-dock-clean - remove Google Chrome entries from macOS Dock recents"
	@echo "Legacy aliases:"
	@echo "  make dev-full     - deprecated alias for make dev"

chrome-devtools-mcp-status:
	@bash scripts/chrome-devtools-mcp-status.sh

next-devtools-mcp-status:
	@bash scripts/next-devtools-mcp-status.sh

chrome-repair:
	@bash scripts/chrome-repair.sh

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
