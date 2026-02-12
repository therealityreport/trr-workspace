# Admin Product Suggestions: Shows, Seasons, Cast, Gallery, Social, Videos, News, and New Pages

Date: 2026-02-12  
Scope: TRR-APP admin UX + supporting TRR-Backend endpoints

## Implementation Status (Completed)
1. Completed: `Content Health` strip implemented and now grouped inside Health popup.
2. Completed: deterministic `Sync Pipeline` panel implemented with topic states and timestamps.
3. Completed: `Operations Inbox` implemented and moved into Health popup with deep-link actions.
4. Completed: `Refresh Log` grouped by category with compact “Done ✔️” completion rows.
5. Completed: season eligibility guardrails added (`Eligible` vs `Placeholder`) with explicit override.
6. Completed: episode coverage matrix added on season page for still/description/air date/runtime completeness.
7. Completed: season cast split includes `Archive Footage Credits` (excluded from actual episode counts).
8. Completed: gallery diagnostics panel added (missing variants, oversized, unclassified, source mix).
9. Completed: archive-only cast retrieval support added through season cast API query flag.
10. Completed: Health icon workflow added under `Sync by Bravo` to access all operational panels.

## Objective
Provide 10 concrete, high-impact suggestions to improve daily operator workflows across show, season/episode, cast, gallery, social, video, and news surfaces.

## 10 Suggestions

1. Unified "Content Health" strip on Show page
- Add one status row at top: `Show`, `Seasons`, `Episodes`, `Cast`, `Images`, `Videos`, `News`, each with `Ready / Missing / Stale`.
- Clicking a status jumps to relevant section/tab.
- Reduces guesswork before actions like `Sync by Bravo`.

2. Deterministic Sync Pipeline panel (Show page)
- Replace noisy logs with fixed pipeline steps:
  - `Show Info -> Seasons -> Episodes -> Cast -> Media -> Bravo`
- Each step has `queued/running/done/failed`, elapsed time, and actionable retry button.
- Keep details collapsible under each step.

3. Season Eligibility guardrails (Season/Episode page)
- Clearly label season as `Eligible` or `Placeholder` (e.g., missing premiere date or episode count).
- Prevent accidental media assignment to placeholder seasons.
- Add clear explanation with one-click override for admins.

4. Episode Coverage matrix (Season/Episode page)
- Add compact grid: episodes vs key assets (`still`, `description`, `air date`, `cast credits`).
- Surface gaps immediately and provide `Fix missing` quick actions.

5. Cast Evidence and Credit Types split (Cast pages)
- Separate `Actual Appearances` vs `Archive Footage` sections everywhere cast is shown.
- Show episode evidence count and source confidence tooltip.
- Keep total episode count visible under each member name.

6. Gallery Ingest Review queue (Gallery)
- After import, show `Needs Classification` queue for ambiguous images.
- Required fields before publish: `kind`, optional cast assignment, source metadata.
- Batch actions: set kind, set season, tag cast, move to other.

7. Smart Source and Size diagnostics (Gallery)
- Per image badge row: `Source`, `Mirrored`, `Bytes`, `Dimensions`, `Variant status`.
- One-click filter for `oversized`, `unmirrored`, `missing tags`, `slow-load risk`.
- Helps maintain quality and performance continuously.

8. Social command center by season (Social)
- Add season scoreboard:
  - post volume, engagement proxy, platform mix, stale accounts, missing handles.
- Include "what changed in last 7 days" panel to avoid manual diffing.

9. Video and News linkage quality tools (Videos/News tabs)
- Add a right-rail QA panel for each item:
  - linked cast tags, season mapping, source date, duplicate detection status.
- Add bulk actions: tag by caption/title, re-run person matching, assign season.

10. New page: "Operations Inbox"
- Central queue for all unresolved admin tasks:
  - failed sync steps, unclassified media, missing cast evidence, untagged news/videos, missing socials.
- Prioritize by impact and recency with direct deep links to fix screens.

## Prioritization (Recommended)
1. P1: Suggestions 1, 2, 5, 7, 10 (core operations stability + speed).
2. P2: Suggestions 3, 4, 6, 9 (quality and data integrity).
3. P3: Suggestion 8 (ongoing social analytics workflow enhancement).

## Suggested Implementation Slices
1. Slice A (Ops clarity): 1 + 2 + 10
2. Slice B (Cast/data quality): 5 + 9
3. Slice C (Media performance/quality): 6 + 7
4. Slice D (Season structure): 3 + 4
5. Slice E (Social analytics): 8

## Success Metrics
1. Time-to-complete full show setup (from refresh to publishable) reduced.
2. Fewer manual retries per show sync.
3. Reduced number of unclassified/untagged media items.
4. Lower median gallery payload size and improved perceived load time.
5. Fewer support/debug sessions for missing cast/news/video linkage.
