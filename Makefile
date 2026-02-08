.PHONY: dev stop logs bootstrap doctor test down

dev:
	@bash scripts/dev-workspace.sh

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

down:
	@bash scripts/down-screenalytics-infra.sh
