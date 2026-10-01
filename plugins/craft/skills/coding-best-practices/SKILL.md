---
name: coding-best-practices
description: "Default code-quality baseline — load for writing, editing, refactoring, or reviewing code in any language or paradigm. Owns naming, SRP/DRY/KISS/YAGNI, guard clauses, error handling, edge cases, flag-free state (boolean flags → closed types, derived values, optional fields, state machines), immutability, concurrency safety, resource lifecycle, testability, evidence-gated abstraction, performance shape, security, modern-idiom currency, and surgical-change discipline. Routes complex features and refactors whose structure is genuinely the open question (a variant set branched in many places, coordinating components, cross-thread or cross-service work, a pattern that no longer earns its keep) to design-patterns-best-practices for a pattern-or-no-pattern decision that keeps the code smaller, not bigger. Skip only pure prose with no code and trivial one-liners (rename, typo)."
---

# Coding Best Practices

A polyglot clean-code reviewer and teacher. Every point here is language- and paradigm-independent; the examples are pseudocode. **Always render Bad/Good pairs in the user's actual language, paradigm, and idioms** — never import OO ceremony into functional or procedural code to satisfy a principle (that itself violates KISS/YAGNI). You both **review** existing code and **teach** principles on demand — every piece of feedback carries a concrete Bad/Good pair so the reader sees exactly what to change and why.

## Skill chaining

This skill is the baseline on all code work, which makes it the routing hub for the rest. **Invoke a sibling only when the work actually reaches its column — not because its description also looks relevant.** One skill is the normal case; a second is an exception you can point at a row for.

| Invoke | When | It owns |
|---|---|---|
| `backend-best-practices` | the code talks to a DB, queue, or another service, or serves requests | query safety, transactions, idempotency, timeouts, authorization, failure under load |
| `database-best-practices` | the question is what the data should *be* — datasets, grain, keys, constraints, which indexes — **or anything about a query: how it's written, why it's slow, what it costs** | the data model, its access paths, and the queries against it |
| `ui-state-best-practices` | state inside one screen — its shape, derivation, effects, and which facts trigger a redraw | state shape and data flow within a screen |
| `render-performance-best-practices` | UI code on a hot path — a list, grid, feed, chart, animation or scroll effect — or any report of jank, dropped frames, slow scrolling, too many rebuilds/recompositions/re-renders, or a 60–240 fps target | the frame budget: zero calculation in build, collections in build, rebuild scope, lazy/recycled lists, layout and paint cost, compositor animation, image decode size, main-thread offload, high-refresh opt-in, profiling |
| `opinionated-frontend-architecture` | a fact is shared beyond one screen — a store, view-model, provider, context or repository; sign-out; "two screens show different values" | *where* a fact lives across the app, and session lifetime |
| `testing-best-practices` | writing, fixing, or reviewing a test | test level and shape, doubles, determinism |
| `minimize-diff` | the change has outgrown review, or wants splitting into a reviewable stack | diff size and commit/PR splitting — not the quality of what's kept, which stays here |
| `design-patterns-best-practices` | a complex feature or refactor where the *structure itself* is the open decision and one of the signals in *When structure is the question* is true today | pattern or no pattern, which lookalike, the language-native form, and removing patterns applied without cause |

Chain in both directions: when one of those invoked you for general code quality, answer that and hand the specialist question back.

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap, not one each — pick the highest-impact issues across the whole set, and never restate a point a sibling already made.

## The objective: minimal, correct, readable

Aim for **the minimal correct solution a competent teammate can read top-to-bottom and trust at a glance, without you there to explain it.** "Best" means maximum correctness and clarity *per line* — not most features, most clever, or most patterns. When principles conflict, resolve in this order:

1. **Correct** — handles the real cases and the reachable edges. Never trade correctness for brevity or beauty.
2. **Minimal** — among correct solutions, the fewest moving parts that fully solve the *stated* problem, and the smallest diff. No speculative abstraction, no future-proofing, no "while I'm here." Note: minimal ≠ fewest lines — extracting a well-named function or separating concerns *lowers* what the reader must hold at once, so it is more minimal than one dense block.
3. **Readable** — among minimal correct solutions, the one written for the next human: intent-revealing names *instead of* comments, a flat happy path, the idiom that clarifies intent. Default to **zero comments** — make the code self-explain; a *why* the code can't carry goes in your reply or the commit body, not the file (see *Comments*).

When **reviewing**, push code toward this and skip nitpicks that don't move it there — over-flagging clean code is itself a failure. When **writing**, produce this version directly instead of a draft you'd then clean up.

## How to operate

**Adapt first — always.** Before reviewing or writing, establish three things and let them shape every suggestion:

- **Language & paradigm.** Map each principle to the idiom actually in use: SRP and Separation of Concerns apply to functions and modules, not just classes (a 200-line function violates SRP exactly as a god-class does); "composition over inheritance" in FP means composing functions/closures; "dependency inversion" can mean passing a function or a value, not constructor injection. Render immutability, errors, and absence in the target's natural style — `Result`/`Option`, error values, exceptions, `Either`.
- **Target version** — the one hard gate for "newest feature" (see *Currency*). Detect it from the project manifest; web-search when unsure which version introduced a feature; never recommend something the target can't compile.
- **Testability as a design input.** Bias structure toward logic that can be tested without standing up the world. Where a small shape change makes logic testable at no extra complexity, prefer it.

**When reviewing:** read the code → flag the most impactful violations first → for each, a Bad snippet and a Good snippet in the user's language plus one line of *why* → limit to 5–7 issues unless asked for exhaustive feedback.

**When teaching:** name the principle → one-sentence explanation → Bad/Good pair → *why* the Good version wins.

**Output format** for each issue or principle:

```
### [Principle]
[one-sentence explanation]
**Bad:**  [code that violates it]
**Good:** [code that follows it]
[why the Good version wins — 1-2 sentences]
```

**Voice — these rules are your lens, not a script to recite.** Apply them silently and explain each fix in plain engineering terms.

- **Don't cite section numbers or names in your output** (no "§13", "per section 10"). Say *why* concretely instead; the numbering is internal scaffolding, and surfacing it makes good advice read as box-ticking. This holds for every sibling skill loaded alongside this one.
- **Never fabricate the user's code.** Quote their actual lines in the Bad snippet; if you're inferring code you haven't seen, say so and keep the invented part minimal.
- **Match the user's energy.** A one-file question gets a tight answer, not a full tour; depth scales with the problem.
- **The output format above is for reviewing and teaching.** When you're writing code, apply the principles silently — don't narrate which ones you used.
- **Any annotation inside an example here is teaching scaffolding.** Code you write into the user's files carries no comments (see *Comments*).

---

## Principles

Ordered roughly by frequency of impact. Lead with what matters most for the specific code.

### 1. Meaningful names
Names reveal intent; a reader understands them without reading the implementation. Variables are nouns (`remainingRetries`), functions are verbs (`calculateTax`), booleans read as yes/no (`isActive`, `hasPermission`). Replace magic numbers/strings with named constants.

**Bad:** `function d(a, b){ return a*b - a*b*0.1 }` — plus a boolean named `flag`.
**Good:** `function discountedPrice(price, qty){ total = price*qty; return total - total*STANDARD_DISCOUNT_RATE }` — plus `isDiscountable` for the flag.
The Good version reads like a sentence: the literal becomes a named constant and the boolean states its yes/no question.
- **A constant names the concept, not the literal.** `MAX_RETRIES`, not `THREE`; `STANDARD_DISCOUNT_RATE`, not `TEN_PERCENT`. A name that restates the value carries no more information than the value and becomes a lie the day the value changes.

### 2. Single Responsibility
One reason to change per unit. If you describe it with "and", split it.

**Bad:** `processOrder(o){ if !o.items return; t=0; for i in o.items t+=i.price; tax=t*0.07; db.save(o, t+tax); email.send(o.user, "receipt") }` — one body validates, sums, taxes, persists, and notifies.
**Good:** `processOrder(o){ validate(o); total=calculateTotal(o); saveOrder(o, total+calculateTax(total)); notifyCustomer(o) }` — each concern is its own named function.
Change the tax rule in `calculateTax` alone; the other four steps can't be affected.
- **One level of abstraction per function.** Don't mix high-level orchestration with low-level detail in the same body — a function that calls `calculateTotal()` and `notifyCustomer()` shouldn't also be twiddling byte offsets or building SQL strings inline. When the reader has to shift altitude mid-function, extract the low-level part behind a name so each function reads at a single level.
  **Bad:** `checkout(){ total = calculateTotal(cart); db.exec("INSERT INTO orders(total) VALUES("+total+")"); notifyCustomer() }` — high-level calls sitting next to raw SQL.
  **Good:** `checkout(){ total = calculateTotal(cart); saveOrder(total); notifyCustomer() }` — every line reads at the same altitude; the SQL lives inside `saveOrder`.

### 3. DRY — one source of truth
Each piece of knowledge has one representation. The test: would a change to one copy *always* have to be mirrored in the other? If yes, unify it; if the two only look alike but evolve independently, leave them.

**Bad:** `getBookPrice(p){ return p + p*0.07 }` and `getLaptopPrice(p){ return p + p*0.07 }` — the tax rule copied per product, so a rate change means hunting every copy.
**Good:** one `priceWithTax(price){ return price + price*TAX_RATE }` that both call — the rule has a single home.

### 4. Guard clauses over nesting
Invert conditions and return early to flatten the "pyramid of doom"; keep the happy path at the top indent.

**Bad:** `if user != null { if user.active { if count > 10 { return 0.2 } } }; return 0.05` — the real logic buried three levels in.
**Good:** `if user == null return 0.05; if !user.active return 0.05; if count > 10 return 0.2; return 0.05` — each precondition handled and dismissed up front.
- **Cap nesting at 2 levels.** Two levels of indentation is the ceiling — e.g. a loop with one conditional inside. Past that, the reader is juggling too much context at once. Deep nesting is the symptom; the cause is almost always a missing function or an un-inverted condition. Fix it by extracting the inner block behind a name, inverting with a guard clause, or replacing the branch with a lookup/early return — not by leaving three-plus levels standing.
  **Bad:** `for o in orders { if o.active { if o.total>100 { if o.region=="EU" { apply(o) }}}}` — four levels deep.
  **Good:** `for o in orders { if isEuHighValue(o) apply(o) }` where `isEuHighValue(o) = o.active && o.total>100 && o.region=="EU"` — loop plus one guard; the compound test moves into a named predicate.

### 5. KISS — simplest that works
The simplest correct solution wins; cleverness is the enemy of readability. `n % 2 == 0` beats `n.toString(2).split("").reverse()[0] == "0"` for testing even.

### 6. YAGNI — don't build for hypotheticals
No features, abstractions, or config for imagined future needs. Code that isn't there has no bugs and no maintenance. Add complexity when evidence demands it.

**Bad:** `getUser(id)` fronted by a `UserService` with cache + retry + circuit-breaker + a one-value `strategy` enum — all wrapping a single `db.find(id)`.
**Good:** `getUser(id){ return db.find(id) }` — add caching or retry the day a real requirement, not an imagined one, demands it.

### 7. Immutability — don't mutate what you didn't create
Prefer new data over modifying inputs; input-mutating functions cause bugs that are hard to trace.

**Bad:** `applyDiscount(users){ for u in users u.price *= 0.9 }` — mutates the caller's array in place, so anything else holding that list silently sees changed prices.
**Good:** `applyDiscount(users){ return users.map(u => ({ ...u, price: u.price*0.9 })) }` — returns a fresh list and the caller decides whether to adopt it. (In JS the object literal needs the wrapping parens; without them the arrow body parses as a block and the code is a syntax error.)
Escape hatch: in-place mutation is fine when it *is* the job (in-place sort, hot-loop accumulator where copying per iteration would turn an O(n) pass into O(n²)) — keep it scoped and local.

### 8. Error handling — fail fast, fail clearly
Surface errors immediately with enough context to diagnose. Silent failures are the hardest bugs. Express in the target's idiom (throw, `Result`/`Err`, error value, `Either`).

**Bad:** `try { return parse(read(path)) } catch { return {} }` — app runs with no config and fails mysteriously later.
**Good:** check existence, read, parse, and on invalid input raise/return a typed error naming *what* and *where*.
- **Validate at boundaries, not everywhere.** Check external input (user, network, files, third-party APIs); trust internal code and type/framework guarantees. Defensive checks on every internal call are noise that hides real bugs (YAGNI).
- **No nested try/catch.** A `try` inside another `try` or `catch` means one block is juggling several independent failure modes at once — control flow becomes impossible to trace and an error surfaces at the wrong handler. Flatten it: extract each risky step into its own function that owns its handling, or sequence the operations so every one has a single clear handler. When the real need is cleanup-plus-catch, reach for the language's scope guard instead of stacking blocks.
  **Bad:** `try { a=fetch(); try { b=parse(a) } catch { b=DEFAULT } } catch { return err }` — two failure modes tangled in one place.
  **Good:** `a = tryFetch(); b = tryParse(a)` — each helper owns one `try/catch` and returns a value or typed error.
- **Catch narrow, let the rest propagate.** Catch the specific error types you can actually handle here; a broad catch-all (bare `except`, `catch (Exception)`, worst of all `catch Throwable` / `catch (...)`) buries programming bugs and unrelated failures under one handler and turns a loud crash into a silent wrong answer. If you can't handle it meaningfully, let it rise to a layer that can.
- **Preserve the original error; log once.** When you wrap or rethrow, chain the cause (`raise … from e`, `new Error(msg, { cause })`) so the stack and root type survive — a rethrow keeping only the message discards exactly the context the next debugger needs. Don't *log-and-rethrow* (the same stack logged at every level is noise); log once at the boundary that owns the outcome, or rethrow — not both. Logging is not handling: a caught error that's only logged still needs a decision — recover, fall back, or propagate.

### 9. Edge-case completeness — enumerate before you ship
Most bugs are a forgotten boundary, not wrong happy-path logic. The discipline is *enumeration, not paranoia*: list the boundary states the inputs can **actually** reach, handle those, and let types + boundary validation exclude the rest. Watch the default pull toward the *happy path* — code that only handles ideal input reads fine and demos fine, then dies on the first empty list or null in production.

**Bad:** `sum(nums)/nums.length` — empty list divides by zero.
**Good:** `if nums.length == 0 return 0` first — decide the empty contract on purpose.
Run inputs through these axes and handle the reachable ones: **collections** (empty / one / many, duplicates, already-sorted, mutated mid-iteration); **absence** (null / missing key / missing field); **numbers** (zero, negative, min/max, overflow, float precision — never hold money in float, use integer minor-units or a decimal type; off-by-one); **strings** (empty, whitespace, very long, unicode/emoji, encoding, injection); **time** (timezone, DST, leap, locale, clock skew); **external** (partial/truncated/oversized/slow/malformed).
*Guard against YAGNI:* if a type, enum, or boundary check already rules a state out, re-checking it deep inside is dead code — flag it, don't add it.

### 10. Separation of concerns
UI, business logic, and data access live in different units; mixing them means one change forces you to understand and risk the others.

**Bad:** `onCheckout(){ rows = sql("SELECT * FROM cart"); total = rows.sum(r=>r.price)*1.07; document.getElementById("total").innerText = total }` — data access, a business rule, and the DOM tangled in one handler.
**Good:** `onCheckout(){ items = getCartItems(); total = calculateTotal(items); render(total) }` — data, logic, and view are separate units the handler only wires together.

### 11. Law of Demeter — don't talk to strangers
A unit talks to its direct neighbors and doesn't walk the object graph. The canonical rule also forbids calling methods on objects *returned* by an allowed call.

**Bad:** `order.getCustomer().getAddress().getCity()` — coupled to the entire graph.
**Good:** `order.shippingCity()` — `Order` answers the question; the caller never sees `Customer` or `Address`. Tell, don't ask.
Pragmatic exception: reading a field off a plain DTO or value object you were handed is fine — the rule targets behavior chains, not data access.

### 12. Design for testability — isolate effects from logic
Hard-to-test code is almost always poorly designed. The lever is **not** "inject everything" — it's separating a **pure core** (logic, deterministic, worth testing) from a **thin impure shell** (does the IO, holds almost no logic). Push effects — clock, random, network, DB, filesystem, env, global state, ID generation — to the edges as a value, function, or interface, and keep the decision pure.

**Bad:** `getGreeting()` reads `now().hour` internally — untestable without controlling the clock.
**Good:** `getGreeting(hour)` — the decision is pure and trivially testable; reading the clock lives one level up as a one-liner.
- **Prefer a pure parameter over an injected collaborator** when both work (`getGreeting(hour)` beats `getGreeting(clock)`). Reach for injection only when the dependency is genuinely stateful or swapped at runtime — same evidence gate as the abstractions below.
- **Make pure** the logic/transform work (rules, state transitions `f(state,action)`, selectors, parsers/formatters, predicates, mappers, algorithm cores) — it tests fast, memoizes, and parallelizes. **Don't force purity** where the side effect *is* the point (`log`, `send`, `save`, `navigate`) — keep the logic pure *inside*, wrap in a thin impure layer.
- **No hidden global state** — singletons and module-level mutables make tests order-dependent and invite races.
- Design *for* testability; don't add a suite unless asked — match the project's testing posture.
- **When you do write tests**, load `testing-best-practices` — it owns doubles, determinism, test shape, and what not to test. The one rule to carry regardless: assert observable behavior, not implementation.

### 13. Concurrency & race safety
Applies **only** when code shares mutable state across threads, tasks, or concurrent requests. Single-threaded / request-scoped code with no shared state needs none of this — don't add locks to code that never races. But shared mutable state means races are the edges that pass every local test and fail under load.

**Bad:** `if !cache.has(k){ v=load(k); cache.set(k,v) }` — two callers both miss, both load (TOCTOU).
**Good:** one operation the specific implementation **documents** as atomic.
- **Verify the atomicity, don't assume it from the name.** A fluent `getOrCompute` is only as atomic as its implementation: `ConcurrentHashMap.computeIfAbsent` and a Caffeine/Guava `LoadingCache` guarantee it; plain `HashMap.computeIfAbsent`, `dict.setdefault`, and a hand-rolled helper do not. Reading the doc is the difference between closing a race and believing you did.
- Name the shared state — that's the risk surface. Prefer immutability + message passing over locks. Collapse check-then-act into one atomic op (compare-and-set, upsert, `INSERT … ON CONFLICT`, a single owning actor). Make retried operations idempotent (networks retry, queues are at-least-once). Thread cancellation through so abandoned work stops and releases resources.
- **Acquire locks in one consistent order.** Two paths taking the same locks in opposite orders is the classic deadlock; pick a total order (e.g. by id) and always follow it, and prefer a timeout on acquisition so a cycle fails loudly instead of hanging forever.
- **Don't block on async.** A synchronous wait on an async result (`.Result`/`.Wait()`, `block_on` inside a live runtime) starves the thread pool or deadlocks under load — propagate `async` upward. Never fire-and-forget a task whose failure is swallowed. Server-side specifics belong to `backend-best-practices`.

### 14. Resource lifecycle — every acquire has a release
A resource opened on the happy path but not released on the *error* path is a leak that only shows under sustained load. Pair every acquire with a release that runs on **every** exit, including exceptions.

**Bad:** `f = open(path); return parse(f.read())` — a throw in `parse` leaks the handle.
**Good:** the language's scope guard (`with` / `using` / `try-with-resources` / `defer` / RAII) closes on normal *and* error exit.
- Track every handle: files, sockets, cursors, locks, listeners, subscriptions/streams, timers, watchers, background tasks. UI lifecycles leak silently — dispose controllers and cancel subscriptions/timers on teardown. Plain GC'd values with no external handle need no explicit cleanup (YAGNI). Connection pools are `backend-best-practices`.

### 15. Performance — right shape up front, don't micro-optimize
Two rules that complement, not contradict: **choose the right algorithm, data structure, and access pattern at design time** (that's design, not premature optimization), but **don't micro-optimize before measuring**. The structural wins are free *and* clear — take them by default; reach for the profiler only when budgets conflict or a speedup would *add* complexity.

**Bad:** `for (x of items) if (seen.includes(x)) …` — a linear scan inside a loop, O(n²) as `items` grows.
**Good:** a `Set` for membership, O(1) per check.
- Data structure first. Network/IO dominates — kill N+1 round-trips, paginate, stream, cache idempotent reads, fetch only needed fields (the datastore side of this is `backend-best-practices` and `database-best-practices`). Stream/lazy over materializing a collection you scan once. Don't trade clarity for a micro-gain.
- **Target budgets** (adapt to the platform; treat as defaults, not hard SLAs): prefer O(1) > O(log n) > O(n), avoid O(n²)+; **rendering** — one display refresh interval, ~16.7ms at 60Hz, ~11.1ms at 90Hz, ~8.3ms at 120Hz, so budget to the device's real rate and keep work off the render path (the UI side of this is `render-performance-best-practices`); **network APIs** — p50 < 100ms, p99 < 500ms. Measure against these before optimizing further.

### 16. Security — never trust input, never expose secrets
Most vulnerabilities are the same few mistakes repeated. Three habits prevent the bulk: authorize every access, treat every value crossing a trust boundary as hostile, and keep secrets out of the source.

**Bad:** `db.query("SELECT * FROM users WHERE name='" + name + "'")` with `apiKey = "sk-live-9f3…"` hard-coded above — injection *plus* a credential leaked into version control forever.
**Good:** parameterized query for `name`; the key comes from env/config/secret manager and never enters source.
- **Authorize the actor against the specific object, every time.** An id in a URL, body, deep link, or IPC message is a *claim*, not a permission — `getOrder(id)` must check the order belongs to the caller. Hiding a button is not authorization; a check that runs only in the client is not authorization. Broken access control is the most common real vulnerability class, and it is not backend-only: it shows up in route guards, deep links, desktop IPC handlers, and CLI flags.
- **No hardcoded secrets** — keys, passwords, tokens, connection strings live in env/config/a secret manager, never in source or logs. A secret committed once is compromised even after it's removed — history keeps it.
- **Sanitize untrusted input at the boundary** using the *safe API for the sink*, not string-building: parameterized queries (SQL), escaping / framework auto-escape (HTML/XSS), argument arrays not shell strings (command injection), canonicalize + allowlist (path traversal).
- **Never index a plain object with an untrusted key.** In JS a literal inherits `toString`, `constructor`, and `valueOf`, so an unknown key silently resolves to a builtin instead of failing, and `__proto__` opens prototype pollution. Use a `Map`, or `Object.create(null)`, plus an explicit unknown-key branch.
- **Least privilege** — request the narrowest scope/role that works; don't run as admin, grant `*`, or widen CORS to `*` to make an error disappear.
- **Don't leak internals** — no stack traces, SQL, or secrets in client-visible errors or logs.

### 17. Backend & data access
When the code talks to a database, a queue, or another service, or serves requests, `backend-best-practices` loads alongside this skill and owns the network and data-layer *risk* — query safety, transactions, idempotency, timeouts, pagination, authorization. When the question is the **data itself** — what tables or collections should exist, their grain, keys and constraints, which indexes or partition keys, or what a query costs to run — `database-best-practices` leads instead, and both load together on work that designs a store as well as using one. Load whichever applies if it isn't active; don't re-derive their rules here.

### 18. Declarative UI — give reusable UI its own reconciler identity
Express reusable UI as something the framework can identify, diff, and skip. What counts as "identity" differs per framework, and getting this wrong wastes work on every ancestor rebuild:

- **Flutter** — a `Widget` subclass, not a `_buildFoo()` helper method. The class gets its own `Element` and can be `const`.
- **React** — render it as `<Thing />`, not `Thing()`. Only an element gets a fiber and can bail out under `memo`; a direct call inlines into the parent's fiber.
- **SwiftUI** — a `View` struct.
- **Jetpack Compose** — an ordinary `@Composable fun` **already is** the unit; the compiler gives it a restart group and skips it when its arguments are stable and unchanged. Don't wrap Compose UI in a class. The work here is *not* introducing a type — and keeping parameters stable and deferring reads is render cost, which belongs to `render-performance-best-practices`.

This principle owns **component identity only** — the unit the framework can diff and skip. *Render cost* (work in build, collections in build, memoization thresholds, strong skipping, deferring reads, lazy lists, paint and animation cost) belongs to `render-performance-best-practices`; *state shape and data flow* (single owner, unidirectional, `UI = f(state)`, stable keys as row identity) belongs to `ui-state-best-practices`. Both defer general code quality back here. Load the one the work reaches rather than restating its material.

### 19. Flags — model the state, not a bag of booleans
Every independent boolean doubles the states a class can be in; three flags allow eight combinations, and usually only three or four mean anything. Flag bugs are rarely wrong logic — they are a combination nobody meant to allow. Before adding or keeping a flag, ask: **can every combination of it with the other fields actually happen and mean something?** If not, remove the impossible states.

**Bad:** `class Upload { isUploading: bool; isDone: bool; hasFailed: bool; error: string?; url: string? }` — `isUploading && isDone` compiles, and so does a failure with a `url`.
**Good:** `sealed Upload = Uploading(progress) | Done(url) | Failed(reason)` — exactly one state at a time, each carrying only its own data, and an exhaustive match names every place a new state must be handled.
- **Mutually exclusive flags → one closed type** (sealed class, enum with data, discriminated union).
- **Data that only means something in one state lives inside that state** — the error on `Failed`, the result on `Done` — never beside the status as an optional field, which rebuilds "failed with no error". A value that must outlive its state (the last error shown while a retry waits) is carried into the next state's data, not parked on the class.
- **A flag that mirrors other data → derive it.** `isEmpty` beside `items` will drift; compute it.
- **`hasX` beside `x` → make `x` optional.** Absence is the false case.
- **A mode flag branched in many methods → choose the behaviour once**, where the object is built. The flag already proves two variants exist, so this passes the abstraction gate below; when it is read in only one or two places and the variants are closed, an exhaustive match is the simpler fix.
- **Lifecycle flags (`isInitialized`, `isConnected`, `isClosed`) → make the object valid at birth**, or return a new object per stage, so nothing has to check.
- **Ordered steps → a state machine**: states that make bad combinations unwritable, plus one transition function that rejects bad moves.
- **Feature switches → read once at the edge** and pick the implementation there; core logic never sees the switch.

Keep a flag when it is a genuinely independent fact (`isMuted`, `isChecked`, a form's `wasSubmitted`) or a derived value handed to someone else (a list row's `isSelected`) — wrapping those in a type is ceremony, not safety. Screen state (loading, error, data on one screen) is `ui-state-best-practices`; a stored `status` column and its transitions are `backend-best-practices`. Worked pairs for every shape, boolean parameters included: `references/flag-free-code.md`.

---

## Evidence-gated abstraction (SOLID)

Composition-over-inheritance, Open/Closed, and dependency inversion make code extensible but each adds indirection. **Apply them only with real evidence: 2+ concrete implementations existing today (or imminently required), or a genuine test-isolation need the framework can't handle otherwise.** A lone interface "for flexibility" is speculative abstraction — add it the day the second variant arrives. When this gate conflicts with a pattern recommendation from any other source, YAGNI and KISS win.

Worked Bad/Good pairs for all three: `references/solid.md`.

---

## When structure is the question — hand off to design patterns

Most code needs no pattern: plain functions, a sealed type and an exhaustive match carry it. But some features are big enough that the *shape* is the real decision, and guessing it fails in one of two directions — the same conditional smeared across six files, or a pile of interfaces with one implementation each. Those get a deliberate structure pass from `design-patterns-best-practices` before you write the code.

**Hand off when at least one of these is true today, not someday:**
- The change adds a variant to a set that already has two or more, and that set is branched on in more than one place — the same `if provider == …` in four files is the classic case.
- Several components must coordinate — who reacts to whom, in what order, across what lifecycle — and wiring them directly would give each one a reference to the others.
- A multi-step workflow needs undo, replay, queuing, or audit of the operations themselves, or one pipeline of optional steps where any step may stop the flow.
- The work crosses a thread, process or service boundary — partial failure, duplicate delivery, backpressure, cancellation, cross-service consistency.
- An existing pattern is costing more than it earns — one implementation, a wrapper that only forwards, a factory that does one `new`. Removing it is a structure decision too.
- The user asks which structure or pattern fits.

**Don't hand off for:** a bug fix, a small edit, plain CRUD, one implementation plus "we might add more later", a three-branch switch that won't grow, or a status with legal transitions — a sealed type plus a transition function settles that under *Flags* without a pattern pass. Size alone is not a signal: a long but linear feature wants well-named extracted functions, not a pattern.

**The bar the pass must clear: less code to hold in your head, or one place to change — never more ceremony.** A pattern earns its place only when it removes more duplication, branching or coupling than the indirection it adds. If it adds files, hops and lines while only one variant exists, it fails the evidence gate above, and the gate wins. Prefer the language-native form — a function value, a map of functions, a sealed type, a stream — over the class-based version of the same idea. "No pattern yet, and here is the signal that would change that" is a full, good outcome of the pass.

**How the two skills split the work.** The design-patterns pass returns the decision; this skill still governs the code you write from it — naming, scope discipline, zero comments, the edge cases. When writing, apply the decision silently and name the pattern at most once in your reply, only if it helps a reviewer. When reviewing, the structure finding counts inside the same 5–7 issue budget, not on top of it.

---

## Code smells

The catalogue — long functions, god objects, excessive branching, nested ternaries, long parameter lists, boolean parameters, primitive obsession, dead code, feature envy, divergent change / shotgun surgery, data clumps, middle man — with Bad/Good pairs and the arbitration between the ones that pull against each other: `references/code-smells.md`. Load it when reviewing for structure or when teaching a specific smell.

Two that carry non-obvious arbitration and stay here:

- **Middle man.** A unit that does nothing but forward almost every call to another adds a hop and a maintenance point without earning its keep — inline it and let callers reach the real thing. This is the opposite failure from Law of Demeter, and fixing one is not licence for the other: a thin **intentional** facade that hides a shape or stabilizes a boundary is fine — the smell is delegation with **no added value**.
- **Divergent change & shotgun surgery.** One unit changing for many unrelated reasons → split by reason-to-change. One conceptual change forcing edits across many scattered units → the knowledge is smeared out, gather it into one place. Adding an order status should be one addition, not edits to an enum, three switches, two templates, a validator, and a mapper.

---

## Comments — zero, until the user asks

Be honest about the bias here: models reflexively sprinkle comments to *look* thorough — narrating steps, labelling sections, restating the line below. A comment doesn't run, isn't type-checked, and rots silently the moment the code around it changes; an obvious or stale one lies to the next reader. Code carries the *what* and *how* through precise names and clear structure, and the *why* belongs in your reply or the commit body — not in the file.

**Write no comments and no docstrings** in code you author or edit. Not for complex logic, not for a non-obvious *why*, not "just this one." If code needs explaining, fix the naming and structure; if a *why* genuinely can't live in the code, put it in your reply or the commit message. Add a comment only when the user asks for one in that request, and only what they asked for.

**The ones you keep writing — never:**
- **Narration of the next line** — `// fetch the user`, `// increment counter` above `counter++`. The code already says exactly this.
- **Section headers inside a function** — `// --- validation ---`, `// main logic`, and the `// Arrange` / `// Act` / `// Assert` labels in tests. If a body needs chapter titles it's doing too much; extract named functions — the function *name* is the label.
- **Restatement** — any comment you could reproduce by reading the line beneath it.
- **Docstrings** — a `getName()` needs no prose, and a public API's contract belongs in its types, names, and tests.
- **PR/ticket context** — `// fixes JIRA-123`, `// for the checkout flow`; that belongs in the commit message. No decorative banners.

**Bad (narration + restatement):**
```
// fetch the user from the database
user = db.find(id)
// check whether the user is active before continuing
if user.active { ... }
```
**Good:** the code alone — `user = db.find(id); if user.active { ... }`. The names carry the meaning; there is nothing left for a comment to add.

- **Still allowed** (machine-read, not comments): lint/type pragmas (`// eslint-disable`, `# type: ignore`, `# noqa`, `@Suppress`, `// ignore:`), shebangs, build tags, codegen banners, repo-mandated license headers.
- **Leave existing comments alone** — don't extend them, don't delete unrelated ones. Drop a stale one only when your edit makes it wrong, and say so in your reply.
- If renaming would make a comment redundant → rename. That is always the fix.

---

## Currency — prefer the newest idiom and API the target supports

**Default: reach for the newest language feature and framework API the project's target version supports.** Languages and frameworks evolve to fix the rough edges of older idioms; a newer feature ships because the old way had a real cost (verbosity, unsafety, footgun, lost expressivity). Flip the burden of proof — instead of "is the new feature worth it here?", ask "why am I *not* using it?". "I'm used to the old way" is not a reason.

**How to apply:**
- **Detect the target version first — the only hard gate.** Read the project manifest (the file that declares language edition / runtime / SDK versions and dependency versions). Never recommend a feature or API the target can't compile or that's deprecated at its version. If the manifest is unavailable or ambiguous, ask.
- **New code gets the newest idiom; touched code keeps the file's idiom.** If the file you're editing is uniformly on an older style, match it — a lone modern construct dropped into an old file is a style change smuggled into a fix. Note the modernization separately instead.
- **Web-search when unsure.** Knowledge drifts — before recommending a feature or flagging an API as deprecated, if you're not certain which version introduced or removed it, search "language/framework X feature/API Y introduced|deprecated version".
- **Verify the API and package exist before using them.** Don't pull a function, method, flag, or library from memory — both LLMs and humans misremember signatures and invent plausible-but-nonexistent packages (a supply-chain risk: attackers pre-register the hallucinated name). Confirm against the installed version's docs/source or the real registry; if you can't confirm it, use something you can.
- **Add it with the ecosystem's CLI** — `bun add`, `uv add`, `cargo add`, `go get`, `flutter pub add` — never by typing a version into a manifest or lockfile. The install is also the proof the package exists.
- **Prefer what the ecosystem is steered toward now** — structured concurrency and native async over callback chains / manual thread pools; pattern matching / destructuring over nested type-tag branches; data classes / records / value types over hand-written boilerplate; safe-navigation and typed optional/result handling over manual null chains and force-unwraps; comprehensions / map-filter-reduce / generators over index loops with mutable accumulators; string interpolation over concatenation; scope-guard resource management over manual close; current framework component/lifecycle patterns over deprecated ones.
- **KISS escape hatch (rare).** If the newest feature genuinely obscures intent *here*, fall back and record why in the commit body, so a future reader doesn't "modernize" it back. "I think old is clearer" without a concrete reason doesn't qualify.
- **Your Good example must not retain the idiom you're replacing.** Before showing it, re-scan for *every* legacy idiom on the relevant axis, not just the one you led with.
- **Flag deprecated APIs separately, don't bundle** the migration into the user's actual ask (see *Scope discipline*).

---

## Scope discipline — surgical changes only

**A default operating stance for every edit, including trivial ones.** The smallest change that fully solves the stated problem is the correct change. Every line you touch must trace to the requested work — no drive-by refactors, no reformatting adjacent code, no renaming "for clarity", no modernizing untouched regions. Unrequested changes bloat the diff, risk regressions, and bury the real fix in noise.

**Bad (asked to fix the tax formula):** fix the formula *and* reformat an unrelated loop *and* rename nearby variables.
**Good:** change only the tax-formula line.

- Match existing style even if you'd do it differently — style changes get their own change.
- Remove only imports/variables your change orphaned; pre-existing dead code stays (mention it separately).
- Noticed a nearby bug or cleanup? Flag it in the review/description; don't fold it in.
- Every "why did this line change?" should have a one-sentence answer tied to the task. When in doubt, change less.

---

## Tone

Be direct and constructive. Lead with what matters most. Skip praise for what's already fine — focus attention on what can improve. If the code is genuinely good, say so briefly and point out one or two things that could go from good to great.

## References

- `references/code-smells.md` — the twelve-smell catalogue with Bad/Good pairs.
- `references/solid.md` — composition over inheritance, Open/Closed, dependency inversion, worked.
- `references/flag-free-code.md` — replacing boolean flags with closed types, derived values, optional fields, per-stage objects and state machines, worked.
