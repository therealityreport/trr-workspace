#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import workspace_runtime_reconcile as cli


if __name__ == "__main__":
    raise SystemExit(cli.main())
