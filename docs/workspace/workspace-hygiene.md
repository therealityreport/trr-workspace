# TRR Workspace Hygiene

Created: 2026-05-21

This contract keeps local cleanup safe. It explains what is active TRR source,
what is adjacent work, and what can be reported or cleaned without changing app
or backend behavior.

## Simple Rule

Start from the current user request, `AGENTS.md`, the project rules, and live
files. Older notes and plans are evidence only. They are not permission to edit,
delete, or continue work until they are checked against the current branch,
current files, and the user's current request.

## Active Roots

- Root workspace orchestration: `Makefile`, `scripts/`, `profiles/`, `.codex/`,
  and `docs/workspace/`.
- Backend: `TRR-Backend/api/`, `TRR-Backend/trr_backend/`,
  `TRR-Backend/tests/`, and `TRR-Backend/supabase/`.
- Web app: `TRR-APP/apps/web/src/` and `TRR-APP/apps/web/tests/`.
- Documentation contracts: `AGENTS.md`, `.codex/rules/trr-project.md`, and the
  docs under `docs/workspace/`.

These paths are active work areas. Do not rename, remove, format, or clean them
as hygiene unless the current task explicitly includes that change and the
right validation is run.

## Retired Local Checkouts

`screenalytics/` is retired local state for TRR workspace startup and hygiene.
Recurring workspace commands must not require it, report it as an active
adjacent checkout, or delete from it.

`BRAVOTV/`, `.external/`, `data/`, and nested repo checkouts are adjacent
workspaces. They can be useful context, but they are separate ownership domains.
Do not edit or delete files inside them unless a task explicitly includes that
workspace.

Any remaining `screenalytics/` checkout, env file, git history, or data
directory is protected local state until a separate one-time retirement cleanup
task names exactly what to archive or remove.

## Plan Authority

`.plan-work/plan-architect/*` contains planning artifacts. A plan can guide an
implementation only when the user names it or the current task explicitly
depends on it. Before acting on any old plan, re-check:

- current branch and git status,
- current file contents,
- current tests or runtime state that matter to the task,
- current user scope and exclusions.

Stale plans should be treated as historical evidence, not live instructions.

## Read-Only Report

Run:

```bash
make workspace-hygiene-report
```

The report prints:

- root, backend, and app git status,
- known large local artifacts,
- ignored runtime clutter categories,
- untracked non-ignored items,
- active-root search guidance,
- a clear statement that no files were deleted.

The report is read-only and must keep working when optional paths such as
`.logs`, `.plan-work`, retired `screenalytics/`, or build output are missing.

## Dry-Run Cleanup

Run:

```bash
make workspace-hygiene-clean-dry-run
```

This command is dry-run only. It lists conservative candidates and deletes
nothing. The current cleanup boundary is limited to ignored rebuildable clutter:

- `__pycache__/`
- `*.pyc`
- `.DS_Store`

## Env Hygiene

Run:

```bash
make env-hygiene
```

Env hygiene validates file authority, not secret contents. The command reads
env key names only and never prints values.

Authority classes:

- Source of truth: `docs/workspace/shared-env-manifest.json` plus generated
  contract projections under `docs/workspace/`.
- Runtime profile adapters: checked-in files under `profiles/*.env`.
- Surface setup adapters: checked-in `.env.example` files for TRR-APP,
  TRR-Backend, and any still-supported runtime surface.
- Local secret adapters: ignored files such as `TRR-APP/apps/web/.env.local`
  and `TRR-Backend/.env`.
- Retired env surfaces: adjacent or retired checkout env files. These are
  excluded by default; set `WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT=1` when a
  task intentionally needs key-name evidence from retired local state such as
  `screenalytics/.env`.
- Evidence snapshots: generated or pulled files under `.logs/`, `.artifacts/`,
  and `.vercel/`.

The command may warn when a shared key appears in more than one ignored local
secret adapter. Each warning includes a cleanup status for the local file:

- `keep`: the key belongs in that local adapter.
- `move`: the key should live in a narrower shell/profile override instead of
  the always-loaded local adapter.
- `remove`: the key is obsolete or belongs to another runtime surface.

The markdown dry-run status report uses the same statuses across every
configured env-file surface: runtime profiles, setup examples, ignored local
secret adapters, and generated evidence snapshots. Evidence snapshots are
reported as `keep` because they are observations, not files to edit. Terminal
output stays focused on local adapters plus `remove`/`move` rows; write a
markdown report when you need the complete all-env-files table.

The command fails only for authority drift, such as deprecated runtime names in
examples/profiles or shared env keys without manifest ownership.

## Runtime Lock State

`TRR-Backend/.locks/` stores small local lock files used by backend jobs, such
as social auth refresh work, so two runs do not step on each other. These files
are machine-local runtime state, not source code and not evidence artifacts.

The lock directory is ignored by `TRR-Backend/.gitignore`. Hygiene report and
cleanup commands may classify it as runtime state, but cleanup must not delete
the directory or any lock JSON by default.

The cleanup command must not delete:

- dirty tracked source files,
- untracked non-ignored files,
- `.logs/` wholesale,
- `.plan-work/`,
- `.artifacts/` or `output/`,
- retired `screenalytics/` checkout state,
- `TRR-Backend/.locks/` and lock JSON files,
- dependency and build folders such as `node_modules/`, `.next/`, `.venv/`,
  and `.worktrees/`,
- `.env*`, secrets, cookies, auth state, or evidence directories.

Destructive cleanup is intentionally not part of this command. If a future task
requires deletion, it must name the exact target and re-check ownership,
excluded paths, and current git status before any removal command is introduced.

## Active Search Guidance

Default active-source search:

```bash
rg "term" Makefile scripts profiles .codex docs/workspace TRR-Backend/api TRR-Backend/trr_backend TRR-Backend/tests TRR-APP/apps/web/src TRR-APP/apps/web/tests
```

Use broad repository searches only when the task needs generated output,
runtime evidence, old plans, adjacent workspaces, or retired local checkout
state. When you do, explain why that wider search is needed.

## Related Contracts

- `docs/workspace/codebase-cleanup-inventory.md`
- `docs/workspace/backend-codebase-cleanup-inventory.md`
- `docs/workspace/codebase-cleanup-validation-matrix.md`
- `docs/ai/HANDOFF_WORKFLOW.md`
