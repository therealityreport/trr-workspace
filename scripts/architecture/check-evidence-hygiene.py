#!/usr/bin/env python3
"""Reject credential-like content and broad permissions in architecture evidence."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import stat
from typing import Iterable


WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCAN_PATHS = (
    Path(".plan-work/plan-architect/trr-architecture-overhaul-20260715"),
    Path("docs/workspace/architecture-evidence.schema.json"),
    Path("docs/workspace/architecture-hotspots.json"),
    Path("docs/workspace/architecture-task-locks.json"),
    Path("docs/workspace/release-packet.schema.json"),
    Path("docs/workspace/release-packets"),
    Path("docs/workspace/architecture-evidence"),
    Path("artifacts/architecture-overhaul"),
)
DETAILED_EVIDENCE_ROOT = Path("artifacts/architecture-overhaul")
TEXT_SUFFIXES = {
    ".cfg",
    ".cjs",
    ".conf",
    ".csv",
    ".env",
    ".html",
    ".ini",
    ".js",
    ".json",
    ".jsonl",
    ".key",
    ".log",
    ".md",
    ".mjs",
    ".pem",
    ".properties",
    ".py",
    ".sh",
    ".sql",
    ".toml",
    ".ts",
    ".tsv",
    ".tsx",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}
MAX_TEXT_BYTES = 10 * 1024 * 1024


@dataclass(frozen=True)
class SecretPattern:
    label: str
    pattern: re.Pattern[str]


SECRET_PATTERNS = (
    SecretPattern("private-key", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    SecretPattern("database-url", re.compile(r"(?i)\bpostgres(?:ql)?://")),
    SecretPattern("url-credentials", re.compile(r"(?i)https://[^/\s:@]+:[^/\s@]+@")),
    SecretPattern("bearer-token", re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}")),
    SecretPattern("github-or-slack-token", re.compile(r"(?i)\b(?:gh[pousr]|xox[baprs])[-_][A-Za-z0-9_-]{12,}")),
    SecretPattern(
        "provider-secret",
        re.compile(
            r"(?i)\b(?:(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{8,}|"
            r"sk-(?:proj-)?[A-Za-z0-9_-]{20,}|sb_secret_[A-Za-z0-9_-]{16,})"
        ),
    ),
    SecretPattern(
        "jwt",
        re.compile(
            r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"
        ),
    ),
    SecretPattern("aws-access-key", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    SecretPattern(
        "secret-assignment",
        re.compile(
            r"(?i)\b(?:api[_-]?key|authorization|cookie|database[_-]?url|dsn|password|"
            r"private[_-]?key|secret|token)\s*[:=]\s*"
            r"(?!\$|<|\{|redacted\b|none\b|null\b|false\b|true\b|\*{3})[^\s,;]+"
        ),
    ),
)


def _within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _is_text_evidence(path: Path) -> bool:
    name = path.name.lower()
    return path.suffix.lower() in TEXT_SUFFIXES or name == ".env" or name.startswith(".env.")


def discover_files(root: Path, paths: Iterable[Path]) -> list[Path]:
    files: set[Path] = set()
    for raw_path in paths:
        path = raw_path if raw_path.is_absolute() else root / raw_path
        if not _within(path, root):
            raise ValueError(f"scan path escapes workspace: {raw_path}")
        if path.is_symlink():
            raise ValueError(f"scan path must not be a symlink: {raw_path}")
        if path.is_file():
            files.add(path.resolve())
            continue
        if not path.is_dir():
            continue
        for candidate in path.rglob("*"):
            if candidate.is_symlink():
                raise ValueError(f"scan path entry must not be a symlink: {candidate}")
            if candidate.is_file() and _is_text_evidence(candidate):
                if _within(candidate, root):
                    files.add(candidate.resolve())
    return sorted(files)


def scan_file(path: Path) -> list[str]:
    size = path.stat().st_size
    if size > MAX_TEXT_BYTES:
        return [f"{path}: text evidence exceeds {MAX_TEXT_BYTES} bytes"]
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return [f"{path}: text evidence is not valid UTF-8"]
    failures: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        for secret_pattern in SECRET_PATTERNS:
            if secret_pattern.pattern.search(line):
                failures.append(f"{path}:{line_number}: matched {secret_pattern.label}")
    return failures


def evidence_permission_failures(root: Path) -> list[str]:
    unresolved_root = root / DETAILED_EVIDENCE_ROOT
    if unresolved_root.is_symlink():
        return [f"{unresolved_root}: detailed evidence root must not be a symlink"]
    evidence_root = unresolved_root.resolve()
    if not _within(evidence_root, root):
        return [f"{unresolved_root}: detailed evidence root escapes workspace"]
    if not evidence_root.is_dir():
        return []
    failures: list[str] = []
    for path in [evidence_root, *sorted(evidence_root.rglob("*"))]:
        if path.is_symlink():
            failures.append(f"{path}: symlinks are forbidden in detailed evidence")
            continue
        mode = stat.S_IMODE(path.stat().st_mode)
        if mode & 0o077:
            kind = "directory" if path.is_dir() else "file"
            failures.append(f"{path}: {kind} mode {mode:04o} exposes group/world permissions")
    return failures


def validate_evidence_hygiene(root: Path, paths: Iterable[Path]) -> tuple[int, list[str]]:
    root = root.resolve()
    files = discover_files(root, paths)
    failures = evidence_permission_failures(root)
    for path in files:
        failures.extend(scan_file(path))
    return len(files), failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=WORKSPACE_ROOT)
    parser.add_argument("--path", type=Path, action="append", default=[])
    args = parser.parse_args()

    try:
        file_count, failures = validate_evidence_hygiene(
            args.root,
            args.path or DEFAULT_SCAN_PATHS,
        )
    except (OSError, ValueError) as exc:
        print(f"architecture-evidence-hygiene: ERROR {exc}")
        return 1
    if failures:
        for failure in failures:
            print(f"architecture-evidence-hygiene: ERROR {failure}")
        return 1
    print(f"architecture-evidence-hygiene: OK files={file_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
