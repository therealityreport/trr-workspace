from __future__ import annotations

import contextlib
import io
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check-import-graph.py"
SPEC = importlib.util.spec_from_file_location("check_import_graph", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class ImportGraphTests(unittest.TestCase):
    def test_tarjan_reports_only_real_cycles(self) -> None:
        graph = {
            "a": {"b"},
            "b": {"a", "c"},
            "c": set(),
            "d": {"d"},
        }
        self.assertEqual(MODULE.cyclic_components(graph), [["a", "b"], ["d"]])

    def test_backend_graph_resolves_relative_and_legacy_dynamic_imports(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            social = root / "TRR-Backend/trr_backend/socials"
            repository = root / "TRR-Backend/trr_backend/repositories"
            social.mkdir(parents=True)
            repository.mkdir(parents=True)
            (root / "TRR-Backend/trr_backend/__init__.py").write_text("")
            (social / "__init__.py").write_text("")
            (repository / "__init__.py").write_text("")
            (repository / "social_season_analytics.py").write_text("VALUE = 1\n")
            (social / "social_season_analytics_impl.py").write_text("VALUE = 1\n")
            (social / "first.py").write_text(
                "from . import second\n"
                "from trr_backend.repositories import social_season_analytics\n"
            )
            (social / "second.py").write_text(
                "import importlib\n"
                "from . import first\n"
                "legacy = importlib.import_module('trr_backend.socials.social_season_analytics_impl')\n"
            )

            summary = MODULE.summarize_backend(MODULE.build_backend_graph(root))

            self.assertEqual(summary["social_cycle_count"], 1)
            self.assertEqual(summary["legacy_social_import_count"], 2)
            self.assertEqual(summary["legacy_social_importer_count"], 2)

    def test_app_graph_resolves_alias_relative_and_dynamic_imports(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "TRR-APP/apps/web/src"
            (source / "lib").mkdir(parents=True)
            (source / "feature").mkdir(parents=True)
            (source / "lib/a.ts").write_text(
                "import value from '../feature/b'\nexport default value\n"
            )
            (source / "feature/b.ts").write_text(
                "const load = () => import('@/lib/a')\nexport default load\n"
            )
            (source / "feature/index.ts").write_text("export { default } from './b'\n")

            result = MODULE.build_app_graph(root)
            summary = MODULE.summarize_app(result)

            self.assertEqual(summary["module_count"], 3)
            self.assertEqual(summary["cycle_count"], 1)
            self.assertIn(["feature/b.ts", "lib/a.ts"], summary["cycles"])

    def test_nonliteral_dynamic_targets_fail_closed_without_synthetic_edges(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            routers = root / "TRR-Backend/api/routers"
            app_source = root / "TRR-APP/apps/web/src/feature"
            routers.mkdir(parents=True)
            app_source.mkdir(parents=True)
            (root / "TRR-Backend/api/__init__.py").write_text("")
            (routers / "__init__.py").write_text("")
            (routers / "admin_target.py").write_text("VALUE = 1\n")
            (routers / "admin.py").write_text(
                "from importlib import import_module\n"
                "\n"
                "class AdminRouterInterface:\n"
                "    router_module = '.'.join(('api', 'routers', 'admin_target'))\n"
                "\n"
                "router_target = AdminRouterInterface.router_module\n"
                "router = import_module(router_target)\n"
                "provider_target = router_target\n"
                "provider = __import__(provider_target)\n"
            )
            (app_source / "loader.ts").write_text(
                "const target = '@/feature/target'\n"
                "export const load = () => import(target)\n"
            )

            backend = MODULE.build_backend_graph(root)
            app = MODULE.build_app_graph(root)
            report = {
                "backend": MODULE.summarize_backend(backend),
                "app": MODULE.summarize_app(app),
            }
            failures = MODULE.parse_error_failures(report)

            self.assertEqual(backend.graph["api.routers.admin"], set())
            self.assertEqual(len(backend.nonliteral_dynamic_imports), 2)
            self.assertEqual(len(app.nonliteral_dynamic_imports), 1)
            self.assertTrue(
                any(
                    "api/routers/admin.py:7 import_module(router_target)" in failure
                    for failure in failures
                )
            )
            self.assertTrue(
                any("__import__(provider_target)" in failure for failure in failures)
            )
            self.assertTrue(any("import(target)" in failure for failure in failures))
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    MODULE.main(["--repo-root", str(root), "--check-zero"]),
                    1,
                )

    def test_nonliteral_dynamic_target_requires_exact_documented_allowlist_entry(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "TRR-Backend/trr_backend"
            source.mkdir(parents=True)
            (source / "__init__.py").write_text("")
            path = source / "runtime_loader.py"
            path.write_text(
                "from importlib import import_module\n"
                "target = 'trr_backend.optional'\n"
                "loaded = import_module(target)\n"
            )
            key = (
                "TRR-Backend/trr_backend/runtime_loader.py",
                3,
                "import_module",
            )
            original = MODULE.DYNAMIC_IMPORT_ALLOWLIST
            MODULE.DYNAMIC_IMPORT_ALLOWLIST = {
                key: "Test-only optional runtime plugin load; not an architecture edge."
            }
            try:
                result = MODULE.build_backend_graph(root)
            finally:
                MODULE.DYNAMIC_IMPORT_ALLOWLIST = original

            self.assertEqual(result.nonliteral_dynamic_imports, [])

    def test_reviewed_provider_patch_import_is_structural_and_fails_closed_elsewhere(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "TRR-Backend/trr_backend/socials"
            source.mkdir(parents=True)
            (root / "TRR-Backend/trr_backend/__init__.py").write_text("")
            (source / "__init__.py").write_text("")
            path = source / "social_season_analytics_impl.py"
            path.write_text(
                "\n" * 137
                + "for _provider_path in (\n"
                + "    'trr_backend.socials.control_plane.queue_status',\n"
                + "    'trr_backend.socials.read_models.account_profile.common',\n"
                + "    'trr_backend.socials.analytics.read_models',\n"
                + "    'trr_backend.socials.pipelines.account_catalog.progress',\n"
                + "    'trr_backend.socials.control_plane.run_lifecycle',\n"
                + "    'trr_backend.socials.control_plane.dispatch_runtime',\n"
                + "    'trr_backend.socials.control_plane.dispatch',\n"
                + "    'trr_backend.socials.control_plane.recovery',\n"
                + "    'trr_backend.socials.control_plane.runtime',\n"
                + "    'trr_backend.socials.control_plane.shared_accounts',\n"
                + "    'trr_backend.socials.instagram.catalog_ingest',\n"
                + "    'trr_backend.socials.pipelines.account_catalog.launch',\n"
                + "    'trr_backend.socials.pipelines.comments.instagram',\n"
                + "):\n"
                + "    __import__(_provider_path, fromlist=['_configure_legacy_provider'])\n"
                + "__import__(_provider_path, fromlist=['_configure_legacy_provider'])\n"
            )

            result = MODULE.build_backend_graph(root)

            self.assertEqual(len(result.nonliteral_dynamic_imports), 1)
            violation = result.nonliteral_dynamic_imports[0]
            self.assertEqual(
                violation.source_path,
                "TRR-Backend/trr_backend/socials/social_season_analytics_impl.py",
            )
            self.assertEqual(violation.callee, "__import__")
            self.assertEqual(violation.target_expression, "_provider_path")
            self.assertGreater(violation.line, 137)

    def test_baseline_policy_allows_decreases_and_rejects_increases(self) -> None:
        original = MODULE.BASELINE
        MODULE.BASELINE = {
            "backend": {
                "module_count": 1,
                "social_cycle_count": 2,
                "social_cyclic_module_count": 4,
                "legacy_social_import_count": 3,
                "legacy_social_importer_count": 2,
            },
            "app": {"module_count": 1, "cycle_count": 2, "cyclic_module_count": 4},
        }
        try:
            report = {
                "backend": {
                    "social_cycle_count": 1,
                    "social_cyclic_module_count": 3,
                    "legacy_social_import_count": 3,
                    "legacy_social_importer_count": 2,
                },
                "app": {"cycle_count": 1, "cyclic_module_count": 2},
            }
            self.assertEqual(MODULE.baseline_failures(report), [])
            report["app"]["cycle_count"] = 3
            self.assertIn(
                "app.cycle_count increased: current=3 baseline=2",
                MODULE.baseline_failures(report),
            )
        finally:
            MODULE.BASELINE = original

    def test_zero_policy_requires_all_backend_sccs_without_weakening_legacy_checks(
        self,
    ) -> None:
        report = {
            "backend": {
                "cycle_count": 1,
                "social_cycle_count": 0,
                "legacy_social_import_count": 1,
            },
            "app": {"cycle_count": 1},
        }

        self.assertEqual(
            MODULE.zero_failures(report),
            [
                "backend.cycle_count must be zero; current=1",
                "backend.legacy_social_import_count must be zero; current=1",
                "app.cycle_count must be zero; current=1",
            ],
        )

        report["backend"]["cycle_count"] = 0
        report["backend"]["legacy_social_import_count"] = 0
        report["app"]["cycle_count"] = 0
        self.assertEqual(MODULE.zero_failures(report), [])

    def test_frozen_policy_rejects_exact_source_and_graph_drift(self) -> None:
        original = MODULE.BASELINE
        MODULE.BASELINE = {
            "scope_version": MODULE.SCOPE_VERSION,
            "backend": {
                "module_count": 2,
                "edge_count": 1,
                "cycle_count": 0,
                "cyclic_module_count": 0,
                "social_cycle_count": 0,
                "social_cyclic_module_count": 0,
                "legacy_social_import_count": 0,
                "legacy_social_importer_count": 0,
                "source_sha256": "a" * 64,
                "graph_sha256": "b" * 64,
            },
            "app": {
                "module_count": 2,
                "edge_count": 1,
                "cycle_count": 0,
                "cyclic_module_count": 0,
                "source_sha256": "c" * 64,
                "graph_sha256": "d" * 64,
            },
        }
        report = {
            "backend": dict(MODULE.BASELINE["backend"]),
            "app": dict(MODULE.BASELINE["app"]),
        }
        try:
            self.assertEqual(MODULE.frozen_failures(report), [])
            report["backend"]["source_sha256"] = "e" * 64
            report["app"]["graph_sha256"] = "f" * 64
            failures = MODULE.frozen_failures(report)
            self.assertTrue(
                any("backend.source_sha256 drifted" in failure for failure in failures)
            )
            self.assertTrue(
                any("app.graph_sha256 drifted" in failure for failure in failures)
            )
        finally:
            MODULE.BASELINE = original


if __name__ == "__main__":
    unittest.main()
