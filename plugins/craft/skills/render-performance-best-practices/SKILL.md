---
name: render-performance-best-practices
description: "Frame-rate baseline for any frontend: hold 60–240 fps with no jank. Owns the frame budget, zero calculation in build/compose/body/render, collections in build (no per-frame filter/sort/find, no O(n²) row lookups), rebuild/recomposition/re-render scope, lazy and recycled lists (slivers, RecyclerView/DiffUtil, LazyColumn, List/LazyVStack, UICollectionView, FlatList/FlashList, virtual scroll), layout and paint cost, compositor animation, image decode size, main-thread offload, high-refresh opt-in and profiling. Load when a Flutter, Compose, Android Views, SwiftUI, UIKit, React, React Native, Vue, Svelte, Solid or Angular screen janks, stutters, drops frames, hitches, scrolls laggy, freezes on updates or rebuilds too often — or when building a list, feed, table, chart or scroll effect that must stay smooth. Skip page load/LCP and bundle size, API or database speed, startup benchmarks, state bugs, easing design, layout overflow errors, game engines, framework choice, metric dashboards and concept explainers."
---

# Render performance

**The governing law: every frame has a hard deadline, and the build step is not where work happens.** At a given refresh rate the whole frame — input, build, layout, paint, raster, composite — must finish inside one refresh interval, or the display repeats the last frame and the user sees a stutter.

| Refresh | Budget per frame | What fits |
|---|---|---|
| 60 Hz | 16.7 ms | forgiving; a sloppy build step still often fits |
| 90 Hz | 11.1 ms | sloppy build steps start to show |
| 120 Hz | 8.3 ms | ProMotion phones, most flagship Android; build must be near-trivial |
| 144 Hz | 6.9 ms | gaming phones, desktop monitors |
| 240 Hz | 4.2 ms | desktop monitors; steady-state frames must do **no build and no layout at all** |

Most frameworks pipeline the frame across two threads (UI/main thread builds and lays out, a raster/render/GPU thread draws), so **each thread must fit the budget on its own**. And the budget is not yours to spend in full: garbage collection, thermal throttling and the operating system take a slice. Aim for the UI thread using about half the budget on a mid-range device.

The consequence that shapes everything below: **at 120 Hz and above, a smooth scroll or animation is one where most frames only move already-built layers.** Build and layout happen when *data* changes, not when *pixels* move.

Examples use neutral declarative pseudo-code. **Translate every example into the user's framework** with the primitive map below, and read the matching reference file before writing framework code — APIs here churn.

## Skill chaining

| Invoke | When | It owns |
|---|---|---|
| `ui-state-best-practices` | the fix is really about which facts exist, who owns them, or where state is hoisted | state shape and data flow. This skill decides what a redraw *costs*; that one decides what *causes* it |
| `coding-best-practices` | always, on any code you write or change | naming, structure, errors, immutability |
| `perfetto-trace-analysis` / `perfetto-sql` | the user has an Android or Perfetto trace to read | trace querying and interpretation |
| `motion-design` | the question is how an animation should *feel* — timing, easing, choreography | motion design. This skill only makes it run on time |
| `testing-best-practices` | writing a benchmark or frame-timing test | test shape, determinism |

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap.

## Framework primitive map

| Concept | Flutter | Compose | Android Views | SwiftUI | UIKit | React (web) | React Native | Vue / Svelte / Solid / Angular |
|---|---|---|---|---|---|---|---|---|
| Where build-time work goes | ChangeNotifier / Bloc / Riverpod Notifier | ViewModel → `StateFlow<UiState>` | item model built before `submitList` | `@Observable` model | view model / snapshot builder | store, memoized selector, module-scope formatter | store / query `select` | `computed` / `$derived` / `createMemo` / `computed()` signal |
| Id lookup + stable collections | `Map` in state; keep list identity until contents change | map in ViewModel; `ImmutableList` | map in item model; `ListAdapter` | `Set`/`Dictionary`; per-row `@Observable` | identifier-keyed snapshot | `Map`/`Set`; `createSelector` / `useShallow` | `Set`; stable `data` array | `Map`/`Set`; `shallowRef`, `$state.raw` |
| Lazy list | `ListView.builder`, `SliverList.builder` in `CustomScrollView` | `LazyColumn` / `LazyVerticalGrid` | `RecyclerView` + `ListAdapter` | `List`, `LazyVStack` in `ScrollView` | `UICollectionView` + diffable data source | TanStack Virtual, react-window, react-virtuoso | `FlashList`, `FlatList` | `vue-virtual-scroller` / TanStack Virtual / CDK `cdk-virtual-scroll-viewport` |
| Stable row identity | `ValueKey(id)` + `findChildIndexCallback` | `key = { it.id }` + `contentType` | `DiffUtil.ItemCallback`, stable ids | `Identifiable` / `id: \.id` | item identifiers | `key={id}` | `keyExtractor`, `getItemType` | `:key`, `(item.id)`, `<For>`, `track item.id` |
| Narrow the rebuild | `const`, widget split, `select`, `ValueListenableBuilder` | small composables, lambda-deferred reads | `notifyItemChanged` + payloads | small views, `@Observable` | `reconfigureItems` | React Compiler / `memo`, state colocation, selectors | same as React | `computed` / `$derived` / `createMemo` / signals + `OnPush` |
| Move pixels without rebuild | `Transform`/`FadeTransition`, `CustomPaint(repaint:)` | `Modifier.graphicsLayer { }`, `offset { }`, `drawBehind` | `ViewPropertyAnimator` | `.visualEffect`, `.scrollTransition` | Core Animation | CSS `transform`/`opacity`, WAAPI | Reanimated worklets, native driver | CSS `transform`/`opacity` |
| Isolate repaint | `RepaintBoundary` | `graphicsLayer` | hardware layer during animation | `.drawingGroup()` (rarely) | `shouldRasterize` (rarely) | `contain`, `will-change` (sparingly) | — | same as web |
| Off the main thread | `Isolate.run` / `compute` | `Dispatchers.Default` | `Dispatchers.Default` / executors | non-main-actor `async` / `@concurrent` | GCD / actors | Web Worker, `scheduler.yield()` | worklet / native module / worker | Web Worker |
| Decode at display size | `cacheWidth` / `ResizeImage` | Coil `AsyncImage` | Glide / Coil target size | ImageIO thumbnail, `byPreparingThumbnail` | same + `prepareForDisplay` | `srcset` + `sizes`, `decoding="async"` | `expo-image`, sized source | `srcset` + `sizes` |
| Unlock high refresh | `CADisableMinimumFrameDurationOnPhone`; `flutter_displaymode` | `Modifier.preferredFrameRate` | `View.setRequestedFrameRate`, `Surface.setFrameRate` | `CADisableMinimumFrameDurationOnPhone` | same + `CADisplayLink.preferredFrameRateRange` | automatic (rAF follows monitor) | `CADisableMinimumFrameDurationOnPhone` | automatic |
| Profiler | DevTools Performance (profile mode) | Layout Inspector counts, Perfetto, Macrobenchmark | `gfxinfo`, Perfetto, JankStats | Instruments SwiftUI + Hitches | Instruments Animation Hitches | DevTools Performance, React Profiler, LoAF | Perf Monitor, RN DevTools, Flashlight | DevTools Performance, framework devtools |

References — read the one for the stack in play before writing code. Every reference file uses the **same section numbers as the rules below** (section 5 is always lists, section 13 always high refresh), and each section covers every toolkit in that file:
- `references/flutter.md` · `references/android.md` (Compose + Views) · `references/apple.md` (SwiftUI + UIKit) · `references/web.md` (React, Vue, Svelte, Solid, Angular, DOM/CSS) · `references/react-native.md`

If you are unsure whether an API exists in the user's version, say so and check — a confidently wrong API is worse than an admitted gap.

## How to operate

### Reviewing code
1. Find the **hot paths** first: the build/render function of anything inside a scrolling list, anything driven by an animation, scroll offset, timer, stream or keystroke, and any per-row function (item builder, `onBindViewHolder`, `cellForItemAt`, `renderItem`).
2. For each hot path ask three questions: *what runs per frame, how much does it cost as the data grows, and how much of the tree does it drag along?*
3. Rank issues by frames lost at realistic data size: O(n) or O(n²) work per frame > whole-screen rebuild per tick > non-lazy list > offscreen layers > micro-allocation.
4. For each issue: quote the user's real line (Bad), show the fix in their framework (Good), and say what it costs in plain numbers ("2,000 rows × a linear search = 4 million comparisons every scroll frame").
5. Cap at 5–7 issues unless asked for an exhaustive pass.

### Building a new screen
State the target refresh rate and data size, then shape the code so that data changes do the work and frames only draw: precompute a render-ready model when data arrives, pick the lazy container, give rows stable identity, route every per-frame value to the smallest leaf.

### Diagnosing reported jank
Do not guess from code alone when a measurement is cheap. Ask for, or give the exact steps to get, one trace in a **release or profile build on a real device** — then read which thread misses the budget. UI/main thread over (Apple calls this a commit hitch) → build, layout, or main-thread work. Raster/GPU/render-server thread over (a render hitch) → paint cost: offscreen layers, blurs, masks, huge images, shaders. Both fine but still stutters → frame pacing, garbage-collection pauses, or the app is capped at 60 Hz. Rebuild and recomposition counters often need a debug build while frame times need release/profile — take two separate measurements rather than reading frame times with counters switched on.

### Output format

```
### [Plain-language problem name]

[One sentence: what runs, how often, and what it costs.]

**Bad:**
[their code]

**Good:**
[the fix, in their framework]

[Why it is faster — 1–2 sentences, with numbers where possible.]
```

Finish with **how to verify**: the one measurement that shows the fix worked (frame time p90/p99, rebuild or recomposition count, jank percentage, hitch ratio) and the target for their refresh rate.

### Voice
- Speak like an engineer, not a rulebook. Never cite rule numbers; say what runs and what it costs.
- Never fabricate the user's code. If you infer code you have not seen, say so.
- Lead with the framework's blessed tool (slivers, `ListAdapter`, `LazyColumn` keys, `@Observable`, FlashList, TanStack Virtual) before a hand-rolled fix.
- Memoization is a last resort, not the first fix. The usual fix for work in build is **moving it to where the data changes**, not caching it inside build.
- **A performance fix must not change what the user sees or can do.** Keep the same visuals, effects, text, layout at large font sizes, and loading behaviour; if a fix truly has to change something (a clamped effect, truncated text, a header that no longer reappears), say so in one line. A faster screen that looks broken is a regression.
- **Bugs you uncover get fixed and named, not preserved.** "Don't change behaviour" protects what the user sees on purpose; it doesn't mean keeping a crash on missing data. Fix it and say so in one line.
- **Say when you change an API** the rest of the app touches — a renamed state property, a type that became main-actor-bound, a property made read-only, an initializer that changed.
- **Code you hand over must compile as written.** Include the required pieces (`required init?(coder:)` for UIKit cells, concurrency annotations under strict Swift 6 checks, imports). If a snippet is deliberately partial, label it partial.
- **Don't swap one hard-coded number for another.** Size image decodes from the real on-screen frame times the screen scale, not a fixed 1,600 px; clamp scroll-driven offsets so no empty strip appears.

---

## The rules

### 1. Measure in release, on a real device, before and after

Debug builds lie. Flutter debug runs a just-in-time compiler with assertions; Compose debug builds skip R8 and baseline profiles; React development mode double-renders and checks everything; React Native dev mode runs a slower JavaScript path. A screen that stutters in debug may be fine in release, and one that looks fine on a flagship may miss 120 Hz on a mid-range phone.

Name the target (60, 120, 240) and the device, measure frame times, fix, measure again. Report p90 and p99 frame time, not the average — one 50 ms frame per second is invisible in an average and obvious to a thumb.

### 2. Zero calculation in build

The build function (`build`, a composable body, SwiftUI `body`, a React component, a template) can run every frame during scrolls, animations and keystrokes. It must be a **cheap projection of ready data**: read fields, pick branches, place children.

Calculation means anything whose cost grows with the data or allocates heavy objects: sorting, filtering, grouping, searching, summing, parsing JSON or dates, compiling a regular expression, creating a date or number formatter, reading storage, building maps.

**Bad:**
```
function OrdersScreen({ orders }) {
  const fmt = new DateFormatter("dd MMM, HH:mm")               // heavy object, every build
  const rows = orders
    .filter(o => o.status !== "archived")
    .sort((a, b) => b.createdAt - a.createdAt)                  // O(n log n), every build
  const total = rows.reduce((s, o) => s + o.amount, 0)          // O(n), every build
  return <List>{rows.map(o => <Row label={fmt.format(o.createdAt)} … />)}</List>
}
```

**Good:** compute once, when the data changes, and hand build a render-ready model.
```
// state layer — runs when orders arrive or change, not per frame
const DATE_FMT = new DateFormatter("dd MMM, HH:mm")             // created once
function toViewModel(orders) {
  const rows = orders.filter(o => o.status !== "archived")
                     .sort((a, b) => b.createdAt - a.createdAt)
                     .map(o => ({ id: o.id, label: DATE_FMT.format(o.createdAt), amount: o.amountText }))
  return { rows, totalText: formatMoney(sum(rows)) }
}

function OrdersScreen({ vm }) {                                   // build only reads
  return <LazyList items={vm.rows} key={r => r.id} render={r => <Row row={r} />} />
}
```

**Recompute each derived list only from the inputs it depends on.** If the sorted, formatted rows come from `messages`, a change to `selectedId`, a scroll position or a text field must not re-run that sort and format for all 3,000 rows. Derive the heavy list from its own source (a separate flow/selector/memo keyed on the data), and combine the cheap, fast-changing facts (selection, expanded ids) at the row, as a boolean.

This is **compute-on-write, not compute-on-read**: data changes a few times a minute, frames happen 120 times a second. Where the framework offers a built-in derived value that recomputes only when inputs change (`computed`, `$derived`, `createMemo`, `remember(keys)`, React Compiler), that is acceptable for *moderate* work local to one screen. For large lists, prefer the state layer — a memo inside build still runs the whole job on every data change, on the UI thread.

Cheap things stay in build and need no ceremony: string interpolation of prepared values, a ternary, reading a field.

### 3. Collections in build: no copies, no scans, no quadratic lookups

Lists are where build cost explodes, because the per-row function runs once per visible row per frame.

- **Never search a list inside a row builder.** `users.find(u => u.id == msg.authorId)` inside `renderItem` is O(n) per row → O(n²) per frame. Build an `id → item` map once in the state layer.
- **Never build a derived list in build just to show part of it.** `items.where(...).toList()` then `ListView.builder` allocates and scans every item each frame, though only ten are visible.
- **Hand the lazy container the indexable collection**, and let the builder index into it. `ListView(children: items.map(Row).toList())` builds every row up front; `ListView.builder(itemCount:, itemBuilder: (_, i) => Row(items[i]))` builds only the visible ones.
- **Keep collection identity stable when nothing changed.** Skipping and diffing (Compose skipping, `React.memo`, `Selector`, `DiffUtil`, `@Observable`) compare by identity or equality. A fresh list instance every build — `.toList()`, `[...spread]`, `filter`, `listOf(...)` — looks "changed" every time and turns skipping off for the whole subtree. Rebuild the list only when its contents change.
- **Precompute per-row display strings and flags** (formatted price, "is selected", initials, relative time bucket) into the row model. Pass the row a boolean `isSelected`, not the whole `selectedId`, so selecting one row updates two rows, not all of them.
- **Use the right structure for the question**: a set for "is this selected", a map for lookup by id, a pre-grouped structure for section headers.

### 4. Rebuild the smallest thing that changed

A state change rebuilds its reader and, in most frameworks, everything beneath it. Hot values — scroll offset, animation progress, a ticking clock, a text field, a stream of prices, drag position — must reach **only the leaf that shows them**.

**Bad:**
```
function Screen() {
  const [scrollY, setScrollY] = useState(0)                   // every scroll frame…
  return <Page onScroll={e => setScrollY(e.y)}>               // …rebuilds the whole page
           <Header shadow={scrollY > 0} />
           <Feed items={items} />
         </Page>
}
```

**Good:**
```
function Screen() {
  const scroll = useScrollPosition()                          // observable handle, not a value
  return <Page scroll={scroll}>
           <Header shadowVisible={derived(() => scroll.y > 0)} />   // updates only when the boolean flips
           <Feed items={items} />                              // never rebuilt by scrolling
         </Page>
}
```

Levers by framework: split big build functions into separate components/widgets (in Flutter, a helper *method* rebuilds with its parent; a separate `const` widget class can be skipped), mark static subtrees `const`, subscribe through selectors with equality, pass a stable `child` into animation builders, defer reads in Compose with lambdas (`() -> Float`), use `@Observable` in SwiftUI, and derive a *boolean* from a fast-changing number so readers update only when the boolean flips.

### 5. Long or unknown-length content goes in a lazy, recycled list

A non-lazy column of 500 rows builds, lays out and keeps 500 rows in memory before the first frame. A lazy list builds what is on screen plus a small margin, and recycling reuses row objects instead of allocating new ones.

- **Lazy by default** for anything that can exceed about two screens or comes from the server.
- **Tell the list the row size when you know it** (`itemExtent`, `prototypeItem`, `getItemLayout`, `setHasFixedSize`, fixed `itemSize`). Unknown sizes force measuring; known sizes make jumps and fast flings cheap.
- **Stable keys, and a content type for mixed rows**, so the list reuses the right recycled row and keeps row state attached to the right item.
- **One scroll container per axis.** A lazy list inside a non-lazy scroll view — `shrinkWrap: true`, a `ListView` in a `Column` inside a `SingleChildScrollView`, a `FlatList` inside a `ScrollView`, a `LazyVStack` inside a `VStack` in a `List` — silently builds every row. For headers, carousels and mixed sections, use one sliver/section-based container (`CustomScrollView` + slivers, `LazyColumn` with `item {}` blocks, `ConcatAdapter`, compositional layout, `SectionList`).
- **Diff, don't reset.** `ListAdapter`/`DiffUtil`, diffable data sources, keyed lists. `notifyDataSetChanged` or `reloadData` rebinds everything and kills animations.
- **Nested horizontal lists** share a recycled-view pool and prefetch a few items.
- **Recycled rows must not hold item state in local fields** — reset it from the item on bind (FlashList and RecyclerView both bite here).
- **Paginate** anything unbounded. Virtualization keeps frames cheap; it does not make a 100,000-item array free to diff.

### 6. Layout once, and never read it back mid-frame

- **Avoid multi-pass measurement in rows**: Flutter `IntrinsicHeight`/`IntrinsicWidth`, nested weighted `LinearLayout` and `RelativeLayout` in Views, SwiftUI `GeometryReader` in every row, Compose `SubcomposeLayout`/`BoxWithConstraints` in list rows, Auto Layout constraint churn in UIKit cells. Each adds layout work per row, and nested they multiply.
- **Flatten deep hierarchies** in rows (`ConstraintLayout`, fewer wrapper widgets).
- **Web: batch reads before writes.** Reading `offsetHeight` or `getBoundingClientRect()` after writing a style forces a synchronous layout — in a loop, that is layout thrashing. Use `ResizeObserver` and `IntersectionObserver` instead of measuring in scroll handlers.
- **Never animate layout properties** (width, height, top, left, margin, padding, flex) at high refresh. Animate a transform of a fixed-size box instead.

### 7. Paint cheaply; offscreen layers are the expensive kind

The raster/GPU thread chokes on work that needs an offscreen buffer: group opacity on a subtree, clip with anti-aliasing through a save-layer, shader masks, backdrop blur, color filters on large areas, shadows without a precomputed path.

- Fade an image with its own alpha or a fade transition, not an opacity wrapper around a whole subtree.
- Prefer rounded decoration or shape clipping over a generic clip wrapper; set shadow paths explicitly on iOS.
- Blur once into an image rather than live-blurring a scrolling area.
- **Isolate what repaints often** (spinner, progress ring, live chart, video, cursor) behind its own layer — `RepaintBoundary`, `graphicsLayer`, CSS containment — so it doesn't repaint its neighbours. Don't blanket the tree with layers: each one costs GPU memory and composite time.
- Custom painters: repaint only when inputs change (`shouldRepaint`, `repaint:` listenable, `invalidate()` on the changed region) and allocate paints, paths and shaders once, not per draw.
- Watch overdraw: an opaque full-screen background on the window *and* the page *and* the card is three paints of the same pixel.

### 8. Animate on the compositor, by time, not by rebuild

- Animate **transform and opacity** (and Compose `graphicsLayer`, Core Animation layers, Reanimated shared values). These skip build and layout and often run off the main thread — the only animations that hold 240 Hz reliably.
- **Never drive an animation with `setState` on a big widget or component.** Route the animation value to the smallest leaf, or better, straight to the layer.
- **Use elapsed time, never frame counts.** `x += 2` per frame runs twice as fast at 120 Hz and four times as fast at 240 Hz. Every platform frame callback hands you a timestamp — use the delta.
- Scroll-driven effects (parallax, collapsing header, fade on scroll) use the platform's scroll-linked tools (`.scrollTransition`/`.visualEffect`, CSS scroll-driven animations, Reanimated `useAnimatedScrollHandler`, Compose `graphicsLayer` reading scroll state in the lambda, Flutter `SliverAppBar`/`SliverPersistentHeader`) instead of writing scroll offset into state.

### 9. Decode images at the size they are shown

A 4000×3000 photo in a 100×100 thumbnail decodes 12 million pixels (about 48 MB) to show 10,000 on a 1x screen, blocks the raster or main thread, and pushes memory into garbage collection. Decode to the display size times the device pixel ratio (Flutter `cacheWidth`, Coil/Glide target size, ImageIO thumbnails, `srcset`/`sizes`), decode asynchronously with a few decodes in parallel (not one serial queue, which lags a fast fling), cancel the decode when the row is recycled, cache decoded images, and reserve the space with a placeholder of known size so layout doesn't shift when the image lands.

### 10. The main thread is for frames; everything else leaves

Anything that can take more than about a millisecond runs off the UI thread — including building the row view models (formatting 1,500 rows' dates and prices) when data arrives, on every platform, not just the one you started with: JSON parsing of large payloads, sorting or grouping big lists, search indexing, diffing huge lists, image processing, cryptography, database reads. Use the platform's worker (Dart isolates, Kotlin `Dispatchers.Default`, Swift non-main-actor tasks, Web Workers, React Native worklets or native modules). On the web, when work must stay on the main thread, split it into chunks and yield between them so input and frames get through.

Also keep synchronous disk and network off the main thread entirely (Android `StrictMode` catches it).

### 11. No allocation in hot paths

Per-frame and per-row functions — draw/paint, `onBindViewHolder`, `cellForItemAt`, item builders, scroll listeners, animation ticks — should not allocate paints, paths, formatters, closures over large captures, or temporary lists. Each allocation is small, but at 120 frames × 20 rows it becomes garbage-collection pauses that land as random dropped frames. Hoist to fields, constants or one-time setup.

### 12. Kill first-frame and first-use jank

The first time a shader, a code path or a screen runs, it can take far longer than the steady state. Use the platform's warm-up: Flutter's Impeller renderer (precompiled shaders), Android baseline profiles, precaching images for the next screen, code-splitting on the web so the route chunk loads before the transition, not during it.

### 13. Make sure the app is actually allowed to run fast

A perfectly optimized app still shows 60 fps if the platform caps it.
- **iPhone ProMotion**: frame-rate requests above 60 Hz from `CADisplayLink`, Core Animation and cross-platform engines (Flutter, React Native) are ignored unless `CADisableMinimumFrameDurationOnPhone = YES` is in `Info.plist` (new Flutter, React Native and Expo projects include it; old and add-to-app projects often don't). iPad Pro needs no key. Ask for the lowest rate that looks right — 120 Hz only for high-impact motion.
- **Android**: on adaptive-refresh devices (Android 15 QPR1+), Views default to the "Normal" category, typically about 60 Hz; touch and fling boost it temporarily. Request more for motion with `View.setRequestedFrameRate` (API 35), `Modifier.preferredFrameRate` (Compose UI 1.9+) or `Surface.setFrameRate` (API 30); check capability APIs' levels before calling them.
- **Web and desktop**: `requestAnimationFrame` follows the monitor, so 144 and 240 Hz happen automatically — which is why hard-coded 16 ms timers and frame-count animations break there.
- **Battery**: high refresh drains power. Request it for motion (scroll, animation, drag), and let the system drop the rate when the screen is still.

Details and exact API names per platform are in the reference files.

---

## One card

| # | Rule | One line |
|---|---|---|
| 1 | Measure | Release build, real mid-range device, p90/p99 frame time, before and after. |
| 2 | Zero calculation in build | Compute when data changes; build only reads a ready model. |
| 3 | Collections | No scans, copies or searches per row; maps for lookup; stable identity. |
| 4 | Narrow rebuilds | Hot values reach only the leaf that shows them. |
| 5 | Lazy lists | Virtualize, give sizes, key rows, one scroll container, diff don't reset. |
| 6 | Layout once | No multi-pass rows, no read-after-write, no animated layout properties. |
| 7 | Cheap paint | Avoid offscreen layers; isolate frequent repaints; allocate paints once. |
| 8 | Compositor animation | Transform/opacity, time-based, never setState per frame. |
| 9 | Image size | Decode at display size, asynchronously, cached, with reserved space. |
| 10 | Main thread | Anything over about 1 ms moves to a worker or gets chunked. |
| 11 | No hot allocation | Nothing allocated per frame or per row. |
| 12 | Warm up | Precompile shaders, baseline profiles, precache the next screen. |
| 13 | Unlock the rate | Opt in to ProMotion / Android high refresh; never assume 16 ms. |

If you remember one thing: **data changes do the work, frames only draw.** At 60 Hz you can get away with breaking that; at 120 Hz you can't; at 240 Hz the only frames that make it are the ones that move layers someone already built.
