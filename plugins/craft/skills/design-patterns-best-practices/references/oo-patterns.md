# The 22 object-oriented patterns

One entry per pattern. Read the entries for your two or three candidates, not the file.

Each entry gives: **the force** (what varies against what stays stable), **use it when**, **don't**, **cost**, and **lighter form** (what to reach for first if your language offers it).

## Contents

**Creational** — who decides which object gets made
[Factory Method](#factory-method) · [Abstract Factory](#abstract-factory) · [Builder](#builder) · [Prototype](#prototype) · [Singleton](#singleton)

**Structural** — how objects are composed into bigger things
[Adapter](#adapter) · [Bridge](#bridge) · [Composite](#composite) · [Decorator](#decorator) · [Facade](#facade) · [Flyweight](#flyweight) · [Proxy](#proxy)

**Behavioural** — how responsibility and control flow are assigned
[Chain of Responsibility](#chain-of-responsibility) · [Command](#command) · [Iterator](#iterator) · [Mediator](#mediator) · [Memento](#memento) · [Observer](#observer) · [State](#state) · [Strategy](#strategy) · [Template Method](#template-method) · [Visitor](#visitor)

---

# Creational

## Factory Method

**The force.** The *kind* of object varies; the code that uses it must not. A subclass, not the caller, gets to decide.

**Use it when**
- A framework or library needs to let users substitute a component it constructs internally. This is the pattern's strongest case: the framework calls its own `createX()`, and a user's subclass overrides it. Without the hook, the user can subclass the component but has no way to make the framework use it.
- Construction needs to do more than `new` — pull from a pool, reuse an existing instance, consult a registry — and a constructor can't, because a constructor must return a fresh object.
- The construction choice belongs in a class hierarchy you already have. Retrofitting it into existing creator subclasses is cheap; inventing a hierarchy just to host it is not.

**Don't** when a plain function with a `when`/`match` on a tag would do — which is most of the time. `fun parserFor(kind: Kind): Parser` is smaller, easier to test, and needs no inheritance. Reserve the pattern for when *subclass override* is the actual requirement.

**Cost.** A parallel creator hierarchy shadowing the product hierarchy. Two files to open to learn what got constructed.

**Lighter form.** A factory function; a sealed type whose constructors are the variants.

## Abstract Factory

**The force.** Several products must come from the *same family*, and mixing families is a bug the type system should prevent.

**Use it when**
- There is a real family invariant a caller could violate. Widgets that must all match one theme; repositories that must all target the same database; parsers and serialisers that must agree on one wire format. The factory makes "all from one family" the only expressible option.
- A class has accumulated several factory methods that have nothing to do with its main job, and they want their own home.

**Don't** when there's only one product type — that's a factory function. And don't when families can be freely mixed: if a dark button next to a light checkbox is merely ugly rather than *wrong*, the invariant isn't real and you're paying for nothing.

**Cost.** An interface plus one implementation per family, all of which must change together when the family gains a product. The most boilerplate-heavy creational pattern.

**Lighter form.** A record of functions (`data class Theme(val button: () -> Button, val field: () -> Field)`); a module per family.

## Builder

**The force.** Construction is a *process* with steps, not a single call — and the half-built object must never escape.

**Use it when**
- Construction genuinely has ordered or optional **steps**, some deferrable, possibly recursive. Building a nested tree is the clearest case: the builder can call itself.
- The same construction sequence should produce different representations — the steps are identical, the details differ.
- Callers must not be able to observe a partially constructed object. The builder holds it until it's complete.

**Don't** reach for it merely because a constructor has many parameters. In a language with named and default arguments, that problem is already solved and a Builder is pure ceremony. The tell that you need Builder is *steps*, not *arity*.

**Cost.** A builder class per representation, plus the sequencing logic. Easy to leave in a state where the caller can forget a required step and get a silently incomplete object — so validate on `build()`.

**Lighter form.** Named/default arguments; an immutable record with `copy`; a DSL block if the language has one (Kotlin's `apply`, a trailing lambda).

## Prototype

**The force.** You need a copy of an object whose concrete class you can't name.

**Use it when**
- Objects arrive from third-party code behind an interface, and you must duplicate one without knowing what it actually is.
- You'd otherwise write a subclass per pre-configured variant. Keep a few configured instances and clone the one you want instead.

**Don't** when you know the concrete type — just copy it directly. And be wary when the object graph has cycles or holds external resources (open sockets, file handles): deciding what "copy" means then is the hard part, and the pattern doesn't help you decide.

**Cost.** Every participating class owns correct clone logic forever, including after someone adds a mutable field and forgets. Deep-vs-shallow bugs here are quiet and nasty.

**Lighter form.** An immutable record's `copy`; a copy constructor; serialise-and-deserialise for a genuinely deep copy.

## Singleton

**The force.** One instance must exist — and, in the classic form, be reachable from anywhere.

**Use it when** the thing genuinely is single and global, and the global reach is *wanted* rather than merely convenient. Real cases are narrower than people assume: a process-wide logger, a metrics registry.

**Don't** — usually. This is the most over-applied pattern in the catalogue, and its problem is that it does **two** things at once: it enforces uniqueness *and* it provides a global access point. The second is what hurts. Global reach hides dependencies (a signature tells you nothing about what it touches), makes tests order-dependent, needs care to initialise safely under concurrency, and is awkward to substitute because the constructor is private and statics rarely override.

Almost always the actual requirement is **one instance per scope** — per process, per request, per user session. Dependency injection expresses that directly: construct one, pass it in. You keep uniqueness, lose the global, and the dependency becomes visible in the signature. On a server the distinction is critical, since "one per application" and "one per request" are different lifetimes and conflating them leaks one user's data into another's response.

**Cost.** Hidden coupling, test interference, concurrency care, and it masks design problems by letting any component reach any other.

**Lighter form.** A DI-scoped instance. A module-level value in a language with module initialisation semantics you trust.

---

# Structural

## Adapter

**The force.** Two interfaces that must work together were designed without knowledge of each other, and you can't change either.

**Use it when**
- You want an existing class — legacy, third-party, oddly shaped — and its interface doesn't match your code.
- Several existing subclasses need shared behaviour that can't go in the shared superclass. Wrapping them beats duplicating into each.

**Don't** when you *can* just change the class to fit. Editing the service is often simpler and honest; an adapter is what you write when editing isn't available to you.

**Cost.** A translation layer to keep in sync with both sides. When both interfaces evolve, adapters rot quietly — the compiler catches signature drift but not semantic drift.

**Lighter form.** A mapping function. Most adapters in functional code are one function per direction.

## Bridge

**The force.** Two dimensions vary independently, and subclassing both at once produces a combinatorial matrix.

**Use it when**
- You have or foresee an `N×M` class explosion on genuinely **orthogonal** axes — shape × renderer, notification-kind × transport, report-type × output-format. Split into two hierarchies and let one hold a reference to the other, and you get `N+M` classes instead of `N×M`.
- A monolithic class has several variants of functionality tangled together, and each change to one variant risks the others.
- Implementations must be swappable at runtime.

**Don't** apply it to a class that's highly cohesive — you'll split something that wanted to stay whole. And the axes must really be independent; if a change to one always forces a change to the other, they're one axis wearing a disguise.

**Cost.** Indirection on every call, and a design you're expected to get right *up front*. Bridge is a planned architecture, not a refactor you stumble into.

**Lighter form.** Parameterise by a record of functions, or by a type class / trait, rather than a second class hierarchy.

## Composite

**The force.** A tree of parts and wholes, where clients want to ignore which one they're holding.

**Use it when**
- The domain genuinely is recursive — a filesystem, a UI tree, a nested order with bundles, an expression.
- Clients should treat one item and a group of items identically. `total()` on a line and `total()` on a bundle both just work.

**Don't** when clients constantly need to know whether they have a leaf or a container. If every call site branches on it, the uniform interface is a fiction and you've paid for a lie. Also watch the interface degrading: forcing `add(child)` onto leaves to keep the type uniform means leaves get methods that throw.

**Cost.** An overgeneralised component interface, and recursion that's easy to make accidentally quadratic.

**Lighter form.** A recursive algebraic data type — `sealed interface Node { data class Leaf(...); data class Branch(val children: List<Node>) }` — plus functions over it. You get exhaustiveness checking for free.

## Decorator

**The force.** Behaviour must be added to individual objects at runtime, in combinations, without a subclass per combination.

**Use it when**
- Layers genuinely **stack** and combine: compression, then encryption, then buffering, on a stream. Subclassing every combination is `2^n` classes; wrapping is `n`.
- The class is `final` or otherwise closed to extension, and wrapping is the only route in.
- One monolithic class implements many optional behaviours and wants splitting into composable pieces.

**Don't** when there is exactly one wrapper and there always will be — a subclass or a plain function is clearer. And don't when order-independence matters but you can't guarantee it.

**Cost.** Behaviour depends on nesting order, which is invisible at the call site and rarely tested. Removing one wrapper from deep in a stack is awkward. The assembly code where the stack is built tends to be ugly. Stack traces gain a frame per layer.

**Lighter form.** Function composition. `val handler = logging(retrying(authenticating(base)))` is the same idea with no classes.

## Facade

**The force.** A subsystem is powerful and correspondingly painful to call; most callers want one common path through it.

**Use it when**
- Clients need a small, obvious entry point into something with a lot of setup and many collaborating objects.
- You want to layer a system: give each layer a facade and let layers talk only through them, which cuts coupling between them.

**Don't** let it become a god object. A facade that grows a method for every use case ends up coupled to everything and is the thing you now can't change. And a facade that only forwards, adding no simplification, is a middle man — delete it.

**Cost.** One more indirection, and a natural magnet for unrelated methods.

**Lighter form.** A module with a small public surface and the rest internal. Language visibility does this without a class.

## Flyweight

**The force.** Enormous numbers of similar objects don't fit in memory, and much of their state is duplicated.

**Use it when** all three hold: the program creates a very large number of similar objects, this actually exhausts memory on the target device, and the objects share **immutable** state that can be extracted and pooled. Split intrinsic (shared, immutable) from extrinsic (per-instance, passed in).

**Don't** without a profiler. This is the clearest measure-first pattern in the catalogue — it trades a lot of clarity for memory, and only pays at genuine scale.

**Cost.** Substantial. The state split is unintuitive, and every future maintainer wonders why the entity is cut in half. You may trade memory for CPU, recomputing extrinsic state on each call. Mutating shared state by accident corrupts everything at once.

**Lighter form.** String interning; a cache of canonical instances; hash-consing. Value types that the runtime already flattens.

## Proxy

**The force.** Something must happen around access to an object, and the caller must not have to know.

**Use it when** you need to interpose while keeping the interface identical and substitutable:
- **Lazy** — defer building an expensive object until first use.
- **Access control** — check the caller's rights before forwarding.
- **Remote** — the real object is on another machine; the proxy handles the wire.
- **Logging / metrics** — record calls before delegating.
- **Caching** — memoise results, keyed on arguments.
- **Lifecycle** — release the underlying resource when nobody holds it any more.

**Don't** when the caller can reasonably do the thing itself, or when the hidden behaviour is surprising — an innocuous-looking call that silently makes a network request is a debugging trap. Hidden latency is the recurring complaint.

**Cost.** Another class per concern, delayed or unpredictable response times, and behaviour that doesn't appear at the call site.

**Lighter form.** A memoising or lazy wrapper function; a `by lazy` delegate; an interceptor the framework already provides.

---

# Behavioural

## Chain of Responsibility

**The force.** A request should pass through a sequence of handlers, each free to handle it, transform it, or stop it — and the sequence isn't fixed.

**Use it when**
- You're building middleware: authentication, then rate limiting, then validation, then the handler. Any layer may reject and short-circuit.
- The order of handling matters and should be explicit and reorderable.
- The set of handlers changes at runtime or by configuration.

**Don't** when every request must reach the end — that's Decorator, and it makes the guarantee explicit. Also note the pattern's built-in hazard: a request can fall off the end **unhandled**. Decide deliberately what happens then; a silent drop is the usual bug.

**Cost.** Control flow spread across handlers, so "why did my request stop?" means walking the chain. Unhandled requests need an explicit terminal case.

**Lighter form.** A list of functions returning `Option`/`Either`, folded until one returns a result. Explicit, testable, and the short-circuit is visible in the types.

## Command

**The force.** An *operation* needs to become a value — so it can be stored, passed, queued, logged, replayed, or reversed.

**Use it when**
- You need **undo/redo**. Keep executed commands in a stack; undo either applies the inverse operation or restores a snapshot (pair with Memento when the state is private or the inverse is hard).
- Work must be **deferred, queued, scheduled, retried, or sent over a network**. A command is serialisable in a way a method call isn't.
- A UI element should be configured with an action — a menu item, a button, a keyboard shortcut — decoupled from what the action does. The same command can back all three.
- Simple operations should compose into a macro operation.

**Don't** when you only need interchangeable algorithms — that's Strategy, and it's lighter. The tell for Command is that you need the operation to *persist as a value beyond its invocation*.

**Cost.** A class per operation, and a whole layer between caller and receiver. Undo via state snapshots can consume real memory.

**Lighter form.** A closure for the simple cases. For undo and replay, a sealed `Action` type you interpret — that gives you serialisation and exhaustive handling that closures can't.

## Iterator

**The force.** Traversal should be decoupled from the structure being traversed.

**Use it when**
- The collection's internals are complex or must stay hidden, and clients need simple sequential access.
- Bulky traversal logic is cluttering business code.
- Code must walk several different structures uniformly.
- You need multiple independent cursors over one collection, or to pause and resume a traversal.

**Don't** hand-roll it in any modern language — iteration protocols, generators, and lazy sequences are built in. Writing an Iterator class from scratch in Kotlin, Python, JS, C#, Swift or Rust means reimplementing the standard library.

**Cost.** Overkill for simple collections, and sometimes slower than a direct loop over a specialised structure.

**Lighter form.** `Sequence`/`Iterator`/generator/`yield`; lazy list; the language's `for` protocol.

## Mediator

**The force.** A set of components are so entangled that none can be understood, changed, or reused alone.

**Use it when**
- Components are tightly coupled to each other and you want the relationships in **one** place — a form where each field's state affects several others is the classic case.
- A component can't be reused elsewhere because it references its siblings directly.
- You're writing component subclasses purely to vary how they interact.

**Don't** if the hub will only forward calls — that's a middle man, and it adds a hop while claiming to add a boundary. Watch for the real failure mode: the mediator accumulates every interaction rule in the system and becomes the god object you can no longer change. When that starts, split it by concern.

**Cost.** Centralised complexity. You've traded many-to-many coupling for one component everything depends on.

**Lighter form.** A reducer — `(state, event) -> state` — which is a mediator with the coordination made explicit and testable. Or an event bus, accepting that you lose static traceability of who reacts to what.

## Memento

**The force.** Snapshot and restore an object's state without exposing its internals.

**Use it when**
- You need undo, or transactional rollback on error, and the state to save is **private**. The object makes its own snapshot; nobody else can read inside it.
- Exposing enough getters and setters for an outsider to save and restore would wreck encapsulation.

**Don't** when your state is already immutable — you have this for free by keeping the previous value, and a pattern would be pure overhead. And in dynamic languages the encapsulation guarantee is weak anyway, which removes much of the motivation.

**Cost.** Memory, if snapshots are frequent — bound the history. Somebody must own discarding stale mementos.

**Lighter form.** An immutable value you hold on to. Persistent data structures make history cheap through structural sharing.

## Observer

**The force.** Several objects must react when something changes, and which objects isn't known when the publisher is written.

**Use it when**
- A change in one object requires updating an unknown or dynamic set of others.
- Subscription is temporary or conditional — subscribers join and leave at runtime.

**Don't** hand-roll it if the platform ships a reactive primitive. Flows, observables, signals, event emitters and property observers are all this pattern, already built and already handling the parts people get wrong. And the parts people get wrong are worth naming: **unsubscription** (a subscriber that outlives its need is a memory leak, and this is the single most common real bug in observer code) and **notification order**, which is generally not guaranteed — logic that depends on it is fragile.

**Cost.** Leaks without disciplined teardown. Unordered notifications. Cascading updates that are hard to trace, since the publisher can't tell you who reacts.

**Lighter form.** A stream/flow/signal from your platform. Pair with the lifecycle-aware collector your framework provides.

## State

**The force.** An object's behaviour depends on which of several modes it's in, and the modes have rules about legal transitions.

**Use it when**
- Behaviour varies by mode, there are many modes, and mode-specific code changes often.
- A class is full of conditionals switching on a `status` field, along with temporary fields only meaningful in some modes.
- A condition-based state machine has grown duplicated logic across similar states.

**Don't** when there are two or three states that rarely change — a conditional is clearer than a class hierarchy. The pattern earns its keep at genuine complexity.

**Cost.** A class per state, and states that reference each other, which can quietly re-couple what you split.

**Lighter form.** A sealed type for the states plus a pure transition function `(State, Event) -> State`. This is strictly better where available: transitions become a single readable table, illegal moves are rejected in one place, and the compiler checks you've handled every state. Reject illegal transitions explicitly rather than ignoring them silently.

## Strategy

**The force.** One task, several interchangeable ways to do it, chosen at runtime.

**Use it when**
- You need to swap algorithms at runtime — sorting, pricing, routing, compression, retry policy.
- Many near-identical classes differ only in one behaviour; extract that behaviour and collapse the classes into one.
- A class holds a large conditional selecting between variants of the same algorithm.
- Algorithm internals and dependencies should be isolated from the code that uses them.

**Don't** when there are two variants that never change — the conditional is fine, and the pattern's own literature concedes this. Note too that clients must know enough to *choose* a strategy, which pushes a decision outward; if the caller can't reasonably decide, the abstraction is in the wrong place.

**Cost.** An interface plus a class per algorithm, and a choice the caller now has to make.

**Lighter form.** A function value. `val price: (Order) -> Money` needs no interface and no classes, and this is explicitly acknowledged as the better answer in languages with first-class functions. A map from key to function replaces the factory too.

## Template Method

**The force.** An algorithm's skeleton is fixed; a few steps vary.

**Use it when**
- Clients should extend **specific steps** but must not restructure the algorithm — the superclass keeps the order, subclasses fill in the gaps.
- Several classes hold nearly identical algorithms; pull the shared steps up and leave only the differences below.

**Don't** when you want runtime swapping — inheritance fixes the choice at compile time, so that's Strategy. Be careful with the Liskov trap: a subclass that neuters a step by overriding it with an empty body breaks the contract the base class advertises. And each new hook makes the template harder to follow.

**Cost.** Inheritance coupling. Subclasses constrained by a skeleton they can't change. Understanding one subclass means reading two files.

**Lighter form.** A higher-order function taking the varying steps as parameters. Same shape, no hierarchy, and the steps become independently testable.

## Visitor

**The force.** Many *operations* must run over a hierarchy of *types*, and you'd rather not add a method to every type for each new operation.

**Use it when**
- You need to run an operation across a structure of differently-typed elements — an AST, a document tree, a scene graph — and the **set of types is stable** while operations keep arriving.
- Auxiliary behaviours (export, validate, measure, pretty-print) are cluttering classes whose job is something else.
- A behaviour is meaningful for only some types in the hierarchy.

**Don't** when new **types** arrive often. This is the decisive question, and getting it backwards is the classic Visitor mistake. Visitor makes adding an operation cheap (one new visitor) and adding a type expensive (every existing visitor must change). If your types churn and your operations are stable, plain polymorphism is right and Visitor is exactly inverted. Also: visitors often can't reach the private state they need, which leads to widening accessors and undoing the encapsulation you were protecting.

**Cost.** Every visitor changes when the hierarchy changes. Double dispatch is genuinely hard to read for people who haven't met it. Accessor creep.

**Lighter form.** Exhaustive pattern matching on a sealed/algebraic type. The pattern **dissolves completely** — each operation is one function with a `when` over the variants, the compiler enforces exhaustiveness, and adding a type produces compile errors at exactly the places needing attention. If the language has sealed types and exhaustive matching, prefer this and say so.
