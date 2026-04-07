# Workspace Cloud-First Validation Contract Phase 6

Date: 2026-04-03

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-03
  current_phase: "phase 6 contract freeze implemented"
  next_action: "Execute Phase 7 to align default scripts and profiles to the frozen cloud-first contract."
  detail: self
```

## What Landed
- `docs/workspace/dev-commands.md` now states one preferred contract explicitly: `make dev` is the cloud-first default and `make dev-local` is Docker-backed fallback only.
- The generated workspace env contract now includes the same top-level policy so daily docs and generated docs do not drift on the preferred path.
- Script-facing wording in `scripts/dev-workspace.sh`, `scripts/doctor.sh`, `scripts/preflight.sh`, and `scripts/status-workspace.sh` now labels `local_docker` as an explicit fallback instead of implying it is a peer default.

## Canonical Contract After Phase 6
- Preferred development path:
  - `make dev`
  - normal backend and app work should not require Docker
- Preferred validation path:
  - use an isolated Supabase branch or disposable database target
  - point `TRR_DB_URL` at that isolated target
  - run verification against that isolated target
- Fallback-only local path:
  - use `make dev-local` or local Docker-backed DB replay only when you intentionally need local-only infrastructure that the cloud-first path does not answer

## Safety Boundaries
- Never run destructive replay or reset verification against production or other long-lived shared persistent databases.
- Remote-first validation must use isolated branch/disposable targets.
- This phase froze the wording and guardrails only; Phase 7 owns broader default/script alignment.

## Verification
- `bash /Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh`
- `python3 /Users/thomashulihan/Projects/TRR/scripts/env_contract_report.py validate`
- `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh /Users/thomashulihan/Projects/TRR/scripts/doctor.sh /Users/thomashulihan/Projects/TRR/scripts/preflight.sh /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`
