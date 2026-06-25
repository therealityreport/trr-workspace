#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXPECTED_NAME = "trr-app"
DEFAULT_EXPECTED_ID = "prj_MHpStkwr26rV5kjt0f80zqhwZpAs"
KNOWN_STALE_PROJECTS = {
    ("web", "prj_0nWn8xpm9ikhcvhzE3ma4jUXTe1p"): "stale-old-web-project",
}
PRUNED_DIRS = {".git", "node_modules", ".next", "dist", "build", ".turbo", ".venv", "__pycache__"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Find stale local Vercel project links in the TRR app checkout.")
    parser.add_argument("--scan-root", type=Path, action="append", default=None)
    parser.add_argument("--expected-name", default=DEFAULT_EXPECTED_NAME)
    parser.add_argument("--expected-id", default=DEFAULT_EXPECTED_ID)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def iter_project_files(scan_root: Path) -> list[Path]:
    project_files: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(scan_root):
        dirnames[:] = [name for name in dirnames if name not in PRUNED_DIRS]
        if Path(dirpath).name == ".vercel" and "project.json" in filenames:
            project_files.append(Path(dirpath) / "project.json")
            dirnames[:] = []
    return sorted(project_files)


def load_project(project_file: Path) -> dict[str, Any]:
    return json.loads(project_file.read_text(encoding="utf-8"))


def classify_project(name: str, project_id: str, expected_name: str, expected_id: str) -> tuple[bool, str]:
    if name == expected_name and project_id == expected_id:
        return True, "project-of-record"
    if (name, project_id) in KNOWN_STALE_PROJECTS:
        return False, KNOWN_STALE_PROJECTS[(name, project_id)]
    if name == expected_name:
        return False, "expected-name-wrong-id"
    if name == "web":
        return False, "stale-web-project-name"
    return False, "unknown-project-link"


def scan_link(project_file: Path, expected_name: str, expected_id: str) -> dict[str, Any]:
    project_dir = project_file.parent.parent
    try:
        data = load_project(project_file)
    except Exception as exc:
        return {
            "ok": False,
            "classification": "unreadable-project-link",
            "projectDir": str(project_dir),
            "projectFile": str(project_file),
            "projectName": "",
            "projectId": "",
            "teamId": "",
            "cleanupPath": str(project_file.parent),
            "error": str(exc),
        }

    name = str(data.get("projectName") or "")
    project_id = str(data.get("projectId") or "")
    team_id = str(data.get("orgId") or data.get("teamId") or "")
    ok, classification = classify_project(name, project_id, expected_name, expected_id)
    return {
        "ok": ok,
        "classification": classification,
        "projectDir": str(project_dir),
        "projectFile": str(project_file),
        "projectName": name,
        "projectId": project_id,
        "teamId": team_id,
        "cleanupPath": str(project_file.parent),
    }


def render_human(results: list[dict[str, Any]], expected_name: str, expected_id: str) -> str:
    if not results:
        return (
            "[vercel-cleanup-doctor] ERROR: no local Vercel project links found.\n"
            f"[vercel-cleanup-doctor] Expected {expected_name} ({expected_id}) under TRR-APP."
        )

    lines: list[str] = []
    for result in results:
        prefix = "OK" if result["ok"] else "CLEANUP"
        lines.append(
            "[vercel-cleanup-doctor] "
            f"{prefix}: {result['projectName'] or '<missing>'} ({result['projectId'] or '<missing>'}) "
            f"at {result['projectFile']} classification={result['classification']}"
        )
        if not result["ok"]:
            lines.append(
                "[vercel-cleanup-doctor]   Local cleanup candidate after dashboard migration checks: "
                f"rm -rf {result['cleanupPath']}"
            )
    if all(result["ok"] for result in results):
        lines.append("[vercel-cleanup-doctor] OK: no stale local Vercel links found.")
    else:
        lines.append(
            "[vercel-cleanup-doctor] Review domains, env vars, integrations, and deployment history before deleting any remote Vercel project."
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    scan_roots = args.scan_root or [ROOT / "TRR-APP"]
    project_files: list[Path] = []
    for scan_root in scan_roots:
        root = scan_root if scan_root.is_absolute() else ROOT / scan_root
        if root.exists():
            project_files.extend(iter_project_files(root))

    results = [scan_link(path, args.expected_name, args.expected_id) for path in sorted(set(project_files))]
    payload = {
        "ok": bool(results) and all(result["ok"] for result in results),
        "expectedName": args.expected_name,
        "expectedId": args.expected_id,
        "links": results,
    }
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(render_human(results, args.expected_name, args.expected_id))
    return 0 if payload["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
