from __future__ import annotations

import subprocess
import tempfile
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
