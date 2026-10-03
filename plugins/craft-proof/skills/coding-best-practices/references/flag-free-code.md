# Flag-free code, worked

Each entry: the flag shape, what it really is, and a Bad/Good pair in pseudocode. Render every pair in the user's own language — a sealed class in Kotlin or Dart, an enum with associated values in Swift or Rust, a discriminated union in TypeScript, a tagged tuple or dataclass union in Python. In a language with no closed types, a string or integer tag plus one constructor per case gets most of the benefit.

## Contents
- [Why flags rot](#why-flags-rot)
- [1. Mutually exclusive flags → one closed type](#1-mutually-exclusive-flags--one-closed-type)
- [2. A flag that mirrors other data → derive it](#2-a-flag-that-mirrors-other-data--derive-it)
- [3. `hasX` beside `x` → make `x` optional](#3-hasx-beside-x--make-x-optional)
- [4. A mode flag branched in many methods → choose the behaviour once](#4-a-mode-flag-branched-in-many-methods--choose-the-behaviour-once)
- [5. Lifecycle flags → valid at birth, or a new object per stage](#5-lifecycle-flags--valid-at-birth-or-a-new-object-per-stage)
- [6. Ordered steps → a state machine](#6-ordered-steps--a-state-machine)
- [7. Boolean parameters → split, or name the choice](#7-boolean-parameters--split-or-name-the-choice)
- [8. Feature switches → read once at the edge](#8-feature-switches--read-once-at-the-edge)
- [When a flag is the right answer](#when-a-flag-is-the-right-answer)
- [Arbitration with other principles](#arbitration-with-other-principles)

## Why flags rot

Every independent boolean doubles the number of states a class can be in. Three flags allow 8 combinations; usually 3 or 4 of them mean anything. The code must either handle the rest or hope they never happen — and they do, the day one setter is called without its partner. Flag bugs are rarely wrong logic; they are a combination nobody meant to allow.

The test for any flag: **can every combination of it with the other fields actually happen and mean something?** If yes, it is a real independent fact — keep it. If no, the type is allowing states the domain forbids, and one of the shapes below removes them.

## 1. Mutually exclusive flags → one closed type

**Bad:**
```
class Upload {
  isUploading: bool
  isDone: bool
  hasFailed: bool
  errorMessage: string?
  url: string?
}
```
`isUploading && isDone` compiles. `hasFailed` with a `url` compiles. Every reader must guess which fields are meaningful right now.

**Good:**
```
sealed Upload =
  | Uploading(progress: Percent)
  | Done(url: Url)
  | Failed(reason: string)
```
Exactly one state at a time, and each state carries only the data that exists in it. An exhaustive match makes the compiler list every place a new state must be handled.

The closed type only helps if the state-specific data moves into it. Keeping it beside the status quietly rebuilds the flag bag:

**Bad:**
```
class Job {
  status: Queued | Running | Failed | Done
  lastError: Error?
  attempts: int
}
```
`status = Failed` with `lastError = null` compiles again.

**Good:**
```
sealed JobState =
  | Queued(attempts, previousError: Error?)
  | Running(attempts, previousError: Error?)
  | Failed(attempts, error: Error)
  | Done(attempts, report)
```
`Failed` cannot exist without its error. When a value has to outlive its state — the last error still shown while a retry waits in the queue — carry it forward into the next state's data instead of parking it on the class. A fact that is meaningful in every state, like a running attempt count, may sit on each variant or beside the union; what must not sit beside it is data whose presence depends on which state you are in.

## 2. A flag that mirrors other data → derive it

**Bad:**
```
items: List<Item>
isEmpty: bool
total: Money
hasItems: bool
```
Four fields, two independent facts. The day someone appends to `items` and forgets `isEmpty`, they disagree.

**Good:**
```
items: List<Item>
isEmpty   = items.isEmpty()
total     = sum(items.price)
```
Store the fact; compute everything that follows from it. A computed property, getter, or selector costs nothing to keep in step.

## 3. `hasX` beside `x` → make `x` optional

**Bad:** `hasCoupon: bool` and `couponCode: string` — `hasCoupon = true` with an empty code is representable.
**Good:** `coupon: Coupon?` (or `Option<Coupon>`). Absence *is* the false case, and the type forces the reader to handle it.

## 4. A mode flag branched in many methods → choose the behaviour once

**Bad:**
```
class Exporter(isPdf: bool) {
  header()  { if isPdf pdfHeader()  else csvHeader() }
  row(r)    { if isPdf pdfRow(r)    else csvRow(r) }
  footer()  { if isPdf pdfFooter()  else csvFooter() }
}
```
The same `if` in every method: one class is really two, glued together by a flag.

**Good:**
```
interface Exporter { header(); row(r); footer() }
PdfExporter : Exporter
CsvExporter : Exporter

exporter = format == Pdf ? PdfExporter() : CsvExporter()
```
The decision happens once, where the object is built. Adding a third format adds a class instead of editing every method.

This passes the evidence gate for abstraction — the flag itself proves two real variants exist today. But scale the fix to the branching: when the flag is read in one or two places and the set of variants is closed, a sealed type with an exhaustive match is simpler and just as safe (see `solid.md`, the Open/Closed counterweight). Split into separate implementations when the same branch repeats across many methods.

## 5. Lifecycle flags → valid at birth, or a new object per stage

**Bad:**
```
class Client {
  isConnected: bool
  socket: Socket?
  connect()  { socket = open(); isConnected = true }
  send(msg)  { if !isConnected throw NotConnected; socket!.write(msg) }
  close()    { socket!.close(); isConnected = false }
}
```
Every method re-checks the flag, and one that forgets crashes on the force-unwrap.

**Good:**
```
connect(address) -> Connection
class Connection(socket: Socket) {
  send(msg)  { socket.write(msg) }
  close()    { socket.close() }
}
```
A `Connection` that exists is connected; there is nothing to check. For an expensive dependency the object needs later, a lazy value replaces `isInitialized`. Pair the release with the language's scope guard (see *Resource lifecycle*).

## 6. Ordered steps → a state machine

**Bad:** `isAddressEntered`, `isPaymentEntered`, `isConfirmed` on one `Checkout` — "confirmed with no payment" is a legal value.
**Good:**
```
sealed Checkout =
  | EnteringAddress
  | EnteringPayment(address)
  | Confirmed(address, payment)

next(EnteringAddress, AddressGiven(a))     -> EnteringPayment(a)
next(EnteringPayment(a), PaymentGiven(p))  -> Confirmed(a, p)
next(state, event)                         -> reject
```
The states make the bad combination unwritable; the transition function makes the bad *move* (jumping straight to `Confirmed`) unreachable. For a status stored in a database row, the transition guard also has to live in the write itself — that belongs to `backend-best-practices`.

## 7. Boolean parameters → split, or name the choice

**Bad:** `save(doc, true, false)` — nobody reading the call knows what either literal means, and inside, the function is two functions sharing an `if`.
**Good:** `saveDraft(doc)` and `publish(doc)` when the boolean picks between two behaviours. When it picks between more than two, or is a genuine setting rather than a behaviour switch, pass a named value: `save(doc, Visibility.Private)`. Named arguments (`save(doc, notify = false)`) are an acceptable lighter fix where the language has them and the function really does one thing with a tweak.

## 8. Feature switches → read once at the edge

A remote on/off switch for a rollout is a flag you can't design away. Keep it from spreading:

**Bad:** `if flags.newPricing` checked inside `calculateTotal`, `renderCart`, `applyCoupon` and `sendReceipt`.
**Good:** read the switch once where the object graph is built, and pick the implementation there: `pricer = flags.newPricing ? NewPricer() : LegacyPricer()`. Core logic never sees the switch, tests cover each implementation directly, and deleting the switch after rollout is a one-line change. Whether and how to gate a risky rollout is `backend-best-practices`.

## When a flag is the right answer

- **A genuinely independent fact.** Every combination with the other fields is valid: `isMuted` on a player, `isChecked` on a checkbox, a form's `wasSubmitted`. Wrapping one of these in a sealed type or a state machine is ceremony with no state removed.
- **A derived boolean handed to someone else.** Passing a list row `isSelected` instead of the whole `selectedId` is a computed parameter, not stored state, and is the right shape for render cost.
- **A boundary format you don't own.** An API or file format with `"is_active": true` stays a boolean on the wire; convert it into your own type when you read it in, if the combinations matter.

## Arbitration with other principles

- **YAGNI and KISS.** Remove flags that let impossible states exist; don't add a type, a hierarchy, or a state machine around a single independent boolean.
- **Evidence-gated abstraction.** Splitting a mode flag into implementations is justified by the variants the flag already encodes. A lone interface with one implementation is still speculative.
- **Scope discipline.** In a review or an edit, change a bag of flags only when it is in the code you were asked to touch and its combinations cause, or plausibly cause, a real bug. Otherwise mention it separately.
- **Siblings.** Loading, error and data flags on one screen are `ui-state-best-practices`. A `status` column and its allowed transitions are `backend-best-practices`. Phantom types and smart constructors as named patterns are `design-patterns-best-practices`. This file owns the general rule for classes, functions, and modules.
