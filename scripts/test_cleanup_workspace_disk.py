from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


SCRIPT_PATH = Path(__file__).resolve().parent / "cleanup-workspace-disk.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("cleanup_workspace_disk_under_test", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _mkdir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / ".keep").write_text("generated\n", encoding="utf-8")


def test_screenalytics_generated_candidates_exclude_protected_paths(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    screenalytics_root = tmp_path / "screenalytics"
    monkeypatch.setattr(module, "SCREENALYTICS_ROOT", screenalytics_root)
    monkeypatch.setattr(module, "SCREENALYTICS_DATA_ROOT", screenalytics_root / "data")

    _mkdir(screenalytics_root / ".venv")
    _mkdir(screenalytics_root / ".venv-crawl4ai")
    _mkdir(screenalytics_root / "web" / "node_modules")
    _mkdir(screenalytics_root / "web" / ".next")
    _mkdir(screenalytics_root / ".logs")
    _mkdir(screenalytics_root / ".git")
    _mkdir(screenalytics_root / "data" / "show-s01e01")
    (screenalytics_root / ".env").write_text("SECRET=value\n", encoding="utf-8")
    (screenalytics_root / ".env.example").write_text("SECRET=\n", encoding="utf-8")

    candidate_paths = {
        candidate.path.relative_to(screenalytics_root).as_posix()
        for candidate in module.screenalytics_generated_artifact_candidates()
    }

    assert ".venv" in candidate_paths
    assert ".venv-crawl4ai" in candidate_paths
    assert "web/node_modules" in candidate_paths
    assert "web/.next" in candidate_paths
    assert ".logs" in candidate_paths
    assert ".git" not in candidate_paths
    assert "data/show-s01e01" not in candidate_paths
    assert ".env" not in candidate_paths
    assert ".env.example" not in candidate_paths


def test_apply_requires_confirmation_flag() -> None:
    module = _load_module()

    with pytest.raises(SystemExit):
        module.parse_args(["--apply"])

    args = module.parse_args(["--apply", "--confirm-delete-local-artifacts"])

    assert args.apply is True
    assert args.confirm_delete_local_artifacts is True


def test_default_run_is_dry_run_and_names_protected_paths(tmp_path: Path, monkeypatch, capsys) -> None:
    module = _load_module()
    workspace_root = tmp_path
    screenalytics_root = workspace_root / "screenalytics"
    backend_root = workspace_root / "TRR-Backend"
    app_root = workspace_root / "TRR-APP"
    monkeypatch.setattr(module, "WORKSPACE_ROOT", workspace_root)
    monkeypatch.setattr(module, "TRR_BACKEND_ROOT", backend_root)
    monkeypatch.setattr(module, "TRR_APP_ROOT", app_root)
    monkeypatch.setattr(module, "SCREENALYTICS_ROOT", screenalytics_root)
    monkeypatch.setattr(module, "SCREENALYTICS_DATA_ROOT", screenalytics_root / "data")
    monkeypatch.setattr(module, "REPO_ROOTS", {"screenalytics": screenalytics_root})

    _mkdir(screenalytics_root / ".venv")
    _mkdir(screenalytics_root / "data" / "show-s01e01")
    _mkdir(screenalytics_root / ".git")
    _mkdir(backend_root)
    _mkdir(app_root)
    (screenalytics_root / ".env").write_text("SECRET=value\n", encoding="utf-8")

    result = module.main([])
    output = capsys.readouterr().out

    assert result == 0
    assert "mode=dry-run" in output
    assert "Dry run only. Re-run with --apply" in output
    assert "screenalytics/.env and screenalytics/.env.*" in output
    assert "screenalytics/.git" in output
    assert "screenalytics/data/" in output
    assert "[screenalytics-generated]" in output
    assert str(screenalytics_root / ".venv") in output
    assert str(screenalytics_root / "data" / "show-s01e01") not in output
