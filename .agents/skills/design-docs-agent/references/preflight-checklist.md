# Preflight Checklist

Run this checklist before reporting Design Docs success:

1. `contentBlocks` preserves source order.
2. `chartTypes` and renderer-ready data exist for every interactive artifact.
3. Typography specimens contain actual extracted styles, not assumptions.
4. `h2` and `h3` styles differ when the source differs.
5. Article colors are extracted from the current article, not copied.
6. Required sections such as typography and colors are populated when present in source.
7. The article `url` is present for the View Page action.
8. Brand tabs reflect the article through aggregation rather than hardcoded article logic.
9. Generated pages use the expected white page background contract.
10. Typecheck and pipeline verification commands pass or any remaining failures
    are explicitly reported.
11. If the article is `bespoke_interactive`, acquisition succeeded or the caller
    supplied a bundle rich enough for fidelity extraction.
12. `verify-source-fidelity` reports no blocking findings. Any degraded
    findings are explicitly disclosed.
13. Existing legacy articles only rely on `legacyFidelityMode` when they were
    not re-ingested in the current run.

### Data File Checks (when a standalone `*-data.ts` file is generated)

14. Read back the first entry in the data file and confirm it matches the
    expected rank-1 player/item from the source HTML.
15. Read back the last entry and confirm it matches the expected final
    player/item. A mismatch on either check indicates the wrong source was used.
16. The export constant name in the data file matches the import statement in
    `ArticleDetailPage.tsx` exactly (same identifier, same year suffix).

### Wide Component Checks (when `filter-card-tracker` or similar is present)

17. `ArticleDetailPage.tsx` outer container uses `maxWidth: "100%"` (not a
    fixed pixel value).
18. The component's internal container applies the appropriate max-width
    (e.g., 1150px) and centering.

### Interactive Component Visual Fidelity

19. Any SVG shape elements (`<polygon>`, `<polyline>`) in the generated
    component use the exact `points` coordinates extracted from the source HTML,
    not CSS approximations.
