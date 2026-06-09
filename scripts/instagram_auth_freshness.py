from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
BACKEND_ROOT = ROOT / "TRR-Backend"
DEFAULT_COOKIE_FILES = (
    BACKEND_ROOT / "data" / "instagram_cookies.json",
    BACKEND_ROOT / "scripts" / "socials" / "instagram" / "instagram_cookies.json",
)
ENV_COOKIE_FILE_KEYS = ("SOCIAL_INSTAGRAM_COOKIES_FILE", "INSTAGRAM_COOKIES_FILE")
DEFAULT_MAX_AGE_DAYS = 14


def _python_command() -> str:
    repo_python = BACKEND_ROOT / ".venv" / "bin" / "python"
    if repo_python.is_file():
        return str(repo_python)
    return sys.executable or "python3"


def _max_age_seconds() -> int:
    raw = str(
        os.getenv("WORKSPACE_INSTAGRAM_AUTH_FRESHNESS_MAX_AGE_DAYS")
        or os.getenv("TRR_INSTAGRAM_AUTH_FRESHNESS_MAX_AGE_DAYS")
        or DEFAULT_MAX_AGE_DAYS
    ).strip()
    try:
        days = float(raw)
    except ValueError:
        days = float(DEFAULT_MAX_AGE_DAYS)
    return max(1, int(days * 24 * 60 * 60))


def _timeout_seconds() -> int:
    raw = str(os.getenv("WORKSPACE_INSTAGRAM_AUTH_FRESHNESS_TIMEOUT_SECONDS") or "150").strip()
    try:
        parsed = int(raw)
    except ValueError:
        parsed = 150
    return max(30, parsed)


def _parse_json_output(stdout: str) -> dict[str, Any]:
    stripped = str(stdout or "").strip()
    if stripped:
        try:
            payload = json.loads(stripped)
            if isinstance(payload, dict):
                return payload
        except json.JSONDecodeError:
            pass
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
    return {}


def _resolve_cookie_path(raw_path: str) -> Path:
    path = Path(raw_path).expanduser()
    if path.is_absolute():
        return path
    return ROOT / path


def _cookie_file_candidates() -> tuple[Path, ...]:
    env_paths: list[Path] = []
    for key in ENV_COOKIE_FILE_KEYS:
        raw = str(os.getenv(key) or "").strip()
        if raw:
            env_paths.append(_resolve_cookie_path(raw))
    candidates = env_paths or list(DEFAULT_COOKIE_FILES)
    deduped: list[Path] = []
    seen: set[str] = set()
    for path in candidates:
        label = str(path)
        if label in seen:
            continue
        seen.add(label)
        deduped.append(path)
    return tuple(deduped)


def _cookie_file_status(now: float | None = None) -> list[dict[str, Any]]:
    current_time = time.time() if now is None else now
    statuses: list[dict[str, Any]] = []
    for path in _cookie_file_candidates():
        try:
            stat = path.stat()
        except FileNotFoundError:
            statuses.append({"path": str(path), "present": False, "age_seconds": None})
            continue
        statuses.append(
            {
                "path": str(path),
                "present": True,
                "age_seconds": max(0, int(current_time - stat.st_mtime)),
            }
        )
    return statuses


def _render_age(seconds: int | None) -> str:
    if seconds is None:
        return "unknown"
    if seconds < 90:
        return f"{seconds}s"
    minutes = seconds // 60
    if minutes < 90:
        return f"{minutes}m"
    hours = minutes // 60
    if hours < 48:
        return f"{hours}h"
    return f"{hours // 24}d"


def check_instagram_auth_freshness() -> dict[str, Any]:
    cookie_files = _cookie_file_status()
    present_ages = [int(item["age_seconds"]) for item in cookie_files if item.get("present") and item["age_seconds"] is not None]
    newest_cookie_age_seconds = min(present_ages) if present_ages else None
    missing_cookie_files = [item["path"] for item in cookie_files if not item.get("present")]

    command = [
        _python_command(),
        "scripts/modal/repair_instagram_auth.py",
        "--validate-local-only",
        "--json",
    ]
    try:
        completed = subprocess.run(
            command,
            cwd=BACKEND_ROOT,
            capture_output=True,
            text=True,
            check=False,
            timeout=_timeout_seconds(),
        )
    except subprocess.TimeoutExpired:
        return {
            "state": "advisory",
            "ok": False,
            "reason": "instagram_auth_freshness_timeout",
            "remediation": "Local Instagram auth validation timed out; no refresh or Modal update was attempted.",
            "cookie_files": cookie_files,
            "newest_cookie_age_seconds": newest_cookie_age_seconds,
            "side_effects": {
                "cookie_refresh": False,
                "modal_secret_apply": False,
                "modal_deploy": False,
                "remote_verify": False,
            },
        }

    payload = _parse_json_output(completed.stdout)
    validation_ok = bool(payload.get("ok")) and completed.returncode == 0
    failure_reason = str(payload.get("failure_reason") or "").strip() or None
    side_effects = {
        "cookie_refresh": False,
        "modal_secret_apply": bool(payload.get("modal_secret_apply_reached")),
        "modal_deploy": bool(payload.get("modal_deploy_reached")),
        "remote_verify": bool(payload.get("remote_verify_reached")),
    }

    max_age = _max_age_seconds()
    stale = newest_cookie_age_seconds is None or newest_cookie_age_seconds > max_age
    if not validation_ok:
        return {
            "state": "advisory",
            "ok": False,
            "reason": failure_reason or "instagram_auth_validation_failed",
            "remediation": "Local Instagram auth is not fresh; no refresh or Modal update was attempted.",
            "cookie_files": cookie_files,
            "missing_cookie_files": missing_cookie_files,
            "newest_cookie_age_seconds": newest_cookie_age_seconds,
            "max_age_seconds": max_age,
            "validation": payload,
            "side_effects": side_effects,
        }
    if stale:
        reason = (
            "instagram_auth_cookie_file_missing"
            if newest_cookie_age_seconds is None
            else "instagram_auth_cookie_age_exceeds_threshold"
        )
        return {
            "state": "advisory",
            "ok": True,
            "reason": reason,
            "remediation": "Cookies still validate, but the active configured cookie file is missing or older than the preflight freshness threshold.",
            "cookie_files": cookie_files,
            "missing_cookie_files": missing_cookie_files,
            "newest_cookie_age_seconds": newest_cookie_age_seconds,
            "max_age_seconds": max_age,
            "validation": payload,
            "side_effects": side_effects,
        }
    return {
        "state": "ok",
        "ok": True,
        "reason": None,
        "cookie_files": cookie_files,
        "missing_cookie_files": missing_cookie_files,
        "newest_cookie_age_seconds": newest_cookie_age_seconds,
        "max_age_seconds": max_age,
        "validation": payload,
        "side_effects": side_effects,
    }


def render_summary(payload: dict[str, Any]) -> str:
    state = str(payload.get("state") or "advisory").strip()
    age = _render_age(payload.get("newest_cookie_age_seconds"))
    if state == "ok":
        return f"[preflight] Instagram auth freshness OK (validated; newest cookie age {age})"
    reason = str(payload.get("reason") or "instagram_auth_freshness_advisory").strip()
    return f"[preflight] Instagram auth freshness ADVISORY ({reason}; no refresh attempted)"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Safely validate local Instagram auth freshness for preflight.")
    parser.add_argument("--json", action="store_true", help="Emit structured JSON instead of a preflight summary line.")
    args = parser.parse_args(argv)

    payload = check_instagram_auth_freshness()
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(render_summary(payload))
    strict = str(os.getenv("WORKSPACE_PREFLIGHT_STRICT") or "0").strip() == "1"
    return 1 if strict and payload.get("state") != "ok" else 0


if __name__ == "__main__":
    raise SystemExit(main())
