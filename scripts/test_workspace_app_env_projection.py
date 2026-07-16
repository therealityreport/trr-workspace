#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEV_SCRIPT = ROOT / "scripts" / "dev-workspace.sh"
STATUS_SCRIPT = ROOT / "scripts" / "status-workspace.sh"
MAKEFILE = ROOT / "Makefile"
SOCIAL_DEBUG_PROFILE = ROOT / "profiles" / "social-debug.env"
LOCAL_CLOUD_PROFILE = ROOT / "profiles" / "local-cloud.env"
ENV_CONTRACT_DOC = ROOT / "docs" / "workspace" / "env-contract.md"
DEFAULT_PROFILE = ROOT / "profiles" / "default.env"
PORTFUL_BROWSER_URL_PATTERNS = (
    "admin.localhost:3000",
    "localhost:3000/",
    "127.0.0.1:3000/",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "https://admin.trr.localhost:",
    "https://trr.localhost:",
    "https://api.trr.localhost:",
)
PORTFUL_BROWSER_URL_DOC_ROOTS = (
    ROOT / "AGENTS.md",
    ROOT / "docs",
    ROOT / "TRR-APP" / "docs",
)
PORTFUL_BROWSER_URL_ALLOWED_PARTS = (
    ("docs", "ai", "archive"),
)


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

    def assert_profile_has_unique_keys(self, profile_path: Path) -> None:
        seen: set[str] = set()
        duplicates: list[str] = []
        for raw_line in profile_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line or "=" not in line:
                continue
            key = line.split("=", 1)[0]
            if key in seen:
                duplicates.append(key)
            seen.add(key)
        self.assertEqual(duplicates, [], f"{profile_path.name} has duplicate profile keys")

    def test_compatibility_profiles_do_not_duplicate_first_wins_keys(self) -> None:
        for profile in (
            ROOT / "profiles" / "local-cloud.env",
            ROOT / "profiles" / "local-lite.env",
            ROOT / "profiles" / "local-full.env",
            ROOT / "profiles" / "local-docker.env",
        ):
            with self.subTest(profile=profile.name):
                self.assert_profile_has_unique_keys(profile)

    def test_dev_workspace_defaults_backend_watchdog_on(self) -> None:
        text = DEV_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('WORKSPACE_BACKEND_AUTO_RESTART="${WORKSPACE_BACKEND_AUTO_RESTART:-1}"', text)

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
        self.assertIn("TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN=2", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)

    def test_local_cloud_profile_uses_session_pool_headroom_caps(self) -> None:
        text = LOCAL_CLOUD_PROFILE.read_text(encoding="utf-8")
        self.assertIn("WORKSPACE_BACKEND_AUTO_RESTART=1", text)
        self.assertIn("TRR_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_DB_POOL_MAXCONN=3", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=2", text)
        self.assertIn("TRR_SOCIAL_CONTROL_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN=2", text)
        self.assertIn("TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)

    def test_default_profile_keeps_low_pressure_modal_social_caps(self) -> None:
        text = DEFAULT_PROFILE.read_text(encoding="utf-8")
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=4", text)
        self.assertIn("WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=4", text)
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
        self.assertIn("TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN=2", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MINCONN=1", text)
        self.assertIn("TRR_HEALTH_DB_POOL_MAXCONN=1", text)
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=1", text)
        self.assertIn("WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=1", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=4", text)
        self.assertIn("WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=4", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1", text)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=1", text)

    def test_workspace_scripts_pin_low_pressure_modal_social_defaults(self) -> None:
        dev_text = DEV_SCRIPT.read_text(encoding="utf-8")
        status_text = STATUS_SCRIPT.read_text(encoding="utf-8")
        defaults = {
            "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT": "4",
            "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": "4",
            "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS": "1",
            "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS": "1",
        }
        for key, value in defaults.items():
            self.assertIn(f'{key}="${{{key}:-{value}}}"', dev_text)
            self.assertIn(f'{key}="${{{key}:-{value}}}"', status_text)
        self.assertIn("WORKSPACE_RUNTIME_CAPACITY_DISPATCH_BATCH_SIZE", dev_text)
        self.assertIn("WORKSPACE_RUNTIME_CAPACITY_GENERAL_CONCURRENCY", dev_text)
        self.assertIn("WORKSPACE_RUNTIME_CAPACITY_CONTEXT", status_text)

    def test_make_dev_defaults_to_hybrid_portless_runtime(self) -> None:
        text = MAKEFILE.read_text(encoding="utf-8")
        dev_target = text[text.index("\ndev:") : text.index("\ndev-redis:", text.index("\ndev:"))]
        self.assertIn("dev-hybrid", dev_target)
        self.assertIn('PROFILE="$${PROFILE:-local-cloud}"', dev_target)

        dev_redis = text[text.index("\ndev-redis:") : text.index("\n# Compatibility alias", text.index("\ndev-redis:"))]
        self.assertIn("dev-local PROFILE=local-redis", dev_redis)

        dev_local = text[text.index("\ndev-local:") : text.index("\n# Deprecated compatibility alias", text.index("\ndev-local:"))]
        self.assertIn("preflight", dev_local)
        self.assertIn("WORKSPACE_DEV_MODE=local", dev_local)

    def test_workspace_launcher_always_uses_portless_urls(self) -> None:
        dev_text = DEV_SCRIPT.read_text(encoding="utf-8")
        makefile_text = MAKEFILE.read_text(encoding="utf-8")
        contract_text = ENV_CONTRACT_DOC.read_text(encoding="utf-8")

        self.assertIn('WORKSPACE_USE_PORTLESS_URLS="1"', dev_text)
        self.assertNotIn('WORKSPACE_USE_PORTLESS_URLS="${WORKSPACE_USE_PORTLESS_URLS:-0}"', dev_text)
        self.assertNotIn("http://admin.localhost:3000", dev_text)
        self.assertNotIn("PORTLESS_PUBLIC_PORT_SUFFIX", dev_text)
        self.assertIn("PORTLESS_PORT=${PORTLESS_PORT} would publish numbered TRR dev URLs", dev_text)
        self.assertIn('WORKSPACE_PORTLESS_APP_URL="https://trr.localhost"', dev_text)
        self.assertIn('WORKSPACE_PORTLESS_ADMIN_URL="https://admin.trr.localhost"', dev_text)
        self.assertIn('WORKSPACE_PORTLESS_API_URL="https://api.trr.localhost"', dev_text)
        self.assertIn('ADMIN_APP_ORIGIN="${ADMIN_APP_ORIGIN:-$WORKSPACE_PORTLESS_ADMIN_URL}"', dev_text)
        self.assertIn('TRR_APP_RUNTIME_API_URL="$WORKSPACE_PORTLESS_API_URL"', dev_text)
        self.assertIn('WORKSPACE_PUBLIC_APP_URL="$WORKSPACE_PORTLESS_APP_URL"', dev_text)
        self.assertIn('WORKSPACE_PUBLIC_ADMIN_URL="$WORKSPACE_PORTLESS_ADMIN_URL"', dev_text)
        self.assertIn('WORKSPACE_PUBLIC_API_URL="$WORKSPACE_PORTLESS_API_URL"', dev_text)
        self.assertIn("portless api.trr", dev_text)
        self.assertIn("portless trr", dev_text)
        self.assertIn("| `WORKSPACE_USE_PORTLESS_URLS` | `1` | `1` |", contract_text)
        for command_prefix in makefile_text.split("bash scripts/dev-workspace.sh")[:-1]:
            self.assertIn("WORKSPACE_USE_PORTLESS_URLS=1", command_prefix[-300:])

    def test_active_docs_do_not_reintroduce_portful_browser_urls(self) -> None:
        violations: list[str] = []
        for root in PORTFUL_BROWSER_URL_DOC_ROOTS:
            paths = [root] if root.is_file() else sorted(path for path in root.rglob("*") if path.is_file())
            for path in paths:
                relative_parts = path.relative_to(ROOT).parts
                if any(
                    tuple(relative_parts[index : index + len(allowed)]) == allowed
                    for allowed in PORTFUL_BROWSER_URL_ALLOWED_PARTS
                    for index in range(len(relative_parts) - len(allowed) + 1)
                ):
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                for pattern in PORTFUL_BROWSER_URL_PATTERNS:
                    if pattern in text:
                        violations.append(f"{path.relative_to(ROOT)} contains {pattern}")

        self.assertEqual(
            violations,
            [],
            "Use Portless clean URLs in active docs: https://admin.trr.localhost, "
            "https://trr.localhost, and https://api.trr.localhost.",
        )

    def test_dev_hybrid_adopts_social_safe_make_overrides(self) -> None:
        text = MAKEFILE.read_text(encoding="utf-8")
        dev_hybrid = text[text.index("\ndev-hybrid:") : text.index("\n# Compatibility alias", text.index("\ndev-hybrid:"))]
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1", dev_hybrid)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8", dev_hybrid)
        self.assertIn("WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8", dev_hybrid)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1", dev_hybrid)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8", dev_hybrid)
        self.assertIn("SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8", dev_hybrid)
        self.assertIn("SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false", dev_hybrid)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1", dev_hybrid)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1", dev_hybrid)
        self.assertIn("WORKSPACE_USE_PORTLESS_URLS=1", dev_hybrid)
        self.assertIn("WORKSPACE_DEV_MODE=hybrid", dev_hybrid)
        self.assertIn("instagram-media-mirror-recovery", text)
        self.assertIn("media_mirror_recovery.py", text)
        self.assertIn("RECOVER MEDIA MIRROR JOBS", text)
        self.assertIn("social-queue-snapshot", text)
        self.assertIn("queue_snapshot.py", text)

        media_safe = text[
            text.index("\ndev-hybrid-media-safe:") : text.index("\n# Detached hybrid launcher", text.index("\ndev-hybrid-media-safe:"))
        ]
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1", media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8", media_safe)
        self.assertIn("WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8", media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8", media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=2", media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=2", media_safe)
        self.assertIn("WORKSPACE_DEV_MODE=hybrid", media_safe)
        self.assertIn("media_queue_guard.py", media_safe)
        self.assertIn("ALLOW_STALE_MEDIA", media_safe)

        posts_media_safe = text[
            text.index("\ndev-hybrid-media-safe-posts:")
            : text.index("\ndev-hybrid-media-safe-comments:", text.index("\ndev-hybrid-media-safe-posts:"))
        ]
        self.assertIn("media_queue_guard.py", posts_media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=3", posts_media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1", posts_media_safe)
        self.assertIn("WORKSPACE_DEV_MODE=hybrid", posts_media_safe)

        comments_media_safe = text[
            text.index("\ndev-hybrid-media-safe-comments:")
            : text.index("\n# Detached hybrid launcher", text.index("\ndev-hybrid-media-safe-comments:"))
        ]
        self.assertIn("media_queue_guard.py", comments_media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1", comments_media_safe)
        self.assertIn("WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=3", comments_media_safe)
        self.assertIn("WORKSPACE_DEV_MODE=hybrid", comments_media_safe)

        snapshot_target = text[
            text.index("\nsocial-queue-snapshot:") : text.index("\n# Compatibility alias", text.index("\nsocial-queue-snapshot:"))
        ]
        self.assertIn(".logs/workspace/social-queue-snapshots", snapshot_target)
        self.assertIn("tee", snapshot_target)

        social_safe_alias = text[
            text.index("\ndev-hybrid-social-safe:") : text.index("\n# Deprecated compatibility alias", text.index("\ndev-hybrid-social-safe:"))
        ]
        self.assertIn("dev-hybrid PROFILE=", social_safe_alias)

    def test_modal_instagram_auth_status_target_is_bounded(self) -> None:
        text = MAKEFILE.read_text(encoding="utf-8")
        target = text[
            text.index("\nmodal-instagram-auth-status:")
            : text.index("\nmodal-instagram-auth-repair:", text.index("\nmodal-instagram-auth-status:"))
        ]

        self.assertIn("--probe-remote-auth instagram", target)
        self.assertIn("--remote-probe-timeout-seconds", target)
        self.assertIn("--modal-lookup-timeout-seconds", target)
        self.assertIn("MODAL_INSTAGRAM_AUTH_STATUS_TIMEOUT_SECONDS:-45", target)
        self.assertIn("MODAL_INSTAGRAM_AUTH_LOOKUP_TIMEOUT_SECONDS:-30", target)

    def test_modal_instagram_auth_repair_target_runs_owner_guardrail(self) -> None:
        text = MAKEFILE.read_text(encoding="utf-8")
        target = text[
            text.index("\nmodal-instagram-auth-repair:")
            : text.index("\n# Compatibility alias", text.index("\nmodal-instagram-auth-repair:"))
        ]

        self.assertIn("./scripts/modal-billing-guardrail.sh", target)
        self.assertIn('backend_dir="$${TRR_MODAL_BACKEND_DIR:-$(CURDIR)/TRR-Backend}"', target)
        self.assertIn('TRR_MODAL_BACKEND_DIR="$$backend_dir"', target)
        self.assertIn("TRR_MODAL_SOURCE_ENV=\"$$source_env\"", target)
        self.assertIn('python_cmd="$${TRR_BACKEND_PYTHON:-$(CURDIR)/TRR-Backend/.venv/bin/python}"', target)
        self.assertIn("scripts/modal/repair_instagram_auth.py --json", target)

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
        self.assertNotIn("Screenalytics DB:", text)
        self.assertNotIn("WORKSPACE_SCREENALYTICS_DB_ENABLED", text)
        self.assertIn('WORKSPACE_TRR_MODAL_ENABLED_DEFAULT="0"', text)
        self.assertIn('WORKSPACE_TRR_REMOTE_WORKERS_ENABLED_DEFAULT="0"', text)
        self.assertIn('WORKSPACE_TRR_MODAL_ENABLED_DEFAULT="1"', text)

    def test_profiles_do_not_set_retired_screenalytics_db_toggle(self) -> None:
        for profile in (DEFAULT_PROFILE, LOCAL_CLOUD_PROFILE, SOCIAL_DEBUG_PROFILE):
            with self.subTest(profile=profile.name):
                self.assertNotIn(
                    "WORKSPACE_SCREENALYTICS_DB_ENABLED",
                    profile.read_text(encoding="utf-8"),
                )

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
                    "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN": "2",
                    "TRR_HEALTH_DB_POOL_MAXCONN": "1",
                }
            ),
            "app=1, backend=6, social_profile=4, social_control=2, social_progress=2, health=1, total=16",
        )

    def test_effective_db_holder_budget_uses_default_profile_fallbacks_when_omitted(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget({}),
            "app=1, backend=6, social_profile=4, social_control=2, social_progress=2, health=1, total=16",
        )

    def test_effective_db_holder_budget_uses_social_debug_profile_values(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget(self.read_profile_env(SOCIAL_DEBUG_PROFILE)),
            "app=1, backend=4, social_profile=4, social_control=2, social_progress=2, health=1, total=14",
        )

    def test_effective_db_holder_budget_uses_local_cloud_profile_values(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget(self.read_profile_env(LOCAL_CLOUD_PROFILE)),
            "app=1, backend=3, social_profile=2, social_control=2, social_progress=1, health=1, total=10",
        )

    def test_session_fallback_launch_footprint_supports_api_concurrency_and_four_remote_workers(self) -> None:
        low_pressure_env = {
            "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX": "1",
            # One primary connection is not launch-capable: concurrent admin
            # status reads can occupy it while the start request needs a write.
            "TRR_DB_POOL_MAXCONN": "2",
            "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN": "1",
            "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN": "1",
            "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN": "1",
            "TRR_HEALTH_DB_POOL_MAXCONN": "1",
        }
        remote_worker_launch_settings = {
            "WORKSPACE_TRR_REMOTE_ADMIN_WORKERS": "1",
            "WORKSPACE_TRR_REMOTE_REDDIT_WORKERS": "1",
            "WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS": "1",
            "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS": "1",
        }

        budget = self.run_workspace_db_holder_budget(low_pressure_env)
        total = int(budget.rsplit("total=", 1)[1])
        api_concurrency = int(low_pressure_env["TRR_DB_POOL_MAXCONN"])
        remote_worker_count = sum(int(value) for value in remote_worker_launch_settings.values())

        dev_text = DEV_SCRIPT.read_text(encoding="utf-8")
        makefile_text = MAKEFILE.read_text(encoding="utf-8")
        dev_hybrid = makefile_text[
            makefile_text.index("\ndev-hybrid:") : makefile_text.index(
                "\n# Compatibility alias", makefile_text.index("\ndev-hybrid:")
            )
        ]
        for key, value in remote_worker_launch_settings.items():
            if key == "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS":
                self.assertIn(f"{key}={value}", dev_hybrid)
            else:
                self.assertIn(f'{key}="${{{key}:-{value}}}"', dev_text)

        self.assertEqual(
            budget,
            "app=1, backend=2, social_profile=1, social_control=1, social_progress=1, health=1, total=7",
        )
        self.assertEqual(api_concurrency, 2)
        self.assertEqual(remote_worker_count, 4)
        self.assertLessEqual(total + remote_worker_count, 15)

    def test_effective_db_holder_budget_uses_default_profile_fallbacks_when_malformed(self) -> None:
        self.assertEqual(
            self.run_workspace_db_holder_budget(
                {
                    "POSTGRES_POOL_MAX": "bad",
                    "TRR_DB_POOL_MAXCONN": "0",
                    "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN": "abc",
                    "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN": "nope",
                    "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN": "nan",
                    "TRR_HEALTH_DB_POOL_MAXCONN": "-1",
                }
            ),
            "app=1, backend=6, social_profile=4, social_control=2, social_progress=2, health=1, total=16",
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
