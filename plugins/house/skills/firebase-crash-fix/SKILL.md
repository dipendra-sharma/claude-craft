---
name: firebase-crash-fix
description: >
  Fix Firebase Crashlytics crashes and ANRs on any mobile platform — Android (Kotlin/Java),
  iOS (Swift/ObjC), Flutter (Dart), React Native. MUST AUTO-TRIGGER on: Crashlytics issue,
  crash ID, Firebase crash link/URL, stack trace from Firebase console, 'fix this crash',
  'app is crashing', 'crash report', ANR report, 'this ANR', Crashlytics dashboard paste,
  any Firebase crash debugging request. Drives an evidence-first loop: gather every event,
  map the variants, trace backward to where the bad state started, reproduce it with a test
  that fails on the unfixed code, then apply the smallest fix and prove it. No guessing,
  no symptom patches. SKIP when: non-Firebase crash reports (use platform-native debugging),
  pre-release local crashes without Crashlytics, feature requests unrelated to crash debugging.
---

# Firebase Crash Fix

The crash tells you where execution **ended**. The bug is where the bad state **started**.
Those are almost never the same line, so every phase below pushes backward from the crash
site toward the origin — and nothing is called fixed until a test that failed on the unfixed
code passes on the fixed one.

Load `coding-best-practices` before writing fix code, and `testing-best-practices` when
writing the reproduction test. If the crash site is inside a third-party library, read
`references/third-party.md`.

## The loop

| Phase | Question it answers |
|-------|--------------------|
| 1 Gather | What actually happened, on which versions and devices? |
| 2 Map | One root cause or several? Which variants are in scope? |
| 3 Trace | Which assumption broke, and where did the bad value come from? |
| 4 Reproduce | Can I make it fail on demand, for the reason I predicted? |
| 5 Fix | What is the smallest change at the right layer? |
| 6 Verify | Is the bottom "why" now impossible? What is still open? |

Jumping from phase 1 to phase 5 is the failure this skill exists to prevent. A fix you cannot
make fail first is a guess wearing a diff.

---

## Phase 1 — Gather

**Coordinates.** From the user's message pull the `appId` and `issueId`
(`...apps/{appId}/issues/{issueId}`). The app segment of a Firebase console URL
(`android:com.example.app`) is the **package name, not the app ID** — call
`firebase_list_apps` and match by package/bundle to get the real one
(`1:PROJECT_NUMBER:platform:HEX`). If the project is unclear, read `google-services.json`,
`GoogleService-Info.plist`, or `firebase.json`. If the source directory is unclear, ask —
do not assume the working directory is the right repo. With only a vague description and no
issue ID or link, ask for one rather than guessing at an issue.

**Fetch in parallel:**

```
crashlytics_get_issue(appId, issueId)
crashlytics_list_notes(appId, issueId)
crashlytics_get_report(appId, "topVariants",         filter: { issueId })
crashlytics_get_report(appId, "topVersions",         filter: { issueId })
crashlytics_get_report(appId, "topAndroidDevices",   filter: { issueId })   // Android only
crashlytics_get_report(appId, "topOperatingSystems", filter: { issueId })
```

**Then the full event.** Responses carry a `sampleEvent` resource name; pass it to
`crashlytics_batch_get_events(appId, names: [sampleEvent])` for the complete record — stack
trace, all threads, breadcrumbs, custom keys, device, memory, build stamp.

**Then targeted events**, once you have seen the variants and versions:

```
crashlytics_list_events(appId, filter: { issueVariantId: "<id>" }, pageSize: 3)
crashlytics_list_events(appId, filter: { issueId, versionDisplayNames: ["3.12.4.0 (507)"] }, pageSize: 3)
```

Fetch the latest shipped version too — it tells you whether the crash is still live or was
already fixed by a later release.

### API rules that will otherwise cost you a round trip

- `list_events` `pageSize` **defaults to 1**. Always pass 3–5 or you get one event.
- `issueId` and `issueVariantId` are **mutually exclusive** in a `list_events` filter.
  Passing both errors with "Must specify 'filter.issueId' or 'filter.issueVariantId'".
- `topVariants` **requires** `issueId` in the filter. No other report does.
- Display names must be exact strings from a previous response:
  version `"3.12.4.0 (507)"`, OS `"Android (10)"`, device `"INFINIX MOBILITY LIMITED (Infinix X680D)"`.
- Omitting `intervalStartTime` defaults to 7 days. For a wider window compute
  **(currentDate − 80 days)** from the injected current date — never hardcode one. The API
  rejects anything older than 90 days.
- If `batch_get_events` fails with "Too many events in batchGet request" even for one event
  (known server-side bug), fall back to `list_events(appId, filter: { issueId }, pageSize: 5)`.

**Record before moving on** — exception type and message, crash site
`Class.method(File:line)`, platform, affected versions, device/OS pattern, the last few
breadcrumbs, and any custom keys or logs. Breadcrumbs are the user's actual path into the
bug; skipping them is why investigations stall.

---

## Phase 2 — Map the variants

One Crashlytics issue groups **variants** — distinct stack paths that landed on the same
signature. They do not have to share a root cause, and a fix that covers one may leave
another live. Write the map down:

```
Variant A: <crash site> — v3.12–v3.14, 412 users — same cause as B
Variant B: <crash site> — v3.10 only,   38 users — different: pre-migration data shape
Scope of this fix: A (highest impact). B tracked separately.
```

A variant confined to certain versions is a hint about *when* the bug entered — check git
history around that release before reading any further code.

---

## Phase 3 — Trace backward

Split the stack once: frames in your package are the investigation, `android.*`, `androidx.*`,
`java.*`, `UIKit.*`, `SwiftUI.*`, `dart:*`, `flutter/*` are the path that led there. Start at
the **first frame in your own code** and read every one of your frames before forming any
hypothesis — the top frame is where the problem was *detected*, rarely where it was *created*.

For each of your frames ask: what does this line assume is true, and what could make that
assumption false? Then follow the value:

```
crash at submit():88   → what does this line assume?
  ↑ onConfirm():54     → what did it pass in?
    ↑ ViewModel state  → where did that state come from?
      ↑ API parser     → was the field ever there?
```

Stop when you reach the **origin of the bad state**, not when you reach the layer that is
convenient to edit. The origin is usually a parser, a cache, or an async callback, not the
screen that crashed.

**Five Whys, written out.** If the first "why" hands you a null check, you have not finished:

```
Crash: NullPointerException on order.cart.total
Why 1: cart is null
Why 2: the Order was built without a cart
Why 3: the API response had no "cart" field
Why 4: the API omits cart while order status is "pending"
Why 5: our model declares cart non-optional — the contract was never modelled
Root cause: invalid assumption at the API model boundary.
```

**Then state the hypothesis before opening an editor** — what you believe, what you expect to
see in the code if it is true, and what would falsify it:

```
HYPOTHESIS: cart is null because pending orders arrive without the field and Order treats it as required.
EXPECT TO SEE: cart declared non-nullable; parser with no branch for a missing key.
FALSIFIED BY: nulls on confirmed orders too (→ wrong API call), or the field present but unparsed (→ parser bug).
```

Predicting first is what turns reading code into a test of the idea instead of a search for
something that looks wrong. Read the whole crashing file, its callers, the data layer that
produced the value, and the state holder if UI state is involved — then say plainly whether
the code confirmed or falsified the hypothesis. If two explanations remain equally plausible,
say so and name the evidence that would separate them rather than silently picking one.

For ANRs, `perfetto-trace-analysis` gives you thread detail beyond the Crashlytics dump.

---

## Phase 4 — Reproduce: the test must fail first

A test written after the fix, never seen to fail, proves nothing — it pins the code you just
wrote, not the bug you just found.

```
1. Write the test while the bug is still in the tree
2. Run it → it fails, with the failure you predicted
3. Apply the fix → it passes
4. Revert the fix, re-run → it fails again; restore the fix
```

Step 2 is the one that gets skipped. **Predict the failure message before running it.** If it
fails for a different reason than you predicted, the test is exercising something else and you
do not yet understand the crash. If it passes on the unfixed code, it is not testing the bug.

### When the crashing line is unreachable in a harness

Platform bugs, OEM ROMs, drivers and races often cannot be executed in a test. Do not retreat
to a happy-path test — move the assertion one step back, onto the decision that led into the
broken code:

| Cannot test | Assert this instead |
|---|---|
| Platform throws inside the OS/SDK | which OS/SDK entry point our code chose |
| Race between two threads | the ordering or guard that makes it impossible |
| Device-specific driver failure | our branch for that device/OS condition |
| Corrupt bytes from a remote | the parser given those same bytes |

### Cover the axis that selects the bug

If the crash needs one OS version, flavour, locale or form factor, the test must run across
that axis — the broken value **and** its neighbours. A single version pinned alone hides both
a regression and an over-broad fix. Use Robolectric `@Config(sdk = [...])` on Android, an
injected version check on iOS, a seam over the platform lookup in Flutter, a mocked
`Platform.Version` in React Native.

Keep the plain contract tests too — they pass before and after, which is fine; they document
behaviour. The test that failed in step 2 is the proof.

**Report numbers, not adjectives:** "without the fix, 1 failed at API 33,
`expected:<X> but was:<null>`; with the fix, 48 tests, 0 failures." Never write "fully tested"
without both. If the project has no test harness, say so plainly and state how you verified
instead — do not build a harness as part of a crash fix.

---

## Phase 5 — Fix the cause, not the symptom

The tell that you are patching a symptom: *"I'll just add a null check here and move on."*
A guard is sometimes exactly right — at a **boundary**. Ask first whether this value should
ever be invalid at this point. If it should not, the invalid value is a symptom and the bug
is upstream.

```
VALIDATE AT BOUNDARIES              FAIL FAST INTERNALLY
API responses, user input,          calls between your own classes,
SDK callbacks, disk/DB reads,       ViewModel → Repository → DB,
shared preferences                  state transitions, async handoffs
```

At a boundary, validate and return a typed error or a modelled empty state. Internally, let it
fail loudly — a corrupted-state app does more damage than a crashed one.

| Symptom fix | Root-cause fix |
|---|---|
| null-check and skip | model the field as optional; caller handles absence |
| catch `Exception`, swallow | catch the specific error, surface it to the caller |
| return an empty default | fail fast, expose the invalid state |
| retry on any error | detect the actual failure and recover for that case |

**Fix rules**

- **No feature changes in a crash fix.** Only: fix the bug, bump a dependency, or add a
  minimal guard. If it would not make sense as a hotfix, it does not belong here.
- No refactoring, cleanup, or new abstractions. Fix at the correct layer using patterns
  already present in the codebase. Change as few lines as possible.
- One change at a time — two at once and you cannot tell which one worked.
- Place a guard at the **tightest scope**, never at a higher layer that swallows the error.
- **New `try/catch` added as crash mitigation gets one comment naming the source and trigger:**
  `// Crash fix: <issueId> — <trigger>`. A silent catch with no context reads as dead
  defensive code, gets deleted in a later cleanup, and the crash comes back. This is the one
  comment this workflow requires; pre-existing error handling stays untouched.

**ANRs** — find the block, move it off the main thread:

| Platform | Typical blocker | Fix |
|---|---|---|
| Android | `runBlocking`, disk/DB/Binder on main | project's `DispatcherProvider` → `Dispatchers.IO` |
| iOS | sync network/disk on main, `DispatchQueue.main.sync` deadlock | global queue or `async/await` off the main actor |
| Flutter | heavy compute on the UI isolate | `compute()` or a dedicated `Isolate` |
| React Native | JS thread blocked by sync work | native module or `InteractionManager.runAfterInteractions` |

---

## Phase 6 — Verify and report

Answer all five, out loud:

1. Trace the Five Whys again — is the bottom "why" now impossible?
2. Handling the state or hiding it? Handling means the caller gets a typed error or a correct
   empty state and the UI reflects reality.
3. Does the crashing line still run with the same precondition? Then the fix is incomplete.
4. Does the happy path still work? Re-read the normal flow through the changed code.
5. Did the test fail before the fix? If not, it is documentation, not proof.

Then confirm the variant map: every variant you claimed to cover, covered; version-specific
variants fixed on the right branch; and anything still open stated explicitly, not omitted.

**Report:**

```
## Root Cause
<the origin, not the crash site — 1–2 sentences>

## What Was Happening
<user did X → state Y → assumption Z broke → crash — the Five Whys in plain language>

## Fix
<what changed and why it closes the root cause>

## Why This Approach
<why this over the alternative — e.g. model the field vs guard the call site>

## Proof
<pre-fix failure quoted; post-fix test counts>

## Scope
Resolved:   Variant(s) A, B — v3.12–v3.14
Still open: Variant C — different root cause, tracked separately
Branch:     <target branch; note if a live version needs a hotfix>
```

After the fix ships and is confirmed in production, you can close or mute the issue —
`crashlytics_update_issue(appId, issueId, state: "CLOSED" | "MUTED" | "OPEN")`. Never close
speculatively; a reopened issue loses the signal that it regressed.

---

## Anti-patterns

- Reading only the crashing method, or only the top frame
- Forming a hypothesis before reading the code, or picking one of two plausible causes silently
- Assuming the newest version introduced the bug without checking "first seen"
- Adding `?.let` / `guard let` / `?? []` without knowing why the value is absent
- A `try/catch` that swallows the exception, or one added without the crash-fix comment
- Guarding at a high layer when the contract broke at a lower one
- Fixing a base class without reading the subclasses it affects
- Upgrading several dependencies when one is implicated
- Calling a test proof when it was never seen to fail; testing only the one OS version in the
  report, so a fix cannot be told apart from a coincidence
