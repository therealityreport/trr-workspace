.PHONY: \
	dev dev-lite dev-cloud dev-hybrid dev-local dev-full \
	preflight preflight-local preflight-cloud preflight-hybrid preflight-strict preflight-diagnostics env-contract env-contract-report check-policy codex-check handoff-check handoff-sync smoke status backend-restart-diagnose stop logs logs-prune cleanup-disk help \
	app-direct-sql-inventory redacted-env-inventory vercel-project-guard migration-ownership-lint rls-grants-snapshot db-pressure-rehearsal supabase-mcp-access supabase-advisor-snapshot \
	bootstrap doctor test test-fast test-full test-changed test-env-sensitive \
	workspace-contract-check \
	cast-screentime-gap-check cast-screentime-live-check \
	down chrome-devtools-mcp-status chrome-devtools-mcp-clean-stale chrome-devtools-mcp-stop-conflicts \
	mcp-clean chrome-dock-clean \
	workspace-pr-agent \
	getty-server getty-tunnel getty-remote

# Daily default: `make dev` runs local TRR-APP + local TRR-Backend on the direct DB lane.
# Remote workers and Modal dispatch are disabled unless an explicit cloud/hybrid target is used.
# To override the default profile explicitly:
# PROFILE=default make dev
# make dev-cloud                      # explicit cloud/remote worker mode
# make dev-hybrid                     # local direct app/backend plus remote workers on session/pooler
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

# Compatibility alias for the canonical default path.
dev-lite:
	@echo "[workspace] NOTE: 'make dev-lite' is deprecated; running 'make dev'."
	@$(MAKE) --no-print-directory dev PROFILE="$${PROFILE:-default}"

# Explicit cloud/remote path.
dev-cloud:
	@$(MAKE) --no-print-directory preflight-cloud
	@PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=cloud bash scripts/dev-workspace.sh

# Explicit hybrid path: local app/backend use direct DB; Modal/remote workers use session/pooler.
dev-hybrid:
	@$(MAKE) --no-print-directory preflight-hybrid
	@PROFILE="$${PROFILE:-local-cloud}" WORKSPACE_DEV_MODE=hybrid bash scripts/dev-workspace.sh

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

# Workspace status snapshot (PIDs, ports, health).
status:
	@bash scripts/status-workspace.sh

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
	@echo "  make dev          - local TRR-APP + local TRR-Backend, direct DB lane, remote workers disabled"
	@echo "  make dev-cloud    - explicit cloud/remote worker path using session/pooler DB"
	@echo "  make dev-hybrid   - local direct app/backend plus Modal/remote workers on session/pooler DB"
	@echo "  make dev-local    - deprecated alias for make dev"
	@echo "  make preflight    - validates the local/direct workspace path"
	@echo "  make preflight-cloud - validates the explicit cloud/session path"
	@echo "  make preflight-hybrid - validates direct local plus session remote separation"
	@echo "  make env-contract - refresh docs/workspace/env-contract.md"
	@echo "  make env-contract-report - refresh env contract inventory/deprecation review docs"
	@echo "  make codex-check  - validates tracked Codex config, rules, and user bootstrap state"
	@echo "  make supabase-advisor-snapshot - capture dated Supabase advisor JSON artifacts"
	@echo "  make backend-restart-diagnose - prints backend restart/watchdog attribution state"
	@echo "  make down         - deprecated no-op retained for compatibility"
	@echo "  make chrome-dock-clean - remove Google Chrome entries from macOS Dock recents"
	@echo "Legacy aliases:"
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
