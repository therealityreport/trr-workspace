#!/usr/bin/env python3
"""Enforce shrink-only line ceilings and expiring metadata for architecture hotspots."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import date, timedelta
import json
from pathlib import Path
import subprocess
from typing import Any


WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = Path("docs/workspace/architecture-hotspots.json")
DEFAULT_SCHEMA = Path("docs/workspace/architecture-hotspots.schema.json")
DEFAULT_BASELINE_REF = "origin/main"
VALID_CLASSIFICATIONS = {"existing_hotspot", "temporary_exception"}
REQUIRED_EXCEPTION_FIELDS = (
    "name",
    "path",
    "approver",
    "reason",
    "expires_on",
    "independent_reviewer",
)
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


def load_manifest_schema(root: Path) -> dict[str, Any]:
    """Load the checked-in JSON Schema used to validate the proposed manifest."""

    schema_path = resolve_manifest_path(root, DEFAULT_SCHEMA)
    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HotspotValidationError(
            f"{schema_path}: cannot read schema: {exc}"
        ) from exc
    if not isinstance(schema, dict):
        raise HotspotValidationError(f"{schema_path}: schema must be an object")
    try:
        import jsonschema

        jsonschema.Draft202012Validator.check_schema(schema)
    except ModuleNotFoundError as exc:
        raise HotspotValidationError(
            "architecture-hotspots schema validation requires the jsonschema package"
        ) from exc
    except jsonschema.SchemaError as exc:
        raise HotspotValidationError(
            f"{schema_path}: invalid JSON Schema: {exc.message}"
        ) from exc
    return schema


def validate_manifest_schema(
    manifest: dict[str, Any], schema: dict[str, Any]
) -> list[str]:
    """Return every JSON Schema violation in stable path order."""

    import jsonschema

    validator = jsonschema.Draft202012Validator(
        schema,
        format_checker=jsonschema.Draft202012Validator.FORMAT_CHECKER,
    )
    errors: list[str] = []
    for error in sorted(
        validator.iter_errors(manifest), key=lambda item: list(item.path)
    ):
        location = ".".join(str(part) for part in error.absolute_path) or "$"
        errors.append(f"schema: {location}: {error.message}")
    return errors


def load_baseline_manifest(
    root: Path,
    manifest_path: Path,
    baseline_ref: str,
) -> dict[str, Any]:
    """Read the manifest from an exact Git object, never from the worktree."""

    root = root.resolve()
    try:
        relative_manifest = manifest_path.resolve().relative_to(root).as_posix()
    except ValueError as exc:
        raise HotspotValidationError(
            f"baseline manifest must stay workspace-relative: {manifest_path}"
        ) from exc
    if not baseline_ref.strip():
        raise HotspotValidationError("baseline_ref must not be empty")
    completed = subprocess.run(
        ["git", "-C", str(root), "show", f"{baseline_ref}:{relative_manifest}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise HotspotValidationError(
            f"cannot read baseline manifest from {baseline_ref}: {detail}"
        )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise HotspotValidationError(
            f"baseline manifest from {baseline_ref} is not valid JSON: {exc}"
        ) from exc
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise HotspotValidationError(
            f"baseline manifest from {baseline_ref}: schema_version must be 1"
        )
    return payload


def validate_baseline_ratchet(
    manifest: dict[str, Any],
    baseline_manifest: dict[str, Any],
    *,
    baseline_ref: str,
) -> list[str]:
    """Reject manifest regressions against the exact remote-main Git object."""

    errors: list[str] = []
    proposed_records = manifest.get("hotspots")
    baseline_records = baseline_manifest.get("hotspots")
    if not isinstance(proposed_records, list) or not all(
        isinstance(record, dict) for record in proposed_records
    ):
        return ["hotspots must be an array of objects"]
    if not isinstance(baseline_records, list) or not all(
        isinstance(record, dict) for record in baseline_records
    ):
        return [f"baseline {baseline_ref}: hotspots must be an array of objects"]

    proposed_by_path = {
        record.get("path"): record
        for record in proposed_records
        if isinstance(record.get("path"), str)
    }
    baseline_by_path = {
        record.get("path"): record
        for record in baseline_records
        if isinstance(record.get("path"), str)
    }
    for path, count in sorted(
        Counter(
            record.get("path")
            for record in baseline_records
            if isinstance(record.get("path"), str)
        ).items()
    ):
        if count > 1:
            errors.append(f"baseline {baseline_ref}: duplicate hotspot path: {path}")
    for path in sorted(baseline_by_path):
        if path not in proposed_by_path:
            errors.append(f"{path}: baseline hotspot is missing from proposed manifest")
            continue
        baseline_ceiling = baseline_by_path[path].get("line_ceiling")
        proposed_ceiling = proposed_by_path[path].get("line_ceiling")
        if not _positive_integer(baseline_ceiling):
            errors.append(
                f"baseline {baseline_ref}: {path}: line_ceiling must be a positive integer"
            )
        elif (
            _positive_integer(proposed_ceiling) and proposed_ceiling > baseline_ceiling
        ):
            errors.append(
                f"{path}: line_ceiling increase from baseline {baseline_ceiling} to {proposed_ceiling} is not allowed"
            )
    return errors


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


def validate_ceiling_exceptions(
    manifest: dict[str, Any],
    records_by_path: dict[str, dict[str, Any]],
    measured_lines: dict[str, int],
    *,
    effective_date: date,
    review_window: int,
) -> tuple[list[str], set[str]]:
    """Validate path-scoped temporary permission for a measured ceiling overage."""

    errors: list[str] = []
    active_paths: set[str] = set()
    exceptions = manifest.get("ceiling_exceptions")
    if not isinstance(exceptions, list) or not all(
        isinstance(exception, dict) for exception in exceptions
    ):
        return ["ceiling_exceptions must be an array of objects"], active_paths

    names: Counter[str] = Counter()
    paths: Counter[str] = Counter()
    for index, exception in enumerate(exceptions):
        label = f"ceiling_exceptions[{index}]"
        complete = True
        for field in REQUIRED_EXCEPTION_FIELDS:
            value = exception.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{label}: missing {field}")
                complete = False
        name = exception.get("name")
        path = exception.get("path")
        if isinstance(name, str) and name.strip():
            names[name] += 1
        if isinstance(path, str) and path.strip():
            paths[path] += 1
        expires_on = exception.get("expires_on")
        try:
            expiration = (
                date.fromisoformat(expires_on) if isinstance(expires_on, str) else None
            )
        except ValueError:
            expiration = None
        if expiration is None or expiration.isoformat() != expires_on:
            errors.append(f"{label}: expires_on must use YYYY-MM-DD")
            complete = False
        elif expiration < effective_date:
            errors.append(f"{label}: ceiling exception expired on {expires_on}")
            complete = False
        elif expiration > effective_date + timedelta(days=review_window):
            errors.append(
                f"{label}: expires_on {expires_on} exceeds the {review_window}-day review window"
            )
            complete = False
        if not isinstance(path, str) or path not in records_by_path:
            errors.append(f"{label}: path must identify a hotspot record")
            complete = False
        elif path not in measured_lines:
            complete = False
        elif measured_lines[path] <= records_by_path[path]["line_ceiling"]:
            errors.append(
                f"{label}: exception path is not currently over its stored ceiling"
            )
            complete = False
        if complete and isinstance(path, str):
            active_paths.add(path)

    for name, count in sorted(names.items()):
        if count > 1:
            errors.append(f"duplicate ceiling exception name: {name}")
            for exception in exceptions:
                if exception.get("name") == name:
                    active_paths.discard(exception.get("path"))
    for path, count in sorted(paths.items()):
        if count > 1:
            errors.append(f"duplicate ceiling exception path: {path}")
            active_paths.discard(path)
    return errors, active_paths


def validate_hotspots(
    root: Path,
    manifest: dict[str, Any],
    *,
    fail_expired: bool = False,
    as_of: date | None = None,
    production_source_trees: tuple[
        tuple[Path, frozenset[str]], ...
    ] = PRODUCTION_SOURCE_TREES,
) -> list[str]:
    errors: list[str] = []
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
    records_by_path: dict[str, dict[str, Any]] = {}
    measured_lines: dict[str, int] = {}
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
        records_by_path[relative] = record
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
        current_lines = line_count(source_path)
        measured_lines[relative] = current_lines

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

    exception_errors, active_exception_paths = validate_ceiling_exceptions(
        manifest,
        records_by_path,
        measured_lines,
        effective_date=effective_date,
        review_window=review_window,
    )
    errors.extend(exception_errors)
    for relative, current_lines in measured_lines.items():
        ceiling = records_by_path[relative].get("line_ceiling")
        if current_lines > ceiling and relative not in active_exception_paths:
            errors.append(
                f"{relative}: grew past line ceiling current={current_lines} ceiling={ceiling}"
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
    parser.add_argument(
        "--baseline-ref",
        default=DEFAULT_BASELINE_REF,
        help="Git ref containing the exact workspace baseline manifest (default: origin/main)",
    )
    parser.add_argument("--fail-expired", action="store_true")
    parser.add_argument("--as-of", type=date.fromisoformat)
    args = parser.parse_args()

    root = args.root.resolve()
    try:
        manifest_path = resolve_manifest_path(root, args.manifest)
        manifest = load_manifest(manifest_path)
        schema = load_manifest_schema(root)
        baseline_manifest = load_baseline_manifest(
            root,
            manifest_path,
            args.baseline_ref,
        )
    except HotspotValidationError as exc:
        print(f"architecture-hotspots: ERROR {exc}")
        return 1
    errors = validate_manifest_schema(manifest, schema)
    errors.extend(
        validate_hotspots(
            root,
            manifest,
            fail_expired=args.fail_expired,
            as_of=args.as_of,
        )
    )
    errors.extend(
        validate_baseline_ratchet(
            manifest,
            baseline_manifest,
            baseline_ref=args.baseline_ref,
        )
    )
    if errors:
        for error in errors:
            print(f"architecture-hotspots: ERROR {error}")
        return 1
    print(f"architecture-hotspots: OK tracked={len(manifest['hotspots'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
