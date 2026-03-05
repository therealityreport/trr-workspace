#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AGENTS_FILES=(
  "$ROOT/AGENTS.md"
  "$ROOT/TRR-Backend/AGENTS.md"
  "$ROOT/TRR-APP/AGENTS.md"
  "$ROOT/screenalytics/AGENTS.md"
)

CLAUDE_FILES=(
  "$ROOT/CLAUDE.md"
  "$ROOT/TRR-Backend/CLAUDE.md"
  "$ROOT/TRR-APP/CLAUDE.md"
  "$ROOT/screenalytics/CLAUDE.md"
)

POLICY_SCAN_FILES=(
  "${AGENTS_FILES[@]}"
  "${CLAUDE_FILES[@]}"
  "$ROOT/docs/agent-governance/codex_skills.md"
  "$ROOT/docs/agent-governance/claude_skill_overlap.md"
  "$ROOT/docs/agent-governance/mcp_inventory.md"
)

failures=0

for file in "${AGENTS_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! rg -q '^## MCP Invocation Matrix' "$file"; then
    echo "[check-policy] ERROR: missing MCP matrix section in $file" >&2
    failures=$((failures + 1))
  fi
done

for file in "${CLAUDE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    continue
  fi

  line_count="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$line_count" -gt 20 ]]; then
    echo "[check-policy] ERROR: $file exceeds 20 lines ($line_count)." >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'AGENTS\.md' "$file"; then
    echo "[check-policy] ERROR: $file does not point to AGENTS.md." >&2
    failures=$((failures + 1))
  fi

  if ! rg -qi 'authoritative|conflict.*AGENTS\.md|AGENTS\.md.*wins' "$file"; then
    echo "[check-policy] ERROR: $file missing AGENTS authority/conflict rule." >&2
    failures=$((failures + 1))
  fi
done

if rg -n -i 'playwright' "${POLICY_SCAN_FILES[@]}" >/tmp/trr-policy-playwright-hits.txt; then
  if [[ -s /tmp/trr-policy-playwright-hits.txt ]]; then
    echo "[check-policy] ERROR: disallowed 'playwright' references found:" >&2
    cat /tmp/trr-policy-playwright-hits.txt >&2
    failures=$((failures + 1))
  fi
fi
rm -f /tmp/trr-policy-playwright-hits.txt

if [[ "$failures" -gt 0 ]]; then
  echo "[check-policy] FAILED with ${failures} issue(s)." >&2
  exit 1
fi

echo "[check-policy] OK"
