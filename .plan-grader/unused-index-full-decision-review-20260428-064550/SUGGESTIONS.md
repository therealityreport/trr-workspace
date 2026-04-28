# SUGGESTIONS

These are optional improvements, not required fixes for approval.

1. **Title:** Add a reusable decision-matrix validator
   **Type:** Medium
   **Why:** The matrix has many required columns and approval invariants.
   **Where it would apply:** `TRR-Backend/scripts/db/` or `scripts/`
   **How it could improve the plan:** Turns CSV shape, row-count, and approved-drop checks into one repeatable command.

2. **Title:** Generate owner packet filenames from workload slugs
   **Type:** Small
   **Why:** Existing packet names and requested packet names differ.
   **Where it would apply:** decision-matrix generation helper
   **How it could improve the plan:** Prevents packet naming drift between CSV, MD, and owner-review directory.

3. **Title:** Add a no-destructive-SQL scanner
   **Type:** Small
   **Why:** This review must never execute or stage live drops.
   **Where it would apply:** validation phase
   **How it could improve the plan:** Flags accidental runnable `DROP INDEX` blocks outside proposed batch artifacts.

4. **Title:** Add a social hashtag architecture stub
   **Type:** Medium
   **Why:** The product architecture blocker is central to social search index decisions.
   **Where it would apply:** `docs/codex/plans/` or `docs/workspace/`
   **How it could improve the plan:** Gives future reviewers a canonical place to resolve hashtag leaderboard/search architecture.

5. **Title:** Save stats-window evidence as a small JSON artifact
   **Type:** Small
   **Why:** Markdown summaries are easy to read but harder to assert.
   **Where it would apply:** `docs/workspace/`
   **How it could improve the plan:** Lets validators confirm `stats_window_checked_at` and stats-window age programmatically.

6. **Title:** Add per-workload time budgets
   **Type:** Medium
   **Why:** Reviewing all rows can sprawl.
   **Where it would apply:** subagent roster section
   **How it could improve the plan:** Helps the orchestrator decide when a row should become `needs_manual_query_review` rather than consuming unbounded review time.

7. **Title:** Add query-pattern taxonomy labels
   **Type:** Medium
   **Why:** Free-form `query_pattern_supported` text may be hard to summarize later.
   **Where it would apply:** decision matrix columns or helper script
   **How it could improve the plan:** Makes replacement candidates and route-dependency patterns easier to group.

8. **Title:** Add a prior-approval quarantine list
   **Type:** Small
   **Why:** Prior Phase 3 SQL files are present and can confuse future sessions.
   **Where it would apply:** `docs/workspace/unused-index-owner-review-2026-04-28/README.md`
   **How it could improve the plan:** Clearly separates historical approved drops from the new full-review decision matrix.

9. **Title:** Add sample owner packet table schema
   **Type:** Small
   **Why:** Six subagents may format packet evidence differently.
   **Where it would apply:** revised plan or owner-review README
   **How it could improve the plan:** Keeps owner packets consistent enough to merge cleanly.

10. **Title:** Add post-review Advisor delta snapshot
    **Type:** Medium
    **Why:** The review does not change live indexes, but Advisor state may still drift.
    **Where it would apply:** closeout phase
    **How it could improve the plan:** Captures whether the remaining unused-index count changed during the review window.
