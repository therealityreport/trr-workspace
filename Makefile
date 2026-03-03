.PHONY: dev dev-lite dev-cloud dev-full status stop logs bootstrap doctor test test-env-sensitive down chrome-agent chrome-agent-stop

# Daily default: starts TRR-APP + TRR-Backend + screenalytics.
# Disable screenalytics explicitly with: WORKSPACE_SCREENALYTICS=0 make dev
# Default also bypasses local Docker for screenalytics (managed Redis/S3 mode).
# Opt back into local Docker infra with:
# WORKSPACE_SCREENALYTICS_SKIP_DOCKER=0 make dev
# Startup tuning:
# WORKSPACE_CLEAN_NEXT_CACHE=1 make dev  # force clean Next.js cache
# WORKSPACE_OPEN_BROWSER=0 make dev      # skip browser tab refresh/open
# WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make dev  # opt in to screenalytics Streamlit/Web tabs
# TRR_BACKEND_RELOAD=1 make dev          # opt in backend hot-reload (default workspace mode is non-reload)
dev:
	@WORKSPACE_OPEN_SCREENALYTICS_TABS="$${WORKSPACE_OPEN_SCREENALYTICS_TABS:-0}" bash scripts/dev-workspace.sh

# Lightweight mode: TRR-APP + TRR-Backend only (no screenalytics).
dev-lite:
	@WORKSPACE_SCREENALYTICS=0 bash scripts/dev-workspace.sh

# Cloud-backed screenalytics mode (no local Docker infra).
dev-cloud:
	@WORKSPACE_SCREENALYTICS=1 WORKSPACE_SCREENALYTICS_SKIP_DOCKER=1 bash scripts/dev-workspace.sh

# Full local screenalytics mode (with Docker Redis/MinIO).
dev-full:
	@WORKSPACE_SCREENALYTICS=1 WORKSPACE_SCREENALYTICS_SKIP_DOCKER=0 bash scripts/dev-workspace.sh

# Workspace status snapshot (PIDs, ports, health).
status:
	@bash scripts/status-workspace.sh

# Stops workspace-managed processes only (from make dev).
stop:
	@bash scripts/stop-workspace.sh

logs:
	@bash scripts/logs-workspace.sh

bootstrap:
	@bash scripts/bootstrap.sh

doctor:
	@bash scripts/doctor.sh

test:
	@bash scripts/test.sh

# Environment-sensitive regression gate across repos.
test-env-sensitive:
	@bash scripts/test-env-sensitive.sh

# Tears down screenalytics docker compose infra (redis + minio).
# Use "make stop && make down" for a full cleanup.
down:
	@bash scripts/down-screenalytics-infra.sh

# Launch Chrome with a dedicated agent profile and remote debugging enabled.
# First run: manually log into the agent Gmail/accounts in the opened window.
# Sessions persist across restarts in ~/.chrome-profiles/claude-agent.
# Override profile: CHROME_AGENT_PROFILE_DIR=... make chrome-agent
# Override port:    CHROME_AGENT_DEBUG_PORT=9333 make chrome-agent
# Headless mode:    CHROME_AGENT_HEADLESS=1 make chrome-agent
chrome-agent:
	@bash scripts/chrome-agent.sh

chrome-agent-stop:
	@bash scripts/stop-chrome-agent.sh
