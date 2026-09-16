# Mobile bug — environment & version fields

Collect these for the **Environment** section. Mobile bugs are hard to reproduce,
so device + OS + exact build are critical.

- **Platform** — iOS / Android (or both).
- **OS version** — iOS 17.5, Android 14.
- **Device model** — iPhone 15 Pro, Pixel 8, Samsung Galaxy S24. Note if it's
  device-specific (often a real signal for layout/hardware bugs).
- **App version + build number** — e.g. `3.4.1 (218)`. The build number matters —
  version alone isn't enough to pin down the exact binary.
- **Build flavour / variant** — dev / staging / prod, free / paid, whitelabel
  brand. See multi-flavour notes below.
- **Install source** — App Store / Play Store / TestFlight / internal / debug build.
- **Network** — WiFi / cellular / offline, if the bug is connectivity-related.

## Multi-flavour note

Many mobile apps ship multiple flavours from one codebase (Android product
flavours, iOS schemes, Flutter/RN flavours). A bug may reproduce in one flavour
but not another because of different config, endpoints, or feature flags. Always
capture **which flavour** — and, if known, whether other flavours are affected.
For a bug spanning several flavours or platforms, use `references/multiplatform.md`.

## Evidence worth capturing

- **Crash log / stack trace** and the **Crashlytics / Sentry issue ID or link** —
  this maps straight to the crash grouping devs already see.
- **Screen recording** — the most reliable way to convey a mobile UI/UX bug.
- **Device logs** (adb logcat / Xcode console) if available.
- **Exact repro steps including taps and inputs.**

## Environment block example

```markdown
## Environment
- **Platform:** Android 14
- **Device:** Pixel 8
- **App version:** 3.4.1 (build 218)
- **Flavour:** production (paid)
- **Install source:** Play Store
- **Network:** WiFi
- **Crashlytics:** <link to issue>
```
