# Pattern vs pattern

Patterns get confused because several share a structure and differ only in **intent**. That's not a flaw in the catalogue — it's the point. The name communicates *which problem you were solving*, so a reviewer reading `PaymentStrategy` learns something a reviewer reading `PaymentWrapper` doesn't.

Each entry below gives the one question that settles it. When you explain a choice to a user, give them that question, not the taxonomy.

## Contents

- [The four wrappers](#the-four-wrappers)
- [Strategy vs State](#strategy-vs-state)
- [Strategy vs Bridge](#strategy-vs-bridge)
- [Strategy vs Template Method](#strategy-vs-template-method)
- [Strategy vs Command](#strategy-vs-command)
- [Composite vs Decorator](#composite-vs-decorator)
- [Decorator vs Chain of Responsibility](#decorator-vs-chain-of-responsibility)
- [Facade vs Mediator](#facade-vs-mediator)
- [Mediator vs Observer](#mediator-vs-observer)
- [The four sender-receiver topologies](#the-four-sender-receiver-topologies)
- [Adapter vs Bridge](#adapter-vs-bridge)
- [Facade vs Proxy](#facade-vs-proxy)
- [Facade vs Abstract Factory](#facade-vs-abstract-factory)
- [Factory Method vs Abstract Factory](#factory-method-vs-abstract-factory)
- [Abstract Factory vs Builder](#abstract-factory-vs-builder)
- [Factory Method vs Prototype](#factory-method-vs-prototype)
- [Factory Method vs Template Method](#factory-method-vs-template-method)
- [Singleton vs Flyweight](#singleton-vs-flyweight)
- [Memento vs Prototype](#memento-vs-prototype)
- [Command vs Visitor](#command-vs-visitor)
- [Visitor vs plain polymorphism](#visitor-vs-plain-polymorphism)

---

## The four wrappers

Adapter, Proxy, Decorator and Facade all put an object in front of another object. **The interface they present is the whole discriminator.**

| | Interface presented | Wraps | Who composes it | Typical trigger |
|---|---|---|---|---|
| **Adapter** | a **different** one | one object | you, once | "this library doesn't fit my code" |
| **Proxy** | the **same** one | one object | often itself | "something must happen around every call" |
| **Decorator** | the **same contract, more behaviour** | one object, **stackable** | the client, at runtime | "add behaviours in combinations" |
| **Facade** | a **new, simpler** one | a whole **subsystem** | you, once | "calling this subsystem is painful" |

**Decide by asking:** *what does the caller see?*
- A different shape than before → Adapter.
- The identical shape, so it's substitutable without the caller knowing → Proxy.
- The identical shape, and I can wrap it again and again → Decorator.
- A brand-new small shape over many objects → Facade.

Two follow-on distinctions worth keeping straight:

- **Proxy vs Decorator.** Same structure, different intent and different ownership. A Proxy typically manages its subject's **lifecycle** on its own — it decides when to create it, when to release it. A Decorator's composition is always controlled by the **client**, who chooses the layers. So: "the wrapper decides" leans Proxy, "the caller decides" leans Decorator.
- **Adapter vs Facade.** Adapter makes an *existing* interface usable as-is; Facade *defines a new* interface. Adapter almost always wraps one object; Facade fronts a subsystem.

## Strategy vs State

The most-confused pair, because the class diagrams are identical: a context delegating to a swappable object.

- **Strategy** — interchangeable ways to do **one task**. The strategies are **mutually ignorant**; none knows the others exist, and none decides what runs next. The *caller* or configuration picks.
- **State** — behaviour tied to a **lifecycle**. States may know each other, and crucially a state can **reassign the context's current state**. The object appears to change its class as it moves through modes.

**Decide by asking:** *can one variant cause the next variant to be used?*
- No — they're parallel alternatives → Strategy.
- Yes — `Paid` moves you to `Shipped` → State.

Secondary tell: Strategy variants usually have the same "shape" of behaviour with different algorithms (three sort orders). State variants usually differ in *which operations are even legal* (you can't ship an unpaid order).

## Strategy vs Bridge

- **Strategy** is a single axis: one task, many algorithms, usually chosen per call or per object, often retrofitted to kill a conditional.
- **Bridge** is two axes: an abstraction hierarchy *and* an implementation hierarchy, both expected to grow, **designed together up front** to avoid an `N×M` matrix.

**Decide by asking:** *how many things vary, and did I plan this?*
- One thing varies, and I'm removing a conditional I already have → Strategy.
- Two independent things vary, and I'm structuring a subsystem before writing it → Bridge.

Bridge is architecture; Strategy is usually a refactor. If you arrived here from a `switch` statement, it's Strategy.

## Strategy vs Template Method

Both let parts of an algorithm vary.

- **Template Method** — **inheritance**. The skeleton lives in a superclass, steps are overridden in subclasses. Fixed at the **class** level, so the choice is made at compile time and can't change per instance.
- **Strategy** — **composition**. The varying behaviour is a separate object held by the context. Works at the **object** level, so it can be swapped at runtime.

**Decide by asking:** *does the variation need to change while the program runs?*
- No, and the variants are known types → Template Method is acceptable.
- Yes, or you want to avoid inheritance coupling → Strategy.

In practice prefer Strategy, or better, pass the varying steps as functions. Template Method's cost is inheritance: subclasses are welded to a skeleton they can't restructure, and understanding one means reading two files.

## Strategy vs Command

Both parameterise an object with an action, and both are often just a function.

- **Strategy** — different ways of doing **the same thing**, swapped inside one context. The point is *interchangeability*.
- **Command** — turn **any operation** into an object, with its arguments as fields. The point is that the operation becomes a **value with a life of its own**: queue it, serialise it, log it, schedule it, undo it.

**Decide by asking:** *does the operation need to outlive its invocation?*
- No, I just want to swap implementations → Strategy.
- Yes — I need history, a queue, a wire format, or undo → Command.

## Composite vs Decorator

Nearly identical diagrams; both use recursive composition.

- **Composite** — **many** children. It **combines** their results (sums a total, renders each child). It's about **structure**.
- **Decorator** — exactly **one** child. It **adds responsibility** around it. It's about **behaviour**.

**Decide by asking:** *how many children, and does the wrapper add behaviour or aggregate it?*

They cooperate happily: decorate one specific node inside a composite tree.

## Decorator vs Chain of Responsibility

Both pass execution through a series of objects built by recursive composition.

- **Decorator** — every layer runs and **must not break the flow**. Each preserves the base contract; the request always reaches the core.
- **Chain of Responsibility** — handlers are independent and **may stop the request at any point**. Short-circuiting is the feature.

**Decide by asking:** *may a layer legitimately refuse to pass the request on?*
- No, everything must reach the end → Decorator.
- Yes, and that's the point → Chain of Responsibility.

This is also the practical difference between "wrap this service in retry and logging" (Decorator) and "auth, then rate-limit, then validate — any may reject" (CoR).

## Facade vs Mediator

Both organise collaboration among tightly coupled classes.

- **Facade** — a simplified interface to a subsystem. Adds **no new functionality**. The subsystem **doesn't know the facade exists**, and its objects can still talk to each other directly. Callers may bypass it.
- **Mediator** — **centralises** communication. Components know **only the mediator** and no longer talk directly. It adds real coordination logic.

**Decide by asking:** *do the components still know about each other?*
- Yes, I've only added a convenient front door → Facade.
- No, I've rerouted all their communication through a hub → Mediator.

Corollary: if your "mediator" adds no logic and components still reference each other, you built a facade — or a middle man.

## Mediator vs Observer

Genuinely subtle, and they're often combined, which is why people can't separate them.

- **Mediator** — goal: **remove mutual dependencies** among a set of components. They all end up depending on one hub instead of on each other.
- **Observer** — goal: establish **dynamic one-way** connections, where subscribers can come and go at runtime and the publisher doesn't know who they are.

They overlap because a very common way to *implement* a mediator is to make it a publisher and the components subscribers. That implementation looks exactly like Observer while still being Mediator in intent.

**Decide by asking:** *what am I trying to eliminate?*
- Tangled `N²` coupling between known components → Mediator (however you implement it).
- Not knowing who needs to react, with subscribers joining and leaving → Observer.

Useful boundary case: if there's no central object at all and every component publishes its own events, you have a distributed set of observers, not a mediator.

## The four sender-receiver topologies

Chain of Responsibility, Command, Mediator and Observer are all answers to "how do senders reach receivers?" — four different wiring shapes.

| Pattern | Topology |
|---|---|
| **Chain of Responsibility** | a sequential chain of candidates; passed along until one handles it |
| **Command** | a one-way link from sender to receiver, with the request reified as an object |
| **Mediator** | a hub; no direct sender-receiver links at all |
| **Observer** | dynamic subscription; receivers opt in and out at runtime |

**Decide by asking:** *how many receivers, and who knows whom?*
- One receiver, unknown which, tried in order → CoR.
- One known receiver, but the request must become storable → Command.
- Many components, all mutually entangled → Mediator.
- Many receivers, membership changing at runtime → Observer.

## Adapter vs Bridge

Same shape, opposite timing.

- **Bridge** — **designed up front** so two parts of a system can be developed independently.
- **Adapter** — applied **after the fact** to make existing, otherwise-incompatible things work together.

**Decide by asking:** *did I choose this structure before or after the code existed?* That's the whole distinction.

## Facade vs Proxy

Both front a complex thing and may initialise it themselves.

- **Proxy** has the **same interface** as its subject, so the two are interchangeable.
- **Facade** has a **new, simpler** interface, and fronts a subsystem rather than one object.

**Decide by asking:** *could I drop this in where the original was, with no caller changes?* Yes → Proxy. No → Facade.

## Facade vs Abstract Factory

Abstract Factory can substitute for a Facade when the *only* thing you want to hide is **how objects get created**. If callers also need a simpler way to *use* the subsystem once they have the objects, you want a Facade.

**Decide by asking:** *am I hiding construction, or hiding usage?*

## Factory Method vs Abstract Factory

- **Factory Method** — **one** product; the decision is a **subclass override**. Less machinery, customised through inheritance.
- **Abstract Factory** — a **family** of related products that must stay mutually consistent; usually implemented as an object holding several factory methods.

**Decide by asking:** *one product, or a family that must match?* If a caller mixing variants would be a **bug**, you need Abstract Factory. If it would merely be unusual, you don't.

## Abstract Factory vs Builder

- **Abstract Factory** returns the product **immediately**, and specialises in families of related objects.
- **Builder** constructs **one** complex object **step by step**, and lets you run extra steps before you fetch the result.

**Decide by asking:** *is construction one call or a sequence?* A sequence — deferrable, possibly recursive — is Builder.

## Factory Method vs Prototype

Two ways to get an object without naming its class.

- **Factory Method** is **inheritance**-based: you need a creator hierarchy, but no initialisation dance.
- **Prototype** avoids inheritance entirely: you clone an existing instance, but you now owe correct — sometimes complicated — copy logic.

**Decide by asking:** *do I already have a configured instance to copy, or a hierarchy to hook into?*

## Factory Method vs Template Method

Factory Method is a **specialisation** of Template Method: it's a template method whose single varying step is "create the object". Conversely, a factory method often *is* one step inside a larger template method. If you're reaching for both, they're likely the same refactor.

## Singleton vs Flyweight

They resemble each other only if you reduce all shared state to a single instance. Two hard differences:

1. **Count** — Singleton permits exactly **one** instance. A Flyweight class has **many** instances, each with different intrinsic state.
2. **Mutability** — a Singleton **may be mutable**. Flyweights are **immutable**, because their state is shared across many contexts and mutating it would corrupt all of them.

**Decide by asking:** *one object, or many shared immutable ones?*

## Memento vs Prototype

Prototype is the **simpler alternative** to Memento when the object is straightforward — no links to external resources, or links that are easy to re-establish. Just clone it and keep the clone.

Reach for Memento when the state you must capture is **private** (the object snapshots itself, nobody else can read it), or when the object holds resources that make a naive copy wrong.

**Decide by asking:** *can I copy this from the outside without breaking encapsulation or resources?* Yes → Prototype. No → Memento.

## Command vs Visitor

Visitor is in a sense a more powerful Command: its objects execute operations over targets of **many different classes**, dispatching on the target's type. A Command usually encapsulates one operation against a known receiver.

**Decide by asking:** *does the operation need to behave differently per element type?* Yes → Visitor. No → Command.

## Visitor vs plain polymorphism

The decisive question, and the one people get backwards. It's the classic expression problem: you can make adding *types* cheap or adding *operations* cheap, not both.

| What grows often | Use | What becomes expensive |
|---|---|---|
| **Operations** (export, validate, measure, print) over a stable set of types | **Visitor** | adding a type — every visitor must change |
| **Types** (new node kinds keep arriving) with a stable set of operations | **plain polymorphism** — a method on each type | adding an operation — every type must change |

**Decide by asking:** *which axis is churning — my types or my operations?*

If the language has sealed types and exhaustive pattern matching, prefer matching over either. Each operation becomes one function with a `when` over the variants; the compiler enforces exhaustiveness, so adding a type produces errors in precisely the places that need attention. You get Visitor's benefit without double dispatch, and adding a type stops being silent.
