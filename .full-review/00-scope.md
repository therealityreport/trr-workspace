# Review Scope

## Target

The **entire TRR monorepo** (user-selected scope: "Entire monorepo"), reviewed via the **Workflow tool** (multi-agent background orchestration). Two live runtime repos plus the workspace orchestration layer:

- **TRR-Backend/** — Python 3.11 / FastAPI / Supabase(Postgres) / Modal / Render. 37 routers, 280 SQL migrations, domain layer under `trr_backend/`.
- **TRR-APP/** — pnpm workspace; Next.js 16 App Router + React 19 (`apps/web`), Firebase auth + Firestore rules, direct Postgres reads, Vercel deploy. 327 API route handlers, 72 server libs, secondary `apps/vue-wordle`.
- **Workspace tooling** — `scripts/`, `profiles/`, `Makefile`, `docs/`, `.codex/`, CI/CD (`.github/workflows` in both repos).

## Explicitly OUT of scope

- **`screenalytics/`** — retired/removed from the workspace (retirement plan dated 2026-05-28). Code migrated into TRR-Backend. Only *compatibility shims/labels* remain in the two live repos; agents treat live shims as in-scope but do not chase the deleted tree.
- Vendored/generated: `node_modules/`, `.venv/`, `.next/`, `__pycache__/`, caches, `data/`, `output/`, build artifacts.
- Giant generated files are **sampled, not read whole** (e.g. `TRR-APP/.../api-references/generated/inventory.ts` ~23.3k lines).

## Verified high-signal surfaces (work-list for agents)

**Security-critical**
- `TRR-Backend/api/auth.py`, `api/main.py`, `api/screenalytics_auth.py` — Supabase JWT verify, admin allowlist, internal-admin secret.
- `TRR-Backend/supabase/migrations/` (280 files) — RLS/grants. (`docs/workspace/supabase-rls-grants-review.md` has a +1,597-line working diff.)
- `TRR-APP/apps/web/src/lib/server/auth.ts`, `firebaseAdmin.ts`, `firestore.rules` — client/server authz.
- `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` + admin proxy routes — cross-repo JWT minting, potential backend-origin leakage / SSRF surface.

**Largest / highest-regression-radius modules (verified line counts)**
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` — 61,116
- `TRR-Backend/tests/repositories/test_social_season_analytics.py` — 46,023
- `TRR-Backend/api/routers/admin_person_images.py` — 17,207; `admin_show_links.py` — 8,269; `socials/__init__.py` — 7,878
- `TRR-APP/.../admin/api-references/generated/inventory.ts` — 23,299 (generated)
- `TRR-APP/.../admin/trr-shows/[showId]/page.tsx` — 16,907; `PersonPageClient.tsx` — 11,946; `reddit-sources-manager.tsx` — 10,150

**Known concerns to confirm/refute against live code (from generated maps — treated as untrusted leads)**
- Admin proxy error payloads leak `TRR_API_URL`/backend origin.
- Secret sprawl across `.env*` + `TRR-Backend/keys/`; startup auto-derives local shared secrets.
- Heavy work runs synchronously in request/worker processes when async infra absent.
- Cross-repo backend URL contract (`/api/v1` auto-append) is fragile and drift-prone.

## Flags

- Security Focus: no (default) · Performance Critical: no · Strict Mode: no · Framework: auto-detected (FastAPI / Next.js 16)

## Run mode

Workflow tool. The command's mid-run approval checkpoint (after Phase 2) is **not** used in this mode — the full multi-dimension review runs as one background workflow with adversarial verification, then results are consolidated into the phase files below.

## Review Phases (8 dimensions across the command's 5 phases)

1. Code Quality & Architecture
2. Security & Performance
3. Testing & Documentation
4. Best Practices & Standards (Framework/Language + CI/CD & DevOps)
5. Consolidated Report

Each dimension fans out across the relevant areas (backend API / backend domain+data / app BFF+routes / app frontend / workspace tooling / CI-CD). Critical & High findings are adversarially verified before inclusion. A completeness critic checks for missed surfaces.
