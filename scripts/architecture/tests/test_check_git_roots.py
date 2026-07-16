from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "architecture" / "check-git-roots.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_git_roots_under_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def create_expected_roots(workspace: Path) -> None:
    for relative in (Path("."), Path("TRR-APP"), Path("TRR-Backend")):
        (workspace / relative / ".git").mkdir(parents=True)


def test_exact_three_roots_pass(tmp_path: Path) -> None:
    module = load_module()
    create_expected_roots(tmp_path)

    actual, missing, unexpected = module.validate_git_roots(tmp_path)

    assert actual == [".", "TRR-APP", "TRR-Backend"]
    assert missing == []
    assert unexpected == []


def test_nested_fourth_root_fails(tmp_path: Path) -> None:
    module = load_module()
    create_expected_roots(tmp_path)
    (tmp_path / "TRR-APP" / "apps" / "web" / ".git").mkdir(parents=True)

    _, missing, unexpected = module.validate_git_roots(tmp_path)

    assert missing == []
    assert unexpected == ["TRR-APP/apps/web"]


def test_missing_intended_root_fails(tmp_path: Path) -> None:
    module = load_module()
    create_expected_roots(tmp_path)
    (tmp_path / "TRR-Backend" / ".git").rmdir()

    _, missing, unexpected = module.validate_git_roots(tmp_path)

    assert missing == ["TRR-Backend"]
    assert unexpected == []


def test_git_file_counts_as_active_root(tmp_path: Path) -> None:
    module = load_module()
    create_expected_roots(tmp_path)
    (tmp_path / "TRR-APP" / ".git").rmdir()
    (tmp_path / "TRR-APP" / ".git").write_text("gitdir: /tmp/example\n", encoding="utf-8")

    actual, missing, unexpected = module.validate_git_roots(tmp_path)

    assert actual == [".", "TRR-APP", "TRR-Backend"]
    assert missing == []
    assert unexpected == []
