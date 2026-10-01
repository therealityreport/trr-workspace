# Plan 027: Use the comment-rollup table for Instagram season week/coverage counts

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row in `plans/README.md` unless a reviewer told
> you they maintain the index.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/social_season_analytics_impl.py`
> The nested `TRR-Backend` tree is authoritative and dirty. This file is 68k+
> lines; never read it whole — use the `grep` commands below. Confirm the
> "Current state" excerpts before editing. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

The admin season analytics "week detail" and "coverage" views are the busiest
polled surfaces (week caches refresh ~90s, coverage ~20s, per
season×scope×platform×sort during an active week). For comment counts they run
`select count(*) ... from social.instagram_comments where post_id = any(...) group by post_id`
— scanning the entire comment slice for every post in the week (e.g. 50 posts ×
~2K comments ≈ 100K rows scanned+grouped) on every poll. A trigger-maintained
rollup table, `social.instagram_post_comment_rollups`, already stores the exact
per-post counts keyed by `post_id` (a ≤N-row keyed lookup). The account-profile
read path already reads from it; the season week/coverage builders never do.
Switching them cuts the hot-path cost from a full comment-table scan to a primary
-key lookup, against the constrained Supabase pooler.

This plan scopes the change to **Instagram** (the dominant platform) at the
week-detail and coverage sites. TikTok/YouTube rollups exist too and are a
documented follow-up using the same helper.

## Current state

- `trr_backend/socials/social_season_analytics_impl.py` — the god module.
  The Instagram week-detail builder computes counts like this (around line 55790):

  ```python
  comment_counts_by_post: dict[Any, int] = defaultdict(int)
  instagram_comment_active_filter = (
      "and coalesce(c.is_missing, false) = false" if _comment_lifecycle_supported("instagram_comments") else ""
  )
  if post_ids:
      count_rows = pg.fetch_all(
          f"""
          select c.post_id, count(*)::int as cnt
          from social.instagram_comments c
          where c.post_id = any(%s::uuid[])
            {instagram_comment_active_filter}
          group by c.post_id
          """,
          [post_ids],
      )
      for row in count_rows:
          comment_counts_by_post[row["post_id"]] = row["cnt"]
  ```

- **Semantic mapping that MUST be preserved** — the rollup migration
  (`supabase/migrations/20260610190000_instagram_post_comment_rollups.sql`) stores
  three columns:
  - `active_comment_count` = comments with `is_missing = false`
  - `total_comment_count` = all comments
  - `missing_comment_count` = comments with `is_missing = true`

  So the raw query above equals:
  - `active_comment_count` **when** `instagram_comment_active_filter` is applied
    (`_comment_lifecycle_supported("instagram_comments")` is true), and
  - `total_comment_count` **when** it is not.

  A naive swap to `active_comment_count` unconditionally is a **bug** — it would
  under-count when lifecycle is unsupported. The rollup column must be chosen by
  the same `_comment_lifecycle_supported` condition.

- The rollup-availability check already exists as a helper pattern:
  `read_models/account_profile/common.py:181` defines
  `_instagram_post_comment_rollups_available(*, conn=None)` →
  `_relation_exists("social.instagram_post_comment_rollups", conn=conn)`. The god
  module also has `_relation_exists` (grep to confirm the exact name it uses).

Repo conventions: ruff py311, line 120, double quotes. Tests under
`TRR-Backend/tests/`; DB-touching tests live in `tests/repositories/`. Rollup
behavior tests exist — grep `tests/` for `instagram_post_comment_rollups` to find
the pattern.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Find week/coverage count sites | `grep -n "from social.instagram_comments c" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` | the count sites |
| Find rollup helper | `grep -n "_relation_exists\|instagram_post_comment_rollups" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` | availability check + call sites |
| Import gate | `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` | exit 0 |
| Focused tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_season_comment_rollup_counts.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/socials/social_season_analytics_impl.py tests/socials/test_season_comment_rollup_counts.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` — add ONE
  private helper `_instagram_saved_comment_counts_by_post(...)` and call it from
  the Instagram **week-detail** builder and the Instagram **coverage** builder
  only.
- `TRR-Backend/tests/socials/test_season_comment_rollup_counts.py` (create).

**Out of scope** (do NOT touch):
- TikTok / YouTube / Threads / Facebook count sites (follow-up).
- Any change to rollup triggers or migrations.
- The `count(*)` used for anything other than the per-post comment count
  (e.g. media coverage counts, reply counts) — only the comment-count sites.
- The rest of the god module.

## Steps

### Step 1: Add one rollup-aware helper

Add a private helper near the Instagram week-detail builder. It returns a
`dict[post_id -> int]` and encapsulates: rollup-availability check, the
active/total column choice, and the raw fallback. Target shape:

```python
def _instagram_saved_comment_counts_by_post(
    post_ids: list[Any],
    *,
    active_filter_applied: bool,
) -> dict[Any, int]:
    """Per-post Instagram comment counts, from the rollup table when present.

    active_filter_applied mirrors the caller's is_missing filter:
      True  -> active_comment_count, False -> total_comment_count.
    Falls back to a raw aggregate when the rollup relation is absent so the
    result is identical either way.
    """
    counts: dict[Any, int] = defaultdict(int)
    if not post_ids:
        return counts
    if _relation_exists("social.instagram_post_comment_rollups"):
        column = "active_comment_count" if active_filter_applied else "total_comment_count"
        rows = pg.fetch_all(
            f"""
            select r.post_id, r.{column}::int as cnt
            from social.instagram_post_comment_rollups r
            where r.post_id = any(%s::uuid[])
            """,
            [post_ids],
        )
    else:
        active_filter = "and coalesce(c.is_missing, false) = false" if active_filter_applied else ""
        rows = pg.fetch_all(
            f"""
            select c.post_id, count(*)::int as cnt
            from social.instagram_comments c
            where c.post_id = any(%s::uuid[])
              {active_filter}
            group by c.post_id
            """,
            [post_ids],
        )
    for row in rows:
        counts[row["post_id"]] = row["cnt"]
    return counts
```

Use the exact `_relation_exists` symbol name the god module already defines
(confirm via grep in Step 0 commands). Match the file's f-string SQL style.

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` → exit 0.

### Step 2: Call the helper from the Instagram week-detail builder

Replace the inline `count_rows = pg.fetch_all(... instagram_comments ... group by post_id)`
block shown in "Current state" with:

```python
comment_counts_by_post = _instagram_saved_comment_counts_by_post(
    post_ids,
    active_filter_applied=bool(_comment_lifecycle_supported("instagram_comments")),
)
```

Delete the now-unused `instagram_comment_active_filter` local **only if** nothing
else in the function references it (grep the function body first).

**Verify**: `grep -n "select c.post_id, count(\*)::int as cnt" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` — the week-detail occurrence is gone (only the helper's fallback remains).

### Step 3: Apply the same helper at the Instagram coverage builder

Find the Instagram coverage count site (grep `from social.instagram_comments c`
for the site inside `_comments_coverage_for_platform` / the coverage builder).
If — and only if — it computes the identical per-post comment count with the same
`is_missing` semantics, replace it with the helper call the same way. If the
coverage site computes something different (e.g. a coverage ratio, distinct
authors, or a different filter), **do not change it** — note it in your report
and leave it.

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` → exit 0.

### Step 4: Parity test (the safety guardrail)

Create `tests/socials/test_season_comment_rollup_counts.py`. This is the gate
that proves the swap did not change results. Model it on the existing rollup test
(grep `tests/` for `instagram_post_comment_rollups`). Cover:

1. **Rollup present, lifecycle supported** → helper returns `active_comment_count`.
2. **Rollup present, lifecycle unsupported** → helper returns `total_comment_count`.
3. **Rollup absent** → helper falls back to the raw aggregate and returns the
   same numbers as a direct `count(*)` with the matching filter.

Prefer the repo's existing approach for these tests: if there is a DB-backed
rollup test harness, seed a post with N active + M missing comments and assert
the helper returns N (lifecycle on) / N+M (lifecycle off) and that this equals a
direct raw count. If the suite mocks `pg.fetch_all`, assert the helper issues the
rollup query (not the raw scan) when `_relation_exists` is true, and the raw
query when false. Match whichever pattern the existing rollup test uses.

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_season_comment_rollup_counts.py -q` → all pass.

## Test plan

- New `tests/socials/test_season_comment_rollup_counts.py` with the 3 cases
  above; the active-vs-total parity cases are mandatory.
- Verification: focused test command above → all pass.

## Done criteria

- [ ] `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` exits 0
- [ ] The Instagram week-detail builder calls `_instagram_saved_comment_counts_by_post`
- [ ] The helper chooses `active_comment_count` vs `total_comment_count` by
      `active_filter_applied` (grep shows both columns present)
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_season_comment_rollup_counts.py -q` passes, including the active-vs-total parity cases
- [ ] `cd TRR-Backend && ruff check ...` exits 0
- [ ] No files outside scope modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report (do not improvise) if:

- The week-detail count block does not match the "Current state" excerpt.
- You cannot confirm, from the migration, that `active_comment_count` =
  `count(*) where is_missing=false` and `total_comment_count` = `count(*)` (the
  mapping is the whole correctness argument — do not guess).
- The coverage site computes a different quantity than the week-detail count
  (leave it; report it).
- The parity test cannot be made to show rollup and raw producing identical
  numbers — that means the mapping is wrong; STOP rather than shipping changed
  counts.

## Maintenance notes

- **Follow-up (same pattern, deferred):** TikTok (`social.tiktok_post_comment_rollups`,
  key `video_id`) and YouTube (`social.youtube_post_comment_rollups`) week-detail
  and coverage sites can adopt an equivalent helper. Twitter/Threads/Facebook have
  no rollup table, so they keep the raw count.
- This mirrors a decision the team already made in the account-profile read path
  (`read_models/account_profile/common.py` reads `active_comment_count`), so
  rollup-as-source-of-truth for counts is established, not new.
- A reviewer should confirm the trigger that maintains the rollup
  (`social.refresh_instagram_post_comment_rollup`) is live; if the rollup could
  lag raw counts, that is a rollup-maintenance bug to fix separately, not a reason
  to keep scanning raw here.
