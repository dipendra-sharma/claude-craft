# Frontend / web bug — environment & version fields

Collect these for the **Environment** section. Ask for anything missing; assume
production unless the user says otherwise.

- **Browser + version** — Chrome 126, Safari 17.5, Firefox 127. Note if it's
  browser-specific ("only on Safari") — that's a huge clue.
- **OS** — macOS 14, Windows 11, iOS 17 (mobile Safari).
- **Device / viewport** — desktop vs. mobile web; screen size if it's a layout
  bug (e.g. "breaks below 768px").
- **App version / build** — release tag or commit SHA of the deployed frontend.
- **Environment** — production / staging / local, plus the **URL / route**
  where it happens.
- **User / role / auth state** — logged in vs. out, account type, feature flags,
  A/B bucket if relevant.

## Evidence worth capturing

- **Screenshot or screen recording** — for anything visual, this is non-negotiable.
- **Browser console errors** — copy the actual error text and stack.
- **Failing network request** — from the Network tab: URL, status, response body.
- **Steps that involve exact clicks/inputs** — the coupon code, the form values.

## Environment block example

```markdown
## Environment
- **URL:** https://app.example.com/checkout
- **Environment:** production
- **App version:** v3.4.1 (commit `9f8e7d6`)
- **Browser:** Chrome 126.0 (macOS 14.5)
- **Viewport:** desktop, 1440×900
- **User:** logged in, standard plan
```
