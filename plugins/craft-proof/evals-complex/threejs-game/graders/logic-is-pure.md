---
type: regex
target: { source: file, path: src/logic.js }
pattern: 'from\s+["'']three|Math\.random\s*\(|Date\.now\s*\(|\bdocument\.|\bwindow\.'
match: not_contains
---
