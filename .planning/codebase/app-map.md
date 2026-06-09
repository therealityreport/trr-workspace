# TRR App / Frontend Map

Scope: `TRR-APP/apps/web` only. This is the Next.js frontend shell, its route tree, its client/server data boundary, and the local validation surface.

## Structure

- [`TRR-APP/apps/web/src/app/layout.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/layout.tsx) is the root shell. It loads hosted fonts, wraps the app in `TypographyRuntimeClient`, `SideMenuProvider`, `ErrorBoundary`, `ToastHost`, and `DebugPanel`, and sets the site metadata.
- [`TRR-APP/apps/web/src/app/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/page.tsx) is the public landing page. It is client-rendered and owns the primary sign-in CTA and top-level navigation into auth, hub, games, and shows.
- [`TRR-APP/apps/web/next.config.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/next.config.ts) is the routing compatibility layer. It defines canonical show/season/social rewrites plus legacy redirects, and it also pins Firebase package aliases for runtime stability.

## Route Map

- Public entrypoints live under `src/app/` and are mostly thin route pages: `/`, `/login`, `/auth/*`, `/hub`, `/profile`, `/settings`, `/shows`, `/social-media`, `/brands`, `/games`, `/docs`, `/surveys`, `/realitease`, `/bravodle`, `/flashback`, `/realations`, `/screenalytics`, `/screenlaytics`, `/privacy-policy`, `/terms-of-service`, `/terms-of-sale`, and `/users`.
- Show and season detail routes are split between root-scoped app routes and compatibility aliases. The key trees are `src/app/[showId]/...`, `src/app/shows/...`, `src/app/people/[personId]/[[...personTab]]/page.tsx`, `src/app/social/[platform]/[handle]/page.tsx`, and `src/app/admin/[showId]/...`.
- The canonical URL rules are in `next.config.ts`: old `/shows/:showId/...` paths redirect or rewrite into the root-scoped `/:showId/...` and `/:showId/s:seasonNumber/...` forms, while old social season variants are normalized into `/:showId/social/...`.
- Admin has its own route family under `src/app/admin/`, including the dashboard, per-show workspaces, brand workflows, cast screentime, design docs, fonts, games, surveys, Reddit, social, and the `admin/trr-shows/[showId]` workspace.

## Key Surfaces

- [`TRR-APP/apps/web/src/app/login/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/login/page.tsx) handles email/password login and Google sign-in, then sends the user into the session/profile flow.
- [`TRR-APP/apps/web/src/app/auth/complete/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/auth/complete/page.tsx) finishes OAuth sign-in, creates the server session cookie, checks Firestore profile completeness, and routes to `/hub` or `/auth/finish`.
- [`TRR-APP/apps/web/src/app/auth/finish/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/auth/finish/page.tsx) collects the profile record, fetches show options, validates the form, and writes the profile to Firestore directly.
- [`TRR-APP/apps/web/src/app/hub/layout.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/hub/layout.tsx) still contains the commented-out server guard, but the active gating is client-side.
- [`TRR-APP/apps/web/src/app/hub/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/hub/page.tsx) is the authenticated game hub and wraps its content in `ClientAuthGuard requireComplete={true}`.
- [`TRR-APP/apps/web/src/app/hub/surveys/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/hub/surveys/page.tsx) is the survey landing surface and owns the Survey X modal flow.
- [`TRR-APP/apps/web/src/app/admin/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/page.tsx) is the admin landing dashboard and entry point into the higher-frequency admin routes.
- [`TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx) is the main admin show workspace, and [`TRR-APP/apps/web/src/app/admin/users/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/users/page.tsx) is the current access-management placeholder.
- [`TRR-APP/apps/web/src/app/brands/shows-and-franchises/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/brands/shows-and-franchises/page.tsx) is a good example of a public-facing page that still uses admin-authenticated backend APIs for brand workflows.

## Data Flow

- [`TRR-APP/apps/web/src/lib/firebase.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/firebase.ts) owns the client Firebase singleton, auth listener helper, Google popup sign-in, logout, and session-cookie calls to `/api/session/login` and `/api/session/logout`.
- [`TRR-APP/apps/web/src/lib/db/users.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/db/users.ts) is the main Firestore user-profile helper. It reads and writes the `users` collection, and it is the shared profile source for auth, hub gating, and the profile page.
- [`TRR-APP/apps/web/src/lib/firebase-db.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/firebase-db.ts) is the Firestore availability boundary. If Firestore is missing or misconfigured, callers can fall back instead of crashing.
- [`TRR-APP/apps/web/src/hooks/useNormalizedSurvey.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/hooks/useNormalizedSurvey.ts) and [`TRR-APP/apps/web/src/lib/db/surveys.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/db/surveys.ts) drive survey fetch/submit flows.
- [`TRR-APP/apps/web/src/lib/admin/client-auth.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/client-auth.ts) is the admin request gate. It waits for Firebase auth readiness, adds `Authorization`, `x-trr-tab-session-id`, and `x-trr-flow-key`, and retries token acquisition when needed.
- [`TRR-APP/apps/web/src/lib/admin/client-access.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/client-access.ts) is the client-side allowlist for admin visibility. It is only an optimistic gate and is still checked against `/api/admin/auth/status`.
- [`TRR-APP/apps/web/src/lib/server/auth.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/auth.ts) is the server auth boundary. It is the single intentional server consumer of `@supabase/supabase-js` and handles token verification, diagnostics, and provider branching.
- [`TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/trr-api/backend.ts) is the bridge to `TRR_API_URL`. It appends `/api/v1` and is the pattern used by backend-proxy routes such as [`TRR-APP/apps/web/src/app/api/shows/list/route.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/shows/list/route.ts).

## Session And Auth Touchpoints

- [`TRR-APP/apps/web/src/app/api/session/login/route.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/session/login/route.ts) creates the `__session` cookie from a Firebase ID token.
- [`TRR-APP/apps/web/src/app/api/session/logout/route.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/session/logout/route.ts) clears the cookie.
- [`TRR-APP/apps/web/src/components/ClientAuthGuard.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/ClientAuthGuard.tsx) is the reusable client-side auth gate for protected content.
- [`TRR-APP/apps/web/src/components/GlobalHeader.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/GlobalHeader.tsx) listens to Firebase auth state, checks admin status, and exposes the profile/settings actions.
- [`TRR-APP/apps/web/src/components/SideMenuProvider.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/SideMenuProvider.tsx) owns the site nav drawer and the logout path.
- [`TRR-APP/apps/web/src/app/profile/page.tsx`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/profile/page.tsx) is an auth-backed user view that reads the current profile directly from Firebase and falls back if Firestore is unavailable.

## Component Organization

- `src/components/` contains the reusable shells and feature widgets.
- `src/components/admin/` is the largest bucket and holds admin workspaces, dashboards, modals, analytics panes, search, and route-specific UI.
- `src/components/survey/` holds the survey interaction primitives and renderers.
- `src/components/ui/` is the local primitive layer for button, dialog, table, dropdown, tooltip, and related controls.
- `src/components/typography/` owns the runtime typography client and data-attribute plumbing used across the public shell and auth flows.
- `src/lib/admin/` contains admin-specific helpers, route state, fetch wrappers, access checks, and route path builders.
- `src/lib/design-system/` contains design-system tokens, surface definitions, and Figma mapping helpers.
- `src/lib/server/` is server-only code for auth, backend proxying, and server repositories.
- `src/styles/` plus `src/app/globals.css` and `src/app/side-menu.css` provide global styling.

## Validation Commands

- `pnpm -C TRR-APP/apps/web run validate:quick`
- `pnpm -C TRR-APP/apps/web run typecheck`
- `pnpm -C TRR-APP/apps/web run lint`
- `pnpm -C TRR-APP/apps/web run test`
- `pnpm -C TRR-APP/apps/web run smoke:admin-detail-routes`
- `pnpm -C TRR-APP/apps/web run test:e2e`
- `pnpm run web:dev`
- `pnpm run web:emu`
- `pnpm run web:build` uses the safe build wrapper from `apps/web/scripts/safe-next-build.mjs`

## Boundary Notes

- The app/frontend boundary to `TRR-Backend` is mostly `/api/*` route handlers plus the `TRR_API_URL` helper. If that env var is missing, backend-proxy routes fail early instead of guessing a base URL.
- Client Firestore usage is concentrated in `src/lib/db/users.ts`, `src/lib/db/surveys.ts`, and the auth/profile pages. Any Firestore permission or emulator change affects login, profile completion, and profile display.
- Admin fetches depend on `fetchAdminWithAuth` headers and flow keys. Changing those headers will affect request routing, deduping, and session-aware backend behavior.
- `src/app/auth/finish/page.tsx` bypasses the helper layer with a direct Firestore write. That is the main place where profile completion can drift from the shared user-profile helpers.
- Route aliasing is split between the app router and `next.config.ts`. If a show or season route changes, both the page tree and the rewrite table need to stay in sync.
