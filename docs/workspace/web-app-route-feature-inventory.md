# Web-App Route-To-Feature Inventory

Scope: `TRR-APP/apps/web/src/app`, `TRR-APP/apps/web/src/components`, `TRR-APP/apps/web/src/lib`, and `TRR-APP/apps/web/tests`.

This inventory is for the TRR cleanup plan slice. It is a map only: preserve all URLs, keep `src/app` as route ownership, and do not move route files until redirect coverage and browser smoke coverage exist.

Updated: 2026-05-21

Current status: keep this inventory as the next web cleanup map, but do not start
large web-app extraction until the active backend social route cleanup slice has
clean validation. Browser verification of the admin social page found backend
runtime/API issues that should be triaged before splitting social-week or admin
social web components.

Backend-gated web follow-ups:

- The admin social page at
  `http://admin.localhost:3000/southern-charm/s11/social` rendered the analytics
  section after the backend SQL fix.
- The season episodes proxy returned HTTP 500.
- The social week-detail endpoint can time out through the app proxy.
- Treat social-week web cleanup as blocked until those backend/runtime issues
  are fixed or explicitly split into their own bug backlog.

## Route Ownership Map

Route files should remain thin Adapters from URL params/search params into feature Modules. The cleanup target is to move Depth out of route files while keeping the public/admin route contract stable.

| Route family | Current route paths | Feature ownership | Cleanup work area | Notes |
| --- | --- | --- | --- | --- |
| Admin home and admin shell | `TRR-APP/apps/web/src/app/admin/page.tsx`, `TRR-APP/apps/web/src/components/admin/AdminGlobalHeader.tsx`, `TRR-APP/apps/web/src/components/admin/AdminSideMenu.tsx`, `TRR-APP/apps/web/src/lib/admin/admin-navigation.ts` | Operations/admin IA Module | Keep route shell in `src/app/admin`; keep navigation state in `src/lib/admin` | High Leverage because many admin workspaces depend on active-section and alias behavior. |
| Show workspace | `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/layout.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/[showSection]/page.tsx`, `TRR-APP/apps/web/src/app/[showId]/[[...rest]]/page.tsx`, `TRR-APP/apps/web/src/app/shows/[showId]/page.tsx` | Shows Module | Move page-owned state, mutation orchestration, and tab sections behind `src/lib/admin/show-page/*` and `src/components/admin/show-tabs/*` Interfaces | The main admin show page is about 17,211 lines and already imports `src/lib/admin/show-page/*`; preserve root URL aliases such as `/[showId]`. |
| Season workspace | `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/social/week/[weekIndex]/page.tsx`, `TRR-APP/apps/web/src/app/shows/[showId]/seasons/[seasonNumber]/page.tsx`, `TRR-APP/apps/web/src/app/[showId]/s[seasonNumber]/[[...rest]]/page.tsx` | Shows/seasons/social Module | Continue extracting season state to `src/lib/admin/season-page/*` and presentational pieces to `src/components/admin/season-tabs/*` | The season page is about 6,851 lines; `WeekDetailPageViewLoader` keeps social-week URLs thin already. |
| Person workspace | `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/[[...personTab]]/page.tsx`, `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/people/[personId]/[[...personTab]]/page.tsx`, `TRR-APP/apps/web/src/app/people/[personId]/[[...personTab]]/page.tsx` | People Module | Treat route pages as Adapters into `PersonPageClient`; deepen `src/lib/admin/person-page/*` and split UI into feature-owned components | Both admin person route files re-export the same client. `PersonPageClient.tsx` is about 12,836 lines and is a prime Depth target. |
| Social account profiles | `TRR-APP/apps/web/src/app/social/[platform]/[handle]/*/page.tsx`, `TRR-APP/apps/web/src/app/admin/social/[platform]/[handle]/*/page.tsx` | Social Module | Keep canonical profile UI behind `src/components/admin/SocialAccountProfilePage.tsx`; keep route resolution in `src/lib/admin/social-account-profile-route.ts` | Admin-prefixed social profile pages are legacy redirect Adapters. Preserve `/social/...` as canonical unless a later route policy slice changes it. |
| Social landing and Reddit sources | `TRR-APP/apps/web/src/app/admin/social/page.tsx`, `TRR-APP/apps/web/src/app/admin/social/reddit/*`, `TRR-APP/apps/web/src/app/admin/social-media/*` | Social/reddit Module | Separate landing data shaping, source management, shared account editing, and Reddit discovery into Modules | `admin/social/page.tsx` is about 2,324 lines; `reddit-sources-manager.tsx` is about 10,150 lines. Legacy `/admin/social-media` redirects to `/admin/social`. |
| Public social windows | `TRR-APP/apps/web/src/app/[showId]/social/*`, `TRR-APP/apps/web/src/app/[showId]/s[seasonNumber]/social/*`, `TRR-APP/apps/web/src/app/shows/[showId]/seasons/[seasonNumber]/social/week/*` | Social public/read Module | Share read-only social window rendering behind Interfaces; keep admin mutation controls out of public routes | Public route rewrite tests assert these routes do not collapse into admin pages. |
| Surveys | `TRR-APP/apps/web/src/app/surveys/*`, `TRR-APP/apps/web/src/app/admin/surveys/*`, `TRR-APP/apps/web/src/app/api/surveys/*`, `TRR-APP/apps/web/src/app/api/admin/surveys/*`, `TRR-APP/apps/web/src/app/api/admin/normalized-surveys/*` | Surveys Module | Keep public play/results routes separate from admin builders; use `src/lib/server/surveys/*` as server Interface | Existing tests cover normalized survey routes, play continuation, question mapping, and section grouping. |
| Brands, networks, and streaming | `TRR-APP/apps/web/src/app/brands/*`, `TRR-APP/apps/web/src/app/admin/brands/page.tsx`, `TRR-APP/apps/web/src/app/admin/networks*`, `TRR-APP/apps/web/src/app/api/admin/trr-api/brands/*`, `TRR-APP/apps/web/src/app/api/admin/networks-streaming/*` | Brands Module | Keep brand profile UI and server repositories separate from route handlers | `UnifiedBrandsWorkspace.tsx`, `brand-profile-repository.ts`, and `networks-streaming-repository.ts` are existing Module anchors. |
| Design docs and design system | `TRR-APP/apps/web/src/app/admin/design-docs/*`, `TRR-APP/apps/web/src/app/design-system/*`, `TRR-APP/apps/web/src/app/api/design-docs/*`, `TRR-APP/apps/web/src/app/api/admin/design-system/*` | Design-docs/design-system Module | Keep generated config and article components isolated; do not hand-edit generated API inventory | `src/components/admin/design-docs/*` has the largest component sub-tree; `src/lib/admin/api-references/generated/inventory.ts` is generated. |
| Games | `TRR-APP/apps/web/src/app/bravodle/*`, `TRR-APP/apps/web/src/app/realitease/*`, `TRR-APP/apps/web/src/app/flashback/*`, `TRR-APP/apps/web/src/app/admin/games/*`, `TRR-APP/apps/web/src/app/api/games/*`, `TRR-APP/apps/web/src/app/api/admin/flashback/*` | Games Module | Keep gameplay Modules in `src/lib/bravodle`, `src/lib/realitease`, and `src/lib/flashback`; keep admin problem reports separate | `flashback` public routes are currently disabled by workspace contract and redirect to `/hub`. |
| Media, images, fonts | `TRR-APP/apps/web/src/app/admin/scrape-images/page.tsx`, `TRR-APP/apps/web/src/app/fonts/[...assetPath]/route.ts`, `TRR-APP/apps/web/src/app/hosted-fonts.css/route.ts`, image/media API routes under `src/app/api/admin/trr-api/*` | Media/design assets Module | Keep gallery and image mutation Interfaces in server Modules; keep font-generated artifacts in generated folders | High-risk because image proxying, hosted media, and generated fonts affect visible admin assets. |
| Auth, profile, settings, users | `TRR-APP/apps/web/src/app/auth/*`, `TRR-APP/apps/web/src/app/login/page.tsx`, `TRR-APP/apps/web/src/app/profile/*`, `TRR-APP/apps/web/src/app/settings/page.tsx`, `TRR-APP/apps/web/src/app/users/page.tsx`, `TRR-APP/apps/web/src/app/api/session/*` | Auth/profile Module | Keep Firebase/session auth behind `src/lib/server/auth.ts` and client auth helpers | Auth is an Interface, not a feature-local concern. Do not mix auth checks into extracted UI Modules. |
| Misc root pages and aliases | `TRR-APP/apps/web/src/app/screenalytics/page.tsx`, `TRR-APP/apps/web/src/app/screenlaytics/page.tsx`, `TRR-APP/apps/web/src/app/realations/page.tsx`, `TRR-APP/apps/web/src/app/social-media/page.tsx`, `TRR-APP/apps/web/src/app/groups/page.tsx`, `TRR-APP/apps/web/src/app/docs/page.tsx` | Route contract / product alias Module | Document and test aliases before changing names | These are low Locality but high route-risk because some names are reserved by `src/proxy.ts`. |

## Feature Modules

These are the cleanup-ready work areas. A Module should own a meaningful behavior boundary and expose a small Interface to route files and client components. Avoid pass-through Modules with no Depth.

| Proposed Module | Current anchors | Intended Interface | Depth / Leverage / Locality |
| --- | --- | --- | --- |
| Shows workspace Module | `src/app/admin/trr-shows/[showId]/page.tsx`, `src/lib/admin/show-page/*`, `src/components/admin/show-tabs/*`, `src/lib/server/trr-api/trr-shows-repository.ts` | Route shell supplies route state; Module supplies tab controllers, mutation commands, gallery state, and presentational tab sections | High Depth, high Leverage, medium Locality. Biggest file and many tests already target show behavior. |
| Season workspace Module | `src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/page.tsx`, `src/lib/admin/season-page/*`, `src/components/admin/season-tabs/*`, `src/components/admin/season-social-analytics-section.tsx` | Season route state, cast/gallery/social controllers, and tab renderers | High Depth, high Leverage, medium Locality. Closely coupled to show workspace and social-week routes. |
| People workspace Module | `src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`, `src/lib/admin/person-page/*`, `src/components/admin/ImageScrapeDrawer.tsx`, `src/components/admin/social-growth-section.tsx` | Person profile load/controller Interface, refresh operation Interface, gallery/media view Interface | High Depth, high Leverage, medium Locality. Route pages already re-export a single implementation. |
| Social profile Module | `src/components/admin/SocialAccountProfilePage.tsx`, `src/lib/admin/social-account-profile.ts`, `src/lib/admin/social-account-profile-route.ts`, `src/app/social/[platform]/[handle]/*` | Canonical tab resolver, tab data fetchers, catalog command Interface, comments/socialblade adapters | High Depth, high Leverage, high Locality within social account pages. |
| Social-week Module | `src/components/admin/social-week/WeekDetailPageView.tsx`, `src/components/admin/social-week/WeekDetailPageViewLoader.tsx`, `src/lib/admin/social-sync-session.ts`, `src/lib/admin/shared-live-resource.ts` | Week detail loader and sync/session Interfaces | High Depth, medium Leverage, high Locality. Existing loader already gives a useful Seam. |
| Reddit sources Module | `src/components/admin/reddit-sources-manager.tsx`, `src/lib/server/admin/reddit-sources-repository.ts`, `src/lib/server/admin/reddit-discovery-service.ts`, `src/app/api/admin/reddit/*` | Community/source management Interface, discovery command Interface, flair assignment Interface | High Depth, medium Leverage, medium Locality because it touches social, Reddit, and route aliases. |
| Server admin proxy Module | `src/lib/server/trr-api/admin-backend-proxy-route.ts`, `src/lib/server/trr-api/admin-read-proxy.ts`, many `src/app/api/admin/trr-api/*/route.ts` files | Typed backend proxy Adapter for GET/mutation/SSE-style routes | Medium Depth, high Leverage, high Locality for API routes that only forward to backend. |
| Social backend proxy Module | `src/lib/server/trr-api/social-admin-proxy.ts`, `src/lib/server/trr-api/social-profile-route-factory.ts`, social routes under `src/app/api/admin/trr-api/social/*` | Typed social backend Adapter with timeout/error normalization | High Depth, high Leverage, high Locality for social scraper/admin surfaces. |
| Direct Postgres repositories Module | `src/lib/server/postgres.ts`, `src/lib/server/admin/*-repository.ts`, `src/lib/server/surveys/*`, `src/lib/server/trr-api/trr-shows-repository.ts` | Repository functions only; no route/UI code | High Depth, high Leverage, lower Locality because data access is shared. |
| Design-docs Module | `src/components/admin/design-docs/*`, `src/lib/admin/design-docs-*`, `src/app/admin/design-docs/*` | Generated article/page config and reusable section components | Medium Depth, medium Leverage, high Locality. Generated inventory remains read-only. |

## Server Access Interfaces

Normalize server access through a small number of Interfaces. Route handlers and client pages should call these Interfaces rather than open-coding fetch, auth, or SQL behavior.

| Interface | Current paths | Role | Cleanup rule |
| --- | --- | --- | --- |
| Backend admin proxy | `src/lib/server/trr-api/admin-backend-proxy-route.ts`, `src/lib/server/trr-api/admin-read-proxy.ts`, `src/lib/server/trr-api/backend.ts`, `src/lib/server/trr-api/internal-admin-auth.ts` | Adapter from Next route handlers to TRR-Backend admin routes | New API route cleanup should prefer this Interface when the route is primarily proxy behavior. |
| Social backend proxy | `src/lib/server/trr-api/social-admin-proxy.ts`, `src/lib/server/trr-api/social-profile-route-factory.ts` | Adapter from web admin routes to backend social/scraper endpoints | Keep timeout tiers, retry semantics, trace IDs, and saturation errors centralized here. |
| Direct Postgres | `src/lib/server/postgres.ts`, `src/lib/server/admin/*-repository.ts`, `src/lib/server/surveys/*`, `src/lib/server/trr-api/trr-shows-repository.ts` | Direct DB reads/writes for app-owned data | Route handlers should call repository functions; do not move SQL into pages or route handlers. |
| Firebase/session auth | `src/lib/server/auth.ts`, `src/lib/admin/client-auth.ts`, `src/lib/admin/useAdminGuard.ts`, `src/app/api/session/*` | Admin/session verification and client auth headers | Extracted Modules should receive auth state or use existing auth helpers; do not invent feature-local auth checks. |
| Browser/admin utilities | `src/proxy.ts`, `src/lib/admin/admin-route-paths.ts`, `src/lib/admin/show-admin-routes.ts`, `src/lib/admin/admin-route-audit.ts`, `src/lib/admin/admin-navigation.ts` | URL canonicalization, redirects, route audit, and navigation | Treat these as route-contract Interfaces. Update tests before changing aliases. |
| SSE/long-running operations | `src/lib/server/sse-proxy.ts`, `src/lib/admin/async-handles.ts`, `src/lib/admin/operation-session.ts`, `src/lib/admin/run-session.ts`, stream routes under `src/app/api/admin/trr-api/*/stream/route.ts` | Long-running operation Adapters and browser resume state | High-risk Interface because extraction can break progress, cancel, or resume semantics without visible compile errors. |

## Route Alias Policy

- Preserve all current URLs during cleanup. This includes typo-like, legacy, and internal implementation paths.
- Keep route files in `src/app` until a later slice has redirects, route tests, and browser smoke coverage.
- Treat canonicalization helpers as the route contract: `TRR-APP/apps/web/src/proxy.ts`, `TRR-APP/apps/web/src/lib/admin/show-admin-routes.ts`, `TRR-APP/apps/web/src/lib/admin/admin-route-paths.ts`, and `TRR-APP/apps/web/src/lib/admin/admin-route-audit.ts`.
- `screenalytics` is canonical at `/screenalytics`; `/screenlaytics`, `/admin/screenalytics`, and `/admin/screenlaytics` are compatibility aliases.
- `realations` is a reserved root route segment in `src/proxy.ts` and has a real page at `src/app/realations/page.tsx`; do not rename it as cleanup.
- `uitripled` exists as component source under `src/components/uitripled/comment-thread-shadcnui.tsx`; it is not a route today, so route cleanup should not invent a URL for it.
- `/admin/social-media/*` is a legacy alias family redirecting toward `/admin/social/*`.
- `/admin/[showId]` and nested `/admin/[showId]/[...rest]` are legacy show aliases forwarding into the root show workspace; tests already assert this.
- `/admin/trr-shows/*` and `/admin/trr-shows/people/*` are implementation paths used by the admin workspace. Do not classify them as browser-facing canonical routes without a separate product decision.

## High-Risk Surfaces

- `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`: very large client page with route state, local state, mutations, gallery behavior, refresh operations, social analytics, and tab rendering in one file.
- `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/page.tsx`: large client page with season identity, cast, gallery, Fandom, social analytics, and progress operations.
- `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`: large shared person implementation used by multiple route aliases.
- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`: large social profile component with stats, posts, catalog, comments, hashtags, socialblade, shared polling, and command orchestration.
- `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`: social-week detail component with media thumbnails, comment threads, live polling/SSE, sync sessions, cancel/retry controls, and route tab state.
- `TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx`: large Reddit source manager with discovery, episode discussions, flair assignments, backfill, and polling.
- `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`: large direct Postgres repository; high Leverage but low tolerance for accidental SQL, lane, or transaction changes.
- API route stream paths such as `src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts`, `src/app/api/admin/trr-api/shows/[showId]/refresh/stream/route.ts`, and `src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/sync-sessions/[syncSessionId]/stream/route.ts`: preserve streaming response behavior and cancel/resume handles.
- Generated or generated-like files: `src/lib/admin/api-references/generated/inventory.ts`, `src/lib/fonts/generated/*`. Do not hand-edit them during route cleanup.
- Route aliases and rewrites: `src/proxy.ts`, route re-export files, and redirect-only route files can look redundant but are route-contract Adapters.

## Safe First Slices

### Slice 1: Show Workspace Route Shell And Tab Module Extraction

Practical result: the show page becomes navigable without changing `/[showId]`, `/shows/[showId]`, or `/admin/trr-shows/[showId]`.

- Paths to touch in a later implementation slice:
  - `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
  - `TRR-APP/apps/web/src/lib/admin/show-page/*`
  - `TRR-APP/apps/web/src/components/admin/show-tabs/*`
  - focused tests under `TRR-APP/apps/web/tests/show-*.test.ts*` and `TRR-APP/apps/web/tests/trr-shows-*.test.ts*`
- Keep the route file as the Adapter that reads params/search params and mounts the show workspace.
- Extract only cohesive Depth first:
  - route state parsing and tab selection behind a show route-state Interface
  - gallery/media state and batch operation helpers behind a show media Interface
  - refresh/link/news/Bravo mutation orchestration behind command Interfaces
  - presentational tab sections that do not own fetch/mutation behavior
- Preserve existing `src/lib/admin/show-page/*` hooks and types. Prefer deepening those Modules over creating a parallel abstraction.
- Validation target after implementation: `make app-check`, then focused tests such as `show-route-canonicalization-wiring`, `show-tabs-nav`, `show-gallery-*`, `show-refresh-*`, and `show-social-*`. Browser smoke is required only when visible route/UI behavior changes.

Why first: highest Leverage and clear Locality around the largest route file. The file already imports many show-page helpers, so the Seam exists.

### Slice 2: Person Workspace Client Extraction

Practical result: all person URLs continue to land on the same workspace, while profile load, refresh operations, gallery state, and tab rendering become testable Modules.

- Paths to touch in a later implementation slice:
  - `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
  - `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/[[...personTab]]/page.tsx`
  - `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/people/[personId]/[[...personTab]]/page.tsx`
  - `TRR-APP/apps/web/src/lib/admin/person-page/*`
  - focused tests under `TRR-APP/apps/web/tests/person-*.test.ts*`, `TRR-APP/apps/web/tests/people-*.test.ts*`, and `TRR-APP/apps/web/tests/social-growth-*.test.ts*`
- Keep the two admin route pages as re-export/Adapter paths; do not delete either alias in this slice.
- Extract cohesive Depth first:
  - person profile load/read diagnostics behind a load Interface
  - refresh and Getty/Fandom operation orchestration behind command Interfaces
  - gallery filtering, thumbnail crop, and facebank state behind UI-state Modules
  - tab sections into presentational components that receive already-normalized state
- Preserve the existing `src/lib/admin/person-page/use-person-profile-*` and `use-person-settings-controller` helpers. They are the preferred Seam.
- Validation target after implementation: `make app-check`, then focused tests such as `people-page-tabs-runtime`, `person-route-parity`, `person-refresh-*`, `person-gallery-*`, and `social-growth-*`. Browser smoke is required if tab URLs, redirects, gallery interactions, or refresh controls visibly change.

Why second: high Depth with existing route Adapter behavior and good Locality around one shared client file. It also lowers risk before splitting social/profile components because person routes already depend on social growth and image workflows.

## Later Candidate Slices

- Social profile Module: split `SocialAccountProfilePage.tsx` by tab and command Interface. Start with catalog and comments because they already have route-level tests.
- Social-week Module: split `WeekDetailPageView.tsx` into loader, media grid, comments, sync controls, and live status Modules. Keep `WeekDetailPageViewLoader` as the route Adapter.
- Reddit sources Module: split `reddit-sources-manager.tsx` into community list, flair assignment, discovery, episode discussions, and backfill Modules. Pair with `reddit-discovery-service` and repository tests.
- Server API Adapter cleanup: convert thin proxy routes to `executeAdminBackendProxy` or `social-profile-route-factory` when behavior matches the existing Interface. Do not change backend paths.
- Generated/admin reference cleanup: document regeneration commands before any generated inventory changes.

## Validation Commands

This inventory slice is markdown-only, so no app test is required.

Read-only evidence commands used:

```bash
sed -n '1,220p' /Users/thomashulihan/Projects/TRR/.codex/rules/trr-project.md
sed -n '1,260p' /Users/thomashulihan/Projects/TRR/.plan-work/plan-architect/trr-codebase-cleanup-20260519/REVISED_PLAN.md
sed -n '1,240p' /Users/thomashulihan/Projects/TRR/.plan-work/plan-architect/trr-codebase-cleanup-20260519/HANDOFF.md
sed -n '1,220p' /Users/thomashulihan/Projects/TRR/docs/workspace/dev-commands.md
find TRR-APP/apps/web/src/app -type f \( -name 'page.tsx' -o -name 'layout.tsx' -o -name 'route.ts' -o -name 'route.tsx' -o -name 'loading.tsx' -o -name 'error.tsx' -o -name 'not-found.tsx' \) | sort
find TRR-APP/apps/web/src/app -type f \( -name 'page.tsx' -o -name 'route.ts' -o -name 'route.tsx' \) -print0 | xargs -0 wc -l | sort -nr | head -80
find TRR-APP/apps/web/src/components TRR-APP/apps/web/src/lib TRR-APP/apps/web/tests -type f \( -name '*.ts' -o -name '*.tsx' \) -print0 | xargs -0 wc -l | sort -nr | head -100
rg --files TRR-APP/apps/web/src/app | rg '/(page|route)\.(ts|tsx)$' | sed 's#^TRR-APP/apps/web/src/app/##' | awk -F/ '{print $1}' | sort | uniq -c | sort -nr
rg --files TRR-APP/apps/web/src/app/api/admin/trr-api | rg '/route\.ts$' | sed 's#^TRR-APP/apps/web/src/app/api/admin/trr-api/##' | awk -F/ '{print $1}' | sort | uniq -c | sort -nr
rg "screenalytics|screenlaytics|realations|uitripled" TRR-APP/apps/web/src TRR-APP/apps/web/tests -n
```

Future implementation validation should be selected by touched surface:

```bash
make app-check
pnpm -C TRR-APP/apps/web run test -- <focused test names>
make dev-hybrid
make browser-smoke-admin-details
```

Use browser validation only when visible route/UI/runtime behavior changes. For doc-only inventory work, no Modal update is needed because no Modal-deployed backend, worker, scraper, job, runtime, or Modal secret-preparation code changed.
