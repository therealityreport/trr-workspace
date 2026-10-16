from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize("preflight_status", [0, 17])
def test_hybrid_starts_only_after_successful_preflight(tmp_path: Path, preflight_status: int) -> None:
    (tmp_path / "Makefile").write_text((ROOT / "Makefile").read_text(encoding="utf-8"), encoding="utf-8")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    bash = bin_dir / "bash"
    bash.write_text('''#!/bin/sh
case "$1" in
  scripts/preflight.sh) echo preflight >> "$STARTUP_EVENTS"; exit "$PREFLIGHT_STATUS" ;;
  scripts/dev-workspace.sh) echo startup >> "$STARTUP_EVENTS"; exit 0 ;;
  *) echo unexpected-command >&2; exit 99 ;;
esac
''', encoding="utf-8")
    bash.chmod(0o755)
    events = tmp_path / "events"
    result = subprocess.run(
        ["make", "--no-print-directory", "dev-hybrid"], cwd=tmp_path,
        env={**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "PROFILE": "",
             "STARTUP_EVENTS": str(events), "PREFLIGHT_STATUS": str(preflight_status)},
        capture_output=True, text=True, check=False,
    )
    assert (result.returncode == 0) == (preflight_status == 0), result.stderr
    assert events.read_text(encoding="utf-8").splitlines() == (["preflight", "startup"] if preflight_status == 0 else ["preflight"])
