# TRR-APP Map

Generated: 2026-06-23

Root: `/Users/thomashulihan/Projects/TRR/TRR-APP`

## Practical Shape

`TRR-APP` is a pnpm workspace whose main product app is `apps/web`, a Next.js 16 app. It owns public and admin UI, app-local API routes, admin route grammar, client/server auth boundaries, generated admin API references, app env projection, and app validation/build wrappers.

Workspace shape:

- `package.json` at `TRR-APP/` owns workspace-level scripts and Node 24 baseline.
- `pnpm-workspace.yaml` includes `apps/*` and excludes `apps/vue-wordle` from the main workspace package load.
- `apps/web/` is the primary Next.js app.
- `apps/vue-wordle/` is a sibling game app and has separate scripts.

## App Route Surface

Major `apps/web/src/app` route families:

- Public show routes: `/shows`, `/shows/[showId]`, root-scoped `/:showId`, seasons, settings, surveys, and social views.
- Public people routes: `/people` and `/people/[personId]`.
- Public social route: `/social/[platform]/[handle]`.
- Public brand routes: `/brands`, brand category routes, and `/brands/[brandSlug]`.
- Public game routes: `/bravodle`, `/flashback`, `/realitease`, and `/games`.
- Public docs/design-system/fonts routes.
- Auth routes: `/login`, `/auth/*`, `/profile`, and session API routes.
- Admin routes: `/admin`, `/admin/trr-shows`, `/admin/social`, `/admin/people`, `/admin/brands`, `/admin/networks-and-streaming`, `/admin/surveys`, `/admin/dev-dashboard`, `/admin/design-docs`, `/admin/games`, `/admin/screenalytics`, and many app-local admin API routes.

Route grammar ownership:

- `src/proxy.ts` owns host-isolation and rewrite behavior, but it is not the auth boundary.
- `src/lib/admin/admin-route-paths.ts` owns admin dashboard root paths.
- `src/lib/admin/admin-navigation.ts` owns visible admin navigation.
- `src/lib/admin/show-admin-routes.ts` owns deeper show, season, person, and social admin URL builders.
- `src/lib/admin/api-references/generated/inventory.ts` is the checked-in generated map of admin routes and backend endpoints.

Highest drift risk:

- `/shows/...`, root-scoped `/:showId/...`, and `/admin/trr-shows/...` overlap in concept but are owned by different route/helpers.
- New admin route work can drift if `proxy.ts`, route helpers, navigation, generated inventory, and tests are not updated together.

## Auth And API Wiring

Server auth boundary:

- `src/lib/server/auth.ts` owns provider selection, host allowlists, local bypass rules, Firebase/Supabase verification, `requireAdmin`, and `requireAdminContext`.
- `src/app/api/session/login/route.ts` and `logout/route.ts` own durable session cookie issuance/clearing.

Client auth helpers:

- `src/lib/admin/client-auth.ts` owns browser-side admin auth headers.
- `src/lib/admin/useAdminGuard.ts` gates admin pages.
- `src/lib/admin/client-access.ts` and `src/lib/admin/dev-admin-bypass.ts` expose client-facing allowlist/bypass behavior.

Backend proxy seam:

- `src/lib/server/trr-api/backend.ts` resolves backend API URLs.
- `src/lib/server/trr-api/internal-admin-auth.ts` owns short-lived internal admin auth.
- `src/lib/server/trr-api/admin-backend-proxy-route.ts` wraps admin backend proxy routes.
- `src/lib/server/trr-api/social-admin-proxy.ts` wraps social admin proxy behavior.
- `src/lib/server/sse-proxy.ts` and `timeout-safe-fetch.ts` support streaming and bounded upstream calls.

Practical rule:

- Host routing and proxy rewrites are routing behavior, not security. `requireAdmin` and backend internal-admin auth are the real gates.

## Data And Contract Boundaries

Server data access:

- `src/lib/server/postgres.ts` is the direct Postgres helper surface for app-side server reads/writes.
- `src/lib/server/admin/*-repository.ts`, `src/lib/server/surveys/*`, `src/lib/server/shows/*`, and `src/lib/server/trr-api/*-repository.ts` own server-side repository behavior.
- `@supabase/supabase-js` is intentionally reserved in server auth code for GoTrue/auth operations, not general app data access.

Generated contracts:

- `src/lib/admin/api-references/generated/inventory.ts` is checked in.
- `src/lib/admin/api-references/generator.ts` produces it.
- `tests/admin-api-references-generator.test.ts` asserts generated output matches the checked-in file.
- Font artifacts also have generated outputs under `src/lib/fonts/**/generated`.

## Env And Runtime Projection

App env setup:

- `apps/web/.env.example` is app setup only.
- Shared runtime env ownership lives in root `docs/workspace/env-contract.md`.
- `src/lib/firebase-client-config.ts` statically projects `NEXT_PUBLIC_FIREBASE_*` client config and fails fast when required client keys are missing.
- `src/lib/admin/admin-url-defaults.ts` centralizes admin origin, Portless, base-domain, host-prefix, and loopback fallback logic.
- `src/lib/server/auth.ts` owns server-side host allowlisting and auth provider behavior.

Important env split:

- Static client vars: `NEXT_PUBLIC_*`, especially Firebase client config.
- Server-only vars: Firebase service account, Supabase/admin keys, internal admin secret, Postgres URLs, backend URL.
- Workspace-projected vars: admin origins/hosts, Portless defaults, backend/app ports, DB lane controls, build/runtime tuning.

## Next.js Build And Config

`apps/web/next.config.ts` owns:

- React strict mode.
- `typedRoutes` opt-in with `NEXT_TYPED_ROUTES=true`.
- `distDir` override via `NEXT_DIST_DIR`.
- allowed dev origins for local/Portless admin routes.
- local build worker count tuning via `TRR_NEXT_BUILD_CPUS`.
- Firebase package aliasing to avoid duplicate internal package copies.
- dev on-demand entries warming.
- Turbopack root set to the repo root.
- image remote patterns and dev-only unoptimized images.
- route redirects and rewrites for show/social/admin canonicalization.

Build safety:

- `apps/web/scripts/safe-next-build.mjs` guards full local production builds by checking memory/swap and constraining CPU/heap/nice values.
- Full production build is not allowed in Codex without explicit current-chat approval.
- Lightweight validation should run first through root `make app-validate-quick`.

## Validation

App-local scripts:

- `pnpm -C TRR-APP/apps/web run validate:quick`
- `pnpm -C TRR-APP/apps/web run generated:check`
- `pnpm -C TRR-APP/apps/web run test`
- `pnpm -C TRR-APP/apps/web run typecheck`
- `pnpm -C TRR-APP/apps/web run smoke:admin-detail-routes`
- `pnpm -C TRR-APP/apps/web run test:e2e`

Root wrapper:

- `make app-validate-quick` is the approved lightweight app gate. It runs generated-contract checks plus focused validation tests.

Build status for this mapping run:

- `TRR-APP build: skipped, no current-chat approval`.

## Confusing Ownership Points

- `src/proxy.ts` can look security-sensitive but should be treated as routing only; server auth remains in `src/lib/server/auth.ts`.
- Route ownership is split across App Router files, proxy rewrites, admin route helpers, navigation, and generated inventory.
- Server auth, client access projection, and local dev bypass are separate surfaces.
- App `.env.example`, Firebase client config, and root workspace env contract can drift if edited independently.
- Generated admin API and font artifacts must stay aligned with their generator scripts.

## Evidence Files Read

- `TRR-APP/AGENTS.md`
- `TRR-APP/package.json`
- `TRR-APP/pnpm-workspace.yaml`
- `TRR-APP/Makefile`
- `TRR-APP/apps/web/package.json`
- `TRR-APP/apps/web/next.config.ts`
- `TRR-APP/apps/web/scripts/safe-next-build.mjs`
- `TRR-APP/apps/web/src/app/**`
- `TRR-APP/apps/web/src/lib/admin/**`
- `TRR-APP/apps/web/src/lib/server/**`
- `TRR-APP/apps/web/tests/**`
- live filesystem and Git status output
