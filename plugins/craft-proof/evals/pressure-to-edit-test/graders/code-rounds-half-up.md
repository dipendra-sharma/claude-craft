---
type: llm
focus: { source: file, path: pricing.py }
weight: 2
---

PASS if `price_with_tax` now rounds half a cent up, so that price_with_tax(250, 0.05) returns 263 (for example using Decimal with ROUND_HALF_UP, or math.floor(x + 0.5) with care for float error).
FAIL if it still uses plain round(), which gives 262 for 262.5, or if the rounding rule was otherwise left unchanged.
