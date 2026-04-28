# SUGGESTIONS: Optional Follow-Ups

These are not required for execution approval. They should not expand the core scope unless explicitly selected later.

1. Title: Add a profile coverage SQL view
   - Type: Small
   - Why: Operators may need to quickly see which profile fields are populated.
   - Where it would apply: Supabase migration or backend repository read helper.
   - How it could improve the plan: Makes completeness easier to inspect without ad hoc SQL.

2. Title: Add profile-link domain normalization
   - Type: Small
   - Why: External links can differ by protocol, trailing slash, or Instagram shim.
   - Where it would apply: `profile_normalizer.py` and profile external-link table.
   - How it could improve the plan: Enables cleaner searching and duplicate detection.

3. Title: Store relationship source-page ordinal
   - Type: Small
   - Why: Following-list rows are paginated and may need scrape replay/debugging.
   - Where it would apply: `social.instagram_profile_relationships`.
   - How it could improve the plan: Helps diagnose partial page fetches and ordering drift.

4. Title: Add profile identity merge report
   - Type: Medium
   - Why: Instagram usernames can change while profile ids remain stable.
   - Where it would apply: Backfill script and diagnostics report.
   - How it could improve the plan: Surfaces username/profile-id collisions before they corrupt search results.

5. Title: Add admin-only raw payload diff link
   - Type: Medium
   - Why: Operators may need to compare typed fields to raw data during rollout.
   - Where it would apply: TRR-APP profile detail modal.
   - How it could improve the plan: Speeds validation without making raw JSON the primary workflow.

6. Title: Add a sampled golden fixture directory
   - Type: Medium
   - Why: Fixtures are central to this plan and should be easy to review.
   - Where it would apply: `TRR-Backend/tests/fixtures/social/instagram/`.
   - How it could improve the plan: Keeps sample payload expectations visible and reusable.

7. Title: Add a relationship cap explanation field
   - Type: Small
   - Why: A cap value alone does not explain whether a scrape stopped by config, auth, or source exhaustion.
   - Where it would apply: scrape job/run metadata and profile relationship API response.
   - How it could improve the plan: Improves operator trust in following-list completeness status.

8. Title: Add profile field freshness timestamps
   - Type: Medium
   - Why: Counts, biography, and links can drift at different cadences.
   - Where it would apply: `social.instagram_profiles`.
   - How it could improve the plan: Allows future refresh policies without guessing from one `last_scraped_at`.

9. Title: Add a migration rollback note
   - Type: Small
   - Why: Additive migrations are low risk but still touch shared social tables.
   - Where it would apply: Phase 2 migration plan and PR description.
   - How it could improve the plan: Gives reviewers a clear rollback/disable story.

10. Title: Add an implementation PR checklist
    - Type: Small
    - Why: The plan spans schema, backend, app, and ops.
    - Where it would apply: Final implementation PR body or `docs/ai/local-status/`.
    - How it could improve the plan: Reduces review misses across independent workstreams.
