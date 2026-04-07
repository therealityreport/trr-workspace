# Stack Research: Cloud-First / No-Docker Workspace Tooling

## Current Baseline

- Root workspace orchestration still exposes `local_docker` as a first-class mode through the root [Makefile](/Users/thomashulihan/Projects/TRR/Makefile) and [scripts/dev-workspace.sh](/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh).
- Backend schema validation guidance still points heavily at local Supabase CLI reset flows in [TRR-Backend/Makefile](/Users/thomashulihan/Projects/TRR/TRR-Backend/Makefile).
- Existing status notes already reference remote validation through Supabase preview or branch databases as a viable alternative.

## Relevant External Guidance

- Supabase “Managing Environments” recommends CI/CD and linked remote projects for migration deployment, with `supabase db push` as the deployment path.
- Supabase “Working with branches” explicitly supports remote development workflows where changes are made on a branch, pulled locally, and validated without requiring local Docker as the primary path.
- Supabase branches are isolated environments with separate credentials, which fits the workspace preference better than destructive shared-project validation.

## Recommended Additions

- Keep Supabase CLI as the primary DB tooling surface, but bias toward:
  - remote branch credentials
  - `supabase db push --db-url ...`
  - branch/disposable project validation notes
- Keep Docker-based local Supabase as an escape hatch only, not the documented happy path.
- Preserve `cloud` workspace mode as the preferred default and treat `local_docker` as explicitly opt-in.

## What Not To Add

- Do not introduce another local container stack just to replace existing Docker-based flows.
- Do not add a second parallel environment contract when `TRR_DB_URL` and remote branch URLs already cover the runtime need.
- Do not make remote validation depend on ad hoc secret handling outside the existing env contract.
