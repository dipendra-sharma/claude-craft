# Evidence-gated abstraction, worked

The gate first, because it decides whether any of this applies: **2+ concrete implementations existing today (or imminently required), or a genuine test-isolation need the framework can't handle otherwise.** A lone interface "for flexibility" is speculative abstraction — add it the day the second variant arrives. Where this conflicts with a pattern recommendation from any other source, YAGNI and KISS win.

Render each of these in the target's idiom. In a functional or procedural codebase "inject the dependency" means passing a function or a value — do not introduce classes to satisfy the shape of a principle.

## A. Composition over inheritance
Inheritance creates rigid hierarchies that break when assumptions change; composition mixes only the behaviors a thing actually has.

**Bad:** `Penguin extends Bird` inherits `fly()` then throws in it — a subtype that can't stand in for its supertype.
**Good:** compose `canSwim` + `canWalk` for penguin, `canFly` + `canWalk` for eagle.

Inheritance still earns its place for genuine is-a hierarchies with a stable contract, and for framework base classes you don't control. The smell is inheriting to reuse an implementation.

## B. Open/Closed
Adding a variant should mean adding code, not editing working code.

**Bad:** `area(s){ if s.type=="circle" return PI*s.r*s.r; if s.type=="square" return s.side*s.side }` — every new shape edits this working function.
**Good:** each shape owns its `area()` (`circle.area()`, `square.area()`); adding `Triangle` with its own `area()` touches nothing existing.

Counterweight: in a language with exhaustive pattern matching over a sealed/closed type, the `switch` is often *better* than polymorphic dispatch — the compiler tells you every place a new variant must be handled, which is exactly the safety Open/Closed is trying to buy. Prefer the sealed match when the variant set is genuinely closed and the behaviors are few.

## C. Dependency inversion
High-level code depends on an abstraction, not a concrete implementation; inject the dependency as a value, function, or interface.

**Bad:** `OrderService(){ this.db = new MySQLDatabase(HOST) }` — bound to one concrete DB, so a test can't swap it.
**Good:** `OrderService(repo){ this.repo = repo }` — pass a Postgres repo in prod, an in-memory one in tests.

Prefer the smallest form that works: a pure parameter beats a passed function, which beats an injected object, which beats a DI container. `getGreeting(hour)` needs no abstraction at all — reach for injection only when the dependency is genuinely stateful or swapped at runtime.
