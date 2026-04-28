# SUGGESTIONS

These are optional follow-ups. They are not required fixes for approval.

1. **Title:** Add an advisor diff helper
   **Type:** Medium
   **Why:** Manual count comparisons are easy to misread.
   **Where it would apply:** `scripts/` or `TRR-Backend/scripts/db/`
   **How it could improve the plan:** Generate before/after lint deltas from saved advisor snapshots.

2. **Title:** Generalize the policy semantics test harness after Phase 1
   **Type:** Large
   **Why:** The Phase 1 permission matrix is now required for the target tables, but the same pattern will be useful for future policy work.
   **Where it would apply:** `TRR-Backend/tests/db/`
   **How it could improve the plan:** Turn the one-off target-table matrix into a reusable helper for later RLS migrations.

3. **Title:** Store redacted `pg_policies` snapshots as markdown tables
   **Type:** Small
   **Why:** JSON or raw SQL output is harder to review.
   **Where it would apply:** `docs/workspace/`
   **How it could improve the plan:** Makes policy drift easier to audit during review.

4. **Title:** Add index candidate age detection
   **Type:** Medium
   **Why:** Recent indexes may have zero scans only because workload has not run.
   **Where it would apply:** unused-index evidence script
   **How it could improve the plan:** Reduces false-positive drop candidates.

5. **Title:** Add route owner labels to index review output
   **Type:** Medium
   **Why:** A DB index can serve multiple pages or jobs.
   **Where it would apply:** unused-index review report
   **How it could improve the plan:** Prevents DB-only review from missing app/backend consumers.

6. **Title:** Add a rollback smoke checklist per index batch
   **Type:** Small
   **Why:** Concurrent index drops need fast operator response if a route slows down.
   **Where it would apply:** `docs/workspace/unused-index-advisor-review-*.md`
   **How it could improve the plan:** Makes rollback practical instead of theoretical.

7. **Title:** Add a dashboard evidence template for advisor closeout
   **Type:** Small
   **Why:** Advisor screenshots and dashboard state can be inconsistent if captured ad hoc.
   **Where it would apply:** `docs/workspace/supabase-dashboard-evidence-template.md`
   **How it could improve the plan:** Standardizes closeout proof.

8. **Title:** Track write-latency impact for social backfills
   **Type:** Medium
   **Why:** Index drops should improve write-heavy jobs, but the benefit should be observed.
   **Where it would apply:** social backfill logs or DB pressure docs
   **How it could improve the plan:** Gives the cleanup a concrete operational payoff.

9. **Title:** Add a "do not drop" index registry
   **Type:** Medium
   **Why:** Some rarely used indexes are intentionally retained.
   **Where it would apply:** `docs/workspace/` or `TRR-Backend/scripts/db/`
   **How it could improve the plan:** Prevents future advisor runs from repeatedly proposing rejected drops.

10. **Title:** Create the full safety-plan stub after the hotfix gate
    **Type:** Small
    **Why:** The emergency safety hotfix is now required; the broader search-path/vector work still needs a clean follow-up plan.
    **Where it would apply:** `docs/codex/plans/`
    **How it could improve the plan:** Gives the hotfix gate a clean handoff to the later full security pass.
