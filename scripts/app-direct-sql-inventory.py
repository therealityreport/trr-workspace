#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "TRR-APP/apps/web"
GENERATED_BY = "scripts/app-direct-sql-inventory.py"
MAX_REAUTHORIZATION_DAYS = 30
SCAN_ROOTS = (
    APP_ROOT / "src/lib/server",
    APP_ROOT / "src/app/api",
)
CALL_SYMBOLS = frozenset(
    ("query", "withTransaction", "withAuthTransaction", "queryWithAuth")
)
REGEX_PREFIX_KEYWORDS = frozenset(("return", "throw", "case", "else"))
POSTGRES_MODULE_PATTERN = r"(?:@/lib/server/postgres|(?:\.\.?/)+postgres)"
NAMED_POSTGRES_IMPORT_RE = re.compile(
    rf"\bimport\s*(?!type\b)\{{(?P<body>[^{{}}]*)\}}\s*from\s*['\"]{POSTGRES_MODULE_PATTERN}['\"]",
    re.DOTALL,
)
NAMESPACE_POSTGRES_IMPORT_RE = re.compile(
    rf"\bimport\s*\*\s*as\s*(?P<local>[A-Za-z_$][\w$]*)\s*from\s*['\"]{POSTGRES_MODULE_PATTERN}['\"]"
)


@dataclass(frozen=True)
class DirectSqlUse:
    path: Path
    line_number: int
    symbol: str
    ordinal: int
    row_id: str
    owner_alias: str
    risk: str
    context: str
    excerpt: str


@dataclass(frozen=True)
class MigrationPlan:
    packet: str
    migration_target: str


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
        "docs/workspace/api-migration-ledger.json",
    ),
    (
        "backend-shared-schema",
        "Shared schema, social/reddit, and TRR API compatibility data access.",
        "TRR-Backend reviewer owns the target API or migration.",
        "TRR-Backend APIs/migrations plus docs/workspace/api-migration-ledger.json",
    ),
    (
        "workspace-ops",
        "Workspace scripts, inventories, and runbooks.",
        "Workspace operator.",
        "docs/workspace/ and root scripts/",
    ),
)


MIGRATION_PLANS = (
    (
        "media-links",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET/POST/PATCH/DELETE /api/v2/admin/media-links and /api/v2/admin/media-links/{link_id}",
        ),
    ),
    (
        "/social/profiles/",
        MigrationPlan(
            "packet-3-reddit-social-admin-reads",
            "GET /api/v2/admin/socials/profiles/{platform}/{handle}/catalog/runs/recent",
        ),
    ),
    (
        "covered-shows-repository.ts",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET/POST /api/v2/admin/covered-shows and GET/DELETE /api/v2/admin/covered-shows/{show_id}",
        ),
    ),
    (
        "flashback-admin-repository.ts",
        MigrationPlan(
            "packet-4-remaining-admin-read-write-models",
            "GET/POST/PATCH/DELETE /api/v2/admin/flashback/quizzes and /api/v2/admin/flashback/events",
        ),
    ),
    (
        "images-repository.ts",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET/POST/PATCH/DELETE /api/v2/admin/media/images and /api/v2/admin/media/image-sources",
        ),
    ),
    (
        "networks-streaming-repository.ts",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/admin/networks and /api/v2/admin/streaming-services read models",
        ),
    ),
    (
        "person-cover-photos-repository.ts",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET/PUT/DELETE /api/v2/admin/people/{person_id}/cover-photos",
        ),
    ),
    (
        "person-thumbnail-crops-repository.ts",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "PUT /api/v2/admin/people/{person_id}/thumbnail-crops",
        ),
    ),
    (
        "reddit-sources-repository.ts",
        MigrationPlan(
            "packet-3-reddit-social-admin-reads",
            "GET /api/v2/admin/reddit/posts/{post_id} and /api/v2/admin/reddit/post-windows",
        ),
    ),
    (
        "season-cast-survey-roles-repository.ts",
        MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET/POST/PATCH/DELETE /api/v2/admin/shows/{show_id}/seasons/{season_number}/cast-survey-roles",
        ),
    ),
    (
        "shared-account-sources.ts",
        MigrationPlan(
            "packet-3-reddit-social-admin-reads",
            "GET /api/v2/admin/socials/shared-account-sources",
        ),
    ),
    (
        "typography-repository.ts",
        MigrationPlan(
            "packet-4-remaining-admin-read-write-models",
            "GET/POST/PATCH/DELETE /api/v2/admin/site-typography/sets and /api/v2/admin/site-typography/assignments",
        ),
    ),
)

TRR_SHOWS_PACKET_1_SHOW_IDENTITY_CONTEXTS = {
    "getShowByExactSlug",
    "resolveShowSlug",
    "getShowByImdbId",
}
TRR_SHOWS_PACKET_1_PERSON_IDENTITY_CONTEXTS = {
    "resolvePersonSlug",
}
TRR_SHOWS_PACKET_2_SHOW_CONTEXTS = {"searchShows", "getShowById"}
TRR_SHOWS_PACKET_2_SEASON_EPISODE_CONTEXTS = {
    "getSeasonsByShowId",
    "getSeasonById",
    "getSeasonByShowAndNumber",
    "getEpisodesBySeasonId",
    "getEpisodesByShowAndSeason",
    "getEpisodeById",
    "searchEpisodes",
}
TRR_SHOWS_PACKET_2_CAST_CONTEXTS = {
    "getPreferredCastPhotoMap",
    "getCastByShowId",
    "getCastNamesByShowId",
    "getShowCastWithStats",
    "getShowArchiveFootageCast",
    "getCastByShowSeason",
    "getSeasonCastWithEpisodeCounts",
}
TRR_SHOWS_PACKET_2_PERSON_CONTEXTS = {
    "getPersonById",
    "searchPeople",
    "getDeducedFamilyRelationshipsByPersonId",
    "searchPeopleWithShowContext",
    "getPeopleMostShows",
    "getPeopleTopEpisodes",
    "getPeopleRecentlyAdded",
    "getPeopleMostPopular",
}
TRR_SHOWS_PACKET_2_MEDIA_CONTEXTS = {
    "validateShowImageForField",
    "ensureExpectedPersonName",
    "getAssetsByShowSeason",
    "getAssetsByShowId",
    "getFandomDataByPersonId",
}
TRR_SHOWS_PACKET_2_CREDIT_CONTEXTS = {
    "getCreditsByPersonId",
    "getCuratedCastShowIdsByPersonId",
    "getEpisodeCreditsByPersonShowId",
    "getEpisodeCreditsByPersonId",
}
TRR_SHOWS_PACKET_3_CONTEXTS = {"listEffectivePersonSocialHandlesByPersonIds"}
TRR_SHOWS_PACKET_4_SHOW_CONTEXTS = {"updateShowById"}
TRR_SHOWS_PACKET_4_PERSON_CONTEXTS = {"updatePersonCanonicalProfileSourceOrder"}

FUNCTION_CONTEXT_RE = re.compile(
    r"^[ \t]*(?:(?:export\s+)?async\s+function\s+(?P<async_function>[A-Za-z_$][\w$]*)"
    r"|(?:export\s+)?function\s+(?P<function>[A-Za-z_$][\w$]*)"
    r"|(?:export\s+)?const\s+(?P<async_const>[A-Za-z_$][\w$]*)\s*=\s*async\b)",
    re.MULTILINE,
)

# Keep surviving row IDs stable when a migration removes calls from the middle
# of a file. These slots are historical locators, not live exceptions.
RETIRED_CALL_ORDINALS = {
    (
        "TRR-APP/apps/web/src/lib/server/admin/person-cover-photos-repository.ts",
        "query",
    ): (1, 2, 3, 4),
    (
        "TRR-APP/apps/web/src/lib/server/admin/person-cover-photos-repository.ts",
        "withAuthTransaction",
    ): (1, 2),
    (
        "TRR-APP/apps/web/src/lib/server/admin/person-thumbnail-crops-repository.ts",
        "query",
    ): (1, 2),
    (
        "TRR-APP/apps/web/src/lib/server/admin/networks-streaming-repository.ts",
        "query",
    ): (1, 2, 3, 4, 5, 6, 7),
    (
        "TRR-APP/apps/web/src/lib/server/admin/images-repository.ts",
        "query",
    ): (1, 2, 3, 4, 5, 6, 7, 8, 9),
    (
        "TRR-APP/apps/web/src/lib/server/trr-api/media-links-repository.ts",
        "query",
    ): (1, 2, 3, 4, 5, 6),
    (
        "TRR-APP/apps/web/src/app/api/admin/trr-api/media-links/route.ts",
        "query",
    ): (1,),
    (
        "TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts",
        "query",
    ): (
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63,
        64,
        65,
        66,
        67,
        68,
        69,
        70,
        71,
        72,
        73,
        74,
        75,
        76,
        77,
        78,
    ),
}


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


def _looks_like_regex_literal(text: str, index: int) -> bool:
    previous = index - 1
    while previous >= 0 and text[previous].isspace():
        previous -= 1
    if previous < 0 or text[previous] in "=([{,:;!?&|+-*%^~<>":
        return True
    token_end = previous + 1
    while previous >= 0 and (text[previous].isalnum() or text[previous] in "_$"):
        previous -= 1
    return text[previous + 1 : token_end] in REGEX_PREFIX_KEYWORDS


def _skip_regex_literal(text: str, index: int) -> int:
    index += 1
    in_character_class = False
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == "[":
            in_character_class = True
        elif char == "]":
            in_character_class = False
        elif char == "/" and not in_character_class:
            index += 1
            while index < len(text) and text[index].isalpha():
                index += 1
            return index
        index += 1
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
    """Find the call paren after a balanced TypeScript generic starting at ``<``."""
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
                return (
                    call_index
                    if call_index < len(text) and text[call_index] == "("
                    else None
                )
        index += 1
    return None


def parse_postgres_import_bindings(text: str) -> tuple[dict[str, str], set[str]]:
    """Return local named bindings and namespace bindings for the Postgres module."""
    named: dict[str, str] = {}
    for match in NAMED_POSTGRES_IMPORT_RE.finditer(text):
        body = re.sub(r"/\*.*?\*/|//[^\n]*", "", match.group("body"), flags=re.DOTALL)
        for raw_specifier in body.split(","):
            specifier = raw_specifier.strip()
            if not specifier or specifier.startswith("type "):
                continue
            binding_match = re.fullmatch(
                r"(?P<imported>[A-Za-z_$][\w$]*)(?:\s+as\s+(?P<local>[A-Za-z_$][\w$]*))?",
                specifier,
            )
            if not binding_match:
                continue
            imported = binding_match.group("imported")
            if imported not in CALL_SYMBOLS:
                continue
            named[binding_match.group("local") or imported] = imported
    namespaces = {
        match.group("local") for match in NAMESPACE_POSTGRES_IMPORT_RE.finditer(text)
    }
    return named, namespaces


def _transaction_receiver_names(text: str, named_bindings: dict[str, str]) -> set[str]:
    receivers: set[str] = set()
    for local, imported in named_bindings.items():
        if imported not in {"withTransaction", "withAuthTransaction"}:
            continue
        pattern = re.compile(
            rf"(?<![\w$.]){re.escape(local)}\s*(?:<[^;{{}}]{{0,300}}>)?\s*\("
            rf"[\s\S]{{0,800}}?(?:async\s*)?(?:\(\s*(?P<paren>[A-Za-z_$][\w$]*)\s*\)|"
            rf"(?P<bare>[A-Za-z_$][\w$]*))\s*=>"
        )
        for match in pattern.finditer(text):
            receivers.add(match.group("paren") or match.group("bare"))
    return receivers


def _identifier_at(text: str, index: int) -> tuple[str, int] | None:
    if index >= len(text) or not (text[index].isalpha() or text[index] in "_$"):
        return None
    end = index + 1
    while end < len(text) and (text[end].isalnum() or text[end] in "_$"):
        end += 1
    return text[index:end], end


def _member_at(text: str, index: int) -> tuple[str, int, int] | None:
    operator = _skip_trivia(text, index)
    if text.startswith("?.", operator):
        member_start = _skip_trivia(text, operator + 2)
    elif operator < len(text) and text[operator] == ".":
        member_start = _skip_trivia(text, operator + 1)
    else:
        return None
    identifier = _identifier_at(text, member_start)
    if identifier is None:
        return None
    member, member_end = identifier
    return member, member_start, member_end


def _is_call_at(text: str, index: int) -> bool:
    suffix = _skip_trivia(text, index)
    if suffix < len(text) and text[suffix] == "(":
        return True
    return (
        suffix < len(text)
        and text[suffix] == "<"
        and _generic_call_open_paren(text, suffix) is not None
    )


def _is_member_identifier(text: str, start: int) -> bool:
    previous = start - 1
    while previous >= 0 and text[previous].isspace():
        previous -= 1
    return previous >= 0 and text[previous] == "."


def scan_call_sites(text: str) -> list[tuple[str, int]]:
    """Return calls proven to originate from the imported Postgres module."""
    named_bindings, namespace_bindings = parse_postgres_import_bindings(text)
    transaction_receivers = _transaction_receiver_names(text, named_bindings)
    if not named_bindings and not namespace_bindings:
        return []
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
        if char == "/" and _looks_like_regex_literal(text, index):
            index = _skip_regex_literal(text, index)
            continue
        if char in "'\"`":
            index = _skip_quoted(text, index)
            continue
        if char.isalpha() or char in "_$":
            start = index
            index += 1
            while index < len(text) and (text[index].isalnum() or text[index] in "_$"):
                index += 1
            local_symbol = text[start:index]
            if local_symbol in named_bindings and not _is_member_identifier(
                text, start
            ):
                if _is_call_at(text, index):
                    calls.append((named_bindings[local_symbol], start))
                continue
            if (
                local_symbol in namespace_bindings
                or local_symbol in transaction_receivers
            ):
                member = _member_at(text, index)
                if member is None:
                    continue
                member_symbol, member_start, member_end = member
                allowed_members = (
                    CALL_SYMBOLS if local_symbol in namespace_bindings else {"query"}
                )
                if member_symbol in allowed_members and _is_call_at(text, member_end):
                    calls.append((member_symbol, member_start))
            continue
        index += 1
    return calls


def _iter_function_contexts(text: str, offsets: list[int]) -> Iterator[str]:
    declarations = [
        (
            match.start(),
            match.group("async_function")
            or match.group("function")
            or match.group("async_const"),
        )
        for match in FUNCTION_CONTEXT_RE.finditer(text)
    ]
    declaration_index = 0
    context = "module"
    for offset in offsets:
        while (
            declaration_index < len(declarations)
            and declarations[declaration_index][0] < offset
        ):
            context = declarations[declaration_index][1]
            declaration_index += 1
        yield context


def _iter_line_numbers(text: str, offsets: list[int]) -> Iterator[int]:
    """Yield one-based line numbers for increasing source offsets in one pass."""
    newline_offsets = (index for index, char in enumerate(text) if char == "\n")
    next_newline = next(newline_offsets, None)
    line_number = 1
    for offset in offsets:
        while next_newline is not None and next_newline < offset:
            line_number += 1
            next_newline = next(newline_offsets, None)
        yield line_number


def _classify(path: Path) -> tuple[str, str]:
    path_text = path.as_posix()
    if "/surveys/" in path_text or "/api/admin/surveys/" in path_text:
        return "app-local", "medium"
    if "/shows/" in path_text:
        return "app-local", "medium"
    if "/trr-api/" in path_text:
        return "backend-shared-schema", "medium"
    if "/social" in path_text or "reddit" in path_text:
        return "backend-shared-schema", "high-fan-out production risk"
    if "/admin/" in path_text or "/api/admin/" in path_text:
        return "admin-read-model", "medium"
    return "workspace-ops", "unknown"


def stable_row_id(path: Path, symbol: str, ordinal: int) -> str:
    """Build a line-independent ID for one path/symbol ordinal."""
    locator = f"v1\0{path.as_posix()}\0{symbol}\0{ordinal}".encode()
    return f"app-sql-{hashlib.sha256(locator).hexdigest()[:16]}"


def stable_ordinal(path: Path, symbol: str, live_ordinal: int) -> int:
    """Map a live ordinal around retired slots without renumbering later rows."""
    ordinal = live_ordinal
    for retired_ordinal in RETIRED_CALL_ORDINALS.get((path.as_posix(), symbol), ()):
        if ordinal >= retired_ordinal:
            ordinal += 1
    return ordinal


def collect_uses() -> list[DirectSqlUse]:
    uses: list[DirectSqlUse] = []
    for path in _iter_source_files():
        if path == APP_ROOT / "src/lib/server/postgres.ts":
            continue
        text = path.read_text(encoding="utf-8")
        call_sites = scan_call_sites(text)
        if not call_sites:
            continue
        owner_alias, risk = _classify(path)
        relative_path = path.relative_to(ROOT)
        lines = text.splitlines()
        offsets = [offset for _, offset in call_sites]
        line_numbers = _iter_line_numbers(text, offsets)
        contexts = _iter_function_contexts(text, offsets)
        symbol_ordinals: Counter[str] = Counter()
        for (symbol, _), line_number, context in zip(
            call_sites, line_numbers, contexts
        ):
            symbol_ordinals[symbol] += 1
            ordinal = stable_ordinal(relative_path, symbol, symbol_ordinals[symbol])
            excerpt = lines[line_number - 1].strip()[:120] if lines else ""
            uses.append(
                DirectSqlUse(
                    path=relative_path,
                    line_number=line_number,
                    symbol=symbol,
                    ordinal=ordinal,
                    row_id=stable_row_id(relative_path, symbol, ordinal),
                    owner_alias=owner_alias,
                    risk=risk,
                    context=context,
                    excerpt=excerpt,
                )
            )
    return uses


def _trr_shows_migration_plan(context: str) -> MigrationPlan:
    if context in TRR_SHOWS_PACKET_1_SHOW_IDENTITY_CONTEXTS:
        return MigrationPlan(
            "packet-1-public-identity-slugs",
            "GET /api/v2/shows/resolve/{slug}, /api/v2/shows/identities, and external show identity resolvers",
        )
    if context in TRR_SHOWS_PACKET_1_PERSON_IDENTITY_CONTEXTS:
        return MigrationPlan(
            "packet-1-public-identity-slugs",
            "GET /api/v2/people/resolve/{slug}, /api/v2/people/identities, and canonical person alias resolvers",
        )
    if context in TRR_SHOWS_PACKET_2_SHOW_CONTEXTS:
        return MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/shows and /api/v2/shows/{show_id}",
        )
    if context in TRR_SHOWS_PACKET_2_SEASON_EPISODE_CONTEXTS:
        return MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/shows/{show_id}/seasons and /api/v2/seasons/{season_id}/episodes",
        )
    if context in TRR_SHOWS_PACKET_2_CAST_CONTEXTS:
        return MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/shows/{show_id}/cast and /api/v2/seasons/{season_id}/cast",
        )
    if context in TRR_SHOWS_PACKET_2_PERSON_CONTEXTS:
        return MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/people, /api/v2/people/{person_id}, and people leaderboard read models",
        )
    if context in TRR_SHOWS_PACKET_2_MEDIA_CONTEXTS:
        return MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/shows/{show_id}/assets, /api/v2/people/{person_id}/photos, and person fandom media",
        )
    if context in TRR_SHOWS_PACKET_2_CREDIT_CONTEXTS:
        return MigrationPlan(
            "packet-2-shows-seasons-people-media",
            "GET /api/v2/people/{person_id}/credits and /api/v2/people/{person_id}/episode-credits",
        )
    if context in TRR_SHOWS_PACKET_3_CONTEXTS:
        return MigrationPlan(
            "packet-3-reddit-social-admin-reads",
            "GET /api/v2/admin/socials/people/effective-handles",
        )
    if context in TRR_SHOWS_PACKET_4_SHOW_CONTEXTS:
        return MigrationPlan(
            "packet-4-remaining-admin-read-write-models",
            "PATCH /api/v2/admin/shows/{show_id}",
        )
    if context in TRR_SHOWS_PACKET_4_PERSON_CONTEXTS:
        return MigrationPlan(
            "packet-4-remaining-admin-read-write-models",
            "PATCH /api/v2/admin/people/{person_id}/canonical-profile-source-order",
        )
    raise ValueError(
        f"No concrete trr-shows migration plan for function context: {context}"
    )


def _migration_plan_for(use: DirectSqlUse) -> MigrationPlan:
    path_text = use.path.as_posix()
    if use.path.name == "trr-shows-repository.ts":
        return _trr_shows_migration_plan(use.context)
    for marker, plan in MIGRATION_PLANS:
        if marker in path_text:
            return plan
    raise ValueError(
        f"No concrete migration plan for non-app-local source: {path_text}"
    )


def build_exception_records(
    uses: list[DirectSqlUse],
    *,
    reauthorized_at: str,
    review_by: str,
    execution_owner: str = "Task 3",
) -> list[dict[str, Any]]:
    """Build an explicitly dated proposal; callers decide whether to persist it."""
    records: list[dict[str, Any]] = []
    for use in uses:
        if use.owner_alias == "app-local":
            continue
        plan = _migration_plan_for(use)
        if use.owner_alias == "backend-shared-schema":
            reason = (
                "Temporary shared-schema compatibility SQL retained until the named FastAPI target "
                f"becomes the sole data owner in {plan.packet}."
            )
        else:
            reason = (
                "Temporary admin read-model SQL retained until the named FastAPI target is implemented "
                f"and the Next.js caller is cut over in {plan.packet}."
            )
        records.append(
            {
                "id": use.row_id,
                "source": {
                    "path": use.path.as_posix(),
                    "symbol": use.symbol,
                    "ordinal": use.ordinal,
                    "context": use.context,
                },
                "classification": use.owner_alias,
                "durable_owner": use.owner_alias,
                "execution_owner": execution_owner,
                "reason": reason,
                "packet": plan.packet,
                "migration_target": plan.migration_target,
                "reauthorized_at": reauthorized_at,
                "review_by": review_by,
            }
        )
    return records


def render_exception_manifest(records: list[dict[str, Any]]) -> str:
    payload = {
        "schema_version": 1,
        "policy": {"max_review_window_days": MAX_REAUTHORIZATION_DAYS},
        "exceptions": records,
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def load_exception_records(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError(f"{path}: unsupported or missing schema_version")
    policy = payload.get("policy")
    if (
        not isinstance(policy, dict)
        or policy.get("max_review_window_days") != MAX_REAUTHORIZATION_DAYS
    ):
        raise ValueError(
            f"{path}: max_review_window_days must be {MAX_REAUTHORIZATION_DAYS}"
        )
    records = payload.get("exceptions")
    if not isinstance(records, list) or not all(
        isinstance(record, dict) for record in records
    ):
        raise ValueError(f"{path}: exceptions must be an array of objects")
    return records


def _source_key(record: dict[str, Any]) -> tuple[str, str, int] | None:
    source = record.get("source")
    if not isinstance(source, dict):
        return None
    path = source.get("path")
    symbol = source.get("symbol")
    ordinal = source.get("ordinal")
    if (
        not isinstance(path, str)
        or not path
        or not isinstance(symbol, str)
        or not symbol
    ):
        return None
    if not isinstance(ordinal, int) or isinstance(ordinal, bool) or ordinal < 1:
        return None
    return path, symbol, ordinal


def _parse_record_date(
    record: dict[str, Any], field: str, row_id: str, errors: list[str]
) -> date | None:
    value = record.get(field)
    if not isinstance(value, str):
        errors.append(f"{row_id}: missing absolute {field}")
        return None
    try:
        parsed = date.fromisoformat(value)
    except ValueError:
        errors.append(f"{row_id}: invalid absolute {field}: {value!r}")
        return None
    if parsed.isoformat() != value:
        errors.append(f"{row_id}: {field} must use YYYY-MM-DD")
        return None
    return parsed


def validate_exception_records(
    uses: list[DirectSqlUse],
    records: list[dict[str, Any]],
    *,
    fail_expired: bool,
    as_of: date | None = None,
) -> list[str]:
    errors: list[str] = []
    current = {use.row_id: use for use in uses if use.owner_alias != "app-local"}
    ids = [record.get("id") for record in records if isinstance(record.get("id"), str)]
    for row_id, count in sorted(Counter(ids).items()):
        if count > 1:
            errors.append(f"duplicate exception id: {row_id}")
    sources = [
        source for record in records if (source := _source_key(record)) is not None
    ]
    for source, count in sorted(Counter(sources).items()):
        if count > 1:
            errors.append(
                f"duplicate exception source: {source[0]}::{source[1]}::{source[2]}"
            )

    record_ids = set(ids)
    for row_id in sorted(set(current) - record_ids):
        use = current[row_id]
        errors.append(f"missing exception: {row_id} ({use.path}:{use.line_number})")

    effective_as_of = (as_of or date.today()) if fail_expired else None
    for index, record in enumerate(records):
        row_id = record.get("id")
        label = row_id if isinstance(row_id, str) and row_id else f"exception[{index}]"
        if not isinstance(row_id, str) or not row_id:
            errors.append(f"{label}: missing stable id")
            continue
        use = current.get(row_id)
        if use is None:
            errors.append(f"orphaned exception: {row_id}")
            continue
        expected_source = (use.path.as_posix(), use.symbol, use.ordinal)
        actual_source = _source_key(record)
        if actual_source != expected_source:
            errors.append(
                f"{row_id}: source locator mismatch; expected {expected_source!r}"
            )
        source = record.get("source")
        actual_context = source.get("context") if isinstance(source, dict) else None
        if actual_context != use.context:
            errors.append(
                f"{row_id}: function context mismatch; expected {use.context!r}"
            )
        if record.get("classification") != use.owner_alias:
            errors.append(f"{row_id}: classification must remain {use.owner_alias}")
        durable_owner = record.get("durable_owner")
        if durable_owner != use.owner_alias:
            errors.append(f"{row_id}: durable_owner must remain {use.owner_alias}")
        execution_owner = record.get("execution_owner")
        if not isinstance(execution_owner, str) or not execution_owner.strip():
            errors.append(f"{row_id}: missing execution_owner")
        elif execution_owner == durable_owner:
            errors.append(
                f"{row_id}: execution_owner must be separate from durable_owner"
            )
        for field in ("reason", "packet", "migration_target"):
            value = record.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{row_id}: missing {field}")
        migration_target = str(record.get("migration_target") or "").strip().lower()
        if migration_target in {
            "n/a",
            "none",
            "manual owner review",
            "trr-backend aggregate endpoint",
            "backend aggregate endpoint when fanout justifies migration",
        }:
            errors.append(f"{row_id}: migration_target is not concrete")
        reauthorized_at = _parse_record_date(record, "reauthorized_at", row_id, errors)
        review_by = _parse_record_date(record, "review_by", row_id, errors)
        if reauthorized_at is None or review_by is None:
            continue
        review_window = (review_by - reauthorized_at).days
        if review_window < 0:
            errors.append(f"{row_id}: review_by precedes reauthorized_at")
        elif review_window > MAX_REAUTHORIZATION_DAYS:
            errors.append(
                f"{row_id}: exception window exceeds {MAX_REAUTHORIZATION_DAYS} days "
                f"({reauthorized_at} to {review_by})"
            )
        if fail_expired and review_by < effective_as_of:
            errors.append(
                f"expired exception: {row_id} review_by={review_by} as_of={effective_as_of}"
            )
    return errors


def _counts(uses: list[DirectSqlUse]) -> dict[str, int]:
    owner_counts = Counter(use.owner_alias for use in uses)
    return {
        "total": len(uses),
        "app-local": owner_counts["app-local"],
        "admin-read-model": owner_counts["admin-read-model"],
        "backend-shared-schema": owner_counts["backend-shared-schema"],
    }


def _escape_markdown(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def render_markdown(
    uses: list[DirectSqlUse], records: list[dict[str, Any]] | None = None
) -> str:
    records = records or []
    exceptions = {str(record.get("id")): record for record in records}
    counts = _counts(uses)
    high_risk = sum(1 for use in uses if use.risk == "high-fan-out production risk")
    lines = [
        "# App Direct SQL Inventory",
        "",
        f"Generated by `{GENERATED_BY}`. Regenerate after each app-to-backend API migration slice.",
        "",
        "## Summary",
        "",
        f"- Total direct SQL call sites: `{counts['total']}`",
        f"- App-local call sites: `{counts['app-local']}`",
        f"- Admin read-model call sites: `{counts['admin-read-model']}`",
        f"- Backend shared-schema call sites: `{counts['backend-shared-schema']}`",
        f"- Governed non-app-local exceptions: `{len(records)}`",
        f"- High-fan-out production-risk call sites: `{high_risk}`",
        "- Expiry enforcement: run `python3 scripts/app-direct-sql-inventory.py --check --fail-expired --as-of YYYY-MM-DD`.",
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
            "## Retained High-Fan-Out Exceptions",
            "",
            "| Row ID | Call site | Durable owner | Execution owner | Packet | Reauthorized at | Review by | Migration target |",
            "|---|---|---|---|---|---|---|---|",
        ]
    )
    high_risk_uses = [use for use in uses if use.risk == "high-fan-out production risk"]
    if not high_risk_uses:
        lines.append("| n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |")
    for use in high_risk_uses:
        record = exceptions.get(use.row_id, {})
        lines.append(
            "| "
            f"`{use.row_id}` | `{use.path}:{use.line_number}` | `{record.get('durable_owner', 'missing')}` | "
            f"`{record.get('execution_owner', 'missing')}` | `{record.get('packet', 'missing')}` | "
            f"`{record.get('reauthorized_at', 'missing')}` | `{record.get('review_by', 'missing')}` | "
            f"{_escape_markdown(record.get('migration_target', 'missing'))} |"
        )
    lines.extend(
        [
            "",
            "## Governed Non-App-Local Exceptions",
            "",
            "| Row ID | Call site | Classification | Durable owner | Execution owner | Packet | Reason | Reauthorized at | Review by | Migration target |",
            "|---|---|---|---|---|---|---|---|---|---|",
        ]
    )
    for use in uses:
        if use.owner_alias == "app-local":
            continue
        record = exceptions.get(use.row_id, {})
        lines.append(
            "| "
            f"`{use.row_id}` | `{use.path}:{use.line_number}` | `{use.owner_alias}` | "
            f"`{record.get('durable_owner', 'missing')}` | `{record.get('execution_owner', 'missing')}` | "
            f"`{record.get('packet', 'missing')}` | {_escape_markdown(record.get('reason', 'missing'))} | "
            f"`{record.get('reauthorized_at', 'missing')}` | `{record.get('review_by', 'missing')}` | "
            f"{_escape_markdown(record.get('migration_target', 'missing'))} |"
        )
    lines.extend(
        [
            "",
            "## Review Contract",
            "",
            "- Every non-app-local direct-SQL row requires one unique exception record with a stable row ID.",
            "- Durable ownership/classification is separate from the temporary execution owner doing the migration.",
            "- Each exception names a reason, vertical packet, concrete migration target, absolute reauthorization date, and absolute review date.",
            f"- A review date may be at most {MAX_REAUTHORIZATION_DAYS} calendar days after reauthorization.",
            "- Default `--check` remains deterministic and does not consult the wall clock; add `--fail-expired` for clock-aware enforcement.",
            "- `backend-shared-schema` and `admin-read-model` rows are also generated into `docs/workspace/api-migration-ledger.json`.",
            "",
            "## Call Sites",
            "",
            "| Row ID | File | Line | Symbol | Ordinal | Function context | Owner alias | Risk | Excerpt |",
            "|---|---|---:|---|---:|---|---|---|---|",
        ]
    )
    for use in uses:
        lines.append(
            f"| `{use.row_id}` | `{use.path}` | {use.line_number} | `{use.symbol}` | {use.ordinal} | "
            f"`{use.context}` | `{use.owner_alias}` | {use.risk} | `{_escape_markdown(use.excerpt)}` |"
        )
    return "\n".join(lines) + "\n"


def render_inventory_json(
    uses: list[DirectSqlUse], records: list[dict[str, Any]]
) -> str:
    exceptions = {str(record["id"]): record for record in records}
    rows = []
    for use in uses:
        rows.append(
            {
                "id": use.row_id,
                "source": {
                    "path": use.path.as_posix(),
                    "line": use.line_number,
                    "symbol": use.symbol,
                    "ordinal": use.ordinal,
                    "context": use.context,
                },
                "classification": use.owner_alias,
                "risk": use.risk,
                "excerpt": use.excerpt,
                "exception": exceptions.get(use.row_id),
            }
        )
    payload = {
        "schema_version": 1,
        "generated_by": GENERATED_BY,
        "counts": _counts(uses),
        "rows": rows,
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def render_api_ledger_json(
    uses: list[DirectSqlUse], records: list[dict[str, Any]]
) -> str:
    current = {use.row_id: use for use in uses if use.owner_alias != "app-local"}
    rows = []
    for record in records:
        use = current[str(record["id"])]
        rows.append(
            {
                **record,
                "source": {
                    **record["source"],
                    "line": use.line_number,
                },
                "status": "planned",
                "auth_contract": "packet-defined-pending",
                "cache_contract": "packet-defined-pending",
                "error_contract": "packet-defined-pending",
                "validation_contract": "packet-defined-pending",
                "rollback_contract": "packet-defined-pending",
            }
        )
    payload = {
        "schema_version": 1,
        "generated_by": GENERATED_BY,
        "counts": {
            "total_non_app_local": len(rows),
            "admin-read-model": sum(
                row["classification"] == "admin-read-model" for row in rows
            ),
            "backend-shared-schema": sum(
                row["classification"] == "backend-shared-schema" for row in rows
            ),
        },
        "rows": rows,
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def _parse_date_argument(value: str) -> date:
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("expected YYYY-MM-DD") from exc
    if parsed.isoformat() != value:
        raise argparse.ArgumentTypeError("expected YYYY-MM-DD")
    return parsed


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inventory TRR-APP direct SQL call sites."
    )
    parser.add_argument(
        "--output", type=Path, help="Write Markdown inventory; defaults to stdout."
    )
    parser.add_argument(
        "--inventory-json", type=Path, help="Write machine-readable inventory JSON."
    )
    parser.add_argument(
        "--api-ledger",
        type=Path,
        help="Write API migration ledger JSON; requires --exceptions.",
    )
    parser.add_argument(
        "--exceptions",
        type=Path,
        help="Read and validate an explicit exception manifest.",
    )
    parser.add_argument(
        "--check", action="store_true", help="Fail if generated outputs are stale."
    )
    parser.add_argument(
        "--fail-expired",
        action="store_true",
        help="Fail when a current exception's review_by is before the evaluation date.",
    )
    parser.add_argument(
        "--as-of",
        type=_parse_date_argument,
        help="Expiry evaluation date (YYYY-MM-DD).",
    )
    args = parser.parse_args(argv)
    if args.as_of is not None and not args.fail_expired:
        parser.error("--as-of requires --fail-expired")
    if args.fail_expired and args.exceptions is None:
        parser.error("--fail-expired requires --exceptions")
    if args.api_ledger is not None and args.exceptions is None:
        parser.error("--api-ledger requires --exceptions")
    return args


def _resolve(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def _check_output(path: Path, expected: str) -> bool:
    existing = path.read_text(encoding="utf-8") if path.is_file() else ""
    if existing == expected:
        return True
    print(f"[app-direct-sql-inventory] ERROR: {path} is stale.", file=sys.stderr)
    return False


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    output = _resolve(args.output) if args.output else None
    exceptions_path = _resolve(args.exceptions) if args.exceptions else None
    inventory_json = _resolve(args.inventory_json) if args.inventory_json else None
    api_ledger = _resolve(args.api_ledger) if args.api_ledger else None
    try:
        uses = collect_uses()
        records = load_exception_records(exceptions_path) if exceptions_path else []
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[app-direct-sql-inventory] ERROR: {exc}", file=sys.stderr)
        return 1
    if exceptions_path:
        errors = validate_exception_records(
            uses,
            records,
            fail_expired=args.fail_expired,
            as_of=args.as_of,
        )
        if errors:
            print(
                "[app-direct-sql-inventory] ERROR: exception validation failed:",
                file=sys.stderr,
            )
            for error in errors:
                print(f"  - {error}", file=sys.stderr)
            return 1

    outputs: list[tuple[Path, str]] = []
    if output is not None:
        outputs.append((output, render_markdown(uses, records)))
    if inventory_json is not None:
        outputs.append((inventory_json, render_inventory_json(uses, records)))
    if api_ledger is not None:
        outputs.append((api_ledger, render_api_ledger_json(uses, records)))

    if args.check:
        return (
            0 if all(_check_output(path, expected) for path, expected in outputs) else 1
        )
    if not outputs:
        sys.stdout.write(render_markdown(uses, records))
        return 0
    for path, rendered in outputs:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
