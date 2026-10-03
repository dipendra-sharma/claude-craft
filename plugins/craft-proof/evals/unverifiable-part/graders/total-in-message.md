---
type: llm
focus: { source: file, path: confirmation.py }
---

PASS if `confirmation_text(order_id, total_cents)` includes the total formatted in dollars with two decimals, so 1250 cents appears as $12.50.
FAIL if the total is missing or formatted differently.
