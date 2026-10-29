# Instagram recovery controls

The existing v2 run API accepts a frozen account/date range. January is only a historical fixture. Intervals remain start-inclusive and end-exclusive; source profile and selected tasks remain bound to the run.

Normal local and Modal runs use the same resume/retry endpoints. Local resume/retry requires an online compatible Mac worker; it preserves the run's placement and injected validation policy. Offline status produces the existing service-unavailable error. Runtime holds, exhausted budgets, blocked identities and bounded recovery history are not cleared by ordinary controls. Backend allowed_actions remains the UI authority; the client must not suppress valid controls solely because placement is local.

Special bounded recovery continues through recover_run.py with explicit account, run ID, intent hash, generation and package manifest. Historical bounded runs require their latest predecessor evidence before any worker handover. A failed attempt does not reset its useful-progress clock. Authorization here is a persisted execution binding, not a repeated human approval requirement.

certify_run.py accepts an explicit account/date interval and verifies it against the frozen intent. Generic TRR_INSTAGRAM_RECOVERY_* configuration is supported; legacy JANUARY aliases remain compatible and conflicting aliases fail. New worker certification uses the actual frozen dates. Historical certificate field/version names remain unchanged for evidence compatibility.

Implementation and outstanding release/acceptance gates: [plan 056](../../plans/056-instagram-date-range-recovery.md).
