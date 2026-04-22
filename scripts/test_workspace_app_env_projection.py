#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEV_SCRIPT = ROOT / "scripts" / "dev-workspace.sh"
SOCIAL_DEBUG_PROFILE = ROOT / "profiles" / "social-debug.env"
ENV_CONTRACT_DOC = ROOT / "docs" / "workspace" / "env-contract.md"


class WorkspaceAppEnvProjectionTests(unittest.TestCase):
    def test_dev_workspace_declares_app_pool_projection_defaults(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn(
            'WORKSPACE_TRR_APP_POSTGRES_POOL_MAX="${WORKSPACE_TRR_APP_POSTGRES_POOL_MAX:-}"',
            text,
        )
        self.assertIn(
            'WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS="${WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS:-}"',
            text,
        )

    def test_dev_workspace_projects_app_pool_values_into_trr_app(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn(
            'POSTGRES_POOL_MAX=\\"${WORKSPACE_TRR_APP_POSTGRES_POOL_MAX:-${POSTGRES_POOL_MAX:-}}\\" \\',
            text,
        )
        self.assertIn(
            'POSTGRES_MAX_CONCURRENT_OPERATIONS=\\"${WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS:-${POSTGRES_MAX_CONCURRENT_OPERATIONS:-}}\\" \\',
            text,
        )

    def test_social_debug_profile_owns_low_pressure_app_pool_values(self) -> None:
        text = SOCIAL_DEBUG_PROFILE.read_text(encoding="utf-8")
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=2", text)
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=2", text)

    def test_generated_env_contract_mentions_app_pool_projection_vars(self) -> None:
        text = ENV_CONTRACT_DOC.read_text(encoding="utf-8")
        self.assertIn("| `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX` |", text)
        self.assertIn("| `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS` |", text)


if __name__ == "__main__":
    unittest.main()
