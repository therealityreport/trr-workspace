# Security-Critical Environment Contract (TRR-APP admin surface)

Hand-maintained companion to the generated `docs/workspace/env-contract.md`. These variables decide whether
admin auth in `TRR-APP/apps/web` fails **closed** (safe) or **open** (exposed). Source of truth:
`apps/web/src/lib/server/auth.ts`, `apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, and
`apps/web/src/app/api/cron/*/route.ts`. Last verified: 2026-06-10 (Phase 0 of the admin remediation roadmap).

## Production requirements (Vercel `production` environment)

| Variable | Required prod state | Behavior if violated |
|---|---|---|
| `CRON_SECRET` | **Set** (strong random) | Cron routes (`/api/cron/episode-progression`, `/api/cron/create-survey-runs`) return **500 `Server misconfiguration`** in production when unset (fail-closed, enforced 2026-06-10). Wrong bearer → 401. |
| `TRR_DEV_ADMIN_BYPASS` | **Unset** | If truthy while `VERCEL_ENV=production`, `auth.ts` **throws at module load** — admin/API routes refuse to serve rather than honor the bypass. The bypass is additionally inert whenever `VERCEL_ENV=production`, regardless of host or `NODE_ENV`. |
| `NEXT_PUBLIC_DEV_ADMIN_BYPASS` | **Unset** | Client-side only: makes browsers *send* the bypass token. Harmless while the server gate is closed, but keep unset in prod builds to avoid noise/confusion. |
| `ADMIN_ENFORCE_HOST` | **Unset or `true`** | `false` disables the admin host allowlist in `requireAdmin`/`requireAdminContext`; identity allowlists remain, but host isolation is lost. |
| `ADMIN_APP_HOSTS` / `ADMIN_APP_ORIGIN` | Set to the canonical admin host(s) | Empty allowlist degrades the host gate to allow-any-host. |
| `FIREBASE_SERVICE_ACCOUNT` | **Set** | Without it, token verification falls back to signature-less decode + Google Identity Toolkit lookup (weaker; see roadmap item F-10 to make this fail-closed). |
| `TRR_INTERNAL_ADMIN_SHARED_SECRET` | **Set, ≥32 random bytes, rotated** | Holder can mint 120s full-admin JWTs (HS256). Host allowlist now applies to this path too (fixed 2026-06-10), but the secret remains the crown jewel: never log it, rotate on any suspicion. Unset disables internal-admin propagation entirely (safe). |
| `ADMIN_EMAIL_ALLOWLIST` / `ADMIN_UID_ALLOWLIST` | Set to owner emails/uids | These + Firebase custom claim `admin: true` are the only authorization legs. **Display names no longer authorize** (removed 2026-06-10; they were user-settable). Email leg also requires the Firebase `email_verified` claim. |

## Authorization model (after 2026-06-10 hardening)

`requireAdmin` grants access iff host allowlist passes AND one of:

1. `uid` ∈ `DEFAULT_ADMIN_UIDS` ∪ `ADMIN_UID_ALLOWLIST` ∪ `NEXT_PUBLIC_ADMIN_UIDS`
2. verified email ∈ `ADMIN_EMAIL_ALLOWLIST` ∪ `NEXT_PUBLIC_ADMIN_EMAILS` (requires `email_verified === true`)
3. Firebase custom claim `admin === true` (set server-side via `setCustomUserClaims`)
4. A valid propagated internal-admin JWT (HS256-only, host-allowlisted as of 2026-06-10)
5. Dev bypass — **only** when `VERCEL_ENV !== "production"`, on a local host, and (`NODE_ENV !== "production"` or `TRR_DEV_ADMIN_BYPASS=true`)

## Operational checklist (run on each prod deploy review)

- [ ] Vercel prod env: `CRON_SECRET` present; `TRR_DEV_ADMIN_BYPASS` and `NEXT_PUBLIC_DEV_ADMIN_BYPASS` absent; `ADMIN_ENFORCE_HOST` not `false`; `FIREBASE_SERVICE_ACCOUNT` present; allowlists populated.
- [ ] Rotate `TRR_INTERNAL_ADMIN_SHARED_SECRET` (last rotation: pending — flagged in Phase 0, 2026-06-10) and update the matching TRR-Backend secret.
- [ ] Firebase console: decide/record whether email/password self-signup stays enabled; with displayName authorization removed, self-signup no longer grants admin, but it still creates accounts.
- [ ] Owner access: owner uid is seeded in `DEFAULT_ADMIN_UIDS` (`apps/web/src/lib/admin/constants.ts`); owner email must be **verified** in Firebase for the email leg to work.

## Regression tests guarding this contract

- `apps/web/tests/server-auth-adapter.test.ts` — displayName rejection, email-verified requirement, custom claim, uid leg, VERCEL_ENV bypass gate, boot assertion, requireAdminContext host check.
- `apps/web/tests/internal-admin-auth.test.ts` — HS256-only token acceptance.
- `apps/web/tests/cron-routes-auth.test.ts` — cron fail-closed (500 on missing secret, 401 on mismatch).
