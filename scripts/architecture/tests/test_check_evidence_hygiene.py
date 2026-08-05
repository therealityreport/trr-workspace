from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import sys

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "architecture" / "check-evidence-hygiene.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_evidence_hygiene_under_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_safe_names_redactions_and_hashes_pass(tmp_path: Path) -> None:
    module = load_module()
    evidence = tmp_path / "docs/evidence.json"
    evidence.parent.mkdir(parents=True)
    evidence.write_text(
        '{"environment_variable_names":["TRR_RENDER_API_KEY"],"value":"<redacted>","sha256":"'
        + "a" * 64
        + '"}\n',
        encoding="utf-8",
    )

    count, failures = module.validate_evidence_hygiene(tmp_path, [Path("docs")])

    assert count == 1
    assert failures == []


@pytest.mark.parametrize(
    "content,label",
    [
        ("DATABASE_URL=postgresql://user:pass@db.example/test", "database-url"),
        ("Authorization: Bearer abcdefghijklmnopqrstuvwxyz", "bearer-token"),
        ("token=not-redacted-value", "secret-assignment"),
        ("-----BEGIN PRIVATE KEY-----", "private-key"),
        ("eyJ" + "a" * 20 + "." + "b" * 20 + "." + "c" * 20, "jwt"),
        ("AKIA" + "A" * 16, "aws-access-key"),
        ("sk-proj-" + "a" * 32, "provider-secret"),
    ],
)
def test_secret_like_content_is_rejected(
    tmp_path: Path,
    content: str,
    label: str,
) -> None:
    module = load_module()
    evidence = tmp_path / "docs/evidence.log"
    evidence.parent.mkdir(parents=True)
    evidence.write_text(content + "\n", encoding="utf-8")

    _, failures = module.validate_evidence_hygiene(tmp_path, [Path("docs")])

    assert any(f"matched {label}" in failure for failure in failures)


def test_detailed_evidence_requires_private_permissions(tmp_path: Path) -> None:
    module = load_module()
    evidence_root = tmp_path / "artifacts/architecture-overhaul/run"
    evidence_root.mkdir(parents=True)
    evidence = evidence_root / "command.log"
    evidence.write_text("safe output\n", encoding="utf-8")
    os.chmod(tmp_path / "artifacts/architecture-overhaul", 0o700)
    os.chmod(evidence_root, 0o700)
    os.chmod(evidence, 0o640)

    _, failures = module.validate_evidence_hygiene(
        tmp_path,
        [Path("artifacts/architecture-overhaul")],
    )

    assert any("mode 0640 exposes group/world permissions" in failure for failure in failures)


def test_scan_path_cannot_escape_workspace(tmp_path: Path) -> None:
    module = load_module()

    with pytest.raises(ValueError, match="escapes workspace"):
        module.discover_files(tmp_path, [Path("../outside")])


def test_env_style_evidence_file_is_scanned(tmp_path: Path) -> None:
    module = load_module()
    evidence = tmp_path / "docs/.env.production"
    evidence.parent.mkdir(parents=True)
    evidence.write_text(
        "DATABASE_URL=postgresql://user:pass@db.example/test\n",
        encoding="utf-8",
    )

    count, failures = module.validate_evidence_hygiene(tmp_path, [Path("docs")])

    assert count == 1
    assert any("matched database-url" in failure for failure in failures)


def test_nested_evidence_symlink_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    evidence_root = tmp_path / "docs"
    evidence_root.mkdir()
    target = tmp_path / "target.log"
    target.write_text("safe output\n", encoding="utf-8")
    (evidence_root / "linked.log").symlink_to(target)

    with pytest.raises(ValueError, match="must not be a symlink"):
        module.discover_files(tmp_path, [Path("docs")])


def test_detailed_evidence_root_symlink_is_rejected_for_custom_scans(tmp_path: Path) -> None:
    module = load_module()
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "safe.log").write_text("safe output\n", encoding="utf-8")
    private_root = tmp_path / "private-evidence"
    private_root.mkdir()
    artifact_parent = tmp_path / "artifacts"
    artifact_parent.mkdir()
    (artifact_parent / "architecture-overhaul").symlink_to(private_root, target_is_directory=True)

    _, failures = module.validate_evidence_hygiene(tmp_path, [Path("docs")])

    assert any("detailed evidence root must not be a symlink" in failure for failure in failures)


def test_default_scan_paths_cover_ignored_architecture_policy_files() -> None:
    module = load_module()

    assert {
        Path("docs/workspace/architecture-evidence.schema.json"),
        Path("docs/workspace/architecture-hotspots.json"),
        Path("docs/workspace/architecture-task-locks.json"),
        Path("docs/workspace/release-packet.schema.json"),
    }.issubset(set(module.DEFAULT_SCAN_PATHS))
