#!/usr/bin/env python3
"""Generate and validate scope-level HANDOFF.md files from canonical snapshots."""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import difflib
import fcntl
import os
import re
import sys
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

ROOT = Path(__file__).resolve().parents[1]

EXIT_DRIFT = 1
EXIT_INVALID_SOURCE = 2
EXIT_FRESHNESS = 3
EXIT_LOCK_TIMEOUT = 4
EXIT_RUNTIME = 5

STATE_ACTIVE = "active"
STATE_BLOCKED = "blocked"
STATE_RECENT = "recent"
STATE_ARCHIVED = "archived"
STATE_OLDER = "older"
VALID_STATES = {STATE_ACTIVE, STATE_BLOCKED, STATE_RECENT, STATE_ARCHIVED}
FRESHNESS_LIMITS = {
    STATE_ACTIVE: 3,
    STATE_BLOCKED: 14,
    STATE_RECENT: 7,
}
RECENT_COMPLETIONS_LIMIT = 5
OLDER_PLANS_LIMIT = 10

TASK_STATUS_RE = re.compile(r"^Status\s+[—-]\s+Task\s+(\d+)\s+\((.+)\)\s*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
H1_RE = re.compile(r"^#\s+(.+?)\s*$")


class SyncHandoffsError(Exception):
    exit_code = EXIT_RUNTIME


class DriftError(SyncHandoffsError):
    exit_code = EXIT_DRIFT


class InvalidSourceError(SyncHandoffsError):
    exit_code = EXIT_INVALID_SOURCE


class FreshnessError(SyncHandoffsError):
    exit_code = EXIT_FRESHNESS


class LockTimeoutError(SyncHandoffsError):
    exit_code = EXIT_LOCK_TIMEOUT


@dataclasses.dataclass(frozen=True)
class HandoffSnapshot:
    include: bool
    state: str
    last_updated: dt.date
    current_phase: str
    next_action: str
    detail: str


@dataclasses.dataclass(frozen=True)
class HandoffItem:
    title: str
    source_path: Path
    snapshot: HandoffSnapshot


@dataclasses.dataclass(frozen=True)
class ScopeConfig:
    key: str
    title: str
    handoff_path: Path
    purpose: str
    task_status_glob: str | None
    local_status_dir: Path
    static_links: tuple[tuple[str, str], ...]


def build_scopes(root: Path) -> dict[str, ScopeConfig]:
    return {
        "workspace": ScopeConfig(
            key="workspace",
            title="TRR Workspace",
            handoff_path=root / "docs/ai/HANDOFF.md",
            purpose=(
                "active-work index for multi-turn AI agent sessions affecting "
                "workspace-level tooling or cross-repo coordination. Keep this file short."
            ),
            task_status_glob=None,
            local_status_dir=root / "docs/ai/local-status",
            static_links=(
                ("History archive", "archive/HANDOFF-legacy-2026-03-16.md"),
                ("Canonical workflow", "../cross-collab/WORKFLOW.md"),
                ("Workspace policy", "../../AGENTS.md"),
                ("TRR-Backend handoff", "../../TRR-Backend/docs/ai/HANDOFF.md"),
                ("TRR-APP handoff", "../../TRR-APP/docs/ai/HANDOFF.md"),
                ("screenalytics handoff", "../../screenalytics/docs/ai/HANDOFF.md"),
            ),
        ),
        "backend": ScopeConfig(
            key="backend",
            title="TRR-Backend",
            handoff_path=root / "TRR-Backend/docs/ai/HANDOFF.md",
            purpose="active-work index for multi-turn AI agent sessions in `TRR-Backend`. Keep this file short.",
            task_status_glob="TRR-Backend/docs/cross-collab/TASK*/STATUS.md",
            local_status_dir=root / "TRR-Backend/docs/ai/local-status",
            static_links=(
                ("History archive", "archive/HANDOFF-legacy-2026-03-16.md"),
                ("Canonical workflow", "../../../docs/cross-collab/WORKFLOW.md"),
                ("Repo policy", "../../AGENTS.md"),
            ),
        ),
        "app": ScopeConfig(
            key="app",
            title="TRR-APP",
            handoff_path=root / "TRR-APP/docs/ai/HANDOFF.md",
            purpose="active-work index for multi-turn AI agent sessions in `TRR-APP`. Keep this file short.",
            task_status_glob="TRR-APP/docs/cross-collab/TASK*/STATUS.md",
            local_status_dir=root / "TRR-APP/docs/ai/local-status",
            static_links=(
                ("History archive", "archive/HANDOFF-legacy-2026-03-16.md"),
                ("Canonical workflow", "../../../docs/cross-collab/WORKFLOW.md"),
                ("Repo policy", "../../AGENTS.md"),
            ),
        ),
        "screenalytics": ScopeConfig(
            key="screenalytics",
            title="screenalytics",
            handoff_path=root / "screenalytics/docs/ai/HANDOFF.md",
            purpose="active-work index for multi-turn AI agent sessions in `screenalytics`. Keep this file short.",
            task_status_glob="screenalytics/docs/cross-collab/TASK*/STATUS.md",
            local_status_dir=root / "screenalytics/docs/ai/local-status",
            static_links=(
                ("History archive", "archive/HANDOFF-legacy-2026-03-16.md"),
                ("Canonical workflow", "../../../docs/cross-collab/WORKFLOW.md"),
                ("Repo policy", "../../AGENTS.md"),
            ),
        ),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Check generated handoffs for drift.")
    mode.add_argument("--write", action="store_true", help="Write generated handoffs.")
    parser.add_argument(
        "--scope",
        action="append",
        choices=("workspace", "backend", "app", "screenalytics"),
        help="Limit work to one or more named scopes.",
    )
    parser.add_argument(
        "--lock-timeout-seconds",
        type=float,
        default=10.0,
        help="How long to wait for the shared handoff lock.",
    )
    return parser.parse_args()


def strip_quotes(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def read_h1(text: str, source_path: Path) -> str:
    for line in text.splitlines():
        match = H1_RE.match(line)
        if match:
            return match.group(1).strip()
    raise InvalidSourceError(f"{source_path}: missing top-level H1 title.")


def extract_snapshot_yaml(text: str, source_path: Path, *, required: bool = True) -> str | None:
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.strip() != "## Handoff Snapshot":
            continue
        fence_index = index + 1
        while fence_index < len(lines) and not lines[fence_index].strip():
            fence_index += 1
        if fence_index >= len(lines) or lines[fence_index].strip() != "```yaml":
            raise InvalidSourceError(
                f"{source_path}: expected ```yaml fence immediately after '## Handoff Snapshot'."
            )
        end_index = fence_index + 1
        while end_index < len(lines) and lines[end_index].strip() != "```":
            end_index += 1
        if end_index >= len(lines):
            raise InvalidSourceError(f"{source_path}: unterminated Handoff Snapshot fenced block.")
        return "\n".join(lines[fence_index + 1 : end_index])
    if required:
        raise InvalidSourceError(f"{source_path}: missing '## Handoff Snapshot' section.")
    return None


def parse_snapshot_block(block: str, source_path: Path) -> HandoffSnapshot:
    raw_lines = [line.rstrip() for line in block.splitlines() if line.strip()]
    if not raw_lines or raw_lines[0].strip() != "handoff:":
        raise InvalidSourceError(f"{source_path}: snapshot block must start with 'handoff:'.")

    values: dict[str, str] = {}
    for line in raw_lines[1:]:
        if not line.startswith("  "):
            raise InvalidSourceError(
                f"{source_path}: snapshot fields must be indented two spaces under 'handoff:'."
            )
        stripped = line[2:]
        if ":" not in stripped:
            raise InvalidSourceError(f"{source_path}: invalid snapshot line: {line!r}")
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = strip_quotes(value.strip())
        if key in values:
            raise InvalidSourceError(f"{source_path}: duplicate snapshot key '{key}'.")
        values[key] = value

    required_keys = {"include", "state", "last_updated", "current_phase", "next_action", "detail"}
    missing = required_keys - set(values)
    unknown = set(values) - required_keys
    if missing:
        raise InvalidSourceError(f"{source_path}: missing snapshot keys: {', '.join(sorted(missing))}.")
    if unknown:
        raise InvalidSourceError(f"{source_path}: unknown snapshot keys: {', '.join(sorted(unknown))}.")

    include_raw = values["include"].lower()
    if include_raw not in {"true", "false"}:
        raise InvalidSourceError(f"{source_path}: include must be true or false.")
    include = include_raw == "true"

    state = values["state"]
    if state not in VALID_STATES:
        raise InvalidSourceError(
            f"{source_path}: state must be one of {', '.join(sorted(VALID_STATES))}."
        )

    if not DATE_RE.match(values["last_updated"]):
        raise InvalidSourceError(f"{source_path}: last_updated must be YYYY-MM-DD.")
    last_updated = dt.date.fromisoformat(values["last_updated"])

    current_phase = values["current_phase"].strip()
    next_action = values["next_action"].strip()
    detail = values["detail"].strip()
    if not current_phase:
        raise InvalidSourceError(f"{source_path}: current_phase must not be empty.")
    if not next_action:
        raise InvalidSourceError(f"{source_path}: next_action must not be empty.")
    if not detail:
        raise InvalidSourceError(f"{source_path}: detail must not be empty.")
    if detail != "self":
        detail_path = (source_path.parent / detail).resolve()
        root_resolved = ROOT.resolve()
        try:
            detail_path.relative_to(root_resolved)
        except ValueError as exc:
            raise InvalidSourceError(
                f"{source_path}: detail path must resolve inside the workspace: {detail}"
            ) from exc
        if not detail_path.exists():
            raise InvalidSourceError(f"{source_path}: detail path does not exist: {detail}")

    return HandoffSnapshot(
        include=include,
        state=state,
        last_updated=last_updated,
        current_phase=current_phase,
        next_action=next_action,
        detail=detail,
    )


def derive_title(h1: str) -> str:
    match = TASK_STATUS_RE.match(h1)
    if match:
        task_number = int(match.group(1))
        return f"TASK{task_number} {match.group(2).strip()}"
    return h1.strip()


def classify_render_state(item: HandoffItem, today: dt.date) -> str:
    age_days = (today - item.snapshot.last_updated).days
    freshness_limit = FRESHNESS_LIMITS.get(item.snapshot.state)
    if freshness_limit is not None and age_days > freshness_limit:
        return STATE_OLDER
    return item.snapshot.state


def parse_source_file(source_path: Path, today: dt.date, *, snapshot_required: bool = True) -> HandoffItem | None:
    text = source_path.read_text(encoding="utf-8")
    h1 = read_h1(text, source_path)
    snapshot_yaml = extract_snapshot_yaml(text, source_path, required=snapshot_required)
    if snapshot_yaml is None:
        return None
    snapshot = parse_snapshot_block(snapshot_yaml, source_path)
    if not snapshot.include or snapshot.state == STATE_ARCHIVED:
        return None
    item = HandoffItem(title=derive_title(h1), source_path=source_path, snapshot=snapshot)
    return item


def task_sort_key(path: Path) -> tuple[int, str]:
    match = re.search(r"TASK(\d+)", path.as_posix())
    if match:
        return (int(match.group(1)), path.as_posix())
    return (sys.maxsize, path.as_posix())


def iter_scope_sources(scope: ScopeConfig) -> Iterator[tuple[Path, bool]]:
    if scope.local_status_dir.exists():
        for path in sorted(scope.local_status_dir.glob("*.md")):
            yield path, True
    if scope.task_status_glob:
        for path in sorted(ROOT.glob(scope.task_status_glob), key=task_sort_key):
            yield path, False


def collect_scope_items(scope: ScopeConfig, today: dt.date) -> list[HandoffItem]:
    items: list[HandoffItem] = []
    for source_path, snapshot_required in iter_scope_sources(scope):
        item = parse_source_file(source_path, today, snapshot_required=snapshot_required)
        if item is not None:
            items.append(item)
    return items


def relative_detail_path(target: Path, handoff_path: Path) -> str:
    return os.path.relpath(target, start=handoff_path.parent).replace(os.sep, "/")


def render_items(items: list[HandoffItem], handoff_path: Path) -> list[str]:
    if not items:
        return ["- None."]
    rendered: list[str] = []
    for item in items:
        detail_path = item.source_path if item.snapshot.detail == "self" else (item.source_path.parent / item.snapshot.detail)
        rendered.append(
            "- "
            f"`{item.title}` | last updated `{item.snapshot.last_updated.isoformat()}` | "
            f"current phase `{item.snapshot.current_phase}` | next action `{item.snapshot.next_action}` | "
            f"details `{relative_detail_path(detail_path.resolve(), handoff_path)}`"
        )
    return rendered


def render_scope(scope: ScopeConfig, today: dt.date) -> str:
    items = collect_scope_items(scope, today)
    sorted_items = sorted(items, key=lambda item: (item.snapshot.last_updated, item.title), reverse=True)
    grouped = {
        STATE_ACTIVE: [],
        STATE_BLOCKED: [],
        STATE_RECENT: [],
        STATE_OLDER: [],
    }
    for item in sorted_items:
        grouped[classify_render_state(item, today)].append(item)
    grouped[STATE_RECENT] = grouped[STATE_RECENT][:RECENT_COMPLETIONS_LIMIT]
    grouped[STATE_OLDER] = grouped[STATE_OLDER][:OLDER_PLANS_LIMIT]

    lines = [
        f"# Session Handoff ({scope.title})",
        "",
        "Generated by `scripts/sync-handoffs.py`. Do not edit by hand.",
        "",
        f"Purpose: {scope.purpose}",
        "",
        "## Current Active Work",
        *render_items(grouped[STATE_ACTIVE], scope.handoff_path),
        "",
        "## Blocked / Waiting",
        *render_items(grouped[STATE_BLOCKED], scope.handoff_path),
        "",
        "## Recent Completions",
        *render_items(grouped[STATE_RECENT], scope.handoff_path),
        "",
        "## Older Plans",
        *render_items(grouped[STATE_OLDER], scope.handoff_path),
        "",
        "## Archives / Canonical Links",
    ]
    for label, relative_path in scope.static_links:
        lines.append(f"- {label}: `{relative_path}`")
    lines.append("")
    return "\n".join(lines)


def render_selected_scopes(selected_scopes: list[ScopeConfig], today: dt.date) -> dict[Path, str]:
    return {scope.handoff_path: render_scope(scope, today) for scope in selected_scopes}


def emit_drift(path: Path, expected: str, actual: str) -> None:
    diff = difflib.unified_diff(
        actual.splitlines(),
        expected.splitlines(),
        fromfile=str(path),
        tofile=f"{path} (generated)",
        lineterm="",
    )
    sys.stderr.write("\n".join(diff) + "\n")


@contextmanager
def lock_workspace(exclusive: bool, timeout_seconds: float) -> Iterator[None]:
    lockfile = ROOT / ".locks" / "handoff-sync.lock"
    lockfile.parent.mkdir(parents=True, exist_ok=True)
    with lockfile.open("a+", encoding="utf-8") as handle:
        lock_type = fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH
        deadline = time.monotonic() + timeout_seconds
        while True:
            try:
                fcntl.flock(handle.fileno(), lock_type | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise LockTimeoutError(
                        f"Timed out waiting for handoff lock at {lockfile}; another sync is still running."
                    )
                time.sleep(0.1)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def run_check(rendered: dict[Path, str]) -> None:
    drift_detected = False
    for path, expected in rendered.items():
        actual = path.read_text(encoding="utf-8") if path.exists() else ""
        if actual != expected:
            drift_detected = True
            emit_drift(path, expected, actual)
    if drift_detected:
        raise DriftError("Generated handoffs are out of sync.")


def run_write(rendered: dict[Path, str]) -> None:
    for path, expected in rendered.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")


def selected_scopes(args: argparse.Namespace) -> list[ScopeConfig]:
    scopes = build_scopes(ROOT)
    if not args.scope:
        return list(scopes.values())
    return [scopes[key] for key in args.scope]


def main() -> int:
    args = parse_args()
    today = dt.date.today()
    scopes = selected_scopes(args)

    try:
        with lock_workspace(exclusive=args.write, timeout_seconds=args.lock_timeout_seconds):
            rendered = render_selected_scopes(scopes, today)
            if args.write:
                run_write(rendered)
            else:
                run_check(rendered)
    except SyncHandoffsError as exc:
        print(f"[sync-handoffs] ERROR: {exc}", file=sys.stderr)
        return exc.exit_code
    except Exception as exc:  # pragma: no cover - defensive fallback
        print(f"[sync-handoffs] ERROR: unexpected failure: {exc}", file=sys.stderr)
        return EXIT_RUNTIME

    action = "wrote" if args.write else "verified"
    scope_names = ", ".join(scope.key for scope in scopes)
    print(f"[sync-handoffs] OK: {action} handoffs for {scope_names}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
