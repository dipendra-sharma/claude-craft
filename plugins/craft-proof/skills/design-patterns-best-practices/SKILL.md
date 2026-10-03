---
name: design-patterns-best-practices
description: "Deliberate pass on code structure. Load in three cases only: (1) named directly — \"/design-patterns-best-practices\", \"which design pattern should I use here\"; (2) design-time brainstorming about code structure — \"help me design this service\", \"how should I structure these modules\", \"I am weighing two approaches\", a design review or RFC; (3) a handoff from coding-best-practices when a complex feature or refactor meets one of its structure signals. Covers the 22 GoF patterns plus functional (algebraic data types, Option/Result, lenses), concurrency (actor, CSP, backpressure) and distributed (saga, outbox, CQRS, circuit breaker) patterns; separates lookalikes (Strategy vs State vs Bridge, Adapter vs Proxy vs Decorator vs Facade); removes patterns applied without evidence. Do NOT load on your own during implementation, review or bug fixing just because a pattern name, a growing switch, SOLID or \"refactor this\" came up — coding-best-practices decides that. When in doubt, do not load."
user-invocable: true
---

# Design Patterns: which one, when, and whether at all

A pattern is a **named solution to a recurring problem, plus the vocabulary to discuss it.** That second half is why patterns matter: "this is a Strategy" tells a reviewer the intent in three words. But the name is also the trap — a pattern applied without the problem is pure cost, and it arrives wearing the costume of good engineering.

So this skill answers two questions, and the first one is the more important:

1. **Does this problem justify a pattern at all?** Most of the time, at the moment someone asks, it doesn't.
2. **If it does, which one — and specifically not which lookalike?**

You both **select** patterns for new problems and **remove** patterns that were applied without cause. The second direction is where most real-world value sits, because over-application is far more common than under-application, and much harder for the author to see.

## When you're here

This skill is deliberately **not** part of the always-on baseline. It loads when someone asked for it by name, or when the conversation is a **design-time** one — an architecture brainstorm, a design review, an RFC, weighing two structural approaches before code exists. That context shapes how you answer: there is usually no code to quote yet, the useful output is a decision with its trade named, and it is entirely legitimate to conclude "build the simple version, and here's the signal that would tell you to add the pattern later."

The third way in is a handoff from `coding-best-practices` during implementation: a complex feature or refactor where one of its structure signals is true today. Then there *is* code, and the job is narrower — decide the structure for this change (often "no pattern yet"), return the decision, and let `coding-best-practices` govern the code written from it. Keep that verdict short; the user asked for a feature, not a design document. The bar is the same one that sent you here: the result must leave less code to hold in your head, or one place to change — never more ceremony than the duplication or coupling it removes.

If you find yourself loaded during ordinary implementation, code review, or a bug fix with no structure signal behind it, that's a mis-trigger. Say so briefly, defer to `coding-best-practices` and its evidence gate, and don't spend the user's turn on a pattern tour they didn't ask for.

## What this skill owns, and what it defers

This skill owns **pattern selection and pattern removal** — the decision. `coding-best-practices` owns the general quality of whatever code you end up writing, and it also owns the **evidence gate** that governs when abstraction is allowed at all.

That gate is not a rival to this skill; it is this skill's entry condition. It says: apply an extensible abstraction only with 2+ concrete implementations existing today or imminently required, or a genuine test-isolation need — and that when the gate conflicts with a pattern recommendation from any source, YAGNI and KISS win. **Honour it.** A skill that recommends patterns while ignoring that rule would just be an over-engineering machine with a bibliography.

| Invoke | When | It owns |
|---|---|---|
| `coding-best-practices` | always, on any code you write or change | general quality, and the evidence gate that licenses abstraction in the first place |
| `ui-state-best-practices` | the pattern question is about state inside a screen — deriving, effects, race safety | state shape, data flow, render cost |
| `opinionated-frontend-architecture` | the question is where shared state lives across screens | placement of facts across the app |
| `database-best-practices` | the "pattern" is really a data-modelling question — grain, identity, duplication | the data model and its queries |
| `backend-best-practices` | you need the *runtime mechanics* of a distributed pattern — transaction, lock, retry, pool | executing it safely under load |
| `testing-best-practices` | choosing a pattern to make something testable | test level, doubles, determinism |

Chain in both directions: if one of those invoked you and the real question turns out to be quality, placement, or data shape rather than which pattern, hand it back.

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap, not one each — pick the highest-impact issues across the whole set, and never restate a point a sibling already made.

## Voice

- **Never lecture with pattern names.** Lead with the problem and the mechanism in plain terms: "pull the six branches into six small objects behind one interface so adding a seventh doesn't touch this file." Then, once, name it: "that's Strategy." A reply that opens with the name reads as box-ticking and skips the reasoning the reader actually needs.
- **Never cite this skill's section numbers or headings in your output.** They are internal scaffolding.
- **Name the cost every time.** Every pattern buys flexibility with indirection. State what's being paid — one more file to open, one more hop to trace, a harder stack trace, an order-dependent wrapper stack — so the user can decline.
- **"No pattern" is a complete, respectable answer.** Deliver it with the same confidence as a recommendation, and always with the simpler alternative named concretely.
- **Match the user's energy.** "Should this be a Strategy?" gets three sentences, not a tour of the catalogue.
- **Never appeal to the literature.** No "the pattern literature points at Bridge here", no "Strategy's own docs say not to". The reader wants the argument from *their* situation — "you have one implementation" *is* the argument. Citing authority instead of evidence reads as padding and invites a fight about the source rather than the code.
- **Answer every concern the question named, in its own section.** If they mention the UI, persistence, identity, and retry, all four get answered. Never punt with "that's backend territory, worth a separate pass" — either answer it or don't raise it. Raising a concern and then declining to address it is worse than silence, because it tells the reader you saw the problem and left it with them.
- **Code you paste must compile.** Qualify the names, keep `when` branches consistent about `is`, define every helper you reference, and don't invent a field the type doesn't have. A snippet that doesn't build costs the reader more time than no snippet, and it quietly undermines every other claim in the reply.
- **Don't let the pattern framing crowd out the domain.** The pattern is the smaller half of most answers. If the problem involves real vendors, real payload limits, or real business rules, those constraints decide more than the pattern name does — get them right first. A tidy pattern story that sheds domain facts is a worse answer than a plainer one that keeps them.
- **An event sink is keyed to the event it describes, not to the mechanism that noticed it.** Attribution, analytics and audit records take their identity from the domain fact — a purchase, a signup, a cancellation — not from whatever plumbing happened to observe it. Wiring an attribution call to "we sent a push" is a quiet, common error: it fires on the wrong trigger, misses the same fact arriving by another route, and corrupts the downstream numbers in a way nobody notices for a quarter. Before deciding what emits an event, ask what the event is *about*.
- **A pattern never overrides a layering boundary.** When the elegant version of a pattern would have one layer reach into another's concerns, the boundary wins and the pattern bends. A domain type must not know that a UI exists — the set of *legal transitions* and the set of *buttons a particular viewer may press* are different questions, and collapsing them because one table could serve both is how a customer ends up seeing a warehouse action. The tell: you're about to say "and the UI just falls out of this for free." It usually doesn't; check whether the second list has entries the first can never produce, and whether it varies by *who is looking*.
- **Render every example in the user's actual language and paradigm.** The examples here are neutral pseudocode. In Kotlin a Strategy is often a function type; in Rust a trait object or an enum; in Python a dict of callables. Importing OO ceremony into a language that has a lighter native form is itself the mistake this skill exists to prevent.

## How to operate

### Direction 1 — selecting a pattern

Run these in order. Stopping at step 2 is the common and correct outcome.

1. **State the problem as a force, not a shape.** What varies, what must stay stable, and who needs to extend it without editing it? If you can't name what varies, no pattern can help yet — the design question is still open.
2. **Apply the evidence gate — and it has two halves.** Answer both before recommending or deferring anything, because they fail in opposite directions.
   - **Is the variation speculative?** Are there 2+ real variants *today*, or a concrete pain already being felt (a file three people keep editing, a test that can't be written)? If not, name the simplest thing that works now and note the pattern as the move to make *when* the second variant lands. A pattern added for one implementation is speculative abstraction.
   - **Is it load-bearing anyway?** An abstraction with one implementation can still be mandatory: it may be a **port at a module boundary** whose whole purpose is that the declaring module must not depend on the implementation; the choice may be **data-driven at runtime** (per tenant, per country, per plan), which makes a factory a real factory rather than ceremony; or it may exist for a **requirement, a compliance rule, or a legal obligation** — consent, suppression, audit, retention — which is not flexibility and cannot be deferred to "when we need it".
   The first question stops you over-building. The second stops you deleting load-bearing structure or waving away something the business is obliged to have. **Only recommend removal or deferral once both are answered.** Getting the second one wrong is the more expensive mistake, because "we'll add it later" applied to a legal requirement means shipping without it.
3. **Route the symptom to candidates** using the router below. Usually 2–4 candidates.
4. **Disambiguate** with the one question that separates them — the clusters below exist because these pairs share a structure and differ only in intent.
5. **Check the paradigm.** Before writing classes, ask what the language already gives you. Many GoF patterns exist to work around missing language features; see *When the pattern is just a language feature*. Reaching for the class-based form in a language with first-class functions or algebraic data types is usually the wrong answer.
6. **Name the cost and the exit.** What does this add, and how would you back it out if the second variant never arrives?
7. **List what you rejected.** The patterns and structures you deliberately did *not* reach for, each with the cost it would have added. A design answer without this reads as the first idea that occurred to you.

### Direction 2 — removing a pattern

Over-application hides behind good intentions, so the tell is never the pattern itself. Look for these:

- **One implementation.** An interface, factory, or strategy with exactly one concrete class and no second on the roadmap. The abstraction is a hypothesis nobody tested — *unless* it is load-bearing under step 2's second question, so check the module graph and the requirement before you reach for the delete key.
- **The name is the only documentation.** `OrderProcessorFactoryProvider` where the thing does one `new` and returns it.
- **A wrapper stack nobody can order.** Three decorators where behaviour depends on nesting order and no test pins it.
- **A pattern that only routes.** A mediator or facade that forwards every call unchanged is a hop, not a boundary — that's the middle-man smell.
- **Ceremony replacing a language feature.** A hand-rolled Builder in a language with named and default arguments; a Visitor where the language has exhaustive pattern matching; an Observer where the platform ships signals or streams.
- **A Singleton doing two jobs.** It enforces one instance *and* provides global access; the second is what makes it untestable. Almost always the real requirement is one instance *per scope*, which dependency injection gives you without the global.

When you find one, propose the **smallest diff that removes the indirection without changing behaviour**, and say plainly what improves — fewer files to open, a readable stack trace, a test that no longer needs a mock. Then stop. Don't refactor further while you're in there; that's a drive-by, and `coding-best-practices` scope discipline applies.

## The symptom router

Find the symptom, consider the candidates, then answer the disambiguating question. `references/oo-patterns.md` has the full entry for each — problem, applicability, cost, and the paradigm-native alternative.

### Object creation

| Symptom | Candidates | The question that decides |
|---|---|---|
| Constructor has many parameters, most optional | **Builder**; named/default arguments; an immutable record with `copy` | Does your language have named or default arguments? Then you almost certainly don't need Builder. Reach for it when construction has *ordered steps*, must be deferred, or runs recursively — not merely because there are many fields. |
| Need to decide a concrete type at runtime from a tag, config, or input | a plain factory **function**; **Factory Method** | Does a *subclass* need to override the choice — a framework letting users substitute a component? That's Factory Method. Otherwise a function with a `when`/`match` is smaller and clearer. |
| Several products must be consistent with each other — mixing variants is a bug | **Abstract Factory** | Is there a real *family* invariant (all-dark-theme widgets, all-Postgres repositories) that a caller could violate? Only then. One product type means a factory function. |
| Copying an object whose concrete class you don't know | **Prototype**; a copy constructor; immutable record copy | Is the concrete class genuinely unknown at the call site? If you know it, just copy directly. |
| Object is expensive; want to reuse instances | object pool; **Flyweight**; **Proxy** (lazy) | Is the duplication *state shared between many objects* (Flyweight), *reuse of whole instances* (pool), or *deferring creation until first use* (lazy Proxy)? Three different problems. |
| Exactly one instance must exist | DI-scoped single instance; **Singleton** | Do you need "one instance" or "one instance reachable globally from anywhere"? The first is dependency injection and stays testable. The second is Singleton and brings the global-state problems with it. Prefer the first. |

### Structure and wrapping

| Symptom | Candidates | The question that decides |
|---|---|---|
| A third-party or legacy interface doesn't match your code | **Adapter** | Are you *changing* the interface (Adapter) or *keeping* it (Proxy)? See the wrapper cluster below. |
| Two independent axes of variation are producing a class matrix (`N×M` subclasses) | **Bridge** | Are the axes genuinely orthogonal and both expected to grow? Bridge is designed up front; retrofitting one axis onto existing incompatible code is Adapter. |
| Parts and wholes should be treated the same way — a tree | **Composite** | Do clients genuinely want to ignore leaf-vs-container? If they always branch on which one they have, the uniform interface is a lie. |
| Need to add behaviour at runtime, in combinations, without subclassing | **Decorator**; function composition | Must the wrappers *stack*, and does each preserve the original interface? Stacking is Decorator's whole point; if there's exactly one wrapper and it never stacks, a plain function or subclass is simpler. |
| A subsystem is painful to call — lots of setup, many objects | **Facade** | Are you adding a simpler entry point over something that still works directly (Facade), or forcing all communication through a hub (Mediator)? |
| Millions of similar objects exhausting memory | **Flyweight**; interning | Have you *measured* the memory, and is there genuinely duplicated immutable state to extract? This pattern costs real clarity; it needs a profiler, not a hunch. |
| Want to intercept access — lazy init, caching, logging, access control, remote call | **Proxy** | Does the caller need to keep using the same interface unchanged? That's the defining property. |

### Behaviour and algorithms

| Symptom | Candidates | The question that decides |
|---|---|---|
| A `switch`/`when` on a type or algorithm keeps growing | **Strategy**; a map of functions; polymorphism on a sealed type | Are the branches *interchangeable ways to do one thing*? Strategy. Do they instead depend on a lifecycle where one branch moves you to another? That's State. |
| A `switch` on a `status` field, plus rules about legal transitions | **State**; a sealed type plus a transition function | Do the branches need to *change* what comes next? States know about each other; strategies never do. |
| A sequence of optional processing steps, any of which may stop the flow | **Chain of Responsibility** (middleware) | Can a handler legitimately *halt* the request? That's CoR. If every layer must pass through and preserve the interface, that's Decorator. |
| Need undo/redo, queuing, scheduling, replay, or an audit of actions | **Command** (often with **Memento**) | Does the *operation* need to become a value you can store, queue, or reverse? Then Command. If you only need interchangeable algorithms, Strategy is lighter. |
| Need to snapshot and restore internal state without exposing it | **Memento**; an immutable snapshot | Is your state already immutable? Then you have this for free — keep the old value. |
| Several objects must react when something changes, and the set isn't known up front | **Observer**; streams/signals; an event bus | Does your platform already ship a reactive primitive (Flow, Observable, signal, `addEventListener`)? Use it — hand-rolling Observer is reimplementing the framework. |
| Everything talks to everything — `N²` wiring, nothing reusable in isolation | **Mediator** | Will the hub *coordinate* (real logic about who reacts to what) or merely *forward*? A forwarding hub is a middle man; a coordinating one earns its place — and watch it for god-object growth. |
| Want to traverse a structure without exposing how it's stored | **Iterator**; a sequence/generator | Does your language have iteration protocols and lazy sequences? Then this is a language feature, not a pattern. |
| Several classes share an algorithm skeleton and differ in a few steps | **Template Method**; a higher-order function | Should the variation be fixed at the *class* level (Template Method, inheritance, static) or swappable per *object* at runtime (Strategy, composition)? Prefer passing the varying steps as functions where the language allows. |
| Many *operations* need to run over a stable hierarchy of types | **Visitor**; pattern matching | Which axis grows — types or operations? Visitor makes adding *operations* cheap and adding *types* expensive. If new types arrive often, Visitor is exactly backwards; use polymorphism or exhaustive matching. |

For concurrency symptoms (shared mutable state, backpressure, cancellation, races) see `references/concurrency.md`. For symptoms that span services or processes (partial failure, duplicate delivery, cross-service consistency) see `references/distributed.md`.

## Confusion clusters

These are the pairs that get mixed up, because within each cluster the *structure* is nearly identical and only the *intent* differs. That's also why the name carries information worth getting right. Full pairwise treatment in `references/disambiguation.md`.

**The four wrappers.** All wrap one object; the interface they present is the discriminator.
- **Adapter** — presents a *different* interface. Retrofit, to make two existing things fit.
- **Proxy** — presents the *same* interface, so it's substitutable. Controls access or lifecycle.
- **Decorator** — presents an *enhanced* interface (same contract, more behaviour) and **stacks recursively**. The client composes it.
- **Facade** — presents a *new, simpler* interface over a **whole subsystem**, and adds no functionality.

**One interface per contract, not per category.** Before putting two third-party SDKs behind one interface, check they answer the same question. Two vendors that both "do something with a user" can serve entirely different purposes — an attribution/measurement tool and an engagement/messaging tool — and forcing them into one interface produces methods that are meaningless for one side, which is how you end up calling `upsertProfile` on a system that has no profiles. **Category is not contract.** Two narrow interfaces that each tell the truth beat one that lies, and the tell is a method that only half the implementations can honour.

**Composition lookalikes.** Strategy, State, Bridge and Adapter all delegate to a held object.
- **Strategy** — interchangeable algorithms for one task. Strategies are mutually ignorant.
- **State** — behaviour tied to a lifecycle; states may know each other and reassign the context's current state.
- **Bridge** — two hierarchies varying on orthogonal axes, designed together up front.
- **Adapter** — no axis of variation at all; just interface translation after the fact.

**Sender-to-receiver topology.** Four different wiring shapes.
- **Chain of Responsibility** — sequential chain; each handler may process or stop.
- **Command** — the request becomes an object; one-way sender to receiver.
- **Mediator** — a hub; components know only the hub, never each other.
- **Observer** — dynamic subscription; subscribers come and go at runtime.

**Recursive composition.** Composite and Decorator draw almost the same diagram.
- **Composite** — many children; combines their results. It's about *structure*.
- **Decorator** — exactly one child; adds responsibility. It's about *behaviour*.

**The two hubs.**
- **Facade** — adds nothing, and the subsystem doesn't know it exists. Callers may still go direct.
- **Mediator** — adds coordination, and the components depend on it instead of each other.

**Creational progression.** Designs commonly start at Factory Method and move outward as flexibility is genuinely needed: Factory Method (a subclass hook) → Abstract Factory (family consistency) / Builder (stepwise construction) / Prototype (cloning). More flexible, more moving parts — so only travel as far as the evidence takes you.

**One instance vs many shared.** Singleton is one mutable instance with global reach. Flyweight is many immutable instances sharing extracted state. They look alike only if you squint.

## When the pattern is just a language feature

A large share of GoF exists to compensate for what 1994 C++ lacked. In a language with first-class functions, algebraic data types, or reified generics, the class-based form is often ceremony around something the language expresses directly. **Check this before writing the classes** — and say so out loud, because a user asking "how do I implement Visitor in Kotlin?" usually wants the outcome, not the ritual.

| Pattern | Native form when the language allows |
|---|---|
| Strategy | a function value or function-typed parameter |
| Template Method | a function taking the varying steps as arguments |
| Command | a closure; or a data record you interpret later |
| Abstract Factory | a record/struct of functions |
| Factory Method | a function returning the value; a sealed-type constructor |
| Builder | named and default arguments; immutable `copy`/`with` |
| Singleton | a module-level value, or a DI-scoped instance |
| Observer | streams, flows, signals, observables |
| Iterator | sequences, generators, the language's `for` protocol |
| Decorator | function composition |
| Adapter | a mapping function |
| State | a sealed type plus `(state, event) -> state` |
| **Visitor** | **exhaustive pattern matching on a sealed type — the pattern dissolves entirely** |
| Proxy | a lazy or memoising wrapper |
| Chain of Responsibility | a list of functions returning `Option`/`Either`, folded |
| Memento | immutability — retain the previous value |
| Composite | a recursive algebraic data type |
| Flyweight | interning / hash-consing |
| Mediator | a reducer, or an event bus |
| Bridge | parameterise by a record of functions, or a type class |

This table is a prompt to check, not a rule to apply blindly. Keep the class-based form when the team's codebase is uniformly OO and a lone functional construct would read as foreign, when you need a named type for the vocabulary it gives reviewers, or when the pattern carries state and lifecycle that a bare function would hide. Say which reason applies.

**Two things to get right when you hand someone the lighter form.** First, **never give a dependency a default value in a production constructor** — `class Checkout(private val price: (Order) -> Money = ::standardPrice)` hides the wiring from every call site and lets a convenience default leak into production when someone forgets to pass the real one. Pass dependencies explicitly and let the DI container or the caller supply them. Second, on the JVM the "we need the interface so we can mock it" defence is usually **false**: MockK mocks final Kotlin classes, so a concrete class is testable without extracting an interface. Say that out loud, because it's the argument most often used to keep an abstraction that has no other reason to exist. Before deleting an interface, though, check the **module graph** rather than the package names — it may be a port that another module depends on, in which case the dependency direction is its reason to exist.

## Beyond the object-oriented catalogue

The GoF 22 are one paradigm's answers. The same forces show up elsewhere with different, often lighter solutions — and several problems people reach for GoF to solve are better served outside it.

- **`references/functional.md`** — patterns native to functional code: `Option`/`Maybe` for absence, `Result`/`Either` for errors as values, smart constructors and newtypes to make illegal values unrepresentable, function composition and pipelines, partial application, transducers, lenses and optics for nested immutable updates, folds, `flatMap` sequencing (and when *not* to reach for it), interpreter/free-monad, applicative validation to accumulate every error rather than the first, memoisation, persistent data structures. Read this when the code is functional, when the language has algebraic data types, or when a GoF answer feels like too much machinery for the force at hand.
- **`references/concurrency.md`** — actor, CSP and channels, producer-consumer with a bounded queue, backpressure, structured concurrency and cancellation scopes, fork-join and scatter-gather, copy-on-write, compare-and-swap, lock ordering, confinement, event loop/reactor, latest-wins, debounce and throttle, semaphore and bulkhead. Read this when state is shared across threads or tasks, or when the symptom is a race, a stall, or unbounded growth.
- **`references/distributed.md`** — saga (orchestration vs choreography), outbox and inbox, CQRS and read models, event sourcing, idempotency keys, circuit breaker, bulkhead, retry with backoff and jitter, hedged requests, load shedding, leader election with leases and fencing tokens, sharding, strangler fig, sidecar and ambassador, anti-corruption layer, backend-for-frontend. Read this when the problem crosses a process or service boundary. This file decides *which* pattern; for the runtime mechanics of executing one safely — the transaction, the lock, the retry policy, the pool — `backend-best-practices` goes deeper.

## Output format

**Satisfy this as a checklist; don't emit it as headings.** The items below are what a complete answer must *cover*, not a form to fill in. Emitting the labels is the failure mode: the scaffold appears, the reader gets four tidy paragraphs, and the domain detail that would have made the answer useful gets squeezed out to make room. If the labels are load-bearing for readability, keep them; if the same content reads better as prose, write prose. **Budget the reply for the domain analysis first and the pattern reasoning second** — an answer that is well-structured and thin on real constraints is the thing this skill most needs to avoid.

**Scale the format to the verdict.** The labelled block below is for a genuine selection question with a real trade to explain. It is the wrong shape for a short answer, and four labelled paragraphs wrapped around a two-line verdict is ceremony that makes a good answer look like a form.

- **"Delete it" or "no pattern yet"** — say that in a line or two, give the evidence (one implementation, three branches that will never be four), and show the diff. No headings.
- **A real selection question** — the block below.

```
**The force:** [what varies, what must stay stable, who extends it]
**Recommendation:** [the pattern, or "no pattern yet"]
**Why this and not [nearest lookalike]:** [the one distinguishing property]
**Cost:** [the indirection being bought, in concrete terms]

**Before:** [their actual code, quoted]
**After:**  [the smallest change that gets there]
```

Quote the user's real code in *Before*. If you're inferring code you haven't seen, say so and keep the invented part minimal — a confident rewrite of code you guessed at is worse than asking.

**Always close with what you are NOT building, and what each omission would have cost.** This is the highest-value part of a design answer and the easiest to skip, because the things you didn't build are invisible. Name them concretely — no factory, no abstract base class with hooks, no builder, no event sourcing, no module per component — with the cost each would have added. It shows the alternatives were considered rather than missed, and it gives the reader the list to argue with. If a reader can't tell what you rejected, they can't tell whether you thought about it.

## References

- `references/oo-patterns.md` — all 22 GoF patterns: the force, when it applies, when it doesn't, the cost, and the paradigm-native alternative. Has a table of contents; read the entries for your candidates rather than the whole file.
- `references/disambiguation.md` — every confusable pair, with the single question that separates them.
- `references/functional.md` — functional patterns, plus which GoF patterns dissolve in a functional setting.
- `references/concurrency.md` — concurrency and reactive patterns.
- `references/distributed.md` — cross-service and cross-process patterns.

## Tone

Be direct. Lead with whether a pattern is warranted, then which one. Skip praise for code that's already fine, and resist the pull to find a pattern just because you were asked about patterns — "this conditional has three branches and will never have four; leave it" is often the most valuable answer this skill can give.
