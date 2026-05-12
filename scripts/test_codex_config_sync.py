from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "codex-config-sync.sh"


def _run_sync(action: str, home: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["CODEX_HOME"] = str(home / ".codex")
    env["CODEX_CONFIG_FILE"] = str(home / ".codex" / "config.toml")
    return subprocess.run(
        ["/bin/bash", str(SCRIPT), action],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_validate_rejects_user_level_model_reasoning_effort() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()
        (codex_home / "AGENTS.md").write_text("# User Codex preferences\n", encoding="utf-8")
        (codex_home / "config.toml").write_text(
            f"""
model = "gpt-5.5"
personality = "pragmatic"
approval_policy = "never"
sandbox_mode = "danger-full-access"
web_search = "cached"
project_doc_max_bytes = 65536
project_doc_fallback_filenames = []
model_reasoning_effort = "high"

[projects."{ROOT}"]
trust_level = "trusted"
""".strip()
            + "\n",
            encoding="utf-8",
        )

        result = _run_sync("validate", home)

    assert result.returncode == 1
    assert "user config must omit top-level model_reasoning_effort" in result.stderr


def test_bootstrap_removes_top_level_model_reasoning_effort() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()
        config = codex_home / "config.toml"
        config.write_text(
            """
model = "gpt-5.5"
personality = "pragmatic"
approval_policy = "never"
sandbox_mode = "danger-full-access"
model_reasoning_effort = "high"

[features]
memories = true
""".strip()
            + "\n",
            encoding="utf-8",
        )

        result = _run_sync("bootstrap", home)
        config_text = config.read_text(encoding="utf-8")

    assert result.returncode == 0, result.stderr
    assert "Bootstrapped user config" in result.stdout
    assert "model_reasoning_effort" not in config_text
    assert "memories = true" in config_text
    assert f'[projects."{ROOT}"]' in config_text
