# PATCHES

The revised plan preserves the source structure and applies targeted planning changes.

## Patch 1 - Make current row-count drift a hard preflight blocker

Source issue: the plan targets `1,324` rows from the owner request, but the current CSV parses as `1,302`.

Revised behavior:

- Phase 0 now records the current CSV totals.
- Execution must reconcile owner-supplied counts against the current CSV/MD and live inventory before any matrix work.
- The review universe is not allowed to silently shrink from `1,324` to `1,302`.

## Patch 2 - Treat current detached HEAD and conflicts as blockers

Source issue: the source plan mentioned dirty-state checks but did not preserve the full current conflict set.

Revised behavior:

- Project context now records detached `HEAD` and unresolved conflicts.
- Phase 0 stops unless the owner resolves conflicts or explicitly approves artifact-only/index-review work in the dirty state.

## Patch 3 - Prevent prior Phase 3 SQL from becoming implicit approval

Source issue: existing files under `docs/workspace/unused-index-owner-review-2026-04-28/` include prior `phase3-*-approved-drops.sql` artifacts.

Revised behavior:

- Those files are treated as historical evidence only.
- The new decision matrix must recompute approval from the full-review rules.
- No prior approved SQL can be imported into `approved_to_drop=yes` without new row evidence.

## Patch 4 - Add concrete subagent roster and write scopes

Source issue: the plan recommended `orchestrate-subagents` but did not assign disjoint packet ownership.

Revised behavior:

- The revised plan adds six owner/workload workstreams with separate packet paths.
- The main session owns preflight, matrix schema, reconciliation, final CSV/MD integration, and Phase 3 batch filtering.

## Patch 5 - Add validation snippets for the riskiest mistakes

Source issue: validation commands were good but did not include exact checks for row-count drift or illegal approved rows.

Revised behavior:

- Adds CSV validators for required columns, row counts, decision totals, and approved-drop required fields.
- Adds a check that proposed batches include only `approved_to_drop=yes`.
