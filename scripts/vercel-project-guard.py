#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROJECT_DIR = ROOT / "TRR-APP"
DEFAULT_EXPECTED_NAME = "trr-app"
DEFAULT_EXPECTED_ID = "prj_MHpStkwr26rV5kjt0f80zqhwZpAs"
KNOWN_NON_PRODUCTION_PROJECTS = {
    ("web", "prj_0nWn8xpm9ikhcvhzE3ma4jUXTe1p"): "sandbox/stale-nested-project",
}


def _load_project(project_dir: Path) -> dict[str, Any]:
    project_file = project_dir / ".vercel" / "project.json"
    if not project_file.is_file():
        raise FileNotFoundError(f"{project_file} does not exist")
    return json.loads(project_file.read_text(encoding="utf-8"))


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Guard Vercel env work against the wrong linked project.")
    parser.add_argument("--project-dir", type=Path, default=DEFAULT_PROJECT_DIR)
    parser.add_argument("--expected-name", default=DEFAULT_EXPECTED_NAME)
    parser.add_argument("--expected-id", default=DEFAULT_EXPECTED_ID)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def _classify_linked_project(name: str, project_id: str, ok: bool) -> str:
    if ok:
        return "production-project-of-record"
    return KNOWN_NON_PRODUCTION_PROJECTS.get((name, project_id), "unknown-project-mismatch")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    project_dir = args.project_dir if args.project_dir.is_absolute() else ROOT / args.project_dir
    try:
        data = _load_project(project_dir)
    except Exception as exc:
        print(f"[vercel-project-guard] ERROR: {exc}", file=sys.stderr)
        return 1

    name = str(data.get("projectName") or "")
    project_id = str(data.get("projectId") or "")
    team_id = str(data.get("orgId") or data.get("teamId") or "")
    ok = name == args.expected_name and project_id == args.expected_id
    classification = _classify_linked_project(name, project_id, ok)
    payload = {
        "projectDir": str(project_dir),
        "projectName": name,
        "projectId": project_id,
        "teamId": team_id,
        "expectedName": args.expected_name,
        "expectedId": args.expected_id,
        "classification": classification,
        "ok": ok,
    }
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    elif ok:
        print(f"[vercel-project-guard] OK: {name} ({project_id})")
    else:
        print(
            "[vercel-project-guard] ERROR: linked project is "
            f"{name or '<missing>'} ({project_id or '<missing>'}); expected "
            f"{args.expected_name} ({args.expected_id}). classification={classification}; "
            "production env mutation is blocked from this directory.",
            file=sys.stderr,
        )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
