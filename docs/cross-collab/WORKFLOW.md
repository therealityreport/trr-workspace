# Cross-Collab Workflow Guide

Path: `docs/cross-collab/WORKFLOW.md`

This is the canonical end-to-end lifecycle for cross-repo tasks in the TRR workspace.
It complements `AGENTS.md` (workspace root) and each repo's `AGENTS.md`.

## Section 1 — Cross-Collab Lifecycle (9 Steps)

| Step | Who | Action |
|------|-----|--------|
| 1. Receive plan | Agent | Read plan/spec. Identify which repos are affected. |
| 2. Create TASK folders | Agent | Create `docs/cross-collab/TASK{N}/` in each affected repo with `PLAN.md` + `OTHER_PROJECTS.md` + `STATUS.md` (use templates in Section 3). Next sequential number per repo. |
| 3. Implement | Agent | Follow repo order: TRR-Backend → TRR-APP. Run each repo's fast checks after changes. |
| 4. Update canonical status sources | Agent | Immediately after each completed implementation phase or materially completed plan step, update `STATUS.md` or `docs/ai/local-status/*.md`. These are the only handoff source files; they must carry a `## Handoff Snapshot` block when they should surface in handoff. |
| 5. Sync generated `HANDOFF.md` | Agent | Run `scripts/handoff-lifecycle.sh post-phase` after each completed implementation phase when current state, blockers, or next action changed. `docs/ai/HANDOFF.md` is generated output only. |
| 6. Verify | Agent | Per-repo fast checks: TRR-Backend (`ruff check . && ruff format --check . && pytest -q`), TRR-APP (`pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`). |
| 7. Commit + PR | Agent | One PR per repo. Use PR template (Section 3d). Include `docs/cross-collab/` changes in the PR. |
| 8. Merge | Human/Agent | Merge PRs in implementation order (Backend → APP). |
| 9. Sync docs + close out | Agent | Update `OTHER_PROJECTS.md` snapshots, add the final `STATUS.md` Recent Activity entry, and run `scripts/handoff-lifecycle.sh closeout` for final generated handoff + policy verification. |

Before any formal `<proposed_plan>` or documented multi-phase implementation plan, run `scripts/handoff-lifecycle.sh pre-plan`. This is not required for ad-hoc Q&A or one-off comments with no formal plan artifact.

Use `scripts/codex-formal-plan.sh ...` when you want a launcher that performs the pre-plan check automatically before starting a formal Codex planning session.

## Section 2 — Task Numbering Rules

- Numbers are per-repo sequential (`TASK1`, `TASK2`, ...) — NOT globally synchronized across repos.
- The same logical feature may be `TASK4` in one repo and `TASK5` in another.
- When inserting a new task mid-sequence, renumber only within that repo.
- After any renumbering, grep for stale cross-references:

```bash
rg -n "TRR-APP TASK{old}|TRR-Backend TASK{old}" \
  TRR-Backend/docs/cross-collab/ TRR-APP/docs/cross-collab/
```

### Task Scaffolder (Recommended)

Use the workspace scaffolder to create new task folders with templates:

```bash
cd /Users/thomashulihan/Projects/TRR
./scripts/new-cross-collab-task.sh \
  --repos TRR-Backend,TRR-APP \
  --title "Your task title"
```

This creates the next sequential `TASK{N}` in each selected repo with `PLAN.md`, `OTHER_PROJECTS.md`, and `STATUS.md`.

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

## Responsibility Alignment
- TRR-Backend
  - {What this repo owns}
- TRR-APP
  - {What this repo owns}

## Dependency Order
1. {First step — which repo, what action}
2. {Second step}

## Locked Contracts (Mirrored)
- {Contract details — must match PLAN.md in owning repo}
```

### 3c. STATUS.md Template

````markdown
# Status — Task {N} ({Title})

Repo: {REPO_NAME}
Last updated: {DATE}

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active | blocked | recent | archived
  last_updated: YYYY-MM-DD
  current_phase: "{short phrase}"
  next_action: "{short phrase}"
  detail: self | "../ACCEPTANCE_REPORT.md"
```

## Phase Status

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| {id} | {Description} | Pending/Implemented/Complete/Blocked | {Notes} |

## Blockers
- {Blocker description, or "None."}

## Recent Activity
- {DATE}: {What happened.}
````

Use `STATUS.md` as the canonical detailed continuity log for the task. Do not mirror the full dated history into `docs/ai/HANDOFF.md`.

If `ACCEPTANCE_REPORT.md` exists, keep validation evidence there and reference it from `STATUS.md` instead of duplicating long command transcripts elsewhere.

### 3d. HANDOFF.md Template

```markdown
# Session Handoff ({SCOPE})

Generated by `scripts/sync-handoffs.py`. Do not edit by hand.

Purpose: active-work index for multi-turn AI agent sessions in this scope. Keep this file short.

## Current Active Work
- `{task/reference}` | last updated `{timestamp}` | current phase `{phase}` | next action `{next action}` | details `{canonical link}`

## Blocked / Waiting
- `{task/reference}` | last updated `{timestamp}` | current phase `{phase}` | next action `{next action}` | details `{canonical link}`

## Recent Completions
- `{task/reference}` | last updated `{timestamp}` | current phase `{phase}` | next action `{next action}` | details `{canonical link}`

## Older Plans
- `{task/reference}` | last updated `{timestamp}` | current phase `{phase}` | next action `{next action}` | details `{canonical link}`

## Archives / Canonical Links
- History archive: `{archive link}`
- Active task detail: `{STATUS.md or equivalent link}`
```

Rules:
- Keep `HANDOFF.md` as generated output, not an append-only changelog.
- Cap `Recent Completions` to a short recent window.
- Move stale entries into generated `Older Plans` instead of failing handoff sync. Freshness windows are `active` 3 days, `blocked` 14 days, and `recent` 7 days.
- For work without a `TASK*` folder, create `docs/ai/local-status/*.md` and let the generator link to that canonical doc.

### 3e. PR Description Template

```markdown
## Summary
- {Bullet 1: what changed}
- {Bullet 2: why}

## Test plan
- [ ] `ruff check . && ruff format --check .` (TRR-Backend)
- [ ] `pytest -q` (TRR-Backend)
- [ ] `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` (TRR-APP)
- [ ] Cross-repo docs updated (PLAN.md, STATUS.md, OTHER_PROJECTS.md)

## Cross-collab refs
- TRR-Backend TASK{N}: `docs/cross-collab/TASK{N}/`
- TRR-APP TASK{M}: `docs/cross-collab/TASK{M}/`
```

## Section 4 — Common Patterns

**Migration-first**: Deploy schema changes (migrations, views) before consumer code. This ensures the database is ready before any app tries to use new structures.

**View bridge**: When dropping a table that has consumers in other repos, create a replacement view first (`CREATE VIEW ... AS SELECT ... FROM new_tables`). Deploy the view, switch all consumers, then drop the original table.

**Independent phases**: When a task has multiple phases with no data dependencies between them, implement them in parallel across repos. Document which phases are independent in PLAN.md.

**Vercel env review gate**: Before any survey or app cutover that depends on Vercel runtime env contracts, compare `vercel env ls` and `vercel env pull` for the active project. Any pull-only or otherwise unexplained env must be classified as `canonical`, `deprecated-removable`, `integration-managed-retained`, or `unknown-blocking`. Cutover is blocked while any `unknown-blocking` entry remains. Reviewed retained vars should be recorded in `docs/workspace/vercel-env-review.md`.

## Section 5 — Production Deploy Runbook (Current Release)

**What's being deployed**: Supabase Data Layer Unification (migrations `0102–0105`) + Schema Cleanup (migrations `0106–0114`) + drift reconciliation (`0115`).

**Pre-deploy checklist**:
- [ ] All repos merged to `main` (TRR-Backend PR #48, TRR-APP PR #23)
- [ ] Staging Supabase migrations `0102–0115` applied (`supabase db push --linked` reports up to date)
- [ ] Credits backfill verified on staging (see Section 6)

**Deploy order**:
1. **Supabase (production)**: `supabase db push --linked` against production project. Applies migrations `0102–0115`.
2. **TRR-Backend (Cloud Run)**: Deploy via Cloud Run continuous deployment from `main` branch, or manually via `gcloud`. See `TRR-Backend/docs/deploy/cloud_run.md` for full instructions. Note: `gcloud auth login` is interactive.
3. **TRR-APP (Vercel)**: Auto-deploys on merge to `main`. Verify Vercel preview before production promotion.

**Post-deploy verification**:
- [ ] TRR-Backend: `curl https://<trr-backend-url>/health` returns 200
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
