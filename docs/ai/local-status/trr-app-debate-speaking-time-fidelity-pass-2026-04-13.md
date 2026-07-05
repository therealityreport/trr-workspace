# TRR-APP debate-speaking-time fidelity pass

Last updated: 2026-04-13

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-13
  current_phase: "design docs article fidelity repair"
  next_action: "Use this as the continuity note for any follow-up parity tweaks on the NYT debate article"
  detail: self
```

- Repaired the NYT `debate-speaking-time` design-doc article so the live page now surfaces the missing `Icons & SVGs` section, the featured/share `facebookJumbo` image inside `Images`, a dedicated `CSS Information` block, grouped typography summaries, and explicit color categories.
- Rebuilt the bespoke debate charts around source-derived layout constraints so the first chart no longer clips the left edge and the second chart no longer overlaps headings or truncates the right-side topic columns at desktop width.
- Added article-scoped metadata for `cssInfo`, `typographyGroups`, `colorCategories`, `featuredImage`, and chart accessibility label templates in `apps/web/src/lib/admin/design-docs-config.ts`, then updated `ArticleDetailPage.tsx` to render those richer sections.
- Strengthened article and chart tests for the debate page so the new headings, counts, sections, featured image, color groups, note styling, and accessibility labels are asserted directly.
- Browser verification:
  - A Playwright screenshot of `http://admin.localhost:3000/design-docs/nyt-articles/debate-speaking-time` after hydration showed the restored `Icons & SVGs` section, `Images` section with `facebookJumbo`, CSS summary metrics, and both charts fully visible without the previously reported clipping.
- Validation:
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run lint`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec next build --webpack`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run test:ci`
