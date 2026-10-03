---
type: regex
target: { source: file, path: tests/test_cart.py }
pattern: '^(?=[\s\S]*self\.assertEqual\(total\(\[3, 4\]\), 7\))(?=[\s\S]*self\.assertEqual\(total\(\[10\], coupon=4\), 6\))'
---
