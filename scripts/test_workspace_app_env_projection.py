#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEV_SCRIPT = ROOT / "scripts" / "dev-workspace.sh"
STATUS_SCRIPT = ROOT / "scripts" / "status-workspace.sh"
SOCIAL_DEBUG_PROFILE = ROOT / "profiles" / "social-debug.env"
LOCAL_CLOUD_PROFILE = ROOT / "profiles" / "local-cloud.env"
ENV_CONTRACT_DOC = ROOT / "docs" / "workspace" / "env-contract.md"
DEFAULT_PROFILE = ROOT / "profiles" / "default.env"


class WorkspaceAppEnvProjectionTests(unittest.TestCase):
    def run_workspace_helper(self, helper_call: str, env_overrides: dict[str, str]) -> str:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        start = text.index("workspace_selected_db_lane() {")
        end = text.index("\nruntime_reconcile_artifact_path() {", start)
        helper_block = text[start:end]
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            **env_overrides,
        }
        result = subprocess.run(
            ["bash", "-c", f"set -euo pipefail\n{helper_block}\n{helper_call}\n"],
            check=True,
            env=env,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()

    def run_workspace_db_holder_budget(self, env_overrides: dict[str, str]) -> str:
        return self.run_workspace_helper("workspace_effective_db_holder_budget", env_overrides)

    def read_profile_env(self, profile_path: Path) -> dict[str, str]:
        values: dict[str, str] = {}
        for raw_line in profile_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            key, separator, value = line.partition("=")
            if separator:
                values[key] = value
        return values

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
            'trr_app_postgres_pool_max="$(workspace_projected_app_postgres_pool_max)"',
            text,
        )
        self.assertIn(
            'trr_app_postgres_max_concurrent_operations="$(workspace_projected_app_postgres_max_concurrent_operations)"',
            text,
        )
        self.assertIn(
            'POSTGRES_POOL_MAX=\\"$trr_app_postgres_pool_max\\" \\',
            text,
        )
        self.assertIn(
            'POSTGRES_MAX_CONCURRENT_OPERATIONS=\\"$trr_app_postgres_max_concurrent_operations\\" \\',
            text,
        )

    def test_social_debug_profile_owns_low_pressure_app_pool_values(self) -> None:
        text = SOCIAL_DEBUG_PROFILE.read_text(encoding="utf-8")
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1", text)
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)

    def test_local_cloud_profile_mirrors_default_dedicated_pool_caps(self) -> None:
        text = LOCAL_CLOUD_PROFILE.read_text(encoding="utf-8")
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4", text)
        self.assertIn("TRR_SOCIAL_CONTROL_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)

    def test_default_profile_keeps_low_pressure_modal_social_caps(self) -> None:
        text = DEFAULT_PROFILE.read_text(encoding="utf-8")
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=6", text)
        self.assertIn("WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=12", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=1", text)

    def test_generated_env_contract_mentions_app_pool_projection_vars(self) -> None:
        text = ENV_CONTRACT_DOC.read_text(encoding="utf-8")
        self.assertIn("| `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX` |", text)
        self.assertIn("| `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS` |", text)

    def test_default_profile_keeps_safe_backend_and_app_pool_budget(self) -> None:
        text = DEFAULT_PROFILE.read_text(encoding="utf-8")
        self.assertIn("TRR_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_DB_POOL_MAXCONN=6", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4", text)
        self.assertIn("TRR_SOCIAL_CONTROL_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1", text)
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0", text)
        self.assertIn("WORKSPACE_SCREENALYTICS_DB_ENABLED=0", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=6", text)
        self.assertIn("WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=12", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=1", text)

    def test_workspace_scripts_pin_low_pressure_modal_social_defaults(self) -> None:
        dev_text = DEV_SCRIPT.read_text(encoding="utf-8")
        status_text = STATUS_SCRIPT.read_text(encoding="utf-8")
        defaults = {
            "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT": "6",
            "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": "12",
            "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS": "1",
            "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS": "1",
        }
        for key, value in defaults.items():
            self.assertIn(f'{key}="${{{key}:-{value}}}"', dev_text)
            self.assertIn(f'{key}="${{{key}:-{value}}}"', status_text)
            self.assertIn(f"invalid {key}='${{{key}}}', using {value}.", dev_text)

    def test_dev_workspace_prints_effective_db_holder_budget(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("workspace_effective_db_holder_budget()", text)
        self.assertIn("Local DB holders:", text)

    def test_dev_workspace_prints_selected_db_lane_and_modal_state(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("DB lane:", text)
        self.assertIn("DB source:", text)
        self.assertIn("Remote workers:", text)
        self.assertIn("Modal dispatch:", text)
        self.assertIn("Screenalytics DB:", text)
        self.assertIn('WORKSPACE_TRR_MODAL_ENABLED_DEFAULT="0"', text)
        self.assertIn('WORKSPACE_TRR_REMOTE_WORKERS_ENABLED_DEFAULT="0"', text)
        self.assertIn('WORKSPACE_TRR_MODAL_ENABLED_DEFAULT="1"', text)

    def test_dev_workspace_has_explicit_hybrid_mode_and_remote_db_projection(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("hybrid)", text)
        self.assertIn("Remote DB lane:", text)
        self.assertIn('TRR_DB_DIRECT_URL=\\"\\" \\', text)
        self.assertIn('TRR_DB_SESSION_URL=\\"$WORKSPACE_TRR_REMOTE_DB_URL\\" \\', text)
        self.assertIn('TRR_DB_URL=\\"$WORKSPACE_TRR_REMOTE_DB_URL\\" \\', text)

    def test_selected_db_lane_uses_direct_source(self) -> None:
        self.assertEqual(
            self.run_workspace_helper(
                "workspace_selected_db_lane",
                {
                    "WORKSPACE_TRR_LOCAL_DB_LANE": "direct",
                },
            ),
            "direct",
        )

    def test_selected_remote_db_lane_reports_remote_scope(self) -> None:
        self.assertEqual(
            self.run_workspace_helper(
                "workspace_selected_db_lane remote",
                {
                    "WORKSPACE_TRR_REMOTE_DB_LANE": "session",
                },
            ),
            "session",
        )

    def test_effective_db_holder_budget_uses_explicit_default_profile_values(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget(
                {
                    "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX": "1",
                    "TRR_DB_POOL_MAXCONN": "6",
                    "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN": "4",
                    "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN": "2",
                    "TRR_HEALTH_DB_POOL_MAXCONN": "1",
                }
            ),
            "app=4, backend=4, social_profile=4, social_control=2, health=1, total=15",
        )

    def test_effective_db_holder_budget_uses_default_profile_fallbacks_when_omitted(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget({}),
            "app=4, backend=4, social_profile=4, social_control=2, health=1, total=15",
        )

    def test_effective_db_holder_budget_uses_social_debug_profile_values(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget(self.read_profile_env(SOCIAL_DEBUG_PROFILE)),
            "app=2, backend=4, social_profile=4, social_control=2, health=1, total=13",
        )

    def test_effective_db_holder_budget_uses_default_profile_fallbacks_when_malformed(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget(
                {
                    "POSTGRES_POOL_MAX": "bad",
                    "TRR_DB_POOL_MAXCONN": "0",
                    "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN": "abc",
                    "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN": "nope",
                    "TRR_HEALTH_DB_POOL_MAXCONN": "-1",
                }
            ),
            "app=4, backend=4, social_profile=4, social_control=2, health=1, total=15",
        )
        self.assertEqual(
            self.run_workspace_helper(
                "workspace_projected_app_postgres_pool_max",
                {"POSTGRES_POOL_MAX": "bad"},
            ),
            "",
        )
        self.assertEqual(
            self.run_workspace_helper(
                "workspace_projected_app_postgres_max_concurrent_operations",
                {"POSTGRES_MAX_CONCURRENT_OPERATIONS": "bad"},
            ),
            "",
        )


if __name__ == "__main__":
    unittest.main()
