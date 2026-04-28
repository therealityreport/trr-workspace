#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "docs/workspace/env-contract-inventory.md"
DEPRECATIONS_PATH = ROOT / "docs/workspace/env-deprecations.md"
VERCEL_REVIEW_PATH = ROOT / "docs/workspace/vercel-env-review.md"
SHARED_ENV_MANIFEST_PATH = ROOT / "docs/workspace/shared-env-manifest.json"

CANONICAL_INVENTORY: tuple[tuple[str, tuple[tuple[str, tuple[str, ...]], ...]], ...] = (
    (
        "Workspace Launcher",
        (
            ("Local workspace sentinel", ("TRR_LOCAL_DEV",)),
            ("Managed local backend base", ("TRR_API_URL",)),
            (
                "Managed local runtime DB",
                (
                    "TRR_DB_DIRECT_URL",
                    "TRR_DB_SESSION_URL",
                    "TRR_DB_URL",
                    "TRR_DB_TRANSACTION_URL",
                    "TRR_DB_RUNTIME_LANE",
                    "TRR_DB_TRANSACTION_FLIGHT_TEST",
                    "TRR_DB_FALLBACK_URL",
                ),
            ),
        ),
    ),
    (
        "TRR-Backend",
        (
            (
                "Runtime DB",
                (
                    "TRR_DB_DIRECT_URL",
                    "TRR_DB_SESSION_URL",
                    "TRR_DB_URL",
                    "TRR_DB_TRANSACTION_URL",
                    "TRR_DB_RUNTIME_LANE",
                    "TRR_DB_TRANSACTION_FLIGHT_TEST",
                    "TRR_DB_FALLBACK_URL",
                ),
            ),
            ("Supabase API/auth", ("SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_JWT_SECRET")),
            ("Service auth", ("TRR_INTERNAL_ADMIN_SHARED_SECRET",)),
        ),
    ),
    (
        "TRR-APP",
        (
            ("Backend base", ("TRR_API_URL",)),
            ("Server/admin Supabase", ("TRR_CORE_SUPABASE_URL", "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY")),
            ("Internal admin auth", ("TRR_INTERNAL_ADMIN_SHARED_SECRET",)),
            (
                "Server Postgres runtime",
                (
                    "TRR_DB_DIRECT_URL",
                    "TRR_DB_SESSION_URL",
                    "TRR_DB_URL",
                    "TRR_DB_TRANSACTION_URL",
                    "TRR_DB_RUNTIME_LANE",
                    "TRR_DB_TRANSACTION_FLIGHT_TEST",
                    "TRR_DB_FALLBACK_URL",
                ),
            ),
        ),
    ),
)

DEPRECATED_NAMES = ("SUPABASE_DB_URL", "DATABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")

HISTORICAL_PATH_FRAGMENTS = (
    "docs/cross-collab/",
    "docs/ai/",
    "docs/codex/plans/",
    "docs/_archive/",
    "docs/superpowers/plans/",
)

IN_PROGRESS_PATH_FRAGMENTS = (
    "docs/plans/in_progress/",
)

GENERATED_NON_ACTIONABLE_PATHS = {
    "TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts",
    "docs/workspace/redacted-env-inventory.md",
}

COMPATIBILITY_PATHS = {
    "TRR-Backend/api/main.py",
    "TRR-Backend/scripts/_db_url.py",
    "TRR-Backend/scripts/db/guard_core_schema.sql",
    "TRR-Backend/scripts/db/run_sql.sh",
    "TRR-Backend/scripts/modal/prepare_named_secrets.py",
    "TRR-Backend/scripts/sync/sync_shows_all.py",
    "TRR-Backend/scripts/verify/verify_media_unification.py",
    "TRR-Backend/trr_backend/db/postgrest_cache.py",
    "TRR-Backend/trr_backend/db/connection.py",
    "TRR-Backend/trr_backend/db/preflight.py",
    "TRR-APP/apps/web/src/lib/server/postgres.ts",
    "TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts",
    "TRR-APP/scripts/auto-categorize-flairs.ts",
    "scripts/redact-env-inventory.py",
    "scripts/lib/runtime-db-env.sh",
}

COMPATIBILITY_PREFIXES = (
    "TRR-Backend/tests/",
    "TRR-APP/apps/web/tests/",
    "TRR-Backend/trr_backend/repositories/",
    "TRR-Backend/scripts/ops/",
)

DATABASE_URL_TOOLING_PATHS = {
    "TRR-Backend/scripts/db/README.md",
    "TRR-APP/apps/web/POSTGRES_SETUP.md",
    "TRR-APP/apps/web/scripts/check-surveys.mjs",
    "TRR-APP/apps/web/scripts/check-survey-x.mjs",
    "TRR-APP/apps/web/scripts/delete-web-scrape-imports.mjs",
    "TRR-APP/apps/web/scripts/import-rhoslc-s6.mjs",
    "TRR-APP/apps/web/scripts/run-migrations.mjs",
}

SUPABASE_SERVICE_ROLE_KEY_CANONICAL_PATHS = {
    "TRR-Backend/.env.example",
    "TRR-Backend/README.md",
    "TRR-Backend/docs/api/run.md",
    "TRR-Backend/docs/cloud/quick_cloud_setup.md",
    "TRR-Backend/docs/runbooks/postgrest_schema_cache.md",
    "TRR-Backend/docs/runbooks/show_import_job.md",
    "TRR-Backend/scripts/README.md",
    "TRR-Backend/scripts/db/README.md",
}

INTENTIONAL_EXCEPTION_NOTES: tuple[tuple[str, str], ...] = (
    (
        "Backend compatibility fallbacks",
        "`TRR-Backend/trr_backend/db/connection.py`, `TRR-Backend/scripts/_db_url.py`, "
        "and `TRR-Backend/scripts/db/run_sql.sh` may still read `SUPABASE_DB_URL` / `DATABASE_URL` as "
        "deprecated fallback inputs while runtime preference stays on `TRR_DB_DIRECT_URL` / `TRR_DB_SESSION_URL` / `TRR_DB_URL` / `TRR_DB_FALLBACK_URL`.",
    ),
    (
        "Vercel integration-managed retained envs",
        "`docs/workspace/vercel-env-review.md` documents the reviewed retained `DATABASE_URL`, `POSTGRES_*`, "
        "and `SUPABASE_*` integration-managed values for the active `trr-app` project.",
    ),
    (
        "Tooling-only DATABASE_URL consumers",
        "`TRR-APP/apps/web/scripts/run-migrations.mjs` and related one-off scripts still require `DATABASE_URL`; "
        "operators should source it from `TRR_DB_DIRECT_URL`, `TRR_DB_SESSION_URL`, or `TRR_DB_URL` at invocation time instead of treating it as a runtime contract.",
    ),
)

VERCEL_REVIEW_ROWS: tuple[tuple[str, str, str, str, str], ...] = (
    (
        "Preview",
        "DATABASE_URL",
        "env pull only",
        "integration-managed-retained",
        "Retained because the deployed app runtime does not read DATABASE_URL and the value is provisioned outside the normal project env listing surface.",
    ),
    (
        "Preview",
        "FIREBASE_SERVICE_ACCOUNT",
        "env pull only",
        "canonical",
        "Canonical app-owned Firebase admin credential used by server auth, layouts, and session routes.",
    ),
    (
        "Preview",
        "NX_DAEMON",
        "env pull only",
        "integration-managed-retained",
        "Retained as a Vercel/Nx build-runtime flag rather than an app contract variable.",
    ),
    (
        "Preview",
        "TURBO_*",
        "env pull only",
        "integration-managed-retained",
        "Retained as Turborepo/Vercel build-system metadata.",
    ),
    (
        "Preview",
        "VERCEL_*",
        "env pull only",
        "integration-managed-retained",
        "Retained as Vercel platform metadata and deployment/OIDC values.",
    ),
    (
        "Production",
        "DATABASE_URL",
        "env pull only",
        "integration-managed-retained",
        "Retained because the deployed app runtime does not read DATABASE_URL and the value is provisioned outside the normal project env listing surface.",
    ),
    (
        "Production",
        "POSTGRES_*",
        "env ls + env pull",
        "integration-managed-retained",
        "Retained as integration-provisioned Postgres connection helpers; app runtime stays on canonical TRR_DB_DIRECT_URL, TRR_DB_SESSION_URL, or TRR_DB_URL.",
    ),
    (
        "Production",
        "SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_JWT_SECRET, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY",
        "env ls + env pull",
        "integration-managed-retained",
        "Retained as integration-provisioned Supabase helpers; active app runtime uses TRR_CORE_SUPABASE_* server-side instead.",
    ),
    (
        "Production",
        "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
        "env ls + env pull",
        "integration-managed-retained",
        "Retained as an integration-managed public helper, not part of the active app runtime contract.",
    ),
    (
        "Production",
        "FIREBASE_SERVICE_ACCOUNT",
        "env pull only",
        "canonical",
        "Canonical app-owned Firebase admin credential used by server auth, layouts, and session routes.",
    ),
    (
        "Production",
        "NX_DAEMON",
        "env pull only",
        "integration-managed-retained",
        "Retained as a Vercel/Nx build-runtime flag rather than an app contract variable.",
    ),
    (
        "Production",
        "TURBO_*",
        "env pull only",
        "integration-managed-retained",
        "Retained as Turborepo/Vercel build-system metadata.",
    ),
    (
        "Production",
        "VERCEL_*",
        "env pull only",
        "integration-managed-retained",
        "Retained as Vercel platform metadata and deployment/OIDC values.",
    ),
)

EXCLUDE_GLOBS = (
    "!**/node_modules/**",
    "!**/.next/**",
    "!**/.git/**",
    "!**/__pycache__/**",
    "!**/dist/**",
    "!**/build/**",
    "!**/docs/ai/archive/**",
    "!**/docs/ai/evidence/**",
    "!docs/workspace/env-contract-inventory.md",
    "!docs/workspace/env-deprecations.md",
    "!docs/workspace/vercel-env-review.md",
    "!scripts/env_contract_report.py",
)


@dataclass(frozen=True)
class ValidationError:
    label: str
    detail: str


@dataclass(frozen=True)
class DeprecationHit:
    name: str
    path: str
    line_number: int
    text: str
    classification: str
    rationale: str


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _load_shared_env_manifest() -> dict:
    return json.loads(_read_text(SHARED_ENV_MANIFEST_PATH))


def _env_keys(path: Path) -> set[str]:
    keys: set[str] = set()
    for raw_line in _read_text(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, _ = line.partition("=")
        if key and key.replace("_", "").isalnum():
            keys.add(key)
    return keys


def _run_rg(pattern: str) -> list[str]:
    command = ["rg", "-n", pattern, "TRR-Backend", "TRR-APP", "scripts", "docs"]
    for glob in EXCLUDE_GLOBS:
        command.extend(["--glob", glob])
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode not in {0, 1}:
        raise RuntimeError(result.stderr.strip() or f"rg failed for pattern: {pattern}")
    return sorted(line for line in result.stdout.splitlines() if line.strip())


def _iter_deprecation_hits(name: str) -> Iterable[DeprecationHit]:
    for raw_hit in _run_rg(rf"\b{name}\b"):
        path, line_no, text = raw_hit.split(":", 2)
        parsed = _classify_deprecation_hit(name=name, path=path, line_number=int(line_no), text=text.strip())
        if parsed is None:
            continue
        yield parsed


def _is_historical_path(path: str) -> bool:
    if path in GENERATED_NON_ACTIONABLE_PATHS:
        return True
    if "docs/plans/" in path and not any(fragment in path for fragment in IN_PROGRESS_PATH_FRAGMENTS):
        return True
    return any(fragment in path for fragment in HISTORICAL_PATH_FRAGMENTS)


def _is_compatibility_path(path: str) -> bool:
    return path in COMPATIBILITY_PATHS or any(path.startswith(prefix) for prefix in COMPATIBILITY_PREFIXES)


def _classify_deprecation_hit(
    *,
    name: str,
    path: str,
    line_number: int,
    text: str,
) -> DeprecationHit | None:
    lower_text = text.lower()

    if name == "SUPABASE_SERVICE_ROLE_KEY":
        if path in SUPABASE_SERVICE_ROLE_KEY_CANONICAL_PATHS:
            return None
        if path.startswith("TRR-Backend/scripts/") and "db/README.md" not in path:
            return None
        if path.startswith("TRR-Backend/tests/"):
            return None

    if _is_historical_path(path):
        return DeprecationHit(
            name=name,
            path=path,
            line_number=line_number,
            text=text,
            classification="historical/docs",
            rationale="Historical handoff, archived material, or generated artifact retained for reference only.",
        )

    if path == "docs/workspace/vercel-env-review.md":
        return DeprecationHit(
            name=name,
            path=path,
            line_number=line_number,
            text=text,
            classification="compatibility-only",
            rationale="Reviewed deployment-governance exception retained intentionally for the active Vercel project.",
        )

    if path in DATABASE_URL_TOOLING_PATHS:
        return DeprecationHit(
            name=name,
            path=path,
            line_number=line_number,
            text=text,
            classification="compatibility-only",
            rationale="Tooling-only script still requires DATABASE_URL at invocation time; this is not a runtime contract.",
        )

    if _is_compatibility_path(path):
        return DeprecationHit(
            name=name,
            path=path,
            line_number=line_number,
            text=text,
            classification="compatibility-only",
            rationale="Explicit compatibility layer or regression coverage for deprecated env handling.",
        )

    if any(
        phrase in lower_text
        for phrase in (
            "deprecated",
            "compatibility",
            "does not use",
            "no longer",
            "legacy-only",
            "tooling-only",
            "tool-specific",
            "third-party tool",
            "migration scripts only",
            "runtime contract",
            "explicitly requires",
            "integration-managed-retained",
        )
    ):
        return DeprecationHit(
            name=name,
            path=path,
            line_number=line_number,
            text=text,
            classification="compatibility-only",
            rationale="The deprecated name is referenced only to document or enforce non-preferred fallback behavior.",
        )

    return DeprecationHit(
        name=name,
        path=path,
        line_number=line_number,
        text=text,
        classification="active drift",
        rationale="Active runtime, operator, or deployment-facing surface still advertises a deprecated env name as normal usage.",
    )


def _collect_deprecation_hits() -> list[DeprecationHit]:
    hits: list[DeprecationHit] = []
    for name in DEPRECATED_NAMES:
        hits.extend(_iter_deprecation_hits(name))
    hits.sort(key=lambda hit: (hit.classification, hit.name, hit.path, hit.line_number))
    return hits


def _build_inventory_markdown() -> str:
    lines = [
        "# Canonical Env Contract Inventory",
        "",
        "Generated by `scripts/env_contract_report.py`. Do not edit by hand.",
        "",
        "| Surface | Responsibility | Canonical variables |",
        "|---|---|---|",
    ]
    for surface, rows in CANONICAL_INVENTORY:
        for responsibility, variables in rows:
            lines.append(f"| {surface} | {responsibility} | `{ '`, `'.join(variables) }` |")
    lines.extend(
        [
            "",
            "## Owner Aliases",
            "",
            "| Alias | Scope | Source of truth |",
            "|---|---|---|",
            "| `workspace-ops` | Workspace scripts, profiles, redacted inventories, and operator runbooks. | `docs/workspace/` plus root `scripts/` and `profiles/`. |",
            "| `backend-shared-schema` | Shared schema, backend APIs, migrations, auth validation, and worker DB access. | `TRR-Backend` code and `TRR-Backend/supabase/migrations`. |",
            "| `admin-read-model` | TRR-APP admin read paths retained until a backend aggregate endpoint exists. | `docs/workspace/api-migration-ledger.md`. |",
            "| `app-local` | TRR-APP-only authoring/editor flows that intentionally remain app-local. | TRR-APP app code plus this workspace contract. |",
            "",
            "## Supabase Runtime Ownership Matrix",
            "",
            "| Surface | Owner alias | Runtime context | Privilege | Allowed environments | Connection/API type | Notes |",
            "|---|---|---|---|---|---|---|",
            "| `TRR_DB_DIRECT_URL` | `workspace-ops` | Local `make dev` Next server and backend API | postgres role | local only | Direct Postgres | Required local direct lane for default `make dev`; never pass to Modal, Render, Cloud Run, Vercel, or remote workers. |",
            "| `TRR_DB_SESSION_URL`, `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` | `workspace-ops` | Cloud/hybrid remote workers, deployed runtimes, and migration/tooling | postgres role | local, preview, production | Postgres session by default | Session-mode runtime lane; `TRR_DB_URL` remains the compatibility fallback while explicit lanes roll out. |",
            "| `TRR_DB_TRANSACTION_URL`, `TRR_DB_RUNTIME_LANE`, `TRR_DB_TRANSACTION_FLIGHT_TEST` | `workspace-ops` | Scoped Next/backend read flight tests | postgres role | local, preview, production with review | Supavisor transaction mode | Optional `:6543` lane; selected only when runtime lane is `transaction` and flight-test flag is enabled. |",
            "| `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` | `admin-read-model` | Next server only | service role | local, preview, production | Supabase REST/Auth/Storage API | Server/admin only; never browser public. |",
            "| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `backend-shared-schema` | Backend API or local Supabase tooling | public anon or local tooling | local, preview, production as explicitly configured | Supabase REST/Auth API | Backend and tooling surface; not a TRR-APP browser requirement. |",
            "| `SUPABASE_JWT_SECRET` | `backend-shared-schema` | Backend API | JWT validation secret | preview, production, local when Supabase auth is exercised | JWT validation only | Required for backend validation; not a client credential. |",
            "| `NEXT_PUBLIC_SUPABASE_*` | `app-local` | Browser only when a feature explicitly needs it | public anon | only explicitly enabled environments | Supabase browser API | Not required by the current TRR-APP runtime contract. |",
            "| Vercel `POSTGRES_*` and integration `SUPABASE_*` | `workspace-ops` | Vercel integration metadata | platform-managed | preview, production | Integration-managed retained envs | Reviewed in `docs/workspace/vercel-env-review.md`; do not promote to runtime source without a guard review. |",
            "| `DATABASE_URL`, `SUPABASE_DB_URL` | `workspace-ops` | migration/tooling compatibility only | postgres role | local/operator shells only | Tool-specific Postgres input | Deprecated for runtime; allowed only in explicit compatibility shims and reviewed generated inventories. |",
            "",
            "## Compatibility Policy",
            "",
            "- `compatibility-only` references are allowed only in explicit fallback code, tests, or reviewed deployment-governance exceptions.",
            "- `active drift` references fail env-contract validation and must be removed from active runtime, operator, and deployment guidance.",
            "- `historical/docs` references are retained for archive value and are excluded from the actionable drift count.",
            "",
            "## Deployment Governance",
            "",
            "- `unknown-blocking` Vercel vars block survey cutover until they are reviewed explicitly.",
            "- `integration-managed-retained` Vercel vars are allowed once documented in `docs/workspace/vercel-env-review.md`.",
            "- Live env governance uses four review labels where applicable: `canonical`, `compatibility-only`, `integration-managed-retained`, and `deprecated-removable`.",
            "",
            "## Deprecated Runtime Names",
            "",
            "- `SUPABASE_DB_URL`",
            "- runtime `DATABASE_URL` outside explicit tooling flows",
            "- app-local/server `SUPABASE_SERVICE_ROLE_KEY` where `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` is canonical",
            "",
        ]
    )
    return "\n".join(lines)


def _build_deprecations_markdown() -> str:
    hits = _collect_deprecation_hits()
    grouped: dict[str, list[DeprecationHit]] = {
        "active drift": [],
        "compatibility-only": [],
        "historical/docs": [],
    }
    for hit in hits:
        grouped[hit.classification].append(hit)

    lines = [
        "# Env Contract Deprecation Report",
        "",
        "Generated by `scripts/env_contract_report.py`. Do not edit by hand.",
        "",
        "This report enumerates remaining deprecated-name occurrences across active repo files, compatibility shims, and archived/history surfaces.",
        "",
        "## Summary",
        "",
        f"- `active drift`: {len(grouped['active drift'])}",
        f"- `compatibility-only`: {len(grouped['compatibility-only'])}",
        f"- `historical/docs`: {len(grouped['historical/docs'])}",
        "",
    ]

    for classification in ("active drift", "compatibility-only", "historical/docs"):
        lines.append(f"## {classification.title()}")
        if not grouped[classification]:
            lines.extend(["", "No occurrences in this category.", ""])
            continue
        lines.extend(["", "| Deprecated name | Location | Rationale |", "|---|---|---|"])
        for hit in grouped[classification]:
            lines.append(
                f"| `{hit.name}` | `{hit.path}:{hit.line_number}:{hit.text}` | {hit.rationale} |"
            )
        lines.append("")

    lines.extend(
        [
            "## Remaining Intentional Exceptions",
            "",
        ]
    )
    for label, detail in INTENTIONAL_EXCEPTION_NOTES:
        lines.append(f"- {label}: {detail}")
    lines.append("")
    return "\n".join(lines)


def _build_vercel_review_markdown() -> str:
    lines = [
        "# Reviewed Vercel Env Surface",
        "",
        "Generated by `scripts/env_contract_report.py`. Do not edit by hand.",
        "",
        "## Active Source Of Truth",
        "",
        "| Surface | Source | Status |",
        "|---|---|---|",
        "| Active app project | `TRR-APP/.vercel/project.json` -> `trr-app` | canonical |",
        "| Nested app surface | `TRR-APP/apps/web/.vercel/project.json` -> `web` | `sandbox/stale`; project guard must fail for production work |",
        "| Project guard | `scripts/vercel-project-guard.py --project-dir TRR-APP` | required before production env mutation |",
        "| Nested project guard | `scripts/vercel-project-guard.py --project-dir TRR-APP/apps/web` | expected non-zero with `sandbox/stale-nested-project` classification |",
        "| Redacted env inventory | `scripts/redact-env-inventory.py --output docs/workspace/redacted-env-inventory.md` | shape-only review; no secret values |",
        "",
        "## Review Outcome",
        "",
        "- `unknown-blocking` entries remaining: `0`",
        "- Production env mutation remains blocked unless the active-project guard passes from `TRR-APP`.",
        "- The nested `TRR-APP/apps/web` link is formally classified as `sandbox/stale`, not production.",
        "- Historical production runtime evidence: `https://trr-app.vercel.app/` returned `200` after the earlier review pass.",
        "- Historical preview runtime evidence: latest preview deployment was `Ready` in `vercel inspect`; direct unauthenticated `curl` returns `401` because the deployment is Vercel-protected rather than unhealthy.",
        "",
        "## Reviewed Inventory",
        "",
        "| Environment | Variable(s) | Visibility | Classification | Rationale |",
        "|---|---|---|---|---|",
    ]
    for environment, variable, visibility, classification, rationale in VERCEL_REVIEW_ROWS:
        lines.append(f"| {environment} | `{variable}` | {visibility} | `{classification}` | {rationale} |")
    lines.extend(
        [
            "",
            "## Runtime Contract Checks",
            "",
            "- App server Postgres reads `TRR_DB_DIRECT_URL` / `TRR_DB_SESSION_URL` / `TRR_DB_URL` / `TRR_DB_FALLBACK_URL`; transaction mode additionally requires `TRR_DB_TRANSACTION_URL` and `TRR_DB_TRANSACTION_FLIGHT_TEST=1`. It does not use `DATABASE_URL` or legacy server-side Supabase names.",
            "- App server/admin Supabase reads `TRR_CORE_SUPABASE_URL` / `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` only.",
            "- No browser-side `NEXT_PUBLIC_SUPABASE_*` runtime envs are required for TRR-APP.",
            "- Internal admin proxy/auth flows require `TRR_INTERNAL_ADMIN_SHARED_SECRET`.",
            "- `FIREBASE_SERVICE_ACCOUNT` remains a canonical app-owned secret and is not part of the deprecated runtime-name cleanup.",
            "- Run the project guard from `TRR-APP`, not `TRR-APP/apps/web`, before any production env mutation.",
            "- Treat a passing guard from `TRR-APP/apps/web` as a deployment-process regression unless that directory is deliberately relinked and this review is rewritten.",
            "- Use the redacted env inventory helper for shape-only review; do not paste raw Vercel env values into docs.",
            "",
        ]
    )
    return "\n".join(lines)


def _write_if_changed(path: Path, content: str) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def _validate_contract() -> list[ValidationError]:
    errors: list[ValidationError] = []

    launcher = _read_text(ROOT / "scripts/dev-workspace.sh")
    if 'TRR_LOCAL_DEV=1 \\' not in launcher:
        errors.append(ValidationError("launcher-sentinel", "scripts/dev-workspace.sh must export TRR_LOCAL_DEV=1 to managed child processes."))
    if 'TRR_API_URL="http://127.0.0.1:${TRR_BACKEND_PORT}"' not in launcher:
        errors.append(ValidationError("launcher-backend-url", "scripts/dev-workspace.sh must own the managed local TRR_API_URL loopback value."))

    backend_keys = _env_keys(ROOT / "TRR-Backend/.env.example")
    for required in ("TRR_DB_DIRECT_URL", "TRR_DB_SESSION_URL", "TRR_DB_URL"):
        if required not in backend_keys:
            errors.append(ValidationError(f"backend-missing-{required.lower()}", f"TRR-Backend/.env.example must define {required}."))
    if "SUPABASE_DB_URL" in backend_keys:
        errors.append(ValidationError("backend-deprecated-supabase-db-url", "TRR-Backend/.env.example must not advertise SUPABASE_DB_URL."))

    manifest = _load_shared_env_manifest()
    app_required_keys = tuple(manifest["repo_validation"]["TRR-APP"]["required_env_example_keys"])

    app_keys = _env_keys(ROOT / "TRR-APP/apps/web/.env.example")
    for required in app_required_keys:
        if required not in app_keys:
            errors.append(ValidationError(f"app-missing-{required.lower()}", f"TRR-APP/apps/web/.env.example must define {required}."))
    for deprecated in ("SUPABASE_DB_URL", "DATABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"):
        if deprecated in app_keys:
            errors.append(ValidationError(f"app-deprecated-{deprecated.lower()}", f"TRR-APP/apps/web/.env.example must not advertise {deprecated}."))

    expected_inventory = _build_inventory_markdown()
    expected_deprecations = _build_deprecations_markdown()
    expected_vercel_review = _build_vercel_review_markdown()
    if INVENTORY_PATH.exists() and INVENTORY_PATH.read_text(encoding="utf-8") != expected_inventory:
        errors.append(ValidationError("inventory-stale", "docs/workspace/env-contract-inventory.md is out of date; regenerate it with scripts/env_contract_report.py write."))
    if DEPRECATIONS_PATH.exists() and DEPRECATIONS_PATH.read_text(encoding="utf-8") != expected_deprecations:
        errors.append(ValidationError("deprecations-stale", "docs/workspace/env-deprecations.md is out of date; regenerate it with scripts/env_contract_report.py write."))
    if VERCEL_REVIEW_PATH.exists() and VERCEL_REVIEW_PATH.read_text(encoding="utf-8") != expected_vercel_review:
        errors.append(ValidationError("vercel-review-stale", "docs/workspace/vercel-env-review.md is out of date; regenerate it with scripts/env_contract_report.py write."))

    active_drift = [hit for hit in _collect_deprecation_hits() if hit.classification == "active drift"]
    if active_drift:
        sample = ", ".join(f"{hit.path}:{hit.line_number}" for hit in active_drift[:5])
        if len(active_drift) > 5:
            sample = f"{sample}, ..."
        errors.append(
            ValidationError(
                "active-drift-present",
                f"Deprecated env names still appear in active runtime/operator surfaces ({len(active_drift)} hit(s)): {sample}",
            )
        )

    return errors


def _write_reports() -> None:
    inventory = _build_inventory_markdown()
    deprecations = _build_deprecations_markdown()
    vercel_review = _build_vercel_review_markdown()
    inventory_changed = _write_if_changed(INVENTORY_PATH, inventory)
    deprecations_changed = _write_if_changed(DEPRECATIONS_PATH, deprecations)
    vercel_review_changed = _write_if_changed(VERCEL_REVIEW_PATH, vercel_review)
    status = []
    if inventory_changed:
        status.append(str(INVENTORY_PATH.relative_to(ROOT)))
    if deprecations_changed:
        status.append(str(DEPRECATIONS_PATH.relative_to(ROOT)))
    if vercel_review_changed:
        status.append(str(VERCEL_REVIEW_PATH.relative_to(ROOT)))
    if status:
        print("Updated:", ", ".join(status))
    else:
        print("Env contract reports already up to date.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and generate TRR env contract reports.")
    parser.add_argument("command", choices=("validate", "write"))
    args = parser.parse_args(argv)

    if args.command == "write":
        _write_reports()
        return 0

    errors = _validate_contract()
    if not errors:
        print("Env contract validation OK")
        return 0

    for error in errors:
        print(f"[env-contract] {error.label}: {error.detail}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
