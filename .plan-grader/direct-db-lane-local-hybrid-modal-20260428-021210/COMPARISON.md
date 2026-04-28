# Comparison

## Summary

The new revision preserves the safety posture of the previous plan but adds a useful explicit hybrid mode. This answers the user's follow-up: Modal workers can be used with local direct DB as long as the remote DB lane remains session/pooler and direct secrets never cross process boundaries.

## Topic Table

| Topic | Prior revised | New revised | Delta | Reason |
|---|---:|---:|---:|---|
| A.1 Goal clarity | 9 | 9 | 0 | Adds mode matrix without weakening the default. |
| A.2 Repo/surface awareness | 8 | 9 | +1 | Names remote worker and Modal env separation as first-class surfaces. |
| A.3 Sequencing | 9 | 9 | 0 | Keeps dependency-safe sequence. |
| A.4 Specificity | 8 | 9 | +1 | Adds process-specific resolver and projection rules. |
| A.5 Verification | 9 | 9 | 0 | Adds hybrid tests but score was already strong. |
| B Coverage | 8 | 9 | +1 | Covers the direct+Modal workflow gap. |
| C Tooling | 8 | 8 | 0 | Still best as inline/sequential work. |
| D.1 | 2 | 2 | 0 | Same real blocker. |
| D.2 | 2 | 2 | 0 | Improved solution fit for user's desired workflow. |
| D.3 | 2 | 2 | 0 | Same measurable startup outcomes, plus hybrid. |
| D.4 | 2 | 2 | 0 | Added complexity is justified. |
| D.5 | 2 | 2 | 0 | Durable mode matrix. |
| E Safety | 9 | 9 | 0 | Keeps remote direct-URI stop rule. |
| F Scope | 8 | 8 | 0 | No scope creep into deployed direct lanes. |
| G Format | 5 | 5 | 0 | Still clear. |
| H Bonus | 3 | 4 | +1 | Hybrid mode is a meaningful operator workflow improvement. |

## Score Summary

- Prior revised estimate: 92 / 100
- New revised estimate: 94 / 100
