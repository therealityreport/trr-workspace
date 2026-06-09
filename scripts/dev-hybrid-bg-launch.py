#!/usr/bin/env python3
"""Launch make dev-hybrid as a detached workspace process."""

from __future__ import annotations

import argparse
import os
import signal
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-file", required=True, type=Path)
    parser.add_argument("--pid-file", required=True, type=Path)
    parser.add_argument("--cwd", required=True, type=Path)
    return parser.parse_args()


def _write_pipe_message(fd: int, message: str) -> None:
    os.write(fd, message.encode("utf-8", errors="replace"))
    os.close(fd)


def launch_detached(*, log_file: Path, pid_file: Path, cwd: Path) -> int:
    log_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file.parent.mkdir(parents=True, exist_ok=True)

    read_fd, write_fd = os.pipe()
    supervisor_pid = os.fork()
    if supervisor_pid:
        os.close(write_fd)
        chunks: list[bytes] = []
        while True:
            chunk = os.read(read_fd, 4096)
            if not chunk:
                break
            chunks.append(chunk)
        os.close(read_fd)
        _, status = os.waitpid(supervisor_pid, 0)
        message = b"".join(chunks).decode("utf-8", errors="replace").strip()
        if os.WIFEXITED(status) and os.WEXITSTATUS(status) == 0 and message.startswith("pid="):
            return int(message.removeprefix("pid=").strip())
        raise RuntimeError(message or f"background launcher failed with status {status}")

    os.close(read_fd)
    try:
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        os.setsid()
        daemon_pid = os.fork()
        if daemon_pid:
            pid_file.write_text(f"{daemon_pid}\n", encoding="utf-8")
            _write_pipe_message(write_fd, f"pid={daemon_pid}\n")
            os._exit(0)

        try:
            signal.signal(signal.SIGHUP, signal.SIG_IGN)
            os.chdir(cwd)
            stdin_fd = os.open(os.devnull, os.O_RDONLY)
            log_fd = os.open(log_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
            os.dup2(stdin_fd, 0)
            os.dup2(log_fd, 1)
            os.dup2(log_fd, 2)
            os.close(stdin_fd)
            os.close(log_fd)
            os.execvp("make", ["make", "--no-print-directory", "dev-hybrid"])
        except BaseException as exc:  # noqa: BLE001
            print(f"[workspace] failed to exec make dev-hybrid: {type(exc).__name__}: {exc}", file=sys.stderr)
            os._exit(127)
    except BaseException as exc:  # noqa: BLE001
        _write_pipe_message(write_fd, f"error={type(exc).__name__}: {exc}\n")
        os._exit(1)


def main() -> int:
    args = parse_args()
    pid = launch_detached(log_file=args.log_file, pid_file=args.pid_file, cwd=args.cwd)
    print(pid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
