#!/usr/bin/env python3
"""Require exactly the three intended active Git roots in the TRR workspace."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


EXPECTED_ROOTS = (Path("."), Path("TRR-APP"), Path("TRR-Backend"))
EXCLUDED_DIRECTORY_NAMES = {
    ".next",
    ".next-e2e",
    ".pytest_cache",
    ".venv",
    "__pycache__",
    "artifacts",
    "dist",
    "node_modules",
    "test-results",
}


def discover_git_roots(workspace_root: Path) -> set[Path]:
    workspace_root = workspace_root.resolve()
    discovered: set[Path] = set()
    for current, directory_names, file_names in os.walk(workspace_root, topdown=True):
        current_path = Path(current)
        if ".git" in directory_names:
            discovered.add(current_path.resolve())
            directory_names.remove(".git")
        if ".git" in file_names:
            discovered.add(current_path.resolve())
        directory_names[:] = [
            name for name in directory_names if name not in EXCLUDED_DIRECTORY_NAMES
        ]
    return discovered


def relative_roots(workspace_root: Path, roots: set[Path]) -> list[str]:
    workspace_root = workspace_root.resolve()
    return sorted(
        "." if root == workspace_root else root.relative_to(workspace_root).as_posix()
        for root in roots
    )


def validate_git_roots(workspace_root: Path) -> tuple[list[str], list[str], list[str]]:
    actual = discover_git_roots(workspace_root)
    expected = {(workspace_root / relative).resolve() for relative in EXPECTED_ROOTS}
    missing = relative_roots(workspace_root, expected - actual)
    unexpected = relative_roots(workspace_root, actual - expected)
    return relative_roots(workspace_root, actual), missing, unexpected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="TRR workspace root (defaults to the repository containing this script).",
    )
    args = parser.parse_args()
    actual, missing, unexpected = validate_git_roots(args.root)
    for root in actual:
        print(f"active_git_root={root}")
    if missing:
        print(f"architecture-git-roots: ERROR missing={','.join(missing)}")
    if unexpected:
        print(f"architecture-git-roots: ERROR unexpected={','.join(unexpected)}")
    if missing or unexpected:
        return 1
    print("architecture-git-roots: OK count=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
