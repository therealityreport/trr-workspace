.PHONY: \
	dev dev-lite dev-cloud dev-local dev-full \
	preflight preflight-local preflight-strict preflight-diagnostics env-contract env-contract-report check-policy codex-check handoff-check handoff-sync smoke status stop logs logs-prune cleanup-disk help \
	bootstrap doctor test test-fast test-full test-changed test-env-sensitive \
	workspace-contract-check \
	cast-screentime-gap-check cast-screentime-live-check \
	down chrome-devtools-mcp-status chrome-devtools-mcp-clean-stale chrome-devtools-mcp-stop-conflicts \
	mcp-clean chrome-dock-clean \
	workspace-pr-agent \
	getty-server getty-tunnel getty-remote

# Daily default: `make dev` runs the canonical cloud-first workspace profile.
# It starts TRR-APP + TRR-Backend locally and avoids legacy screenalytics runtime wiring.
# To override the default profile explicitly:
# PROFILE=default make dev
# PROFILE=local-cloud make dev        # deprecated compatibility alias
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
	@PROFILE="$${PROFILE:-default}" WORKSPACE_DEV_MODE=cloud bash scripts/dev-workspace.sh

# Compatibility alias for the canonical default path.
dev-lite:
	@echo "[workspace] NOTE: 'make dev-lite' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Compatibility alias for the canonical default path.
dev-cloud:
	@echo "[workspace] NOTE: 'make dev-cloud' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Deprecated compatibility alias retained for older local muscle memory.
dev-local:
	@echo "[workspace] NOTE: 'make dev-local' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Deprecated compatibility alias retained for older local muscle memory.
dev-full:
	@echo "[workspace] NOTE: 'make dev-full' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

preflight:
	@WORKSPACE_DEV_MODE=cloud bash scripts/preflight.sh

preflight-local:
	@echo "[workspace] NOTE: 'make preflight-local' is deprecated; running 'make preflight'."
	@WORKSPACE_DEV_MODE=cloud bash scripts/preflight.sh

preflight-strict:
	@WORKSPACE_DEV_MODE=cloud WORKSPACE_PREFLIGHT_STRICT=1 bash scripts/preflight.sh

preflight-diagnostics:
	@WORKSPACE_DEV_MODE=cloud WORKSPACE_PREFLIGHT_DIAGNOSTICS=1 bash scripts/preflight.sh

env-contract:
	@bash scripts/workspace-env-contract.sh --generate

env-contract-report:
	@python3 scripts/env_contract_report.py write

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

# Legacy no-op retained so older cleanup muscle memory does not fail.
down:
	@echo "[workspace] NOTE: local screenalytics infra is retired; nothing to tear down."

help:
	@echo "Workspace commands:"
	@echo "  make dev          - canonical default; cloud-first backend/app path with no local Docker infra"
	@echo "  make dev-local    - deprecated alias for make dev"
	@echo "  make preflight    - validates the canonical no-Docker workspace path"
	@echo "  make preflight-local - deprecated alias for make preflight"
	@echo "  make env-contract - refresh docs/workspace/env-contract.md"
	@echo "  make env-contract-report - refresh env contract inventory/deprecation review docs"
	@echo "  make codex-check  - validates tracked Codex config, rules, and user bootstrap state"
	@echo "  make down         - deprecated no-op retained for compatibility"
	@echo "  make chrome-dock-clean - remove Google Chrome entries from macOS Dock recents"
	@echo "Legacy aliases:"
	@echo "  make dev-cloud    - deprecated alias for make dev"
	@echo "  make dev-full     - deprecated alias for make dev"

chrome-devtools-mcp-status:
	@bash scripts/chrome-devtools-mcp-status.sh

chrome-devtools-mcp-clean-stale:
	@bash scripts/chrome-devtools-mcp-clean-stale.sh

chrome-devtools-mcp-stop-conflicts:
	@bash scripts/chrome-devtools-mcp-stop-conflicts.sh

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
