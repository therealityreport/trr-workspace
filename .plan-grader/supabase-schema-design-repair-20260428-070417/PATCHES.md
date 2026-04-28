# Patches - Supabase Schema Design Repair Plan

No source plan file was overwritten. The concrete patch is a full replacement plan in `REVISED_PLAN.md`.

## Patch Map

| Original gap | Revised plan section |
|---|---|
| Missing delegated Instagram plan | `Phase 1 - Add Canonical Instagram Schema` now contains the schema tasks directly. |
| Case-sensitive membership key risk | `Phase 1` requires display and normalized account handles, with uniqueness on normalized keys. |
| Metric conflict policy left open | `Phase 2` defines canonical metric merge rules and observation recording. |
| Supabase migration safety too implicit | `Phase 1` and `Phase 7` add verifier SQL, rollback artifacts, migration lint, RLS/grants snapshot, and DDL gates. |
| Legacy fallback not measurable | `Phase 4` and `Phase 5` add a named compatibility flag, fallback telemetry, and retirement stop rules. |
| Platform-wide cleanup could sprawl | `Phase 6` keeps cross-platform work review-only until Instagram proves the model. |
| Accepted suggestions needed integration | `ADDITIONAL SUGGESTIONS` now contains one detailed task per numbered suggestion from `SUGGESTIONS.md`. |

## Representative Replacement Blocks

Replace:

```md
Implement the additive migration from `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-schema-unification-plan.md`.
```

With:

```md
Create a backend-owned migration that adds `social.instagram_account_post_catalog`,
`social.instagram_post_entities`, `social.instagram_post_media_assets`, and
`social.instagram_post_observations`. Do not depend on a separate missing plan
artifact for table definitions or verifier requirements.
```

Replace:

```md
Add `social.instagram_account_post_catalog` with `(account_handle, post_id)` as the membership key.
```

With:

```md
Store both `account_handle_display` and `account_handle_normalized`. Use
`account_handle_normalized` in uniqueness, indexes, and query filters so `@Foo`,
`foo`, and `FOO` cannot create separate memberships.
```

## Accepted Suggestion Patch Map

| Suggestion | Revised plan location |
|---|---|
| 1. Add source-runtime provenance table | `ADDITIONAL SUGGESTIONS` / `Suggestion 1` |
| 2. Add query-plan snapshots for before and after | `ADDITIONAL SUGGESTIONS` / `Suggestion 2` |
| 3. Add fallback counter to admin health endpoint | `ADDITIONAL SUGGESTIONS` / `Suggestion 3` |
| 4. Create a temporary compatibility view | `ADDITIONAL SUGGESTIONS` / `Suggestion 4` |
| 5. Add ownership comments on new tables | `ADDITIONAL SUGGESTIONS` / `Suggestion 5` |
| 6. Add generated normalized columns if Postgres expression rules fit | `ADDITIONAL SUGGESTIONS` / `Suggestion 6` |
| 7. Add retention policy for raw observations | `ADDITIONAL SUGGESTIONS` / `Suggestion 7` |
| 8. Build a cross-platform schema inventory report | `ADDITIONAL SUGGESTIONS` / `Suggestion 8` |
| 9. Add RLS policy regression SQL fixtures | `ADDITIONAL SUGGESTIONS` / `Suggestion 9` |
| 10. Add app fixture snapshots for response-envelope parity | `ADDITIONAL SUGGESTIONS` / `Suggestion 10` |
