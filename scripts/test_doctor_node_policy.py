from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DoctorNodePolicyTests(unittest.TestCase):
    def test_unsupported_node_reports_required_and_preview_lanes_without_provider_work(self) -> None:
        with tempfile.TemporaryDirectory(prefix="trr-doctor-node-policy-") as directory:
            root = Path(directory)
            scripts = root / "scripts"
            libraries = scripts / "lib"
            libraries.mkdir(parents=True)
            shutil.copyfile(ROOT / "scripts/doctor.sh", scripts / "doctor.sh")
            for name in ("mcp-runtime.sh", "chrome-devtools-status.sh", "context7-status.sh", "doctor-plugin-registry.sh"):
                (libraries / name).write_text("# Fixture: provider and plugin work unavailable.\n", encoding="utf-8")
            (libraries / "node-baseline.sh").write_text(
                "trr_node_required_major() { echo 24; }\n"
                "trr_node_major_version() { echo 22; }\n"
                "trr_node_version_string() { echo v22.23.2; }\n"
                "trr_try_activate_required_node_with_nvm() { return 1; }\n",
                encoding="utf-8",
            )
            fake_bin = root / "bin"
            fake_bin.mkdir()
            for name in ("node", "npm", "pnpm"):
                command = fake_bin / name
                command.write_text("#!/bin/sh\necho unexpected-external-command >&2\nexit 99\n", encoding="utf-8")
                command.chmod(0o755)
            fake_python = fake_bin / "fixture-python"
            fake_python.write_text("#!/bin/sh\nprintf '3 11\\n'\n", encoding="utf-8")
            fake_python.chmod(0o755)
            result = subprocess.run(
                ["bash", str(scripts / "doctor.sh")],
                cwd=root,
                env={**os.environ, "PATH": f"{fake_bin}:{os.environ['PATH']}", "PYTHON_BIN": str(fake_python)},
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("TRR-APP requires Node 24.x; Node 26 is a non-blocking CI preview.", result.stderr)
            self.assertNotIn("Node 22 compatibility lane", result.stderr)
            self.assertNotIn("unexpected-external-command", result.stderr)
            self.assertIn("nvm use 24", result.stderr)


if __name__ == "__main__":
    unittest.main()
