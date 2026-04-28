#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - exercised on older local python3 installs.
    tomllib = None  # type: ignore[assignment]


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / ".codex" / "config.toml"
DEFAULT_PROJECT_REF = "vwxfvzutyufrkhfgoeaa"
DEFAULT_TOKEN_ENV = "TRR_SUPABASE_ACCESS_TOKEN"


@dataclass(frozen=True)
class SupabaseMcpConfig:
    project_ref: str
    token_env: str
    url: str


@dataclass(frozen=True)
class AccessResult:
    state: str
    exit_code: int
    project_ref: str
    token_env: str
    http_status: int | None = None
    project_name: str | None = None
    project_status: str | None = None
    api_message: str | None = None
    legacy_generic_token_present: bool = False

    def to_json(self) -> dict[str, Any]:
        return {
            "state": self.state,
            "exit_code": self.exit_code,
            "project_ref": self.project_ref,
            "token_env": self.token_env,
            "http_status": self.http_status,
            "project_name": self.project_name,
            "project_status": self.project_status,
            "api_message": self.api_message,
            "legacy_generic_token_present": self.legacy_generic_token_present,
        }


def _parse_project_ref(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    params = urllib.parse.parse_qs(parsed.query)
    ref = (params.get("project_ref") or [DEFAULT_PROJECT_REF])[0]
    return ref or DEFAULT_PROJECT_REF


def load_config(path: Path) -> SupabaseMcpConfig:
    if not path.exists():
        raise SystemExit(f"[supabase-mcp-access] ERROR: config file not found: {path}")

    data = _load_toml(path)

    server = ((data.get("mcp_servers") or {}).get("supabase") or {})
    if not isinstance(server, dict):
        raise SystemExit("[supabase-mcp-access] ERROR: missing [mcp_servers.supabase] config")

    url = server.get("url")
    if not isinstance(url, str) or not url:
        raise SystemExit("[supabase-mcp-access] ERROR: [mcp_servers.supabase].url is missing")

    token_env = server.get("bearer_token_env_var") or DEFAULT_TOKEN_ENV
    if not isinstance(token_env, str) or not token_env:
        raise SystemExit(
            "[supabase-mcp-access] ERROR: [mcp_servers.supabase].bearer_token_env_var is invalid"
        )

    return SupabaseMcpConfig(
        project_ref=_parse_project_ref(url),
        token_env=token_env,
        url=url,
    )


def _load_toml(path: Path) -> dict[str, Any]:
    if tomllib is not None:
        with path.open("rb") as handle:
            return tomllib.load(handle)

    server: dict[str, str] = {}
    in_supabase_section = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            in_supabase_section = line == "[mcp_servers.supabase]"
            continue
        if not in_supabase_section or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if value.startswith('"') and value.endswith('"'):
            server[key] = value[1:-1]

    return {"mcp_servers": {"supabase": server}}


def _decode_json_body(body: bytes) -> dict[str, Any]:
    try:
        value = json.loads(body.decode("utf-8") or "{}")
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


UrlOpener = Callable[[urllib.request.Request, float], Any]


def check_project_access(
    *,
    project_ref: str,
    token_env: str,
    token: str,
    timeout: float,
    opener: UrlOpener = urllib.request.urlopen,
    legacy_generic_token_present: bool = False,
) -> AccessResult:
    if not token:
        return AccessResult(
            state="missing_token",
            exit_code=2,
            project_ref=project_ref,
            token_env=token_env,
            legacy_generic_token_present=legacy_generic_token_present,
        )

    url = f"https://api.supabase.com/v1/projects/{project_ref}"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "TRR supabase-mcp-access/1.0",
        },
    )

    try:
        with opener(request, timeout=timeout) as response:
            status = int(getattr(response, "status", 200))
            payload = _decode_json_body(response.read())
    except urllib.error.HTTPError as exc:
        status = exc.code
        payload = _decode_json_body(exc.read())
    except urllib.error.URLError as exc:
        return AccessResult(
            state="network_error",
            exit_code=4,
            project_ref=project_ref,
            token_env=token_env,
            api_message=str(exc.reason),
            legacy_generic_token_present=legacy_generic_token_present,
        )

    if status == 200:
        return AccessResult(
            state="ok",
            exit_code=0,
            project_ref=project_ref,
            token_env=token_env,
            http_status=status,
            project_name=payload.get("name") if isinstance(payload.get("name"), str) else None,
            project_status=payload.get("status") if isinstance(payload.get("status"), str) else None,
            legacy_generic_token_present=legacy_generic_token_present,
        )

    state = "permission_blocked" if status in {401, 403} else "api_error"
    return AccessResult(
        state=state,
        exit_code=3 if state == "permission_blocked" else 4,
        project_ref=project_ref,
        token_env=token_env,
        http_status=status,
        api_message=payload.get("message") if isinstance(payload.get("message"), str) else None,
        legacy_generic_token_present=legacy_generic_token_present,
    )


def render_human(result: AccessResult) -> str:
    prefix = "[supabase-mcp-access]"
    lines: list[str] = []

    if result.state == "ok":
        detail = f"project={result.project_ref}"
        if result.project_name:
            detail += f" name={result.project_name}"
        if result.project_status:
            detail += f" status={result.project_status}"
        lines.append(f"{prefix} OK: {result.token_env} can access {detail}.")
        return "\n".join(lines)

    if result.state == "missing_token":
        lines.append(f"{prefix} ERROR: {result.token_env} is not set.")
        if result.legacy_generic_token_present:
            lines.append(
                f"{prefix} NOTE: SUPABASE_ACCESS_TOKEN is set but TRR ignores it to avoid cross-project token reuse."
            )
        lines.append(
            f"{prefix} Impact: Supabase MCP project tools for {result.project_ref} cannot authenticate."
        )
    elif result.state == "permission_blocked":
        lines.append(
            f"{prefix} ERROR: {result.token_env} is set but Supabase returned HTTP {result.http_status} for project {result.project_ref}."
        )
        lines.append(
            f"{prefix} Impact: Supabase MCP tools will fail with MCP error -32600: You do not have permission to perform this action."
        )
        if result.api_message:
            lines.append(f"{prefix} Supabase API message: {result.api_message}")
    else:
        suffix = f"HTTP {result.http_status}" if result.http_status else result.state
        lines.append(f"{prefix} ERROR: could not verify Supabase access for {result.project_ref}: {suffix}.")
        if result.api_message:
            lines.append(f"{prefix} Detail: {result.api_message}")

    lines.append(
        f"{prefix} Remediation: set {result.token_env} to a Supabase personal access token from an account or org that can access TRR core, then restart Codex."
    )
    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check TRR Supabase MCP token access.")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--project-ref")
    parser.add_argument("--token-env")
    parser.add_argument("--timeout", type=float, default=8.0)
    parser.add_argument("--allow-missing", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    config = load_config(args.config)
    project_ref = args.project_ref or config.project_ref
    token_env = args.token_env or config.token_env
    token = os.environ.get(token_env, "").strip()
    legacy_generic_token_present = bool(os.environ.get("SUPABASE_ACCESS_TOKEN")) and token_env != "SUPABASE_ACCESS_TOKEN"

    result = check_project_access(
        project_ref=project_ref,
        token_env=token_env,
        token=token,
        timeout=args.timeout,
        legacy_generic_token_present=legacy_generic_token_present,
    )

    exit_code = 0 if args.allow_missing and result.state == "missing_token" else result.exit_code
    if args.json:
        payload = result.to_json()
        payload["exit_code"] = exit_code
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stream = sys.stdout if exit_code == 0 else sys.stderr
        print(render_human(result), file=stream)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
