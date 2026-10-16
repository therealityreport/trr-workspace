from __future__ import annotations

from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("project_manager_router_ready", ROOT / "scripts/project-manager-router-ready.py")
assert SPEC and SPEC.loader
router = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(router)


class ProjectManagerRouterReadyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.state = self.home / ".portless"
        self.state.mkdir()
        self.manifest_path = self.home / "release-manifest.json"
        self.health_path = self.home / router.HEALTH_SUFFIX
        self.health_path.parent.mkdir(parents=True)
        self.manifest = {
            "schemaVersion": "project-manager.portless-router.release/v1",
            "mode": "production", "identity": {"uid": os.getuid()},
            "routing": {"strict": False, "tlds": ["localhost"]},
            "sockets": {"https": {"port": 443}, "http": {"port": 80}},
            "state": {"directory": str(self.state), "routes": str(self.state / "routes.json"), "caCertificate": str(self.state / "ca.pem")},
            "runtime": {"node": {"path": "/installed/node"}, "adapter": {"path": "/installed/Project Manager/scripts/portless-router.mjs"}},
        }
        self.observed = datetime.now(timezone.utc)
        self.health = {"schemaVersion": "project-manager.portless-router.health/v1", "component": "adapter", "state": "ready", "pid": 123, "observedAt": self.observed.isoformat()}
        self.routes = [{"hostname": "thb.localhost", "port": 4746, "pid": 71272}, {"hostname": "admin.thb.localhost", "port": 4746, "pid": 0}]
        for name, value in {"proxy.pid": "123", "proxy.port": "443", "proxy.tls": "1", "proxy.tld": "localhost", "proxy.tlds": '["localhost"]'}.items():
            (self.state / name).write_text(value)
        self.process = Mock(side_effect=self._process)
        self.tls = Mock(return_value=True)
        self.write()

    def write(self) -> None:
        self.manifest_path.write_text(json.dumps(self.manifest))
        os.utime(self.manifest_path, (self.observed.timestamp() - 10,) * 2)
        self.health_path.write_text(json.dumps(self.health))
        (self.state / "routes.json").write_text(json.dumps(self.routes))

    def _process(self, *_args, **_kwargs):
        started = (self.observed - timedelta(seconds=20)).astimezone().strftime("%a %b %d %H:%M:%S %Y")
        command = f'/installed/node /installed/Project Manager/scripts/portless-router.mjs --manifest {self.manifest_path}'
        return SimpleNamespace(returncode=0, stdout=f"{os.getuid()} {started} {command}\n")

    def verify(self) -> None:
        router.verify_router(self.manifest_path, home=self.home, process_runner=self.process, tls_probe=self.tls)

    def test_live_compatible_managed_router_preserves_existing_thb_routes(self) -> None:
        self.verify()
        self.process.assert_called_once()
        self.tls.assert_called_once_with(self.state / "ca.pem")
        self.assertEqual(json.loads((self.state / "routes.json").read_text()), self.routes)

    def test_static_manifest_without_matching_runtime_markers_is_rejected(self) -> None:
        (self.state / "proxy.pid").unlink()
        with self.assertRaises(OSError):
            self.verify()
        self.process.assert_not_called()
        self.tls.assert_not_called()

    def test_bad_manifest_and_health_conditions_fail_before_network(self) -> None:
        cases = [
            ("strict", lambda: self.manifest["routing"].update(strict=True)),
            ("other_tld", lambda: self.manifest["routing"].update(tlds=["test"])),
            ("other_port", lambda: self.manifest["sockets"]["https"].update(port=8443)),
            ("not_ready", lambda: self.health.update(state="failed")),
            ("wrong_owner", lambda: self.manifest["identity"].update(uid=os.getuid() + 1)),
            ("old_pid", lambda: self.health.update(pid=999)),
        ]
        for name, mutate in cases:
            with self.subTest(name=name):
                self.setUp()
                mutate(); self.write()
                with self.assertRaises(router.RouterNotReady):
                    self.verify()
                self.tls.assert_not_called()

    def test_malformed_manifest_or_receipt_is_rejected_without_a_network_request(self) -> None:
        self.manifest_path.write_text("[]")
        with self.assertRaises(router.RouterNotReady):
            self.verify()
        self.tls.assert_not_called()

    def test_new_manifest_requires_a_new_ready_receipt(self) -> None:
        os.utime(self.manifest_path, (self.observed.timestamp() + 10,) * 2)
        with self.assertRaises(router.RouterNotReady):
            self.verify()
        self.tls.assert_not_called()

    def test_wrong_or_reused_process_cannot_supply_readiness(self) -> None:
        self.process.side_effect = None
        self.process.return_value = SimpleNamespace(returncode=0, stdout=f"{os.getuid()} Tue Oct 13 10:00:00 2026 another-command")
        with self.assertRaises(router.RouterNotReady):
            self.verify()
        self.tls.assert_not_called()

    def test_receipt_must_belong_to_current_process_start(self) -> None:
        self.process.side_effect = None
        started = (self.observed + timedelta(seconds=20)).astimezone().strftime("%a %b %d %H:%M:%S %Y")
        self.process.return_value = SimpleNamespace(returncode=0, stdout=f"{os.getuid()} {started} /installed/node /installed/Project Manager/scripts/portless-router.mjs --manifest {self.manifest_path}")
        with self.assertRaises(router.RouterNotReady):
            self.verify()
        self.tls.assert_not_called()

    def test_conflicting_or_invalid_routes_are_rejected(self) -> None:
        for entry in [
            {"hostname": "admin.trr.localhost", "port": 3000, "pid": 123},
            {"hostname": "trr.localhost:7443", "port": 3000, "pid": 123},
            {"hostname": "trr.localhost", "port": 0, "pid": 123},
            {"hostname": "thb.localhost", "port": 4747, "pid": 123},
        ]:
            with self.subTest(entry=entry):
                self.routes = [{"hostname": "thb.localhost", "port": 4746, "pid": 71272}, entry]
                self.write()
                with self.assertRaises(router.RouterNotReady):
                    self.verify()
                self.tls.assert_not_called()

    def test_unresponsive_router_is_rejected_despite_ready_receipt(self) -> None:
        self.tls.return_value = False
        with self.assertRaises(router.RouterNotReady):
            self.verify()

    def test_tls_probe_is_bounded_verified_and_cannot_reach_an_app(self) -> None:
        connection = Mock()
        connection.getresponse.return_value = SimpleNamespace(status=404, getheader=lambda name: "1" if name == "X-Portless" else None)
        with patch.object(router.ssl, "create_default_context", return_value="verified-context") as context, patch.object(router.http.client, "HTTPSConnection", return_value=connection) as https:
            self.assertTrue(router._trusted_tls_probe(self.state / "ca.pem"))
        context.assert_called_once_with(cafile=str(self.state / "ca.pem"))
        https.assert_called_once_with("localhost", 443, timeout=2, context="verified-context")
        connection.request.assert_called_once_with("HEAD", "/", headers={"Host": "trr-router-readiness.invalid"})
        connection.close.assert_called_once()

    def test_installed_owner_remains_present_when_manifest_is_invalid_or_unready(self) -> None:
        self.manifest_path.write_text("invalid manifest")
        self.assertTrue(router.managed_owner_present(self.manifest_path, service_path=self.home / "missing.plist", process_runner=self.process))
        self.process.assert_not_called()

    def test_launchd_registration_preserves_ownership_without_a_manifest(self) -> None:
        self.manifest_path.unlink()
        service = self.home / "router.plist"
        service.write_text("installed managed service")
        self.assertTrue(router.managed_owner_present(self.manifest_path, service_path=service, process_runner=self.process))
        self.process.assert_not_called()

    def test_live_managed_adapter_preserves_ownership_without_installed_metadata(self) -> None:
        self.manifest_path.unlink()
        release = str(router.MANIFEST.parent / "releases" / ("a" * 64))
        self.process.side_effect = None
        self.process.return_value = SimpleNamespace(returncode=0, stdout=f"{release}/node/bin/node {release}/scripts/portless-router.mjs --manifest {self.manifest_path}\n")
        self.assertTrue(router.managed_owner_present(self.manifest_path, service_path=self.home / "missing.plist", process_runner=self.process))
        self.process.return_value = SimpleNamespace(returncode=0, stdout="another process")
        self.assertFalse(router.managed_owner_present(self.manifest_path, service_path=self.home / "missing.plist", process_runner=self.process))

    def test_unknown_process_inventory_holds_generic_startup(self) -> None:
        self.manifest_path.unlink()
        self.process.side_effect = OSError("process inventory unavailable")
        self.assertTrue(router.managed_owner_present(self.manifest_path, service_path=self.home / "missing.plist", process_runner=self.process))

    def test_owner_entrypoint_never_runs_the_tls_readiness_probe(self) -> None:
        with patch.object(router, "managed_owner_present", return_value=True), patch.object(router, "verify_router") as ready:
            self.assertEqual(router.main(["--owner-present"]), 0)
            ready.assert_not_called()

    def test_entrypoint_fails_closed_on_io_or_malformed_state(self) -> None:
        for failure in (OSError("unavailable"), ValueError("invalid json"), router.RouterNotReady("not ready")):
            with self.subTest(failure=type(failure).__name__), patch.object(router, "verify_router", side_effect=failure):
                self.assertEqual(router.main([]), 1)


if __name__ == "__main__":
    unittest.main()
