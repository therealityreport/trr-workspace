# Architecture Research: Cloud-First / No-Docker Workspace Tooling

## Current Integration Points

- Root workspace entry: [Makefile](/Users/thomashulihan/Projects/TRR/Makefile)
- Workspace bootstrap and mode selection: [scripts/dev-workspace.sh](/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh)
- Readiness and diagnostics: [scripts/preflight.sh](/Users/thomashulihan/Projects/TRR/scripts/preflight.sh), [scripts/doctor.sh](/Users/thomashulihan/Projects/TRR/scripts/doctor.sh)
- Backend schema validation and docs drift checks: [TRR-Backend/Makefile](/Users/thomashulihan/Projects/TRR/TRR-Backend/Makefile)
- Shared env contract and historical status notes under `docs/workspace/` and `docs/ai/local-status/`

## Suggested Architecture Direction

- Keep one shared workspace contract:
  - `cloud` mode is the normal path
  - `local_docker` is explicit fallback only
- Move DB validation guidance toward remote branch/disposable DB targets:
  - validate migrations against isolated remote DB URLs
  - document how to avoid shared-environment risk
- Isolate Screenalytics-specific local infra so it cannot block unrelated backend/app work:
  - only enable it when a task explicitly needs that lane
  - keep the default workspace path free of that dependency

## Suggested Build Order

1. Define the preferred no-Docker workflow contract and update docs
2. Update root scripts and `Makefile` defaults to match that contract
3. Refine backend schema validation guidance around remote branch/disposable DB paths
4. Align doctor/preflight/handoff messaging so the same behavior is visible everywhere
