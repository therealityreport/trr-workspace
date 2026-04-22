# Global Brain Vault Bootstrap Improvement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up `/Users/thomashulihan/brain` as the always-on persistent-memory vault for new Claude Code and Codex CLI sessions from any directory, with safe backup/rollback behavior and Obsidian registration.

**Architecture:** Keep this as a narrow home-directory bootstrap, not a repo feature. Install only missing prerequisites, scaffold the vault directly in `/Users/thomashulihan/brain`, merge the current personal Codex global rules into the new vault bootloader, then repoint `/Users/thomashulihan/.claude/CLAUDE.md` and `/Users/thomashulihan/.codex/AGENTS.md` to that single source of truth. Gate the high-risk home-global rewiring with behavioral smoke tests from `/tmp/brain-smoke`, and only touch Obsidian state after Claude and Codex both prove they can see the new vault.

**Tech Stack:** macOS shell commands, Homebrew, npm global CLIs, Python 3 standard library (`json`, `pathlib`, `shutil`, `uuid`), git, Obsidian desktop, Claude Code CLI, Codex CLI.

---

## Scope

This plan covers:

1. Installing any missing prerequisites on macOS.
2. Creating `/Users/thomashulihan/brain` and its bootstrap files.
3. Preserving the existing `/Users/thomashulihan/.codex/AGENTS.md` rules inside the new vault.
4. Replacing the Claude and Codex global entrypoints with symlinks to `/Users/thomashulihan/brain/CLAUDE.md`.
5. Proving the new memory auto-loads from a throwaway directory before Obsidian registration.
6. Registering `/Users/thomashulihan/brain` as an Obsidian vault without clobbering existing vaults.

This plan does not cover:

- Cursor wiring. Cursor is intentionally skipped in this pass.
- Editing `/Users/thomashulihan/.codex/config.toml` or `/Users/thomashulihan/.claude/settings.json`.
- Adding extra automation, sync, or backup tooling beyond the requested setup and the minimum rollback safety.

## File Structure

- Create: `/Users/thomashulihan/brain/CLAUDE.md`
  - Canonical vault bootloader for Claude Code and Codex CLI.
- Create: `/Users/thomashulihan/brain/me.md`
  - User-editable profile template with TODO placeholders.
- Create: `/Users/thomashulihan/brain/debug-history.md`
  - Empty one-line gotcha log file.
- Create: `/Users/thomashulihan/brain/.gitignore`
  - Ignores `sessions/` and `.loom-backup/`.
- Create: `/Users/thomashulihan/brain/AGENTS.md`
  - Symlink to `/Users/thomashulihan/brain/CLAUDE.md`.
- Modify: `/Users/thomashulihan/.claude/CLAUDE.md`
  - Replace the existing empty file with a symlink to the vault bootloader.
- Modify: `/Users/thomashulihan/.codex/AGENTS.md`
  - Back up the existing file, then replace it with a symlink to the vault bootloader.
- Modify: `/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json`
  - Merge `/Users/thomashulihan/brain` into the `vaults` map after Claude and Codex smoke tests pass.

## Acceptance Targets

- `brew`, `git`, `rg`, `claude`, and `codex` resolve from the shell.
- `brew list --cask obsidian` succeeds after installation.
- `/Users/thomashulihan/brain/CLAUDE.md` exists and contains both the requested vault rules and the preserved Codex global rules.
- `/Users/thomashulihan/brain/AGENTS.md` resolves to `/Users/thomashulihan/brain/CLAUDE.md`.
- `/Users/thomashulihan/.claude/CLAUDE.md` and `/Users/thomashulihan/.codex/AGENTS.md` resolve to `/Users/thomashulihan/brain/CLAUDE.md`.
- Running `codex exec` from `/tmp/brain-smoke` mentions `GLOBAL VAULT — ~/brain`.
- Running `claude -p` from `/tmp/brain-smoke` mentions `GLOBAL VAULT — ~/brain`.
- `obsidian.json` contains exactly one vault entry whose path is `/Users/thomashulihan/brain`.
- Final summary prints `Cursor          skipped`.

### Task 1: Preflight The Machine And Install Missing Prerequisites

**Files:**
- Modify: `/Users/thomashulihan/.claude/CLAUDE.md`
- Modify: `/Users/thomashulihan/.codex/AGENTS.md`

- [ ] **Step 1: Run the preflight check before changing anything**

Run:

```bash
mkdir -p /tmp/brain-smoke
{
  printf 'OS=%s\n' "$(uname -s)"
  for cmd in brew git rg obsidian claude codex npm node; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '%s=MISSING\n' "$cmd"
    fi
  done
  printf 'git_user_name=%s\n' "$(git config --global user.name 2>/dev/null || true)"
  printf 'git_user_email=%s\n' "$(git config --global user.email 2>/dev/null || true)"
  for path in \
    "/Users/thomashulihan/brain" \
    "/Users/thomashulihan/.claude/CLAUDE.md" \
    "/Users/thomashulihan/.codex/AGENTS.md" \
    "/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json"
  do
    if [ -e "$path" ] || [ -L "$path" ]; then
      printf 'EXISTS %s\n' "$path"
      /usr/bin/stat -f 'type=%HT mode=%Sp' "$path"
    else
      printf 'MISSING %s\n' "$path"
    fi
  done
} | tee /tmp/brain-smoke/preflight.txt
```

Expected:

- `OS=Darwin`
- `/Users/thomashulihan/brain` is missing
- `/Users/thomashulihan/.claude/CLAUDE.md` exists
- `/Users/thomashulihan/.codex/AGENTS.md` exists
- `obsidian=MISSING`

- [ ] **Step 2: Install only the missing prerequisites**

Run:

```bash
command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
command -v git >/dev/null 2>&1 || brew install git
command -v rg >/dev/null 2>&1 || brew install ripgrep
command -v npm >/dev/null 2>&1 || brew install node
brew list --cask obsidian >/dev/null 2>&1 || brew install --cask obsidian
command -v claude >/dev/null 2>&1 || npm install -g @anthropic-ai/claude-code
command -v codex >/dev/null 2>&1 || npm install -g @openai/codex
```

Expected: every command completes without reinstalling tools that are already present.

- [ ] **Step 3: Stop immediately if git identity is still missing**

Run:

```bash
if [ -z "$(git config --global user.name 2>/dev/null)" ] || [ -z "$(git config --global user.email 2>/dev/null)" ]; then
  echo "STOP: git config --global user.name and user.email must be set before continuing"
  exit 1
fi
printf 'git_user_name=%s\n' "$(git config --global user.name)"
printf 'git_user_email=%s\n' "$(git config --global user.email)"
```

Expected: both values print. If either is empty, stop here and ask the user once before continuing.

- [ ] **Step 4: Re-run the tool-resolution check and confirm the machine is ready**

Run:

```bash
{
  for cmd in brew git rg claude codex; do
    printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
  done
  brew list --cask obsidian >/dev/null 2>&1 && echo "obsidian_cask=INSTALLED"
} | tee /tmp/brain-smoke/prereqs-ready.txt
```

Expected: every CLI prints a path and `obsidian_cask=INSTALLED` appears.

### Task 2: Create The Brain Vault And Write The Merged Bootloader

**Files:**
- Create: `/Users/thomashulihan/brain/CLAUDE.md`
- Create: `/Users/thomashulihan/brain/me.md`
- Create: `/Users/thomashulihan/brain/debug-history.md`
- Create: `/Users/thomashulihan/brain/.gitignore`
- Create: `/Users/thomashulihan/brain/AGENTS.md`

- [ ] **Step 1: Create the vault directories and initialize git**

Run:

```bash
mkdir -p /Users/thomashulihan/brain/{patterns,decisions,sessions,handoffs,.obsidian}
cd /Users/thomashulihan/brain
git init
```

Expected: `.git/` exists inside `/Users/thomashulihan/brain`.

- [ ] **Step 2: Write the canonical bootloader with the preserved Codex rules**

Run:

```bash
cat > /Users/thomashulihan/brain/CLAUDE.md <<'EOF'
# GLOBAL VAULT — ~/brain
This is my global persistent memory. Every agent (Claude Code, Codex CLI) boots from this file.

## ON BOOT — read ONLY these
- this file
- me.md

## ON DEMAND — grep/cat these when a task needs them
- patterns/        reusable solutions I've hit before
- decisions/       non-obvious choices and why
- debug-history.md one-line log of gotchas with dates
- handoffs/        cross-session letters

## WRITE RULES
- Append to sessions/YYYY-MM-DD-<your-agent-name>.md as you work.
- Never edit another agent's session log.
- Propose a pattern or decision capture only after the same thing has come up TWICE.
- Keep every note in patterns/ and decisions/ under 30 lines. Split if longer.
- Never read more than the most recent session log unless I explicitly ask.

## INHERITANCE
- Project and workspace bootloaders extend this file; their rules add to mine, they do not replace.

## PRESERVED GLOBAL CODEX PREFERENCES
# User Codex preferences

Use this file only for personal, cross-project preferences.
Do not put project-specific policy, repo instructions, or workspace-specific MCP settings here.
Keep user-level and system-level MCPs, plugins, and skills available by default across projects unless I explicitly disable them.
Project-local policy should resolve overlap through routing and ownership, not by suppressing unrelated user-global capabilities.
EOF
```

Expected: `/Users/thomashulihan/brain/CLAUDE.md` exists, stays under 200 lines, and contains `GLOBAL VAULT — ~/brain`.

- [ ] **Step 3: Seed `me.md`, `debug-history.md`, and `.gitignore`**

Run:

```bash
cat > /Users/thomashulihan/brain/me.md <<'EOF'
# ME
## Stack
- languages: TODO
- frameworks: TODO
- tooling: TODO
## Style
- how I like code organized: TODO
- what I hate: TODO
## Recurring gotchas
- TODO
## Current focus
- TODO
EOF

: > /Users/thomashulihan/brain/debug-history.md

cat > /Users/thomashulihan/brain/.gitignore <<'EOF'
sessions/
.loom-backup/
EOF
```

Expected:

- `me.md` contains the requested TODO template
- `debug-history.md` exists and is empty
- `.gitignore` contains exactly two lines

- [ ] **Step 4: Create the in-vault `AGENTS.md` symlink and verify the scaffold**

Run:

```bash
ln -sfn /Users/thomashulihan/brain/CLAUDE.md /Users/thomashulihan/brain/AGENTS.md
python3 - <<'PY'
from pathlib import Path
for path in [
    Path("/Users/thomashulihan/brain/CLAUDE.md"),
    Path("/Users/thomashulihan/brain/AGENTS.md"),
    Path("/Users/thomashulihan/brain/.obsidian"),
    Path("/Users/thomashulihan/brain/.gitignore"),
]:
    print(f"{path} exists={path.exists()} is_symlink={path.is_symlink()}")
if Path("/Users/thomashulihan/brain/AGENTS.md").is_symlink():
    print("AGENTS_RESOLVES_TO=" + str(Path("/Users/thomashulihan/brain/AGENTS.md").resolve()))
PY
```

Expected: `AGENTS_RESOLVES_TO=/Users/thomashulihan/brain/CLAUDE.md`.

### Task 3: Rewire Claude And Codex With Backup And Rollback Safety

**Files:**
- Modify: `/Users/thomashulihan/.claude/CLAUDE.md`
- Modify: `/Users/thomashulihan/.codex/AGENTS.md`

- [ ] **Step 1: Back up the existing Codex global file and print the backup path**

Run:

```bash
CODEX_BACKUP="/Users/thomashulihan/.codex/AGENTS.md.pre-brain-$(date +%Y%m%d-%H%M%S).bak"
cp /Users/thomashulihan/.codex/AGENTS.md "$CODEX_BACKUP"
printf '%s\n' "$CODEX_BACKUP" > /tmp/brain-smoke/codex-backup-path.txt
printf 'CODEX_BACKUP=%s\n' "$CODEX_BACKUP"
```

Expected: `CODEX_BACKUP=/Users/thomashulihan/.codex/AGENTS.md.pre-brain-...` prints and the backup file exists.

- [ ] **Step 2: Replace the Claude global entrypoint with a symlink**

Run:

```bash
mkdir -p /Users/thomashulihan/.claude /Users/thomashulihan/.codex
rm -f /Users/thomashulihan/.claude/CLAUDE.md
ln -sfn /Users/thomashulihan/brain/CLAUDE.md /Users/thomashulihan/.claude/CLAUDE.md
```

Expected: `/Users/thomashulihan/.claude/CLAUDE.md` is now a symlink.

- [ ] **Step 3: Replace the Codex global entrypoint with a symlink**

Run:

```bash
rm -f /Users/thomashulihan/.codex/AGENTS.md
ln -sfn /Users/thomashulihan/brain/CLAUDE.md /Users/thomashulihan/.codex/AGENTS.md
```

Expected: `/Users/thomashulihan/.codex/AGENTS.md` is now a symlink.

- [ ] **Step 4: Verify the symlink targets before any behavioral smoke test**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
for path in [
    Path("/Users/thomashulihan/.claude/CLAUDE.md"),
    Path("/Users/thomashulihan/.codex/AGENTS.md"),
]:
    print(f"{path} exists={path.exists()} is_symlink={path.is_symlink()} resolved={path.resolve()}")
PY
```

Expected: both resolved paths equal `/Users/thomashulihan/brain/CLAUDE.md`.

- [ ] **Step 5: Run the behavioral smoke tests from a throwaway directory**

Run:

```bash
mkdir -p /tmp/brain-smoke

codex exec \
  --skip-git-repo-check \
  -C /tmp/brain-smoke \
  "State the exact title of the global instructions or memory file you loaded for this session. If you know the path, print that too." \
  | tee /tmp/brain-smoke/codex-smoke.txt

(cd /tmp/brain-smoke && claude -p "State the exact title of the global instructions or memory file you loaded for this session. If you know the path, print that too.") \
  | tee /tmp/brain-smoke/claude-smoke.txt
```

Expected: both outputs contain `GLOBAL VAULT — ~/brain`.

- [ ] **Step 6: Roll back and stop immediately if either smoke test does not mention the vault**

Run:

```bash
if ! rg -q "GLOBAL VAULT — ~/brain" /tmp/brain-smoke/codex-smoke.txt || ! rg -q "GLOBAL VAULT — ~/brain" /tmp/brain-smoke/claude-smoke.txt; then
  CODEX_BACKUP="$(cat /tmp/brain-smoke/codex-backup-path.txt)"
  rm -f /Users/thomashulihan/.codex/AGENTS.md
  cp "$CODEX_BACKUP" /Users/thomashulihan/.codex/AGENTS.md
  echo "ROLLBACK: restored /Users/thomashulihan/.codex/AGENTS.md from backup"
  exit 1
fi
```

Expected: no output on success. If either smoke test fails, stop here and do not touch Obsidian state.

### Task 4: Register `/Users/thomashulihan/brain` With Obsidian Safely

**Files:**
- Modify: `/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json`

- [ ] **Step 1: Launch Obsidian once, then quit it**

Run:

```bash
open -a Obsidian
sleep 4
osascript -e 'quit app "Obsidian"'
```

Expected: `/Users/thomashulihan/Library/Application Support/obsidian` exists after this step.

- [ ] **Step 2: Merge the brain vault into `obsidian.json` without clobbering existing keys**

Run:

```bash
BRAIN_TS="$(date +%Y%m%d-%H%M%S)" python3 - <<'PY'
import json
import os
import shutil
import uuid
from pathlib import Path

brain_path = "/Users/thomashulihan/brain"
obsidian_json = Path("/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json")
obsidian_json.parent.mkdir(parents=True, exist_ok=True)

if not obsidian_json.exists():
    data = {"vaults": {}}
else:
    raw = obsidian_json.read_text()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        backup = obsidian_json.with_name(f"{obsidian_json.name}.pre-brain-{os.environ['BRAIN_TS']}.bak")
        shutil.copy2(obsidian_json, backup)
        raise SystemExit(f"STOP: malformed obsidian.json backed up to {backup}")

vaults = data.get("vaults")
if not isinstance(vaults, dict):
    vaults = {}
    data["vaults"] = vaults

already_present = any(
    isinstance(entry, dict) and entry.get("path") == brain_path
    for entry in vaults.values()
)
if not already_present:
    vault_id = uuid.uuid4().hex
    vaults[vault_id] = {"path": brain_path}

obsidian_json.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
print(obsidian_json)
PY
```

Expected: the script exits successfully and preserves every existing top-level key in the JSON file.

- [ ] **Step 3: Verify there is exactly one brain vault entry**

Run:

```bash
python3 - <<'PY'
import json
from pathlib import Path

obsidian_json = Path("/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json")
data = json.loads(obsidian_json.read_text())
matches = [
    (vault_id, entry.get("path"))
    for vault_id, entry in data.get("vaults", {}).items()
    if isinstance(entry, dict) and entry.get("path") == "/Users/thomashulihan/brain"
]
print(matches)
print(f"MATCH_COUNT={len(matches)}")
PY
```

Expected: `MATCH_COUNT=1`.

### Task 5: Run Final Verification And Print The Completion Summary

**Files:**
- Modify: `/Users/thomashulihan/brain/CLAUDE.md`
- Modify: `/Users/thomashulihan/.claude/CLAUDE.md`
- Modify: `/Users/thomashulihan/.codex/AGENTS.md`
- Modify: `/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json`

- [ ] **Step 1: Run the final verification checklist**

Run:

```bash
{
  for cmd in brew git rg claude codex; do
    printf '[ok] %s -> %s\n' "$cmd" "$(command -v "$cmd")"
  done
  brew list --cask obsidian >/dev/null 2>&1 && echo "[ok] Obsidian cask installed"

  python3 - <<'PY'
from pathlib import Path
checks = [
    Path("/Users/thomashulihan/brain/CLAUDE.md"),
    Path("/Users/thomashulihan/brain/.obsidian"),
    Path("/Users/thomashulihan/brain/.git"),
    Path("/Users/thomashulihan/.claude/CLAUDE.md"),
    Path("/Users/thomashulihan/.codex/AGENTS.md"),
    Path("/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json"),
]
for path in checks:
    print(f"[path] {path} exists={path.exists()} is_symlink={path.is_symlink()}")
print("[resolve] brain_AGENTS=" + str(Path("/Users/thomashulihan/brain/AGENTS.md").resolve()))
print("[resolve] claude=" + str(Path("/Users/thomashulihan/.claude/CLAUDE.md").resolve()))
print("[resolve] codex=" + str(Path("/Users/thomashulihan/.codex/AGENTS.md").resolve()))
PY
} | tee /tmp/brain-smoke/final-checks.txt
```

Expected: every path exists and all three symlink resolves point at `/Users/thomashulihan/brain/CLAUDE.md`.

- [ ] **Step 2: Re-check that Obsidian lists the brain vault exactly once**

Run:

```bash
python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(Path("/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json").read_text())
brain_entries = [
    entry for entry in data.get("vaults", {}).values()
    if isinstance(entry, dict) and entry.get("path") == "/Users/thomashulihan/brain"
]
print(f"OBSIDIAN_BRAIN_VAULTS={len(brain_entries)}")
PY
```

Expected: `OBSIDIAN_BRAIN_VAULTS=1`.

- [ ] **Step 3: Print the final summary table**

Run:

```bash
cat <<'EOF'
COMPONENT       STATUS
Homebrew        installed
git             installed
ripgrep         installed
Obsidian        installed
Claude Code     installed
Codex CLI       installed
Cursor          skipped
~/brain vault   ready
Agent wiring    ready
Obsidian reg.   ready
EOF
```

Expected: the table prints exactly once, with `Cursor          skipped`.

- [ ] **Step 4: Print the user closeout instruction**

Run:

```bash
cat <<'EOF'
Next thing I should do as the user: open /Users/thomashulihan/brain/me.md in Obsidian and fill in the TODOs. After that, open a new Claude Code or Codex CLI session from any folder and it will auto-load this memory.
EOF
```

Expected: the closeout instruction matches the requested wording and path.

## Self-Review

- Spec coverage: this revision adds the audit-required smoke-test gate, explicit backup and rollback behavior for `/Users/thomashulihan/.codex/AGENTS.md`, duplicate-safe Obsidian merging, malformed-JSON stop handling, and a final output table that marks Cursor as skipped.
- Placeholder scan: no unresolved `TBD`, `implement later`, or symbolic task references remain in the execution path. The only TODO text is the intentional user-facing content inside `/Users/thomashulihan/brain/me.md`.
- Type and path consistency: the canonical bootloader path is `/Users/thomashulihan/brain/CLAUDE.md` in every task; the Obsidian registry path is `/Users/thomashulihan/Library/Application Support/obsidian/obsidian.json` in every task; Cursor remains explicitly out of scope throughout.
