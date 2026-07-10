# Plan 019: Remove tracked root scratch artifacts

> **Executor instructions**: This is repo hygiene. Do not delete untracked user
> files; only handle tracked artifacts after confirming with `git ls-files`.
>
> **Drift check**: `git diff --stat fb76b5b..HEAD -- plan.md instagram-backfill-debug-report.md claude-desktop-ui-mod-plan.html design-docs-agent-comparison.html TRR-Backend/test_connection.py TRR-Backend/backfill_tmdb_show_details.py TRR-Backend/resolve_tmdb_ids_via_find.py .gitignore TRR-Backend/.gitignore`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: workspace `fb76b5b`, TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

The workspace has tracked scratch reports and tiny backend root scripts that
duplicate real script locations. They add noise to searches and reviews.

## Current state

Tracked workspace-root artifacts:
- `plan.md` (336 lines)
- `instagram-backfill-debug-report.md` (337 lines)
- `claude-desktop-ui-mod-plan.html` (327 lines)
- `design-docs-agent-comparison.html` (463 lines)

Backend root artifacts exist at:
- `TRR-Backend/test_connection.py`
- `TRR-Backend/backfill_tmdb_show_details.py`
- `TRR-Backend/resolve_tmdb_ids_via_find.py`

## Scope

**In scope**:
- tracked files named above
- `.gitignore` / `TRR-Backend/.gitignore` only if needed to prevent recurrence

**Out of scope**:
- Any docs under `docs/`
- Any untracked file not listed by `git ls-files`

## Steps

1. Run `git ls-files` for every candidate file.
2. For each tracked scratch artifact, either remove it from the repo or move the
   useful content into a proper docs path if it is still current.
3. For backend root scripts, prefer deleting if canonical scripts already exist
   under `scripts/`; otherwise move to the right scripts directory.
4. Add ignore rules only for generated scratch patterns, not broad markdown/html.

## Commands

Run from workspace root:

```bash
git ls-files plan.md instagram-backfill-debug-report.md claude-desktop-ui-mod-plan.html design-docs-agent-comparison.html TRR-Backend/test_connection.py TRR-Backend/backfill_tmdb_show_details.py TRR-Backend/resolve_tmdb_ids_via_find.py
git status --short
```

## Done criteria

- The listed tracked scratch files are removed or moved to canonical locations.
- No unrelated untracked user files are touched.
- `git status` shows only the intended hygiene changes.
