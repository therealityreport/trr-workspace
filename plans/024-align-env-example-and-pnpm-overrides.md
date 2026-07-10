# Plan 024: Align backend env examples and app pnpm override documentation

> **Executor instructions**: This is documentation/config hygiene. Do not bump
> package versions without evidence that the override is stale and safe to
> remove.
>
> **Drift check**: `git diff --stat fb76b5b..HEAD -- TRR-Backend/.env.example TRR-Backend/README.md TRR-APP/pnpm-workspace.yaml TRR-APP/.nvmrc TRR-APP/package.json`

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx/deps
- **Planned at**: workspace `fb76b5b`, TRR-Backend `8ea7aa1a`, TRR-APP `83778e5c`, 2026-07-07

## Why this matters

Backend docs mention Supabase JWT override env vars that `.env.example` does not
list. The app pnpm workspace also carries overrides and minimum-release-age
exceptions without enough local rationale for future maintainers.

## Current state

- `TRR-Backend/README.md:55` mentions `SUPABASE_JWT_SECRET`.
- `TRR-Backend/README.md:56` mentions optional `SUPABASE_PROJECT_REF` and
  `SUPABASE_JWT_ISSUER`.
- `TRR-Backend/.env.example` includes `SUPABASE_JWT_SECRET` but not those two
  optional override variables near the Supabase block.
- `TRR-APP/.nvmrc` says `24`; `TRR-APP/pnpm-workspace.yaml:5` pins
  `nodeVersion: 24.14.0`; `TRR-APP/package.json` allows `node: 24.x`.
- `TRR-APP/pnpm-workspace.yaml:23` has overrides for `glob`, `json-ptr`,
  `jwks-rsa@4>jose`, and `node-domexception`, plus a long
  `minimumReleaseAgeExclude` list.

## Scope

**In scope**:
- `TRR-Backend/.env.example`
- `TRR-Backend/README.md`
- `TRR-APP/pnpm-workspace.yaml`
- `TRR-APP/.nvmrc` / `package.json` only if aligning Node docs is necessary

**Out of scope**:
- Broad dependency upgrades.
- Removing security overrides without proving why they are obsolete.

## Steps

1. Add the missing optional Supabase JWT override env vars to `.env.example`
   near `SUPABASE_JWT_SECRET`.
2. Add comments explaining when to use them.
3. For each pnpm override, add a short reason or remove it only if lockfile and
   package evidence prove it is dead.
4. Align Node version wording so `.nvmrc`, `nodeVersion`, and `engines` do not
   confuse contributors.

## Commands

Run from workspace root:

```bash
cd TRR-Backend && python scripts/check_env_example.py --file .env.example --required TRR_INTERNAL_ADMIN_SHARED_SECRET --allow-hyphen GEMINI-MODEL
cd ../TRR-APP && pnpm install --lockfile-only
git diff --check
```

## Done criteria

- `.env.example` includes the documented Supabase JWT override vars.
- pnpm overrides have clear rationale or are removed with evidence.
- Node version guidance is consistent enough for onboarding.
