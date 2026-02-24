.PHONY: dev dev-lite dev-cloud dev-full status stop logs bootstrap doctor test down

# Daily default: starts TRR-APP + TRR-Backend + screenalytics.
# Disable screenalytics explicitly with: WORKSPACE_SCREENALYTICS=0 make dev
# Default also bypasses local Docker for screenalytics (managed Redis/S3 mode).
# Opt back into local Docker infra with:
# WORKSPACE_SCREENALYTICS_SKIP_DOCKER=0 make dev
# Startup tuning:
# WORKSPACE_CLEAN_NEXT_CACHE=1 make dev  # force clean Next.js cache
# WORKSPACE_OPEN_BROWSER=0 make dev      # skip browser tab refresh/open
dev:
	@bash scripts/dev-workspace.sh

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

# Tears down screenalytics docker compose infra (redis + minio).
# Use "make stop && make down" for a full cleanup.
down:
	@bash scripts/down-screenalytics-infra.sh
