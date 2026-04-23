# Workspace Policy Contract Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make TRR workspace policy validation deterministic so `make preflight` and `make dev` fail only on real root/backend/app `AGENTS.md` or entrypoint `CLAUDE.md` drift, while leaving the three `* Brain/CLAUDE.md` boot docs outside the entrypoint symlink contract.

**Architecture:** Keep `AGENTS.md` as the canonical instruction surface for the three repo entrypoints, and require only `/TRR/CLAUDE.md`, `/TRR/TRR-Backend/CLAUDE.md`, and `/TRR/TRR-APP/CLAUDE.md` to be symlinks resolving to their matching `AGENTS.md` files. Refactor `scripts/check-policy.sh` so it can validate a supplied fixture root, route every policy target through `POLICY_ROOT`, explicitly validate only the three entrypoint `CLAUDE.md` files as symlinks, and skip external handoff/Codex checks in isolated tests. Preserve the three `* Brain/CLAUDE.md` files as substantive boot docs and prove that the rewritten top-level `CLAUDE.md` files still route Claude to the right `AGENTS.md` file in root, backend, and app scopes.

**Tech Stack:** Bash, ripgrep, Python 3.11, pytest, Make, markdown docs, Claude CLI.

---

## Scope

This plan covers:

1. Locking the policy scope decision that only the three repo entrypoint `CLAUDE.md` files are entrypoint symlinks.
2. Adding automated regression coverage for `check-policy.sh` using a fixture workspace rooted outside the live repo.
3. Refactoring `scripts/check-policy.sh` so `--root` works end-to-end and the `CLAUDE.md` scope is explicit.
4. Replacing the three live entrypoint `CLAUDE.md` files with symlinks to the matching `AGENTS.md`.
5. Verifying the targeted pytest file, `bash scripts/check-policy.sh`, and Claude boot routing.

This plan does not cover:

- Rewriting the existing root/backend/app `AGENTS.md` content unless policy checks prove actual drift there.
- Converting `TRR Workspace Brain/CLAUDE.md`, `TRR-Backend/TRR Backend Brain/CLAUDE.md`, or `TRR-APP/TRR App Brain/CLAUDE.md` into pointer shims.
- Changing runtime-reconcile, Modal, Render, or Decodo behavior.
- Reverting unrelated in-progress workspace changes under `.agents/`, `Makefile`, or repo-local brain migrations.

## File Structure

- Modify: `/Users/thomashulihan/Projects/TRR/scripts/check-policy.sh`
  - Add `--root` support, route all policy targets through `POLICY_ROOT`, keep helper sourcing on `SCRIPT_ROOT`, explicitly collect only the three entrypoint `CLAUDE.md` files, require them to be symlinks resolving to the matching `AGENTS.md`, and gate external checks with `CHECK_POLICY_SKIP_EXTERNAL`.
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_check_policy.py`
  - Regression coverage for invalid entrypoint `CLAUDE.md` state, valid entrypoint symlinks, and explicit exclusion of the three `* Brain/CLAUDE.md` files from symlink enforcement.
- Modify: `/Users/thomashulihan/Projects/TRR/CLAUDE.md`
  - Replace the regular file with a symlink to `/Users/thomashulihan/Projects/TRR/AGENTS.md`.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/CLAUDE.md`
  - Replace the regular file with a symlink to `/Users/thomashulihan/Projects/TRR/TRR-Backend/AGENTS.md`.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-APP/CLAUDE.md`
  - Replace the regular file with a symlink to `/Users/thomashulihan/Projects/TRR/TRR-APP/AGENTS.md`.

## Acceptance Targets

- `pytest -q TRR-Backend/tests/scripts/test_check_policy.py` passes.
- The test suite proves that:
  - invalid root/backend/app `CLAUDE.md` entrypoint state fails policy checks,
  - valid root/backend/app symlinks pass policy checks,
  - the three `* Brain/CLAUDE.md` files are ignored by the entrypoint symlink validator.
- `bash scripts/check-policy.sh` succeeds in the live workspace.
- `/Users/thomashulihan/Projects/TRR/CLAUDE.md`, `/Users/thomashulihan/Projects/TRR/TRR-Backend/CLAUDE.md`, and `/Users/thomashulihan/Projects/TRR/TRR-APP/CLAUDE.md` are symlinks resolving to the matching `AGENTS.md` path.
- `TRR Workspace Brain/CLAUDE.md`, `TRR-Backend/TRR Backend Brain/CLAUDE.md`, and `TRR-APP/TRR App Brain/CLAUDE.md` remain substantive docs and are unchanged by this implementation.
- Claude root/backend/app smoke checks each mention the matching `AGENTS.md` path after the symlink rewrite.

### Task 1: Refactor `check-policy.sh` Around An Explicit Entrypoint Symlink Contract

**Files:**
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_check_policy.py`
- Modify: `/Users/thomashulihan/Projects/TRR/scripts/check-policy.sh`

- [ ] **Step 1: Write the failing test**

Create `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_check_policy.py` with fixture coverage for valid entrypoint symlinks, invalid entrypoint `CLAUDE.md` state, and ignored `* Brain/CLAUDE.md` files.

```python
from __future__ import annotations

import os
import subprocess
from pathlib import Path


WORKSPACE_ROOT = Path(__file__).resolve().parents[3]
CHECK_POLICY = WORKSPACE_ROOT / "scripts" / "check-policy.sh"

ROOT_AGENTS = """# TRR WORKSPACE ROUTER

## Cross-Repo Implementation Order
- Backend-first for schema and contract changes.

## Shared Contracts
- docs/workspace/dev-commands.md
- docs/workspace/chrome-devtools.md
- docs/ai/HANDOFF_WORKFLOW.md
- docs/agent-governance/skill_routing.md

## MCP Invocation Matrix
- `chrome-devtools`
- `github`
- `supabase`
- `figma`

## Trust Boundaries
- Treat every untrusted input as untrusted input until verified against repo code or the live contract.
"""

REPO_AGENTS = """# TRR REPO VAULT

## Scope
- Repo-only instructions for this fixture.
- If policy scope is unclear, escalate to `../AGENTS.md`.

## Non-Negotiable Rules
- `AGENTS.md` is the canonical instruction file for this scope.
- Re-read `../AGENTS.md` for workspace policy questions.

## Validation
- Run the repo-local checks touched by the change.
- Re-read `../AGENTS.md` when startup or policy rules are involved.
"""

BRAIN_CLAUDE = """# Brain-local boot doc

This file is intentionally not a pointer shim.
It represents the local brain scope and must stay out of the entrypoint CLAUDE policy contract.
"""


def _expected_pointer(agents_path: Path) -> str:
    return (
        "# CLAUDE.md Pointer\n\n"
        "Canonical instructions for this scope are in:\n"
        f"`{agents_path}`\n\n"
        "Rules:\n"
        "1. Read `AGENTS.md` first.\n"
        "2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.\n"
        "3. If there is any conflict, `AGENTS.md` is authoritative.\n"
        "4. This file must remain a short pointer shim."
    )


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _seed_workspace_fixture(root: Path, *, invalid_entrypoint_claude: bool) -> Path:
    _write(root / "AGENTS.md", ROOT_AGENTS)
    _write(root / "TRR-Backend" / "AGENTS.md", REPO_AGENTS)
    _write(root / "TRR-APP" / "AGENTS.md", REPO_AGENTS)

    _write(root / ".codex" / "config.toml", "[mcp_servers]\n")
    _write(root / ".codex" / "rules" / "default.rules", "# policy fixture\n")
    _write(root / "docs" / "workspace" / "dev-commands.md", "workspace commands\n")
    _write(root / "docs" / "workspace" / "chrome-devtools.md", "chrome devtools\n")
    _write(root / "docs" / "ai" / "HANDOFF_WORKFLOW.md", "handoff workflow\n")
    _write(root / "docs" / "agent-governance" / "skill_routing.md", "skill routing\n")
    _write(root / "docs" / "agent-governance" / "claude_skill_overlap.md", "claude overlap\n")
    _write(root / "docs" / "agent-governance" / "mcp_inventory.md", "mcp inventory\n")

    _write(root / "TRR Workspace Brain" / "CLAUDE.md", BRAIN_CLAUDE)
    _write(root / "TRR-Backend" / "TRR Backend Brain" / "CLAUDE.md", BRAIN_CLAUDE)
    _write(root / "TRR-APP" / "TRR App Brain" / "CLAUDE.md", BRAIN_CLAUDE)

    if invalid_entrypoint_claude:
      bad = "# not a pointer shim\n\nThis should fail policy validation.\n"
      _write(root / "CLAUDE.md", bad)
      _write(root / "TRR-Backend" / "CLAUDE.md", bad)
      _write(root / "TRR-APP" / "CLAUDE.md", bad)
    else:
      _write(root / "CLAUDE.md", _expected_pointer(root / "AGENTS.md"))
      _write(root / "TRR-Backend" / "CLAUDE.md", _expected_pointer(root / "TRR-Backend" / "AGENTS.md"))
      _write(root / "TRR-APP" / "CLAUDE.md", _expected_pointer(root / "TRR-APP" / "AGENTS.md"))

    return root


def _run_check_policy(root: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["CHECK_POLICY_SKIP_EXTERNAL"] = "1"
    return subprocess.run(
        ["bash", str(CHECK_POLICY), "--root", str(root)],
        cwd=WORKSPACE_ROOT,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )


def test_check_policy_fails_when_entrypoint_claude_files_are_not_pointer_shims(tmp_path) -> None:
    fixture_root = _seed_workspace_fixture(tmp_path / "workspace", invalid_entrypoint_claude=True)

    result = _run_check_policy(fixture_root)

    assert result.returncode == 1
    assert "canonical pointer-shim template" in result.stderr


def test_check_policy_accepts_valid_entrypoint_pointer_shims(tmp_path) -> None:
    fixture_root = _seed_workspace_fixture(tmp_path / "workspace", invalid_entrypoint_claude=False)

    result = _run_check_policy(fixture_root)

    assert result.returncode == 0
    assert "[check-policy] OK" in result.stdout


def test_check_policy_ignores_brain_claude_docs_when_entrypoint_shims_are_valid(tmp_path) -> None:
    fixture_root = _seed_workspace_fixture(tmp_path / "workspace", invalid_entrypoint_claude=False)

    result = _run_check_policy(fixture_root)

    assert result.returncode == 0
    assert "TRR Workspace Brain/CLAUDE.md" not in result.stderr
    assert "TRR Backend Brain/CLAUDE.md" not in result.stderr
    assert "TRR App Brain/CLAUDE.md" not in result.stderr
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
pytest -q TRR-Backend/tests/scripts/test_check_policy.py
```

Expected: FAIL because `scripts/check-policy.sh` does not yet honor `--root`, still validates live-repo targets through `$ROOT`, and does not explicitly separate entrypoint `CLAUDE.md` files from the three `* Brain/CLAUDE.md` docs.

- [ ] **Step 3: Write the minimal implementation**

Update the top of `/Users/thomashulihan/Projects/TRR/scripts/check-policy.sh` to this:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_ROOT="$SCRIPT_ROOT"
CHECK_POLICY_SKIP_EXTERNAL="${CHECK_POLICY_SKIP_EXTERNAL:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      POLICY_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    *)
      echo "[check-policy] ERROR: unknown argument $1" >&2
      exit 2
      ;;
  esac
done

source "$SCRIPT_ROOT/scripts/lib/preflight-diagnostics.sh"
source "$SCRIPT_ROOT/scripts/lib/preflight-handoff.sh"

preflight_diag_init "check-policy.sh" "$SCRIPT_ROOT" "check-policy"
WORKSPACE_PREFLIGHT_STRICT="${WORKSPACE_PREFLIGHT_STRICT:-0}"
```

Replace the current `AGENTS_FILES` and `CLAUDE_FILES` block with this explicit entrypoint-only version:

```bash
AGENTS_FILES=(
  "$POLICY_ROOT/AGENTS.md"
  "$POLICY_ROOT/TRR-Backend/AGENTS.md"
  "$POLICY_ROOT/TRR-APP/AGENTS.md"
)

collect_entrypoint_claude_files() {
  local candidate
  for candidate in \
    "$POLICY_ROOT/CLAUDE.md" \
    "$POLICY_ROOT/TRR-Backend/CLAUDE.md" \
    "$POLICY_ROOT/TRR-APP/CLAUDE.md"
  do
    [[ -f "$candidate" ]] && printf '%s\n' "$candidate"
  done
}

mapfile -t CLAUDE_FILES < <(collect_entrypoint_claude_files | LC_ALL=C sort -u)
```

Replace the `POLICY_SCAN_FILES` block with this existence-checked version:

```bash
POLICY_SCAN_FILES=("${AGENTS_FILES[@]}")
for candidate in \
  "$POLICY_ROOT/.codex/config.toml" \
  "$POLICY_ROOT/.codex/rules/default.rules" \
  "$POLICY_ROOT/docs/workspace/dev-commands.md" \
  "$POLICY_ROOT/docs/workspace/chrome-devtools.md" \
  "$POLICY_ROOT/docs/ai/HANDOFF_WORKFLOW.md" \
  "$POLICY_ROOT/docs/agent-governance/skill_routing.md" \
  "$POLICY_ROOT/docs/agent-governance/claude_skill_overlap.md" \
  "$POLICY_ROOT/docs/agent-governance/mcp_inventory.md"
do
  [[ -f "$candidate" ]] && POLICY_SCAN_FILES+=("$candidate")
done
if [[ "${#CLAUDE_FILES[@]}" -gt 0 ]]; then
  POLICY_SCAN_FILES+=("${CLAUDE_FILES[@]}")
fi
```

Make these exact path replacements in the existing functions and invocations so every policy target reads from `POLICY_ROOT`:

```diff
--- a/scripts/check-policy.sh
+++ b/scripts/check-policy.sh
@@
-  local file="$ROOT/AGENTS.md"
+  local file="$POLICY_ROOT/AGENTS.md"
@@
-check_repo_agents "$ROOT/TRR-Backend/AGENTS.md"
-check_repo_agents "$ROOT/TRR-APP/AGENTS.md"
+check_repo_agents "$POLICY_ROOT/TRR-Backend/AGENTS.md"
+check_repo_agents "$POLICY_ROOT/TRR-APP/AGENTS.md"
@@
-  local agents_path="$ROOT/AGENTS.md"
+  local agents_path="$POLICY_ROOT/AGENTS.md"
@@
-    "$ROOT/TRR-Backend"/*)
-      agents_path="$ROOT/TRR-Backend/AGENTS.md"
+    "$POLICY_ROOT/TRR-Backend"/*)
+      agents_path="$POLICY_ROOT/TRR-Backend/AGENTS.md"
@@
-    "$ROOT/TRR-APP"/*)
-      agents_path="$ROOT/TRR-APP/AGENTS.md"
+    "$POLICY_ROOT/TRR-APP"/*)
+      agents_path="$POLICY_ROOT/TRR-APP/AGENTS.md"
```

Gate the external checks so the fixture-root tests stay isolated, but keep the live behavior unchanged when the env var is unset:

```bash
if [[ "$CHECK_POLICY_SKIP_EXTERNAL" != "1" ]]; then
  handoff_check_output=""
  set +e
  handoff_check_output="$(make -C "$POLICY_ROOT" --no-print-directory handoff-check 2>&1)"
  handoff_check_rc="$?"
  set -e
  if [[ "$handoff_check_rc" != "0" ]]; then
    if [[ "$WORKSPACE_PREFLIGHT_STRICT" == "1" ]]; then
      printf '%s\n' "$handoff_check_output" >&2
      echo "[check-policy] ERROR: generated handoffs are out of sync or canonical sources are invalid." >&2
      failures=$((failures + 1))
    else
      handoff_warning="$(preflight_handle_handoff_sync_result "$WORKSPACE_PREFLIGHT_STRICT" "$handoff_check_rc" "$handoff_check_output")"
      printf '%s\n' "$handoff_warning" >&2
      echo "[check-policy] WARNING: handoff validation did not block policy checks in non-strict mode." >&2
    fi
  fi

  if ! bash "$SCRIPT_ROOT/scripts/check-codex.sh"; then
    echo "[check-policy] ERROR: Codex config or rules validation failed." >&2
    failures=$((failures + 1))
  fi
fi
```

Add this comment above `collect_entrypoint_claude_files()`:

```bash
# Only the three repo entrypoint CLAUDE.md files are policy-managed pointer shims.
# Brain-local CLAUDE.md files remain substantive boot docs and are intentionally excluded.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
pytest -q TRR-Backend/tests/scripts/test_check_policy.py
```

Expected:

- `3 passed`
- no stderr references to `TRR Workspace Brain/CLAUDE.md`
- no stderr references to `TRR Backend Brain/CLAUDE.md`
- no stderr references to `TRR App Brain/CLAUDE.md`

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add scripts/check-policy.sh TRR-Backend/tests/scripts/test_check_policy.py
git commit -m "test: harden entrypoint claude policy contract"
```

### Task 2: Convert Only The Three Entrypoint `CLAUDE.md` Files To Pointer Shims

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/CLAUDE.md`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/CLAUDE.md`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-APP/CLAUDE.md`

- [ ] **Step 1: Write the failing verifier**

Create `/tmp/trr-entrypoint-claude-verify.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

assert_file_equals() {
  local file="$1"
  local expected="$2"
  if [[ "$(cat "$file")" != "$expected" ]]; then
    echo "MISMATCH: $file" >&2
    diff -u <(printf '%s' "$expected") "$file" >&2 || true
    return 1
  fi
}

assert_file_differs() {
  local file="$1"
  local forbidden="$2"
  if [[ "$(cat "$file")" == "$forbidden" ]]; then
    echo "UNEXPECTED POINTER SHIM: $file" >&2
    return 1
  fi
}

ROOT_EXPECTED="$(cat <<'EOF'
# CLAUDE.md Pointer

Canonical instructions for this scope are in:
`/Users/thomashulihan/Projects/TRR/AGENTS.md`

Rules:
1. Read `AGENTS.md` first.
2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.
3. If there is any conflict, `AGENTS.md` is authoritative.
4. This file must remain a short pointer shim.
EOF
)"

BACKEND_EXPECTED="$(cat <<'EOF'
# CLAUDE.md Pointer

Canonical instructions for this scope are in:
`/Users/thomashulihan/Projects/TRR/TRR-Backend/AGENTS.md`

Rules:
1. Read `AGENTS.md` first.
2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.
3. If there is any conflict, `AGENTS.md` is authoritative.
4. This file must remain a short pointer shim.
EOF
)"

APP_EXPECTED="$(cat <<'EOF'
# CLAUDE.md Pointer

Canonical instructions for this scope are in:
`/Users/thomashulihan/Projects/TRR/TRR-APP/AGENTS.md`

Rules:
1. Read `AGENTS.md` first.
2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.
3. If there is any conflict, `AGENTS.md` is authoritative.
4. This file must remain a short pointer shim.
EOF
)"

assert_file_equals "/Users/thomashulihan/Projects/TRR/CLAUDE.md" "$ROOT_EXPECTED"
assert_file_equals "/Users/thomashulihan/Projects/TRR/TRR-Backend/CLAUDE.md" "$BACKEND_EXPECTED"
assert_file_equals "/Users/thomashulihan/Projects/TRR/TRR-APP/CLAUDE.md" "$APP_EXPECTED"

assert_file_differs "/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/CLAUDE.md" "$ROOT_EXPECTED"
assert_file_differs "/Users/thomashulihan/Projects/TRR/TRR-Backend/TRR Backend Brain/CLAUDE.md" "$BACKEND_EXPECTED"
assert_file_differs "/Users/thomashulihan/Projects/TRR/TRR-APP/TRR App Brain/CLAUDE.md" "$APP_EXPECTED"
```

Then make it executable:

```bash
chmod +x /tmp/trr-entrypoint-claude-verify.sh
```

- [ ] **Step 2: Run the verifier to confirm the current files fail**

Run:

```bash
/tmp/trr-entrypoint-claude-verify.sh
```

Expected: FAIL with `MISMATCH:` for at least one of the three entrypoint `CLAUDE.md` files because they still contain full router text instead of the pointer-shim template.

- [ ] **Step 3: Write the minimal implementation**

Replace `/Users/thomashulihan/Projects/TRR/CLAUDE.md` with:

```md
# CLAUDE.md Pointer

Canonical instructions for this scope are in:
`/Users/thomashulihan/Projects/TRR/AGENTS.md`

Rules:
1. Read `AGENTS.md` first.
2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.
3. If there is any conflict, `AGENTS.md` is authoritative.
4. This file must remain a short pointer shim.
```

Replace `/Users/thomashulihan/Projects/TRR/TRR-Backend/CLAUDE.md` with:

```md
# CLAUDE.md Pointer

Canonical instructions for this scope are in:
`/Users/thomashulihan/Projects/TRR/TRR-Backend/AGENTS.md`

Rules:
1. Read `AGENTS.md` first.
2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.
3. If there is any conflict, `AGENTS.md` is authoritative.
4. This file must remain a short pointer shim.
```

Replace `/Users/thomashulihan/Projects/TRR/TRR-APP/CLAUDE.md` with:

```md
# CLAUDE.md Pointer

Canonical instructions for this scope are in:
`/Users/thomashulihan/Projects/TRR/TRR-APP/AGENTS.md`

Rules:
1. Read `AGENTS.md` first.
2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.
3. If there is any conflict, `AGENTS.md` is authoritative.
4. This file must remain a short pointer shim.
```

- [ ] **Step 4: Run the verifier and policy check to verify they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
/tmp/trr-entrypoint-claude-verify.sh
bash scripts/check-policy.sh
```

Expected:

- `/tmp/trr-entrypoint-claude-verify.sh` exits `0`
- `bash scripts/check-policy.sh` prints `[check-policy] OK`

- [ ] **Step 5: Run Claude smoke checks for root, backend, and app scopes**

Run:

```bash
if ! command -v claude >/dev/null 2>&1; then
  echo "STOP: claude CLI is required for the entrypoint smoke checks"
  exit 1
fi

ROOT_OUT="$(cd /Users/thomashulihan/Projects/TRR && claude -p 'State the canonical instruction file for this scope. Answer with the absolute path only.')"
BACKEND_OUT="$(cd /Users/thomashulihan/Projects/TRR/TRR-Backend && claude -p 'State the canonical instruction file for this scope. Answer with the absolute path only.')"
APP_OUT="$(cd /Users/thomashulihan/Projects/TRR/TRR-APP && claude -p 'State the canonical instruction file for this scope. Answer with the absolute path only.')"

printf 'ROOT=%s\n' "$ROOT_OUT"
printf 'BACKEND=%s\n' "$BACKEND_OUT"
printf 'APP=%s\n' "$APP_OUT"

[[ "$ROOT_OUT" == *"/Users/thomashulihan/Projects/TRR/AGENTS.md"* ]]
[[ "$BACKEND_OUT" == *"/Users/thomashulihan/Projects/TRR/TRR-Backend/AGENTS.md"* ]]
[[ "$APP_OUT" == *"/Users/thomashulihan/Projects/TRR/TRR-APP/AGENTS.md"* ]]
```

Expected:

- each command prints one line containing the matching `AGENTS.md` absolute path
- none of the three checks exits non-zero

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add CLAUDE.md TRR-Backend/CLAUDE.md TRR-APP/CLAUDE.md
git commit -m "docs: align entrypoint claude files to policy shims"
```

### Task 3: Document The Entrypoint Contract And Verify Startup End-To-End

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/README_local.md`

- [ ] **Step 1: Write the failing check**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "entrypoint CLAUDE.md|pointer shims only for the three repo entrypoints" TRR-Backend/docs/README_local.md
```

Expected: no matches, which proves the operator-facing local README does not yet describe the scoped entrypoint-only `CLAUDE.md` contract.

- [ ] **Step 2: Run the check to verify it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
if rg -n "entrypoint CLAUDE.md|pointer shims only for the three repo entrypoints" TRR-Backend/docs/README_local.md; then
  echo "unexpected match"
  exit 1
else
  echo "missing scoped policy doc line as expected"
fi
```

Expected: `missing scoped policy doc line as expected`

- [ ] **Step 3: Write the minimal implementation**

Add this bullet under the `## make dev Runtime Reconcile` section in `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/README_local.md`:

```md
- Workspace policy treats `AGENTS.md` as the canonical instruction file for each repo entrypoint. Only `/TRR/CLAUDE.md`, `/TRR/TRR-Backend/CLAUDE.md`, and `/TRR/TRR-APP/CLAUDE.md` are validated pointer shims to `AGENTS.md`; the three `* Brain/CLAUDE.md` files remain substantive boot docs and are intentionally outside `scripts/check-policy.sh`.
```

- [ ] **Step 4: Run the verification commands**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n 'entrypoint CLAUDE.md|pointer shims only for the three repo entrypoints|intentionally outside' TRR-Backend/docs/README_local.md
pytest -q TRR-Backend/tests/scripts/test_check_policy.py
bash scripts/check-policy.sh
make preflight
```

Expected:

- the new README bullet is found
- the targeted pytest file passes
- `bash scripts/check-policy.sh` prints `[check-policy] OK`
- `make preflight` clears the policy phase and does not regress earlier startup checks

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/docs/README_local.md
git commit -m "docs: record entrypoint claude policy scope"
```
