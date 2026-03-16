#!/usr/bin/env python3
"""Focused tests for scripts/sync-handoffs.py."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().with_name("sync-handoffs.py")
SPEC = importlib.util.spec_from_file_location("sync_handoffs", SCRIPT_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class SyncHandoffsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)

    def tearDown(self) -> None:
        self.tmpdir.cleanup()

    def write_file(self, relative_path: str, content: str) -> Path:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(content).strip() + "\n", encoding="utf-8")
        return path

    def test_parse_valid_snapshot(self) -> None:
        source = self.write_file(
            "TRR-Backend/docs/cross-collab/TASK12/STATUS.md",
            """
            # Status — Task 12 (Cast Screen-Time Analytics)

            ## Handoff Snapshot
            ```yaml
            handoff:
              include: true
              state: active
              last_updated: 2026-03-16
              current_phase: "operator evidence"
              next_action: "capture full-episode proof"
              detail: self
            ```
            """,
        )

        item = MODULE.parse_source_file(source, MODULE.dt.date(2026, 3, 16))
        self.assertIsNotNone(item)
        assert item is not None
        self.assertEqual(item.title, "TASK12 Cast Screen-Time Analytics")
        self.assertEqual(item.snapshot.state, "active")
        self.assertEqual(item.snapshot.detail, "self")

    def test_missing_snapshot_is_rejected(self) -> None:
        source = self.write_file(
            "docs/ai/local-status/example.md",
            """
            # Example

            Missing the required snapshot block.
            """,
        )

        with self.assertRaises(MODULE.InvalidSourceError):
            MODULE.parse_source_file(source, MODULE.dt.date(2026, 3, 16))

    def test_invalid_detail_path_is_rejected(self) -> None:
        source = self.write_file(
            "docs/ai/local-status/example.md",
            """
            # Example

            ## Handoff Snapshot
            ```yaml
            handoff:
              include: true
              state: recent
              last_updated: 2026-03-16
              current_phase: "done"
              next_action: "monitor"
              detail: "../missing.md"
            ```
            """,
        )

        original_root = MODULE.ROOT
        MODULE.ROOT = self.root
        try:
            with self.assertRaises(MODULE.InvalidSourceError):
                MODULE.parse_source_file(source, MODULE.dt.date(2026, 3, 16))
        finally:
            MODULE.ROOT = original_root

    def test_recent_items_are_capped_and_sorted(self) -> None:
        original_root = MODULE.ROOT
        MODULE.ROOT = self.root
        try:
            for index in range(1, 8):
                self.write_file(
                    f"TRR-APP/docs/ai/local-status/item-{index}.md",
                    f"""
                    # Local Item {index}

                    ## Handoff Snapshot
                    ```yaml
                    handoff:
                      include: true
                      state: recent
                      last_updated: 2026-03-{13 + index:02d}
                      current_phase: "complete"
                      next_action: "monitor"
                      detail: self
                    ```
                    """,
                )

            scope = MODULE.build_scopes(self.root)["app"]
            rendered = MODULE.render_scope(scope, MODULE.dt.date(2026, 3, 20))
            self.assertIn("Local Item 7", rendered)
            self.assertIn("Local Item 3", rendered)
            self.assertNotIn("Local Item 2", rendered)
            self.assertNotIn("Local Item 1", rendered)
        finally:
            MODULE.ROOT = original_root

    def test_freshness_failure_raises(self) -> None:
        source = self.write_file(
            "screenalytics/docs/cross-collab/TASK8/STATUS.md",
            """
            # Status — Task 8 (Cast Screen-Time Analytics)

            ## Handoff Snapshot
            ```yaml
            handoff:
              include: true
              state: blocked
              last_updated: 2026-02-01
              current_phase: "waiting"
              next_action: "refresh"
              detail: self
            ```
            """,
        )

        with self.assertRaises(MODULE.FreshnessError):
            MODULE.parse_source_file(source, MODULE.dt.date(2026, 3, 16))


if __name__ == "__main__":
    unittest.main()
