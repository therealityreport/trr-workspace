#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


@dataclass
class CommandResult:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


def run_command(app_root: Path, *args: str) -> CommandResult:
    command = ["bash", str(app_root / "scripts" / "vercel.sh"), *args]
    result = subprocess.run(
        command,
        cwd=app_root,
        capture_output=True,
        text=True,
        check=False,
    )
    return CommandResult(
        command=command,
        returncode=result.returncode,
        stdout=result.stdout,
        stderr=result.stderr,
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check local Vercel CLI access to the TRR team.")
    parser.add_argument("--app-root", type=Path, default=ROOT / "TRR-APP")
    parser.add_argument("--project-name", default="trr-app")
    parser.add_argument("--team-slug", default="the-reality-reports-projects")
    parser.add_argument("--team-id", default="team_EUsG2kN9TAvVDGOu4yZVEoCX")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def last_content_line(output: str) -> str:
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    non_banner = [line for line in lines if not line.startswith("Vercel CLI ")]
    return non_banner[-1] if non_banner else ""


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    app_root = args.app_root if args.app_root.is_absolute() else ROOT / args.app_root

    whoami = run_command(app_root, "whoami")
    teams = run_command(app_root, "teams", "ls")
    project_list = run_command(app_root, "project", "list", "--scope", args.team_slug)
    selected_scope = args.team_slug
    if project_list.returncode != 0 and args.team_id:
        fallback = run_command(app_root, "project", "list", "--scope", args.team_id)
        if fallback.returncode == 0:
            project_list = fallback
            selected_scope = args.team_id

    whoami_name = last_content_line(whoami.stdout)
    teams_text = teams.stdout + teams.stderr
    project_list_text = project_list.stdout + project_list.stderr
    team_visible = args.team_slug in teams_text or args.team_id in teams_text or "The Reality Report" in teams_text
    project_visible = args.project_name in project_list_text
    ok = whoami.returncode == 0 and teams.returncode == 0 and project_list.returncode == 0 and team_visible and project_visible

    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "ok": ok,
        "whoami": whoami_name,
        "expectedProject": args.project_name,
        "expectedTeamSlug": args.team_slug,
        "expectedTeamId": args.team_id,
        "selectedProjectListScope": selected_scope,
        "teamVisible": team_visible,
        "projectVisible": project_visible,
        "commands": {
            "whoami": asdict(whoami),
            "teams": asdict(teams),
            "projectList": asdict(project_list),
        },
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    elif ok:
        print(f"[vercel-auth-doctor] OK: local CLI user {whoami_name} can access {args.project_name} in {selected_scope}.")
    else:
        print("[vercel-auth-doctor] ERROR: local Vercel CLI cannot access the TRR project of record.", file=sys.stderr)
        print(f"[vercel-auth-doctor] whoami={whoami_name or '<unavailable>'}", file=sys.stderr)
        print(f"[vercel-auth-doctor] team_visible={team_visible} project_visible={project_visible}", file=sys.stderr)
        print("[vercel-auth-doctor] Run `TRR-APP/scripts/vercel.sh login` with the TRR Vercel account, then rerun this doctor.", file=sys.stderr)

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
