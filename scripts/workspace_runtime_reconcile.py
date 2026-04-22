from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
BACKEND_ROOT = ROOT / "TRR-Backend"
ARTIFACT_PATH = ROOT / ".logs" / "workspace" / "runtime-reconcile.json"


def default_component(
    *,
    state: str = "ok",
    reason: str | None = None,
    remediation: str | None = None,
    **extra: Any,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "state": state,
        "reason": reason,
        "remediation": remediation,
    }
    payload.update(extra)
    return payload


def default_artifact() -> dict[str, Any]:
    return {
        "overall_state": "ok",
        "summary": "db=ok, modal=ok, render=ok, decodo=ok",
        "db": default_component(applied_versions=[]),
        "modal": default_component(deployed=False, fingerprint_changed=False),
        "render": default_component(verify_only=True),
        "decodo": default_component(verify_only=True),
    }


def _python_command(repo_root: Path) -> str:
    repo_python = repo_root / ".venv" / "bin" / "python"
    if repo_python.is_file():
        return str(repo_python)
    return sys.executable or "python3"


def load_json_file(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return default_artifact()
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default_artifact()
    if not isinstance(loaded, dict):
        return default_artifact()
    merged = default_artifact()
    for key in ("db", "modal", "render", "decodo"):
        value = loaded.get(key)
        if isinstance(value, dict):
            merged[key].update(value)
    for key in ("overall_state", "summary"):
        if isinstance(loaded.get(key), str):
            merged[key] = loaded[key]
    return merged


def _run_backend_script(script_relpath: str) -> tuple[int, dict[str, Any]]:
    command = [_python_command(BACKEND_ROOT), script_relpath, "--json"]
    completed = subprocess.run(
        command,
        cwd=BACKEND_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    payload: dict[str, Any]
    try:
        payload = json.loads((completed.stdout or "").strip() or "{}")
    except json.JSONDecodeError:
        payload = {
            "state": "blocked",
            "reason": "script_output_invalid",
            "remediation": (completed.stderr or completed.stdout or "Runtime reconcile helper failed").strip() or None,
        }
    if not isinstance(payload, dict):
        payload = {
            "state": "blocked",
            "reason": "script_output_invalid",
            "remediation": "Runtime reconcile helper returned a non-object payload.",
        }
    return completed.returncode, payload


def _component_detail(name: str, component: dict[str, Any]) -> str | None:
    state = str(component.get("state") or "").strip()
    reason = str(component.get("reason") or "").strip()
    if state == "fixed":
        if name == "db":
            applied_versions = component.get("applied_versions") or []
            if isinstance(applied_versions, list) and applied_versions:
                return f"db=applied {len(applied_versions)} migrations"
            return "db=fixed"
        if name == "modal":
            return "modal=redeployed"
        return f"{name}=fixed"
    if state == "advisory":
        return reason or f"{name}=advisory"
    if state == "blocked":
        return reason or f"{name}=blocked"
    return None


def compute_overall_state(artifact: dict[str, Any]) -> dict[str, Any]:
    components = {
        "db": artifact.get("db") or {},
        "modal": artifact.get("modal") or {},
        "render": artifact.get("render") or {},
        "decodo": artifact.get("decodo") or {},
    }
    blocked = [name for name, component in components.items() if component.get("state") == "blocked"]
    fixed = [name for name, component in components.items() if component.get("state") == "fixed"]
    advisory = [name for name, component in components.items() if component.get("state") == "advisory"]

    if blocked:
        details = [_component_detail(name, components[name]) for name in blocked]
        summary = ", ".join(detail for detail in details if detail) or ", ".join(blocked)
        artifact["overall_state"] = "blocked"
        artifact["summary"] = summary
        return artifact
    if fixed:
        details = [_component_detail(name, components[name]) for name in fixed]
        if advisory:
            details.extend(_component_detail(name, components[name]) for name in advisory)
        summary = ", ".join(detail for detail in details if detail) or ", ".join(fixed)
        artifact["overall_state"] = "fixed"
        artifact["summary"] = summary
        return artifact
    if advisory:
        details = [_component_detail(name, components[name]) for name in advisory]
        summary = ", ".join(detail for detail in details if detail) or ", ".join(advisory)
        artifact["overall_state"] = "advisory"
        artifact["summary"] = summary
        return artifact

    artifact["overall_state"] = "ok"
    artifact["summary"] = "db=ok, modal=ok, render=ok, decodo=ok"
    return artifact


def render_preflight_summary(artifact: dict[str, Any]) -> str:
    state = artifact.get("overall_state")
    summary = str(artifact.get("summary") or "").strip()
    if state == "fixed":
        return f"[preflight] Runtime reconcile FIXED ({summary})"
    if state == "advisory":
        return f"[preflight] Runtime reconcile ADVISORY ({summary}; see make status)"
    if state == "blocked":
        return f"[preflight] Runtime reconcile BLOCKED ({summary})"
    return "[preflight] Runtime reconcile OK"


def run_runtime_reconcile() -> dict[str, Any]:
    artifact = default_artifact()

    db_rc, db_payload = _run_backend_script("scripts/dev/reconcile_runtime_db.py")
    modal_rc, modal_payload = _run_backend_script("scripts/modal/reconcile_modal_runtime.py")
    _, external_payload = _run_backend_script("scripts/dev/verify_external_runtime_contracts.py")

    artifact["db"].update(db_payload)
    artifact["modal"].update(modal_payload)
    if isinstance(external_payload.get("render"), dict):
        artifact["render"].update(external_payload["render"])
    if isinstance(external_payload.get("decodo"), dict):
        artifact["decodo"].update(external_payload["decodo"])

    if db_rc != 0 and artifact["db"].get("state") != "blocked":
        artifact["db"]["state"] = "blocked"
        artifact["db"]["reason"] = artifact["db"].get("reason") or "runtime_db_reconcile_failed"
    if modal_rc != 0 and artifact["modal"].get("state") != "blocked":
        artifact["modal"]["state"] = "blocked"
        artifact["modal"]["reason"] = artifact["modal"].get("reason") or "runtime_modal_reconcile_failed"

    return compute_overall_state(artifact)


def main(argv: list[str] | None = None) -> int:
    args = argv or sys.argv[1:]
    emit_json = "--json" in args
    artifact = run_runtime_reconcile()
    ARTIFACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    ARTIFACT_PATH.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if emit_json:
        print(json.dumps(artifact, indent=2, sort_keys=True))
    else:
        print(render_preflight_summary(artifact))
    return 1 if artifact.get("overall_state") == "blocked" else 0
