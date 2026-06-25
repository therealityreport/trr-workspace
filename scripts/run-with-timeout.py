#!/usr/bin/env python3
"""Run a command with a wall-clock timeout and preserve its combined output."""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
from collections.abc import Sequence


def _positive_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a positive integer") from exc
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return parsed


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout-seconds", type=_positive_int, required=True)
    parser.add_argument("--label", default="command")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("command is required")
    return args


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    process = subprocess.Popen(
        args.command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )
    try:
        stdout, _stderr = process.communicate(timeout=args.timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except Exception:
            process.kill()
        stdout, _stderr = process.communicate()
        output = stdout or exc.output or ""
        if isinstance(output, bytes):
            output = output.decode()
        sys.stdout.write(output)
        if output and not output.endswith("\n"):
            sys.stdout.write("\n")
        print(
            f"[run-with-timeout] ERROR: {args.label} timed out after {args.timeout_seconds}s.",
            file=sys.stderr,
        )
        print(
            "[run-with-timeout] Command: " + subprocess.list2cmdline(args.command),
            file=sys.stderr,
        )
        return 124

    sys.stdout.write(stdout or "")
    return int(process.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
