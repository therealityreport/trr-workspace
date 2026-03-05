#!/usr/bin/env python3
"""Default revision command for workspace PR agent.

Consumes WORKSPACE_AGENT_* context env vars and applies deterministic + Codex-assisted
fix flows for failing checks, bot feedback, and merge conflicts.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def run(cmd: list[str], *, cwd: Path, check: bool = False) -> subprocess.CompletedProcess[str]:
    eprint(f"[revision] run: {' '.join(shlex.quote(part) for part in cmd)}")
    result = subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True)
    if result.stdout.strip():
        eprint(result.stdout.strip())
    if result.stderr.strip():
        eprint(result.stderr.strip())
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed with exit {result.returncode}: {' '.join(cmd)}")
    return result


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text())
    except Exception:
        return {}


def git_status_files(repo_path: Path) -> list[str]:
    result = run(["git", "status", "--porcelain"], cwd=repo_path, check=False)
    files: list[str] = []
    for raw_line in (result.stdout or "").splitlines():
        line = raw_line.rstrip("\n")
        if not line:
            continue
        if len(line) < 4:
            continue
        path_part = line[3:]
        # Rename format: old -> new
        if " -> " in path_part:
            path_part = path_part.split(" -> ", 1)[1]
        files.append(path_part.strip())
    return files


def python_bin_for_repo(repo_path: Path) -> str:
    venv_py = repo_path / ".venv" / "bin" / "python"
    if venv_py.exists():
        return str(venv_py)
    return "python3"


def ruff_bin_for_repo(repo_path: Path) -> str:
    venv_ruff = repo_path / ".venv" / "bin" / "ruff"
    if venv_ruff.exists():
        return str(venv_ruff)
    return "ruff"


def deterministic_fix_pass(
    repo_name: str,
    repo_path: Path,
    *,
    reason: str,
    context: dict[str, Any],
) -> None:
    touched_files = git_status_files(repo_path)
    conflict_files = context.get("conflict_files") if isinstance(context.get("conflict_files"), list) else []
    candidate_files = sorted({str(path) for path in (conflict_files or touched_files)})

    py_files = [file for file in candidate_files if file.endswith(".py")]
    app_files = [
        file
        for file in candidate_files
        if file.startswith("apps/web/")
        and file.endswith((".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"))
    ]

    if repo_name == "TRR-Backend":
        if not py_files:
            return
        ruff = ruff_bin_for_repo(repo_path)
        run([ruff, "check", "--fix", *py_files], cwd=repo_path, check=False)
        run([ruff, "format", *py_files], cwd=repo_path, check=False)
        return

    if repo_name == "screenalytics":
        if not py_files:
            return
        py = python_bin_for_repo(repo_path)
        run([py, "-m", "py_compile", *py_files], cwd=repo_path, check=False)
        return

    if repo_name == "TRR-APP":
        if not app_files:
            return
        eslint_targets = [file.removeprefix("apps/web/") for file in app_files]
        run(["pnpm", "-C", "apps/web", "exec", "eslint", "--fix", *eslint_targets], cwd=repo_path, check=False)
        return

    # Unknown repo fallback
    if reason == "failing_checks":
        run(["git", "status", "--short"], cwd=repo_path, check=False)


def codex_prompt(reason: str, context_file: Path) -> str:
    use_github_mcp = os.environ.get("WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP", "1") not in {"0", "false", "no"}
    pr_number = os.environ.get("WORKSPACE_AGENT_PR_NUMBER", "")
    repo_name = os.environ.get("WORKSPACE_AGENT_REPO_NAME", "")

    base = (
        "You are fixing an open PR branch in the current git repository. "
        "Read the JSON context file, apply only necessary code changes to address the issue, "
        "run relevant validations, and do not commit or create branches. "
        "If no safe fix is possible, explain why in your final response."
    )
    mcp_hint = (
        "Use GitHub MCP (not gh CLI) to inspect PR checks/reviews/conversation context before editing. "
        "If GitHub MCP is unavailable, proceed using only local context + context file."
        if use_github_mcp
        else "Do not require GitHub MCP; use local context and the provided context file."
    )

    if reason == "merge_conflict":
        task = (
            "Resolve all git merge conflicts in favor of the correct combined behavior. "
            "Keep compatibility with existing contracts and tests."
        )
    elif reason == "bot_feedback":
        task = "Address actionable bot reviews/messages from the context and update code/tests accordingly."
    else:
        task = "Investigate failing CI/check context and fix root causes, including tests or typing/lint issues."

    return (
        f"{base}\n"
        f"{mcp_hint}\n"
        f"PR: #{pr_number} ({repo_name})\n"
        f"Reason: {reason}\n"
        f"Context file: {context_file}\n"
        f"Task: {task}\n"
    )


def codex_assist(repo_path: Path, reason: str, context_file: Path) -> None:
    if shutil.which("codex") is None:
        raise RuntimeError("codex CLI not found on PATH")
    require_mcp = os.environ.get("WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP", "0") in {"1", "true", "yes"}
    use_mcp = os.environ.get("WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP", "1") not in {"0", "false", "no"}
    if require_mcp and use_mcp and not os.environ.get("GITHUB_PAT"):
        raise RuntimeError("WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1 but GITHUB_PAT is not set")
    prompt = codex_prompt(reason, context_file)
    # full-auto enables non-interactive agent execution with workspace-write sandbox.
    run(["codex", "exec", "--full-auto", "-C", str(repo_path), prompt], cwd=repo_path, check=True)


def main() -> int:
    repo_name = os.environ.get("WORKSPACE_AGENT_REPO_NAME", "")
    repo_path_raw = os.environ.get("WORKSPACE_AGENT_REPO_PATH", "")
    reason = os.environ.get("WORKSPACE_AGENT_REASON", "")
    context_file_raw = os.environ.get("WORKSPACE_AGENT_CONTEXT_FILE", "")

    if not repo_name or not repo_path_raw or not reason or not context_file_raw:
        eprint("[revision] missing required WORKSPACE_AGENT_* context env vars")
        return 2

    repo_path = Path(repo_path_raw).resolve()
    context_file = Path(context_file_raw).resolve()
    if not repo_path.exists():
        eprint(f"[revision] repo path does not exist: {repo_path}")
        return 2
    if not context_file.exists():
        eprint(f"[revision] context file does not exist: {context_file}")
        return 2

    context_data = read_json(context_file)
    context = context_data if isinstance(context_data, dict) else {}
    eprint(f"[revision] repo={repo_name} reason={reason} context_file={context_file}")

    actionable_bot_feedback = False
    if reason == "bot_feedback":
        bot_feedback = context.get("bot_feedback")
        if isinstance(bot_feedback, list):
            actionable_bot_feedback = any(bool(item.get("actionable")) for item in bot_feedback if isinstance(item, dict))

    should_run_deterministic = reason in {"failing_checks", "merge_conflict"} or actionable_bot_feedback
    if should_run_deterministic:
        deterministic_fix_pass(repo_name, repo_path, reason=reason, context=context)

    use_codex = os.environ.get("WORKSPACE_PR_AGENT_REVISION_USE_CODEX", "1") not in {"0", "false", "no"}
    if use_codex and reason in {"failing_checks", "bot_feedback", "merge_conflict"}:
        if reason == "bot_feedback" and not actionable_bot_feedback:
            eprint("[revision] no actionable bot feedback entries; skipping codex assist")
            return 0
        codex_assist(repo_path, reason, context_file)

    return 0


if __name__ == "__main__":
    sys.exit(main())
