# VALIDATION

## files inspected

- `/Users/thomashulihan/Projects/TRR/.plan-grader/unused-index-full-decision-review-20260428-064550/REVISED_PLAN.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.csv`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-advisor-review-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/unused-index-owner-review-2026-04-28/`
- `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`
- `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/skills/revise-plan/SKILL.md`
- `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/SKILL.md`

## commands run

```bash
git status --short --branch
```

Result: current branch is `chore/workspace-batch-2026-04-28`; dirty state includes unrelated modified files and untracked artifact packages/scripts.

```bash
python3 - <<'PY'
import csv
from collections import Counter
p='docs/workspace/unused-index-advisor-review-2026-04-28.csv'
with open(p, newline='') as f:
    rows=list(csv.DictReader(f))
print('rows', len(rows))
print('review_status', dict(Counter(r['review_status'] for r in rows)))
print('approved_to_drop', dict(Counter(r['approved_to_drop'] for r in rows)))
PY
```

Result:

- rows: `1302`
- `review_status`: `drop_review_required=258`, `excluded=777`, `defer:idx_scan_nonzero=267`
- `approved_to_drop`: all `no`

```bash
test -f /Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md && echo rubric-present
```

Result: rubric exists.

## evidence gaps

- The source universe mismatch remains: owner request says `1,324`, current CSV says `1,302`.
- No live DB queries were run during this Plan Grader revision.
- The validator and scanner are plan requirements only; they are not implemented during this planning-only revision.

## recommended validation before execution

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short --branch
```

Expected: no unresolved conflicts and no unclassified dirty files in target surfaces.

```bash
cd /Users/thomashulihan/Projects/TRR
python3 - <<'PY'
import csv
from collections import Counter
p='docs/workspace/unused-index-advisor-review-2026-04-28.csv'
with open(p, newline='') as f:
    rows=list(csv.DictReader(f))
print(len(rows))
print(Counter(r['review_status'] for r in rows))
PY
```

Expected: counts either match the owner-supplied target or the corrected target universe is owner-approved and recorded.

## validation conclusion

The requested suggestions are integrated as required plan changes or non-blocking guardrails. Execution remains blocked until Phase 0 resolves the current report-universe mismatch and dirty-worktree state.
