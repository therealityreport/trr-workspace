# Backend Runtime Ownership

The `TRR-Backend` repository owns the FastAPI runtime, durable services,
database migrations, Modal jobs, and backend operational commands. The
workspace owns only the cross-repository contracts that describe those
boundaries.

- Backend implementation and deployment changes start in `TRR-Backend`.
- `TRR-APP` consumes backend API contracts and owns app-local behavior.
- Workspace launch, environment, capacity, and deployment-target contracts
  coordinate the repositories; they do not transfer runtime ownership.

Use `CONTEXT-MAP.md` and the repository-local `AGENTS.md` files before making
a change that crosses these boundaries.
