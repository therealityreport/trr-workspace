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
    manifest_path = tmp_path / "hotspots.json"
    manifest_path.write_text(json.dumps(payload), encoding="utf-8")

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
    manifest_path = tmp_path / "hotspots.json"
    manifest_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "policy": {
                    "production_hotspot_lines": 2,
                    "route_page_target_lines": 1,
                    "review_window_days": 30,
                },
                "hotspots": [],
            }
        ),
        encoding="utf-8",
    )

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
    manifest_path = tmp_path / "hotspots.json"
    manifest_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "policy": {
                    "production_hotspot_lines": 2,
                    "route_page_target_lines": 1,
                    "review_window_days": 30,
                },
                "hotspots": [],
            }
        ),
        encoding="utf-8",
    )

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


def test_manifest_source_trees_drive_production_discovery(tmp_path: Path) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")
    payload = manifest()
    payload["discovery"] = {
        "mode": "code_owned",
        "source_trees": [{"root": "src", "extensions": [".tsx"]}],
    }

    assert module.validate_hotspots(tmp_path, payload) == []


def test_listed_hotspot_line_count_errors_use_checker_error_contract(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    module = load_module()
    source = tmp_path / "src/known.tsx"
    source.parent.mkdir()
    source.write_text("one\ntwo\n", encoding="utf-8")

    def fail_line_count(_path: Path) -> int:
        raise OSError("permission denied")

    monkeypatch.setattr(module, "line_count", fail_line_count)
    errors = module.validate_hotspots(
        tmp_path,
        manifest(),
        production_source_trees=TEST_PRODUCTION_SOURCE_TREES,
    )

    assert any("src/known.tsx: cannot count source lines" in error for error in errors)


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
