from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "workspace-env-contract.sh"
CONTRACT = ROOT / "docs" / "workspace" / "env-contract.md"
OBJECT_STORAGE_KEYS = {
    "OBJECT_STORAGE_ACCESS_KEY_ID",
    "OBJECT_STORAGE_BUCKET",
    "OBJECT_STORAGE_ENDPOINT_URL",
    "OBJECT_STORAGE_PROVIDER",
    "OBJECT_STORAGE_PUBLIC_BASE_URL",
    "OBJECT_STORAGE_REGION",
    "OBJECT_STORAGE_SECRET_ACCESS_KEY",
    "OBJECT_STORAGE_VIDEO_BUCKET",
    "OBJECT_STORAGE_VIDEO_URL_TTL_SECONDS",
}


def test_generated_contract_tracks_only_supported_object_storage_rows() -> None:
    result = subprocess.run(
        ["bash", str(SCRIPT), "--check"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    rows = {
        line.split("`")[1]
        for line in CONTRACT.read_text(encoding="utf-8").splitlines()
        if line.startswith("| `OBJECT_STORAGE_")
    }
    assert rows == OBJECT_STORAGE_KEYS
    assert "| `VIDEO_STORAGE_" not in CONTRACT.read_text(encoding="utf-8")
