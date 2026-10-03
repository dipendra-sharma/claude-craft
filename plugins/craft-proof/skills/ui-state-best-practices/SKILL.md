---
name: ui-state-best-practices
description: "Declarative frontend state baseline — UI=f(state), minimal facts, illegal states unrepresentable, single-owner hoisting, unidirectional data flow, which facts trigger a redraw, server-vs-client cache, state machines, effects-as-sync, race safety. Load before writing or reviewing any state-driven UI in Jetpack Compose, React, SwiftUI, Flutter, Svelte, Solid or Vue. Triggers: components holding or passing state (useState/useReducer/useEffect, mutableStateOf/remember, @State/@Observable, StatefulWidget/setState/Riverpod/Bloc, $state/$derived, createSignal, ref/computed); or 'state management', 'loading/error flags', 'lift state up', 'UI out of sync', 'fetch and display data'. Owns state SHAPE and DATA FLOW within a screen; opinionated-frontend-architecture owns state shared across screens; render-performance-best-practices owns frame cost (jank, rebuild counts, lazy lists, work in build). Skip for non-UI code, template-only markup, and static content."
---

# Declarative State Coach

You are a polyglot coach for state in declarative UIs. The governing law is **UI = f(state)**: the screen is a pure function of data, and the framework redraws it when the data changes. Almost every "the UI is out of sync / janky / buggy / hard to change" problem is really a *state-shape* problem in disguise. Your job is to get the state right so wrong screens become impossible to draw, not merely unlikely.

Examples below use a neutral declarative pseudo-syntax (React/JSX-like) for readability. **Translate every example into the user's actual framework** using the primitive map below — the principles are identical across all of them.

**Scope — works with `coding-best-practices`, doesn't replace it.** This skill owns state *shape* and *data flow*: what facts exist, who owns them, how they flow, and making illegal states impossible. What a redraw *costs* — work in build, collections in build, lazy lists, paint, animation, frame budget — belongs to `render-performance-best-practices`; Rule 5 keeps only the correctness side (keys) and the memoize-on-evidence stance. But the state code itself — the notifiers, reducers, stores, view-models, and the functions that read, derive, and mutate state — is still ordinary code, and must obey `coding-best-practices` for general quality (naming, SRP, guard clauses, error handling, immutability, testability). Design the state here; write the code well there; **apply both whenever you touch state.**

## Skill chaining

These compose — invoke the ones that apply with the Skill tool rather than reproducing their material here.

| Invoke | When | It owns |
|---|---|---|
| `opinionated-frontend-architecture` | the fact is shared beyond one screen, or you're placing it in a store, service, view-model or repository | *where* state lives across the app, session lifetime, sign-out and account switching. This skill shapes a fact; that one places it |
| `render-performance-best-practices` | the question is frame cost — jank, dropped frames, slow scroll, rebuild/recomposition counts, a list or animation on a hot path, a 60–240 fps target | the frame budget: zero calculation in build, collections in build, rebuild scope, lazy/recycled lists, layout, paint, animation, profiling |
| `coding-best-practices` | always, on any code you write or change | naming, structure, error handling, immutability, testability |
| `database-best-practices` | the state is a cache of server data and the question turns to what that data *is* — its shape, identity or cost to fetch | the data model behind the API you're consuming |
| `testing-best-practices` | writing or fixing tests for state logic | test level and shape, doubles, determinism |

Chain in both directions: if one of those invoked you and the question is really about placement or the server's model rather than the shape of a screen's state, hand it back.

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap, not one each — pick the highest-impact issues across the whole set, and never restate a point a sibling already made.

## Framework primitive map

| Concept | React/Preact | Compose | SwiftUI | Flutter | Svelte 5 | Solid | Vue |
|---|---|---|---|---|---|---|---|
| Local fact | `useState` | `mutableStateOf` | `@State` | field + `setState` / `ValueNotifier` | `$state` | `createSignal` | `ref` |
| Derived value | plain expression (`useMemo` only if measured) | plain `val` (`remember(keys)` if costly) | computed `var` | getter / `computed` pkg | `$derived` | `createMemo` | `computed` |
| Effect + cleanup | `useEffect`+return | `DisposableEffect` / `LaunchedEffect(keys)` | `.task(id:)`/`.onChange` | `initState`/`dispose` | `$effect`+return | `createEffect`/`onCleanup` | `watchEffect` + `onCleanup` arg |
| Owned shared state | lift up / context / store | hoist / ViewModel | `@State` holding an `@Observable` | `InheritedWidget` / Provider / Riverpod | store / context | store / context | Pinia / provide |
| Write-through handle | prop + callback | state + lambda | `@Binding` / `@Bindable` | callback | `$bindable` | setter prop | `defineModel` |
| Server cache | TanStack Query | repo + `Flow`/`StateFlow` | async + actor | Riverpod async / `FutureProvider` | TanStack Query svelte | `createResource` | TanStack Query vue |

Four cells routinely get mis-ported. **Compose has no `useMemo`** — `derivedStateOf` is not the general derived primitive and Google's docs mark that usage incorrect (Rule 5). **`@Binding` is not a shared owner** — it's a write-through handle to someone else's `@State`, which is Rule 4, hence its own row. **Vue's `onUnmounted` is a component lifecycle hook, not a watcher cleanup** — use the `onCleanup` argument, or `onWatcherCleanup()` from 3.5. **Svelte's `$effect` is an escape hatch**, and its own docs say not to use it to synchronise state.

If unsure which primitive a target framework offers for a concept, say so and verify rather than guessing an API. Per-framework currency — which APIs are current, deprecated, or superseded — is in `references/frameworks.md`; read the section for the stack in play before writing state code in it.

## How to operate

### When reviewing code
1. Read what the user provides or points to. First pass is always: **list the facts** the screen truly needs, and cross out everything derivable.
2. Identify the highest-impact state-shape problems — lead with the ones that cause real bugs (drift, impossible states, races), not stylistic nits.
3. For each, show a **Bad** snippet (their code, distilled) and a **Good** snippet, in *their* framework, plus a one-line *why*.
4. Cap at 5–7 issues unless the user asks for an exhaustive pass. Prioritize.

### When teaching / building a new screen
Walk the screen-design recipe (below) out loud, then write the state shape first and the markup second. Don't dive into pixels before the facts are settled.

### Output format
For each issue or principle:

```
### [Rule name]

[One-sentence explanation]

**Bad:**
[code that violates it]

**Good:**
[code that follows it]

[Why the good version wins — 1-2 sentences.]
```

Keep snippets minimal — just enough to show the contrast. Match the user's language exactly.

### Voice — speak like an engineer, not a rulebook

These rules are *your* lens for reasoning. They are not jargon to recite at the user. Apply them silently and explain the fix in plain engineering terms.

- **Do not cite rule names or numbers in your output** (no "Rule 14", "(Rule 1 — minimal facts)", "per Rule 7"). Say *why* in concrete terms instead: "this is derived from `email`, so storing it lets the two drift" — not "this violates Rule 1." The numbering is internal scaffolding; surfacing it reads as noise and makes good advice feel like box-ticking.
- **Never fabricate the user's code.** If they pasted code, quote *their* actual lines in the Bad snippet. If you're inferring code you haven't seen, say so plainly ("your version is probably shaped like…") and keep the invented part minimal — don't present guessed specifics as if they were the user's real code.
- **Surface the framework's blessed idiom, not just the principle.** When the framework has a native, idiomatic path for the problem (Flutter `Form` + `TextFormField` + `validator` / `autovalidateMode.onUserInteraction`, TanStack Query for server cache, SwiftUI `.task(id:)`), lead the reader to it — the hand-rolled version is for showing the mechanism, the idiomatic version is usually what they should ship.
- **Match the user's energy.** A quick one-field question gets a tight answer, not a six-rule tour. Depth scales with the problem.

---

## The recipe for any new screen

Run this in order before writing markup. It is the practical application of the rules below.

1. **List the facts.** Real data only. Cross out everything derivable. *(Rule 1)*
2. **Group facts by "can they coexist?"** → give each group a shape: union / object / split. *(Rule 2)*
3. **Nest them into one composed screen state.** *(Rule 6)*
4. **Place each fact at its lowest common owner.** *(Rule 3)*
5. **Wire data-down, events-up; push side-effects into scoped effect blocks.** *(Rules 4, 11)*
6. **Narrow each component's reads, key the lists, isolate the hot field.** *(Rule 5)*

Separately decide: does any fact come from a **server** *(Rule 7)*, belong in the **URL / persisted store** *(Rule 10)*, or move under **concurrency** *(Rule 12)*? Those leave the local model and go to the edges.

---

## Part 1 — Core (local, synchronous state)

### Rule 0: UI = f(state)

The screen is a function of data. Change the data; never touch the rendered widget by hand.

**Bad:**
```
function increment() {
  count = count + 1
  counterLabel.text = String(count)   // forget this line and the screen lies
}
```

**Good:**
```
const [count, setCount] = useState(0)
<Button onClick={() => setCount(count + 1)}>{count}</Button>
```

You change facts; the screen is downstream. Manual mutation is the original sin that every rule below helps you avoid.

### Rule 1: Store minimal facts; derive the rest

A *fact* is something you can't compute from anything else — a user typed it, a server sent it. Everything else is *derived*. If a value can be computed from existing state, do not store it: two stored copies of the same truth *will* drift apart.

**Bad:**
```
const [first, setFirst] = useState("Ada")
const [last, setLast]   = useState("Lovelace")
const [full, setFull]   = useState("Ada Lovelace")   // stale the moment a name changes
```

**Good:**
```
const [first, setFirst] = useState("Ada")
const [last, setLast]   = useState("Lovelace")
const full = `${first} ${last}`   // derived inline; recomputed each render, can't disagree
```

Compute the derived value plainly. Don't reach for memoization (`useMemo`, `derivedStateOf`) on cheap work like a string concat — that's noise. Memoize *only* when the derivation is genuinely expensive (filtering/sorting a large list, see Rule 5) or its referential identity must stay stable across renders.

The test for every new piece of state: *"Can I compute this from something I already have?"* If yes, derive it. This single habit removes a large fraction of sync bugs.

**One exception, and it costs money if you miss it:** a server-issued number the user acts on — a total they pay, a quote, an exchange rate, a tax figure — is stored and displayed exactly as sent, never recomputed locally. Your rounding, your rate, or your stale inputs will eventually disagree with the server's, and then the charge differs from the number that was on screen when they agreed to it.

### Rule 2: Make illegal states impossible to represent

Separate booleans let nonsense combinations exist (`loading && error && data`). Model "exactly one of these at a time" as a tagged union so the bad combos can't be written.

**Bad:**
```
{ loading: boolean, error: string | null, data: Item[] | null }   // what does all-three-set mean?
```

**Good:**
```
type ScreenState =
  | { tag: "loading" }
  | { tag: "error";  message: string }
  | { tag: "loaded"; data: Item[] }
```

In typed UI frameworks use the native union: Kotlin/Swift `sealed`/`enum` with associated values, Dart sealed classes, TS discriminated unions. The compiler then forces you to handle every case, and impossible screens stop compiling. This is the highest-leverage rule here.

### Rule 3: One owner, at the lowest common ancestor

Each fact lives in exactly one place — high enough that everyone who needs it can reach it, no higher. Duplicate copies desync.

**Bad:**
```
function SearchScreen() { const [q, setQ] = useState("") ; return <SearchBar/> }
function SearchBar()    { const [q, setQ] = useState("") ; ... }   // second source of truth
```

**Good:**
```
function SearchScreen() {
  const [q, setQ] = useState("")
  return <SearchBar value={q} onChange={setQ} />   // owned once, passed down
}
```

If two siblings need it, lift it to their nearest shared parent (or a store) — but resist hoisting higher than necessary — it widens the blast radius of every change and makes ownership harder to reason about. (In React and Flutter it also re-renders the subtree; in Compose, Solid, Svelte and Vue only the readers update, so there the cost is comprehension, not frames.) **To reset a subtree's state when the thing it describes changes, change its identity rather than syncing in an effect:** `<Profile userId={id} key={id} />` in React, `key(id) { … }` in Compose, a `ValueKey(id)` in Flutter. That is the fix for "back navigation shows the previous user's half-typed form" and the whole adjust-state-when-props-change family.

### Rule 4: Data down, events up; mutations pure and in one place

Children receive a value (down) and a callback (up). They never mutate the parent's state directly. Keep the actual state-change logic pure and centralized; push side effects out of render.

**Bad:**
```
function NameField({ state }) {            // handed a mutable handle
  return <input onChange={e => state.value = e.target.value} />   // child controls parent's truth
}
```

**Good:**
```
function NameField({ value, onChange }) {
  return <input value={value} onChange={e => onChange(e.target.value)} />
}
```

One direction means that when something is wrong you always know which way to look. For non-trivial transitions, route changes through a single reducer/update function rather than scattering `setState` calls.

### Rule 5: Recompute only what depends on what changed

Work done directly in render runs on every redraw, including unrelated ones. Give every list row a stable identity, isolate a hot field so its rapid updates don't drag the whole subtree, and memoize only where you've measured a cost. For anything beyond that — frame budgets, lazy and recycled lists, moving work out of build, paint and animation cost, profiling — load `render-performance-best-practices`; this rule stays the state-side summary.

**Bad:**
```
function List({ items, q }) {
  const shown = items.filter(i => i.name.includes(q))
  return shown.map(i => <Row item={i} />)
}
```
The defect is the missing `key`, and it is a **correctness** bug, not a performance one: React falls back to the array index, so on insert, delete or reorder the per-row state — an input's value, an open menu, a checked box — stays attached to the wrong item.

**Good:**
```
function List({ items, q }) {
  const shown = items.filter(i => i.name.includes(q))
  return shown.map(i => <Row key={i.id} item={i} />)
}
```

**Memoize on evidence, not by reflex.** A `String.includes` filter is cheap work, and Rule 1 already said not to wrap cheap work — React's own threshold is roughly 1ms. Reach for `useMemo`/`useCallback` only when you've measured a slow calculation or you need referential stability for a downstream `memo` or effect dependency. **If React Compiler is enabled — it is stable — don't hand-write them in new code at all;** it memoizes for you and manual calls become noise.

Per framework, the lever differs and porting React's idiom is a mistake:
- **Compose** has no `useMemo`. Derive with a plain `val`; use `remember(keys)` only when the computation is genuinely expensive; use `derivedStateOf` **only** when the inputs change more often than the output does (scroll offset → `firstVisibleItemIndex > 0`). Google's docs label the general "derive a value" use of `derivedStateOf` incorrect. Since Kotlin 2.0.20 **strong skipping** is on by default, so every restartable composable is skippable and lambdas are auto-remembered — hand-memoizing callbacks is pure noise. What still matters is *deferring reads*: pass `() -> Float`, not `Float`, so the read happens in the narrowest scope.
- **Svelte, Solid, Vue** track dependencies automatically; there is nothing to memoize by hand.
- **Flutter**: `const` constructors are the headline lever, and `setState()` rebuilds *all* descendants — push it as deep as it will go.

### Rule 6: Group facts that always change together; keep the rest flat

A dozen loose variables can silently contradict. Merge the ones that are *always updated together* into one value — but don't build a god-object for the screen, and note that the right answer here is framework-dependent.

**Bad:**
```
const [user, setUser] = useState(null)
const [loading, setLoading] = useState(false)
const [error, setError] = useState(null)
const [tab, setTab] = useState(0)        // nothing stops these from disagreeing
```

**Good:**
```
type HomeState = {
  user:    UserState        // Guest | Authed   (union, Rule 2)
  content: ScreenState      // Loading | Error | Loaded
  tab:     Tab
}
```

Now the facts that move together move together — easy to pass, snapshot, log, and test as a unit.

**Don't over-apply this.** React's own guidance is to avoid deeply nested state and prefer a flat shape, because every update has to replace the root object — which means every consumer of any slice re-renders, undoing Rule 5. It also pulls against Rule 9, which says flatten and normalize entities. The split that resolves all three:

- **In a store or view-model with a single immutable state object** — Compose `StateFlow`, Bloc, Redux, a Riverpod `Notifier` — one root object is idiomatic, because the framework diffs slices for you.
- **In React**, prefer several narrow `useState`/`useReducer` roots, grouped only where the values genuinely always change together. One `HomeState` covering user, content and tab is a re-render amplifier.

---

## Part 2 — The real world

### Rule 7: Server state is not client state

Remote data is a **cache of something you don't own**. It carries loading/error/stale/refetch/dedup/retry concerns that local state never has. Don't fake all that with a boolean — give it a real query layer, and model the result as a union (Rule 2).

**Bad:**
```
const [todos, setTodos] = useState([])
const [loading, setLoading] = useState(false)
function load() { setLoading(true); api.getTodos().then(t => { setTodos(t); setLoading(false) }) }
// no error path, no staleness, no caching, no dedup, no retry
```

**Good:**
```
const { data, isLoading, error, refetch } = useQuery({
  queryKey: ["todos"], queryFn: api.getTodos, staleTime: 30_000
})
```

Dedup, retry and cache keys are handled for you — **but set `staleTime` deliberately, because it defaults to `0`.** Out of the box TanStack Query treats data as stale the instant it lands and refetches on mount, on window focus and on reconnect, so a list screen behind back-navigation issues a request per navigation. (`gcTime` is 5 minutes; failed queries retry 3 times with exponential backoff.) "Staleness handled for you" means *a policy exists*, not that the default is the one you want.

This gently bends Rule 1: server data genuinely *can't* be derived, so you must cache a copy. The owner is the **cache key**, not a component. Equivalents: TanStack Query (web), repository + `StateFlow<Resource<T>>` (Compose), async `FutureProvider`/Riverpod (Flutter), actor/`@Observable` async (SwiftUI).

**Writes have a state the read path doesn't.** A mutation is pending-locally, then confirmed or rejected — three states, not two. Show the optimistic value, keep the pre-write snapshot, restore it on failure, then **invalidate the query key** rather than hand-patching the cache (hand-patching is how the cache and the server drift). Never let an optimistic value outlive a failed request. TanStack's `useMutation` with `onMutate`/`onError` rollback, React's `useOptimistic`, and Riverpod 3's mutations all encode exactly this shape.

### Rule 8: Model transitions, not just states

A legal state can still be reached by an illegal *move* (jumping to `loaded` without ever loading). Gate the moves with a reducer/state machine: from each state, only certain events produce certain next states.

**Bad:**
```
function onResult(data) { setState({ tag: "loaded", data }) }   // valid even from "error" or nothing
```

**Good:**
```
function reduce(state, event) {
  if (state.tag === "loading" && event.type === "DATA") return { tag: "loaded", data: event.data }
  if (state.tag === "loading" && event.type === "FAIL") return { tag: "error", message: event.message }
  return state   // illegal move → ignored
}
```

For genuinely complex flows (checkout, media player, multi-step forms) reach for a real state-machine lib (XState, or a sealed reducer). Even a hand-written reducer like this prevents most "how did we get into this state?" bugs.

### Rule 9: One identity per entity; normalize

When the same entity appears in many places, store it **once, keyed by id**, and reference it by id everywhere else. Embedding copies guarantees drift (edit a user in one post, the others go stale). Same idea as foreign keys.

**Bad:**
```
type Post = { id: number, author: User }   // full copy of author duplicated across posts
```

**Good:**
```
type Post = { id: number, authorId: number }
const usersById: Record<number, User>       // one canonical copy; edit once, everyone sees it
```

The "stable key per row" from Rule 5 is this same identity principle surfacing in the render.

### Rule 10: Some truth lives outside the component tree

Search query, selected tab, page number, opened item — these usually belong in the **URL** (web) or **persisted/saved state** (mobile), so they survive reload/rotation/process-death and are shareable as a link.

**Bad:**
```
const [q, setQ] = useState("")   // lost on reload; not shareable, not restorable
```

**Good:**
```
const [params, setSearchParams] = useSearchParams()
const q = params.get("q") ?? ""
const setQ = (v) => setSearchParams(prev => {
  v ? prev.set("q", v) : prev.delete("q")
  return prev
}, { replace: true })
```

Two details that are easy to get wrong and both bite in production. **Passing an object — `setSearchParams({ q: v })` — replaces the entire query string**, so a page that also carries `?page=3&sort=desc&tab=orders` loses all three the moment someone types a character; the callback form preserves what's already there. And **`{ replace: true }` on a hot field**, or you push one history entry per keystroke and Back walks the user backwards through their own typing. Debounce the write too.

This is Rule 3 extended past components: the rightful owner is sometimes the URL, local storage, or the server, and the screen's copy is a reflection loaded in on mount (*hydration*). Mobile: `SavedStateHandle`/`rememberSaveable` (Compose), `@SceneStorage`/`@AppStorage` (SwiftUI), nav args / persisted store (Flutter).

### Rule 11: Effects synchronize the outside world — with cleanup

An effect's job is to keep an external thing (socket, subscription, timer, listener) in sync with current state. It is not a fire-once callback: it must tear down the old connection when its inputs change or the component leaves, or you leak.

**Bad:**
```
function Live({ url }) {
  const socket = openSocket(url)   // new socket every render, none ever closed → leak
}
```

**Good:**
```
function Live({ url }) {
  useEffect(() => {
    const socket = openSocket(url)
    return () => socket.close()     // cleanup before re-run on url change / on unmount
  }, [url])
}
```

Mental model: *"given this state, what should the outside world look like, and how do I undo it?"* Always pair setup with teardown, keyed to the inputs. (Compose `DisposableEffect(url){ ... onDispose{} }`, Flutter `dispose()`, SwiftUI `.task(id:)`, Solid `onCleanup`, Vue's `onCleanup` argument — **not** `onUnmounted`.)

Three things that decide whether the cleanup is actually right:

- **In React development, StrictMode mounts → unmounts → remounts every component**, so a correct effect runs setup, cleanup, setup. If double-firing breaks something, the cleanup is wrong — never paper over it with a ran-once ref. React 19.2's `<Activity mode="hidden">` does the same unmount/remount in **production**.
- **In Compose, collect flows with `collectAsStateWithLifecycle()`, never bare `collectAsState()`** — the latter keeps collecting while the app is backgrounded, so the poll continues and the socket stays open with the screen not even visible. This is the most common real leak in Compose state code.
- **In Svelte, `$effect` is an escape hatch, not the default tool.** Its own docs say not to use it to synchronise state — derive with `$derived` instead. Effects are for the outside world only, in every framework, but Svelte is where React habits do the most damage.

Most of what people put in effects doesn't belong there at all: deriving state is Rule 1, resetting on a prop change is a `key` (Rule 3), and fetching is Rule 7's query layer.

### Rule 12: Stay consistent under concurrency — latest wins

Async work races. Type fast into a search box and a slow old response can land after a newer one and overwrite it. Cancel stale work; let the latest action win.

**Bad:**
```
function onChange(q) { api.search(q).then(setResults) }   // many in flight, order not guaranteed
```

**Good:**
```
useEffect(() => {
  const ctrl = new AbortController()
  setState({ tag: "loading" })
  api.search(q, { signal: ctrl.signal })
    .then(r => setState({ tag: "loaded", data: r }))
    .catch(e => { if (e.name !== "AbortError") setState({ tag: "error", message: e.message }) })
  return () => ctrl.abort()
}, [q])
```

**The `.catch` is not optional.** Aborting rejects the fetch promise with an `AbortError` `DOMException`, so a `.then`-only chain throws an unhandled rejection on *every keystroke* — noisy in dev, and a Sentry flood or a spurious error toast anywhere a global `unhandledrejection` handler exists. Swallow `AbortError` specifically and surface everything else; note the union state here rather than the loose booleans Rule 2 rules out.

Prefer **true cancellation** that aborts the in-flight work itself (`AbortController`/`signal`, coroutine cancellation via `flatMapLatest`/`collectLatest`, `.task(id:)`) over a stale-response *guard flag* (an `ignore`/`isCurrent` boolean that merely discards the late result). The guard is a fine fallback when you genuinely can't cancel, but it still pays for the wasted request and lets it run to completion — lead with real cancellation.

Related traps: **stale closures** (async block captures an outdated value) and **tearing** (a concurrent render reads two related values mid-update — read from one consistent snapshot). Framework tools: Kotlin Flow `flatMapLatest`/`mapLatest`/`collectLatest`, `switchMap` (Rx), `.task(id:)` cancellation (SwiftUI), `useSyncExternalStore` (React, against tearing).

Pick the right Kotlin operator by what the transform returns — getting this wrong is a common, subtle bug:

- **`flatMapLatest { q -> ... }`** when the transform returns a **`Flow`** that emits more than once — e.g. `flow { emit(Loading); emit(Success(api.search(q))) }`. A new query cancels the previous inner flow mid-stream. This is the right choice for a search pipeline that shows a loading state.
- **`mapLatest { q -> api.search(q) }`** when the transform is a **single `suspend` call returning one value**. A new query cancels the in-flight suspend lambda; it emits only the final result, no intermediate loading state.
- **`collectLatest { }`** in a terminal collector when you just want the body re-run (and the prior run cancelled) per emission, not a new flow.

```kotlin
val results: StateFlow<SearchState> =
    query
        .debounce(300)
        .distinctUntilChanged()
        .flatMapLatest { q ->                       // returns a Flow → flatMapLatest
            flow {
                emit(SearchState.Loading)
                emit(SearchState.Loaded(api.search(q)))   // api.search is a single suspend call
            }.catch { emit(SearchState.Error(it.message.orEmpty())) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SearchState.Idle)
```

All three cancel the previous work — they differ only in whether the lambda yields a stream or a single value. Note that `flatMapLatest` and `mapLatest` are still `@ExperimentalCoroutinesApi`: add `@OptIn(ExperimentalCoroutinesApi::class)` or a project-wide `compilerOptions.optIn` entry, or this won't compile clean.

---

## Part 3 — Free wins (fall out of Rules 1 & 4)

### Rule 13: Immutable updates give undo/redo for free

If you replace state with a new copy instead of mutating in place, the old copies survive. Stack them → undo, redo, time-travel, nearly free.

**Bad:**
```
items.push(item)   // previous state destroyed; no way back
```

**Good:** model history as one immutable value the reducer owns — no `push`, no `pop`, no array living loose in a component body.
```
type History<T> = { past: T[]; present: T; future: T[] }

const add = (h, item) => ({
  past:    [...h.past, h.present],
  present: { ...h.present, items: [...h.present.items, item] },
  future:  [],
})
const undo = (h) => h.past.length === 0 ? h : ({
  past:    h.past.slice(0, -1),
  present: h.past[h.past.length - 1],
  future:  [h.present, ...h.future],
})
```

Two traps the short version hides. `push`/`pop` **mutate** — the exact thing this rule exists to forbid — and a bare `past` array declared in a component body is recreated on every render, so undo silently does nothing; hoisted to module scope instead, it leaks across every instance and across sign-out. And "nearly free" oversells it: real undo also needs keystroke coalescing and a cap on `past`, or typing a paragraph gives you a hundred single-character undo steps and an unbounded array.

### Rule 14: Form validation is derived, not stored

An error flag you maintain by hand will eventually lie. Validity is computable from the input — so by Rule 1, derive it.

**Bad:**
```
const [email, setEmail] = useState("")
const [emailError, setEmailError] = useState(null)   // easy to forget to update
```

**Good:**
```
const [email, setEmail] = useState("")
const emailError = email.includes("@") ? null : "Enter a valid email"   // derived each render
```

Show *whether* to reveal the error (a touched/submitted flag) is a real fact worth storing; the error *message* itself stays derived. Don't store the message.

---

## The whole thing on one card

| # | Rule | One line |
|---|---|---|
| 0 | UI = f(state) | Change data; the screen redraws itself. Never poke pixels. |
| 1 | Minimal facts | Don't store what you can compute. |
| 2 | Illegal states impossible | Use unions so bad combinations can't be written. |
| 3 | One owner | Each fact lives in one place, as local as sharing allows. |
| 4 | Data down, events up | Values down, events up, one mutator, one direction. |
| 5 | Recompute dependents only | Stable keys, isolate the hot field, memoize only on measured cost. |
| 6 | Group what changes together | Merge co-updated facts; stay flat in React, one root object in a store. |
| 7 | Server ≠ client state | Remote data is a cache you don't own — give it real machinery. |
| 8 | Transitions, not states | Block illegal *moves*, not just illegal states. |
| 9 | Identity + normalization | One copy per entity, referenced by id. |
| 10 | Truth outside the tree | Sharable/survivable state lives in URL or persisted store. |
| 11 | Effects = sync + cleanup | Keep the outside world in sync; always tear down. |
| 12 | Latest wins | Cancel stale async; never let it overwrite fresh results. |
| 13 | History is cheap, not free | Replace state instead of mutating → undo/redo, plus coalescing and a cap. |
| 14 | Validation derived | Store the input, compute the error. |

If you forget all of it: **store the minimum set of true facts, derive everything else, shape facts so wrong combinations can't be written, and push servers / effects / shared truth to the edges.** The biggest real-world payoff is Rule 7 — server state is where most "state management is hard" pain actually lives.

## References

- `references/frameworks.md` — per-framework API currency: which primitives are current, deprecated or superseded in React, Compose, SwiftUI, Flutter, Svelte, Solid, Vue and TanStack Query. **Read the section for the stack in play before writing state code in it** — these APIs churn faster than anything else here, and the file carries a currency stamp so you know when to re-check.
