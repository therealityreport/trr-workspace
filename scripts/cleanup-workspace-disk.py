#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
TRR_BACKEND_ROOT = WORKSPACE_ROOT / "TRR-Backend"
TRR_APP_ROOT = WORKSPACE_ROOT / "TRR-APP"
SCREENALYTICS_ROOT = WORKSPACE_ROOT / "screenalytics"
SCREENALYTICS_DATA_ROOT = SCREENALYTICS_ROOT / "data"
SCREENALYTICS_PROTECTED_PATH_DESCRIPTIONS = (
    "screenalytics/.env and screenalytics/.env.* (local secrets)",
    "screenalytics/.git (nested repository history)",
    "screenalytics/data/ (local data)",
    "dirty nested Screenalytics source files (never selected by this script)",
)
SCREENALYTICS_GENERATED_ARTIFACTS = (
    (".venv", "python virtual environment"),
    (".venv-crawl4ai", "crawl4ai python virtual environment"),
    ("web/node_modules", "web dependency install"),
    ("web/.next", "Next.js build output"),
    (".pytest_cache", "pytest cache"),
    (".ruff_cache", "ruff cache"),
    (".logs", "local logs"),
    ("tmp", "temporary generated output"),
    (".cache", "local cache"),
    ("web/.cache", "web cache"),
    ("web/.turbo", "Turborepo cache"),
    ("web/test-results", "web test output"),
    ("web/dist", "web distribution output"),
    ("web/build", "web build output"),
    ("outputs", "generated output"),
    ("output", "generated output"),
)
REPO_ROOTS = {
    name: path
    for name, path in {
        "workspace": WORKSPACE_ROOT,
        "TRR-Backend": TRR_BACKEND_ROOT,
        "TRR-APP": TRR_APP_ROOT,
        "screenalytics (legacy)": SCREENALYTICS_ROOT,
    }.items()
    if path.exists()
}
MEDIA_EXTENSIONS = {
    ".mp4",
    ".mov",
    ".m4v",
    ".webm",
    ".wav",
    ".mp3",
    ".m4a",
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".gif",
}
EPISODE_ID_RE = re.compile(r".+-s\d+e\d+$", re.IGNORECASE)


@dataclass
class CleanupCandidate:
    category: str
    path: Path
    size_bytes: int
    reason: str


def human_bytes(value: int) -> str:
    size = float(max(value, 0))
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if size < 1024 or unit == "TB":
            return f"{size:.1f}{unit}"
        size /= 1024
    return f"{size:.1f}TB"


def dir_size(path: Path) -> int:
    if not path.exists():
        return 0
    if path.is_file():
        try:
            return path.stat().st_size
        except OSError:
            return 0
    total = 0
    for child in path.rglob("*"):
        if child.is_file():
            try:
                total += child.stat().st_size
            except OSError:
                continue
    return total


def latest_mtime(path: Path) -> float:
    latest = 0.0
    if not path.exists():
        return latest
    try:
        latest = path.stat().st_mtime
    except OSError:
        return latest
    if path.is_dir():
        for child in path.rglob("*"):
            try:
                latest = max(latest, child.stat().st_mtime)
            except OSError:
                continue
    return latest


def build_cache_candidates() -> list[CleanupCandidate]:
    patterns = [
        WORKSPACE_ROOT / ".logs",
        TRR_BACKEND_ROOT / ".pytest_cache",
        TRR_BACKEND_ROOT / ".ruff_cache",
        TRR_BACKEND_ROOT / ".playwright-profiles",
        TRR_APP_ROOT / ".ruff_cache",
        TRR_APP_ROOT / ".playwright-mcp",
        TRR_APP_ROOT / ".emulator-data",
        TRR_APP_ROOT / "apps" / "web" / ".next",
        TRR_APP_ROOT / "apps" / "web" / ".next-turbo-test",
        TRR_APP_ROOT / "apps" / "web" / "test-results",
        SCREENALYTICS_ROOT / ".pytest_cache",
        SCREENALYTICS_ROOT / ".ruff_cache",
        SCREENALYTICS_ROOT / ".logs",
        SCREENALYTICS_ROOT / "web" / ".next",
        SCREENALYTICS_ROOT / "tmp",
    ]
    candidates: list[CleanupCandidate] = []
    for path in patterns:
        if path.exists():
            candidates.append(
                CleanupCandidate(
                    category="build-cache",
                    path=path,
                    size_bytes=dir_size(path),
                    reason="workspace cache/log artifact",
                )
            )
    return candidates


def is_screenalytics_protected_path(path: Path) -> bool:
    try:
        relative_path = path.resolve().relative_to(SCREENALYTICS_ROOT.resolve())
    except ValueError:
        return False
    if relative_path.parts in {(".git",), ("data",)}:
        return True
    if relative_path.parts and relative_path.parts[0] in {".git", "data"}:
        return True
    return path.name == ".env" or path.name.startswith(".env.")


def screenalytics_generated_artifact_candidates() -> list[CleanupCandidate]:
    candidates: list[CleanupCandidate] = []
    for relative_path, reason in SCREENALYTICS_GENERATED_ARTIFACTS:
        path = SCREENALYTICS_ROOT / relative_path
        if not path.exists() or is_screenalytics_protected_path(path):
            continue
        candidates.append(
            CleanupCandidate(
                category="screenalytics-generated",
                path=path,
                size_bytes=dir_size(path),
                reason=reason,
            )
        )
    return candidates


def download_dump_candidates() -> list[CleanupCandidate]:
    candidates: list[CleanupCandidate] = []
    for path in TRR_BACKEND_ROOT.glob("scripts/socials/*/output/*_downloads"):
        if path.exists():
            candidates.append(
                CleanupCandidate(
                    category="download-dump",
                    path=path,
                    size_bytes=dir_size(path),
                    reason="repo-local ad hoc social media download dump",
                )
            )
    return candidates


def screenalytics_artifact_candidates(*, keep_days: int) -> tuple[list[CleanupCandidate], list[CleanupCandidate]]:
    cutoff = datetime.now() - timedelta(days=keep_days)
    cleanup_roots = {
        "audio": SCREENALYTICS_DATA_ROOT / "audio",
        "analytics": SCREENALYTICS_DATA_ROOT / "analytics",
        "videos": SCREENALYTICS_DATA_ROOT / "videos",
        "frames": SCREENALYTICS_DATA_ROOT / "frames",
        "manifests": SCREENALYTICS_DATA_ROOT / "manifests",
    }
    deletable: list[CleanupCandidate] = []
    preserved: list[CleanupCandidate] = []
    for root_name, root in cleanup_roots.items():
        if not root.exists():
            continue
        for child in sorted(root.iterdir()):
            if not child.is_dir():
                continue
            if not EPISODE_ID_RE.fullmatch(child.name):
                continue
            updated_at = datetime.fromtimestamp(latest_mtime(child))
            candidate = CleanupCandidate(
                category="screenalytics-artifact",
                path=child,
                size_bytes=dir_size(child),
                reason=f"{root_name} artifact last touched {updated_at.isoformat(timespec='seconds')}",
            )
            if updated_at < cutoff:
                deletable.append(candidate)
            else:
                preserved.append(candidate)
    return deletable, preserved


def list_repo_subdirs(repo_root: Path) -> list[tuple[Path, int]]:
    if not repo_root.exists():
        return []
    entries: list[tuple[Path, int]] = []
    for child in sorted(repo_root.iterdir()):
        if child.name == ".git":
            continue
        try:
            if child.is_dir():
                entries.append((child, dir_size(child)))
            elif child.is_file():
                entries.append((child, child.stat().st_size))
        except OSError:
            continue
    return sorted(entries, key=lambda item: item[1], reverse=True)


def git_tracked_paths(repo_root: Path) -> set[str]:
    if not repo_root.exists() or not (repo_root / ".git").exists():
        return set()
    proc = subprocess.run(
        ["git", "-C", str(repo_root), "ls-files", "-z"],
        capture_output=True,
        text=False,
        check=False,
    )
    if proc.returncode != 0:
        return set()
    return {
        entry.decode("utf-8", errors="ignore")
        for entry in proc.stdout.split(b"\x00")
        if entry
    }


def large_untracked_media_files(*, min_bytes: int) -> list[tuple[Path, int]]:
    offenders: list[tuple[Path, int]] = []
    for repo_root in (TRR_BACKEND_ROOT, TRR_APP_ROOT, SCREENALYTICS_ROOT):
        if not repo_root.exists():
            continue
        tracked = git_tracked_paths(repo_root)
        for current_root, dirnames, filenames in os.walk(repo_root):
            root_path = Path(current_root)
            dirnames[:] = [
                name
                for name in dirnames
                if name not in {".git", "node_modules", ".venv"}
            ]
            for filename in filenames:
                path = root_path / filename
                if path.suffix.lower() not in MEDIA_EXTENSIONS:
                    continue
                rel_path = path.relative_to(repo_root).as_posix()
                if rel_path in tracked:
                    continue
                try:
                    size_bytes = path.stat().st_size
                except OSError:
                    continue
                if size_bytes >= min_bytes:
                    offenders.append((path, size_bytes))
    offenders.sort(key=lambda item: item[1], reverse=True)
    return offenders


def screenalytics_episode_sizes() -> list[tuple[str, int]]:
    if not SCREENALYTICS_DATA_ROOT.exists():
        return []
    episode_sizes: dict[str, int] = {}
    roots = [
        SCREENALYTICS_DATA_ROOT / "audio",
        SCREENALYTICS_DATA_ROOT / "analytics",
        SCREENALYTICS_DATA_ROOT / "videos",
        SCREENALYTICS_DATA_ROOT / "frames",
        SCREENALYTICS_DATA_ROOT / "manifests",
    ]
    for root in roots:
        if not root.exists():
            continue
        for child in root.iterdir():
            if child.is_dir() and EPISODE_ID_RE.fullmatch(child.name):
                episode_sizes[child.name] = episode_sizes.get(child.name, 0) + dir_size(child)
    return sorted(episode_sizes.items(), key=lambda item: item[1], reverse=True)


def delete_candidate(candidate: CleanupCandidate) -> None:
    if is_screenalytics_protected_path(candidate.path):
        raise RuntimeError(f"refusing to delete protected path: {candidate.path}")
    if candidate.path.is_dir():
        shutil.rmtree(candidate.path)
    elif candidate.path.exists():
        candidate.path.unlink()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit and clean workspace disk usage.",
        epilog=(
            "Protected by default: "
            + "; ".join(SCREENALYTICS_PROTECTED_PATH_DESCRIPTIONS)
            + ". Apply mode requires both --apply and --confirm-delete-local-artifacts."
        ),
    )
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--dry-run", action="store_true", help="Preview cleanup targets (default behavior).")
    mode_group.add_argument("--apply", action="store_true", help="Delete the selected targets; requires --confirm-delete-local-artifacts.")
    parser.add_argument(
        "--confirm-delete-local-artifacts",
        action="store_true",
        help="Required with --apply so destructive cleanup cannot be triggered accidentally.",
    )
    parser.add_argument("--keep-days", type=int, default=14, help="Retention window for legacy screenalytics episode artifacts.")
    parser.add_argument(
        "--include-screenalytics-local-generated",
        action="store_true",
        help="Include generated Screenalytics local artifacts such as .venv, web/node_modules, web/.next, caches, and logs.",
    )
    parser.add_argument(
        "--include-screenalytics-artifacts",
        action="store_true",
        help="Report old legacy screenalytics episode artifact directories; screenalytics/data/ remains protected by default.",
    )
    parser.add_argument(
        "--include-build-caches",
        action="store_true",
        help="Include build/test/cache/log directories in cleanup targets.",
    )
    parser.add_argument(
        "--include-download-dumps",
        action="store_true",
        help="Include repo-local social media download dump directories in cleanup targets.",
    )
    parser.add_argument(
        "--min-media-mb",
        type=int,
        default=20,
        help="Minimum size for large-media offender reporting (default: 20MB).",
    )
    args = parser.parse_args(argv)
    if args.apply and not args.confirm_delete_local_artifacts:
        parser.error("--apply requires --confirm-delete-local-artifacts")
    return args


def dedupe_candidates(candidates: list[CleanupCandidate]) -> list[CleanupCandidate]:
    seen: set[Path] = set()
    deduped: list[CleanupCandidate] = []
    for candidate in candidates:
        try:
            key = candidate.path.resolve()
        except OSError:
            key = candidate.path
        if key in seen:
            continue
        seen.add(key)
        deduped.append(candidate)
    return deduped


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    apply = bool(args.apply)
    keep_days = max(int(args.keep_days), 0)
    min_media_bytes = max(int(args.min_media_mb), 1) * 1024 * 1024

    if not any(
        (
            args.include_screenalytics_local_generated,
            args.include_screenalytics_artifacts,
            args.include_build_caches,
            args.include_download_dumps,
        )
    ):
        args.include_screenalytics_local_generated = SCREENALYTICS_ROOT.exists()
        args.include_build_caches = True
        args.include_download_dumps = False

    print("== Top Offenders ==")
    for repo_name, repo_root in REPO_ROOTS.items():
        print(f"\n[{repo_name}]")
        for path, size_bytes in list_repo_subdirs(repo_root)[:5]:
            print(f"  {human_bytes(size_bytes):>8}  {path}")

    offenders = large_untracked_media_files(min_bytes=min_media_bytes)
    print("\n== Largest Local Media Files In Repo Trees ==")
    if offenders:
        for path, size_bytes in offenders[:15]:
            print(f"  {human_bytes(size_bytes):>8}  {path}")
    else:
        print("  none")

    print("\n== Legacy Screenalytics Episode Artifact Sizes ==")
    episode_sizes = screenalytics_episode_sizes()
    if episode_sizes:
        for episode_id, size_bytes in episode_sizes[:10]:
            print(f"  {human_bytes(size_bytes):>8}  {episode_id}")
    else:
        print("  none")

    print("\n== Protected Paths ==")
    for description in SCREENALYTICS_PROTECTED_PATH_DESCRIPTIONS:
        print(f"  - {description}")

    cleanup_targets: list[CleanupCandidate] = []
    if args.include_screenalytics_local_generated:
        cleanup_targets.extend(screenalytics_generated_artifact_candidates())
    if args.include_build_caches:
        cleanup_targets.extend(build_cache_candidates())
    if args.include_download_dumps:
        cleanup_targets.extend(download_dump_candidates())

    preserved: list[CleanupCandidate] = []
    if args.include_screenalytics_artifacts:
        deletable, preserved = screenalytics_artifact_candidates(keep_days=keep_days)
        cleanup_targets.extend(deletable)

    cleanup_targets = [
        candidate for candidate in dedupe_candidates(cleanup_targets)
        if not is_screenalytics_protected_path(candidate.path)
    ]
    cleanup_targets.sort(key=lambda item: item.size_bytes, reverse=True)
    total_bytes = sum(item.size_bytes for item in cleanup_targets)
    print("\n== Cleanup Targets ==")
    print(
        f"mode={'apply' if apply else 'dry-run'} keep_days={keep_days} "
        f"targets={len(cleanup_targets)} reclaimable={human_bytes(total_bytes)}"
    )
    for candidate in cleanup_targets[:25]:
        print(f"  [{candidate.category}] {human_bytes(candidate.size_bytes):>8}  {candidate.path}")
    if len(cleanup_targets) > 25:
        print(f"  ... and {len(cleanup_targets) - 25} more targets")

    if preserved:
        preserved_bytes = sum(item.size_bytes for item in preserved)
        print(
            f"\n== Preserved Recent Legacy Screenalytics Episode Artifacts ==\n"
            f"  kept={len(preserved)} size={human_bytes(preserved_bytes)}"
        )
        for candidate in sorted(preserved, key=lambda item: item.size_bytes, reverse=True)[:10]:
            print(f"  {human_bytes(candidate.size_bytes):>8}  {candidate.path}")

    if apply:
        reclaimed = 0
        deleted = 0
        for candidate in cleanup_targets:
            if not candidate.path.exists():
                continue
            delete_candidate(candidate)
            reclaimed += candidate.size_bytes
            deleted += 1
        print(f"\nDeleted {deleted} targets and reclaimed approximately {human_bytes(reclaimed)}.")
    else:
        print("\nDry run only. Re-run with --apply to delete the targets above.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
