from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCTOR = ROOT / "scripts" / "doctor.sh"
REGISTRY = ROOT / "scripts" / "lib" / "doctor-plugin-registry.sh"


def test_doctor_plugin_repair_registry_declares_entries() -> None:
    text = REGISTRY.read_text(encoding="utf-8")
    doctor_text = DOCTOR.read_text(encoding="utf-8")

    assert "DOCTOR_PLUGIN_REPAIR_REGISTRY=(" in text
    assert "doctor_run_plugin_repair_entry()" in text
    assert "doctor_plugin_registry_run()" in text
    assert "doctor_plugin_registry_json()" in text
    assert 'source "$ROOT/scripts/lib/doctor-plugin-registry.sh"' in doctor_text
    assert 'doctor_plugin_registry_json "$WORKSPACE_DOCTOR_PLUGIN_REPAIR"' in doctor_text


def test_doctor_plugin_repair_entries_have_check_and_repair_functions() -> None:
    text = REGISTRY.read_text(encoding="utf-8")

    for plugin in ("context7", "browser", "supabase", "modal", "scrapling", "vercel", "decodo"):
        assert f"  {plugin}\n" in text
        assert f"doctor_plugin_{plugin}_check()" in text


def test_repairable_doctor_plugin_entries_have_repair_functions() -> None:
    text = REGISTRY.read_text(encoding="utf-8")

    for plugin in ("context7", "browser", "supabase", "modal"):
        assert f"doctor_plugin_{plugin}_repair()" in text


def test_doctor_plugin_registry_declares_live_mcp_mapping() -> None:
    text = REGISTRY.read_text(encoding="utf-8")

    expected = {
        "context7": "context7",
        "browser": "chrome-devtools",
        "supabase": "supabase",
        "modal": "modal-ops",
        "scrapling": "ScraplingServer",
        "decodo": "decodo",
    }
    for plugin, mcp_name in expected.items():
        assert f"{plugin}) echo \"{mcp_name}\"" in text


def test_doctor_plugin_registry_selects_cache_build_semantically(tmp_path: Path) -> None:
    assert sys.version_info >= (3, 11), "Python 3.11+ is required by the registry's tomllib parser"
    runtime_python = sys.executable
    config = tmp_path / "config.toml"
    config.write_text(
        '[plugins."scrapling@local-plugins"]\nenabled = true\n',
        encoding="utf-8",
    )
    cache_root = tmp_path / "scrapling"
    for build in ("0.4.9+codex.20260801", "0.4.12+codex.20260803"):
        manifest = cache_root / build / ".codex-plugin" / "plugin.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text("{}\n", encoding="utf-8")

    command = (
        f'MCP_RUNTIME_PYTHON_BIN="{runtime_python}"; '
        f'CODEX_CONFIG_FILE="{config}"; '
        f'source "{REGISTRY}"; '
        f'doctor_plugin_enabled_status "scrapling@local-plugins" "{cache_root}/*/.codex-plugin/plugin.json"'
    )
    result = subprocess.run(
        ["bash", "-lc", command],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    expected = cache_root / "0.4.12+codex.20260803" / ".codex-plugin" / "plugin.json"
    assert f"manifest={expected}" in result.stdout


def test_trr_social_readiness_uses_stable_scrapling_local_pointer() -> None:
    readiness = (ROOT / "scripts" / "trr-social-readiness.sh").read_text(encoding="utf-8")
    expected_pointer = (
        'SCRAPLING_PLUGIN_ROOT=${SCRAPLING_PLUGIN_ROOT:-"$HOME/.codex/plugins/cache/local-plugins/scrapling/local"}'
    )

    assert expected_pointer in readiness
    assert "codex-scrapling-readiness" in readiness


def test_browser_doctor_status_check_is_time_bounded() -> None:
    text = REGISTRY.read_text(encoding="utf-8")
    doctor_text = DOCTOR.read_text(encoding="utf-8")
    preflight_text = (ROOT / "scripts" / "preflight.sh").read_text(encoding="utf-8")

    assert "DOCTOR_COMMAND_TIMEOUT_SECONDS" in doctor_text
    assert "doctor_tool_version" in doctor_text
    assert "DOCTOR_PLUGIN_COMMAND_TIMEOUT_SECONDS" in text
    assert "doctor_plugin_timed_command_output" in text
    assert "status check timed out after ${DOCTOR_PLUGIN_COMMAND_TIMEOUT_SECONDS}s" in text
    assert "make chrome-repair" in text
    assert "WORKSPACE_PREFLIGHT_DOCTOR_TIMEOUT_SECONDS" in preflight_text
    assert "scripts/run-with-timeout.py" in preflight_text


def test_preflight_reaps_abandoned_mcp_helpers_before_doctor() -> None:
    preflight_text = (ROOT / "scripts" / "preflight.sh").read_text(encoding="utf-8")

    reap_call = 'run_preflight_phase "mcp-orphan-reap"'
    doctor_call = 'run_preflight_phase "doctor"'
    assert reap_call in preflight_text
    assert preflight_text.index(reap_call) < preflight_text.index(doctor_call)
    assert 'WORKSPACE_PREFLIGHT_MCP_REAP:-1' in preflight_text
    assert 'MCP_REAPER_UNTRACKED_MIN_AGE_SEC="${WORKSPACE_PREFLIGHT_MCP_STALE_AGE_SEC:-3600}"' in preflight_text
    assert 'codex-mcp-session-reaper.sh" reap' in preflight_text


def test_preflight_repairs_context7_cache_without_reloading_connectors() -> None:
    preflight_text = (ROOT / "scripts" / "preflight.sh").read_text(encoding="utf-8")

    repair_call = 'run_preflight_phase "context7-cache-repair"'
    doctor_call = 'run_preflight_phase "doctor"'
    assert repair_call in preflight_text
    assert preflight_text.index(repair_call) < preflight_text.index(doctor_call)
    assert 'node "$context7_repair_script"' in preflight_text
    assert '--reload' not in preflight_text[preflight_text.index(repair_call):preflight_text.index(doctor_call)]


def test_workspace_startup_reaper_uses_stale_age_floor() -> None:
    workspace_text = (ROOT / "scripts" / "dev-workspace.sh").read_text(encoding="utf-8")

    assert 'MCP_REAPER_UNTRACKED_MIN_AGE_SEC="${WORKSPACE_MCP_STALE_AGE_SEC:-3600}"' in workspace_text
    assert 'bash "$ROOT/scripts/codex-mcp-session-reaper.sh" reap' in workspace_text


def test_doctor_pnpm_version_check_kills_stuck_process_group(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    child_pid_file = tmp_path / "pnpm-child.pid"
    fake_node = fake_bin / "node"
    fake_node.write_text(
        """#!/usr/bin/env bash
echo "v24.0.0"
""",
        encoding="utf-8",
    )
    fake_node.chmod(0o755)
    fake_pnpm = fake_bin / "pnpm"
    fake_pnpm.write_text(
        f"""#!/usr/bin/env bash
(sleep 30) &
echo "$!" > "{child_pid_file}"
wait
""",
        encoding="utf-8",
    )
    fake_pnpm.chmod(0o755)

    started = time.monotonic()
    result = subprocess.run(
        ["bash", str(DOCTOR)],
        cwd=ROOT,
        env={
            **dict(os.environ),
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
            "NVM_DIR": str(tmp_path / "missing-nvm"),
            "DOCTOR_COMMAND_TIMEOUT_SECONDS": "1",
            "DOCTOR_PLUGIN_COMMAND_TIMEOUT_SECONDS": "1",
        },
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )

    assert time.monotonic() - started < 10
    if (ROOT / "TRR-Backend").is_dir():
        assert result.returncode == 0
    else:
        # Detached root-only candidates intentionally do not contain the nested
        # backend path that the Modal doctor validates. Keep this timeout test
        # focused on reaping the stuck pnpm process in that isolated layout.
        assert result.returncode in {0, 1}
        if result.returncode == 1:
            assert "modal needs repair: modal command mismatch:" in result.stderr
    assert "pnpm: timeout after 1s" in result.stdout
    assert "pnpm version check timed out after 1s" in result.stderr
    child_pid = int(child_pid_file.read_text(encoding="utf-8").strip())
    assert subprocess.run(["kill", "-0", str(child_pid)], check=False).returncode != 0


def test_status_json_includes_plugin_registry() -> None:
    text = (ROOT / "scripts" / "status-workspace.sh").read_text(encoding="utf-8")
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")

    assert 'source "${ROOT}/scripts/lib/doctor-plugin-registry.sh"' in text
    assert 'PLUGIN_REGISTRY_JSON="$(doctor_plugin_registry_json 0)"' in text
    assert '"plugin_registry": ${PLUGIN_REGISTRY_JSON}' in text
    assert "status-json:" in makefile
    assert "doctor-json:" in makefile
    assert "@bash scripts/doctor.sh --json" in makefile


def test_project_mcp_repair_hook_rewrites_supabase_and_modal_blocks() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        config = tmp / ".codex" / "config.toml"
        config.parent.mkdir()
        config.write_text(
            """
[mcp_servers.supabase]
url = "https://mcp.supabase.com/mcp?project_ref=wrong"
bearer_token_env_var = "SUPABASE_ACCESS_TOKEN"

[mcp_servers.modal-ops]
command = "python"
args = ["wrong.py"]
env = { MODAL_PROFILE = "wrong" }
""".lstrip(),
            encoding="utf-8",
        )

        command = (
            f'ROOT="{tmp}"; '
            f'source "{REGISTRY}"; '
            "doctor_plugin_repair_project_mcp_config supabase; "
            "doctor_plugin_repair_project_mcp_config modal-ops"
        )
        subprocess.run(["bash", "-lc", command], cwd=ROOT, check=True)

        repaired = config.read_text(encoding="utf-8")
        assert "project_ref=vwxfvzutyufrkhfgoeaa" in repaired
        assert 'bearer_token_env_var = "TRR_SUPABASE_ACCESS_TOKEN"' in repaired
        assert f'command = "{tmp}/TRR-Backend/.venv/bin/python"' in repaired
        assert f'args = ["{tmp}/TRR-Backend/scripts/modal/modal_ops_mcp.py"]' in repaired
        assert 'TRR_MODAL_APP_NAME = "trr-backend-jobs"' in repaired


def test_modal_doctor_accepts_equivalent_symlinked_workspace_paths(tmp_path: Path) -> None:
    assert sys.version_info >= (3, 11), "Python 3.11+ is required by the registry's tomllib parser"
    runtime_python = sys.executable
    real_root = tmp_path / "Development" / "Projects" / "TRR"
    alias_root = tmp_path / "Projects" / "TRR"
    python = real_root / "TRR-Backend" / ".venv" / "bin" / "python"
    script = real_root / "TRR-Backend" / "scripts" / "modal" / "modal_ops_mcp.py"
    python.parent.mkdir(parents=True)
    script.parent.mkdir(parents=True)
    python.write_text("", encoding="utf-8")
    script.write_text("", encoding="utf-8")
    alias_root.parent.mkdir(parents=True)
    alias_root.symlink_to(real_root, target_is_directory=True)

    config = real_root / ".codex" / "config.toml"
    config.parent.mkdir()
    config.write_text(
        f'''[mcp_servers.modal-ops]
command = "{alias_root}/TRR-Backend/.venv/bin/python"
args = ["{alias_root}/TRR-Backend/scripts/modal/modal_ops_mcp.py"]
env = {{ MODAL_PROFILE = "admin-56995", MODAL_PROFILE_NAME = "admin-56995", MODAL_PROFILE_LABEL = "TRR Backend Jobs", TRR_MODAL_APP_NAME = "trr-backend-jobs" }}
default_tools_approval_mode = "approve"
''',
        encoding="utf-8",
    )

    command = (
        f'MCP_RUNTIME_PYTHON_BIN="{runtime_python}"; '
        f'ROOT="{real_root}"; '
        f'source "{REGISTRY}"; '
        'doctor_plugin_project_mcp_status modal-ops'
    )
    result = subprocess.run(
        ["bash", "-lc", command],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert "profile=admin-56995; app=trr-backend-jobs" in result.stdout
    assert 'default_tools_approval_mode = "approve"' in config.read_text(encoding="utf-8")
