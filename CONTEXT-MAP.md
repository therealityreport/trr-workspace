# TRR Context Map

Start here before changing a TRR boundary. This workspace coordinates three
intended Git repositories; each repository keeps its own implementation and
validation ownership.

## Repository contexts

| Context | Git root | Read first | Primary ownership |
|---|---|---|---|
| Workspace coordination | `.` | `AGENTS.md`, `.codex/rules/trr-project.md`, `docs/workspace/backend-runtime-ownership.md` | Cross-repository policy, environment and runtime contracts, task locks, release evidence, and operator commands |
| Web app | `TRR-APP` | `TRR-APP/AGENTS.md`, `TRR-APP/docs/Repository/README.md`, `docs/workspace/web-app-route-feature-inventory.md` | Public/admin UI, Next.js route edges and adapters, browser behavior, and explicitly app-local persistence |
| Backend | `TRR-Backend` | `TRR-Backend/AGENTS.md`, `TRR-Backend/CONTEXT.md`, `TRR-Backend/docs/Repository/README.md` | FastAPI contracts, shared schema and migrations, durable services, social ingestion, Modal jobs, and backend operations |

The legacy `TRR-APP/apps/web/.git` metadata was moved, after explicit approval
and full digest verification, to the external recovery quarantine recorded in
`docs/workspace/architecture-task-locks.json`. The workspace now has exactly
three active Git roots. Quarantined metadata must not be deleted without a
separate explicit approval.

## Shared boundary references

- Runtime placement: `docs/workspace/backend-runtime-ownership.md`
- Runtime capacity: `docs/workspace/runtime-capacity.json`
- Deployment identities: `docs/workspace/deployment-targets.json`
- Environment authority: `docs/workspace/env-contract.md`
- Local commands and Portless URLs: `docs/workspace/dev-commands.md`
- Database migration ownership: `docs/workspace/migration-ownership-policy.md`
- App-to-API migration ledger: `docs/workspace/api-migration-ledger.md`
- App direct-SQL inventory: `docs/workspace/app-direct-sql-inventory.md`
- Legacy output disposition: `docs/workspace/output-disposition.json`
- Task ownership locks: `docs/workspace/architecture-task-locks.json`
- Release packet contract: `docs/workspace/release-packet.schema.json`
- Evidence contract: `docs/workspace/architecture-evidence.schema.json`

Required architecture contracts are checked with
`scripts/architecture/check-durable-contracts.py`:

- `--boundary working-tree` requires every contract to exist and be visible to
  normal Git tracking. Untracked files are reported but allowed so a local
  dirty checkpoint remains honest.
- `--boundary candidate` additionally rejects every untracked required path.
  It checks trackability only; it does not stage, commit, or claim that a
  candidate commit exists.

Import-graph gates use `scripts/architecture/check-import-graph.py`:

- Gate 0E: `--check-frozen` requires exact source, edge, and metric hashes.
- Gate 1 and later refactor packets: `--check-baseline` allows debt to shrink
  but rejects increases above the recorded ceilings.
- Final architecture acceptance: `--check-zero` requires the named cycle and
  legacy-import metrics to be zero.

## Domain and decision records

- Backend glossary and domain language: `TRR-Backend/CONTEXT.md`
- Backend ADRs: `TRR-Backend/docs/adr/`
- Adaptive Instagram scrape control plane:
  `TRR-Backend/docs/adr/0001-adaptive-instagram-scrape-control-plane.md`

When a change crosses repositories, freeze the shared contract first,
implement the backend owner first, then update and validate the app consumer.
