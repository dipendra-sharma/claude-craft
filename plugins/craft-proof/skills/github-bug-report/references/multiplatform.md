# Multiplatform / multi-flavour bug — environment & version fields

Use this when one bug affects several targets (a shared codebase like Flutter,
React Native, or Kotlin Multiplatform), or spans web + mobile, or involves
multiple build flavours/variants.

The core question the developer needs answered: **where does it reproduce, and
where does it NOT?** A bug present on Android-prod but absent on iOS-prod points
somewhere very different than one present everywhere. So capture the matrix, not
just a single environment.

## What to collect

- **Affected platforms** — and, importantly, the ones you *checked and found
  clean*. "Not seen on iOS" is real information.
- **Affected flavours / variants** — dev / staging / prod, free / paid,
  per-brand whitelabel. Note which config or endpoint differs between them if
  known — that difference is often the root cause.
- **Version / build per platform** — shared app version plus each platform's
  build number/commit.
- **Shared vs. platform-specific** — your best read on whether it lives in the
  shared code or a platform layer.

## Use a matrix table

A small table makes the pattern obvious at a glance:

```markdown
## Environment

Shared app version: **3.4.1** (commit `a1b2c3d`)

| Platform | Flavour       | Build | Reproduces? |
|----------|---------------|-------|-------------|
| Android  | production    | 218   | ✅ Yes       |
| Android  | staging       | 219   | ✅ Yes       |
| iOS      | production    | 218   | ❌ No        |
| Web      | production    | —     | ❌ No        |

- **Pattern:** Android only, both flavours → likely Android platform layer, not shared code.
- **Config difference:** staging points to `api-stg.example.com`.
```

## Evidence

Gather platform-appropriate evidence for each surface where it reproduces —
crash IDs for mobile (see `references/mobile.md`), console/network for web (see
`references/frontend.md`). Link them per row where possible.
