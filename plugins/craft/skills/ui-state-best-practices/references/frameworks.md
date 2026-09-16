# Framework currency

**Currency stamp: 2026-09-06.** These APIs churn faster than anything else in the skill, and a confidently-wrong API name is worse than an admitted gap. If a claim here matters to what you're writing, re-check it against the framework's own release notes before relying on it.

---

## React

**React Compiler is stable.** It auto-memoizes, and React's own `useMemo` docs now say there is no benefit to wrapping most calculations. In a project with the compiler enabled, do not hand-write `useMemo`/`useCallback` in new code — use them only as a deliberate escape hatch for referential identity the compiler can't infer.

| Need | Reach for | Not |
|---|---|---|
| Reset a subtree's state when its subject changes | change the `key` | sync it in an effect |
| Keep a hot field from dragging the tree | `useDeferredValue`, `useTransition` | manual debounce state |
| Read a fresh value inside an effect without re-firing it | `useEffectEvent` (19.2) | a ref + stale-closure dance |
| Form submit with pending/error | `useActionState` + Actions | hand-rolled `isSubmitting` |
| Optimistic write | `useOptimistic` | patching the cache by hand |
| Read a promise or context in render | `use()` (stable in 19) | an effect that sets state |
| Subscribe to an external store | `useSyncExternalStore` | `useEffect` + `useState` (tears) |

- **StrictMode double-invokes in development**: every component mounts → unmounts → remounts, so a *correct* effect runs setup, cleanup, setup. If double-firing breaks something, the cleanup is wrong — never "fix" it with a ran-once ref. React 19.2's `<Activity mode="hidden">` performs the same unmount/remount **in production**, which turns that latent bug into a real one.
- **Effects are for synchronising with the outside world.** Deriving state, transforming props, and resetting on prop change all belong in render or in a `key`. React's "You Might Not Need an Effect" is the canonical list.

## Jetpack Compose

- **`collectAsStateWithLifecycle()`, never bare `collectAsState()`** for a `Flow` in a composable. `collectAsState` keeps collecting while the app is backgrounded — the flow keeps polling, the socket stays open, the battery drains. Pair it with `SharingStarted.WhileSubscribed(5_000)` upstream so the producer actually stops.
- **Strong skipping is on by default since Kotlin 2.0.20.** Every restartable composable is skippable regardless of parameter stability, and **lambdas inside composables are automatically remembered**. Hand-wrapping callbacks in `remember` is now noise, and `@Stable`/`@Immutable` annotations are needed far less often than older guidance suggests.
- **`derivedStateOf` is narrow.** Use it *only* when the inputs change more often than the output — scroll offset → `firstVisibleItemIndex > 0`. Google's docs use `derivedStateOf { "$first $last" }` as a labelled "DO NOT USE. Incorrect usage" example. Plain `val` for ordinary derivation; `remember(keys)` when it's genuinely costly.
- **Deferring reads is the real recomposition lever.** Pass `() -> Float` rather than `Float` so the state read happens in the narrowest scope that needs it.
- `flatMapLatest` / `mapLatest` are still `@ExperimentalCoroutinesApi` — add `@OptIn(ExperimentalCoroutinesApi::class)` or a project-wide `compilerOptions.optIn` entry, or the snippet won't compile clean.

## SwiftUI

The Observation framework (`@Observable`) requires **iOS 17 / macOS 14 / Swift 5.9**. On an older deployment target the pre-Observation wrappers are still the correct answer — check the target before emitting `@Observable` into a project that can't build it.

Migration map, when the floor allows it:

| Old | New |
|---|---|
| `@StateObject var vm = VM()` | `@State var vm = VM()` where `VM` is `@Observable` |
| `@ObservedObject var vm` (passed in) | plain `let vm` — or `@Bindable var vm` when you need two-way bindings |
| `@EnvironmentObject var vm` | `@Environment(VM.self) var vm`, injected with `.environment(vm)` |
| `ObservableObject` + `@Published` | `@Observable` macro, plain stored properties |

- `@Observable` invalidates per *property read*, not per object change — that's the performance story, and it's why the migration is worth doing.
- `@State` does not take an autoclosure the way `@StateObject` did, so side effects in an `@Observable`'s initializer can run more than once. Keep initializers pure.

## Flutter

- **`const` constructors are the headline rebuild lever** — they let Flutter short-circuit most of the rebuild work. Use them wherever the widget's inputs are compile-time constant.
- **`setState()` rebuilds every descendant** of the calling `State`. Push it as deep as it will go; this is Rule 3's "resist hoisting" as a hard performance fact rather than a comprehension one.
- **Riverpod 3** (Sept 2025) moved `StateProvider`, `StateNotifierProvider` and `ChangeNotifierProvider` to a `legacy` import path; `Notifier`/`AsyncNotifier` are the standard. `AsyncValue` is now sealed, and there is first-class mutation support. Don't emit a legacy import into a Riverpod 3 project.
- **Bloc** maps onto this skill directly: the `State` class is Rule 2's union, the reducer is Rule 4's single mutation point, and `BlocProvider` is Rule 3's owner.

## Svelte 5

- Runes (`$state`, `$derived`, `$derived.by`, `$effect`) are current; Svelte 4 stores still work but are no longer the default idiom.
- **`$effect` is explicitly an escape hatch.** Svelte's own docs say to avoid using it to synchronise state and that you should *not* update state inside effects — use `$derived` instead. This is the single most common way React habits produce bad Svelte.
- SvelteKit moved `$app/stores` → `$app/state` in 2.12.

## Solid

- `createResource` is the async primitive (not bare "resource").
- Solid 2.0 moves async into `createMemo` returning a promise, with loading boundaries and optimistic signals — check which major version the project is on before writing either idiom.

## Vue

- `watchEffect` cleanup is the **`onCleanup` callback argument**, or `onWatcherCleanup()` from 3.5 — **not** `onUnmounted`, which is a component lifecycle hook and fires at a completely different time.
- `defineModel` is the current two-way-binding idiom for Rule 4's write-through handle.

## TanStack Query (v5)

The defaults are not the ones most apps want, and "it handles staleness for you" hides that:

| Default | Value | Consequence |
|---|---|---|
| `staleTime` | `0` | data is stale immediately; refetches on mount, window focus and reconnect |
| `gcTime` | 5 min | inactive queries are garbage-collected after this |
| `retry` | 3 | with exponential backoff, on every failure |

Set `staleTime` deliberately per query. Use `useMutation` with `onMutate`/`onError` for optimistic writes and rollback, and invalidate the query key after a write rather than patching the cache by hand.
