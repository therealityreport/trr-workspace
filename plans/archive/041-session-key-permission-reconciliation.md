# Plan 041: Reconcile at-rest permissions on live social sessions and service-account keys to 0600

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/browser_cookie_refresh.py trr_backend/socials/account_browser_sessions.py`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch, treat
> it as a STOP condition. If the SHA does not resolve, compare by hand and note it.
>
> **NOTE — this plan also requires a manual operator action (credential
> rotation) that the executor cannot perform. Do the code change, then report
> the rotation checklist in "Maintenance notes" back to the operator.**

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

The backend maintains authenticated Instagram browser sessions on disk under
`data/social-browser-sessions/` and GCP service-account keys under `keys/`. The
code already intends these to be private: `write_private_json_file` writes at
`0o600` and `ensure_private_file_mode` re-chmods to `0o600`. But that intent is
not reconciled across all files — several older session files
(`bravodailydish.cookies.json`, `bravowwhl.cookies.json`, their `.storage-state.json`
siblings, a stale `bravotv.cookies.json.bak`, and
`entertainmentdatagroup-gmail.com.storage-state.json`) are **0644
(world-readable)**, while newer files are correctly 0600 — so this is drift, not
policy. All three GCP `service_account` JSON keys in `keys/` are likewise **0644**,
and the parent directories are **0755**. Any other local user or any non-root
process/daemon (backup/sync agents) running under this login can read live
Instagram session cookies (full session takeover of the scraper accounts) and
GCP private keys (cloud-resource access).

Good news, already verified: **nothing under `data/`, `keys/`, or `.locks/` is
tracked in git** (they are gitignored), so this is not a public-repo leak — it is
an at-rest permission gap on the runtime host. The fix is an idempotent
permission-reconciliation sweep at worker/process start that hardens every file
under the session root and `keys/` to 0600 and the dirs to 0700, reusing the
existing `ensure_private_file_mode` helper. Because these credentials have sat
world-readable, remediation also includes **rotating** them (operator action).

## Current state

- `trr_backend/socials/browser_cookie_refresh.py` — the existing private-file
  helpers (lines 440-467). Reuse these:

```python
def ensure_private_file_mode(path: str | Path) -> None:
    target = Path(path).expanduser()
    if not target.exists():
        return
    try:
        target.chmod(0o600)
    except OSError:
        logger.debug("Failed to chmod private cookie/session file %s", target, exc_info=True)


def write_private_json_file(path: str | Path, payload: Any) -> None:
    target = Path(path).expanduser()
    target.parent.mkdir(parents=True, exist_ok=True)
    ...
    os.replace(temp_path, target)
    target.chmod(0o600)
```

- `trr_backend/socials/account_browser_sessions.py` — the session store. It
  re-chmods `storage_state` on open (~line 238) but never the `.cookies.json`
  files, `.bak` siblings, idle accounts, or `keys/`, and there is no
  reconciliation sweep. The session root is env-overridable via
  `SOCIAL_BROWSER_SESSION_DIR` (~lines 53-60); default resolves under
  `data/social-browser-sessions/`.

- Observed on-disk state (host at planning time): mixed 0644/0600 session files,
  0644 on all three `keys/*.json`, 0755 dirs. `git ls-files data/ keys/` is
  empty (nothing tracked).

Convention: use `pathlib.Path`, the module `logger`, and the existing
`ensure_private_file_mode` helper. Be defensive — chmod failures must be logged
and swallowed (a permission sweep must never crash a worker). ruff py311, line
120, double quotes.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                                 | Expected on success   |
|--------------|-----------------------------------------------------------------------------------|-----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                            | exit 0                |
| Focused test | `.venv/bin/python -m pytest tests/socials/test_cookie_refresh_flows.py -q`         | all pass              |
| Lint         | `ruff check trr_backend/socials/browser_cookie_refresh.py`                         | `All checks passed!`  |
| Perm check   | (manual, host) `find data/social-browser-sessions keys -type f -perm -044 -maxdepth 2` after running the sweep → no output | no world-readable files remain |

## Scope

**In scope** (the only files you should modify):
- `trr_backend/socials/browser_cookie_refresh.py` — add an idempotent
  `reconcile_private_paths(...)` sweep next to the existing helpers
- The worker/session entrypoint that should call the sweep — likely
  `trr_backend/socials/account_browser_sessions.py` (call the sweep once when the
  session store is first accessed) and/or the worker `main()` in
  `scripts/socials/worker.py`. Choose the single most central entrypoint; do not
  wire it into many places.
- Tests: `tests/socials/test_cookie_refresh_flows.py` (or a new
  `tests/socials/test_private_path_reconcile.py`)

**Out of scope** (do NOT touch):
- The actual credential values, the session-refresh logic, or
  `write_private_json_file`'s write path (already correct).
- `.gitignore` — the paths are already ignored; do not change ignore rules.
- Anything under `keys/` at runtime other than chmod-ing the files (do not move,
  rename, or read key contents).

## Git workflow

- Branch: `advisor/041-session-key-permission-reconciliation`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `reconcile at-rest permissions for social sessions and service-account keys`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add an idempotent permission-reconciliation sweep

In `browser_cookie_refresh.py`, next to `ensure_private_file_mode`, add:

```python
def reconcile_private_paths(*roots: str | Path, dir_mode: int = 0o700, file_mode: int = 0o600) -> int:
    """Best-effort: chmod every file under each root to 0600 and dirs to 0700.

    Idempotent and non-fatal — chmod failures are logged and swallowed so a
    permission sweep can never crash a worker. Returns the count of files
    hardened (for logging/tests).
    """
    hardened = 0
    for root in roots:
        base = Path(root).expanduser()
        if not base.exists():
            continue
        try:
            for path in base.rglob("*"):
                try:
                    if path.is_dir():
                        path.chmod(dir_mode)
                    elif path.is_file():
                        path.chmod(file_mode)
                        hardened += 1
                except OSError:
                    logger.debug("Failed to chmod %s during private-path reconcile", path, exc_info=True)
            try:
                base.chmod(dir_mode)
            except OSError:
                logger.debug("Failed to chmod root %s during private-path reconcile", base, exc_info=True)
        except OSError:
            logger.debug("Failed to walk %s during private-path reconcile", base, exc_info=True)
    return hardened
```

**Verify**: `.venv/bin/python -c "from trr_backend.socials.browser_cookie_refresh import reconcile_private_paths"` → exit 0.

### Step 2: Call the sweep from the central session/worker entrypoint

Wire the sweep to run once at startup over the two sensitive roots. Prefer the
session store's initialization in `account_browser_sessions.py` (so any process
that touches sessions hardens them). Resolve the two roots from the same config
the store already uses:

- session root: the resolved `SOCIAL_BROWSER_SESSION_DIR` (reuse the existing
  resolver in `account_browser_sessions.py`; do not hardcode the path).
- keys root: the `keys/` directory — resolve it the way the codebase already
  locates service-account keys (grep for `keys/` / `GOOGLE_APPLICATION_CREDENTIALS`
  / a keys-dir constant; use that, do not hardcode a relative path that depends
  on cwd).

Call `reconcile_private_paths(session_root, keys_root)` once (guard with a
module-level "already reconciled" flag so it does not run on every session open).
Log a single info line with the hardened count. If a central keys-dir resolver
does not exist, reconcile only the session root and note the keys-dir gap in your
report rather than hardcoding a fragile path.

**Verify**: `.venv/bin/python -c "import api.main"` → exit 0 (no import-time crash).

### Step 3: Remove the orphaned `.bak` cookie snapshot handling

The stale `bravotv.cookies.json.bak` (0644) has no creator in current code and no
cleanup path (`reset_account_context` unlinks only `.storage-state.json` and
`.cookies.json`). Do not special-case `.bak` in code, but ensure the sweep in
Step 1 covers it (it does — `rglob("*")` includes `.bak`). Optionally, if
`reset_account_context` is in scope and trivially extendable, have it also unlink
`*.bak` siblings; if that widens scope, leave it and note it as follow-up. Do
**not** delete the on-disk `.bak` from within this code change — that is an
operator action (Maintenance notes).

**Verify**: `ruff check trr_backend/socials/browser_cookie_refresh.py` → `All checks passed!`

## Test plan

Add a test (in `tests/socials/test_cookie_refresh_flows.py` or a new file). Model
after existing tests that use `tmp_path`:

- Create a temp dir with a nested file at mode `0o644` and a subdir at `0o755`.
- Call `reconcile_private_paths(tmp_dir)`.
- Assert the file is now `0o600` and the dirs are `0o700`
  (`oct(path.stat().st_mode & 0o777)`), and the returned count is the number of
  files.
- Assert a non-existent root is a no-op (no exception) and a chmod failure is
  swallowed (patch `Path.chmod` to raise `OSError` and assert the function
  returns without raising).

Verification: `.venv/bin/python -m pytest tests/socials/test_cookie_refresh_flows.py -q` (or the new test module) → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -c "from trr_backend.socials.browser_cookie_refresh import reconcile_private_paths"` exits 0
- [ ] `.venv/bin/python -m pytest <the test module you used> -q` passes, with the new tests
- [ ] `ruff check trr_backend/socials/browser_cookie_refresh.py` prints `All checks passed!`
- [ ] `grep -n "reconcile_private_paths" trr_backend/socials/account_browser_sessions.py` (or the chosen entrypoint) shows the sweep is called at startup
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- A "Current state" excerpt does not match live code (drift).
- The session store has no single initialization point and wiring the sweep
  would require touching many call sites — report and propose the worker `main()`
  as the single call site instead.

**NOT a STOP condition — proceed:** if there is no central keys-dir resolver,
this is the *expected* fallback, not a stop. Reconcile only the session root
(Step 2), skip the `keys/` reconciliation, and note the keys-dir gap in your
report. Do NOT stop for this; do NOT hardcode a cwd-relative `keys/` path.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

**Operator actions required after this code lands (executor cannot do these):**
1. Run the sweep once on the host (or restart a worker so Step 2 runs), then
   verify: `find data/social-browser-sessions keys -type f -perm -044` returns
   nothing.
2. Delete the orphaned `data/social-browser-sessions/instagram/bravotv.cookies.json.bak`.
3. **Rotate the exposed credentials** — they sat world-readable, so treat as
   burned: re-authenticate the affected Instagram scraper sessions
   (`bravodailydish`, `bravowwhl`, `bravotv`, `entertainmentdatagroup-gmail.com`,
   and any other that was 0644), and regenerate/rotate the three GCP
   service-account keys in `keys/` (issue new keys, update the runtime secret,
   disable the old keys).

- A reviewer should confirm the sweep is idempotent, non-fatal, and runs once (a
  module flag), and that no key contents are read or logged.
- This does not change how sessions are written (already 0600); it reconciles
  pre-existing drift and covers `keys/`, which the write path never touched.
