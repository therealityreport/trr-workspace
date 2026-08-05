#!/usr/bin/env python3
from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from collections.abc import Iterator
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs" / "workspace" / "runtime-capacity.json"


class CapacityContractError(RuntimeError):
    pass


def load_manifest(path: Path = DEFAULT_MANIFEST) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CapacityContractError(f"unable to load {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise CapacityContractError("runtime-capacity manifest must be a JSON object")
    return payload


def _positive_int(value: Any, label: str, *, allow_zero: bool = False) -> int:
    if (
        not isinstance(value, int)
        or isinstance(value, bool)
        or value < (0 if allow_zero else 1)
    ):
        bound = "non-negative" if allow_zero else "positive"
        raise CapacityContractError(f"{label} must be a {bound} integer")
    return value


def validate_manifest(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        raise CapacityContractError("runtime-capacity version must be 1")
    contexts = payload.get("contexts")
    if not isinstance(contexts, dict):
        raise CapacityContractError("runtime-capacity contexts must be an object")
    for name in (
        "local_workspace",
        "workspace_hybrid",
        "hosted_modal",
        "architecture_refactor",
    ):
        context = contexts.get(name)
        if not isinstance(context, dict):
            raise CapacityContractError(f"missing context: {name}")
        _positive_int(context.get("dispatch_batch_size"), f"{name}.dispatch_batch_size")
        concurrency = context.get("container_job_concurrency")
        if not isinstance(concurrency, dict):
            raise CapacityContractError(
                f"{name}.container_job_concurrency must be an object"
            )
        for key, value in concurrency.items():
            _positive_int(value, f"{name}.container_job_concurrency.{key}")
        if "general_social" not in concurrency:
            raise CapacityContractError(
                f"{name}.container_job_concurrency.general_social is required"
            )
        stage_caps = context.get("stage_caps")
        if not isinstance(stage_caps, dict):
            raise CapacityContractError(f"{name}.stage_caps must be an object")
        for key, value in stage_caps.items():
            _positive_int(value, f"{name}.stage_caps.{key}", allow_zero=True)
        required_stage_caps = {
            "comments",
            "media_mirror",
            "comment_media_mirror",
        }
        if name != "hosted_modal":
            required_stage_caps.add("posts")
        missing_stage_caps = sorted(required_stage_caps - stage_caps.keys())
        if missing_stage_caps:
            raise CapacityContractError(
                f"{name}.stage_caps is missing: {', '.join(missing_stage_caps)}"
            )

    if contexts["local_workspace"]["dispatch_batch_size"] != 4:
        raise CapacityContractError(
            "local workspace dormant dispatch fallback must remain 4"
        )
    if contexts["workspace_hybrid"]["dispatch_batch_size"] != 8:
        raise CapacityContractError("workspace hybrid dispatch must remain 8")
    if contexts["hosted_modal"]["dispatch_batch_size"] != 12:
        raise CapacityContractError("hosted Modal dispatch must remain 12")
    if contexts["architecture_refactor"].get("database_target") != "loopback_only":
        raise CapacityContractError(
            "architecture refactor database target must remain loopback-only"
        )
    hosted_concurrency = contexts["hosted_modal"]["container_job_concurrency"]
    if hosted_concurrency.get("general_social") != 8:
        raise CapacityContractError("hosted general social concurrency must remain 8")
    if (
        hosted_concurrency.get("comments") != 4
        or hosted_concurrency.get("comments_recovery") != 4
    ):
        raise CapacityContractError(
            "hosted comments and recovery concurrency must remain distinct at 4"
        )
    if hosted_concurrency.get("media") != 1 or hosted_concurrency.get("recovery") != 1:
        raise CapacityContractError(
            "hosted media and recovery concurrency must remain distinct at 1"
        )

    expected_side_effects = {
        "database_apply": False,
        "runtime_reconcile": False,
        "modal_deploy": False,
        "render_mutation": False,
        "vercel_mutation": False,
        "remote_workers": False,
    }
    if contexts["architecture_refactor"].get("side_effects") != expected_side_effects:
        raise CapacityContractError(
            "architecture refactor side-effect policy must remain fully disabled"
        )


def shell_projection(payload: dict[str, Any], context_name: str) -> dict[str, str]:
    contexts = payload["contexts"]
    context = contexts.get(context_name)
    if not isinstance(context, dict):
        raise CapacityContractError(f"unknown runtime capacity context: {context_name}")
    stage_caps = context["stage_caps"]
    general = context["container_job_concurrency"]["general_social"]
    projection = {
        "WORKSPACE_RUNTIME_CAPACITY_CONTEXT": context_name,
        "WORKSPACE_RUNTIME_CAPACITY_DISPATCH_BATCH_SIZE": str(
            context["dispatch_batch_size"]
        ),
        "WORKSPACE_RUNTIME_CAPACITY_GENERAL_CONCURRENCY": str(general),
        "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT": str(
            context["dispatch_batch_size"]
        ),
        "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": str(general),
        "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS": str(stage_caps.get("posts", 1)),
        "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS": str(stage_caps.get("comments", 1)),
        "WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR": str(
            stage_caps.get("media_mirror", 1)
        ),
        "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR": str(
            stage_caps.get("comment_media_mirror", 1)
        ),
    }
    platform_cap = stage_caps.get("instagram_posts_comments_platform")
    if platform_cap is not None:
        projection["SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM"] = str(platform_cap)
    return projection


def _parse_profile(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        raise CapacityContractError(f"unable to read profile {path}: {exc}") from exc
    for raw_line in lines:
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        if "=" not in line:
            raise CapacityContractError(f"invalid profile line in {path}: {raw_line}")
        key, value = line.split("=", 1)
        values[key] = value
    return values


def _modal_defaults() -> dict[str, str]:
    path = ROOT / "TRR-Backend" / "trr_backend" / "modal_jobs.py"
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise CapacityContractError(
            f"unable to read Modal runtime defaults from {path}: {exc}"
        ) from exc
    try:
        tree = ast.parse(source, filename=str(path))
    except (SyntaxError, ValueError) as exc:
        raise CapacityContractError(
            f"unable to parse Modal runtime defaults from {path}: {exc}"
        ) from exc
    for node in tree.body:
        if not isinstance(node, ast.AnnAssign) or not isinstance(node.target, ast.Name):
            continue
        if node.target.id != "_CANONICAL_MODAL_RUNTIME_DEFAULTS" or node.value is None:
            continue
        if not isinstance(node.value, ast.Dict):
            break
        values: dict[str, str] = {}
        for key_node, value_node in zip(
            node.value.keys, node.value.values, strict=True
        ):
            try:
                key = ast.literal_eval(key_node)
                value = ast.literal_eval(value_node)
            except (ValueError, TypeError):
                continue
            if isinstance(key, str) and isinstance(value, (str, int)):
                values[key] = str(value)
        return values
    raise CapacityContractError("unable to locate _CANONICAL_MODAL_RUNTIME_DEFAULTS")


def _owned_return_nodes(node: ast.AST) -> Iterator[ast.Return]:
    """Yield returns owned by a function body, excluding nested scopes."""
    if isinstance(node, ast.Return):
        yield node
        return
    if isinstance(
        node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda)
    ):
        return
    for child in ast.iter_child_nodes(node):
        yield from _owned_return_nodes(child)


def validate_social_dispatch_fallback(
    payload: dict[str, Any],
    *,
    implementation_path: Path | None = None,
) -> None:
    path = implementation_path or (
        ROOT
        / "TRR-Backend"
        / "trr_backend"
        / "socials"
        / "social_season_analytics_impl.py"
    )
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (OSError, SyntaxError) as exc:
        raise CapacityContractError(
            f"unable to inspect social dispatch fallback in {path}: {exc}"
        ) from exc

    fallback_value: Any = None
    dispatch_function: ast.FunctionDef | ast.AsyncFunctionDef | None = None
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.name == "_modal_dispatch_limit":
                dispatch_function = node
            continue
        value_node: ast.expr | None = None
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name)
            and target.id == "SOCIAL_MODAL_DISPATCH_LIMIT_DEFAULT"
            for target in node.targets
        ):
            value_node = node.value
        elif (
            isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.target.id == "SOCIAL_MODAL_DISPATCH_LIMIT_DEFAULT"
        ):
            value_node = node.value
        if value_node is not None:
            try:
                fallback_value = ast.literal_eval(value_node)
            except (ValueError, TypeError) as exc:
                raise CapacityContractError(
                    "SOCIAL_MODAL_DISPATCH_LIMIT_DEFAULT must be a literal integer"
                ) from exc

    if not isinstance(fallback_value, int) or isinstance(fallback_value, bool):
        raise CapacityContractError(
            "unable to locate literal SOCIAL_MODAL_DISPATCH_LIMIT_DEFAULT"
        )
    if dispatch_function is None:
        raise CapacityContractError("unable to locate _modal_dispatch_limit")
    returned_resolver_calls = [
        node.value
        for statement in dispatch_function.body
        for node in _owned_return_nodes(statement)
        if isinstance(node.value, ast.Call)
        and isinstance(node.value.func, ast.Name)
        and node.value.func.id == "_resolve_int_env_with_bounds"
    ]
    if not any(
        len(call.args) >= 2
        and isinstance(call.args[1], ast.Name)
        and isinstance(call.args[1].ctx, ast.Load)
        and call.args[1].id == "SOCIAL_MODAL_DISPATCH_LIMIT_DEFAULT"
        for call in returned_resolver_calls
    ):
        raise CapacityContractError(
            "_modal_dispatch_limit must pass SOCIAL_MODAL_DISPATCH_LIMIT_DEFAULT to its returned resolver"
        )

    expected = payload["contexts"]["local_workspace"]["dispatch_batch_size"]
    if fallback_value != expected:
        raise CapacityContractError(
            f"social dispatch fallback {fallback_value} does not match local workspace capacity {expected}"
        )


def validate_projections(payload: dict[str, Any], root: Path = ROOT) -> None:
    contexts = payload["contexts"]
    profile_contexts = payload.get("profile_contexts")
    if not isinstance(profile_contexts, dict):
        raise CapacityContractError("profile_contexts must be an object")

    for profile_name, context_name in profile_contexts.items():
        profile_path = root / "profiles" / f"{profile_name}.env"
        if not profile_path.is_file():
            raise CapacityContractError(f"missing profile: {profile_path}")
        values = _parse_profile(profile_path)
        if values.get("WORKSPACE_RUNTIME_CAPACITY_PROFILE") != context_name:
            raise CapacityContractError(
                f"{profile_name} does not select capacity context {context_name}"
            )
        expected = shell_projection(payload, str(context_name))
        for key in (
            "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT",
            "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT",
        ):
            if key in values and values[key] != expected[key]:
                raise CapacityContractError(
                    f"{profile_name} {key}={values[key]} does not match {context_name}={expected[key]}"
                )
        if values.get("WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS") == "1":
            for key in (
                "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT",
                "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT",
            ):
                if values.get(key) != expected[key]:
                    raise CapacityContractError(
                        f"enabled profile {profile_name} must explicitly preserve {key}={expected[key]}"
                    )

    profile_overrides = payload.get("profile_overrides")
    if not isinstance(profile_overrides, dict):
        raise CapacityContractError("profile_overrides must be an object")
    stage_env_keys = {
        "posts": "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS",
        "comments": "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS",
        "media_mirror": "WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR",
        "comment_media_mirror": "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR",
    }
    for profile_name, override in profile_overrides.items():
        if not isinstance(override, dict):
            raise CapacityContractError(
                f"profile override {profile_name} must be an object"
            )
        values = _parse_profile(root / "profiles" / f"{profile_name}.env")
        remote_social_enabled = override.get("remote_social_enabled")
        if not isinstance(remote_social_enabled, bool):
            raise CapacityContractError(
                f"profile override {profile_name}.remote_social_enabled must be boolean"
            )
        enabled = "1" if remote_social_enabled else "0"
        if values.get("WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS") != enabled:
            raise CapacityContractError(
                f"profile override {profile_name} remote social state differs from profile"
            )
        stage_caps = override.get("stage_caps")
        if not isinstance(stage_caps, dict):
            raise CapacityContractError(
                f"profile override {profile_name}.stage_caps must be an object"
            )
        for stage_name, env_key in stage_env_keys.items():
            expected_value = _positive_int(
                stage_caps.get(stage_name),
                f"profile_overrides.{profile_name}.stage_caps.{stage_name}",
                allow_zero=True,
            )
            if values.get(env_key) != str(expected_value):
                raise CapacityContractError(
                    f"profile override {profile_name} {env_key} differs from matrix"
                )

    validate_social_dispatch_fallback(
        payload,
        implementation_path=(
            root
            / "TRR-Backend"
            / "trr_backend"
            / "socials"
            / "social_season_analytics_impl.py"
        ),
    )

    modal_defaults = _modal_defaults()
    hosted = contexts["hosted_modal"]
    expected_modal = {
        "TRR_RUNTIME_CAPACITY_CONTEXT": "hosted_modal",
        "SOCIAL_MODAL_DISPATCH_LIMIT": hosted["dispatch_batch_size"],
        "TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": hosted["container_job_concurrency"][
            "general_social"
        ],
        "TRR_MODAL_SOCIAL_COMMENTS_JOB_CONCURRENCY_LIMIT": hosted[
            "container_job_concurrency"
        ]["comments"],
        "TRR_MODAL_SOCIAL_COMMENTS_RECOVERY_JOB_CONCURRENCY_LIMIT": hosted[
            "container_job_concurrency"
        ]["comments_recovery"],
        "TRR_MODAL_SOCIAL_MEDIA_JOB_CONCURRENCY_LIMIT": hosted[
            "container_job_concurrency"
        ]["media"],
        "TRR_MODAL_SOCIAL_RECOVERY_CONCURRENCY_LIMIT": hosted[
            "container_job_concurrency"
        ]["recovery"],
        "SOCIAL_WORKER_POOL_COMMENTS": hosted["stage_caps"]["comments"],
        "SOCIAL_WORKER_POOL_MEDIA_MIRROR": hosted["stage_caps"]["media_mirror"],
        "SOCIAL_WORKER_POOL_COMMENT_MEDIA_MIRROR": hosted["stage_caps"][
            "comment_media_mirror"
        ],
        "SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM": hosted["stage_caps"][
            "instagram_posts_comments_platform"
        ],
    }
    for key, expected_value in expected_modal.items():
        if modal_defaults.get(key) != str(expected_value):
            raise CapacityContractError(
                f"Modal projection {key}={modal_defaults.get(key)!r} does not match hosted matrix {expected_value}"
            )

    try:
        makefile = (root / "Makefile").read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise CapacityContractError(f"unable to read Makefile: {exc}") from exc
    hybrid = contexts["workspace_hybrid"]
    for assignment in (
        f"WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT={hybrid['dispatch_batch_size']}",
        "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="
        f"{hybrid['container_job_concurrency']['general_social']}",
    ):
        if assignment not in makefile:
            raise CapacityContractError(
                f"Makefile is missing hybrid projection: {assignment}"
            )

    try:
        status_script = (root / "scripts" / "status-workspace.sh").read_text(
            encoding="utf-8"
        )
    except (OSError, UnicodeError) as exc:
        raise CapacityContractError(
            f"unable to read status-workspace.sh: {exc}"
        ) from exc
    local = contexts["local_workspace"]
    for assignment in (
        'WORKSPACE_RUNTIME_CAPACITY_PROFILE="${WORKSPACE_RUNTIME_CAPACITY_PROFILE:-local_workspace}"',
        'WORKSPACE_RUNTIME_CAPACITY_CONTEXT="${WORKSPACE_RUNTIME_CAPACITY_CONTEXT:-$WORKSPACE_RUNTIME_CAPACITY_PROFILE}"',
        f'WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="${{WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-{local["dispatch_batch_size"]}}}"',
        f'WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="${{WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-{local["container_job_concurrency"]["general_social"]}}}"',
    ):
        if assignment not in status_script:
            raise CapacityContractError(
                f"status-workspace.sh is missing capacity projection: {assignment}"
            )

    workspace_presets = payload.get("workspace_presets")
    if not isinstance(workspace_presets, dict):
        raise CapacityContractError("workspace_presets must be an object")
    for target_name, preset in workspace_presets.items():
        if not isinstance(preset, dict) or preset.get("context") != "workspace_hybrid":
            raise CapacityContractError(
                f"workspace preset {target_name} must select workspace_hybrid"
            )
        target_match = re.search(
            rf"(?ms)^{re.escape(target_name)}:\n(.*?)(?=^[A-Za-z0-9_.-]+:|\Z)",
            makefile,
        )
        if target_match is None:
            raise CapacityContractError(
                f"Makefile is missing workspace preset {target_name}"
            )
        target_body = target_match.group(1)
        preset_stage_caps = preset.get("stage_caps")
        if not isinstance(preset_stage_caps, dict):
            raise CapacityContractError(
                f"workspace preset {target_name}.stage_caps must be an object"
            )
        unknown_stage_caps = sorted(preset_stage_caps.keys() - stage_env_keys.keys())
        if unknown_stage_caps:
            raise CapacityContractError(
                f"workspace preset {target_name} has unknown stage caps: {', '.join(unknown_stage_caps)}"
            )
        for stage_name, value in preset_stage_caps.items():
            _positive_int(
                value,
                f"workspace_presets.{target_name}.stage_caps.{stage_name}",
                allow_zero=True,
            )
        expected_assignments = {
            "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS": 1,
            "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT": hybrid["dispatch_batch_size"],
            "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": hybrid[
                "container_job_concurrency"
            ]["general_social"],
            **{
                stage_env_keys[stage_name]: value
                for stage_name, value in preset_stage_caps.items()
            },
        }
        for key, expected_value in expected_assignments.items():
            if f"{key}={expected_value}" not in target_body:
                raise CapacityContractError(
                    f"Makefile preset {target_name} is missing {key}={expected_value}"
                )

    try:
        runtime_adapter = (
            root / "TRR-Backend" / "scripts" / "_workspace_runtime_env.py"
        ).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise CapacityContractError(
            f"unable to read backend runtime adapter: {exc}"
        ) from exc
    for workspace_key, runtime_key in (
        ("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT", "SOCIAL_MODAL_DISPATCH_LIMIT"),
        (
            "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT",
            "TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT",
        ),
    ):
        pattern = re.compile(rf'"{workspace_key}"\s*:\s*"{runtime_key}"')
        if not pattern.search(runtime_adapter):
            raise CapacityContractError(
                f"backend runtime adapter is missing {workspace_key} -> {runtime_key}"
            )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate and project the TRR runtime-capacity authority."
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("check")
    shell_parser = subparsers.add_parser("shell")
    shell_parser.add_argument("--context", required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        payload = load_manifest(args.manifest)
        validate_manifest(payload)
        if args.command == "check":
            validate_projections(payload)
            print("runtime-capacity: OK")
        else:
            for key, value in shell_projection(payload, args.context).items():
                if not re.fullmatch(r"[A-Za-z0-9_.:/-]+", value):
                    raise CapacityContractError(
                        f"unsafe shell projection value for {key}"
                    )
                print(f"{key}={value}")
    except CapacityContractError as exc:
        print(f"runtime-capacity: ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
