# Plan 008: Parallelize independent social landing payload phases

> **Executor instructions**: Follow this plan step by step. If a live excerpt
> differs, stop and report instead of improvising.
>
> **Drift check**: `git -C TRR-APP diff --stat 83778e5c..HEAD -- apps/web/src/lib/server/admin/social-landing-repository.ts apps/web/tests/social-landing-repository.test.ts`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: TRR-APP `83778e5c`, 2026-07-07

## Why this matters

`getSocialLandingPayloadResult()` waits for independent work in sequence on one
of the hottest admin pages. The people-profile build feeds SocialBlade handle
maps, but the expensive SocialBlade query and social-progress query can be
started as soon as their required inputs exist. Shortening this waterfall should
reduce admin social landing latency without changing the response shape.

## Current state

- `apps/web/src/lib/server/admin/social-landing-repository.ts:2653` defines
  `getSocialLandingPayloadResult()`.
- Lines 2667-2708 already batch seven independent loads in `Promise.all`.
- Lines 2726-2734 await `buildPeopleProfiles(...)`.
- Lines 2735-2745 then await `buildCastSocialBladeShows(...)`.
- Lines 2753-2765 then await `safeLoadSocialProgressSummaries(...)`.

## Scope

**In scope**:
- `apps/web/src/lib/server/admin/social-landing-repository.ts`
- `apps/web/tests/social-landing-repository.test.ts`

**Out of scope**:
- Changing payload fields, cacheability semantics, or timeout defaults.
- Rewriting the repository or adding new caching.

## Steps

1. Keep the initial landing-summary and shared-source `Promise.all` intact.
2. After `buildPeopleProfiles(...)` resolves, start `buildCastSocialBladeShows(...)`
   and `safeLoadSocialProgressSummaries(...)` before awaiting either result.
3. Await both with one local `Promise.all`, preserving the existing wrappers:
   `withOptionalLandingTimeout("cast SocialBlade", ...)` and
   `withOptionalLandingTimeout("social progress", ...)`.
4. Add a regression test that instruments the two loaders and proves social
   progress is started before cast SocialBlade resolves.

## Commands

Run from `TRR-APP/`:

```bash
pnpm -C apps/web exec vitest run tests/social-landing-repository.test.ts
pnpm -C apps/web run typecheck
pnpm -C apps/web run lint
```

## Done criteria

- The response shape is unchanged.
- The social progress load no longer waits for cast SocialBlade to finish.
- Focused test, typecheck, and lint pass.
