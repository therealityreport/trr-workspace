#!/usr/bin/env python3
"""Check that required architecture contracts are durable at a named Git boundary."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess


WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
REQUIRED_CONTRACTS = (
    "CONTEXT-MAP.md",
    "docs/workspace/architecture-task-locks.json",
    "docs/workspace/deployment-targets.json",
    "docs/workspace/runtime-capacity.json",
    "docs/workspace/output-disposition.json",
    "docs/workspace/release-packet.schema.json",
    "docs/workspace/architecture-evidence.schema.json",
    "docs/workspace/architecture-hotspots.json",
    "docs/workspace/parked-unaccepted-local-work.json",
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
REQUIRED_CONTRACT_TREES = (
    "scripts/architecture",
    "docs/workspace/release-packets",
    "docs/workspace/architecture-evidence",
)
GENERATED_TREE_PARTS = {"__pycache__", ".pytest_cache"}
GENERATED_TREE_NAMES = {".DS_Store"}
REGULAR_GIT_MODES = {"100644", "100755"}


def normalize_required_path(raw_path: str, *, label: str = "required path") -> str:
    path = Path(raw_path)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"{label} escapes workspace: {raw_path}")
    normalized = path.as_posix().removeprefix("./")
    if normalized in ("", "."):
        raise ValueError(f"{label} must name a workspace-relative path")
    return normalized


def path_uses_symlink(root: Path, relative_path: str) -> bool:
    current = root
    for part in Path(relative_path).parts:
        current /= part
        if current.is_symlink():
            return True
    return False


def discover_tree_contracts(root: Path, relative_tree: str) -> list[str]:
    tree = root / relative_tree
    if path_uses_symlink(root, relative_tree):
        return [relative_tree]
    if not tree.is_dir():
        raise ValueError(f"missing required tree: {relative_tree}")
    contracts: list[str] = []
    for candidate in tree.rglob("*"):
        relative = candidate.relative_to(root)
        if candidate.is_symlink():
            contracts.append(relative.as_posix())
            continue
        if any(part in GENERATED_TREE_PARTS for part in relative.parts):
            continue
        if candidate.name in GENERATED_TREE_NAMES or candidate.suffix in {".pyc", ".pyo"}:
            continue
        if candidate.is_file():
            contracts.append(relative.as_posix())
    if not contracts:
        raise ValueError(f"required tree has no durable files: {relative_tree}")
    return sorted(contracts)


def git_path_is_ignored(root: Path, path: str) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "--quiet", "--", path],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode not in (0, 1):
        detail = completed.stderr.strip() or "git check-ignore failed"
        raise RuntimeError(detail)
    return completed.returncode == 0


def git_path_is_tracked(root: Path, path: str) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--error-unmatch", "--", path],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode not in (0, 1):
        detail = completed.stderr.strip() or "git ls-files failed"
        raise RuntimeError(detail)
    return completed.returncode == 0


def git_index_entries(root: Path, path: str) -> list[tuple[str, str, str]]:
    completed = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "ls-files",
            "--stage",
            "--error-unmatch",
            "-z",
            "--",
            path,
        ],
        capture_output=True,
        check=False,
    )
    if completed.returncode == 1:
        return []
    if completed.returncode != 0:
        detail = completed.stderr.decode(errors="replace").strip()
        raise RuntimeError(detail or "git ls-files --stage failed")
    entries: list[tuple[str, str, str]] = []
    for record in completed.stdout.split(b"\0"):
        if not record:
            continue
        header, separator, _ = record.partition(b"\t")
        fields = header.split()
        if not separator or len(fields) != 3:
            raise RuntimeError(f"unexpected git index entry for {path}")
        mode, object_id, stage = (field.decode("ascii") for field in fields)
        entries.append((mode, object_id, stage))
    return entries


def git_object_is_blob(root: Path, object_id: str) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{object_id}^{{blob}}"],
        capture_output=True,
        check=False,
    )
    return completed.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=WORKSPACE_ROOT)
    parser.add_argument(
        "--boundary",
        choices=("working-tree", "candidate"),
        default="working-tree",
    )
    parser.add_argument(
        "--required",
        action="append",
        default=[],
        help="Override the default contract set (repeat for multiple paths).",
    )
    parser.add_argument(
        "--required-tree",
        action="append",
        default=[],
        help="Override the default contract trees (repeat for multiple paths).",
    )
    args = parser.parse_args()

    try:
        custom_requirements = bool(args.required or args.required_tree)
        required = [
            normalize_required_path(path)
            for path in (args.required if custom_requirements else REQUIRED_CONTRACTS)
        ]
        raw_required_trees = (
            args.required_tree if custom_requirements else REQUIRED_CONTRACT_TREES
        )
        required_trees = [
            normalize_required_path(path, label="required tree")
            for path in raw_required_trees
        ]
        for tree in required_trees:
            required.extend(discover_tree_contracts(args.root, tree))
        required = sorted(set(required))
        symlinks = [
            path for path in required if path_uses_symlink(args.root, path)
        ]
        missing = [
            path
            for path in required
            if path not in symlinks and not (args.root / path).is_file()
        ]
        ignored = [
            path
            for path in required
            if path not in missing
            and path not in symlinks
            and git_path_is_ignored(args.root, path)
        ]
        eligible = [
            path
            for path in required
            if path not in missing and path not in symlinks and path not in ignored
        ]
        tracked = [path for path in eligible if git_path_is_tracked(args.root, path)]
        untracked = [path for path in eligible if path not in tracked]
        index_non_regular: list[str] = []
        index_invalid_object: list[str] = []
        if args.boundary == "candidate":
            for path in tracked:
                entries = git_index_entries(args.root, path)
                if len(entries) != 1:
                    description = "+".join(
                        f"{mode}@{stage}" for mode, _, stage in entries
                    ) or "missing"
                    index_non_regular.append(f"{path}:{description}")
                    continue
                mode, object_id, stage = entries[0]
                if mode not in REGULAR_GIT_MODES or stage != "0":
                    index_non_regular.append(f"{path}:{mode}")
                elif not git_object_is_blob(args.root, object_id):
                    index_invalid_object.append(f"{path}:{object_id}")
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"durable-contracts: ERROR {exc}")
        return 1
    candidate_failures = untracked or index_non_regular or index_invalid_object
    if missing or symlinks or ignored or (
        args.boundary == "candidate" and candidate_failures
    ):
        failure_groups = [
            ("missing", missing),
            ("symlink", symlinks),
            ("ignored", ignored),
        ]
        if args.boundary == "candidate":
            failure_groups.extend(
                [
                    ("untracked", untracked),
                    ("index_non_regular", index_non_regular),
                    ("index_invalid_object", index_invalid_object),
                ]
            )
        for label, paths in failure_groups:
            if paths:
                print(f"durable-contracts: ERROR {label}={','.join(sorted(paths))}")
        return 1
    print(
        "durable-contracts: OK "
        f"boundary={args.boundary} required={len(required)} "
        f"tracked={len(tracked)} untracked={len(untracked)} "
        "candidate_tracking_ready="
        f"{'true' if not untracked else 'false'} commit_state=not_checked"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
