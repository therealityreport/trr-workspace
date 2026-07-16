#!/usr/bin/env python3
"""Build and enforce the canonical TRR backend/app import graph.

Gate 0E uses ``--check-frozen``: source bytes, graph edges, and metrics must
exactly match the recorded snapshot. Gate 1 and later refactor packets use
``--check-baseline``: debt counts may decrease but may not exceed the recorded
ceilings. Final architecture acceptance uses ``--check-zero`` for social
backend cycles/legacy imports and all app import cycles.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Sequence


SCOPE_VERSION = 1
BACKEND_ROOTS = ("TRR-Backend/api", "TRR-Backend/trr_backend")
APP_ROOT = "TRR-APP/apps/web/src"
PYTHON_EXCLUDED_DIRS = {"__pycache__", ".mypy_cache", ".pytest_cache"}
APP_EXCLUDED_DIRS = {
    ".next",
    ".next-e2e",
    ".next-e2e-debug",
    ".next-e2e-public",
    "node_modules",
    "test-results",
    "tests",
    "__tests__",
}
APP_EXTENSIONS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs")
SOCIAL_PREFIXES = ("trr_backend.socials", "api.routers.socials")
LEGACY_SOCIAL_MODULES = {
    "trr_backend.repositories.social_season_analytics",
    "trr_backend.socials.social_season_analytics_impl",
}

# Filled from this command's canonical scope. Frozen mode detects any exact
# source/graph drift; baseline mode enforces debt ceilings; zero mode enforces
# the program's final acceptance target.
BASELINE = {
    "scope_version": SCOPE_VERSION,
    "captured_at": "2026-07-16T20:59:30Z",
    "backend": {
        "module_count": 483,
        "edge_count": 1264,
        "cycle_count": 5,
        "cyclic_module_count": 66,
        "social_cycle_count": 2,
        "social_cyclic_module_count": 49,
        "legacy_social_import_count": 141,
        "legacy_social_importer_count": 34,
        "source_sha256": "b6633756538ae1a9631279e04b32e76dc735b13fcb7fccb8c7ec7550ba883f8f",
        "graph_sha256": "00687189cb30c0fe25ee837d057b1f4abe386458212d90da7cce438722eddba0",
    },
    "app": {
        "module_count": 1122,
        "edge_count": 2941,
        "cycle_count": 0,
        "cyclic_module_count": 0,
        "source_sha256": "8c3fee0db688b562b3d48383a1aa099a75c3dfd6b7776642a5b411a815c9e714",
        "graph_sha256": "64e040bb7f35784441812d9af7e74dd5e87d1ecc6182d97ed00013ed19beaa4b",
    },
}


@dataclass(frozen=True)
class ImportRecord:
    source: str
    target: str
    line: int
    kind: str


@dataclass
class GraphResult:
    component: str
    graph: dict[str, set[str]]
    source_files: dict[str, Path]
    parse_errors: list[str] = field(default_factory=list)
    import_records: list[ImportRecord] = field(default_factory=list)

    @property
    def cycles(self) -> list[list[str]]:
        return cyclic_components(self.graph)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_digest(source_files: dict[str, Path]) -> str:
    digest = hashlib.sha256()
    for module, path in sorted(source_files.items()):
        digest.update(module.encode())
        digest.update(b"\0")
        digest.update(sha256_file(path).encode())
        digest.update(b"\0")
    return digest.hexdigest()


def graph_digest(graph: dict[str, set[str]]) -> str:
    digest = hashlib.sha256()
    for source in sorted(graph):
        digest.update(source.encode())
        digest.update(b"\0")
        for target in sorted(graph[source]):
            digest.update(target.encode())
            digest.update(b"\0")
        digest.update(b"\n")
    return digest.hexdigest()


def python_module_name(path: Path, backend_root: Path) -> str:
    relative = path.relative_to(backend_root)
    parts = list(relative.with_suffix("").parts)
    if parts[-1] == "__init__":
        parts.pop()
    return ".".join(parts)


def discover_python_modules(repo_root: Path) -> dict[str, Path]:
    backend_root = repo_root / "TRR-Backend"
    modules: dict[str, Path] = {}
    for configured_root in BACKEND_ROOTS:
        root = repo_root / configured_root
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.py")):
            if any(part in PYTHON_EXCLUDED_DIRS for part in path.parts):
                continue
            module = python_module_name(path, backend_root)
            if module:
                modules[module] = path
    return modules


def resolve_python_target(candidate: str, modules: set[str]) -> str | None:
    current = candidate
    while current:
        if current in modules:
            return current
        current = current.rpartition(".")[0]
    return None


def resolve_relative_python_module(
    source_module: str,
    source_path: Path,
    imported_module: str | None,
    level: int,
) -> str:
    package_parts = source_module.split(".")
    if source_path.name != "__init__.py":
        package_parts = package_parts[:-1]
    if level:
        keep = max(0, len(package_parts) - (level - 1))
        package_parts = package_parts[:keep]
    else:
        package_parts = []
    if imported_module:
        package_parts.extend(imported_module.split("."))
    return ".".join(package_parts)


def python_import_records(
    source_module: str,
    source_path: Path,
    tree: ast.AST,
    modules: set[str],
) -> list[ImportRecord]:
    records: list[ImportRecord] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                target = resolve_python_target(alias.name, modules)
                if target:
                    records.append(
                        ImportRecord(source_module, target, node.lineno, "import")
                    )
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                base = resolve_relative_python_module(
                    source_module,
                    source_path,
                    node.module,
                    node.level,
                )
            else:
                base = node.module or ""
            for alias in node.names:
                candidate = (
                    base
                    if alias.name == "*"
                    else ".".join(part for part in (base, alias.name) if part)
                )
                target = resolve_python_target(candidate, modules)
                if target is None:
                    target = resolve_python_target(base, modules)
                if target:
                    records.append(
                        ImportRecord(source_module, target, node.lineno, "from")
                    )
        elif isinstance(node, ast.Call) and node.args:
            function_name = ""
            if isinstance(node.func, ast.Name):
                function_name = node.func.id
            elif isinstance(node.func, ast.Attribute):
                function_name = node.func.attr
            if function_name not in {"import_module", "__import__"}:
                continue
            first = node.args[0]
            if not isinstance(first, ast.Constant) or not isinstance(first.value, str):
                continue
            candidate = first.value
            if candidate.startswith("."):
                level = len(candidate) - len(candidate.lstrip("."))
                candidate = resolve_relative_python_module(
                    source_module,
                    source_path,
                    candidate[level:] or None,
                    level,
                )
            target = resolve_python_target(candidate, modules)
            if target:
                records.append(
                    ImportRecord(source_module, target, node.lineno, "dynamic")
                )
    return records


def build_backend_graph(repo_root: Path) -> GraphResult:
    source_files = discover_python_modules(repo_root)
    module_names = set(source_files)
    graph = {module: set() for module in source_files}
    result = GraphResult("backend", graph, source_files)
    for module, path in sorted(source_files.items()):
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except (OSError, SyntaxError, UnicodeDecodeError) as error:
            result.parse_errors.append(f"{path.relative_to(repo_root)}: {error}")
            continue
        records = python_import_records(module, path, tree, module_names)
        result.import_records.extend(records)
        graph[module].update(
            record.target for record in records if record.target != module
        )
    return result


STATIC_FROM_RE = re.compile(
    r"(?:^|\n)\s*(?:import|export)\s+(?:type\s+)?(?:[\s\S]*?)\s+from\s*[\"']([^\"']+)[\"']",
    re.MULTILINE,
)
SIDE_EFFECT_RE = re.compile(r"(?:^|\n)\s*import\s*[\"']([^\"']+)[\"']", re.MULTILINE)
DYNAMIC_RE = re.compile(r"\b(?:import|require)\s*\(\s*[\"']([^\"']+)[\"']\s*\)")


def discover_app_modules(repo_root: Path) -> dict[str, Path]:
    root = repo_root / APP_ROOT
    modules: dict[str, Path] = {}
    if not root.is_dir():
        return modules
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix not in APP_EXTENSIONS:
            continue
        relative = path.relative_to(root)
        if any(part in APP_EXCLUDED_DIRS for part in relative.parts):
            continue
        if (
            ".test." in path.name
            or ".spec." in path.name
            or path.name.endswith(".d.ts")
        ):
            continue
        modules[relative.as_posix()] = path
    return modules


def app_aliases(source_files: dict[str, Path]) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for module in sorted(source_files):
        path = PurePosixPath(module)
        without_suffix = path.with_suffix("").as_posix()
        aliases.setdefault(without_suffix, module)
        if path.stem == "index":
            aliases.setdefault(path.parent.as_posix(), module)
        for extension in APP_EXTENSIONS:
            aliases.setdefault(f"{without_suffix}{extension}", module)
    return aliases


def normalize_posix_path(path: PurePosixPath) -> str:
    parts: list[str] = []
    for part in path.parts:
        if part in {"", "."}:
            continue
        if part == "..":
            if parts:
                parts.pop()
            continue
        parts.append(part)
    return "/".join(parts)


def resolve_app_specifier(
    source: str, specifier: str, aliases: dict[str, str]
) -> str | None:
    specifier = specifier.split("?", 1)[0].split("#", 1)[0]
    if specifier.startswith("@/"):
        candidate = specifier[2:]
    elif specifier.startswith("./") or specifier.startswith("../"):
        candidate = normalize_posix_path(PurePosixPath(source).parent / specifier)
    else:
        return None
    for extension in APP_EXTENSIONS:
        if candidate.endswith(extension):
            candidate = candidate[: -len(extension)]
            break
    return aliases.get(candidate) or aliases.get(f"{candidate}/index")


def typescript_specifiers(text: str) -> list[tuple[str, int, str]]:
    records: list[tuple[str, int, str]] = []
    occupied: set[tuple[int, int]] = set()
    for kind, pattern in (
        ("from", STATIC_FROM_RE),
        ("side-effect", SIDE_EFFECT_RE),
        ("dynamic", DYNAMIC_RE),
    ):
        for match in pattern.finditer(text):
            span = match.span(1)
            if span in occupied:
                continue
            occupied.add(span)
            line = text.count("\n", 0, match.start(1)) + 1
            records.append((match.group(1), line, kind))
    return records


def build_app_graph(repo_root: Path) -> GraphResult:
    source_files = discover_app_modules(repo_root)
    aliases = app_aliases(source_files)
    graph = {module: set() for module in source_files}
    result = GraphResult("app", graph, source_files)
    for module, path in sorted(source_files.items()):
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            result.parse_errors.append(f"{path.relative_to(repo_root)}: {error}")
            continue
        for specifier, line, kind in typescript_specifiers(text):
            target = resolve_app_specifier(module, specifier, aliases)
            if target and target != module:
                graph[module].add(target)
                result.import_records.append(ImportRecord(module, target, line, kind))
    return result


def strongly_connected_components(graph: dict[str, set[str]]) -> list[list[str]]:
    index = 0
    stack: list[str] = []
    on_stack: set[str] = set()
    indexes: dict[str, int] = {}
    lowlinks: dict[str, int] = {}
    components: list[list[str]] = []

    def visit(node: str) -> None:
        nonlocal index
        indexes[node] = index
        lowlinks[node] = index
        index += 1
        stack.append(node)
        on_stack.add(node)
        for target in sorted(graph.get(node, set())):
            if target not in graph:
                continue
            if target not in indexes:
                visit(target)
                lowlinks[node] = min(lowlinks[node], lowlinks[target])
            elif target in on_stack:
                lowlinks[node] = min(lowlinks[node], indexes[target])
        if lowlinks[node] != indexes[node]:
            return
        component: list[str] = []
        while stack:
            member = stack.pop()
            on_stack.remove(member)
            component.append(member)
            if member == node:
                break
        components.append(sorted(component))

    for node in sorted(graph):
        if node not in indexes:
            visit(node)
    return sorted(components, key=lambda component: (component[0], len(component)))


def cyclic_components(graph: dict[str, set[str]]) -> list[list[str]]:
    cycles = []
    for component in strongly_connected_components(graph):
        if len(component) > 1 or component[0] in graph.get(component[0], set()):
            cycles.append(component)
    return cycles


def is_social_module(module: str) -> bool:
    return any(
        module == prefix or module.startswith(f"{prefix}.")
        for prefix in SOCIAL_PREFIXES
    )


def summarize_backend(result: GraphResult) -> dict[str, object]:
    cycles = result.cycles
    social_cycles = [
        cycle for cycle in cycles if any(is_social_module(module) for module in cycle)
    ]
    legacy_records = [
        record
        for record in result.import_records
        if is_social_module(record.source)
        and record.source not in LEGACY_SOCIAL_MODULES
        and record.target in LEGACY_SOCIAL_MODULES
    ]
    legacy_occurrences = {
        (record.source, record.target, record.line, record.kind)
        for record in legacy_records
    }
    return {
        "scope_roots": list(BACKEND_ROOTS),
        "excluded_directories": sorted(PYTHON_EXCLUDED_DIRS),
        "module_count": len(result.graph),
        "edge_count": sum(len(targets) for targets in result.graph.values()),
        "cycle_count": len(cycles),
        "cyclic_module_count": len({module for cycle in cycles for module in cycle}),
        "social_cycle_count": len(social_cycles),
        "social_cyclic_module_count": len(
            {module for cycle in social_cycles for module in cycle}
        ),
        "legacy_social_import_count": len(legacy_occurrences),
        "legacy_social_importer_count": len(
            {record.source for record in legacy_records}
        ),
        "legacy_social_modules": sorted(LEGACY_SOCIAL_MODULES),
        "legacy_social_importers": sorted({record.source for record in legacy_records}),
        "cycles": cycles,
        "social_cycles": social_cycles,
        "source_sha256": source_digest(result.source_files),
        "graph_sha256": graph_digest(result.graph),
        "parse_errors": result.parse_errors,
    }


def summarize_app(result: GraphResult) -> dict[str, object]:
    cycles = result.cycles
    return {
        "scope_root": APP_ROOT,
        "extensions": list(APP_EXTENSIONS),
        "excluded_directories": sorted(APP_EXCLUDED_DIRS),
        "module_count": len(result.graph),
        "edge_count": sum(len(targets) for targets in result.graph.values()),
        "cycle_count": len(cycles),
        "cyclic_module_count": len({module for cycle in cycles for module in cycle}),
        "cycles": cycles,
        "source_sha256": source_digest(result.source_files),
        "graph_sha256": graph_digest(result.graph),
        "parse_errors": result.parse_errors,
    }


def metric_projection(summary: dict[str, object], component: str) -> dict[str, object]:
    keys = (
        (
            "module_count",
            "edge_count",
            "cycle_count",
            "cyclic_module_count",
            "social_cycle_count",
            "social_cyclic_module_count",
            "legacy_social_import_count",
            "legacy_social_importer_count",
        )
        if component == "backend"
        else ("module_count", "edge_count", "cycle_count", "cyclic_module_count")
    )
    projection: dict[str, object] = {key: int(summary[key]) for key in keys}
    projection["source_sha256"] = str(summary["source_sha256"])
    projection["graph_sha256"] = str(summary["graph_sha256"])
    return projection


def frozen_failures(report: dict[str, object]) -> list[str]:
    failures: list[str] = []
    if BASELINE.get("scope_version") != SCOPE_VERSION:
        failures.append(
            f"scope_version drifted: current={SCOPE_VERSION} "
            f"frozen={BASELINE.get('scope_version')}"
        )
    if BASELINE["backend"]["module_count"] < 0 or BASELINE["app"]["module_count"] < 0:
        return [*failures, "canonical frozen baseline has not been recorded"]
    for component in ("backend", "app"):
        expected = metric_projection(BASELINE[component], component)
        current = metric_projection(report[component], component)
        for metric, frozen_value in expected.items():
            current_value = current[metric]
            if current_value != frozen_value:
                failures.append(
                    f"{component}.{metric} drifted: "
                    f"current={current_value} frozen={frozen_value}"
                )
    return failures


def baseline_failures(report: dict[str, object]) -> list[str]:
    failures: list[str] = []
    if BASELINE["backend"]["module_count"] < 0 or BASELINE["app"]["module_count"] < 0:
        return ["canonical baseline has not been recorded"]
    comparisons = (
        ("backend", "social_cycle_count"),
        ("backend", "social_cyclic_module_count"),
        ("backend", "legacy_social_import_count"),
        ("backend", "legacy_social_importer_count"),
        ("app", "cycle_count"),
        ("app", "cyclic_module_count"),
    )
    for component, metric in comparisons:
        current = int(report[component][metric])
        allowed = int(BASELINE[component][metric])
        if current > allowed:
            failures.append(
                f"{component}.{metric} increased: current={current} baseline={allowed}"
            )
    return failures


def zero_failures(report: dict[str, object]) -> list[str]:
    failures = []
    checks = (
        ("backend", "social_cycle_count"),
        ("backend", "legacy_social_import_count"),
        ("app", "cycle_count"),
    )
    for component, metric in checks:
        value = int(report[component][metric])
        if value:
            failures.append(f"{component}.{metric} must be zero; current={value}")
    return failures


def parse_error_failures(report: dict[str, object]) -> list[str]:
    failures = []
    for component in ("backend", "app"):
        for error in report[component]["parse_errors"]:
            failures.append(f"{component} parse error: {error}")
    return failures


def trim_cycle_details(report: dict[str, object], maximum: int) -> dict[str, object]:
    copied = json.loads(json.dumps(report))
    for component in ("backend", "app"):
        if "cycles" in copied[component]:
            copied[component]["cycles"] = copied[component]["cycles"][:maximum]
    copied["backend"]["social_cycles"] = copied["backend"]["social_cycles"][:maximum]
    return copied


def render_text(
    report: dict[str, object], failures: Sequence[str], maximum: int
) -> str:
    lines = [
        f"scope_version={report['scope_version']}",
        (
            "backend "
            f"modules={report['backend']['module_count']} "
            f"edges={report['backend']['edge_count']} "
            f"cycles={report['backend']['cycle_count']} "
            f"social_cycles={report['backend']['social_cycle_count']} "
            f"legacy_social_imports={report['backend']['legacy_social_import_count']}"
        ),
        (
            "app "
            f"modules={report['app']['module_count']} "
            f"edges={report['app']['edge_count']} "
            f"cycles={report['app']['cycle_count']}"
        ),
        f"result={'fail' if failures else 'pass'}",
    ]
    for failure in failures:
        lines.append(f"failure={failure}")
    for component in ("backend", "app"):
        for cycle in report[component]["cycles"][:maximum]:
            lines.append(f"{component}_cycle={' -> '.join(cycle)}")
    return "\n".join(lines)


def build_report(repo_root: Path) -> dict[str, object]:
    backend = summarize_backend(build_backend_graph(repo_root))
    app = summarize_app(build_app_graph(repo_root))
    return {
        "scope_version": SCOPE_VERSION,
        "repo_root": str(repo_root),
        "gate_modes": {
            "gate_0e": "--check-frozen",
            "gate_1_and_refactor_packets": "--check-baseline",
            "final_acceptance": "--check-zero",
        },
        "backend": backend,
        "app": app,
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="TRR workspace root",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check-frozen",
        action="store_true",
        help="Gate 0E: fail on any exact source, graph, or metric drift",
    )
    mode.add_argument(
        "--check-baseline",
        action="store_true",
        help="Gate 1+: fail only when architecture debt exceeds its ceiling",
    )
    mode.add_argument(
        "--check-zero",
        action="store_true",
        help="enforce final zero-cycle/legacy acceptance",
    )
    mode.add_argument(
        "--print-baseline",
        action="store_true",
        help="print current metrics in baseline shape",
    )
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--max-cycle-details", type=int, default=20)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    repo_root = args.repo_root.expanduser().resolve()
    report = build_report(repo_root)
    if args.print_baseline:
        baseline = {
            "scope_version": SCOPE_VERSION,
            "captured_at": "replace-with-current-utc-timestamp",
            "backend": metric_projection(report["backend"], "backend"),
            "app": metric_projection(report["app"], "app"),
        }
        print(json.dumps(baseline, indent=2, sort_keys=True))
        return 2 if parse_error_failures(report) else 0

    failures = parse_error_failures(report)
    if args.check_frozen:
        failures.extend(frozen_failures(report))
    elif args.check_baseline:
        failures.extend(baseline_failures(report))
    elif args.check_zero:
        failures.extend(zero_failures(report))
    if args.check_frozen:
        report["mode"] = "frozen"
    elif args.check_baseline:
        report["mode"] = "baseline-ceiling"
    elif args.check_zero:
        report["mode"] = "zero"
    else:
        report["mode"] = "report"
    report["result"] = "fail" if failures else "pass"
    report["failures"] = failures
    if args.format == "json":
        print(
            json.dumps(
                trim_cycle_details(report, args.max_cycle_details),
                indent=2,
                sort_keys=True,
            )
        )
    else:
        print(render_text(report, failures, args.max_cycle_details))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
