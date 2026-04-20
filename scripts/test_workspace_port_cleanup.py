from __future__ import annotations

import socket
import subprocess
import time
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "workspace-port-cleanup.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def test_safe_stale_listener_resolves_to_launcher_pid(tmp_path: Path) -> None:
    port = _free_port()
    launcher = subprocess.Popen(
        [
            "/bin/bash",
            "-lc",
            (
                f'cd "{tmp_path}" && '
                f'/bin/bash -lc \'cd "{tmp_path}" && python3.11 -m http.server {port} >/dev/null 2>&1\' & '
                'child_launcher=$!; '
                'printf "%s %s\\n" "$$" "$child_launcher"; '
                'wait'
            ),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        line = launcher.stdout.readline().strip()
        assert line
        launcher_pid, child_launcher_pid = line.split()

        listener_pid = ""
        for _ in range(30):
            probe = subprocess.run(
                ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-t"],
                capture_output=True,
                text=True,
                check=False,
            )
            pids = probe.stdout.split()
            if pids:
                listener_pid = pids[0]
                break
            time.sleep(0.1)
        else:
            raise AssertionError(
                f"listener never bound port {port}; child launcher pid={child_launcher_pid}"
            )

        result = _run_bash(
            f"""
        ROOT="{tmp_path}"
        HAVE_LSOF=1
        TRR_BACKEND_PORT="{port}"
        source "{SCRIPT_PATH}"
        printf '%s' "$(workspace_expand_cleanup_targets '{listener_pid}' '{port}')"
        """
        )

        assert result.returncode == 0, result.stderr
        assert result.stdout.strip() == child_launcher_pid
    finally:
        launcher.terminate()
        try:
            launcher.wait(timeout=5)
        except subprocess.TimeoutExpired:
            launcher.kill()
            launcher.wait(timeout=5)
