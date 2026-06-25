from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "ensure-managed-chrome.sh"


def _run_ensure(*, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    merged_env.update(env)
    return subprocess.run(
        ["/bin/bash", str(SCRIPT_PATH)],
        cwd=ROOT,
        env=merged_env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_default_mode_is_shared_and_can_skip_browser_boot() -> None:
    env = {
        "CODEX_CHROME_MODE": "",
        "CODEX_CHROME_SKIP_BROWSER_BOOT": "1",
        "CODEX_CHROME_SHARED_PORT": "9422",
    }

    result = _run_ensure(env=env)

    assert result.returncode == 0, result.stderr
    assert "CODEX_CHROME_MODE=isolated requires CODEX_CHROME_PORT" not in result.stderr


def test_explicit_isolated_mode_still_requires_port() -> None:
    result = _run_ensure(
        env={
            "CODEX_CHROME_MODE": "isolated",
            "CODEX_CHROME_SKIP_BROWSER_BOOT": "1",
        }
    )

    assert result.returncode == 1
    assert "CODEX_CHROME_MODE=isolated requires CODEX_CHROME_PORT" in result.stderr
