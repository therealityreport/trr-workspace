# TRR Ordering and Guards

## Repository Order
When these repos are present, process in this order:
1. `TRR-Backend`
2. `screenalytics`
3. `TRR-APP`

Process remaining repos alphabetically after ordered repos.

## Repository Discovery Guard
- Only treat directories as repos when they are actual git repo roots/worktrees.
- Do not treat arbitrary subdirectories (for example `docs/` or `scripts/`) as separate repos when they belong to the workspace root repo.
- Include the workspace root itself when it is a git repo.

## Cross-Repo Constraints
- Keep backend-contract-first behavior when backend and app are both involved.
- Preserve same-session compatibility across repos when contract/schema changes exist.
- Keep final branch target as `main` unless explicitly overridden.

## PR Cardinality Guard
- Use one active PR per repo in a run.
- For follow-up fixes, push additional commits to the same branch/PR instead of creating new PRs.

## Clean Repo Policy
Default behavior is to create no-op PRs for clean repos:
- commit with `--allow-empty`
- open PR for auditability and “each repo” completion

Set `--create-noop-pr-for-clean false` to skip clean repos.

## Final State Requirement
At completion, each repo must satisfy:
1. checked out on `main`
2. `HEAD == origin/main`
3. clean working tree

If post-merge changes appear on `main`, open follow-up PR cycles automatically.
