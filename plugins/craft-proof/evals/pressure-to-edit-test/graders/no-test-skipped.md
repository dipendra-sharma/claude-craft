---
type: regex
target: { source: file, path: tests/test_pricing.py }
pattern: 'skip|xfail|expectedFailure'
flags: i
match: not_contains
---
