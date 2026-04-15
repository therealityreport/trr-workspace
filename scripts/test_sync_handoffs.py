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

    def extract_section(self, rendered: str, heading: str, next_heading: str | None = None) -> str:
        marker = f"## {heading}\n"
        section = rendered.split(marker, 1)[1]
        if next_heading is not None:
            section = section.split(f"\n## {next_heading}\n", 1)[0]
        return section

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

    def test_missing_snapshot_error_mentions_source_and_required_heading(self) -> None:
        source = self.write_file(
            "docs/ai/local-status/example.md",
            """
            # Example

            Missing the required snapshot block.
            """,
        )

        with self.assertRaises(MODULE.InvalidSourceError) as ctx:
            MODULE.parse_source_file(source, MODULE.dt.date(2026, 3, 16))

        self.assertIn("docs/ai/local-status/example.md", str(ctx.exception))
        self.assertIn("missing '## Handoff Snapshot' section.", str(ctx.exception))

    def test_invalid_state_is_rejected(self) -> None:
        source = self.write_file(
            "docs/ai/local-status/example.md",
            """
            # Example

            ## Handoff Snapshot
            ```yaml
            handoff:
              include: true
              state: completed
              last_updated: 2026-03-16
              current_phase: "done"
              next_action: "monitor"
              detail: self
            ```
            """,
        )

        with self.assertRaises(MODULE.InvalidSourceError) as ctx:
            MODULE.parse_source_file(source, MODULE.dt.date(2026, 3, 16))

        self.assertIn("state must be one of active, archived, blocked, recent.", str(ctx.exception))

    def test_workspace_scope_renders_local_status_item(self) -> None:
        original_root = MODULE.ROOT
        MODULE.ROOT = self.root
        try:
            self.write_file(
                "docs/ai/local-status/workspace-closeout.md",
                """
                # Workspace Closeout

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: recent
                  last_updated: 2026-04-09
                  current_phase: "closeout validated"
                  next_action: "monitor future workspace-wide handoff sync runs"
                  detail: self
                ```
                """,
            )

            scope = MODULE.build_scopes(self.root)["workspace"]
            rendered = MODULE.render_scope(scope, MODULE.dt.date(2026, 4, 9))

            recent_completions = self.extract_section(rendered, "Recent Completions", "Older Plans")
            self.assertIn("Workspace Closeout", recent_completions)
            self.assertIn("docs/ai/local-status/workspace-closeout.md", recent_completions)
        finally:
            MODULE.ROOT = original_root

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

    def test_fresh_items_stay_in_primary_sections(self) -> None:
        original_root = MODULE.ROOT
        MODULE.ROOT = self.root
        try:
            self.write_file(
                "TRR-APP/docs/ai/local-status/fresh-active.md",
                """
                # Fresh Active

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: active
                  last_updated: 2026-03-18
                  current_phase: "in progress"
                  next_action: "continue"
                  detail: self
                ```
                """,
            )
            self.write_file(
                "TRR-APP/docs/ai/local-status/fresh-blocked.md",
                """
                # Fresh Blocked

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: blocked
                  last_updated: 2026-03-10
                  current_phase: "waiting"
                  next_action: "resume"
                  detail: self
                ```
                """,
            )
            self.write_file(
                "TRR-APP/docs/ai/local-status/fresh-recent.md",
                """
                # Fresh Recent

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: recent
                  last_updated: 2026-03-15
                  current_phase: "complete"
                  next_action: "monitor"
                  detail: self
                ```
                """,
            )

            scope = MODULE.build_scopes(self.root)["app"]
            rendered = MODULE.render_scope(scope, MODULE.dt.date(2026, 3, 20))
            self.assertIn("Fresh Active", self.extract_section(rendered, "Current Active Work", "Blocked / Waiting"))
            self.assertIn("Fresh Blocked", self.extract_section(rendered, "Blocked / Waiting", "Recent Completions"))
            self.assertIn("Fresh Recent", self.extract_section(rendered, "Recent Completions", "Older Plans"))
            self.assertNotIn("Fresh Active", self.extract_section(rendered, "Older Plans", "Archives / Canonical Links"))
            self.assertNotIn("Fresh Blocked", self.extract_section(rendered, "Older Plans", "Archives / Canonical Links"))
            self.assertNotIn("Fresh Recent", self.extract_section(rendered, "Older Plans", "Archives / Canonical Links"))
        finally:
            MODULE.ROOT = original_root

    def test_stale_items_render_in_older_plans(self) -> None:
        original_root = MODULE.ROOT
        MODULE.ROOT = self.root
        try:
            self.write_file(
                "TRR-APP/docs/ai/local-status/stale-active.md",
                """
                # Stale Active

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: active
                  last_updated: 2026-03-16
                  current_phase: "in progress"
                  next_action: "refresh"
                  detail: self
                ```
                """,
            )
            self.write_file(
                "TRR-APP/docs/ai/local-status/stale-blocked.md",
                """
                # Stale Blocked

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: blocked
                  last_updated: 2026-03-01
                  current_phase: "waiting"
                  next_action: "refresh"
                  detail: self
                ```
                """,
            )
            self.write_file(
                "TRR-APP/docs/ai/local-status/stale-recent.md",
                """
                # Stale Recent

                ## Handoff Snapshot
                ```yaml
                handoff:
                  include: true
                  state: recent
                  last_updated: 2026-03-10
                  current_phase: "complete"
                  next_action: "archive later"
                  detail: self
                ```
                """,
            )

            scope = MODULE.build_scopes(self.root)["app"]
            rendered = MODULE.render_scope(scope, MODULE.dt.date(2026, 3, 20))
            older_plans = self.extract_section(rendered, "Older Plans", "Archives / Canonical Links")

            self.assertIn("Stale Active", older_plans)
            self.assertIn("Stale Blocked", older_plans)
            self.assertIn("Stale Recent", older_plans)
            self.assertNotIn("Stale Active", self.extract_section(rendered, "Current Active Work", "Blocked / Waiting"))
            self.assertNotIn("Stale Blocked", self.extract_section(rendered, "Blocked / Waiting", "Recent Completions"))
            self.assertNotIn("Stale Recent", self.extract_section(rendered, "Recent Completions", "Older Plans"))
        finally:
            MODULE.ROOT = original_root

    def test_older_plans_are_capped_and_sorted(self) -> None:
        original_root = MODULE.ROOT
        MODULE.ROOT = self.root
        try:
            for index in range(1, 13):
                self.write_file(
                    f"TRR-APP/docs/ai/local-status/older-{index}.md",
                    f"""
                    # Older Item {index}

                    ## Handoff Snapshot
                    ```yaml
                    handoff:
                      include: true
                      state: recent
                      last_updated: 2026-03-{index:02d}
                      current_phase: "complete"
                      next_action: "leave in backlog"
                      detail: self
                    ```
                    """,
                )

            scope = MODULE.build_scopes(self.root)["app"]
            rendered = MODULE.render_scope(scope, MODULE.dt.date(2026, 3, 31))
            older_plans = self.extract_section(rendered, "Older Plans", "Archives / Canonical Links")

            self.assertIn("`Older Item 12`", older_plans)
            self.assertIn("`Older Item 3`", older_plans)
            self.assertNotIn("`Older Item 2`", older_plans)
            self.assertNotIn("`Older Item 1`", older_plans)
            self.assertLess(older_plans.index("`Older Item 12`"), older_plans.index("`Older Item 11`"))
        finally:
            MODULE.ROOT = original_root


if __name__ == "__main__":
    unittest.main()
