# TRR Codebase Cleanup Inventory

Created: 2026-05-19

This inventory supports Workstream 1 from
`/.plan-work/plan-architect/trr-codebase-cleanup-20260519/REVISED_PLAN.md`.
It is a cleanup guardrail, not permission to move active source code.

## Ownership Classes

| Class | Current paths | Owner / status | Cleanup rule |
|---|---|---|---|
| Root orchestration | `Makefile`, `scripts/`, `profiles/`, `.codex/`, `docs/workspace/` | Active workspace contract surface | Do not rename or remove without workspace contract validation. Root startup, DB lane selection, browser smoke, and env projection depend on this layer. |
| Backend | `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `TRR-Backend/tests/`, `TRR-Backend/supabase/` | Active backend/API/data owner | Backend-first for schema, API, auth, scraper, repository, Modal, and shared contract changes. Keep SQL in repository or migration-owned surfaces. |
| Web app | `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`, `TRR-APP/apps/web/src/lib/`, `TRR-APP/apps/web/tests/` | Active Next.js app owner | Preserve public/admin URLs. Move route-heavy implementation behind feature modules only with app checks and browser smoke when visible behavior changes. |
| Generated artifacts | `TRR-APP/apps/web/src/lib/admin/api-references/generated/`, `TRR-APP/apps/web/src/lib/fonts/**/generated/`, backend repo maps, schema docs, advisor snapshots, `.logs/`, `.artifacts/`, `output/` | Generated or runtime evidence | Regenerate from source commands where available. Do not hand-edit generated output as a cleanup fix. Runtime evidence should stay ignored unless explicitly captured as a reviewed artifact. |
| Adjacent workspaces | `screenalytics/`, `BRAVOTV/`, `.external/`, `data/`, nested repo checkouts under `TRR-APP/` and `TRR-Backend/` | Out of scope for this slice | Leave untouched unless a follow-up explicitly includes them. Treat them as separate ownership domains, not clutter inside the TRR workspace. |
| High-risk contracts | route aliases, auth/session handling, Supabase migrations and DB lanes, Modal worker dispatch, Vercel/Next.js runtime, admin API references, env contract docs | Active behavior contracts | Rename or remove only with explicit redirects, focused tests, and browser/runtime validation. Cosmetic cleanup is not enough proof. |

## Active Roots

- Root workspace orchestration is active and owns commands such as `make dev`,
  `make dev-hybrid`, `make app-check`, `make codex-check`, and
  `make workspace-contract-check`.
- `TRR-Backend/` is the active backend repo for API routes, social scraper
  behavior, repository/data access, migrations, tests, and Modal-adjacent code.
- `TRR-APP/apps/web/` is the active web app. References to `apps/web` in root
  scripts are scoped to this nested path unless the literal top-level path is
  shown.
- `screenalytics/` and `BRAVOTV/` are adjacent workspaces and remain out of
  scope for cleanup unless specifically included.

## Top-Level `apps/web` Fragment

Result: safe to remove.

Evidence checked on 2026-05-19:

- `find apps -maxdepth 6 -type f` showed only:
  - `apps/web/src/lib/fonts/brand-fonts/glyph-comparison.ts`
  - ignored `.DS_Store` files under `apps/web/`
- `wc -c apps/web/src/lib/fonts/brand-fonts/glyph-comparison.ts` reported
  `0`, so the tracked file was empty.
- `git ls-tree -r --name-only HEAD apps/web` showed that this zero-byte file
  was the only tracked top-level `apps/web` file.
- The active implementation exists at
  `TRR-APP/apps/web/src/lib/fonts/brand-fonts/glyph-comparison.ts`.
- `rg "apps/web/src/lib/fonts/brand-fonts/glyph-comparison|from .*glyph-comparison|glyph-comparison" . -g '!node_modules' -g '!.git'`
  produced no matches before removal.
- Broader `rg "apps/web|glyph-comparison" . -g '!node_modules' -g '!.git'`
  found workspace references to `TRR-APP/apps/web` and root tooling, but no
  live import or path reference to the top-level empty fragment.

Cleanup action:

- Remove the tracked top-level `apps/web/src/lib/fonts/brand-fonts/glyph-comparison.ts`.
- Remove ignored `.DS_Store` files only inside the removed `apps/web` fragment.
- Leave unrelated ignored `.DS_Store` files, including `apps/.DS_Store` and
  `docs/workspace/.DS_Store`, untouched because they are outside this slice.

## Route-Alias Policy

These names are user-visible contract surfaces. Do not rename or delete them as
cleanup unless the follow-up explicitly includes redirects and browser smoke.

| Route / alias | Current live state | Cleanup policy |
|---|---|---|
| `screenalytics` | Active route exists at `TRR-APP/apps/web/src/app/screenalytics/page.tsx`; admin navigation points to `/screenalytics`. | Treat `/screenalytics` as the current canonical app/admin entry. Keep it stable. |
| `screenlaytics` | Legacy route folders exist and redirect to `/screenalytics`; proxy/admin navigation still recognizes the spelling for active-state matching. | Preserve as a compatibility alias until a dedicated route cleanup adds redirect coverage and browser verification. |
| `realations` | Active route exists at `TRR-APP/apps/web/src/app/realations/`; it is also reserved in `src/proxy.ts` and linked from menu/icon config. | Keep the exact spelling. Any rename needs redirects, menu updates, auth-flow checks, and browser smoke. |
| `uitripled` | Component source exists at `TRR-APP/apps/web/src/components/uitripled/comment-thread-shadcnui.tsx`, but no current route folder exists for this spelling. | Treat as component ownership, not a URL alias. Do not invent, rename, or delete a route for it during route cleanup. |

## Validation Guidance

- Docs-only inventory changes do not require browser verification.
- Removing the top-level stray fragment should be validated with:
  - `rg "apps/web/src/lib/fonts/brand-fonts/glyph-comparison|from .*glyph-comparison|glyph-comparison" . -g '!node_modules' -g '!.git'`
  - `git status --short -- apps docs/workspace/codebase-cleanup-inventory.md`
- Run broader workspace validation only if cleanup touches root scripts,
  runtime contracts, backend/app source, route behavior, migrations, or Modal
  surfaces.
