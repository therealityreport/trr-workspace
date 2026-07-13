from __future__ import annotations

import os
import shlex
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


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
            env.update(extra_env or {})
            return subprocess.run(
                [
                    "bash",
                    "-lc",
                    (
                        f"source {shlex.quote(str(PORTLESS_LIB))}; "
                        f"pgrep() {{ {shlex.quote(str(pgrep_script))} \"$@\"; }}; "
                        "portless() { "
                        f"if [[ \"$1\" == \"list\" ]]; then cat {shlex.quote(str(list_file))}; "
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
