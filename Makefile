.PHONY: dev stop logs bootstrap doctor test down

# Daily default: starts TRR-APP + TRR-Backend. Enable screenalytics explicitly with
# WORKSPACE_SCREENALYTICS=1 make dev
dev:
	@bash scripts/dev-workspace.sh

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
