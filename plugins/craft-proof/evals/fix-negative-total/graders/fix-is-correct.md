---
type: llm
focus: { source: file, path: cart.py }
weight: 2
---

PASS if `total(prices, coupon)` can no longer return a negative number when the coupon is larger than the sum of prices (for example it returns 0), while a coupon smaller than the sum is still subtracted normally.
FAIL if a coupon larger than the cart can still produce a negative total, or if normal subtraction was broken.
