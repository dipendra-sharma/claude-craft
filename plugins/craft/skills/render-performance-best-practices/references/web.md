# Web — DOM/CSS, React, Vue, Svelte, Solid, Angular

**Currency stamp: 2026-09-26.** Sections follow the rule numbers in `SKILL.md`. Check `package.json` and the lockfile for installed versions, and browser support for newer platform APIs, before relying on them.

## The browser frame

JavaScript → style → layout → paint → composite. Changing `transform` or `opacity` of an element on its own layer skips layout and paint and runs on the compositor thread — the only animation path that holds 144–240 Hz reliably. `requestAnimationFrame` fires at the monitor's rate: 4.2 ms per frame at 240 Hz. At 60 Hz the browser needs about 6 ms of each frame for itself, leaving roughly 10 ms for script.

## 1. Measure

- **DOM** — Chrome DevTools → Performance with CPU throttling (4x–6x) to mimic a mid-range phone. The Frames track shows dropped and partially presented frames; long tasks are marked. Rendering drawer: Frame Rendering Stats, Paint flashing, Layout Shift Regions, Scrolling performance issues.
- **DOM** — field data: Long Animation Frames (`PerformanceObserver` with `type: "long-animation-frame"`, Chrome 123+) attributes slow frames to scripts. Interaction to Next Paint (INP) is "good" at 200 ms or less at the 75th percentile. The `web-vitals` library reports INP (`onINP`); `onFID` was removed in v5.
- **React** — React DevTools Profiler (why each component rendered; "Highlight updates when components render"). `<Profiler id onRender>` reports `actualDuration` (this render) vs `baseDuration` (the whole subtree without memoization); it is disabled in production unless you ship React's profiling build.
- **React** — time a calculation with `console.time` before memoizing; React's guidance is that about 1 ms or more is worth it.
- **Vue / Angular** — Vue DevTools performance tab; Angular DevTools profiler (change-detection cycles per event).

## 2. Zero calculation in build

- **React** — component bodies re-run on every render. Sorting, filtering, grouping and formatter construction (`new Intl.NumberFormat(...)`, `new Intl.DateTimeFormat(...)`, `new RegExp(...)`) belong in the data layer when data arrives, or at module scope for formatters. `useMemo` for moderate derived work local to a component.
- **Vue** — `computed` for derived data (cached until dependencies change); never call a filtering or formatting method from the template.
- **Svelte 5** — `$derived` for derived values; `$effect` only for the outside world.
- **Solid** — components run once; `createMemo` for derived values read in several places.
- **Angular** — never call methods in templates for derived values (they run on every change-detection pass); use `computed()` signals or pure pipes.

## 3. Collections in build

- **All** — no `Object.values(map).sort(...)` or `.filter(...)` per render for large data; keep a pre-sorted, pre-filtered array in the store, updated when data changes. Lookups by id through a `Map`, membership through a `Set`.
- **React** — store selectors that return a new array or object each call (`useSelector(s => s.items.filter(…))`) re-render on every dispatch; select raw data and derive with a memoized selector (`createSelector`). Zustand v5: select narrow slices; `useShallow` for multi-field picks (the old equality-function argument was removed).
- **Vue** — pass each row a computed boolean (`:active="item.id === activeId"`) rather than `activeId` itself, so a selection change updates two rows instead of all. `shallowRef` / `shallowReactive` for large data replaced wholesale; `markRaw` for third-party instances.
- **Svelte 5** — `$state.raw` for large arrays or objects replaced rather than mutated (no deep proxy on every item).

## 4. Rebuild scope

- **React** — a render re-renders the whole subtree unless a child bails out. **React Compiler** 1.0 (a build plugin, React 17+) memoizes components and values automatically: rely on it for new code, keep existing `useMemo`/`useCallback` (removing them can change compiled output), and use them where you need exact control such as effect dependencies.
- **React** — without the compiler: `memo` on expensive children with referentially stable props (no inline objects/functions to memoized children). A custom `memo` comparison must check every prop, including functions, and never deep-walk.
- **React** — **never define a component inside another component's body**: it is a new type every render, so React unmounts and remounts the subtree.
- **React** — colocate fast-changing state (input text, hover, drag position) in the smallest component. Let a stateful wrapper take static content as `children` so its own state changes don't re-render that content.
- **React** — context: every consumer re-renders when the value changes, and `memo` does not block it. Split state and dispatch into separate contexts, split by change frequency, or use a store with selectors. React 19 renders `<Context value={…}>` directly.
- **React** — `useDeferredValue(query)` keeps typing responsive only if the child receiving the deferred value is wrapped in `memo`. With `startTransition`, the callback itself runs synchronously — put expensive work in the render of the deferred child, and never use a transition for the state that controls a text input.
- **React** — high-frequency values (stream ticks, scroll, pointer) that only change visuals should skip React rendering: write to a ref's `style` or a CSS variable inside `requestAnimationFrame`, and batch store updates to at most once per frame.
- **Vue** — `v-memo="[item.selected]"` on the same element as `v-for` for very large lists (Vue suggests it for lists over about 1,000 rows); `v-once` for static content.
- **Solid** — don't destructure props (reads once, breaks reactivity).
- **Angular** — OnPush is the default for components that don't set `changeDetection` from v22 (`Default` is renamed `Eager`); on older versions set `ChangeDetectionStrategy.OnPush` explicitly. Zoneless change detection (`provideZonelessChangeDetection()`, stable in v20.2, default from v21) removes app-wide checks after every async event. In zone-based apps run high-frequency listeners inside `NgZone.runOutsideAngular`.

## 5. Lists

- **React** — virtualize: TanStack Virtual (`useVirtualizer`), react-window, or react-virtuoso (variable heights, chat). Keys are stable ids — never the array index for lists that change, never `Math.random()`.
- **Vue** — keyed `v-for` (`:key="item.id"`); `vue-virtual-scroller` or `@tanstack/vue-virtual`.
- **Svelte 5** — keyed each blocks `{#each items as item (item.id)}`; TanStack Virtual for Svelte.
- **Solid** — `<For each={items}>` keys by reference (objects); `<Index each={items}>` keys by position (primitives, fixed-length lists).
- **Angular** — `@for (item of items; track item.id)` (`track` is required; track by id, not `$index`, for lists that change). `cdk-virtual-scroll-viewport` with `itemSize` + `*cdkVirtualFor`. `@defer` for heavy below-the-fold blocks.
- **DOM** — `content-visibility: auto` with `contain-intrinsic-size: auto 500px` skips rendering off-screen sections of long pages (Baseline since 2024); `auto` makes the browser remember the real size.

## 6. Layout

- **DOM** — batch reads, then writes. Reading `offsetWidth`, `offsetHeight`, `getBoundingClientRect()`, `scrollTop` or `getComputedStyle()` after a style write forces synchronous layout; in a loop over rows, that is layout thrashing.
- **DOM** — `ResizeObserver` for size changes and `IntersectionObserver` for visibility, instead of measuring in `scroll` handlers.
- **DOM** — `contain: content` isolates a widget so its changes don't relayout or repaint the page. `contain: strict` adds size containment, so the element needs an explicit size or it collapses to zero.

## 7. Paint

- **DOM** — `will-change: transform` promotes an element to its own layer. Set it from script just before an animation and back to `auto` after; never leave it on permanently for many elements (each layer costs GPU memory).
- **DOM** — large `filter: blur()` and `backdrop-filter` are expensive every frame they are visible over changing content. Animating `box-shadow`, `background` or `color` repaints every frame; for a shadow effect, fade the opacity of a pseudo-element that holds the shadow; for a flash, fade an overlay's opacity.
- **React** — `className` for static styles, `style` for runtime values.

## 8. Animation

- **DOM** — animate `transform` and `opacity` only (the web.dev animations guide recommends these two). Animating `top`, `left`, `width`, `height`, `margin` triggers layout each frame.
- **DOM** — scroll-driven effects: CSS scroll-driven animations (`animation-timeline: scroll()` / `view()`, Chrome 115+, Safari 26; not yet in stable Firefox) run on the compositor; otherwise update a transform inside `requestAnimationFrame`, never in a `scroll` handler that reads layout.
- **DOM** — use the rAF timestamp delta; never `setInterval(fn, 16)`. Web Animations API (`element.animate`) for script-driven compositor animations.
- **DOM** — `passive: true` matters on `touchstart`/`touchmove`/`wheel` listeners on non-document targets (document-level ones are passive by default); it has no effect on `scroll`, which cannot be cancelled.

## 9. Images

- **DOM** — `width`/`height` attributes (or `aspect-ratio`) reserve space; `srcset` + `sizes` download the right size; `loading="lazy"` below the fold; `decoding="async"`; `await img.decode()` before inserting an image that must appear without a hitch.

## 10. Off the main thread

- **DOM** — Web Workers (optionally with Comlink) for parsing, sorting, searching and diffing large data. For heavy canvas drawing, call `canvas.transferControlToOffscreen()` **once** (before any `getContext`) and draw in a worker; send new data with `postMessage` — transferring twice throws `InvalidStateError`, which a re-running effect will do.
- **DOM** — chunk long main-thread work and yield: `await scheduler.yield()` (Chrome/Edge 129, Firefox 142; not Safari) with a fallback of `await new Promise(r => setTimeout(r, 0))`.
- **DOM** — respond visibly to input within 100 ms and finish handling it within about 50 ms.

## 11. Hot-path allocation

- **React / all** — no new formatters, regexes, large closures or temporary arrays inside row renderers, rAF callbacks or pointer/scroll handlers. Module-scope constants and reused buffers.

## 12. First-frame jank

- **All** — code-split routes and preload the next route's chunk before the transition, not during it. Preload the hero image of the next screen.

## 13. High refresh rate

- **DOM** — nothing to opt in to: `requestAnimationFrame` and CSS animations follow the monitor (60–240 Hz). What breaks at high rates is code that assumes 16 ms: frame-count animation, `setInterval(…, 16)`, throttles tuned to 60 Hz, and per-frame work that fit 16.7 ms but not 4.2 ms.
