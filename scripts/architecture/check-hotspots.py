#!/usr/bin/env python3
"""Enforce shrink-only line ceilings and expiring metadata for architecture hotspots."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import date, timedelta
import json
from pathlib import Path
from typing import Any


WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = Path("docs/workspace/architecture-hotspots.json")
VALID_CLASSIFICATIONS = {"existing_hotspot", "temporary_exception"}
PRODUCTION_SOURCE_TREES: tuple[tuple[Path, frozenset[str]], ...] = (
    (Path("TRR-Backend/api"), frozenset({".py"})),
    (Path("TRR-Backend/trr_backend"), frozenset({".py"})),
    (
        Path("TRR-APP/apps/web/src"),
        frozenset({".css", ".js", ".jsx", ".ts", ".tsx"}),
    ),
)


class HotspotValidationError(ValueError):
    """Raised when the hotspot manifest or live files violate the ratchet."""


def line_count(path: Path) -> int:
    with path.open("r", encoding="utf-8") as source:
        return sum(1 for _ in source)


def manifest_production_source_trees(
    manifest: dict[str, Any],
) -> tuple[tuple[Path, frozenset[str]], ...]:
    """Parse the manifest's production discovery boundary when it is declared."""

    discovery = manifest.get("discovery")
    if discovery is None:
        return PRODUCTION_SOURCE_TREES
    if not isinstance(discovery, dict) or discovery.get("mode") != "code_owned":
        raise HotspotValidationError("discovery.mode must be code_owned")
    raw_source_trees = discovery.get("source_trees")
    if not isinstance(raw_source_trees, list) or not raw_source_trees:
        raise HotspotValidationError("discovery.source_trees must be a non-empty array")

    source_trees: list[tuple[Path, frozenset[str]]] = []
    for index, raw_source_tree in enumerate(raw_source_trees):
        if not isinstance(raw_source_tree, dict):
            raise HotspotValidationError(
                f"discovery.source_trees[{index}] must be an object"
            )
        raw_root = raw_source_tree.get("root")
        raw_extensions = raw_source_tree.get("extensions")
        if not isinstance(raw_root, str) or not raw_root:
            raise HotspotValidationError(
                f"discovery.source_trees[{index}].root must be a non-empty string"
            )
        if (
            not isinstance(raw_extensions, list)
            or not raw_extensions
            or any(
                not isinstance(extension, str) or not extension.startswith(".")
                for extension in raw_extensions
            )
        ):
            raise HotspotValidationError(
                f"discovery.source_trees[{index}].extensions must be a non-empty extension array"
            )
        source_trees.append((Path(raw_root), frozenset(raw_extensions)))
    return tuple(source_trees)


def _positive_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HotspotValidationError(f"{path}: cannot read manifest: {exc}") from exc
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise HotspotValidationError(f"{path}: schema_version must be 1")
    return payload


def resolve_manifest_path(root: Path, raw_path: Path) -> Path:
    root = root.resolve()
    path = raw_path if raw_path.is_absolute() else root / raw_path
    if path.is_symlink():
        raise HotspotValidationError(f"manifest path must not be a symlink: {raw_path}")
    resolved = path.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise HotspotValidationError(
            f"manifest path escapes workspace: {raw_path}"
        ) from exc
    return resolved


def discover_production_files(
    root: Path,
    source_trees: tuple[tuple[Path, frozenset[str]], ...] = PRODUCTION_SOURCE_TREES,
) -> tuple[list[Path], list[str]]:
    """Return every source file from the code-owned production boundary."""

    root = root.resolve()
    files: list[Path] = []
    errors: list[str] = []
    for relative_root, extensions in source_trees:
        if relative_root.is_absolute() or ".." in relative_root.parts:
            errors.append(
                f"production source root must stay workspace-relative: {relative_root.as_posix()!r}"
            )
            continue
        if not extensions or any(
            not isinstance(extension, str) or not extension.startswith(".")
            for extension in extensions
        ):
            errors.append(
                f"production source root has invalid extensions: {relative_root.as_posix()!r}"
            )
            continue
        source_root = root / relative_root
        ancestor = root
        symlinked_ancestor: Path | None = None
        for part in relative_root.parts:
            ancestor /= part
            if ancestor.is_symlink():
                symlinked_ancestor = ancestor
                break
        if symlinked_ancestor is not None:
            errors.append(
                "production source ancestor must not be a symlink: "
                f"{symlinked_ancestor.relative_to(root).as_posix()}"
            )
            continue
        if not source_root.is_dir():
            errors.append(
                f"production source root does not exist: {relative_root.as_posix()}"
            )
            continue
        for source_path in sorted(source_root.rglob("*")):
            relative = source_path.relative_to(root).as_posix()
            if source_path.is_symlink():
                errors.append(
                    f"production source entry must not be a symlink: {relative}"
                )
                continue
            if source_path.suffix not in extensions:
                continue
            if not source_path.is_file():
                continue
            try:
                source_path.resolve().relative_to(source_root.resolve())
            except ValueError:
                errors.append(f"production source file escapes source root: {relative}")
                continue
            files.append(source_path)
    return files, errors


def validate_hotspots(
    root: Path,
    manifest: dict[str, Any],
    *,
    fail_expired: bool = False,
    as_of: date | None = None,
    production_source_trees: tuple[tuple[Path, frozenset[str]], ...] | None = None,
) -> list[str]:
    errors: list[str] = []
    if production_source_trees is None:
        try:
            production_source_trees = manifest_production_source_trees(manifest)
        except HotspotValidationError as exc:
            return [str(exc)]
    root = root.resolve()
    policy = manifest.get("policy")
    if not isinstance(policy, dict):
        return ["policy must be an object"]
    threshold = policy.get("production_hotspot_lines")
    route_target = policy.get("route_page_target_lines")
    review_window = policy.get("review_window_days")
    if not _positive_integer(threshold):
        errors.append("production_hotspot_lines must be a positive integer")
        threshold = 1000
    if not _positive_integer(route_target):
        errors.append("route_page_target_lines must be a positive integer")
        route_target = 500
    if review_window != 30:
        errors.append("review_window_days must be 30")
        review_window = 30

    records = manifest.get("hotspots")
    if not isinstance(records, list) or not all(
        isinstance(record, dict) for record in records
    ):
        return [*errors, "hotspots must be an array of objects"]
    paths = [
        record.get("path") for record in records if isinstance(record.get("path"), str)
    ]
    for path, count in sorted(Counter(paths).items()):
        if count > 1:
            errors.append(f"duplicate hotspot path: {path}")

    effective_date = as_of or date.today()
    listed_paths: set[str] = set()
    for index, record in enumerate(records):
        relative = record.get("path")
        label = (
            relative if isinstance(relative, str) and relative else f"hotspots[{index}]"
        )
        if (
            not isinstance(relative, str)
            or not relative
            or relative.startswith("/")
            or ".." in Path(relative).parts
        ):
            errors.append(f"{label}: path must be workspace-relative")
            continue
        listed_paths.add(relative)
        source_path = (root / relative).resolve()
        try:
            source_path.relative_to(root)
        except ValueError:
            errors.append(f"{label}: path escapes workspace")
            continue
        if not source_path.is_file():
            errors.append(f"{label}: file does not exist")
            continue

        for field in ("owner", "reason", "removal_plan"):
            value = record.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{label}: missing {field}")
        if record.get("classification") not in VALID_CLASSIFICATIONS:
            errors.append(f"{label}: invalid classification")
        ceiling = record.get("line_ceiling")
        target = record.get("target_lines")
        if not _positive_integer(ceiling):
            errors.append(f"{label}: line_ceiling must be a positive integer")
            continue
        if not _positive_integer(target) or target > ceiling:
            errors.append(
                f"{label}: target_lines must be positive and no greater than line_ceiling"
            )
        relative_path = Path(relative)
        if (
            relative.startswith("TRR-APP/apps/web/src/app/")
            and relative_path.name in {"page.ts", "page.tsx", "route.ts", "route.tsx"}
            and _positive_integer(target)
            and target > route_target
        ):
            errors.append(
                f"{label}: route/page target_lines must be no greater than {route_target}"
            )
        try:
            current_lines = line_count(source_path)
        except (OSError, UnicodeError) as exc:
            errors.append(f"{label}: cannot count source lines: {exc}")
            continue
        if current_lines > ceiling:
            errors.append(
                f"{label}: grew past line ceiling current={current_lines} ceiling={ceiling}"
            )

        review_by = record.get("review_by")
        try:
            review_date = (
                date.fromisoformat(review_by) if isinstance(review_by, str) else None
            )
        except ValueError:
            review_date = None
        if review_date is None or review_date.isoformat() != review_by:
            errors.append(f"{label}: review_by must use YYYY-MM-DD")
        elif fail_expired and review_date < effective_date:
            errors.append(f"{label}: hotspot review expired on {review_by}")
        elif review_date > effective_date + timedelta(days=review_window):
            errors.append(
                f"{label}: review_by {review_by} exceeds the {review_window}-day review window"
            )

    if "scan_globs" in manifest:
        errors.append(
            "scan_globs is no longer supported; production discovery is code-owned"
        )
    production_files, discovery_errors = discover_production_files(
        root,
        production_source_trees,
    )
    errors.extend(discovery_errors)
    for source_path in production_files:
        try:
            current_lines = line_count(source_path)
        except (OSError, UnicodeError) as exc:
            relative = source_path.relative_to(root).as_posix()
            errors.append(f"{relative}: cannot count source lines: {exc}")
            continue
        if current_lines <= threshold:
            continue
        relative = source_path.relative_to(root).as_posix()
        if relative not in listed_paths:
            errors.append(
                f"{relative}: new production hotspot exceeds {threshold} lines without metadata"
            )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=WORKSPACE_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--fail-expired", action="store_true")
    parser.add_argument("--as-of", type=date.fromisoformat)
    args = parser.parse_args()

    root = args.root.resolve()
    try:
        manifest_path = resolve_manifest_path(root, args.manifest)
        manifest = load_manifest(manifest_path)
    except HotspotValidationError as exc:
        print(f"architecture-hotspots: ERROR {exc}")
        return 1
    errors = validate_hotspots(
        root,
        manifest,
        fail_expired=args.fail_expired,
        as_of=args.as_of,
    )
    if errors:
        for error in errors:
            print(f"architecture-hotspots: ERROR {error}")
        return 1
    print(f"architecture-hotspots: OK tracked={len(manifest['hotspots'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
