#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "docs/workspace/shared-env-manifest.json"

AUTHORITY_KEYS = (
    "runtime_profile_adapters",
    "surface_setup_adapters",
)
LOCAL_SECRET_KEY = "local_secret_adapters"
RETIRED_ENV_KEY = "retired_env_surfaces"
SNAPSHOT_KEY = "evidence_snapshots"
ENV_FILE_AUTHORITY_KEYS = (
    "runtime_profile_adapters",
    "surface_setup_adapters",
    LOCAL_SECRET_KEY,
    RETIRED_ENV_KEY,
    SNAPSHOT_KEY,
)
TRUTHY_VALUES = frozenset({"1", "true", "yes", "on"})

DEPRECATED_RUNTIME_NAMES = frozenset({"DATABASE_URL", "SUPABASE_DB_URL"})
APP_LOCAL_DEPRECATED_NAMES = frozenset({"SUPABASE_SERVICE_ROLE_KEY"})
SHARED_KEY_PREFIXES = (
    "TRR_",
    "WORKSPACE_",
    "POSTGRES_",
    "SUPABASE_",
    "DATABASE_",
    "ADMIN_",
    "NEXT_PUBLIC_SUPABASE_",
    "SCREENALYTICS_",
)


@dataclass(frozen=True)
class EnvSurface:
    authority: str
    path: Path


@dataclass(frozen=True)
class Finding:
    severity: str
    surface: str
    key: str
    message: str


@dataclass(frozen=True)
class CleanupAction:
    status: str
    authority: str
    surface: str
    key: str
    reason: str


def _load_manifest(path: Path = MANIFEST_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _parse_env_file(path: Path) -> set[str]:
    keys: set[str] = set()
    if not path.is_file():
        return keys
    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key = line.split("=", 1)[0].strip()
        if key.startswith("export "):
            key = key.removeprefix("export ").strip()
        if key and key.replace("_", "").isalnum():
            keys.add(key)
    return keys


def _include_adjacent_env_surfaces() -> bool:
    raw = os.getenv("WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT", "")
    return raw.strip().lower() in TRUTHY_VALUES


def _expand_manifest_surfaces(manifest: dict, authority_key: str) -> list[EnvSurface]:
    if authority_key == RETIRED_ENV_KEY and not _include_adjacent_env_surfaces():
        return []
    surfaces: list[EnvSurface] = []
    for raw_path in manifest.get("authority_surfaces", {}).get(authority_key, []):
        if any(char in raw_path for char in "*?["):
            for path in sorted(ROOT.glob(raw_path)):
                if path.is_file():
                    surfaces.append(EnvSurface(authority_key, path))
            continue
        surfaces.append(EnvSurface(authority_key, ROOT / raw_path))
    return surfaces


def _manifest_exact_keys(manifest: dict) -> dict[str, dict]:
    exact: dict[str, dict] = {}
    for group_name in ("canonical", "transitional"):
        group = manifest.get(group_name, {})
        if isinstance(group, dict):
            for key, metadata in group.items():
                exact[key] = metadata if isinstance(metadata, dict) else {}
    return exact


def _is_shared_candidate(key: str) -> bool:
    return key.startswith(SHARED_KEY_PREFIXES) or key in DEPRECATED_RUNTIME_NAMES


def _owner_for_key(key: str, manifest: dict) -> str | None:
    exact = _manifest_exact_keys(manifest)
    if key in exact:
        owner = exact[key].get("owner")
        return str(owner) if owner else None
    for rule in manifest.get("shared_key_patterns", []):
        pattern = rule.get("pattern")
        owner = rule.get("owner")
        if pattern and owner and fnmatch.fnmatchcase(key, pattern):
            return str(owner)
    return None


def _retired_screenalytics_classification(manifest: dict, key: str) -> tuple[str, str | None] | None:
    policy = manifest.get("retired_screenalytics_env", {})
    if not isinstance(policy, dict):
        return None

    if key in set(policy.get("retain", [])):
        return ("retain", None)
    if key in set(policy.get("retire", [])):
        return ("retire", None)
    for item in policy.get("rename", []):
        if not isinstance(item, dict):
            continue
        if item.get("key") == key:
            replacement = item.get("replacement")
            return ("rename", str(replacement) if replacement else None)
    return None


def _surface_label(surface: EnvSurface) -> str:
    return str(surface.path.relative_to(ROOT))


def _action(status: str, surface: EnvSurface, key: str, reason: str) -> CleanupAction:
    return CleanupAction(status, surface.authority, _surface_label(surface), key, reason)


def _status_for_key(surface: EnvSurface, key: str, manifest: dict | None = None) -> CleanupAction:
    surface_label = _surface_label(surface)
    active_manifest = manifest or _load_manifest()

    if surface.authority == SNAPSHOT_KEY:
        return _action("keep", surface, key, "evidence snapshot; report only and do not edit generated/pulled env evidence")

    if surface.authority in AUTHORITY_KEYS:
        if key in DEPRECATED_RUNTIME_NAMES:
            return _action("remove", surface, key, "deprecated runtime name is not allowed in checked-in profile/example adapters")
        if surface_label == "TRR-APP/apps/web/.env.example" and key in APP_LOCAL_DEPRECATED_NAMES:
            return _action("remove", surface, key, "TRR-APP setup adapter must use TRR_CORE_SUPABASE_SERVICE_ROLE_KEY instead")
        return _action("keep", surface, key, "checked-in profile/setup adapter key")

    is_retired_env_surface = surface.authority == RETIRED_ENV_KEY

    if surface.authority not in {LOCAL_SECRET_KEY, RETIRED_ENV_KEY}:
        return _action("keep", surface, key, "env key in non-local surface; no cleanup rule matched")

    if is_retired_env_surface:
        classification = _retired_screenalytics_classification(active_manifest, key)
        if classification:
            status, replacement = classification
            if status == "retain":
                owner = _owner_for_key(key, active_manifest) or "supported workspace/backend owner"
                return _action("keep", surface, key, f"retired Screenalytics env surface; retained key is owned by {owner}")
            if status == "rename":
                suffix = f"; use {replacement} for new configuration" if replacement else ""
                return _action("move", surface, key, f"retired Screenalytics env surface; legacy key should be renamed{suffix}")
            if status == "retire":
                return _action("remove", surface, key, "retired Screenalytics env surface; key is not current TRR workspace authority")
        if key.startswith("SCREENALYTICS_") or key.startswith("TRR_SCREENALYTICS_"):
            return _action("remove", surface, key, "retired Screenalytics env surface; unclassified Screenalytics-prefixed key should not become current authority")
        if key.startswith("SUPABASE_DB_") or key in {"DB_URL", "DATABASE_URL", "SUPABASE_DB_URL"}:
            return _action("remove", surface, key, "retired Screenalytics DB key; use supported TRR_DB_* owners when a value still matters")
        if _is_shared_candidate(key):
            return _action("move", surface, key, "retired Screenalytics env surface; move any surviving shared key to a supported Backend/App/workspace owner")
        return _action("keep", surface, key, "retired Screenalytics local-only key; preserve file without treating it as TRR workspace authority")

    if not _is_shared_candidate(key):
        return _action("keep", surface, key, "surface-local key is not part of the shared TRR env contract")

    if key in DEPRECATED_RUNTIME_NAMES:
        return _action("remove", surface, key, "deprecated runtime name; use TRR_DB_* lanes instead")

    is_app = surface_label == "TRR-APP/apps/web/.env.local"
    is_app_production = surface_label == "TRR-APP/apps/web/.env.production.local"
    is_backend = surface_label == "TRR-Backend/.env"
    if is_app or is_app_production:
        if key in {"TRR_CORE_SUPABASE_URL", "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY"}:
            return _action("keep", surface, key, "TRR-APP server/admin Supabase contract")
        if key in {"SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_JWT_SECRET"}:
            return _action("remove", surface, key, "legacy app-local Supabase key; TRR-APP uses TRR_CORE_SUPABASE_*")
        if key.startswith("NEXT_PUBLIC_SUPABASE_"):
            return _action("remove", surface, key, "browser Supabase is explicit-feature-only and not part of the active TRR-APP runtime")
        if key in {"POSTGRES_POOL_MAX", "POSTGRES_MAX_CONCURRENT_OPERATIONS", "POSTGRES_APPLICATION_NAME"}:
            return _action("keep", surface, key, "TRR-APP Postgres pool/application-name control")
        if key == "TRR_DB_APPLICATION_NAME":
            return _action("remove", surface, key, "backend-only DB application-name label")
        if key in {
            "TRR_DB_DIRECT_URL",
            "TRR_DB_SESSION_URL",
            "TRR_DB_URL",
            "TRR_DB_FALLBACK_URL",
        }:
            return _action("keep", surface, key, "TRR-APP server Postgres runtime lane")
        if key in {"TRR_DB_TRANSACTION_URL", "TRR_DB_RUNTIME_LANE", "TRR_DB_TRANSACTION_FLIGHT_TEST"}:
            return _action("move", surface, key, "transaction DB lane should be a scoped flight-test shell/profile override")

    if is_backend:
        if key in {"SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_JWT_SECRET"}:
            return _action("keep", surface, key, "backend Supabase API/auth contract")
        if key in {"TRR_CORE_SUPABASE_URL", "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY"}:
            return _action("move", surface, key, "TRR-APP/admin-read-model key; keep in backend only for named ops scripts")
        if key in {"TRR_DB_DIRECT_URL", "TRR_DB_SESSION_URL", "TRR_DB_URL", "TRR_DB_FALLBACK_URL"}:
            return _action("keep", surface, key, "backend Postgres runtime lane")
        if key in {"TRR_DB_TRANSACTION_URL", "TRR_DB_RUNTIME_LANE", "TRR_DB_TRANSACTION_FLIGHT_TEST"}:
            return _action("move", surface, key, "transaction DB lane should be a scoped flight-test shell/profile override")
        if key == "TRR_DB_APPLICATION_NAME":
            return _action("keep", surface, key, "backend DB application-name label")
        if key in {"POSTGRES_POOL_MAX", "POSTGRES_MAX_CONCURRENT_OPERATIONS", "POSTGRES_APPLICATION_NAME"}:
            return _action("remove", surface, key, "TRR-APP-only Postgres pool/application-name control")

    return _action("keep", surface, key, "shared key is present in local adapter; no specific cleanup rule matched")


def _collect_cleanup_actions(manifest: dict) -> list[CleanupAction]:
    actions: list[CleanupAction] = []
    for authority_key in ENV_FILE_AUTHORITY_KEYS:
        for surface in _expand_manifest_surfaces(manifest, authority_key):
            for key in sorted(_parse_env_file(surface.path)):
                actions.append(_status_for_key(surface, key, manifest))
    return actions


def _collect_local_cleanup_actions(manifest: dict) -> list[CleanupAction]:
    actions: list[CleanupAction] = []
    for authority_key in (LOCAL_SECRET_KEY, RETIRED_ENV_KEY):
        for surface in _expand_manifest_surfaces(manifest, authority_key):
            for key in sorted(_parse_env_file(surface.path)):
                actions.append(_status_for_key(surface, key, manifest))
    return actions


def _collect_findings(manifest: dict) -> tuple[list[Finding], dict[str, int]]:
    findings: list[Finding] = []
    counts = {
        "authority_surfaces": 0,
        "local_secret_adapters": 0,
        "retired_env_surfaces": 0,
        "evidence_snapshots": 0,
        "shared_authority_keys": 0,
    }

    authority_surfaces: list[EnvSurface] = []
    for authority_key in AUTHORITY_KEYS:
        authority_surfaces.extend(_expand_manifest_surfaces(manifest, authority_key))
    local_surfaces = _expand_manifest_surfaces(manifest, LOCAL_SECRET_KEY)
    retired_surfaces = _expand_manifest_surfaces(manifest, RETIRED_ENV_KEY)
    snapshot_surfaces = _expand_manifest_surfaces(manifest, SNAPSHOT_KEY)

    counts["authority_surfaces"] = sum(1 for surface in authority_surfaces if surface.path.is_file())
    counts["local_secret_adapters"] = sum(1 for surface in local_surfaces if surface.path.is_file())
    counts["retired_env_surfaces"] = sum(1 for surface in retired_surfaces if surface.path.is_file())
    counts["evidence_snapshots"] = sum(1 for surface in snapshot_surfaces if surface.path.is_file())

    for surface in authority_surfaces:
        keys = _parse_env_file(surface.path)
        if not keys:
            continue
        for key in sorted(keys):
            if _is_shared_candidate(key):
                counts["shared_authority_keys"] += 1
            if key in DEPRECATED_RUNTIME_NAMES:
                findings.append(
                    Finding(
                        "error",
                        _surface_label(surface),
                        key,
                        "deprecated runtime name is not allowed in profile or example adapters",
                    )
                )
            if surface.path.match("TRR-APP/apps/web/.env.example") and key in APP_LOCAL_DEPRECATED_NAMES:
                findings.append(
                    Finding(
                        "error",
                        _surface_label(surface),
                        key,
                        "TRR-APP must use TRR_CORE_SUPABASE_SERVICE_ROLE_KEY instead",
                    )
                )
            if _is_shared_candidate(key) and _owner_for_key(key, manifest) is None:
                findings.append(
                    Finding(
                        "error",
                        _surface_label(surface),
                        key,
                        "shared env key has no owner in docs/workspace/shared-env-manifest.json",
                    )
                )

    for repo_name, policy in manifest.get("repo_validation", {}).items():
        if not isinstance(policy, dict):
            continue
        env_example = policy.get("env_example")
        if env_example:
            path = ROOT / str(env_example)
            keys = _parse_env_file(path)
            for required in policy.get("required_env_example_keys", []):
                if required not in keys:
                    findings.append(
                        Finding(
                            "error",
                            str(path.relative_to(ROOT)),
                            str(required),
                            f"{repo_name} required env example key is missing",
                        )
                    )

        for required in policy.get("auth_required", []):
            example_paths = [ROOT / p for p in manifest.get("authority_surfaces", {}).get("surface_setup_adapters", [])]
            matching = [p for p in example_paths if p.parts and repo_name in p.parts]
            if matching and not any(required in _parse_env_file(path) for path in matching):
                findings.append(
                    Finding(
                        "error",
                        repo_name,
                        str(required),
                        "required auth key is missing from the surface setup adapter",
                    )
                )

    local_key_owners: dict[str, list[EnvSurface]] = {}
    for surface in local_surfaces:
        for key in _parse_env_file(surface.path):
            if _is_shared_candidate(key):
                local_key_owners.setdefault(key, []).append(surface)
    for key, surfaces in sorted(local_key_owners.items()):
        if len(surfaces) > 1 and key not in {"TRR_DB_DIRECT_URL", "TRR_DB_SESSION_URL", "TRR_DB_URL", "TRR_INTERNAL_ADMIN_SHARED_SECRET"}:
            status_notes = []
            for surface in surfaces:
                action = _status_for_key(surface, key, manifest)
                status_notes.append(f"{_surface_label(surface)}={action.status}")
            findings.append(
                Finding(
                    "warn",
                    ", ".join(_surface_label(surface) for surface in surfaces),
                    key,
                    "shared key appears in multiple ignored local secret adapters; cleanup status: "
                    + ", ".join(status_notes),
                )
            )

    return findings, counts


def _render_markdown(manifest: dict, findings: list[Finding], counts: dict[str, int], actions: list[CleanupAction]) -> str:
    authority = manifest.get("authority_surfaces", {})
    lines = [
        "# Env Hygiene Report",
        "",
        "Generated by `scripts/workspace/env_hygiene.py`. Values are never printed.",
        "",
        "## Summary",
        "",
        f"- `authority surfaces present`: {counts['authority_surfaces']}",
        f"- `local secret adapters present`: {counts['local_secret_adapters']}",
        f"- `retired env surfaces present`: {counts['retired_env_surfaces']}",
        f"- `evidence snapshots present`: {counts['evidence_snapshots']}",
        f"- `shared authority keys checked`: {counts['shared_authority_keys']}",
        f"- `errors`: {sum(1 for finding in findings if finding.severity == 'error')}",
        f"- `warnings`: {sum(1 for finding in findings if finding.severity == 'warn')}",
        f"- `env file keys reported`: {len(actions)}",
        f"- `dry-run remove actions`: {sum(1 for action in actions if action.status == 'remove')}",
        f"- `dry-run move actions`: {sum(1 for action in actions if action.status == 'move')}",
        f"- `dry-run keep actions`: {sum(1 for action in actions if action.status == 'keep')}",
        "",
        "## Authority Classes",
        "",
        "| Class | Meaning | Surfaces |",
        "|---|---|---|",
        "| source of truth | Env ownership Interface and generated human projections. | "
        + ", ".join(f"`{item}`" for item in authority.get("source_of_truth", []))
        + " |",
        "| runtime profile adapter | Checked-in workspace mode inputs. | "
        + ", ".join(f"`{item}`" for item in authority.get("runtime_profile_adapters", []))
        + " |",
        "| surface setup adapter | Checked-in setup examples for one runtime surface. | "
        + ", ".join(f"`{item}`" for item in authority.get("surface_setup_adapters", []))
        + " |",
        "| local secret adapter | Ignored operator secrets and overrides. Read key names only. | "
        + ", ".join(f"`{item}`" for item in authority.get("local_secret_adapters", []))
        + " |",
        "| retired env surface | Protected retired env files. Read key names only; not current authority. | "
        + ", ".join(f"`{item}`" for item in authority.get("retired_env_surfaces", []))
        + " |",
        "| evidence snapshot | Generated or pulled env evidence. Not implementation authority. | "
        + ", ".join(f"`{item}`" for item in authority.get("evidence_snapshots", []))
        + " |",
        "",
        "## Findings",
        "",
        "| Severity | Surface | Key | Finding |",
        "|---|---|---|---|",
    ]
    if findings:
        for finding in findings:
            lines.append(f"| {finding.severity} | `{finding.surface}` | `{finding.key}` | {finding.message} |")
    else:
        lines.append("| ok | all checked authority surfaces |  | No env hygiene findings. |")
    lines.extend(
        [
            "",
            "## Env File Dry-Run Status",
            "",
            "This is a dry-run key-name report for every configured env-file surface. It does not print values or edit files.",
            "",
            "| Status | Class | Surface | Key | Reason |",
            "|---|---|---|---|---|",
        ]
    )
    if actions:
        for action in sorted(actions, key=lambda item: (item.status, item.authority, item.surface, item.key)):
            lines.append(f"| {action.status} | `{action.authority}` | `{action.surface}` | `{action.key}` | {action.reason} |")
    else:
        lines.append("| keep | env file surfaces |  |  | No env file keys found. |")
    lines.append("")
    return "\n".join(lines)


def _render_text(findings: list[Finding], counts: dict[str, int], actions: list[CleanupAction]) -> str:
    terminal_actions = [
        action
        for action in actions
        if action.authority in {LOCAL_SECRET_KEY, RETIRED_ENV_KEY} or action.status != "keep"
    ]
    lines = [
        "[env-hygiene] values are never printed",
        f"[env-hygiene] authority_surfaces={counts['authority_surfaces']} local_secret_adapters={counts['local_secret_adapters']} retired_env_surfaces={counts['retired_env_surfaces']} evidence_snapshots={counts['evidence_snapshots']} shared_authority_keys={counts['shared_authority_keys']}",
        f"[env-hygiene] dry_run_status keys={len(actions)} remove={sum(1 for action in actions if action.status == 'remove')} move={sum(1 for action in actions if action.status == 'move')} keep={sum(1 for action in actions if action.status == 'keep')}",
        f"[env-hygiene] terminal_rows={len(terminal_actions)} scope=local-adapters-retired-surfaces-plus-remove-move; use --markdown --output <path> for every env-file key row",
    ]
    for finding in findings:
        lines.append(f"[env-hygiene] {finding.severity.upper()}: {finding.surface}: {finding.key}: {finding.message}")
    for action in sorted(terminal_actions, key=lambda item: (item.status, item.surface, item.key)):
        lines.append(f"[env-hygiene] DRY-RUN {action.status.upper()}: {action.authority}: {action.surface}: {action.key}: {action.reason}")
    if not findings:
        lines.append("[env-hygiene] OK")
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Redacted TRR env authority and drift hygiene check.")
    parser.add_argument("--check", action="store_true", help="Return non-zero when error findings are present.")
    parser.add_argument("--markdown", action="store_true", help="Render a markdown report instead of text.")
    parser.add_argument("--output", type=Path, help="Write a markdown report to this path.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    manifest = _load_manifest()
    findings, counts = _collect_findings(manifest)
    actions = _collect_cleanup_actions(manifest)
    error_count = sum(1 for finding in findings if finding.severity == "error")

    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(_render_markdown(manifest, findings, counts, actions) + "\n", encoding="utf-8")
    else:
        report = _render_markdown(manifest, findings, counts, actions) if args.markdown else _render_text(findings, counts, actions)
        sys.stdout.write(report)

    if args.check and error_count:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
