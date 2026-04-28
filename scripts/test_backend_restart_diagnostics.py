from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIB_PATH = ROOT / "scripts" / "lib" / "backend-restart-diagnostics.sh"
DEV_WORKSPACE_PATH = ROOT / "scripts" / "dev-workspace.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_restart_event_json_records_exit_attribution() -> None:
    result = _run_bash(
        f"""
        source "{LIB_PATH}"
        backend_restart_event_json \\
          "2026-04-28T12:00:00Z" \\
          "restart" \\
          "process_exit" \\
          "0" \\
          "3" \\
          "exited_pid=123;started_at=2026-04-28T11:59:00Z" \\
          "44" \\
          "123" \\
          "123" \\
          "Python:123" \\
          "observed_process_exit" \\
          "143" \\
          "15"
        """
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["event"] == "restart"
    assert payload["reason"] == "process_exit"
    assert payload["manager_pid"] == "44"
    assert payload["backend_pid"] == "123"
    assert payload["backend_pgid"] == "123"
    assert payload["killer_path"] == "observed_process_exit"
    assert payload["exit_status"] == "143"
    assert payload["exit_signal"] == "15"


def test_health_probe_restart_event_keeps_distinct_reason() -> None:
    result = _run_bash(
        f"""
        source "{LIB_PATH}"
        backend_restart_event_json \\
          "2026-04-28T12:01:00Z" \\
          "restart" \\
          "health_probe_failure" \\
          "7" \\
          "4" \\
          "failures=6;busy_timeout_streak=0" \\
          "44" \\
          "456" \\
          "456" \\
          "" \\
          "watchdog_health_probe_failure" \\
          "" \\
          ""
        """
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["reason"] == "health_probe_failure"
    assert payload["probe_rc"] == "7"
    assert payload["killer_path"] == "watchdog_health_probe_failure"
    assert payload["exit_status"] == ""


def test_backend_log_segment_archive_prunes_to_keep_count(tmp_path: Path) -> None:
    log_path = tmp_path / "trr-backend.log"
    segment_dir = tmp_path / "segments"
    log_path.write_text("old line\nstart line\nnext line\n", encoding="utf-8")

    result = _run_bash(
        f"""
        source "{LIB_PATH}"
        backend_restart_archive_segment "{log_path}" "{segment_dir}" "111" "process_exit" "20260428T120000Z" 2 2 >/dev/null
        backend_restart_archive_segment "{log_path}" "{segment_dir}" "222" "health_probe_failure" "20260428T120001Z" 2 2 >/dev/null
        backend_restart_archive_segment "{log_path}" "{segment_dir}" "333" "process_exit" "20260428T120002Z" 2 2 >/dev/null
        find "{segment_dir}" -type f -name '*.log' -print | sort
        """
    )

    assert result.returncode == 0, result.stderr
    paths = [Path(line) for line in result.stdout.splitlines() if line.endswith(".log")]
    remaining = [path for path in paths if path.exists()]
    assert len(remaining) == 2
    assert all(path.read_text(encoding="utf-8") == "start line\nnext line\n" for path in remaining)


def test_dev_workspace_classifies_intentional_backend_stop_as_signal_not_restart() -> None:
    script = DEV_WORKSPACE_PATH.read_text(encoding="utf-8")
    assert 'stop_bg "${NAMES[$idx]-SERVICE_$idx}" "${PIDS[$idx]-}" "workspace_cleanup"' in script
    assert 'record_backend_signal_event "$pid" "TERM" "$killer_path"' in script
    assert 'record_backend_restart "process_exit"' not in script
    assert '"observed_process_exit"' in script
