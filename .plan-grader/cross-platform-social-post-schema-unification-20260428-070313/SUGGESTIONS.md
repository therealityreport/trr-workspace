# SUGGESTIONS

These are optional improvements after the required revision. They are not blockers.

1. Title: Add platform-specific explain fixtures
   Type: Medium
   Why: Shared tables can regress query plans silently.
   Where it would apply: Backend DB scripts and repository tests.
   How it could improve the plan: Adds repeatable `EXPLAIN` snapshots for high-traffic profile and comment routes.

2. Title: Add a social post identity glossary
   Type: Small
   Why: `source_id`, `post_id`, `tweet_id`, `video_id`, and `reddit_post_id` are easy to confuse.
   Where it would apply: `docs/ai/local-status/` or workspace brain glossary.
   How it could improve the plan: Reduces implementation mistakes across platform adapters.

3. Title: Add a dry-run HTML report
   Type: Medium
   Why: JSON parity output is good for automation but harder for operator review.
   Where it would apply: Backfill/parity scripts.
   How it could improve the plan: Makes large all-platform parity reviews easier before approval.

4. Title: Track per-field provenance
   Type: Large
   Why: Metrics may come from different scrapers with different reliability.
   Where it would apply: Observation/provenance schema.
   How it could improve the plan: Supports deciding whether max observed, latest observed, or trusted source should win.

5. Title: Add a compatibility view layer
   Type: Medium
   Why: Legacy query consumers may be easier to migrate gradually through views.
   Where it would apply: Supabase migrations after read-path parity.
   How it could improve the plan: Lowers risk during legacy table retirement.

6. Title: Add per-platform canary handles
   Type: Small
   Why: `thetraitorsus` covers key paths but not every platform shape.
   Where it would apply: Validation docs and parity scripts.
   How it could improve the plan: Ensures every platform has a known small validation target.

7. Title: Add advisory-lock protection to backfills
   Type: Medium
   Why: Concurrent backfills can distort parity results.
   Where it would apply: Backfill scripts.
   How it could improve the plan: Prevents overlapping writes during all-platform migration.

8. Title: Add row-level checksum comparisons
   Type: Medium
   Why: Count parity can miss payload drift.
   Where it would apply: Parity script.
   How it could improve the plan: Compares normalized identity, timestamps, metrics, media counts, and entity counts per row.

9. Title: Add storage asset reconciliation
   Type: Large
   Why: Hosted media fields are spread across platform tables and mirror jobs.
   Where it would apply: Media asset phase.
   How it could improve the plan: Ensures the new media table does not orphan hosted assets or retry state.

10. Title: Add rollback runbook
    Type: Medium
    Why: This is a broad schema migration with dual-write.
    Where it would apply: Rollout phase docs.
    How it could improve the plan: Gives operators exact steps to disable shared reads and fall back to legacy tables.

