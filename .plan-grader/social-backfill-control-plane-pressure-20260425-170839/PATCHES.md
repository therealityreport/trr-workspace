# Patches

## Patch 1: Add Browser-Use Runtime Benchmark Task

Added `Task 8: Browser-Use Runtime Method Benchmark and Default Selection` to the source plan.

Key additions:

- `TRR-Backend/scripts/socials/benchmark_backfill_runtime_methods.py`
- `TRR-Backend/tests/scripts/test_benchmark_backfill_runtime_methods.py`
- `docs/ai/benchmarks/social_backfill_method_comparison.md`
- Subagent A for Scrapling trial
- Subagent B for Crawlee trial
- Browser-use evidence required before any default change

## Patch 2: Prevent Unsupported-Platform False Comparisons

Added explicit instruction:

```text
If a platform has no Scrapling lane, record unsupported_by_current_code for that platform instead of inventing a fake comparison.
```

This matters because X/Twitter currently routes through the Twitter scraper/Crawlee adapter path, not a Twitter Scrapling lane.

## Patch 3: Replace Hard-Coded Crawlee Default With Evidence-Gated Defaults

Replaced the risky default example with:

```python
BENCHMARK_APPROVED_RUNTIME_DEFAULTS: dict[str, str] = {
    # Fill only with methods proven by docs/ai/benchmarks/social_backfill_method_comparison.md.
    # Example after evidence: "instagram": "scrapling" or "instagram": "crawlee".
}


def default_runtime_method_for_platform(platform: str) -> str:
    normalized = (platform or "").strip().lower()
    platform_override = os.getenv(f"SOCIAL_{normalized.upper()}_RUNTIME_METHOD")
    if platform_override:
        return platform_override.strip().lower()
    if normalized in BENCHMARK_APPROVED_RUNTIME_DEFAULTS:
        return BENCHMARK_APPROVED_RUNTIME_DEFAULTS[normalized]
    return os.getenv("SOCIAL_DEFAULT_RUNTIME_METHOD", "legacy").strip().lower()
```

## Patch 4: Renumber Verification and Acceptance

Moved final verification to Task 9 and added:

```text
Browser-use benchmark evidence exists for Scrapling and Crawlee in docs/ai/benchmarks/social_backfill_method_comparison.md, and any runtime default change matches the selected winner.
```

## Patch 5: Add Cleanup Note

Added the required Plan Grader cleanup note to the plan.
