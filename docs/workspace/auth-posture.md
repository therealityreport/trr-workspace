# Auth Posture

Last reviewed: 2026-04-14

## Current state (pre-public)

TRR is not yet public. The backend DB layer accepts an `isAdmin` boolean passed
into `withAuthTransaction` / `queryWithAuth` (`TRR-APP/apps/web/src/lib/server/postgres.ts`)
and forwards it into the Postgres session variable `app.is_admin`, which RLS
policies read.

The boolean is trusted from server-side allowlist/claims checks
(`ADMIN_EMAIL_ALLOWLIST`, `ADMIN_DISPLAYNAME_ALLOWLIST`, Firebase custom claims).
It is a **convention**, not a mechanical guarantee — a caller could pass
`isAdmin: true` from client-derived state, and no code would stop it.

This is acceptable pre-launch because:
- There are no untrusted users yet.
- Admin surfaces are locked behind `TRR_INTERNAL_ADMIN_SHARED_SECRET` and host
  allowlists (see `TRR-APP/apps/web/src/lib/server/auth.ts`).
- The attack surface is internal tooling only.

## Pre-launch TODO (before public release)

Derive `isAdmin` **inside** `withAuthTransaction` by querying an admins table
against `firebaseUid`, rather than accepting it as a caller-provided parameter.
Remove the `isAdmin` field from `AuthContext`. This converts the load-bearing
convention into a mechanical guarantee.

Tracking: this file. When the work lands, delete this section and update the
"Current state" section to describe the new posture.

## Why documented here

An audit found this as a load-bearing convention. Capturing the deferral in
a doc prevents the decision from becoming silent folklore — without this file,
the same finding would likely surface again in six months with no record of
the pre-public rationale.
