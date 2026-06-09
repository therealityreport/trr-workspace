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


def test_validate_allows_user_level_model_reasoning_effort() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()

        bootstrap = _run_sync("bootstrap", home)
        assert bootstrap.returncode == 0, bootstrap.stderr

        config = codex_home / "config.toml"
        config_text = config.read_text(encoding="utf-8")
        first_table = config_text.index("\n[")
        config.write_text(
            config_text[:first_table] + '\nmodel_reasoning_effort = "high"\n' + config_text[first_table:],
            encoding="utf-8",
        )

        result = _run_sync("validate", home)

    assert result.returncode == 0, result.stderr
    assert "Validation OK" in result.stdout


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


def test_validate_allows_disabled_named_skill_config() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()

        bootstrap = _run_sync("bootstrap", home)
        assert bootstrap.returncode == 0, bootstrap.stderr

        config = codex_home / "config.toml"
        with config.open("a", encoding="utf-8") as handle:
            handle.write(
                '\n[skills]\n'
                'config = [{ name = "andrej-karpathy-skills:karpathy-guidelines", enabled = false }]\n'
            )

        result = _run_sync("validate", home)

    assert result.returncode == 0, result.stderr
    assert "Validation OK" in result.stdout


def test_validate_rejects_raw_context7_mcp_config() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()

        bootstrap = _run_sync("bootstrap", home)
        assert bootstrap.returncode == 0, bootstrap.stderr

        config = codex_home / "config.toml"
        config_text = config.read_text(encoding="utf-8")
        wrapper = f'{home}/.codex/plugins/context7/scripts/start-context7-mcp.sh'
        raw = 'command = "npx"\nargs = ["-y", "@upstash/context7-mcp"]'
        config.write_text(config_text.replace(f'command = "{wrapper}"', raw), encoding="utf-8")

        result = _run_sync("validate", home)

    assert result.returncode == 1
    assert "user [mcp_servers.context7] expected command" in result.stderr
    assert "user [mcp_servers.context7] expected args=[]" not in result.stderr


def test_bootstrap_repairs_raw_context7_mcp_config() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()

        bootstrap = _run_sync("bootstrap", home)
        assert bootstrap.returncode == 0, bootstrap.stderr

        config = codex_home / "config.toml"
        config_text = config.read_text(encoding="utf-8")
        wrapper = f'{home}/.codex/plugins/context7/scripts/start-context7-mcp.sh'
        raw = 'command = "npx"\nargs = ["-y", "@upstash/context7-mcp"]'
        config.write_text(config_text.replace(f'command = "{wrapper}"', raw), encoding="utf-8")

        repair = _run_sync("bootstrap", home)
        repaired_text = config.read_text(encoding="utf-8")

    assert repair.returncode == 0, repair.stderr
    assert f'command = "{wrapper}"' in repaired_text
    assert '@upstash/context7-mcp' not in repaired_text


def test_bootstrap_repairs_invalid_service_tier() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        codex_home = home / ".codex"
        codex_home.mkdir()

        bootstrap = _run_sync("bootstrap", home)
        assert bootstrap.returncode == 0, bootstrap.stderr

        config = codex_home / "config.toml"
        config_text = config.read_text(encoding="utf-8")
        first_table = config_text.index("\n[")
        config.write_text(
            config_text[:first_table] + '\nservice_tier = "default"\n' + config_text[first_table:],
            encoding="utf-8",
        )

        repair = _run_sync("bootstrap", home)
        repaired_text = config.read_text(encoding="utf-8")

    assert repair.returncode == 0, repair.stderr
    assert 'service_tier = "fast"' in repaired_text
    assert 'service_tier = "default"' not in repaired_text
