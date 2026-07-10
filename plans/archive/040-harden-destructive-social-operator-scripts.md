# Plan 040: Harden the destructive social operator scripts (retire race + delete-by-default)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- scripts/socials/retire_stale_instagram_media_mirror_failures.py scripts/socials/retire_duplicate_instagram_media_mirror_jobs.py scripts/socials/retire_duplicate_instagram_comment_media_mirror_jobs.py scripts/socials/cleanup_youtube_false_positives.py`
> If any file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition. If the SHA does not resolve, compare by hand and note it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug / security (destructive-op safety)
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

Two safety gaps exist in the social operator one-shot scripts that run against
the live production database:

1. **Retire scripts race live workers.** Three `retire_*` scripts SELECT a set of
   matching `social.scrape_jobs` rows and then, in a *separate* second read +
   UPDATE, set `status='cancelled' where id = any(%s)` with **no status predicate
   in the UPDATE's WHERE**. A pool worker can transition a matched job
   (`failed`→`retrying`→`running`→`completed`) in the window between the read and
   the update, so the update clobbers a now-active or completed job to
   `cancelled`, discarding real work. A sibling script
   (`retire_stale_threads_media_mirror_failures.py`) already re-applies its full
   `status`-bearing WHERE in the UPDATE, and `reconcile_stale_social_run.py`
   includes `and status = any(%s)` — so the guarded pattern already exists in the
   fleet; three scripts drifted off it.

2. **`cleanup_youtube_false_positives.py` deletes by default.** It runs a hard
   `DELETE FROM social.youtube_videos` unless `--dry-run` is passed — safety is
   *opt-in*. Every other retire/repair script in the fleet defaults to safe and
   requires an explicit write flag (`--apply` / `--execute` / `--confirm-*`). An
   operator who omits `--dry-run` irreversibly deletes rows.

These are `--apply`-style operator tools, so blast radius is bounded, but they
run against the live queue/table and the current defaults make a mistake easy.
After this plan the retire UPDATEs are race-safe and the cleanup script defaults
to dry-run with an explicit `--apply` gate, matching the fleet convention.

## Current state

- `scripts/socials/retire_stale_instagram_media_mirror_failures.py` — the UPDATE
  has no status predicate (lines 156-171):

```python
    return pg.execute_returning(
        """
        update social.scrape_jobs
        set
          status = 'cancelled',
          error_message = %s,
          last_error_code = %s,
          last_error_class = %s,
          metadata = coalesce(metadata, '{}'::jsonb) || %s::jsonb
        where id::text = any(%s)
        returning id::text as id, season_id::text as season_id, show_id::text as show_id
        """,
        [OBSOLETE_ERROR_MESSAGE, OBSOLETE_ERROR_CODE, OBSOLETE_ERROR_CLASS, payload, job_ids],
    )
```

  And `main()` reads twice — preview from `_fetch_matches`, mutation from a
  second read inside `_retire_matches` (lines 181-185):

```python
    matched_rows = _fetch_matches(season_ids=season_ids, show_ids=show_ids)
    stats = CleanupStats(matched_rows=len(matched_rows), retired_rows=0)
    if not dry_run and matched_rows:
        retired_rows = _retire_matches(season_ids=season_ids, show_ids=show_ids)
        stats.retired_rows = len(retired_rows)
```

  The same missing-status-guard pattern is in
  `retire_duplicate_instagram_media_mirror_jobs.py` (~lines 115-134) and
  `retire_duplicate_instagram_comment_media_mirror_jobs.py` (~lines 192-205).
  Read each before editing to find the exact eligibility status set each one
  targets (e.g. the stale-failures script targets `failed`; the duplicate
  scripts target the states a duplicate can be in — confirm from each
  `_fetch_matches` WHERE clause).

- The safe sibling to mirror: `retire_stale_threads_media_mirror_failures.py`
  (~lines 119-135) re-applies its `where {where_clause}` (which includes the
  status filter) in the UPDATE. Read it as the pattern.

- `scripts/socials/cleanup_youtube_false_positives.py` — deletes by default; the
  only guard is opt-in `--dry-run` (lines 65-106):

```python
def _delete_rows(*, row_ids: list[str]) -> int:
    deleted = pg.execute_returning(
        """
        delete from social.youtube_videos
        where id = any(%s::uuid[])
        returning id
        """,
        [row_ids],
    )
    return len(deleted)

def main() -> None:
    parser = argparse.ArgumentParser(description="Clean known YouTube false positives for a show.")
    parser.add_argument("--show-id", help="Show UUID to scope cleanup.")
    parser.add_argument("--show-name", default=DEFAULT_SHOW_NAME, ...)
    parser.add_argument("--dry-run", action="store_true", help="Preview candidate rows without deleting.")
    args = parser.parse_args()
    ...
    if args.dry_run:
        logger.info("Dry run enabled: no rows deleted.")
        return
    if not candidates:
        logger.info("No rows to delete.")
        return
    deleted_count = _delete_rows(row_ids=[str(row["id"]) for row in candidates])
```

- The fleet convention to match (from
  `retire_stale_instagram_media_mirror_failures.py`'s arg parsing):
  `set_defaults(dry_run=True)` + an `--apply` flag, with
  `dry_run = bool(args.dry_run and not args.apply)`.

Convention: these scripts use `pg.execute_returning` with parameterized values;
never string-build values into SQL. `load_env()` at the top of `main()`. ruff
py311, line 120, double quotes.

## Commands you will need

| Purpose        | Command (run from `TRR-Backend/`)                                        | Expected on success   |
|----------------|--------------------------------------------------------------------------|-----------------------|
| Import gate    | `.venv/bin/python -c "import api.main"`                                   | exit 0                |
| Syntax/import  | `.venv/bin/python -c "import scripts.socials.cleanup_youtube_false_positives, scripts.socials.retire_stale_instagram_media_mirror_failures"` | exit 0 |
| Focused test   | `.venv/bin/python -m pytest tests/scripts -q -k "retire or cleanup_youtube or media_mirror"` | all pass (or "no tests ran" — then rely on the added tests) |
| Lint           | `ruff check scripts/socials/retire_stale_instagram_media_mirror_failures.py scripts/socials/retire_duplicate_instagram_media_mirror_jobs.py scripts/socials/retire_duplicate_instagram_comment_media_mirror_jobs.py scripts/socials/cleanup_youtube_false_positives.py` | `All checks passed!` |

## Scope

**In scope** (the only files you should modify):
- `scripts/socials/retire_stale_instagram_media_mirror_failures.py`
- `scripts/socials/retire_duplicate_instagram_media_mirror_jobs.py`
- `scripts/socials/retire_duplicate_instagram_comment_media_mirror_jobs.py`
- `scripts/socials/cleanup_youtube_false_positives.py`
- Tests for these scripts under `tests/scripts/` (add or extend — see Test plan)

**Out of scope** (do NOT touch):
- `retire_stale_threads_media_mirror_failures.py` and
  `reconcile_stale_social_run.py` — they are already guarded; use them only as
  reference patterns.
- The job state machine / worker claim logic in `trr_backend/` — do not change
  what statuses mean; only make the scripts respect them.
- The `_fetch_matches` selection logic — keep the candidate selection identical;
  only add the status predicate to the *UPDATE* and fix the delete default.

## Git workflow

- Branch: `advisor/040-harden-destructive-social-operator-scripts`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `make social retire/cleanup scripts race-safe and dry-run by default`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the eligibility status predicate to each retire UPDATE

For each of the three retire scripts, add the same status filter the script's
`_fetch_matches` uses to the UPDATE's WHERE, so a job that has moved to an
ineligible state since selection is not clobbered. For the stale-failures script:

```sql
        where id::text = any(%s)
          and status = 'failed'
```

For the two duplicate scripts, use the exact status set their selection targets
(read each `_fetch_matches` WHERE — e.g. `status = any(%s)` with the same list
used in selection). Pass the status value(s) as bound parameters, appended to the
existing params list — never interpolate them.

This makes the UPDATE a no-op for any row that changed state after the SELECT,
which is the correct behavior: a job that a worker has since picked up must not be
cancelled out from under it.

**Verify**: `.venv/bin/python -c "import scripts.socials.retire_stale_instagram_media_mirror_failures, scripts.socials.retire_duplicate_instagram_media_mirror_jobs, scripts.socials.retire_duplicate_instagram_comment_media_mirror_jobs"` → exit 0.

### Step 2: Flip `cleanup_youtube_false_positives.py` to dry-run-by-default with `--apply`

Match the fleet convention:

- Change the arg parser so dry-run is the default and deletion requires
  `--apply`:
  ```python
  parser.add_argument("--dry-run", action="store_true", default=True,
                      help="Preview candidate rows without deleting (default).")
  parser.add_argument("--apply", action="store_true",
                      help="Actually delete matched rows. Without this, runs in dry-run.")
  ...
  args = parser.parse_args()
  dry_run = bool(args.dry_run and not args.apply)
  ```
  (Use `set_defaults(dry_run=True)` if that reads cleaner — match the
  stale-failures script's exact idiom.)
- Replace the `if args.dry_run:` early-return with `if dry_run:` and update the
  log line to mention `--apply`:
  ```python
  if dry_run:
      logger.info("Dry run (default): no rows deleted. Re-run with --apply to delete %d rows.", len(candidates))
      return
  ```

Do not change `_find_candidate_rows` or `_delete_rows` — only the gating.

**Verify**: running the script with no flags must NOT delete. Prove it in the
test (Step 3), and by inspection: `dry_run` is `True` unless `--apply` is passed.

### Step 3: Tests

Under `tests/scripts/` add (or extend an existing) test module. Model after any
existing `tests/scripts/test_*` that patches `pg.execute_returning` / the DB
layer. Cover:

- **Retire UPDATE carries the status predicate**: patch the `pg.execute_returning`
  used by the retire script's `_retire_matches`, invoke it, and assert the SQL
  string passed contains `status` in the UPDATE WHERE (and that the status value
  is in the bound params, not interpolated). One test per retire script, or a
  parametrized test across the three.
- **cleanup defaults to dry-run**: invoke `cleanup_youtube_false_positives.main`
  (patch `_resolve_show_id`/`_find_candidate_rows` to return a fake candidate and
  patch `_delete_rows` as a spy) with `argv` containing no `--apply`, and assert
  `_delete_rows` is **not** called; then with `--apply` assert it **is** called.
  If `main()` reads `sys.argv` directly, patch `sys.argv` or refactor `main` to
  accept `argv` (mirror how the retire scripts already accept `argv` in `main`).

Verification: `.venv/bin/python -m pytest tests/scripts -q -k "retire or cleanup_youtube or media_mirror"` → all pass, with the new tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] The three retire-script UPDATEs each include a `status` predicate:
      `grep -A12 "update social.scrape_jobs" scripts/socials/retire_stale_instagram_media_mirror_failures.py scripts/socials/retire_duplicate_instagram_media_mirror_jobs.py scripts/socials/retire_duplicate_instagram_comment_media_mirror_jobs.py | grep -c "status ="` is ≥ 3 (one per script; count reflects both the `set` and the WHERE — confirm each file has the WHERE predicate by reading)
- [ ] `grep -n "\-\-apply" scripts/socials/cleanup_youtube_false_positives.py` returns a match
- [ ] `.venv/bin/python -m pytest tests/scripts -q -k "retire or cleanup_youtube or media_mirror"` passes, with the new tests
- [ ] `ruff check` on the four in-scope scripts prints `All checks passed!`
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- A "Current state" excerpt does not match live code (drift).
- A retire script's `_fetch_matches` selects across statuses in a way that makes
  a single status predicate wrong (e.g. it legitimately retires jobs in multiple
  states) — in that case add `and status = any(%s)` with the exact selection set,
  and if the selection set is not obvious from the code, report rather than guess.
- `cleanup_youtube_false_positives.main` cannot be tested without a live DB and
  the existing test harness has no DB-layer patch point — report the gap; still
  make the default-flip change and verify by inspection.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should confirm every destructive UPDATE/DELETE in these scripts now
  either re-applies its eligibility WHERE or is dry-run-gated, and that no value
  is string-interpolated into SQL.
- Follow-up (not in this plan): `backfill_instagram_reel_views_full_history.py`
  executes real runs with no `--dry-run`/`--commit` at all — a candidate for the
  same guard convention. Recorded in the backlog.
- The durable fix for the class of bug is a shared `scripts/socials/_common.py`
  helper for "select + guarded destructive update in one transaction"; this plan
  fixes the four highest-risk scripts without that refactor.
