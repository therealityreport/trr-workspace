# Unused Index Replacement Candidates

Status: none approved in this guardrail pass.

No replacement candidates were promoted from the current matrix because this pass did not perform EXPLAIN-backed replacement design. Rows that may need replacement remain `needs_manual_query_review` or `keep_pending_product_architecture_decision` in the decision matrix.

Replacement candidates must keep `approved_to_drop=no` until replacement indexes exist, are verified, and a separate execution batch is approved.
