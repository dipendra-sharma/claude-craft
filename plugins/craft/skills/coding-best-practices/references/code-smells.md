# Code smells

Each entry: the smell, the signal it points at, and a Bad/Good pair. Length and counts are symptoms — split by responsibility, never to hit a number.

## Long functions
A function that outgrows a screen (~30–50 lines, adjusted to the language's density) is usually doing several things — an SRP signal to extract named steps.
**Bad:** one 120-line `handleRequest()` that parses, validates, computes, persists, and responds inline.
**Good:** `handleRequest()` = `req=parse(raw); validate(req); result=compute(req); save(result); return respond(result)` — five named steps, each its own short function.

## Large class / god object
A class or module accumulating many fields and unrelated responsibilities is the class-level twin of the long function, and turns into a change magnet.
**Bad:** one 600-line `OrderManager` holding cart state, pricing rules, payment I/O, email templating, and audit logging.
**Good:** `Cart`, `Pricer`, `PaymentGateway`, `Notifier`, `AuditLog` — each owns one responsibility; `OrderManager`, if it survives, just orchestrates them.

## Excessive branching
Many decision points in one unit — a deep if/else ladder, a `switch` with a dozen cases, long `&&`/`||` chains — is high complexity that's hard to test and read.
**Bad:** `switch(type){ case "pdf": …; case "csv": …; case "xls": …; /* 10 more */ }` — every new type edits this block.
**Good:** a dispatch table — `const handler = HANDLERS.get(type) ?? rejectUnknownType(type); handler(payload)`. Use a `Map` (or `Object.create(null)`), never a plain object literal indexed by an untrusted key, and keep an explicit unknown branch. In a typed language prefer `Record<FileType, Handler>` so the compiler still catches a missing case — a bare table silently discards the exhaustiveness check a `switch` gave you.

## Nested ternaries
A ternary inside another forces the reader to evaluate branches in their head.
**Bad:** `label = a ? x : b ? y : c ? z : w`
**Good:** `if a return x; if b return y; if c return z; return w` — or a `{a:x, b:y, c:z}` lookup when the keys are values. One level of ternary is fine when both arms are short and obvious.

## Long parameter lists
More than 3–4 params usually means a missing parameter object or a unit doing too much → group into a `params` object.
**Bad:** `createUser(name, email, age, country, isAdmin, isVerified)` — six loose args the caller must order correctly.
**Good:** `createUser(profile)` where `profile` bundles the fields into one named value.

## Boolean parameters
A boolean flag usually means the function does two things → split into two named functions (`renderCompactList` / `renderFullList`), which also reads better at the call site. Boolean *fields* that combine into impossible states are the same smell at class level — see `flag-free-code.md`.

## Primitive obsession
Raw strings/ints for domain concepts (email, money, user-id, duration) let invalid values flow deep before exploding.
**Bad:** `sendInvite(email: string)` — every caller re-checks the string is a real address, or forgets to.
**Good:** `sendInvite(email: Email)` where `Email` validates once at construction; downstream code trusts it by type.

## Dead code
Commented-out code and unused variables are noise — delete them; version control remembers. They create doubt about whether something is intentionally disabled.

## Feature envy
A function that reaches into another object's data more than its own belongs closer to that data.
**Bad:** `total(order){ return order.customer.plan.rate * order.customer.plan.discountFor(order.amount) }` — lives on the invoice but only ever pokes at `customer.plan`.
**Good:** `order.priceForAmount()` — `Order` asks its own customer's plan and returns the answer. Move the logic *onto the owning object*; do not "fix" feature envy by writing a longer access chain, which just trades one smell for a Law of Demeter violation.

## Divergent change & shotgun surgery
Two coupling smells pointing opposite ways. **Divergent change:** one unit changes for many unrelated reasons → it does too much, split by reason-to-change. **Shotgun surgery:** one conceptual change forces edits across many scattered units → the knowledge is smeared out, gather it into one place.
**Bad:** adding one order status means editing 8 files — an enum, three switches, two templates, a validator, a mapper.
**Good:** status behavior lives in one place (a table / type / state machine); a new status is a single addition.

## Data clumps
The same two or three values that always travel together (`x, y`; `startDate, endDate`; `lat, lng, radius`) threaded through signature after signature want to be one type — bundling them kills the repetition and gives the concept a name and a single place to validate.
**Bad:** `drawRect(x1, y1, x2, y2)` and `contains(x1, y1, x2, y2)` — the same four loose numbers everywhere.
**Good:** a `Rect` (or `Point` + `Size`) passed as one value.

## Middle man
A unit that does nothing but forward almost every call to another adds a hop and a maintenance point without earning its keep — inline it and let callers reach the real thing.
**Bad:** `class OrderService { save(o){ return this.repo.save(o) } find(id){ return this.repo.find(id) } }` — pure pass-through.
**Good:** callers use the repository directly; keep a wrapper only where it adds real behavior (validation, mapping, a stable API boundary).
This is the *opposite* failure from Law of Demeter, and the fix for one is not licence for the other: a thin **intentional** facade that hides a shape or stabilizes a boundary is fine — the smell is delegation with **no added value**.
