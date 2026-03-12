.PHONY: \
	dev dev-lite dev-cloud dev-full \
	preflight preflight-diagnostics env-contract check-policy smoke status stop logs logs-prune \
	bootstrap doctor test test-fast test-full test-changed test-env-sensitive \
	down chrome-devtools-mcp-status \
	mcp-aws-on mcp-aws-off mcp-aws-status \
	workspace-pr-agent

# Daily default: `make dev` now runs laptop-safe `local-lite` mode with remote-enforced long jobs.
# This keeps heavy social ingestion off local machine by default.
# To run heavier stacks intentionally, use `make dev-cloud` or `make dev-full`.
# To override this default profile explicitly:
# PROFILE=local-cloud make dev
# PROFILE=local-full make dev
# Startup tuning:
# WORKSPACE_CLEAN_NEXT_CACHE=1 make dev  # force clean Next.js cache
# WORKSPACE_OPEN_BROWSER=1 make dev      # opt in to browser tab refresh/open
# WORKSPACE_BACKEND_AUTO_RESTART=1 make dev  # opt in to backend watchdog auto-restart
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reuse_no_reload make dev  # browser sync strategy when enabled
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_first make dev     # reload only the first matching tab
# WORKSPACE_BROWSER_TAB_SYNC_MODE=reload_all make dev       # legacy behavior: reload every matching tab
# WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make dev  # opt in to screenalytics Streamlit/Web tabs
# TRR_BACKEND_RELOAD=1 make dev          # opt in backend hot-reload (default workspace mode is non-reload)
dev: preflight
	@PROFILE="$${PROFILE:-local-lite}" \
	WORKSPACE_TRR_JOB_PLANE_MODE=remote \
	WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1 \
	WORKSPACE_TRR_REMOTE_EXECUTOR=modal \
	WORKSPACE_TRR_MODAL_ENABLED=1 \
	WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION=run_admin_operation_v2 \
	WORKSPACE_SOCIAL_WORKER_ENABLED=0 \
	WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=0 \
	WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0 \
	bash scripts/dev-workspace.sh

# Lightweight mode: TRR-APP + TRR-Backend only (no screenalytics).
dev-lite: preflight
	@WORKSPACE_SCREENALYTICS=0 bash scripts/dev-workspace.sh

# Cloud-backed screenalytics mode (no local Docker infra).
dev-cloud: preflight
	@WORKSPACE_SCREENALYTICS=1 WORKSPACE_SCREENALYTICS_SKIP_DOCKER=1 bash scripts/dev-workspace.sh

# Full local screenalytics mode (with Docker Redis/MinIO).
dev-full: preflight
	@WORKSPACE_SCREENALYTICS=1 WORKSPACE_SCREENALYTICS_SKIP_DOCKER=0 bash scripts/dev-workspace.sh

preflight:
	@bash scripts/preflight.sh

preflight-diagnostics:
	@WORKSPACE_PREFLIGHT_DIAGNOSTICS=1 bash scripts/preflight.sh

env-contract:
	@bash scripts/workspace-env-contract.sh --generate

check-policy:
	@bash scripts/check-policy.sh

smoke:
	@bash scripts/smoke.sh

# Workspace status snapshot (PIDs, ports, health).
status:
	@bash scripts/status-workspace.sh

# Stops workspace-managed processes only (from make dev).
stop:
	@bash scripts/stop-workspace.sh

logs:
	@bash scripts/logs-workspace.sh

logs-prune:
	@bash scripts/logs-prune.sh

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

# Tears down screenalytics docker compose infra (redis + minio).
# Use "make stop && make down" for a full cleanup.
down:
	@bash scripts/down-screenalytics-infra.sh

chrome-devtools-mcp-status:
	@bash scripts/chrome-devtools-mcp-status.sh

mcp-aws-on:
	@bash scripts/mcp-profile.sh aws-on

mcp-aws-off:
	@bash scripts/mcp-profile.sh aws-off

mcp-aws-status:
	@bash scripts/mcp-profile.sh aws-status

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
