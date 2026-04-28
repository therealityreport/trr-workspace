#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_MIGRATIONS = ROOT / "TRR-APP/apps/web/db/migrations"
BACKEND_MIGRATIONS = ROOT / "TRR-Backend/supabase/migrations"
ALLOWLIST = ROOT / "docs/workspace/app-migration-ownership-allowlist.txt"
MIGRATION_PREFIX_RE = re.compile(r"^(\d+)(?=[_-])")
SHARED_SCHEMA_RE = re.compile(
    r"\b(?:admin|core|firebase_surveys|social)\."
    r"|\b(?:create|alter|drop)\s+schema\s+"
    r"(?:if\s+not\s+exists\s+)?\"?(?:admin|core|firebase_surveys|social)\"?\b"
    r"|\balter\s+schema\s+\"?surveys\"?\s+rename\s+to\s+\"?firebase_surveys\"?\b",
    re.IGNORECASE,
)


def _read_allowlist(path: Path) -> set[str]:
    allowed, _ = _read_policy_metadata(path)
    return allowed


def _read_policy_metadata(path: Path) -> tuple[set[str], set[str]]:
    if not path.is_file():
        return set(), set()
    allowed: set[str] = set()
    documented_duplicate_prefixes: set[str] = set()
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            comment = stripped[1:].strip()
            if comment.startswith("duplicate-prefix:"):
                value = comment.split(":", 1)[1].strip()
                if value:
                    token = value.split(maxsplit=1)[0]
                    documented_duplicate_prefixes.add(token)
            continue
        line = raw_line.split("#", 1)[0].strip()
        if line:
            allowed.add(line)
    return allowed, documented_duplicate_prefixes


def _migration_files(migrations_dir: Path) -> list[Path]:
    if not migrations_dir.exists():
        return []
    return sorted(migrations_dir.glob("*.sql"))


def _shared_schema_migrations() -> list[Path]:
    results = []
    for path in _migration_files(APP_MIGRATIONS):
        text = path.read_text(encoding="utf-8", errors="replace")
        if SHARED_SCHEMA_RE.search(text):
            results.append(path)
    return results


def _duplicate_prefixes(migrations_dir: Path) -> dict[str, list[Path]]:
    grouped: dict[str, list[Path]] = defaultdict(list)
    for path in _migration_files(migrations_dir):
        match = MIGRATION_PREFIX_RE.match(path.name)
        if match:
            grouped[match.group(1)].append(path)
    relative_dir = migrations_dir.relative_to(ROOT).as_posix()
    return {
        f"{relative_dir}:{prefix}": paths
        for prefix, paths in grouped.items()
        if len(paths) > 1
    }


def _all_duplicate_prefixes() -> dict[str, list[Path]]:
    duplicates: dict[str, list[Path]] = {}
    for migrations_dir in (APP_MIGRATIONS, BACKEND_MIGRATIONS):
        duplicates.update(_duplicate_prefixes(migrations_dir))
    return duplicates


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Flag new shared-schema migrations in TRR-APP. "
            "Policy: docs/workspace/migration-ownership-policy.md."
        )
    )
    parser.add_argument("--allowlist", type=Path, default=ALLOWLIST)
    parser.add_argument("--list-current", action="store_true")
    parser.add_argument("--list-duplicate-prefixes", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    migrations = _shared_schema_migrations()
    if args.list_current:
        for path in migrations:
            print(path.relative_to(ROOT).as_posix())
        return 0
    if args.list_duplicate_prefixes:
        for key, paths in _all_duplicate_prefixes().items():
            path_list = ", ".join(path.relative_to(ROOT).as_posix() for path in paths)
            print(f"{key}: {path_list}")
        return 0
    allowlist_path = args.allowlist if args.allowlist.is_absolute() else ROOT / args.allowlist
    allowed, documented_duplicate_prefixes = _read_policy_metadata(allowlist_path)
    violations = [
        path.relative_to(ROOT).as_posix()
        for path in migrations
        if path.relative_to(ROOT).as_posix() not in allowed
    ]
    duplicate_prefixes = _all_duplicate_prefixes()
    undocumented_duplicate_prefixes = {
        key: paths
        for key, paths in duplicate_prefixes.items()
        if key not in documented_duplicate_prefixes
    }
    if violations:
        print("[migration-ownership-lint] ERROR: shared-schema migrations found in TRR-APP:", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        print("Move shared schema migrations to TRR-Backend/supabase/migrations or add an intentional allowlist entry.", file=sys.stderr)
    if undocumented_duplicate_prefixes:
        print("[migration-ownership-lint] ERROR: undocumented duplicate migration prefixes:", file=sys.stderr)
        for key, paths in undocumented_duplicate_prefixes.items():
            print(f"  - {key}", file=sys.stderr)
            for path in paths:
                print(f"    - {path.relative_to(ROOT).as_posix()}", file=sys.stderr)
        print(
            "Rename the duplicate prefix or document the ordering exception with "
            "`# duplicate-prefix: <migration-dir>:<prefix> ...` in the allowlist.",
            file=sys.stderr,
        )
    if violations or undocumented_duplicate_prefixes:
        return 1
    print("[migration-ownership-lint] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
