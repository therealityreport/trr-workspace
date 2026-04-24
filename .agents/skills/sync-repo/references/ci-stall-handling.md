# CI Stall Handling

## Stall Definition
Treat checks as stalled when check state snapshots do not change for `stall-threshold-min`.

A snapshot is the set of `(check name, status, conclusion)` across PR checks.

## Hung-Candidate Definition
Treat checks as hung candidates when snapshots do not change for `hung-threshold-min` and checks are still in-flight.

Hung candidates are intervened on immediately; do not wait for full stall timeout.

## Rerun Cadence
1. Poll checks frequently (`check-poll-seconds`, default `8`).
2. If a hung candidate is detected, cancel/rerun GitHub Actions runs linked from check details URLs immediately.
3. If still unchanged until `stall-threshold-min`, cancel/rerun again if rerun budget remains.
4. Stop after rerun budget (`stall-reruns`) is exhausted.

## Admin Merge Eligibility
Allow admin merge only when all of the following are true:
1. No failing checks are present.
2. Checks are still non-terminal after rerun budget is exhausted.
3. `--allow-admin-merge-on-stall=true`.

Do not use admin merge as first-line behavior.

## Recommended Defaults
- `--check-poll-seconds 8`
- `--hung-threshold-min 5`
- `--stall-threshold-min 15`
- `--stall-reruns 1`
- `--ci-timeout-min 45`
- `--allow-admin-merge-on-stall true`

## Failure Modes
- If checks fail: return `needs_fix` and stop.
- If checks stall and admin fallback disabled: return `stalled_no_admin` and stop.
- If merge command fails: return `merge_failed`.
