.PHONY: \
	dev dev-lite dev-cloud dev-local dev-full \
	preflight preflight-local preflight-strict preflight-diagnostics env-contract check-policy codex-check handoff-check handoff-sync smoke status stop logs logs-prune cleanup-disk help \
	bootstrap doctor test test-fast test-full test-changed test-env-sensitive \
	workspace-contract-check \
	cast-screentime-gap-check cast-screentime-live-check \
	down chrome-devtools-mcp-status chrome-devtools-mcp-clean-stale chrome-devtools-mcp-stop-conflicts \
	mcp-clean \
	workspace-pr-agent \
	getty-server getty-tunnel getty-remote

# Daily default: `make dev` runs the canonical cloud-backed workspace profile.
# It starts TRR-APP + TRR-Backend locally, keeps the screenalytics API on, and bypasses local Docker infra.
# screenalytics Streamlit/Web UIs are disabled in the default profile unless explicitly re-enabled.
# Use `make dev-local` only when you intentionally want Docker-backed local Redis + MinIO.
# To override the default profile explicitly:
# PROFILE=default make dev
# PROFILE=local-cloud make dev        # deprecated compatibility profile
# PROFILE=local-docker make dev-local
# PROFILE=local-full make dev-local   # deprecated compatibility profile
# Startup tuning:
# WORKSPACE_CLEAN_NEXT_CACHE=1 make dev  # force clean Next.js cache
# WORKSPACE_TRR_APP_DEV_BUNDLER=webpack make dev  # force the webpack fallback if Turbopack regresses
# WORKSPACE_OPEN_BROWSER=1 make dev      # opt in to browser tab reuse/open on startup
# WORKSPACE_BACKEND_AUTO_RESTART=0 make dev  # disable backend watchdog auto-restart (default profile enables it)
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reuse_no_reload make dev  # browser sync strategy when enabled
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_first make dev     # reload only the first matching tab
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_all make dev       # legacy behavior: reload every matching tab
# WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make dev  # opt in to screenalytics Streamlit/Web tabs
# TRR_BACKEND_RELOAD=1 make dev          # opt in backend hot-reload (default workspace mode is non-reload)
dev:
	@$(MAKE) --no-print-directory preflight
	@PROFILE="$${PROFILE:-default}" WORKSPACE_DEV_MODE=cloud WORKSPACE_SCREENALYTICS=1 WORKSPACE_SCREENALYTICS_SKIP_DOCKER=1 bash scripts/dev-workspace.sh

# Compatibility alias for the canonical default path.
dev-lite:
	@echo "[workspace] NOTE: 'make dev-lite' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Compatibility alias for the canonical default path.
dev-cloud:
	@echo "[workspace] NOTE: 'make dev-cloud' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Docker-backed local screenalytics mode (local Redis + MinIO).
dev-local:
	@$(MAKE) --no-print-directory preflight-local
	@PROFILE="$${PROFILE:-local-docker}" WORKSPACE_DEV_MODE=local_docker WORKSPACE_SCREENALYTICS=1 WORKSPACE_SCREENALYTICS_SKIP_DOCKER=0 bash scripts/dev-workspace.sh

# Compatibility alias for the Docker-backed local path.
dev-full:
	@echo "[workspace] NOTE: 'make dev-full' is deprecated; running 'make dev-local'."
	@$(MAKE) --no-print-directory dev-local PROFILE="$${PROFILE:-local-docker}"

preflight:
	@WORKSPACE_DEV_MODE=cloud bash scripts/preflight.sh

preflight-local:
	@WORKSPACE_DEV_MODE=local_docker bash scripts/preflight.sh

preflight-strict:
	@WORKSPACE_DEV_MODE=cloud WORKSPACE_PREFLIGHT_STRICT=1 bash scripts/preflight.sh

preflight-diagnostics:
	@WORKSPACE_DEV_MODE=cloud WORKSPACE_PREFLIGHT_DIAGNOSTICS=1 bash scripts/preflight.sh

env-contract:
	@bash scripts/workspace-env-contract.sh --generate

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

# Workspace status snapshot (PIDs, ports, health).
status:
	@bash scripts/status-workspace.sh

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

bootstrap:
	@bash scripts/bootstrap.sh

doctor:
	@bash scripts/doctor.sh

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

# Tears down the local Docker infra used by make dev-local (Redis + MinIO).
# Use "make stop && make down" for a full cleanup.
down:
	@bash scripts/down-screenalytics-infra.sh

help:
	@echo "Workspace commands:"
	@echo "  make dev          - recommended default; cloud-backed screenalytics API, no local Docker infra"
	@echo "  make dev-local    - local Docker mode; starts Redis + MinIO for screenalytics"
	@echo "  make preflight    - validates the default no-Docker dev path"
	@echo "  make preflight-local - validates the Docker-backed local path"
	@echo "  make codex-check  - validates tracked Codex config, rules, and user bootstrap state"
	@echo "  make down         - tears down local Docker infra used by make dev-local"
	@echo "Legacy aliases:"
	@echo "  make dev-cloud    - deprecated alias for make dev"
	@echo "  make dev-full     - deprecated alias for make dev-local"

chrome-devtools-mcp-status:
	@bash scripts/chrome-devtools-mcp-status.sh

chrome-devtools-mcp-clean-stale:
	@bash scripts/chrome-devtools-mcp-clean-stale.sh

chrome-devtools-mcp-stop-conflicts:
	@bash scripts/chrome-devtools-mcp-stop-conflicts.sh

mcp-clean:
	@bash scripts/mcp-clean.sh

# Multi-repo commit/PR/review/merge automation agent.
# Optional env overrides:
# WORKSPACE_PR_AGENT_REVISION_COMMAND='...'   # default uses scripts/workspace-pr-agent-revision.py
# WORKSPACE_PR_AGENT_REVISION_USE_CODEX=0     # disable Codex-assist within revision script
# WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=0   # default is 1 (MCP-preferred Codex prompt)
# WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1   # fail revision assist if GitHub MCP auth is missing
# WORKSPACE_PR_AGENT_DRY_RUN=1
# WORKSPACE_PR_AGENT_REPOS='TRR-Backend,screenalytics,TRR-APP'
workspace-pr-agent:
	@bash scripts/workspace-pr-agent.sh
