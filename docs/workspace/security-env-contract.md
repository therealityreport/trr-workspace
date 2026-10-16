# Security-Critical Environment Contract (TRR-APP admin surface)

Hand-maintained companion to the generated `docs/workspace/env-contract.md`. These variables decide whether
admin auth in `TRR-APP/apps/web` fails **closed** (safe) or **open** (exposed). Source of truth:
paths are relative to the `TRR-APP` repo root: `apps/web/src/lib/server/auth.ts`,
`apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `apps/web/src/lib/server/session-origin.ts`,
`apps/web/src/app/api/session/*/route.ts`, and `apps/web/src/app/api/cron/*/route.ts`.
Firebase/session source contract verified: 2026-10-04 (Plan 055 AUTH-R1/R2). Other rows retain their 2026-06-10 verification date.

## Production requirements (Vercel `production` environment)

| Variable | Required prod state | Behavior if violated |
|---|---|---|
| `CRON_SECRET` | **Set** (strong random) | Cron routes (`/api/cron/episode-progression`, `/api/cron/create-survey-runs`) return **500 `Server misconfiguration`** in production when unset (fail-closed, enforced 2026-06-10). Wrong bearer → 401. |
| `TRR_DEV_ADMIN_BYPASS` | **Unset** | If truthy while `VERCEL_ENV=production`, `auth.ts` **throws at module load** — admin/API routes refuse to serve rather than honor the bypass. The bypass is additionally inert whenever `VERCEL_ENV=production`, regardless of host or `NODE_ENV`. |
| `NEXT_PUBLIC_DEV_ADMIN_BYPASS` | **Unset** | Client-side only: makes browsers *send* the bypass token. Harmless while the server gate is closed, but keep unset in prod builds to avoid noise/confusion. |
| `ADMIN_ENFORCE_HOST` | **Unset or `true`** | `false` disables the admin host allowlist in `requireAdmin`/`requireAdminContext`; identity allowlists remain, but host isolation is lost. |
| `ADMIN_APP_HOSTS` / `ADMIN_APP_ORIGIN` | Set to the canonical admin host(s) | Empty allowlist degrades the host gate to allow-any-host. |
| `FIREBASE_SERVICE_ACCOUNT` | **Set in production** | Firebase Admin `verifyIdToken(token, true)` / `verifySessionCookie(token, true)` are authoritative. Any rejection or verification availability failure denies authentication; there is no signature-less decode/Identity Toolkit fallback. Missing credentials may initialize minimal config for builds, but do not enable a weaker runtime verifier. Session login returns 503 when credentials are absent outside the emulator. |
| `TRR_INTERNAL_ADMIN_SHARED_SECRET` | **Set, ≥32 random bytes, rotated** | Holder can mint 120s full-admin JWTs (HS256). Host allowlist now applies to this path too (fixed 2026-06-10), but the secret remains the crown jewel: never log it, rotate on any suspicion. Unset disables internal-admin propagation entirely (safe). |
| `ADMIN_EMAIL_ALLOWLIST` / `ADMIN_UID_ALLOWLIST` | Set to owner emails/uids | These + Firebase custom claim `admin: true` are the only authorization legs. **Display names no longer authorize** (removed 2026-06-10; they were user-settable). Email leg also requires the Firebase `email_verified` claim. |

## Authorization model (after 2026-06-10 hardening)

`requireAdmin` grants access iff host allowlist passes AND one of:

1. `uid` ∈ `DEFAULT_ADMIN_UIDS` ∪ `ADMIN_UID_ALLOWLIST` ∪ `NEXT_PUBLIC_ADMIN_UIDS`
2. verified email ∈ `ADMIN_EMAIL_ALLOWLIST` ∪ `NEXT_PUBLIC_ADMIN_EMAILS` (requires `email_verified === true`)
3. Firebase custom claim `admin === true` (set server-side via `setCustomUserClaims`)
4. A valid propagated internal-admin JWT (HS256-only, host-allowlisted as of 2026-06-10)
5. Dev bypass — **only** when `VERCEL_ENV !== "production"`, on a local host, and (`NODE_ENV !== "production"` or `TRR_DEV_ADMIN_BYPASS=true`)

## Browser session cookie boundary

`POST /api/session/login` and `POST /api/session/logout` require a well-formed HTTP(S) `Origin` matching
the normalized `request.nextUrl.origin`. When Next's adapter exposes the internal Portless listener URL,
the external Origin must instead match an explicit, strictly parsed `ADMIN_APP_ORIGIN`, `PORTLESS_APP_URL`,
or `PORTLESS_ADMIN_URL`, and the actual `Host` authority must match that Origin's host and port. A supplied
Host must also match on the canonical URL path, preventing an app-host request from issuing an admin-host
session. Configuration with credentials, paths, queries, fragments, or malformed authorities is ignored;
it cannot authorize another origin. Absent, `null`, malformed, and foreign origins return 403
`invalid_origin`; `Sec-Fetch-Site: cross-site` also returns 403. Forwarded host/protocol headers do not
supply a trusted origin. Rejections occur before cookie issuance or mutation.

Login additionally requires `Content-Type: application/json` (parameters are allowed); other media types
return 415 `unsupported_media_type` before parsing the body or calling Firebase's session issuer. The
same-origin browser session-sync caller already sends JSON for login and a bodyless POST for logout;
logout does not require a JSON header. Existing cookie options, unsupported-provider 501, and missing
credentials 503 responses remain in effect after the request boundary passes.

## Operational checklist (run on each prod deploy review)

- [ ] Vercel prod env: `CRON_SECRET` present; `TRR_DEV_ADMIN_BYPASS` and `NEXT_PUBLIC_DEV_ADMIN_BYPASS` absent; `ADMIN_ENFORCE_HOST` not `false`; `FIREBASE_SERVICE_ACCOUNT` present; allowlists populated.
- [x] Rotated `TRR_INTERNAL_ADMIN_SHARED_SECRET` on 2026-10-16 across Vercel, Modal and Render; new credential accepted and old credential rejected. See [Plan 055 release receipt](plan-055-production-release.md). Recheck synchronization on later credential changes.
- [ ] Confirm `DEFAULT_ADMIN_UIDS` owner UID seeding and backend internal-admin secret sync before any production deploy that uses the rotated shared secret.
- [ ] Firebase console: decide/record whether email/password self-signup stays enabled; with displayName authorization removed, self-signup no longer grants admin, but it still creates accounts.
- [ ] Owner access: owner uid is seeded in `DEFAULT_ADMIN_UIDS` (`apps/web/src/lib/admin/constants.ts`); owner email must be **verified** in Firebase for the email leg to work.

## Historical regression references

These June 2026 test references are absent from the current checkout; they do not establish current
coverage. Plan 055 retains offline Firebase SDK/NextRequest probe evidence outside the repository;
provider and browser acceptance remain separate checks.

- `apps/web/tests/server-auth-adapter.test.ts` — displayName rejection, email-verified requirement, custom claim, uid leg, VERCEL_ENV bypass gate, boot assertion, requireAdminContext host check.
- `apps/web/tests/internal-admin-auth.test.ts` — HS256-only token acceptance.
- `apps/web/tests/cron-routes-auth.test.ts` — cron fail-closed (500 on missing secret, 401 on mismatch).
