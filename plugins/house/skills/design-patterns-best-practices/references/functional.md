# Functional patterns

Two halves. **Part 1** covers what happens to the object-oriented catalogue when the language has first-class functions and algebraic data types — several patterns shrink to a line, and a few vanish. **Part 2** is the patterns that are native to functional code and have no GoF entry at all.

The forces don't change. A growing conditional is still a growing conditional. What changes is the cheapest correct answer.

## Contents

- [Part 1 — GoF in a functional setting](#part-1--gof-in-a-functional-setting)
- [Part 2 — Native functional patterns](#part-2--native-functional-patterns)
  - [Making illegal values unrepresentable](#making-illegal-values-unrepresentable)
  - [Absence and failure as values](#absence-and-failure-as-values)
  - [Composition and shaping functions](#composition-and-shaping-functions)
  - [Working with immutable data](#working-with-immutable-data)
  - [Describing effects instead of performing them](#describing-effects-instead-of-performing-them)
  - [When not to reach for the functional form](#when-not-to-reach-for-the-functional-form)

---

# Part 1 — GoF in a functional setting

**Dissolves entirely.** The pattern stops existing as a construct you build:

- **Visitor** → exhaustive pattern matching on a sealed/algebraic type. One function per operation, with a branch per variant. The compiler checks exhaustiveness, so adding a variant surfaces errors exactly where they matter. No double dispatch, no accept methods, no visitor interface to update.
- **Iterator** → lazy sequences and generators. Built into the language.
- **Memento** → immutability. The previous value *is* the snapshot; keep a reference.
- **Composite** → a recursive data type. `sealed interface Node { Leaf; Branch(children: List<Node>) }` plus functions over it.
- **Prototype** → `copy` on an immutable record.

**Shrinks to a function or a value:**

- **Strategy** → a function-typed parameter. `fun total(order: Order, price: (Item) -> Money)`. No interface, no implementing classes, no factory to select one — a map from key to function replaces that too.
- **Template Method** → a function taking the varying steps as arguments. Same skeleton, no inheritance, and each step is independently testable.
- **Command** → a closure for simple cases. When you need serialisation, replay, or undo, use a **sealed `Action` type you interpret** instead: closures can't be inspected, logged meaningfully, or sent over a wire, and a data representation can.
- **Decorator** → function composition. `val h = logging(retrying(base))`. Order is still significant, but it's visible at the call site rather than buried in wiring code.
- **Adapter** → a mapping function, usually one per direction.
- **Factory Method** → a function returning the value, or a sealed type's constructors.
- **Abstract Factory** → a record of functions, one field per product. Family consistency is preserved by passing one record.
- **Builder** → named and default arguments; `copy` on an immutable record.
- **Proxy** → a memoising or lazy wrapper function; `by lazy`.
- **Chain of Responsibility** → a list of functions each returning `Option`/`Either`, folded until one produces a result. The short-circuit becomes visible in the type.
- **State** → a sealed state type plus a pure `(State, Event) -> State` transition. Strictly better than the class-per-state form where available: transitions read as one table, illegal moves are rejected in one place, and exhaustiveness is checked.
- **Mediator** → a reducer. `(state, event) -> state` is a mediator with the coordination made explicit and testable.
- **Observer** → streams, flows, or signals.
- **Flyweight** → interning / hash-consing a canonical instance per distinct value.
- **Bridge** → parameterise by a record of functions, or by a type class / trait with multiple instances.

**Survives largely intact.** Some patterns are about *boundaries*, not about working around missing features, so they stay useful:

- **Facade** → a module with a small public surface. Still a real design act; language visibility just replaces the class.
- **Singleton** → a module-level value, or a DI-scoped instance. Same caution applies: global mutable state is as bad here as anywhere, and worse in a paradigm built on purity.
- **Builder**, when construction genuinely has *ordered steps* rather than many fields.

---

# Part 2 — Native functional patterns

## Making illegal values unrepresentable

This is the highest-leverage idea in the whole file, and it has no GoF equivalent. Rather than validating a value everywhere it's used, make the invalid version impossible to construct, then let the type carry the guarantee.

**Algebraic data types (sum types).** Model "exactly one of these" as a sealed/enum type with data attached, so nonsense combinations can't be written. The canonical fix is replacing a bag of nullable flags — `{ loading, error, data }`, where all three set means nothing — with `Loading | Failed(reason) | Loaded(data)`.

*Use when* a value has mutually exclusive shapes. *This is almost always worth doing*; it's the cheapest correctness win available.

**Newtype / tagged type.** Wrap a primitive so the compiler stops you mixing up two things that share a representation. `UserId(String)` and `OrderId(String)` are both strings, and confusing them is a runtime bug the type system can catch for free.

*Use when* primitives of the same type flow through the same code — ids, currencies, units, raw-vs-escaped strings. Especially valuable at boundaries where an unvalidated input and a validated one look identical.

**Smart constructor.** Make the constructor private and expose one function that returns `Result<T>` (or `Option<T>`). Then a value of type `T` existing at all *proves* it passed validation, and nothing downstream needs to re-check.

*Use when* a type has invariants — a non-empty list, an email, a positive quantity, a percentage in range. *Don't* when there's no invariant; a wrapper with no rule is noise.

**Phantom / state-typed values.** Encode a lifecycle in the type so illegal *operations* don't compile: `Connection<Open>` vs `Connection<Closed>`, where `send` only accepts the former.

*Use when* misuse is expensive and the state machine is small. *Don't* when it makes signatures unreadable — this one has a real legibility cost and is easy to overdo.

## Absence and failure as values

**`Option` / `Maybe`.** Absence as a value rather than a null. The win isn't avoiding a crash, it's that the *type* tells you absence is possible, so the compiler makes you handle it.

*Use when* a value may legitimately be missing. *Don't* stack it with nullability (`Option<T>?` is a bug in your model), and don't use it when the absence is an *error* the caller needs explained — that's `Result`.

**`Result` / `Either`.** Errors as return values instead of exceptions. Failures become part of the signature, so callers can't accidentally ignore them and the happy path stays readable.

*Use when* failure is expected and the caller should decide what to do — validation, parsing, network calls, anything with a business-meaningful failure. *Don't* use it for genuinely unrecoverable bugs; a programming error should crash loudly rather than be threaded politely through twenty signatures. And don't return `Result<T, String>` — a stringly-typed error can't be matched on. Use a sealed error type.

**Applicative validation.** Accumulate **all** errors rather than short-circuiting on the first. Monadic `flatMap` chaining stops at the first failure, which is right for sequential dependencies and wrong for form validation, where the user wants every problem at once.

*Use when* the checks are independent and the caller wants the full list — form submission, config loading, batch import. *Don't* when a later check depends on an earlier one's success; there you *want* short-circuiting.

**`flatMap` sequencing (the monadic pattern).** Chain operations that each might fail or be absent, without nesting conditionals. Each step receives the previous step's success value; any failure skips the rest.

*Use when* steps are sequentially dependent and each can fail. *Don't* reach for the vocabulary when the language has `?.`, `?`, `try`, or for-comprehensions that express the same thing more legibly — and be careful about mixing effect types, which is where this stops being readable and starts needing transformers.

## Composition and shaping functions

**Higher-order functions.** Take or return a function. This is the mechanism most of Part 1 rests on — parameterising behaviour without parameterising types.

**Function composition and pipelines.** Build a big transformation from small named ones. Each stage is independently testable and the data flow reads top to bottom.

*Use when* you have a sequence of transformations over one value. *Don't* build unreadable point-free chains to prove a point; a named intermediate variable is often clearer than another combinator.

**Partial application / currying.** Fix some arguments now, supply the rest later. Useful for configuration: build a `logTo(sink)` once and pass the specialised function around, rather than threading `sink` through every call.

*Use when* one argument is fixed across many calls. *Don't* curry everything by default in a language where it isn't idiomatic.

**Transducers.** Compose transformation steps (`map`, `filter`, `take`) into one composite step that runs in a **single pass** with no intermediate collections. Decoupled from the source, so the same pipeline works over a list, a channel, or a stream.

*Use when* you're chaining many operations over large or streaming data and the intermediate allocations matter. *Don't* when the collection is small — plain `map`/`filter` is far more readable, and most languages' lazy sequences already avoid the intermediates.

**Memoisation.** Cache a pure function's results by its arguments. Sound *only* because the function is pure — the same reason it's dangerous to bolt onto something that isn't.

*Use when* the function is pure, expensive, and called repeatedly with a bounded set of arguments. *Bound the cache*; an unbounded memo table is a memory leak wearing an optimisation costume.

**Trampolining.** Convert deep recursion into a loop over returned thunks, to avoid stack overflow in a language without tail-call elimination.

*Use when* recursion depth is data-dependent and unbounded. *Don't* when a plain loop is clearer, which is often.

## Working with immutable data

**Persistent data structures.** Structures that share unchanged parts between versions, so "copying" is cheap. This is what makes immutability practical at scale, and what makes undo/redo nearly free.

*Use when* you keep multiple versions, or update large structures often. *Don't* hand-roll them — use the library.

**Lenses and optics.** Composable getter/setter pairs for reaching into nested immutable data. Without them, updating one deep field means rebuilding every enclosing record by hand, and the code is both unreadable and easy to get wrong.

*Use when* you're doing repeated deep updates into nested immutable structures. *Don't* when nesting is one or two levels — the language's `copy` handles that, and a lens library is a real conceptual cost. Often the better answer is **flattening the data** so the deep update disappears; reaching for optics can be a signal the model is over-nested.

**Folds (catamorphisms).** Collapse a structure to a value with an accumulator. `reduce`/`fold` generalises sum, count, max, group-by and most aggregation.

*Use when* deriving one value from many. *Don't* use a clever fold where `sum()` exists.

**Copy-on-write / structural update.** Return a new value with one field changed rather than mutating in place. The default in functional code, and the thing that makes concurrency reasoning tractable.

## Describing effects instead of performing them

**Interpreter / free-monad style.** Build a **data description** of what should happen, then run it in a separate interpreter. Because the description is inert data, you can inspect it, test it without side effects, optimise it, or run it against a different backend.

*Use when* you need to test complex effectful logic without performing the effects, or run the same program against a real and a fake backend. This is what makes a sealed `Action` type better than a closure for Command.

*Don't* reach for it casually. It's a heavyweight abstraction with a steep readability cost, and in most codebases a plain interface with a fake implementation gets you the same testability for a fraction of the concept budget. Reserve it for genuinely complex effect orchestration.

**Reader / dependency passing.** Thread configuration or dependencies through a computation without a global. Usually the simple version — pass the dependency as a parameter — is the right one.

*Use when* many functions in a call chain need the same context. *Don't* build a Reader monad where a parameter or a partially-applied function would do.

**State threading.** Pass state in and return the updated state, rather than mutating. `(State, Event) -> State` is the everyday form and it's enough for almost everything.

## When not to reach for the functional form

Say which of these applies when you keep the object-oriented version — the reason matters more than the choice:

- **The codebase is uniformly OO.** A lone functional construct in a Java or C# codebase reads as foreign, and `coding-best-practices` is explicit that touched code keeps the file's idiom. Note the alternative separately instead of smuggling it in.
- **You want the name.** `RetryPolicy` as a type communicates intent to reviewers in a way `(Request) -> Response` doesn't. Vocabulary is a legitimate reason to keep a type.
- **There's state and lifecycle.** A bare function hides that something must be initialised, held, and disposed. A class makes the lifecycle visible, and resource cleanup is easier to get right.
- **The language fights you.** Verbose function types, no type inference in the position you need, or a runtime that boxes every closure in a hot loop.
- **The team doesn't know the vocabulary.** A correct solution nobody can maintain is a worse outcome than a slightly heavier one they can. This is a real engineering constraint, not a concession — but the honest version is "we'll use the simpler form", not "the functional form is wrong."
