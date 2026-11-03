"""Remove only dead static aliases for the shared TRR web/API service."""
from __future__ import annotations

import re
import socket
import subprocess

NAMES = frozenset(('trr', 'admin.trr', 'api.trr'))
PATTERN = re.compile(r'https://([a-z0-9.-]+)\.localhost\s+->\s+localhost:(\d+)\s+\(alias\)')


def aliases(run=subprocess.check_output):
    output = run(['portless', 'list'], text=True, timeout=10)
    return {name: int(port) for name, port in PATTERN.findall(output) if name in NAMES}


def listening(port):
    for host in ('127.0.0.1', '::1'):
        try:
            with socket.create_connection((host, port), timeout=0.3):
                return True
        except ConnectionRefusedError:
            continue
        except OSError:
            # A timeout or unknown network error does not prove an unused port.
            return True
    return False


def repair(read=aliases, active=listening, run=subprocess.run):
    removed = []
    for name, port in read().items():
        if active(port) or read().get(name) != port or active(port):
            continue
        run(['portless', 'alias', '--remove', name], check=True, timeout=10,
            stdout=subprocess.DEVNULL)
        removed.append(name)
    return removed


if __name__ == '__main__':
    for name in repair():
        print(f'[portless-repair] Removed dead static alias: {name}')
