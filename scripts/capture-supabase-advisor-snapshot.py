#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / ".codex" / "config.toml"
DEFAULT_OUTPUT_DIR = ROOT / "docs" / "workspace" / "supabase-advisor-snapshots"
ADVISOR_TYPES = ("performance", "security")
USER_AGENT = "TRR supabase-advisor-snapshot/1.0"


UrlOpener = Callable[[urllib.request.Request, float], Any]


@dataclass(frozen=True)
class AdvisorFetchResult:
    advisor_type: str
    url: str
    status: int | None
    payload: dict[str, Any] | None = None
    message: str | None = None

    @property
    def ok(self) -> bool:
        return self.status == 200 and self.payload is not None

    @property
    def lint_count(self) -> int | None:
        if not self.payload:
            return None
        lints = self.payload.get("lints")
        return len(lints) if isinstance(lints, list) else None


@dataclass(frozen=True)
class SnapshotResult:
    project_ref: str
    token_env: str
    output_dir: Path
    manifest_path: Path
    summary_path: Path
    captured_at: str
    fetches: tuple[AdvisorFetchResult, ...]
    saved_files: dict[str, Path] = field(default_factory=dict)

    @property
    def exit_code(self) -> int:
        return 0 if all(fetch.ok for fetch in self.fetches) else 4


def _load_mcp_access_module():
    module_path = ROOT / "scripts" / "check-supabase-mcp-access.py"
    spec = importlib.util.spec_from_file_location("check_supabase_mcp_access", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {module_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _decode_json_body(body: bytes) -> dict[str, Any]:
    try:
        value = json.loads(body.decode("utf-8") or "{}")
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


def _advisor_url(project_ref: str, advisor_type: str) -> str:
    return f"https://api.supabase.com/v1/projects/{project_ref}/advisors/{advisor_type}"


def fetch_advisor(
    *,
    advisor_type: str,
    project_ref: str,
    token: str,
    timeout: float,
    opener: UrlOpener = urllib.request.urlopen,
) -> AdvisorFetchResult:
    if advisor_type not in ADVISOR_TYPES:
        raise ValueError(f"unsupported advisor type: {advisor_type}")

    url = _advisor_url(project_ref, advisor_type)
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": USER_AGENT,
        },
    )

    try:
        with opener(request, timeout=timeout) as response:
            status = int(getattr(response, "status", 200))
            payload = _decode_json_body(response.read())
    except urllib.error.HTTPError as exc:
        payload = _decode_json_body(exc.read())
        return AdvisorFetchResult(
            advisor_type=advisor_type,
            url=url,
            status=exc.code,
            payload=payload or None,
            message=payload.get("message") if isinstance(payload.get("message"), str) else exc.reason,
        )
    except urllib.error.URLError as exc:
        return AdvisorFetchResult(
            advisor_type=advisor_type,
            url=url,
            status=None,
            message=str(exc.reason),
        )

    message = payload.get("message") if status != 200 and isinstance(payload.get("message"), str) else None
    return AdvisorFetchResult(
        advisor_type=advisor_type,
        url=url,
        status=status,
        payload=payload if status == 200 else payload or None,
        message=message,
    )


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def _display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def _render_summary_markdown(
    *,
    project_ref: str,
    token_env: str,
    captured_at: str,
    output_dir: Path,
    manifest_path: Path,
    fetches: list[AdvisorFetchResult],
    saved_files: dict[str, Path],
) -> str:
    lines = [
        f"# Supabase Advisor Snapshot - {output_dir.name}",
        "",
        f"Captured at: `{captured_at}`",
        f"Project ref: `{project_ref}`",
        f"Token env: `{token_env}`",
        "Source: Supabase Management API",
        "",
        "## Artifacts",
        "",
        f"- Manifest: `{_display_path(manifest_path)}`",
    ]

    for fetch in fetches:
        if fetch.advisor_type in saved_files:
            lines.append(f"- {fetch.advisor_type.title()} JSON: `{_display_path(saved_files[fetch.advisor_type])}`")
    lines.extend(
        [
            "",
            "## Status",
            "",
            "| Advisor | Status | Lint Count | Artifact |",
            "|---|---:|---:|---|",
        ]
    )
    for fetch in fetches:
        status = f"HTTP {fetch.status}" if fetch.status is not None else "network_error"
        artifact = f"`{_display_path(saved_files[fetch.advisor_type])}`" if fetch.advisor_type in saved_files else ""
        count = str(fetch.lint_count) if fetch.lint_count is not None else ""
        lines.append(f"| {fetch.advisor_type} | {status} | {count} | {artifact} |")

    failed = [fetch for fetch in fetches if not fetch.ok]
    if failed:
        lines.extend(["", "## Failures", ""])
        for fetch in failed:
            status = f"HTTP {fetch.status}" if fetch.status is not None else "network_error"
            detail = f" - {fetch.message}" if fetch.message else ""
            lines.append(f"- `{fetch.advisor_type}` failed with {status}{detail}.")

    lines.extend(
        [
            "",
            "## Reproduction",
            "",
            "```bash",
            "make supabase-advisor-snapshot",
            "```",
            "",
            "This workflow intentionally uses `TRR_SUPABASE_ACCESS_TOKEN`, not the generic `SUPABASE_ACCESS_TOKEN`.",
            "",
        ]
    )
    return "\n".join(lines)


def capture_snapshot(
    *,
    project_ref: str,
    token_env: str,
    token: str,
    output_root: Path,
    snapshot_date: str,
    timeout: float,
    opener: UrlOpener = urllib.request.urlopen,
) -> SnapshotResult:
    captured_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    output_dir = output_root / snapshot_date
    output_dir.mkdir(parents=True, exist_ok=True)

    fetches: list[AdvisorFetchResult] = []
    saved_files: dict[str, Path] = {}
    for advisor_type in ADVISOR_TYPES:
        fetch = fetch_advisor(
            advisor_type=advisor_type,
            project_ref=project_ref,
            token=token,
            timeout=timeout,
            opener=opener,
        )
        fetches.append(fetch)
        if fetch.ok and fetch.payload is not None:
            path = output_dir / f"{advisor_type}.json"
            _write_json(path, fetch.payload)
            saved_files[advisor_type] = path

    manifest = {
        "captured_at": captured_at,
        "project_ref": project_ref,
        "token_env": token_env,
        "source": "Supabase Management API",
        "user_agent": USER_AGENT,
        "advisors": {
            fetch.advisor_type: {
                "endpoint": fetch.url,
                "http_status": fetch.status,
                "ok": fetch.ok,
                "lint_count": fetch.lint_count,
                "artifact": _display_path(saved_files[fetch.advisor_type])
                if fetch.advisor_type in saved_files
                else None,
                "message": fetch.message,
            }
            for fetch in fetches
        },
    }
    manifest_path = output_dir / "manifest.json"
    _write_json(manifest_path, manifest)
    summary_path = output_dir / "summary.md"
    _write_text(
        summary_path,
        _render_summary_markdown(
            project_ref=project_ref,
            token_env=token_env,
            captured_at=captured_at,
            output_dir=output_dir,
            manifest_path=manifest_path,
            fetches=fetches,
            saved_files=saved_files,
        ),
    )

    return SnapshotResult(
        project_ref=project_ref,
        token_env=token_env,
        output_dir=output_dir,
        manifest_path=manifest_path,
        summary_path=summary_path,
        captured_at=captured_at,
        fetches=tuple(fetches),
        saved_files=saved_files,
    )


def render_snapshot_result(result: SnapshotResult) -> str:
    prefix = "[supabase-advisor-snapshot]"
    relative_output = _display_path(result.output_dir)
    lines = [
        f"{prefix} {'OK' if result.exit_code == 0 else 'ERROR'}: advisor snapshot for project {result.project_ref}.",
        f"{prefix} Output: {relative_output}",
    ]

    for fetch in result.fetches:
        status = f"HTTP {fetch.status}" if fetch.status is not None else "network_error"
        if fetch.ok:
            artifact = _display_path(result.saved_files[fetch.advisor_type])
            count = fetch.lint_count if fetch.lint_count is not None else "unknown"
            lines.append(f"{prefix} {fetch.advisor_type}: {status}, lints={count}, artifact={artifact}")
            continue

        lines.append(f"{prefix} {fetch.advisor_type}: ERROR {status} at {fetch.url}")
        if fetch.message:
            lines.append(f"{prefix} {fetch.advisor_type}: detail={fetch.message}")
        if fetch.status in {401, 403}:
            lines.append(
                f"{prefix} {fetch.advisor_type}: {result.token_env} can reach the project check only if preflight passed, but the advisor endpoint still requires advisor read permission."
            )
        elif fetch.status == 404:
            lines.append(
                f"{prefix} {fetch.advisor_type}: endpoint not found; Supabase documents advisor endpoints as experimental/deprecated, so keep the manifest as evidence and re-check the Management API contract."
            )

    lines.append(f"{prefix} Manifest: {_display_path(result.manifest_path)}")
    lines.append(f"{prefix} Summary: {_display_path(result.summary_path)}")
    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture TRR Supabase advisor JSON snapshots.")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--project-ref")
    parser.add_argument("--token-env")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--date", default=datetime.now().date().isoformat())
    parser.add_argument("--timeout", type=float, default=20.0)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    mcp_access = _load_mcp_access_module()
    config = mcp_access.load_config(args.config)
    project_ref = args.project_ref or config.project_ref
    token_env = args.token_env or config.token_env
    token = os.environ.get(token_env, "").strip()
    legacy_generic_token_present = bool(os.environ.get("SUPABASE_ACCESS_TOKEN")) and token_env != "SUPABASE_ACCESS_TOKEN"

    access_result = mcp_access.check_project_access(
        project_ref=project_ref,
        token_env=token_env,
        token=token,
        timeout=args.timeout,
        legacy_generic_token_present=legacy_generic_token_present,
    )
    if access_result.exit_code != 0:
        print(mcp_access.render_human(access_result), file=sys.stderr)
        print(
            "[supabase-advisor-snapshot] Advisor snapshots require the TRR Management API token to read the project and advisors. "
            "For fine-grained Supabase tokens, include advisors_read; OAuth flows need database:read.",
            file=sys.stderr,
        )
        return access_result.exit_code

    result = capture_snapshot(
        project_ref=project_ref,
        token_env=token_env,
        token=token,
        output_root=args.output_dir,
        snapshot_date=args.date,
        timeout=args.timeout,
    )

    stream = sys.stdout if result.exit_code == 0 else sys.stderr
    print(render_snapshot_result(result), file=stream)
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
