from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "architecture" / "check-durable-contracts.py"


def init_git_repository(path: Path) -> None:
    subprocess.run(["git", "init", "--quiet", str(path)], check=True)


def run_checker(
    root: Path,
    *,
    boundary: str,
    required: tuple[str, ...] = (),
    required_trees: tuple[str, ...] = (),
) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        str(SCRIPT),
        "--root",
        str(root),
        "--boundary",
        boundary,
    ]
    for path in required:
        command.extend(["--required", path])
    for path in required_trees:
        command.extend(["--required-tree", path])
    return subprocess.run(command, capture_output=True, text=True, check=False)


def test_working_tree_boundary_rejects_missing_required_contract(tmp_path: Path) -> None:
    init_git_repository(tmp_path)

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required=("docs/required.json",),
    )

    assert completed.returncode == 1
    assert "durable-contracts: ERROR missing=docs/required.json" in completed.stdout


def test_working_tree_boundary_rejects_ignored_required_contract(tmp_path: Path) -> None:
    init_git_repository(tmp_path)
    contract = tmp_path / "docs/required.json"
    contract.parent.mkdir()
    contract.write_text("{}\n", encoding="utf-8")
    (tmp_path / ".gitignore").write_text("docs/required.json\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required=("docs/required.json",),
    )

    assert completed.returncode == 1
    assert "durable-contracts: ERROR ignored=docs/required.json" in completed.stdout


def test_candidate_boundary_rejects_untracked_required_contract(tmp_path: Path) -> None:
    init_git_repository(tmp_path)
    contract = tmp_path / "docs/required.json"
    contract.parent.mkdir()
    contract.write_text("{}\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="candidate",
        required=("docs/required.json",),
    )

    assert completed.returncode == 1
    assert "durable-contracts: ERROR untracked=docs/required.json" in completed.stdout


def test_working_tree_boundary_reports_untracked_without_claiming_candidate_commit(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    contract = tmp_path / "docs/required.json"
    contract.parent.mkdir()
    contract.write_text("{}\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required=("docs/required.json",),
    )

    assert completed.returncode == 0
    assert (
        "durable-contracts: OK boundary=working-tree required=1 "
        "tracked=0 untracked=1 candidate_tracking_ready=false "
        "commit_state=not_checked"
    ) in completed.stdout


def test_candidate_boundary_checks_every_file_in_required_tree(tmp_path: Path) -> None:
    init_git_repository(tmp_path)
    helper = tmp_path / "scripts/architecture/check-example.py"
    helper.parent.mkdir(parents=True)
    helper.write_text("#!/usr/bin/env python3\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="candidate",
        required_trees=("scripts/architecture",),
    )

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR untracked=scripts/architecture/check-example.py"
        in completed.stdout
    )


def test_candidate_boundary_accepts_tracked_contract_without_claiming_a_commit(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    contract = tmp_path / "docs/required.json"
    contract.parent.mkdir()
    contract.write_text("{}\n", encoding="utf-8")
    subprocess.run(
        ["git", "-C", str(tmp_path), "add", "--", "docs/required.json"],
        check=True,
    )

    completed = run_checker(
        tmp_path,
        boundary="candidate",
        required=("docs/required.json",),
    )

    assert completed.returncode == 0
    assert (
        "durable-contracts: OK boundary=candidate required=1 "
        "tracked=1 untracked=0 candidate_tracking_ready=true "
        "commit_state=not_checked"
    ) in completed.stdout


def test_working_tree_failure_does_not_mislabel_allowed_untracked_contract(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    present = tmp_path / "docs/present.json"
    present.parent.mkdir()
    present.write_text("{}\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required=("docs/missing.json", "docs/present.json"),
    )

    assert completed.returncode == 1
    assert "durable-contracts: ERROR missing=docs/missing.json" in completed.stdout
    assert "durable-contracts: ERROR untracked=" not in completed.stdout


def test_required_path_cannot_escape_workspace(tmp_path: Path) -> None:
    init_git_repository(tmp_path)
    (tmp_path.parent / "outside.json").write_text("{}\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required=("../outside.json",),
    )

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR required path escapes workspace: ../outside.json"
        in completed.stdout
    )


def test_candidate_boundary_rejects_any_tracked_required_contract_symlink(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    docs = tmp_path / "docs"
    docs.mkdir()
    owned_target = docs / "owned-target.json"
    owned_target.write_text("{}\n", encoding="utf-8")
    outside_target = tmp_path.parent / "outside-target.json"
    outside_target.write_text("{}\n", encoding="utf-8")
    (docs / "external.json").symlink_to(outside_target)
    (docs / "internal.json").symlink_to(owned_target)
    subprocess.run(
        [
            "git",
            "-C",
            str(tmp_path),
            "add",
            "--",
            "docs/external.json",
            "docs/internal.json",
        ],
        check=True,
    )

    completed = run_checker(
        tmp_path,
        boundary="candidate",
        required=("docs/external.json", "docs/internal.json"),
    )

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR symlink="
        "docs/external.json,docs/internal.json" in completed.stdout
    )


def test_working_tree_boundary_rejects_contract_beneath_symlinked_directory(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    outside_docs = tmp_path.parent / "outside-docs"
    outside_docs.mkdir()
    (outside_docs / "required.json").write_text("{}\n", encoding="utf-8")
    (tmp_path / "docs").symlink_to(outside_docs, target_is_directory=True)

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required=("docs/required.json",),
    )

    assert completed.returncode == 1
    assert "durable-contracts: ERROR symlink=docs/required.json" in completed.stdout


def test_required_tree_rejects_directory_and_dangling_symlink_entries(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    tree = tmp_path / "scripts/architecture"
    tree.mkdir(parents=True)
    (tree / "check-example.py").write_text("#!/usr/bin/env python3\n", encoding="utf-8")
    outside_directory = tmp_path.parent / "outside-tree"
    outside_directory.mkdir()
    (tree / "linked-dir").symlink_to(outside_directory, target_is_directory=True)
    (tree / "dangling.py").symlink_to(tree / "missing-target.py")
    subprocess.run(
        [
            "git",
            "-C",
            str(tmp_path),
            "add",
            "--",
            "scripts/architecture/linked-dir",
            "scripts/architecture/dangling.py",
        ],
        check=True,
    )

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required_trees=("scripts/architecture",),
    )

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR symlink="
        "scripts/architecture/dangling.py,scripts/architecture/linked-dir"
        in completed.stdout
    )


def test_required_tree_does_not_hide_symlink_behind_generated_name(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    tree = tmp_path / "scripts/architecture"
    tree.mkdir(parents=True)
    (tree / "check-example.py").write_text("#!/usr/bin/env python3\n", encoding="utf-8")
    (tree / "__pycache__").symlink_to(
        tree / "missing-cache",
        target_is_directory=True,
    )

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required_trees=("scripts/architecture",),
    )

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR symlink=scripts/architecture/__pycache__"
        in completed.stdout
    )


def test_required_tree_rejects_symlinked_ancestor(tmp_path: Path) -> None:
    init_git_repository(tmp_path)
    outside_scripts = tmp_path.parent / "outside-scripts"
    outside_tree = outside_scripts / "architecture"
    outside_tree.mkdir(parents=True)
    (outside_tree / "check-example.py").write_text(
        "#!/usr/bin/env python3\n",
        encoding="utf-8",
    )
    (tmp_path / "scripts").symlink_to(outside_scripts, target_is_directory=True)

    completed = run_checker(
        tmp_path,
        boundary="working-tree",
        required_trees=("scripts/architecture",),
    )

    assert completed.returncode == 1
    assert "durable-contracts: ERROR symlink=scripts/architecture" in completed.stdout


def test_candidate_boundary_rejects_index_symlink_replaced_by_worktree_file(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    docs = tmp_path / "docs"
    docs.mkdir()
    target = docs / "target.json"
    target.write_text("{}\n", encoding="utf-8")
    contract = docs / "required.json"
    contract.symlink_to(target)
    subprocess.run(
        ["git", "-C", str(tmp_path), "add", "--", "docs/required.json"],
        check=True,
    )
    contract.unlink()
    contract.write_text("{}\n", encoding="utf-8")

    completed = run_checker(
        tmp_path,
        boundary="candidate",
        required=("docs/required.json",),
    )

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR index_non_regular=docs/required.json:120000"
        in completed.stdout
    )


def test_default_set_checks_parked_work_and_r0_b_manifest_trees(
    tmp_path: Path,
) -> None:
    init_git_repository(tmp_path)
    existing_default_contracts = (
        "CONTEXT-MAP.md",
        "docs/workspace/architecture-task-locks.json",
        "docs/workspace/deployment-targets.json",
        "docs/workspace/runtime-capacity.json",
        "docs/workspace/output-disposition.json",
        "docs/workspace/release-packet.schema.json",
        "docs/workspace/architecture-evidence.schema.json",
        "docs/workspace/architecture-hotspots.json",
        "scripts/architecture/check-durable-contracts.py",
        "scripts/architecture/check-evidence-hygiene.py",
        "scripts/architecture/check-git-roots.py",
        "scripts/architecture/check-hotspots.py",
        "scripts/architecture/check-import-graph.py",
        "scripts/architecture/check-release-manifests.py",
        "scripts/architecture/tests/test_check_durable_contracts.py",
        "scripts/architecture/tests/test_check_evidence_hygiene.py",
        "scripts/architecture/tests/test_check_git_roots.py",
        "scripts/architecture/tests/test_check_hotspots.py",
        "scripts/architecture/tests/test_check_import_graph.py",
        "scripts/architecture/tests/test_check_release_manifests.py",
    )
    new_default_contracts = (
        "docs/workspace/parked-unaccepted-local-work.json",
        "docs/workspace/release-packets/packet.json",
        "docs/workspace/architecture-evidence/evidence.json",
    )
    for relative_path in (*existing_default_contracts, *new_default_contracts):
        contract = tmp_path / relative_path
        contract.parent.mkdir(parents=True, exist_ok=True)
        contract.write_text("{}\n", encoding="utf-8")
    (tmp_path / ".gitignore").write_text(
        "\n".join(new_default_contracts) + "\n",
        encoding="utf-8",
    )

    completed = run_checker(tmp_path, boundary="working-tree")

    assert completed.returncode == 1
    assert (
        "durable-contracts: ERROR ignored="
        "docs/workspace/architecture-evidence/evidence.json,"
        "docs/workspace/parked-unaccepted-local-work.json,"
        "docs/workspace/release-packets/packet.json" in completed.stdout
    )
