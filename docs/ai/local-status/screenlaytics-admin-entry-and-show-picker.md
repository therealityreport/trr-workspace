# Screenlaytics admin entry and show picker

Last updated: 2026-03-21

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-21
  current_phase: "complete"
  next_action: "Use the Screenalytics card from /admin, open /screenalytics, and verify the root-level /<show> workspace plus /design-system/admin-labels in the browser"
  detail: self
```

- `TRR-APP`
  - Added a new `Screenalytics` dashboard/admin-nav entry that points to `/screenlaytics`.
  - Added a new admin-only show picker page at `/screenlaytics` that searches TRR shows, opens the selected show in the admin workspace, and now includes a recent-shows rail for one-click return access.
  - Added a friendly spelling alias at `/screenalytics` that redirects to `/screenlaytics`.
  - Added `/admin/[showId]` and `/admin/[showId]/[...rest]` compatibility routes, but they now redirect outward to the root-level `/<show>` workspace path instead of exposing `/admin/trr-shows/...` in the browser URL.
  - Updated shared admin recent-show links to normalize on the root-level `/<show>` workspace path.
  - Repaired friendly show-slug resolution for the Screenalytics picker by teaching the server-side resolver to match the stored show `slug` field in addition to the name-derived slug and inline alternative names.
  - Clarified in the Screenalytics picker copy that this flow is owned by `TRR-APP`, not the retiring legacy `screenalytics` repo UI.
  - Moved the admin route audit out of Design Docs and into the design system at `/design-system/admin-labels`, with `/admin/design-docs/admin-ia` preserved only as a compatibility redirect.
  - Registered `Admin Labels & Routes` as a real design-system tab and updated the audit copy to reflect the root-level workspace direction, including `/<show>` as the ideal show workspace path and `/design-system/admin-labels` as the canonical audit location.
  - Normalized some shared admin labels and breadcrumbs toward the cleaner IA: `Surveys` instead of `Survey Editor`, `/surveys` in survey breadcrumbs, and `/brands` in brand breadcrumbs.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/lib/admin/admin-navigation.ts' 'src/app/screenlaytics/page.tsx' 'src/app/screenalytics/page.tsx' 'src/app/admin/[showId]/page.tsx' 'src/app/admin/[showId]/[...rest]/page.tsx'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/trr-shows-repository-resolve-slug.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/lib/server/trr-api/trr-shows-repository.ts' 'tests/trr-shows-repository-resolve-slug.test.ts'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/lib/admin/admin-navigation.ts' 'src/lib/admin/admin-breadcrumbs.ts' 'src/lib/admin/admin-route-audit.ts' 'src/lib/admin/design-docs-config.ts' 'src/components/admin/design-docs/DesignDocsPageClient.tsx' 'src/components/admin/design-docs/sections/AdminIASection.tsx' 'src/app/admin/surveys/page.tsx' 'src/app/screenlaytics/page.tsx' 'tests/admin-navigation.test.ts' 'tests/admin-breadcrumbs.test.ts' 'tests/admin-global-header.test.tsx'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/admin-navigation.test.ts tests/admin-breadcrumbs.test.ts tests/admin-global-header.test.tsx tests/trr-shows-repository-resolve-slug.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/lib/admin/design-system-routing.ts' 'src/lib/admin/admin-route-audit.ts' 'src/lib/admin/design-docs-config.ts' 'src/components/admin/design-docs/DesignDocsPageClient.tsx' 'src/components/admin/design-docs/sections/AdminIASection.tsx' 'src/components/admin/design-system/DesignSystemPageClient.tsx' 'src/components/admin/ScreenalyticsPickerPage.tsx' 'src/lib/admin/admin-recent-shows.ts' 'src/lib/admin/admin-navigation.ts' 'src/app/admin/[showId]/page.tsx' 'src/app/admin/[showId]/[...rest]/page.tsx' 'src/app/admin/design-docs/[section]/page.tsx' 'tests/admin-recent-shows.test.ts' 'tests/admin-navigation.test.ts' 'tests/admin-fonts-tabs.test.ts' 'tests/admin-route-aliases.test.ts'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/admin-recent-shows.test.ts tests/admin-navigation.test.ts tests/admin-fonts-tabs.test.ts tests/admin-route-aliases.test.ts tests/admin-breadcrumbs.test.ts tests/admin-global-header.test.tsx tests/admin-host-middleware.test.ts`
- Follow-up / known limits:
  - I did not wait for the full app-wide `tsc --noEmit` pass because this workspace’s broad Next/TypeScript run can sit in the long-running route-analysis phase without surfacing targeted feedback. The touched files passed targeted lint.
  - The audit now lives at `/design-system/admin-labels`, but the broader dashboard is still mid-migration. Some section entries remain on `/admin/...` routes, and the internal `/admin/trr-shows/...` tree still exists behind proxy rewrites even though browser-facing aliases now redirect outward to friendlier URLs.
