from __future__ import annotations

from datetime import date
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "architecture" / "check-hotspots.py"
TEST_PRODUCTION_SOURCE_TREES = ((Path("src"), frozenset({".tsx"})),)


def load_module():
    spec = importlib.util.spec_from_file_location("check_hotspots_under_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def manifest(*, ceiling: int = 2, review_by: str = "2026-08-14") -> dict:
    return {
        "schema_version": 1,
        "policy": {
            "production_hotspot_lines": 2,
            "route_page_target_lines": 1,
            "review_window_days": 30,
        },
        "ceiling_exceptions": [],
        "hotspots": [
            {
                "path": "src/known.tsx",
                "owner": "Task 4",
                "classification": "temporary_exception",
                "line_ceiling": ceiling,
                "target_lines": 1,
                "reason": "Focused extraction remains oversized.",
                "review_by": review_by,
                "removal_plan": "Split into presentational children.",
            }
        ],
    }


def write_origin_main_baseline(tmp_path: Path, payload: dict) -> None:
    """Create the exact baseline object required by the CLI without a remote."""

    manifest_path = tmp_path / "hotspots.json"
    manifest_path.write_text(json.dumps(payload), encoding="utf-8")
    schema_path = tmp_path / "docs/workspace/architecture-hotspots.schema.json"
    schema_path.parent.mkdir(parents=True)
    schema_path.write_text(
        (ROOT / "docs/workspace/architecture-hotspots.schema.json").read_text(
            encoding="utf-8"
        ),
        encoding="utf-8",
    )
    for command in (
        ["git", "init", "--initial-branch=main", str(tmp_path)],
        ["git", "-C", str(tmp_path), "config", "user.email", "hotspots@example.test"],
        ["git", "-C", str(tmp_path), "config", "user.name", "Hotspot Tests"],
        ["git", "-C", str(tmp_path), "add", "hotspots.json"],
        ["git", "-C", str(tmp_path), "commit", "-m", "baseline"],
        [
            "git",
            "-C",
            str(tmp_path),
            "update-ref",
            "refs/remotes/origin/main",
            "HEAD",
        ],
    ):
        subprocess.run(command, check=True, capture_output=True, text=True)


def test_current_or_smaller_hotspot_passes(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")

    errors = module.validate_hotspots(
        tmp_path,
        manifest(),
        fail_expired=True,
        as_of=date(2026, 7, 16),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert errors == []


def test_growth_past_ceiling_fails(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\nthree\n", encoding="utf-8")

    errors = module.validate_hotspots(
        tmp_path,
        manifest(),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("grew past line ceiling" in error for error in errors)


def test_baseline_ratchet_rejects_a_ceiling_increase() -> None:
    module = load_module()
    baseline = manifest(ceiling=2)
    proposed = manifest(ceiling=3)

    errors = module.validate_baseline_ratchet(
        proposed,
        baseline,
        baseline_ref="origin/main",
    )

    assert errors == [
        "src/known.tsx: line_ceiling increase from baseline 2 to 3 is not allowed"
    ]


def test_baseline_ratchet_allows_retained_or_lowered_ceiling() -> None:
    module = load_module()
    baseline = manifest(ceiling=3)

    assert (
        module.validate_baseline_ratchet(
            manifest(ceiling=3), baseline, baseline_ref="origin/main"
        )
        == []
    )
    assert (
        module.validate_baseline_ratchet(
            manifest(ceiling=2), baseline, baseline_ref="origin/main"
        )
        == []
    )


def test_schema_validation_rejects_a_missing_required_hotspot_field() -> None:
    module = load_module()
    payload = manifest()
    del payload["hotspots"][0]["owner"]

    errors = module.validate_manifest_schema(
        payload,
        module.load_manifest_schema(ROOT),
    )

    assert errors == ["schema: hotspots.0: 'owner' is a required property"]


def test_real_manifest_passes_the_checked_in_schema() -> None:
    module = load_module()
    payload = json.loads(
        (ROOT / "docs/workspace/architecture-hotspots.json").read_text(encoding="utf-8")
    )

    assert (
        module.validate_manifest_schema(
            payload,
            module.load_manifest_schema(ROOT),
        )
        == []
    )


def test_complete_unexpired_exception_permits_only_its_measured_overage(
    tmp_path: Path,
) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\nthree\n", encoding="utf-8")
    payload = manifest(ceiling=2, review_by="2026-09-16")
    payload["ceiling_exceptions"] = [
        {
            "name": "known-tsx-2026-09-16",
            "path": "src/known.tsx",
            "approver": "Thomas Hulihan",
            "reason": "The fixture verifies a narrow temporary measured overage.",
            "expires_on": "2026-09-16",
            "independent_reviewer": "Codex implementation_reviewer T2-REVIEW-20260817",
        }
    ]

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        fail_expired=True,
        as_of=date(2026, 8, 17),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert errors == []


def test_incomplete_or_expired_exception_cannot_permit_an_overage(
    tmp_path: Path,
) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\nthree\n", encoding="utf-8")
    payload = manifest(ceiling=2, review_by="2026-09-16")
    payload["ceiling_exceptions"] = [
        {
            "name": "known-tsx-2026-09-16",
            "path": "src/known.tsx",
            "reason": "The fixture verifies exception validation.",
            "expires_on": "2026-08-16",
            "independent_reviewer": "Codex implementation_reviewer T2-REVIEW-20260817",
        }
    ]

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        as_of=date(2026, 8, 17),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("missing approver" in error for error in errors)
    assert any("ceiling exception expired" in error for error in errors)
    assert any("grew past line ceiling" in error for error in errors)


def test_exception_name_and_path_must_each_be_unique(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\nthree\n", encoding="utf-8")
    payload = manifest(ceiling=2, review_by="2026-09-16")
    exception = {
        "name": "known-tsx-2026-09-16",
        "path": "src/known.tsx",
        "approver": "Thomas Hulihan",
        "reason": "The fixture verifies unique exception identity.",
        "expires_on": "2026-09-16",
        "independent_reviewer": "Codex implementation_reviewer T2-REVIEW-20260817",
    }
    payload["ceiling_exceptions"] = [exception, exception.copy()]

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        as_of=date(2026, 8, 17),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("duplicate ceiling exception name" in error for error in errors)
    assert any("duplicate ceiling exception path" in error for error in errors)


def test_unlisted_new_hotspot_fails(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")
    (tmp_path / "src/new.tsx").write_text("one\ntwo\nthree\n", encoding="utf-8")

    errors = module.validate_hotspots(
        tmp_path,
        manifest(),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("new production hotspot" in error for error in errors)


def test_cli_discovers_hotspots_across_code_owned_production_trees(
    tmp_path: Path,
) -> None:
    backend_api = tmp_path / "TRR-Backend/api"
    backend_runtime = tmp_path / "TRR-Backend/trr_backend"
    app_source = tmp_path / "TRR-APP/apps/web/src/nested"
    backend_api.mkdir(parents=True)
    backend_runtime.mkdir(parents=True)
    app_source.mkdir(parents=True)
    (backend_api / "known.py").write_text("one\ntwo\nthree\n", encoding="utf-8")
    (backend_runtime / "small.py").write_text("one\n", encoding="utf-8")
    (app_source / "unowned.ts").write_text("one\ntwo\nthree\n", encoding="utf-8")
    payload = {
        "schema_version": 1,
        "policy": {
            "production_hotspot_lines": 2,
            "route_page_target_lines": 1,
            "review_window_days": 30,
        },
        # A manifest-owned glob must not be able to hide the app hotspot.
        "scan_globs": ["TRR-Backend/api/*.py"],
        "hotspots": [
            {
                "path": "TRR-Backend/api/known.py",
                "owner": "Task 3",
                "classification": "existing_hotspot",
                "line_ceiling": 3,
                "target_lines": 1,
                "reason": "Legacy API module remains oversized.",
                "review_by": "2026-08-14",
                "removal_plan": "Extract a bounded service and router.",
            }
        ],
    }
    write_origin_main_baseline(tmp_path, payload)
    manifest_path = tmp_path / "hotspots.json"

    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--root",
            str(tmp_path),
            "--manifest",
            str(manifest_path),
            "--as-of",
            "2026-07-16",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 1
    assert (
        "TRR-APP/apps/web/src/nested/unowned.ts: new production hotspot exceeds 2 lines without metadata"
        in completed.stdout
    )


def test_cli_wires_the_checked_in_schema_for_invalid_manifest_shape(
    tmp_path: Path,
) -> None:
    backend_api = tmp_path / "TRR-Backend/api"
    (tmp_path / "TRR-Backend/trr_backend").mkdir(parents=True)
    (tmp_path / "TRR-APP/apps/web/src").mkdir(parents=True)
    backend_api.mkdir(parents=True)
    (backend_api / "known.py").write_text("one\ntwo\n", encoding="utf-8")
    payload = {
        "schema_version": 1,
        "policy": {
            "production_hotspot_lines": 2,
            "route_page_target_lines": 1,
            "review_window_days": 30,
        },
        "ceiling_exceptions": [],
        "hotspots": [
            {
                "path": "TRR-Backend/api/known.py",
                "classification": "existing_hotspot",
                "line_ceiling": 2,
                "target_lines": 1,
                "reason": "Schema wiring fixture.",
                "review_by": "2026-08-14",
                "removal_plan": "Schema wiring fixture.",
            }
        ],
    }
    write_origin_main_baseline(tmp_path, payload)

    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--root",
            str(tmp_path),
            "--manifest",
            str(tmp_path / "hotspots.json"),
            "--as-of",
            "2026-07-16",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 1
    assert (
        "architecture-hotspots: ERROR schema: hotspots.0: 'owner' is a required property"
        in completed.stdout
    )


def test_cli_rejects_symlinked_directory_inside_production_tree(
    tmp_path: Path,
) -> None:
    backend_api = tmp_path / "TRR-Backend/api"
    backend_runtime = tmp_path / "TRR-Backend/trr_backend"
    app_source = tmp_path / "TRR-APP/apps/web/src"
    backend_api.mkdir(parents=True)
    backend_runtime.mkdir(parents=True)
    app_source.mkdir(parents=True)
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "hidden.py").write_text("one\ntwo\nthree\n", encoding="utf-8")
    (backend_api / "linked").symlink_to(outside, target_is_directory=True)
    payload = {
        "schema_version": 1,
        "policy": {
            "production_hotspot_lines": 2,
            "route_page_target_lines": 1,
            "review_window_days": 30,
        },
        "ceiling_exceptions": [],
        "hotspots": [],
    }
    write_origin_main_baseline(tmp_path, payload)
    manifest_path = tmp_path / "hotspots.json"

    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--root",
            str(tmp_path),
            "--manifest",
            str(manifest_path),
            "--as-of",
            "2026-07-16",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 1
    assert (
        "production source entry must not be a symlink: TRR-Backend/api/linked"
        in completed.stdout
    )


def test_cli_rejects_symlinked_ancestor_of_production_root(tmp_path: Path) -> None:
    outside_backend = tmp_path / "outside-backend"
    (outside_backend / "api").mkdir(parents=True)
    (outside_backend / "trr_backend").mkdir()
    (tmp_path / "TRR-Backend").symlink_to(outside_backend, target_is_directory=True)
    (tmp_path / "TRR-APP/apps/web/src").mkdir(parents=True)
    payload = {
        "schema_version": 1,
        "policy": {
            "production_hotspot_lines": 2,
            "route_page_target_lines": 1,
            "review_window_days": 30,
        },
        "ceiling_exceptions": [],
        "hotspots": [],
    }
    write_origin_main_baseline(tmp_path, payload)
    manifest_path = tmp_path / "hotspots.json"

    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--root",
            str(tmp_path),
            "--manifest",
            str(manifest_path),
            "--as-of",
            "2026-07-16",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 1
    assert (
        "production source ancestor must not be a symlink: TRR-Backend"
        in completed.stdout
    )


def test_expired_review_fails_when_requested(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")

    errors = module.validate_hotspots(
        tmp_path,
        manifest(review_by="2026-07-15"),
        fail_expired=True,
        as_of=date(2026, 7, 16),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("hotspot review expired" in error for error in errors)


def test_manifest_cannot_reconfigure_code_owned_discovery(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")
    payload = manifest()
    payload["scan_globs"] = ["../**/*.py"]

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert errors == [
        "scan_globs is no longer supported; production discovery is code-owned"
    ]


def test_route_page_target_cannot_exceed_policy(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "TRR-APP/apps/web/src/app/example/page.tsx"
    source.parent.mkdir(parents=True)
    source.write_text("one\ntwo\n", encoding="utf-8")
    payload = manifest(ceiling=1000)
    payload["hotspots"][0]["path"] = "TRR-APP/apps/web/src/app/example/page.tsx"
    payload["hotspots"][0]["target_lines"] = 501

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        production_source_trees=((Path("TRR-APP/apps/web/src"), frozenset({".tsx"})),),
    )

    assert any(
        "route/page target_lines must be no greater than 1" in error for error in errors
    )


def test_review_date_cannot_disable_the_review_window(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")

    errors = module.validate_hotspots(
        tmp_path,
        manifest(review_by="2027-07-16"),
        as_of=date(2026, 7, 16),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("exceeds the 30-day review window" in error for error in errors)


def test_missing_production_source_root_fails(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")
    payload = manifest()

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        production_source_trees=((Path("missing"), frozenset({".tsx"})),),
    )

    assert errors == ["production source root does not exist: missing"]


def test_invalid_review_window_reports_an_error_instead_of_crashing(
    tmp_path: Path,
) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")
    payload = manifest()
    payload["policy"]["review_window_days"] = "30"

    errors = module.validate_hotspots(
        tmp_path,
        payload,
        as_of=date(2026, 7, 16),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert errors == ["review_window_days must be 30"]


def test_manifest_path_cannot_escape_workspace(tmp_path: Path) -> None:
    module = load_module()

    with pytest.raises(module.HotspotValidationError, match="escapes workspace"):
        module.resolve_manifest_path(tmp_path, Path("../outside.json"))
