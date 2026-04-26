# Suggestions

1. Title: Add explicit non-goals
   Type: Small
   Why: The plan is broad enough that workers may assume production rollout is included.
   Where it would apply: Plan header or Scope Check.
   How it could improve the plan: It would make clear that this pass stabilizes dev/local backfill behavior unless separately promoted.

2. Title: Split benchmark execution if runs are slow
   Type: Medium
   Why: Live browser/runtime trials can consume significant time.
   Where it would apply: Task 8.
   How it could improve the plan: It would let workers complete control-plane stabilization before committing to a full method bakeoff.

3. Title: Add a DB pool pressure dashboard snapshot
   Type: Medium
   Why: Before/after evidence would make the pool isolation benefit easier to validate.
   Where it would apply: Task 9 verification.
   How it could improve the plan: It would give operators a concrete regression baseline.

4. Title: Add rollback commands for workspace cap changes
   Type: Small
   Why: Lower caps are safe but may slow later high-throughput tests.
   Where it would apply: Task 2.
   How it could improve the plan: It would make temporary stress testing easier after stabilization.

5. Title: Add a one-run canary command per platform
   Type: Medium
   Why: Each platform has different auth and media behavior.
   Where it would apply: Task 9.
   How it could improve the plan: It would make the end-to-end smoke more reproducible.

6. Title: Capture Modal invocation IDs in benchmark report
   Type: Small
   Why: Invocation IDs help debug cloud-side differences.
   Where it would apply: Task 8 report template.
   How it could improve the plan: It would connect browser evidence to Modal evidence.

7. Title: Add lock cleanup safety allowlist
   Type: Medium
   Why: Terminating sessions can be risky when query text is broad.
   Where it would apply: Task 5.
   How it could improve the plan: It would reduce chance of terminating unrelated advisory-lock sessions.

8. Title: Add typed benchmark result JSON
   Type: Medium
   Why: Markdown reports are readable but hard to compare over time.
   Where it would apply: Task 8.
   How it could improve the plan: It would make future method comparisons scriptable.

9. Title: Add post-implementation cleanup task
   Type: Small
   Why: The plan creates operational scripts and plan-grader artifacts.
   Where it would apply: Final verification.
   How it could improve the plan: It would ensure temporary artifacts are intentionally kept or removed.

10. Title: Note current Twitter Scrapling absence in the header
   Type: Small
   Why: The user asked about X/Twitter and Scrapling specifically.
   Where it would apply: Scope Check.
   How it could improve the plan: It would prevent a worker from assuming Twitter has a Scrapling route today.
