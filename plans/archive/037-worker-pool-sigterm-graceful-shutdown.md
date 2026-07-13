# Plan 037: Give the social worker pool a SIGTERM handler so stop/deploy doesn't orphan grandchild workers

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- scripts/socials/worker.py scripts/socials/start_worker_pool.sh`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch, treat
> it as a STOP condition. If the SHA does not resolve, compare by hand and note it.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

The social scrape worker pool is a three-level process tree: `start_worker_pool.sh`
launches one `scripts.socials.worker --stage X --parallel N` process per stage
(level 2), and each of those `subprocess.Popen`s N grandchild workers (level 3)
that actually claim and process queue jobs. `worker.py` has **no SIGTERM
handler** anywhere — cleanup lives only in a `finally` block and a
`KeyboardInterrupt` (SIGINT) handler. When the pool is stopped
(`start_worker_pool.sh`'s `stop_all` sends `kill -TERM` to the level-2 PIDs) or a
deploy/orchestrator sends SIGTERM, Python's default SIGTERM disposition
terminates the level-2 process **immediately without running its `finally`**, so
its Popen grandchildren are reparented to init and keep running: claiming jobs,
holding psycopg2 pool connections, and spending Decodo/Instagram proxy budget
after operators believe the pool is stopped. The orphaned grandchildren never
call `mark_worker_stopped`, so heartbeat rows go stale instead of clean-stopped,
and in single-worker mode an in-flight `process_claimed_job` is hard-killed
mid-write.

After this plan, SIGTERM is converted into the same graceful path SIGINT already
takes: children are terminated, the heartbeat is stopped, and the process exits
cleanly with no orphans.

## Current state

- `scripts/socials/worker.py`:
  - No `import signal` and no SIGTERM/SIGINT handler (grep for `signal.` returns
    only unrelated `repair_signal` dict keys in a *different* file).
  - Children are spawned with a bare Popen (lines 707-741):
    ```python
    def _spawn_child_worker(...) -> subprocess.Popen:
        cmd = [sys.executable, "-m", "scripts.socials.worker", "--worker-id", worker_id, "--parallel", "1", ...]
        ...
        return subprocess.Popen(cmd, cwd=os.getcwd(), env=os.environ.copy())
    ```
    Note: no `start_new_session=` / process-group isolation.
  - `_wait_for_children` (lines ~786-833) does terminate children, but only on
    the normal-return path, on `KeyboardInterrupt`, and in `finally`:
    ```python
    except KeyboardInterrupt:
        exit_code = 130
        logger.warning("%s interrupted; terminating child workers", context_label)
        for proc in children:
            if _poll_process(proc) is None:
                _stop_process(proc, force=False)
    finally:
        ...  # force-kill any still-alive children after a grace period
    ```
    On SIGTERM none of these run — the interpreter exits before the `finally`.
  - `main()` (starts line 836) parses args, spawns children, and blocks in
    `_wait_for_children`. Its own cleanup is likewise `finally`-guarded
    (line 1186).
  - `_stop_process` (lines 765-783) already exists and terminates/kills a Popen.

- `scripts/socials/start_worker_pool.sh`:
  - `start_worker` runs `"$PYTHON_BIN" -m scripts.socials.worker "$@" &` and
    records `$!` in `PIDS` (lines ~108-113).
  - `stop_all` loops `PIDS` doing `kill -TERM "$pid"` then `wait` (lines ~114-123).
  - `trap stop_all EXIT INT TERM` (line 125); script ends on `wait` (line 164).

Convention: `worker.py` uses the module `logger` with structured bracketed tags;
match it. ruff py311, line 120, double quotes.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                    | Expected on success   |
|--------------|----------------------------------------------------------------------|-----------------------|
| Import gate  | `.venv/bin/python -c "import scripts.socials.worker"`                 | exit 0                |
| Focused test | `.venv/bin/python -m pytest tests/scripts/test_social_worker.py -q`   | all pass              |
| Lint         | `ruff check scripts/socials/worker.py`                                | `All checks passed!`  |
| Shell syntax | `bash -n scripts/socials/start_worker_pool.sh`                        | exit 0                |

## Scope

**In scope** (the only files you should modify):
- `scripts/socials/worker.py` — install a SIGTERM (and explicit SIGINT) handler
  that triggers the existing graceful-shutdown path
- `tests/scripts/test_social_worker.py` — add a handler-behavior test
- `scripts/socials/start_worker_pool.sh` — make `stop_all` signal the process
  group and give children time to drain (secondary hardening)

**Out of scope** (do NOT touch, even though they look related):
- The job-claim / heartbeat / `mark_worker_stopped` logic — do not change *what*
  cleanup does, only ensure it runs on SIGTERM.
- `scripts/workers/reddit_refresh_worker.py` and the remote supervisor — the
  Reddit worker's loop/respawn is covered by plan 036; do not touch it here.
- `_spawn_child_worker`'s command construction — leave the argv as-is (you may
  add `start_new_session=True`, see Step 2, but do not change the args).

## Git workflow

- Branch: `advisor/037-worker-pool-sigterm-graceful-shutdown`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `handle SIGTERM in the social worker pool to avoid orphaned children`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Convert SIGTERM into a graceful stop signal

At the top of `main()` (before spawning children), install signal handlers that
raise the same exception the existing `KeyboardInterrupt` path already handles,
or set a stop `Event` the loop and `_wait_for_children` observe. The
lowest-risk approach that reuses the existing cleanup is to make SIGTERM raise
`KeyboardInterrupt` (which the code already handles end-to-end):

```python
import signal

def _install_graceful_shutdown() -> None:
    def _handler(signum, _frame):
        logger.warning("[social_worker_signal] received signal=%s; shutting down", signum)
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, _handler)
    signal.signal(signal.SIGINT, _handler)
```

Call `_install_graceful_shutdown()` at the start of `main()`. This makes a
`kill -TERM` land as a `KeyboardInterrupt` inside `_wait_for_children` (and the
single-worker loop), so the existing `except KeyboardInterrupt` / `finally`
child-termination + heartbeat-stop cleanup runs, and the process exits cleanly
(130).

Important correctness note: `raise` inside a signal handler only interrupts the
**main thread**. The heartbeat runs on a daemon thread and its `.stop()` is
already invoked from `main()`'s `finally`, so that is fine. But if the main
thread is blocked in `proc.wait()` (a C call), the handler still runs between
syscalls on CPython; verify the single-worker loop also checks for the interrupt.
If the codebase prefers an `Event`-based stop over exception-raising, use an
`Event` set by the handler and checked in both the single-worker loop and
`_wait_for_children`'s wait loop — either is acceptable as long as the existing
child-termination path executes on SIGTERM.

**Verify**: `.venv/bin/python -c "import scripts.socials.worker"` → exit 0.

### Step 2: Isolate children into their own process group (defense in depth)

So that a signal to the level-2 worker can be propagated to its grandchildren as
a group (and so an orphaned grandchild is easy to sweep), start children in a new
session:

- In `_spawn_child_worker`, add `start_new_session=True` to the `subprocess.Popen(...)`
  call. This puts each child in its own process group led by the child.
- In `worker.py`'s child-termination path (`_stop_process` or where children are
  signalled), when terminating a child prefer signalling its group
  (`os.killpg(os.getpgid(proc.pid), signal.SIGTERM)`) with a fallback to
  `proc.terminate()` if `getpgid` fails (the child may have already exited).
  Keep the existing force-kill escalation after the grace period.

Keep this minimal and guarded — wrap the `killpg` in try/except so a
race (child already gone) does not raise.

**Verify**: `ruff check scripts/socials/worker.py` → `All checks passed!`

### Step 3: Make the pool script signal the group and allow drain time

In `scripts/socials/start_worker_pool.sh`'s `stop_all`, send SIGTERM to the
process group of each tracked PID (so grandchildren get the signal even if the
level-2 handler is mid-install), then wait a bounded grace period before the
trap's implicit exit. Target shape:

```bash
stop_all() {
  if [[ "${#PIDS[@]}" -eq 0 ]]; then
    return
  fi
  echo "[social-worker-pool] stopping workers..."
  for pid in "${PIDS[@]}"; do
    kill -TERM "-${pid}" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1 || true
  done
  wait || true
}
```

`kill -TERM "-${pid}"` signals the process group led by `pid` (requires the
worker to have been started in its own group; with `start_new_session=True` on
the children and the shell's job control, the level-2 process leads a group).
Keep the plain `kill -TERM "$pid"` fallback. Do not change the `trap` line.

**STOP and report** if `start_worker_pool.sh` is not the script that launches
this pool in the target deployment, or if the pool is actually run under a
process supervisor (systemd/launchd/Modal) that owns signal delivery — in that
case Step 1 (the in-process handler) is the load-bearing fix and Step 3 may be
unnecessary or handled by the supervisor.

**Verify**: `bash -n scripts/socials/start_worker_pool.sh` → exit 0.

## Test plan

Add to `tests/scripts/test_social_worker.py` (model after the existing tests in
that file — they already import and drive `scripts.socials.worker`):

- A test that installing the handler and delivering `signal.SIGTERM` to the
  current process (or invoking `_handler` directly) raises `KeyboardInterrupt`
  (or sets the stop Event, depending on the approach chosen), proving SIGTERM is
  wired to the graceful path. Use `signal.getsignal(signal.SIGTERM)` after
  `_install_graceful_shutdown()` to assert a non-default handler is installed.
- If feasible with the existing harness, a test that `_spawn_child_worker`'s
  Popen is called with `start_new_session=True` (patch `subprocess.Popen`, assert
  the kwarg) — only if the test file already patches Popen; otherwise skip and
  note it.

Verification: `.venv/bin/python -m pytest tests/scripts/test_social_worker.py -q` → all pass, with the new test(s).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import scripts.socials.worker"` exits 0
- [ ] `.venv/bin/python -m pytest tests/scripts/test_social_worker.py -q` passes, with the new handler test present
- [ ] `ruff check scripts/socials/worker.py` prints `All checks passed!`
- [ ] `bash -n scripts/socials/start_worker_pool.sh` exits 0
- [ ] `grep -n "signal.SIGTERM" scripts/socials/worker.py` returns a match (handler installed)
- [ ] `grep -n "start_new_session=True" scripts/socials/worker.py` returns a match (children isolated)
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts do not match live code (drift).
- The heartbeat thread or a library the worker uses already installs its own
  SIGTERM handler you would be overriding (grep the imported modules for
  `signal.signal`) — coordinate rather than clobber.
- Raising in the handler causes a re-entrancy problem you cannot resolve
  (e.g. the handler fires while cleanup is already running) — switch to the
  Event-based approach and report.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should confirm: (1) the graceful path actually calls
  `heartbeat.stop()` and terminates all children on SIGTERM, and (2) no code
  path can now double-kill a child (Event vs exception re-entrancy).
- If the pool is later moved under a real process supervisor, the in-process
  handler still helps (it makes SIGTERM clean), but Step 3's group-signal in the
  bash launcher may become redundant.
- Deferred: converting the ad-hoc bash launcher into a supervised unit is a
  larger DX change out of scope here.
