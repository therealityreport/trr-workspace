#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "TRR-APP/apps/web"
DEFAULT_OUTPUT = ROOT / "docs/workspace/app-direct-sql-inventory.md"
SCAN_ROOTS = (
    APP_ROOT / "src/lib/server",
    APP_ROOT / "src/app/api",
)
POSTGRES_IMPORT_RE = re.compile(r"@/lib/server/postgres|['\"](?:\.\.?/)+postgres['\"]")
CALL_SYMBOLS = frozenset(("query", "withTransaction", "withAuthTransaction", "queryWithAuth"))
HIGH_FANOUT_REVIEW_DATE = "2026-05-27"


@dataclass(frozen=True)
class DirectSqlUse:
    path: Path
    line_number: int
    symbol: str
    owner_alias: str
    risk: str
    exception_owner: str
    reason_retained: str
    review_by: str
    migration_target: str
    excerpt: str


OWNER_ALIASES = (
    (
        "app-local",
        "TRR-APP-only authoring/editor flows.",
        "TRR-APP owner, with backend review only when shared schemas are touched.",
        "TRR-APP source plus this workspace inventory.",
    ),
    (
        "admin-read-model",
        "Admin read/update paths retained in TRR-APP until backend aggregate endpoints exist.",
        "TRR-APP and TRR-Backend reviewer for migration slices.",
        "docs/workspace/api-migration-ledger.md",
    ),
    (
        "backend-shared-schema",
        "Shared schema, social/reddit, and TRR API compatibility data access.",
        "TRR-Backend reviewer owns the target API or migration.",
        "TRR-Backend APIs/migrations plus docs/workspace/api-migration-ledger.md",
    ),
    (
        "workspace-ops",
        "Workspace scripts, inventories, and runbooks.",
        "Workspace operator.",
        "docs/workspace/ and root scripts/",
    ),
)


def _iter_source_files() -> list[Path]:
    files: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        files.extend(path for path in root.rglob("*") if path.suffix in {".ts", ".tsx"})
    return sorted(files)


def _skip_quoted(text: str, index: int) -> int:
    """Return the first offset after a JavaScript/TypeScript string literal."""
    quote = text[index]
    index += 1
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        index += 1
        if char == quote:
            break
    return index


def _skip_trivia(text: str, index: int) -> int:
    """Skip whitespace and comments between a symbol, generic, and call paren."""
    while index < len(text):
        if text[index].isspace():
            index += 1
            continue
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            return len(text) if newline < 0 else _skip_trivia(text, newline + 1)
        if text.startswith("/*", index):
            closing = text.find("*/", index + 2)
            return len(text) if closing < 0 else _skip_trivia(text, closing + 2)
        break
    return index


def _generic_call_open_paren(text: str, index: int) -> int | None:
    """Find the call paren after a balanced TypeScript generic starting at ``<``.

    Type arguments can contain nested generics, object/tuple/function types, and
    quoted property names. A greater-than sign in the ``=>`` arrow token is not
    an angle-bracket delimiter.
    """
    depth = 1
    index += 1
    while index < len(text):
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            if newline < 0:
                return None
            index = newline + 1
            continue
        if text.startswith("/*", index):
            closing = text.find("*/", index + 2)
            if closing < 0:
                return None
            index = closing + 2
            continue
        char = text[index]
        if char in "'\"`":
            index = _skip_quoted(text, index)
            continue
        if char == "<":
            depth += 1
        elif char == ">" and (index == 0 or text[index - 1] != "="):
            depth -= 1
            if depth == 0:
                call_index = _skip_trivia(text, index + 1)
                return call_index if call_index < len(text) and text[call_index] == "(" else None
        index += 1
    return None


def scan_call_sites(text: str) -> list[tuple[str, int]]:
    """Return direct-SQL call symbols and their source offsets.

    This is intentionally a small lexical scanner instead of a TypeScript
    parser: it ignores comments and strings, identifies the four supported
    symbols as identifier tokens, then validates either a plain call or a call
    following balanced generic type arguments.
    """
    calls: list[tuple[str, int]] = []
    index = 0
    while index < len(text):
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            continue
        if text.startswith("/*", index):
            closing = text.find("*/", index + 2)
            index = len(text) if closing < 0 else closing + 2
            continue
        char = text[index]
        if char in "'\"`":
            index = _skip_quoted(text, index)
            continue
        if char.isalpha() or char in "_$":
            start = index
            index += 1
            while index < len(text) and (text[index].isalnum() or text[index] in "_$"):
                index += 1
            symbol = text[start:index]
            if symbol not in CALL_SYMBOLS:
                continue
            suffix = _skip_trivia(text, index)
            if suffix < len(text) and text[suffix] == "(":
                calls.append((symbol, start))
            elif suffix < len(text) and text[suffix] == "<" and _generic_call_open_paren(text, suffix) is not None:
                calls.append((symbol, start))
            continue
        index += 1
    return calls


def _classify(path: Path) -> tuple[str, str, str, str, str, str]:
    path_text = path.as_posix()
    if "/surveys/" in path_text or "/api/admin/surveys/" in path_text:
        return "app-local", "medium", "n/a", "app-local survey/editor direct SQL retained", "n/a", "none"
    if "/shows/" in path_text:
        return "app-local", "medium", "app-local", "show/survey authoring SQL retained until Phase 8B DDL cleanup", "2026-06-30", "backend migration provenance for shared schema DDL"
    if "/trr-api/" in path_text:
        return "backend-shared-schema", "medium", "backend-shared-schema", "TRR API compatibility SQL retained until backend route ownership is migrated", "2026-06-30", "TRR-Backend API route"
    if "/social" in path_text or "reddit" in path_text:
        return (
            "backend-shared-schema",
            "high-fan-out production risk",
            "backend-shared-schema",
            "Phase 5 migration is out of this workspace-only slice; retain with explicit owner and review date.",
            HIGH_FANOUT_REVIEW_DATE,
            "TRR-Backend aggregate endpoint",
        )
    if "/admin/" in path_text or "/api/admin/" in path_text:
        return "admin-read-model", "medium", "admin-read-model", "retained admin read-model path", "2026-06-30", "backend aggregate endpoint when fanout justifies migration"
    return "workspace-ops", "unknown", "workspace-ops", "manual classification required", "2026-06-30", "manual owner review"


def collect_uses() -> list[DirectSqlUse]:
    uses: list[DirectSqlUse] = []
    for path in _iter_source_files():
        if path == APP_ROOT / "src/lib/server/postgres.ts":
            continue
        text = path.read_text(encoding="utf-8")
        call_sites = scan_call_sites(text)
        if not POSTGRES_IMPORT_RE.search(text) and not call_sites:
            continue
        owner_alias, risk, exception_owner, reason_retained, review_by, migration_target = _classify(path)
        lines = text.splitlines()
        for symbol, offset in call_sites:
            line_number = text.count("\n", 0, offset) + 1
            excerpt = lines[line_number - 1].strip()[:120] if lines else ""
            uses.append(
                DirectSqlUse(
                    path=path.relative_to(ROOT),
                    line_number=line_number,
                    symbol=symbol,
                    owner_alias=owner_alias,
                    risk=risk,
                    exception_owner=exception_owner,
                    reason_retained=reason_retained,
                    review_by=review_by,
                    migration_target=migration_target,
                    excerpt=excerpt,
                )
            )
    return uses


def render_markdown(uses: list[DirectSqlUse]) -> str:
    high_risk = sum(1 for use in uses if use.risk == "high-fan-out production risk")
    owner_counts: dict[str, int] = {}
    for use in uses:
        owner_counts[use.owner_alias] = owner_counts.get(use.owner_alias, 0) + 1
    lines = [
        "# App Direct SQL Inventory",
        "",
        "Generated by `scripts/app-direct-sql-inventory.py`. Regenerate after each app-to-backend API migration slice.",
        "",
        "## Summary",
        "",
        f"- Total direct SQL call sites: `{len(uses)}`",
        f"- High-fan-out production-risk call sites: `{high_risk}`",
        "- Expiry check: retained high-fan-out exceptions below must be reviewed manually on or before their `Review by` date.",
        "",
        "## Owner Aliases",
        "",
        "| Alias | Scope | Reviewer | Source of truth |",
        "|---|---|---|---|",
    ]
    for alias, scope, reviewer, source in OWNER_ALIASES:
        lines.append(f"| `{alias}` | {scope} | {reviewer} | `{source}` |")
    lines.extend(
        [
            "",
            "## Owner Counts",
            "",
            "| Owner alias | Count |",
            "|---|---:|",
        ]
    )
    for owner, count in sorted(owner_counts.items()):
        lines.append(f"| `{owner}` | {count} |")
    lines.extend(
        [
            "",
            "## Retained High-Fan-Out Exceptions",
            "",
            "| Call site | Exception owner | Reason retained | Review by | Migration target |",
            "|---|---|---|---|---|",
        ]
    )
    high_risk_uses = [use for use in uses if use.risk == "high-fan-out production risk"]
    if high_risk_uses:
        for use in high_risk_uses:
            lines.append(
                f"| `{use.path}:{use.line_number}` | `{use.exception_owner}` | {use.reason_retained} | `{use.review_by}` | {use.migration_target} |"
            )
    else:
        lines.append("| n/a | n/a | n/a | n/a | n/a |")
    lines.extend(
        [
            "",
            "## Manual Review Contract",
            "",
            "- New high-fanout app direct-SQL rows must include an exception owner, reason retained, review date, and migration target.",
            "- `backend-shared-schema` exceptions should move to `docs/workspace/api-migration-ledger.md` when a backend endpoint is created.",
            "- Review dates are intentionally static in this generated inventory so `--check` remains reproducible; operators compare dates during Phase 5 planning.",
            "",
            "## Call Sites",
            "",
            "| File | Line | Symbol | Owner alias | Risk | Excerpt |",
            "|---|---:|---|---|---|---|",
        ]
    )
    for use in uses:
        excerpt = use.excerpt.replace("|", "\\|")
        lines.append(
            f"| `{use.path}` | {use.line_number} | `{use.symbol}` | `{use.owner_alias}` | {use.risk} | `{excerpt}` |"
        )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inventory TRR-APP direct SQL call sites.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="Fail if --output is stale.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    output = args.output if args.output.is_absolute() else ROOT / args.output
    rendered = render_markdown(collect_uses())
    if args.check:
        existing = output.read_text(encoding="utf-8") if output.is_file() else ""
        if existing != rendered:
            print(f"[app-direct-sql-inventory] ERROR: {output} is stale.", file=sys.stderr)
            return 1
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
