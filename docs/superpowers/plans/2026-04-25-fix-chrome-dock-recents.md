# Chrome Dock Recents Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop TRR-managed Chrome automation launches from leaving repeated Chrome icons in the macOS Dock recents area, while preserving the shared Chrome MCP lifecycle.

**Architecture:** Add a small, testable macOS Dock plist cleaner that removes only `com.google.Chrome` entries from `recent-apps`. Expose it through a shell wrapper and a Makefile target for manual cleanup, then wire it into Chrome-agent stop and MCP cleanup behind an explicit opt-in environment flag so automation does not silently mutate Dock preferences.

**Tech Stack:** Bash workspace scripts, Python 3 `plistlib`, pytest, macOS Dock preferences, existing TRR Chrome MCP scripts.

---

## Scope Check

This is a workspace tooling fix only. Do not touch `TRR-APP` or `TRR-Backend` runtime code. The root problem is in the TRR/Codex browser-control layer plus macOS Dock recent-app persistence:

- TRR shared browser automation starts managed Chrome via `/Applications/Google Chrome.app`.
- macOS records repeated launches in `com.apple.dock` `recent-apps`.
- The managed Chrome lifecycle can be correct while Dock recents remain visually noisy.

The fix must not disable shared Chrome MCP, must not kill the user's normal Chrome, and must not clear unrelated recent apps.

## File Structure

- Create `scripts/macos-dock-chrome-recents.py`
  - Responsibility: pure plist read/filter/write logic plus a CLI for removing Chrome entries from Dock recents.
- Create `scripts/cleanup-chrome-dock-recents.sh`
  - Responsibility: safe shell entrypoint for macOS-only cleanup, defaulting to the user's Dock plist and restarting Dock only when the Python tool changed the plist.
- Create `scripts/test_macos_dock_chrome_recents.py`
  - Responsibility: pytest coverage for plist filtering, dry-run behavior, non-Chrome preservation, missing plist behavior, and wrapper behavior through controlled temp files.
- Modify `scripts/stop-chrome-agent.sh`
  - Responsibility: optionally invoke the cleanup wrapper after stopping managed Chrome when `CHROME_AGENT_CLEAN_DOCK_RECENTS=1`.
- Modify `scripts/mcp-clean.sh`
  - Responsibility: optionally invoke the cleanup wrapper during explicit MCP cleanup when `CHROME_AGENT_CLEAN_DOCK_RECENTS=1`.
- Modify `Makefile`
  - Responsibility: expose `make chrome-dock-clean` for manual operator cleanup and mention it in `help`.
- Modify `docs/workspace/chrome-devtools.md`
  - Responsibility: document why Dock recents can show duplicate Chrome icons and how to clean them.

---

### Task 1: Add the plist cleaner

**Files:**
- Create: `scripts/macos-dock-chrome-recents.py`
- Create: `scripts/test_macos_dock_chrome_recents.py`

- [ ] **Step 1: Write failing tests for Chrome-only recent-app filtering**

Create `scripts/test_macos_dock_chrome_recents.py` with this content:

```python
from __future__ import annotations

import plistlib
import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "macos-dock-chrome-recents.py"


def _chrome_tile(guid: int) -> dict[str, object]:
    return {
        "GUID": guid,
        "tile-data": {
            "bundle-identifier": "com.google.Chrome",
            "file-label": "Google Chrome",
            "file-data": {
                "_CFURLString": "file:///Applications/Google%20Chrome.app/",
                "_CFURLStringType": 15,
            },
        },
        "tile-type": "file-tile",
    }


def _safari_tile(guid: int) -> dict[str, object]:
    return {
        "GUID": guid,
        "tile-data": {
            "bundle-identifier": "com.apple.Safari",
            "file-label": "Safari",
            "file-data": {
                "_CFURLString": "file:///Applications/Safari.app/",
                "_CFURLStringType": 15,
            },
        },
        "tile-type": "file-tile",
    }


def _write_plist(path: Path, data: dict[str, object]) -> None:
    with path.open("wb") as handle:
        plistlib.dump(data, handle)


def _read_plist(path: Path) -> dict[str, object]:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def _run_tool(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCRIPT_PATH), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def test_clean_removes_only_chrome_recent_apps(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_plist(
        dock_plist,
        {
            "persistent-apps": [_chrome_tile(1)],
            "recent-apps": [_chrome_tile(2), _safari_tile(3), _chrome_tile(4)],
        },
    )

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=2\ndock_restarted=0\n"
    data = _read_plist(dock_plist)
    assert data["persistent-apps"] == [_chrome_tile(1)]
    assert data["recent-apps"] == [_safari_tile(3)]


def test_clean_dry_run_reports_count_without_writing(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    original = {
        "persistent-apps": [],
        "recent-apps": [_chrome_tile(10), _safari_tile(11), _chrome_tile(12)],
    }
    _write_plist(dock_plist, original)

    result = _run_tool("--plist", str(dock_plist), "--dry-run")

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=2\ndock_restarted=0\n"
    assert _read_plist(dock_plist) == original


def test_clean_handles_missing_recent_apps(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    original = {"persistent-apps": [_chrome_tile(20)]}
    _write_plist(dock_plist, original)

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=0\ndock_restarted=0\n"
    assert _read_plist(dock_plist) == original


def test_clean_missing_plist_is_noop(tmp_path: Path) -> None:
    dock_plist = tmp_path / "missing.plist"

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=0\ndock_restarted=0\n"
    assert not dock_plist.exists()
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py
```

Expected: fail because `scripts/macos-dock-chrome-recents.py` does not exist. The failure should include:

```text
can't open file
```

- [ ] **Step 3: Create the Python cleaner**

Create `scripts/macos-dock-chrome-recents.py` with this content:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_BUNDLE_ID = "com.google.Chrome"
DEFAULT_DOCK_PLIST = Path.home() / "Library" / "Preferences" / "com.apple.dock.plist"


def _tile_bundle_id(item: object) -> str:
    if not isinstance(item, dict):
        return ""
    tile_data = item.get("tile-data")
    if not isinstance(tile_data, dict):
        return ""
    bundle_id = tile_data.get("bundle-identifier")
    if not isinstance(bundle_id, str):
        return ""
    return bundle_id.strip()


def remove_recent_apps_for_bundle(
    dock_data: dict[str, Any],
    *,
    bundle_id: str = DEFAULT_BUNDLE_ID,
) -> tuple[dict[str, Any], int]:
    recent_apps = dock_data.get("recent-apps")
    if not isinstance(recent_apps, list):
        return dock_data, 0

    kept_recent_apps = [
        item for item in recent_apps if _tile_bundle_id(item) != bundle_id
    ]
    removed_count = len(recent_apps) - len(kept_recent_apps)
    if removed_count == 0:
        return dock_data, 0

    updated = dict(dock_data)
    updated["recent-apps"] = kept_recent_apps
    return updated, removed_count


def clean_dock_plist(
    dock_plist: Path,
    *,
    bundle_id: str = DEFAULT_BUNDLE_ID,
    dry_run: bool = False,
) -> int:
    if not dock_plist.exists():
        return 0

    with dock_plist.open("rb") as handle:
        dock_data = plistlib.load(handle)

    if not isinstance(dock_data, dict):
        raise ValueError(f"Dock plist root is not a dictionary: {dock_plist}")

    updated, removed_count = remove_recent_apps_for_bundle(
        dock_data,
        bundle_id=bundle_id,
    )
    if removed_count == 0 or dry_run:
        return removed_count

    with dock_plist.open("wb") as handle:
        plistlib.dump(updated, handle)
    return removed_count


def restart_dock_if_needed(removed_count: int, *, restart_dock: bool) -> bool:
    if removed_count <= 0 or not restart_dock:
        return False
    if platform.system() != "Darwin":
        return False
    subprocess.run(["killall", "Dock"], check=False)
    return True


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove Google Chrome entries from macOS Dock recent apps.",
    )
    parser.add_argument(
        "--plist",
        type=Path,
        default=DEFAULT_DOCK_PLIST,
        help="Dock plist path. Defaults to the current user's Dock preferences.",
    )
    parser.add_argument(
        "--bundle-id",
        default=DEFAULT_BUNDLE_ID,
        help="Bundle identifier to remove from recent-apps.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report removable entries without writing the plist.",
    )
    parser.add_argument(
        "--restart-dock",
        action="store_true",
        help="Restart Dock when entries were removed.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    removed_count = clean_dock_plist(
        args.plist.expanduser(),
        bundle_id=args.bundle_id,
        dry_run=args.dry_run,
    )
    dock_restarted = restart_dock_if_needed(
        removed_count,
        restart_dock=args.restart_dock and not args.dry_run,
    )
    print(f"chrome_recent_apps_removed={removed_count}")
    print(f"dock_restarted={1 if dock_restarted else 0}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
```

- [ ] **Step 4: Make the cleaner executable**

Run:

```bash
chmod +x scripts/macos-dock-chrome-recents.py
```

Expected: command exits `0`.

- [ ] **Step 5: Run the Python tests**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py
```

Expected:

```text
4 passed
```

- [ ] **Step 6: Commit Task 1**

Run:

```bash
git add scripts/macos-dock-chrome-recents.py scripts/test_macos_dock_chrome_recents.py
git commit -m "feat: add Chrome Dock recents cleaner"
```

Expected: commit succeeds.

---

### Task 2: Add the shell entrypoint

**Files:**
- Create: `scripts/cleanup-chrome-dock-recents.sh`
- Modify: `scripts/test_macos_dock_chrome_recents.py`

- [ ] **Step 1: Add failing wrapper tests**

Append these tests to `scripts/test_macos_dock_chrome_recents.py`:

```python

WRAPPER_PATH = Path(__file__).resolve().parent / "cleanup-chrome-dock-recents.sh"


def _run_wrapper(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(WRAPPER_PATH), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def test_wrapper_passes_custom_plist_without_restarting_dock(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_plist(
        dock_plist,
        {
            "persistent-apps": [],
            "recent-apps": [_chrome_tile(30), _safari_tile(31)],
        },
    )

    result = _run_wrapper("--plist", str(dock_plist), "--no-restart-dock")

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=1\ndock_restarted=0\n"
    assert _read_plist(dock_plist)["recent-apps"] == [_safari_tile(31)]


def test_wrapper_dry_run_keeps_custom_plist(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    original = {
        "persistent-apps": [],
        "recent-apps": [_chrome_tile(40), _safari_tile(41)],
    }
    _write_plist(dock_plist, original)

    result = _run_wrapper("--plist", str(dock_plist), "--dry-run", "--no-restart-dock")

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=1\ndock_restarted=0\n"
    assert _read_plist(dock_plist) == original
```

- [ ] **Step 2: Run the wrapper tests to verify they fail**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py -k wrapper
```

Expected: fail because `scripts/cleanup-chrome-dock-recents.sh` does not exist. The failure should include:

```text
No such file or directory
```

- [ ] **Step 3: Create the shell wrapper**

Create `scripts/cleanup-chrome-dock-recents.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
DOCK_PLIST="${CHROME_DOCK_PLIST:-${HOME}/Library/Preferences/com.apple.dock.plist}"
DRY_RUN=0
RESTART_DOCK=1

usage() {
  cat <<'EOF'
Usage:
  cleanup-chrome-dock-recents.sh [--dry-run] [--no-restart-dock] [--plist PATH]

Options:
  --dry-run          Report Chrome Dock recent-app entries without writing.
  --no-restart-dock  Do not run killall Dock after removing entries.
  --plist PATH       Use a custom Dock plist path, primarily for tests.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-restart-dock)
      RESTART_DOCK=0
      ;;
    --plist)
      if [[ "$#" -lt 2 ]]; then
        echo "[chrome-dock-clean] ERROR: --plist requires a path." >&2
        exit 1
      fi
      DOCK_PLIST="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[chrome-dock-clean] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

args=("--plist" "${DOCK_PLIST}")
if [[ "$DRY_RUN" == "1" ]]; then
  args+=("--dry-run")
fi
if [[ "$RESTART_DOCK" == "1" ]]; then
  args+=("--restart-dock")
fi

"${PYTHON_BIN}" "${ROOT}/scripts/macos-dock-chrome-recents.py" "${args[@]}"
```

- [ ] **Step 4: Make the wrapper executable**

Run:

```bash
chmod +x scripts/cleanup-chrome-dock-recents.sh
```

Expected: command exits `0`.

- [ ] **Step 5: Run the wrapper tests**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py -k wrapper
```

Expected:

```text
2 passed
```

- [ ] **Step 6: Run the full Dock cleaner test file**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py
```

Expected:

```text
6 passed
```

- [ ] **Step 7: Commit Task 2**

Run:

```bash
git add scripts/cleanup-chrome-dock-recents.sh scripts/test_macos_dock_chrome_recents.py
git commit -m "feat: wrap Chrome Dock recents cleanup"
```

Expected: commit succeeds.

---

### Task 3: Wire cleanup into managed Chrome shutdown and MCP cleanup

**Files:**
- Modify: `scripts/stop-chrome-agent.sh`
- Modify: `scripts/mcp-clean.sh`
- Modify: `scripts/test_macos_dock_chrome_recents.py`

- [ ] **Step 1: Add failing integration tests for opt-in cleanup wiring**

Append these tests to `scripts/test_macos_dock_chrome_recents.py`:

```python

STOP_CHROME_AGENT_PATH = Path(__file__).resolve().parent / "stop-chrome-agent.sh"
MCP_CLEAN_PATH = Path(__file__).resolve().parent / "mcp-clean.sh"


def test_stop_chrome_agent_contains_opt_in_dock_cleanup_hook() -> None:
    source = STOP_CHROME_AGENT_PATH.read_text()
    assert "cleanup_chrome_dock_recents_if_requested" in source
    assert '[[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]]' in source
    assert '"${ROOT}/scripts/cleanup-chrome-dock-recents.sh"' in source


def test_mcp_clean_contains_opt_in_dock_cleanup_hook() -> None:
    source = MCP_CLEAN_PATH.read_text()
    assert "cleanup_chrome_dock_recents_if_requested" in source
    assert '[[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]]' in source
    assert '"${ROOT}/scripts/cleanup-chrome-dock-recents.sh"' in source
```

- [ ] **Step 2: Run the new wiring tests to verify they fail**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py -k "opt_in_dock_cleanup_hook"
```

Expected: fail because neither script contains the cleanup hook yet.

- [ ] **Step 3: Patch `scripts/stop-chrome-agent.sh`**

Add this function after the variable block near the top of `scripts/stop-chrome-agent.sh`, after `STOP_ALL="${CHROME_AGENT_STOP_ALL:-0}"`:

```bash
cleanup_chrome_dock_recents_if_requested() {
  [[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]] || return 0
  [[ "$(uname)" == "Darwin" ]] || return 0
  bash "${ROOT}/scripts/cleanup-chrome-dock-recents.sh" >&2 || true
}
```

Then add this call before each successful script exit path:

```bash
cleanup_chrome_dock_recents_if_requested
```

The exact placements are:

- In the `STOP_ALL=1` branch, immediately before `exit 0`.
- At the end of the file, immediately after `stop_by_port "$DEBUG_PORT"`.

The final bottom of the file should look like this:

```bash
if [[ "$STOP_ALL" == "1" ]]; then
  shopt -s nullglob
  pidfiles=("${LOG_DIR}"/chrome-agent-*.pid)
  shopt -u nullglob

  if [[ "${#pidfiles[@]}" -eq 0 ]]; then
    echo "[chrome-agent] No managed chrome-agent pidfiles found."
    if [[ -f "$LEGACY_PIDFILE" ]]; then
      stop_by_port "9222"
    fi
    cleanup_chrome_dock_recents_if_requested
    exit 0
  fi

  echo "[chrome-agent] Stopping all managed Chrome agent instances..."
  for pidfile in "${pidfiles[@]}"; do
    port="${pidfile##*/chrome-agent-}"
    port="${port%.pid}"
    stop_by_port "$port"
  done
  if [[ -f "$LEGACY_PIDFILE" ]]; then
    stop_by_port "9222"
  fi
  cleanup_chrome_dock_recents_if_requested
  exit 0
fi

stop_by_port "$DEBUG_PORT"
cleanup_chrome_dock_recents_if_requested
```

- [ ] **Step 4: Patch `scripts/mcp-clean.sh`**

Add this function after `chrome_clean_output=""`:

```bash
cleanup_chrome_dock_recents_if_requested() {
  [[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]] || return 0
  [[ "$(uname)" == "Darwin" ]] || return 0
  bash "${ROOT}/scripts/cleanup-chrome-dock-recents.sh" 2>&1 || true
}
```

Then update `emit_cleanup_results()` so it includes Dock cleanup output only when requested:

```bash
emit_cleanup_results() {
  local dock_clean_output=""

  echo "[mcp-clean] Stale shared wrapper trees killed: ${shared_wrapper_killed}"
  echo "[mcp-clean] Orphan shared clients killed: ${shared_client_killed}"
  echo "${reaper_output}"
  echo "${chrome_clean_output}"

  dock_clean_output="$(cleanup_chrome_dock_recents_if_requested)"
  if [[ -n "$dock_clean_output" ]]; then
    echo "${dock_clean_output}"
  fi
}
```

- [ ] **Step 5: Run the wiring tests**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py -k "opt_in_dock_cleanup_hook"
```

Expected:

```text
2 passed
```

- [ ] **Step 6: Run syntax checks for changed shell scripts**

Run:

```bash
bash -n scripts/stop-chrome-agent.sh scripts/mcp-clean.sh scripts/cleanup-chrome-dock-recents.sh
```

Expected: command exits `0`.

- [ ] **Step 7: Run the full Dock cleaner test file**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py
```

Expected:

```text
8 passed
```

- [ ] **Step 8: Commit Task 3**

Run:

```bash
git add scripts/stop-chrome-agent.sh scripts/mcp-clean.sh scripts/test_macos_dock_chrome_recents.py
git commit -m "feat: opt in Chrome Dock cleanup during MCP shutdown"
```

Expected: commit succeeds.

---

### Task 4: Expose manual cleanup through Makefile and docs

**Files:**
- Modify: `Makefile`
- Modify: `docs/workspace/chrome-devtools.md`
- Modify: `scripts/test_macos_dock_chrome_recents.py`

- [ ] **Step 1: Add failing tests for Makefile and docs coverage**

Append these tests to `scripts/test_macos_dock_chrome_recents.py`:

```python

MAKEFILE_PATH = Path(__file__).resolve().parents[1] / "Makefile"
CHROME_DOCS_PATH = (
    Path(__file__).resolve().parents[1] / "docs" / "workspace" / "chrome-devtools.md"
)


def test_makefile_exposes_chrome_dock_clean_target() -> None:
    source = MAKEFILE_PATH.read_text()
    assert "chrome-dock-clean" in source
    assert "scripts/cleanup-chrome-dock-recents.sh" in source


def test_chrome_devtools_docs_explain_dock_cleanup() -> None:
    source = CHROME_DOCS_PATH.read_text()
    assert "Chrome Dock Recents" in source
    assert "make chrome-dock-clean" in source
    assert "CHROME_AGENT_CLEAN_DOCK_RECENTS=1 make mcp-clean" in source
```

- [ ] **Step 2: Run the docs/Makefile tests to verify they fail**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py -k "makefile_exposes or docs_explain"
```

Expected: fail because the target and docs are not present yet.

- [ ] **Step 3: Patch `Makefile`**

In the `.PHONY` block, add `chrome-dock-clean` next to the other Chrome/MCP targets:

```make
	down chrome-devtools-mcp-status chrome-devtools-mcp-clean-stale chrome-devtools-mcp-stop-conflicts \
	mcp-clean chrome-dock-clean \
```

Add this target after `mcp-clean`:

```make
chrome-dock-clean:
	@bash scripts/cleanup-chrome-dock-recents.sh
```

Add this help line near the existing MCP/Chrome help lines:

```make
	@echo "  make chrome-dock-clean - remove Google Chrome duplicate entries from macOS Dock recents"
```

- [ ] **Step 4: Patch `docs/workspace/chrome-devtools.md`**

Append this section near the Chrome DevTools operational guidance:

```markdown
## Chrome Dock Recents

TRR browser automation can launch `/Applications/Google Chrome.app` for managed Chrome sessions. On macOS, repeated launches can leave duplicate Google Chrome icons in the Dock recent-apps area even when the managed browser process was stopped correctly.

Use this command to remove only Google Chrome entries from Dock recents while preserving pinned Dock apps and unrelated recent apps:

```bash
make chrome-dock-clean
```

For explicit MCP cleanup runs where Dock recents should be cleaned at the same time, opt in with:

```bash
CHROME_AGENT_CLEAN_DOCK_RECENTS=1 make mcp-clean
```

The cleanup is macOS-only and removes only `com.google.Chrome` entries from the Dock `recent-apps` list.
```

- [ ] **Step 5: Run the docs/Makefile tests**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py -k "makefile_exposes or docs_explain"
```

Expected:

```text
2 passed
```

- [ ] **Step 6: Validate the manual cleanup command in dry-run mode**

Run:

```bash
bash scripts/cleanup-chrome-dock-recents.sh --dry-run --no-restart-dock
```

Expected output shape:

```text
chrome_recent_apps_removed=<number>
dock_restarted=0
```

The `<number>` is environment-dependent. On the machine that produced the screenshot, expect a positive value until the real cleanup runs.

- [ ] **Step 7: Run the full focused test suite**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py
bash -n scripts/stop-chrome-agent.sh scripts/mcp-clean.sh scripts/cleanup-chrome-dock-recents.sh
```

Expected:

```text
10 passed
```

and the `bash -n` command exits `0`.

- [ ] **Step 8: Commit Task 4**

Run:

```bash
git add Makefile docs/workspace/chrome-devtools.md scripts/test_macos_dock_chrome_recents.py
git commit -m "docs: document Chrome Dock recents cleanup"
```

Expected: commit succeeds.

---

### Task 5: Final verification on the real machine

**Files:**
- No code changes unless verification reveals a regression.

- [ ] **Step 1: Confirm current Dock Chrome recent-app count without writing**

Run:

```bash
bash scripts/cleanup-chrome-dock-recents.sh --dry-run --no-restart-dock
```

Expected output shape:

```text
chrome_recent_apps_removed=<number>
dock_restarted=0
```

If `<number>` is `0`, the Dock was already clean and the remaining verification should still pass.

- [ ] **Step 2: Run the real manual cleanup**

Run:

```bash
make chrome-dock-clean
```

Expected output shape:

```text
chrome_recent_apps_removed=<number>
dock_restarted=<0-or-1>
```

On macOS with duplicate Chrome Dock recents, expect `dock_restarted=1`.

- [ ] **Step 3: Confirm Chrome recents are gone**

Run:

```bash
bash scripts/cleanup-chrome-dock-recents.sh --dry-run --no-restart-dock
```

Expected:

```text
chrome_recent_apps_removed=0
dock_restarted=0
```

- [ ] **Step 4: Confirm managed Chrome still works**

Run:

```bash
bash scripts/chrome-agent-status.sh
```

Expected output includes either an existing reachable managed Chrome, such as:

```text
9422   running       <pid>    yes       1        /Users/thomashulihan/.chrome-profiles/codex-agent
```

or no managed Chrome if it was intentionally stopped:

```text
[chrome-agent] No managed Chrome instances found.
```

Both are acceptable. The cleanup must not kill the user's normal Chrome unless `stop-chrome-agent.sh` was explicitly invoked for a managed Chrome port.

- [ ] **Step 5: Run all focused tests and shell syntax checks**

Run:

```bash
python3 -m pytest -q scripts/test_macos_dock_chrome_recents.py
bash -n scripts/stop-chrome-agent.sh scripts/mcp-clean.sh scripts/cleanup-chrome-dock-recents.sh scripts/chrome-agent.sh scripts/ensure-managed-chrome.sh
```

Expected:

```text
10 passed
```

and the `bash -n` command exits `0`.

- [ ] **Step 6: Commit final verification note if docs changed during verification**

If verification required no code or doc edits, do not create a commit. If verification required a docs correction, run:

```bash
git add docs/workspace/chrome-devtools.md
git commit -m "docs: clarify Chrome Dock cleanup verification"
```

Expected: commit succeeds only when a docs correction was made.

---

## Self-Review

Spec coverage:
- Explains why TRR opens Chrome in the Dock: covered by docs and the final verification model.
- Fixes leftover Dock icons without disabling shared Chrome: covered by the Chrome-only plist cleaner and `make chrome-dock-clean`.
- Avoids surprising macOS mutations: covered by the opt-in `CHROME_AGENT_CLEAN_DOCK_RECENTS=1` hooks.
- Preserves user Chrome and unrelated Dock recents: covered by tests that preserve pinned Chrome and Safari recent-app entries.

Placeholder scan:
- No step uses vague implementation text. Each code change includes the exact content to add.

Type and command consistency:
- Python CLI output is consistently `chrome_recent_apps_removed=<number>` and `dock_restarted=<0-or-1>`.
- The wrapper, Makefile, docs, and tests all reference `scripts/cleanup-chrome-dock-recents.sh`.
- The opt-in environment variable is consistently `CHROME_AGENT_CLEAN_DOCK_RECENTS=1`.
