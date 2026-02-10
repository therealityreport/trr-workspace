# Cross-Collab Workflow Guide

Path: `docs/cross-collab/WORKFLOW.md`

This is the canonical end-to-end lifecycle for cross-repo tasks in the TRR workspace.
It complements `AGENTS.md` (workspace root) and each repo's `AGENTS.md`.

## Section 1 — Cross-Collab Lifecycle (9 Steps)

| Step | Who | Action |
|------|-----|--------|
| 1. Receive plan | Agent | Read plan/spec. Identify which repos are affected. |
| 2. Create TASK folders | Agent | Create `docs/cross-collab/TASK{N}/` in each affected repo with `PLAN.md` + `OTHER_PROJECTS.md` + `STATUS.md` (use templates in Section 3). Next sequential number per repo. |
| 3. Implement | Agent | Follow repo order: TRR-Backend → screenalytics → TRR-APP. Run each repo's fast checks after changes. |
| 4. Update `STATUS.md` | Agent | Mark phases Implemented/Complete as you go. Add dated entries to Recent Activity. |
| 5. Verify | Agent | Per-repo fast checks: TRR-Backend (`ruff check . && ruff format --check . && pytest -q`), screenalytics (`pytest -q`), TRR-APP (`pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`). |
| 6. Commit + PR | Agent | One PR per repo. Use PR template (Section 3d). Include `docs/cross-collab/` changes in the PR. |
| 7. Merge | Human/Agent | Merge PRs in implementation order (Backend → screenalytics → APP). |
| 8. Sync docs | Agent | Update all `OTHER_PROJECTS.md` snapshots to reflect merged state. Final `STATUS.md` Recent Activity entry. |
| 9. Close out | Agent | Update `docs/ai/HANDOFF.md` in each touched repo. |

## Section 2 — Task Numbering Rules

- Numbers are per-repo sequential (`TASK1`, `TASK2`, ...) — NOT globally synchronized across repos.
- The same logical feature may be `TASK4` in one repo and `TASK5` in another.
- When inserting a new task mid-sequence, renumber only within that repo.
- After any renumbering, grep for stale cross-references:

```bash
rg -n "TRR-APP TASK{old}|TRR-Backend TASK{old}|screenalytics TASK{old}" \
  TRR-Backend/docs/cross-collab/ TRR-APP/docs/cross-collab/ screenalytics/docs/cross-collab/
```

## Section 3 — Templates

### 3a. PLAN.md Template

```markdown
# {Title} — Task {N} Plan

Repo: {REPO_NAME}
Last updated: {DATE}

## Goal
{One sentence describing the objective.}

## Status Snapshot
{Current state, e.g. "Not yet started. Depends on TRR-Backend TASK{X}."}

## Scope

### Phase {id}: {Phase Title}
{Description of what this phase does.}

Files to change:
- `path/to/file.ext` — {what changes}

## Out of Scope
- {Item owned by another repo/task}

## Locked Contracts
### {Contract Name}
{Schema, API shape, or convention that must not drift.}

## Acceptance Criteria
1. {Criterion 1}
2. {Criterion 2}
3. Existing tests pass with no regressions.
4. Task {N} docs are synchronized across repos.
```

### 3b. OTHER_PROJECTS.md Template

```markdown
# Other Projects — Task {N} ({Title})

Repo: {REPO_NAME}
Last updated: {DATE}

## Cross-Repo Snapshot
- TRR-Backend: {Status}. See TRR-Backend TASK{X}.
- TRR-APP: {Status}. See TRR-APP TASK{Y}.
- screenalytics: {Status}. See screenalytics TASK{Z}.

## Responsibility Alignment
- TRR-Backend
  - {What this repo owns}
- TRR-APP
  - {What this repo owns}
- screenalytics
  - {What this repo owns}

## Dependency Order
1. {First step — which repo, what action}
2. {Second step}

## Locked Contracts (Mirrored)
- {Contract details — must match PLAN.md in owning repo}
```

### 3c. STATUS.md Template

```markdown
# Status — Task {N} ({Title})

Repo: {REPO_NAME}
Last updated: {DATE}

## Phase Status

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| {id} | {Description} | Pending/Implemented/Complete/Blocked | {Notes} |

## Blockers
- {Blocker description, or "None."}

## Recent Activity
- {DATE}: {What happened.}
```

### 3d. PR Description Template

```markdown
## Summary
- {Bullet 1: what changed}
- {Bullet 2: why}

## Test plan
- [ ] `ruff check . && ruff format --check .` (TRR-Backend)
- [ ] `pytest -q` (TRR-Backend / screenalytics)
- [ ] `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` (TRR-APP)
- [ ] Cross-repo docs updated (PLAN.md, STATUS.md, OTHER_PROJECTS.md)

## Cross-collab refs
- TRR-Backend TASK{N}: `docs/cross-collab/TASK{N}/`
- TRR-APP TASK{M}: `docs/cross-collab/TASK{M}/`
- screenalytics TASK{K}: `docs/cross-collab/TASK{K}/`
```

## Section 4 — Common Patterns

**Migration-first**: Deploy schema changes (migrations, views) before consumer code. This ensures the database is ready before any app tries to use new structures.

**View bridge**: When dropping a table that has consumers in other repos, create a replacement view first (`CREATE VIEW ... AS SELECT ... FROM new_tables`). Deploy the view, switch all consumers, then drop the original table.

**Independent phases**: When a task has multiple phases with no data dependencies between them, implement them in parallel across repos. Document which phases are independent in PLAN.md.

## Section 5 — Production Deploy Runbook (Current Release)

**What's being deployed**: Supabase Data Layer Unification (migrations `0102–0105`) + Schema Cleanup (migrations `0106–0114`) + drift reconciliation (`0115`).

**Pre-deploy checklist**:
- [ ] All repos merged to `main` (TRR-Backend PR #48, screenalytics `a40943c` + `2cb6f41`, TRR-APP PR #23)
- [ ] Staging Supabase migrations `0102–0115` applied (`supabase db push --linked` reports up to date)
- [ ] Credits backfill verified on staging (see Section 6)

**Deploy order**:
1. **Supabase (production)**: `supabase db push --linked` against production project. Applies migrations `0102–0115`.
2. **TRR-Backend (Cloud Run)**: Deploy via Cloud Run continuous deployment from `main` branch, or manually via `gcloud`. See `TRR-Backend/docs/deploy/cloud_run.md` for full instructions. Note: `gcloud auth login` is interactive.
3. **screenalytics (EC2)**: Pull latest `main` on EC2 instance, restart systemd services. See `screenalytics/infra/README.md`. Ensure `.env` has `TRR_DB_URL` pointing to production Supabase.
4. **TRR-APP (Vercel)**: Auto-deploys on merge to `main`. Verify Vercel preview before production promotion.

**Post-deploy verification**:
- [ ] TRR-Backend: `curl https://<trr-backend-url>/health` returns 200
- [ ] screenalytics: `curl https://<screenalytics-url>/healthz` returns 200
- [ ] TRR-APP: Cast pages render correctly using credits-backed views
- [ ] Credits parity check passes (Section 6)

## Section 6 — Credits Backfill & Verification

**Purpose**: Before legacy cast table drops take effect in production, verify the credits model contains equivalent data.

**Scripts** (exist in TRR-Backend):
- `scripts/backfill/backfill_credits.py` (also at `scripts/backfill_credits.py`)
- `scripts/verify/verify_credits_parity.py` (also at `scripts/verify_credits_parity.py`)

**Staging procedure**:
1. Set `TRR_DB_URL` to staging Supabase connection string.
2. Run backfill.
3. Run verification.
4. Expected: row counts match between legacy cast tables and credits model. No data discrepancies.
5. Verify replacement views: `SELECT count(*) FROM core.v_show_cast` should match legacy equivalent.

Example (staging):
```bash
cd TRR-Backend
export TRR_DB_URL="postgresql://..."

PYTHONPATH=. python scripts/backfill/backfill_credits.py --pass all --verbose
PYTHONPATH=. python scripts/verify/verify_credits_parity.py --limit 20 --spot-check 10 --verbose
```

**Production procedure** (after staging verification passes):
1. Repeat the same steps with `TRR_DB_URL` pointing to production Supabase.
2. After parity confirmed, migration `0107` (cast table drops) can safely take effect.
3. Note: Compatibility views (`core.v_show_cast`, `core.v_episode_cast`) remain available after drops — they're built on `credits` + `credit_occurrences`.
