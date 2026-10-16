from __future__ import annotations

import os
import shlex
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
PORTLESS_LIB = ROOT / "scripts/lib/portless-startup-check.sh"


class PortlessStartupCheckTests(unittest.TestCase):
    def _run_check(
        self,
        command: str,
        *,
        pgrep_output: str = "",
        pgrep_exit: int = 1,
        portless_list_output: str = "",
        extra_env: dict[str, str] | None = None,
        managed_router_ready: bool = False,
        managed_owner_present: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp)
            list_file = bin_dir / "portless-list.txt"
            list_file.write_text(portless_list_output, encoding="utf-8")
            pgrep_script = bin_dir / "pgrep"
            pgrep_script.write_text(
                "#!/usr/bin/env bash\n"
                f"printf '%s' {pgrep_output!r}\n"
                f"exit {pgrep_exit}\n",
                encoding="utf-8",
            )
            portless_script = bin_dir / "portless"
            portless_script.write_text(
                "#!/usr/bin/env bash\n"
                "if [[ \"$1\" == \"list\" ]]; then\n"
                f"  printf '%s' {portless_list_output!r}\n"
                "  exit 0\n"
                "fi\n"
                "exit 0\n",
                encoding="utf-8",
            )
            for path in (pgrep_script, portless_script):
                path.chmod(path.stat().st_mode | stat.S_IXUSR)

            env = {
                **os.environ,
                "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
                "CODEX_CI": "1",
            }
            env.pop("TRR_PORTLESS_ALLOW_PROXY_START", None)
            env.pop("PORTLESS_PORT", None)
            env.update(extra_env or {})
            return subprocess.run(
                [
                    "bash",
                    "-lc",
                    (
                        f"source {shlex.quote(str(PORTLESS_LIB))}; "
                        f"trr_portless_project_manager_router_ready() {{ return {0 if managed_router_ready else 1}; }}; "
                        f"trr_portless_project_manager_owner_present() {{ return {0 if managed_owner_present else 1}; }}; "
                        f"pgrep() {{ {shlex.quote(str(pgrep_script))} \"$@\"; }}; "
                        "portless() { "
                        f"if [[ \"$1\" == \"list\" ]]; then cat {shlex.quote(str(list_file))}; "
                        "elif [[ \"$1\" == proxy ]]; then printf PROXY_COMMAND_WAS_CALLED; return 99; "
                        "else return 0; fi; }; "
                        f"{command}"
                    ),
                ],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

    def test_noninteractive_missing_proxy_fails_before_sudo_prompt(self) -> None:
        result = self._run_check('trr_portless_require_proxy_start_allowed "workspace" "$PWD"')

        self.assertEqual(result.returncode, 2)
        self.assertIn("Portless wildcard proxy is not running", result.stderr)
        self.assertIn("https://admin.trr.localhost", result.stderr)
        self.assertIn("make portless-status", result.stderr)
        self.assertIn("TRR_PORTLESS_ALLOW_PROXY_START=1 make dev-hybrid", result.stderr)
        self.assertIn("rerun the command that failed", result.stderr)
        self.assertNotIn("Browser test", result.stderr)

    def test_host_proxy_start_and_port_overrides_do_not_leak_into_subprocess(self) -> None:
        with patch.dict(
            os.environ,
            {"TRR_PORTLESS_ALLOW_PROXY_START": "1", "PORTLESS_PORT": "7443"},
        ):
            result = self._run_check('trr_portless_require_proxy_start_allowed "workspace" "$PWD"')

        self.assertEqual(result.returncode, 2)
        self.assertIn("Portless wildcard proxy is not running", result.stderr)
        self.assertNotIn("TRR_PORTLESS_ALLOW_PROXY_START=1 was set", result.stderr)
        self.assertNotIn("explicit numeric port", result.stderr)

    def test_noninteractive_allow_proxy_start_requires_passwordless_sudo(self) -> None:
        result = self._run_check(
            (
                "sudo() { return 1; }; "
                'trr_portless_require_proxy_start_allowed "workspace" "$PWD"'
            ),
            extra_env={"TRR_PORTLESS_ALLOW_PROXY_START": "1"},
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("TRR_PORTLESS_ALLOW_PROXY_START=1 was set", result.stderr)
        self.assertIn("cannot satisfy Portless sudo", result.stderr)
        self.assertIn("make portless-repair", result.stderr)

    def test_portless_service_on_clean_https_port_is_allowed(self) -> None:
        result = self._run_check(
            'trr_portless_require_proxy_start_allowed "workspace" "$PWD"',
            pgrep_output=(
                "44503 /Users/thomashulihan/.nvm/versions/node/v22.18.0/bin/node "
                "/opt/homebrew/bin/portless proxy start --foreground --port 443 --https --wildcard --skip-trust\n"
            ),
            pgrep_exit=0,
        )

        self.assertEqual(result.returncode, 0)

    def test_managed_router_can_satisfy_startup_without_sudo_or_legacy_process(self) -> None:
        result = self._run_check(
            'sudo() { return 99; }; trr_portless_require_proxy_start_allowed "workspace" "$PWD"',
            managed_router_ready=True,
        )
        self.assertEqual(result.returncode, 0)

    def test_unready_managed_owner_blocks_interactive_generic_start(self) -> None:
        result = self._run_check(
            'trr_portless_agent_noninteractive() { return 1; }; '
            'if trr_portless_require_proxy_start_allowed "workspace" "$PWD"; then portless proxy start --wildcard; else exit $?; fi',
            managed_owner_present=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Project Manager owns the shared Portless router", result.stderr)
        self.assertIn("sudo launchctl kickstart -k system/local.thomashulihan.projectmanager.portless-router", result.stderr)
        self.assertNotIn("PROXY_COMMAND_WAS_CALLED", result.stdout)

    def test_unready_managed_owner_blocks_opt_in_even_with_passwordless_sudo(self) -> None:
        result = self._run_check(
            'sudo() { return 0; }; '
            'if trr_portless_require_proxy_start_allowed "workspace" "$PWD"; then portless proxy start --wildcard; else exit $?; fi',
            managed_owner_present=True,
            extra_env={"TRR_PORTLESS_ALLOW_PROXY_START": "1"},
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("A generic proxy will not replace the managed service", result.stderr)
        self.assertNotIn("PROXY_COMMAND_WAS_CALLED", result.stdout)

    def test_managed_router_still_requires_compatible_browser_routes(self) -> None:
        result = self._run_check(
            'trr_portless_require_browser_routes "browser-smoke" "$PWD"',
            managed_router_ready=True,
            portless_list_output="https://trr.localhost -> localhost:3000\nhttps://api.trr.localhost -> localhost:8000\n",
        )
        self.assertEqual(result.returncode, 0)
        conflict = self._run_check(
            'trr_portless_require_browser_routes "browser-smoke" "$PWD"',
            managed_router_ready=True,
            portless_list_output="https://trr.localhost -> localhost:3000\nhttps://api.trr.localhost -> localhost:8000\nhttps://admin.trr.localhost -> localhost:3000\n",
        )
        self.assertEqual(conflict.returncode, 2)
        self.assertIn("registered as its own Portless route", conflict.stderr)

    def test_repair_does_not_start_proxy_when_managed_router_is_ready(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls = Path(tmp) / "calls.txt"
            script = (
                "pgrep() { return 1; }; "
                "python3() { [[ \"$1\" == *project-manager-router-ready.py ]]; }; "
                "portless() { "
                f"printf '%s\\n' \"$*\" >> {shlex.quote(str(calls))}; "
                "if [[ \"$1\" == list ]]; then printf '%s\\n' 'https://thb.localhost -> localhost:4746'; return 0; fi; "
                "if [[ \"$1\" == alias ]]; then return 1; fi; return 99; }; "
                "export -f pgrep python3 portless; "
                f"PORTLESS_SYNC_HOSTS=0 PORTLESS_REPAIR_ALLOW_NO_ACTIVE_ROUTES=1 bash {shlex.quote(str(ROOT / 'scripts/portless-repair.sh'))}"
            )
            result = subprocess.run(["bash", "-c", script], cwd=ROOT, env={**os.environ, "CODEX_CI": "1"}, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("already running in wildcard mode", result.stdout)
            self.assertNotIn("proxy start", calls.read_text())
            self.assertNotIn("proxy stop", calls.read_text())

    def test_repair_rechecks_readiness_after_helper_observes_restoration(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls = Path(tmp) / "calls.txt"
            probes = Path(tmp) / "probes.txt"
            script = (
                "pgrep() { return 1; }; "
                "python3() { "
                "if [[ \"${2:-}\" == --owner-present ]]; then return 0; fi; "
                f"local count=0; [[ ! -f {shlex.quote(str(probes))} ]] || read -r count < {shlex.quote(str(probes))}; "
                f"count=$((count + 1)); printf '%s\\n' \"$count\" > {shlex.quote(str(probes))}; "
                "[[ \"$count\" -ge 2 ]]; }; "
                "portless() { "
                f"printf '%s\\n' \"$*\" >> {shlex.quote(str(calls))}; "
                "if [[ \"$1\" == list ]]; then printf '%s\\n' 'https://thb.localhost -> localhost:4746'; return 0; fi; "
                "if [[ \"$1\" == alias ]]; then return 1; fi; return 99; }; "
                "export -f pgrep python3 portless; "
                f"PORTLESS_SYNC_HOSTS=0 PORTLESS_REPAIR_ALLOW_NO_ACTIVE_ROUTES=1 bash {shlex.quote(str(ROOT / 'scripts/portless-repair.sh'))}"
            )
            result = subprocess.run(["bash", "-c", script], cwd=ROOT, env={**os.environ, "CODEX_CI": "1"}, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("became ready; keeping the existing owner", result.stdout)
            self.assertGreaterEqual(int(probes.read_text()), 3)
            self.assertNotIn("proxy start", calls.read_text())
            self.assertNotIn("proxy stop", calls.read_text())

    def test_numbered_proxy_port_is_rejected(self) -> None:
        result = self._run_check(
            'trr_portless_require_proxy_start_allowed "workspace" "$PWD"',
            pgrep_output="123 /opt/homebrew/bin/portless proxy start --foreground --port 8443 --https --wildcard\n",
            pgrep_exit=0,
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("explicit numeric port", result.stderr)

    def test_browser_route_check_requires_clean_app_and_api_routes(self) -> None:
        result = self._run_check(
            (
                'trr_portless_proxy_lines() { printf ""; }; '
                "trr_portless_has_wildcard_proxy() { return 0; }; "
                'trr_portless_require_browser_routes "browser-smoke" "$PWD"'
            ),
            pgrep_output="123 portless proxy start --wildcard\n",
            pgrep_exit=0,
            portless_list_output="No active routes.\n",
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("no active trr.localhost Portless app route is running", result.stderr)
        self.assertIn("make dev-hybrid", result.stderr)

    def test_browser_route_check_accepts_wildcard_admin_routing(self) -> None:
        routes = textwrap.dedent(
            """
            Active routes:

              https://api.trr.localhost  ->  localhost:8000  (pid 123)
              https://trr.localhost  ->  localhost:3000  (pid 124)
            """
        )
        result = self._run_check(
            (
                'trr_portless_proxy_lines() { printf ""; }; '
                "trr_portless_has_wildcard_proxy() { return 0; }; "
                'trr_portless_require_browser_routes "browser-smoke" "$PWD"'
            ),
            pgrep_output="123 portless proxy start --wildcard\n",
            pgrep_exit=0,
            portless_list_output=routes,
        )

        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
