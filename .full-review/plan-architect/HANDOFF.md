# HANDOFF — orchestrate-subagents runbook

**Canonical plan:** `.full-review/REMEDIATION_PLAN.md`. **Findings index:** `.full-review/_raw-findings.json`.

## Preconditions (must hold before launch)
1. **Clean working tree** (or the `.full-review/` artifacts committed) — subagents edit `main` with no branches.
2. **Scope confirmed by human** (default below).
3. **🔒 Wave 0 items owned by a human** — NOT handed to subagents.

## Default auto-execution scope (recommended)
- **Gate G0 first:** Workstream V (read-only verify of 5 leads). Promote confirmed leads (esp. TRR-APP secret-scan) into W1.1.
- **Wave 1 (parallel):** `0A-cron`, `0A-modal`, `W1.1`, `W1.2`, `W1.4`, `W1.6`, `W1.7`.
  - Constraint: `0A-modal` edits `api/main.py` before any `W1.3` work.
  - Commit + run wave-boundary validation before Wave 2.
- **Wave 2 (serialized by ownership):** `W1.3` (backend sanitizer → app proxy), then `W1.5`.

## Explicitly excluded from subagents
- **Wave 0 🔒:** anon-grant revoke, key removal+rotation, branch protection, destructive/RLS-reconciliation migrations. *(Subagents may PREPARE migration files; a human reviews + applies + redeploys.)*
- **Wave 3 staged refactors** (`W1.S1/S2/S3`): each is its own future plan; scaffold + one step only, sequential, single-owner, behind green tests. Do not auto-run as part of this batch.

## Per-wave validation gate
- Backend: `cd TRR-Backend && ruff check . && ruff format --check . && pyright && pytest -q`
- App: `pnpm -C TRR-APP/apps/web lint && typecheck && test:ci && build`
- Workspace: `make preflight && make workspace-contract-check && bash scripts/test-changed.sh`
- Modal: redeploy after `0A-modal` (+ any worker change); verify unauth `/metrics` rejected.

## Sequencing constraints (do not reorder)
- W1.1 (CI) green **before** 0B branch protection (else all merges blocked).
- W1.3 completes **before** Wave 3 S-streams (shared `api/routers/**`).
- Cross-repo static-secret-gate removal (Phase 2) = one slice + rollback (do not split backend/app).

## Stop conditions
- Any wave-boundary validation fails → stop, surface, do not start next wave.
- A subagent needs a file owned by another active workstream → stop and serialize.
