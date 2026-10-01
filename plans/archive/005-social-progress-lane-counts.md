# Plan 005: Fix misleading comments/media progress lanes on the admin social landing page

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report — do
> not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: from `TRR-APP/`, run
> `git diff --stat 83778e5c..HEAD -- apps/web/src/lib/server/admin/social-landing-repository.ts`
> If it changed, compare the "Current state" excerpts against live code before
> proceeding; on a mismatch treat it as a STOP condition. If SHA `83778e5c` does
> not resolve, compare excerpts by hand and note it.

## Status

- **Priority**: P2
- **Effort**: S (media lane) + investigate (comments lane)
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `83778e5c` (TRR-APP), 2026-07-06

## Why this matters

On the admin social landing page, the per-account progress row builds a "Media"
and a "Comments" lane. Both are constructed by passing the **same value** as the
lane's saved *and* scraped count, so:

- **Media** lane: `scraped_percent` always equals `saved_percent` — the second
  progress bar is a redundant duplicate of the first, even though a real
  "source media discovered" total exists and should drive it.
- **Comments** lane (direct-SQL fallback path): `comments_saved_count` is
  hardcoded to `0`, so both bars read 0% regardless of how many comments the
  source reported — an operator sees "no comment progress" when comments may well
  have been captured.

These lanes exist to tell an operator "how much of this account have we scraped
and persisted." Right now they lie in the fallback path. The Media fix is
unambiguous and safe. The Comments fix requires deciding what "saved" means in
the fallback query — that part is scoped as investigate-then-fix with an explicit
STOP if the semantics aren't derivable cheaply.

## Current state

- `apps/web/src/lib/server/admin/social-landing-repository.ts:651-676` — `buildLane`
  signature and math (read it): `totalCount = Math.max(explicitTotalCount, savedCount, scrapedCount)`;
  `saved_percent = normalizeProgressPercent(savedCount, totalCount)`;
  `scraped_percent = normalizeProgressPercent(scrapedCount, totalCount)`.
  So passing the same number as saved and scraped forces the two percentages
  equal.

- `apps/web/src/lib/server/admin/social-landing-repository.ts:718-720` — the
  offending calls:

  ```ts
  buildLane("posts", "Posts", row.saved_count, row.scraped_count),
  buildLane("comments", "Comments", row.comments_saved_count, row.comments_saved_count, row.comments_total_count),
  buildLane("media", "Media", row.media_saved_count, row.media_saved_count, row.media_total_count),
  ```

  Note "Posts" correctly passes distinct `saved_count` / `scraped_count`.
  "Comments" and "Media" pass the saved value twice.

- The direct-SQL fallback query that produces the row
  (`social-landing-repository.ts:1070-1140`). Real count sources:
  - materialized CTE (~line 1075-1077): `count(*) AS saved_count`,
    `sum(rows.reported_comments) AS comments_total_count`,
    `sum(rows.hosted_media_files) AS media_saved_count`.
  - catalog CTE (~line 1089-1091): `count(*) AS scraped_count`,
    `sum(rows.reported_comments) AS comments_total_count`,
    `sum(rows.source_media_files) AS media_total_count`.
  - final SELECT (~line 1136): `0::int AS comments_saved_count` (hardcoded).
  - final SELECT (~line 1142): `media_total_count` is
    `greatest(catalog source_media_files, materialized hosted_media_files)::int`
    — so on the fallback path `media_total_count >= media_saved_count` always
    holds. This is what makes Step 2's media fix provably safe (the "scraped"
    arg can't be less than "saved"), and `buildLane`'s `Math.max` guards the
    edge even if the primary rollup ever supplied an inverted value.

  So `media_saved_count` = hosted media files (persisted), `media_total_count` =
  source media files (discovered), and there is **no** saved-comments column —
  only `comments_total_count` (source-reported).

- The `SocialProgressRow` type (~lines 149-159) already declares
  `comments_saved_count?`, `comments_total_count?`, `media_saved_count?`,
  `media_total_count?`.

- There is also a **primary path** (backend rollup) that supplies these counts
  when `adminContext` is available; this SQL is the fallback used when the rollup
  is unavailable. Confirm during Step 1 which path is which and whether the
  primary path already supplies a real `comments_saved_count` (it may, meaning
  only the fallback is wrong).

- **Convention**: server repositories under `apps/web/src/lib/server/admin/`,
  tested in `apps/web/tests/` with vitest. The relevant existing test is
  `apps/web/tests/social-landing-repository.test.ts` — model new assertions on
  it.

## Commands you will need

Run from `TRR-APP/`.

| Purpose | Command | Expected on success |
|---|---|---|
| Typecheck | `pnpm -C apps/web run typecheck` | exit 0 |
| Repository tests | `pnpm -C apps/web exec vitest run tests/social-landing-repository.test.ts` | all pass incl. new |
| Lint | `pnpm -C apps/web run lint` | exit 0 |

## Scope

**In scope**:
- `apps/web/src/lib/server/admin/social-landing-repository.ts` (the `buildLane`
  calls at lines 718-720, and — only if Step 2 concludes it is safe/cheap — the
  fallback SQL's `comments_saved_count`)
- `apps/web/tests/social-landing-repository.test.ts` (add lane-count assertions)

**Out of scope**:
- The backend rollup endpoint (Python) — if the *primary* path is also wrong,
  record it in your report as a backend follow-up; do not edit backend code from
  this app-side plan.
- Any UI component rendering the lanes — the fix is in the data builder.
- Adding new database indexes or expensive CTEs beyond the bounded option in
  Step 2.

## Git workflow

- Branch: `advisor/005-social-progress-lane-counts`
- Conventional-commit messages (e.g. `fix(admin): correct media/comments progress lane counts`).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Confirm the two paths and the intended lane semantics

Read `buildLane` (651-676), the fallback SQL (1070-1140), and how the primary
(rollup) path fills the same `SocialProgressRow`. Establish:
- For **media**: "saved" = hosted/persisted media (`media_saved_count`),
  "scraped/discovered" = source media found (`media_total_count`). Confirm this
  reading against how "Posts" uses saved (materialized) vs scraped (catalog).
- For **comments**: whether any real saved-comments count exists anywhere in this
  file's queries or the primary rollup.

**Verify**: write one sentence in your report stating, with `file:line`, what
"saved" and "scraped" mean for each lane. If you cannot determine the media
semantics with confidence from the code, STOP and report.

### Step 2: Fix the Media lane (safe, unambiguous)

Change the media call so "scraped" reflects discovered source media rather than
duplicating saved:

```ts
buildLane("media", "Media", row.media_saved_count, row.media_total_count, row.media_total_count),
```

(`saved` = hosted persisted, `scraped` = source discovered, `total` = source
discovered.) This makes `scraped_percent` reflect discovery and `saved_percent`
reflect persistence, matching the Posts lane's saved-vs-scraped meaning.

**Verify**: `pnpm -C apps/web run typecheck` → exit 0.

### Step 3: Make the Comments lane honest

**The `buildLane` edit is the same regardless of what Step 1 found** — change
line 719 to:

```ts
buildLane("comments", "Comments", row.comments_saved_count, row.comments_total_count, row.comments_total_count),
```

(saved stays `comments_saved_count`; scraped becomes `comments_total_count` so
the "discovered" bar reflects reported comments instead of a false 0%.) The
**only** decision is whether to also touch the SQL:

- **Default (take this unless Step 1 gave you positive proof otherwise):** leave
  the SQL `0::int AS comments_saved_count` (line 1136) in place and add a code
  comment noting the fallback path has no persisted-comment count, so the saved
  bar is authoritative only via the primary rollup. You **cannot** confirm the
  backend rollup's payload shape from this repo (it's a Python HTTP endpoint out
  of scope — the only in-repo signal is a test mock), so default here. Record in
  your report that a true saved-comments count needs a backend rollup change.
- **Only if** you have positive, in-repo proof of a cheap saved-comments source
  (a bounded aggregate already in these CTEs — NOT a new comments-table scan):
  replace the `0::int` with it. Do not add any unbounded CTE; the query runs
  under a 1200ms statement timeout (`SOCIAL_LANDING_PROGRESS_STATEMENT_TIMEOUT_MS`).

Note this `buildLane` edit affects **both** the primary (rollup) and fallback
paths — `buildProgressLanes` runs for both. That is fine and more correct: on
the primary path where `comments_saved_count` is real, saved still renders from
it; only the previously-duplicated scraped bar changes to reflect the total.

**Verify**: `pnpm -C apps/web run typecheck` → exit 0.

### Step 4: Tests

In `apps/web/tests/social-landing-repository.test.ts`, add assertions. Note the
existing lane tests use `expect.objectContaining({ key: "media", saved_count: N })`
with exact values — that shape **cannot** express an inequality, so for the
percent comparisons you must extract the lane object and compare numerically
(find the lane by `key` in the returned `lanes` array, then assert on its
`saved_percent` / `scraped_percent`). The existing rollup fixture (~test lines
794-797) already has `media_saved_count: 4 < media_total_count: 6` and
`comments_total_count: 120 > 0`, so it directly supports both new assertions.

- Media: with `media_saved_count < media_total_count`, extract the `"media"`
  lane and assert `saved_percent < scraped_percent` (they were forced equal
  before).
- Comments: with `comments_total_count > 0`, extract the `"comments"` lane and
  assert `scraped_percent > 0` (was a false 0% before).
- Posts lane behavior unchanged (regression guard — an `objectContaining`
  exact-value assertion is fine here).

**Verify**: `pnpm -C apps/web exec vitest run tests/social-landing-repository.test.ts` → all pass incl. new.

## Test plan

- New assertions in `apps/web/tests/social-landing-repository.test.ts`: media
  saved≠scraped when hosted<source; comments scraped>0 when reported>0; posts
  unchanged.
- Structural pattern: existing cases in the same file.
- Verification: Step 4 command passes.

## Done criteria

ALL must hold:

- [ ] Media `buildLane` call no longer passes `media_saved_count` as both args
- [ ] Comments `buildLane` call no longer passes `comments_saved_count` as both
      args (and the SQL hardcoded `0::int AS comments_saved_count` is either
      replaced with a real cheap source or explicitly documented as
      fallback-only)
- [ ] `pnpm -C apps/web run typecheck` → exit 0
- [ ] `pnpm -C apps/web exec vitest run tests/social-landing-repository.test.ts` → all pass incl. new
- [ ] `pnpm -C apps/web run lint` → exit 0
- [ ] `git status` shows only the two in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The `buildLane` math or the three `buildLane` calls (lines 718-720) differ
  structurally from the "Current state" excerpts (drift). **Cosmetic SQL
  differences do not count as drift** — the excerpts elide the live `rows.`
  table-qualifier and `::int` casts (e.g. live code is
  `sum(rows.hosted_media_files)::int AS media_saved_count`); only a changed
  column name, alias, or aggregate is real drift.
- You cannot determine the media saved-vs-scraped semantics from the code
  (Step 1) — do not guess which count means what.
- The only way to get a real saved-comments count is an unbounded/full-scan
  query — stop and record it as a backend rollup follow-up rather than adding it.

## Maintenance notes

- Follow-up (backend): if the primary rollup lacks a true persisted-comments
  count, add one there so the comments lane is accurate on the primary path, not
  just less-wrong on the fallback.
- A reviewer should confirm the media lane now distinguishes "discovered" from
  "hosted", and that no expensive CTE was added to the timeout-bounded query.
