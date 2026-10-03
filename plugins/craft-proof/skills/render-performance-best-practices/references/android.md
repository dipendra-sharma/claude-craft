# Android — Jetpack Compose and Views

**Currency stamp: 2026-09-26.** Sections follow the rule numbers in `SKILL.md`. Check the project's Compose BOM, Kotlin, AGP and `compileSdk` (version catalog / lockfile) before relying on a version-specific claim — Compose performance defaults change between releases.

## 1. Measure

- **Both** — measure a release-like build: R8 on (`proguard-android-optimize.txt`), non-debuggable, with a baseline profile. Debuggable builds run Compose far slower.
- **Both** — Macrobenchmark `FrameTimingMetric`: `frameDurationCpuMs` (all API levels) and `frameOverrunMs` (API 31+; negative means time to spare). Judge p95 and p99, not the median.
- **Both** — `JankStats` (`androidx.metrics:metrics-performance`) reports janky frames in production, annotated with UI state through `PerformanceMetricsState`.
- **Both** — Perfetto / system trace shows the main thread and `RenderThread` per frame (`perfetto-trace-analysis` skill reads traces). `adb shell dumpsys gfxinfo <package> framestats` for a quick look.
- **Views** — `Window.addOnFrameMetricsAvailableListener`: compare `FrameMetrics.TOTAL_DURATION` with `FrameMetrics.DEADLINE` (API 31), never with a hard-coded 16 ms.
- **Compose** — Layout Inspector shows recomposition and skip counts per composable. Add `androidx.compose.runtime:runtime-tracing` to see composable names in system traces (API 30+). In Macrobenchmark, add `tracing-perfetto` + `tracing-perfetto-binary`, set `androidx.benchmark.fullTracing.enable=true`, and assert with `TraceSectionMetric("%Name%")`.
- **Compose** — compiler reports: `composeCompiler { reportsDestination = …; metricsDestination = … }` list restartable/skippable composables and unstable parameters.
- **Views** — Developer options → "Profile HWUI rendering" bars (eight coloured segments on Android 6.0+) and "Debug GPU overdraw".

## 2. Zero calculation in build

- **Compose** — a composable body re-runs on every recomposition. Sorting, filtering, grouping, `SimpleDateFormat`/`DateTimeFormatter` creation and string formatting belong in the ViewModel, producing a render-ready `UiState` exposed as `StateFlow` and collected with `collectAsStateWithLifecycle()`.
- **Compose** — formatters as top-level `val`s. `java.time.format.DateTimeFormatter` is immutable and thread-safe but needs API 26 or core library desugaring; `SimpleDateFormat` and `NumberFormat` are not thread-safe — never share one instance across background threads (use `java.time`, or one instance per thread). `remember(key) { expensive(key) }` only for genuinely expensive work local to the screen.
- **Views** — `onBindViewHolder`, `onDraw`, `onMeasure` and listeners must only assign precomputed values. Precompute display strings (price, date, initials) in the item model when data arrives.

## 3. Collections in build

- **Compose** — `state.users.first { it.id == msg.senderId }` inside `items {}` is a linear scan per row; build `usersById: Map<Id, User>` in the ViewModel.
- **Compose** — strong skipping (default since Kotlin 2.0.20) compares **unstable parameters by instance (`===`) and stable ones by `equals`**. `items.filter { … }`, `sortedBy`, `listOf(...)` or `map` inside a composable creates a new instance every recomposition, so the child never skips. Produce lists in the ViewModel; use `kotlinx.collections.immutable` (`ImmutableList`, `persistentListOf`) or a stability configuration file (`composeCompiler { stabilityConfigurationFiles.add(...) }`) for external types.
- **Compose** — pass each row `isSelected: Boolean`, not the screen's `selectedId`, so a selection change recomposes two rows instead of all.
- **Views** — `customers.first { … }` in `onBindViewHolder` is O(n) per bind; use a map. Never rebuild the adapter's list on every poll when nothing changed.

## 4. Rebuild scope

- **Compose** — three phases: composition → layout → drawing. Read fast-changing state in the latest phase that needs it:

| Per-frame value | Bad (recomposes every frame) | Good |
|---|---|---|
| Offset | `Modifier.offset(x = anim.value.dp)` | `Modifier.offset { IntOffset(anim.value.roundToInt(), 0) }` |
| Alpha, scale, translation, rotation | `Modifier.alpha(a)` with `a` read in composition | `Modifier.graphicsLayer { alpha = a(); translationY = y() }` |
| Animated color | `Modifier.background(color)` | `Modifier.drawBehind { drawRect(color()) }` |
| Passing a hot value down | `Header(scrollOffset: Int)` | `Header(scrollOffset: () -> Int)`, read inside the leaf's lambda |

- **Compose** — `derivedStateOf` only when inputs change more often than the output: `val showFab by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }`.
- **Compose** — never write state after reading it in the same composition (backwards write); it schedules another recomposition every frame.
- **Compose** — `mutableIntStateOf` / `mutableFloatStateOf` / `mutableLongStateOf` / `mutableDoubleStateOf` avoid boxing; enable the `AutoboxingStateCreation` lint.
- **Compose** — write custom modifiers with `Modifier.Node`, not `composed {}`; hoist modifier chains that don't depend on composition out of the composable.
- **Compose** — lambdas, including those inside `LazyListScope.items { }` content, are memoized automatically under strong skipping; hand-wrapping them in `remember` is noise.
- **Views** — `notifyItemChanged(position, payload)` + `onBindViewHolder(holder, position, payloads)` updates one view (a counter, a checkbox) instead of rebinding the row.

## 5. Lists

- **Compose** — `LazyColumn { items(items, key = { it.id }, contentType = { it.type }) { Row(it) } }`. `key` keeps state and scroll position with the item; `contentType` reuses compositions between rows of the same type.
- **Compose** — headers and mixed sections go in one `LazyColumn` (`item {}`, `stickyHeader {}`, several `items(...)` blocks). Never a `LazyColumn` inside `Column(Modifier.verticalScroll(...))`.
- **Compose** — avoid zero-size items (an image with no placeholder size); the list composes too many on the first frame.
- **Compose** — lazy lists prefetch upcoming items, and recent Compose versions can pause and resume prefetch work across frames. The default for pausable prefetch composition and the cache-window API (`LazyLayoutCacheWindow`, 1.9+) have changed across 1.10–1.13 — check the release notes for the BOM in use before tuning.
- **Compose** — prefetch runs an item's `LaunchedEffect` / `DisposableEffect` before the item is on screen. Don't use them as "item is visible"; use `Modifier.onVisibilityChanged`.
- **Compose** — `Modifier.animateItem()` for insert/remove/reorder animation.
- **Views** — `ListAdapter` + `DiffUtil.ItemCallback` (`areItemsTheSame` by id, `areContentsTheSame` by data): the diff runs on a background thread and only changed rows rebind. Never `notifyDataSetChanged()` for incremental changes.
- **Views** — `setHasFixedSize(true)` when adapter changes don't change the RecyclerView's own size. `ConcatAdapter` combines header, sections and footer in one RecyclerView.
- **Views** — nested horizontal lists: share one `RecyclerView.RecycledViewPool` across inner RecyclerViews, set `(layoutManager as LinearLayoutManager).initialPrefetchItemCount` to the number visible at once, and reuse the inner adapter (`submitList`) instead of creating one per bind.

## 6. Layout

- **Compose** — Compose measures each child once per pass; intrinsic queries do not measure children twice. The costs to watch are deep nesting of custom layouts and `SubcomposeLayout` (including `BoxWithConstraints`) in list rows.
- **Views** — flatten rows with `ConstraintLayout`. Nested `LinearLayout`s with `layout_weight`, and `RelativeLayout`, measure children more than once per level; nested, the cost multiplies.
- **Views** — `ViewStub` for rarely shown views; `<merge>` to drop wrappers in includes. Never `requestLayout()` from `onDraw` or a scroll callback.

## 7. Paint

- **Compose** — `graphicsLayer { alpha = … }` below 1 draws into an offscreen buffer; for content that doesn't overlap, `compositingStrategy = CompositingStrategy.ModulateAlpha` avoids it. Use `CompositingStrategy.Offscreen` only for `BlendMode` effects or stable, complex content.
- **Compose** — cache `Path`, `Brush` and `Shader` objects with `Modifier.drawWithCache { … onDrawBehind { } }`.
- **Views** — remove redundant backgrounds (window, root, card) to cut overdraw.

## 8. Animation

- **Compose** — animate through `graphicsLayer`, `offset {}` and `drawBehind {}` lambdas (section 4) so frames skip composition. `TextMotion.Animated` on text that is scaled, moved or rotated so it renders smoothly. In shared-element transitions, `ScaleToBounds` for text; `RemeasureToBounds` can remeasure every frame.
- **Views** — animate only `alpha`, `translationX/Y/Z`, `scaleX/Y`, `rotation*`, `x`/`y`: these update the display list without redrawing the view. Never animate width, height or layout params. For a complex view, `view.animate().alpha(0f).withLayer()` holds a hardware layer only for the animation's duration.

## 9. Images

- **Compose** — Coil `AsyncImage` resolves the target size from layout constraints; give it a fixed size or aspect ratio. `rememberAsyncImagePainter` does not know the on-screen size and loads full size unless you pass a size resolver (for example `rememberConstraintsSizeResolver()`).
- **Views** — Glide or Coil with a target size; `BitmapFactory.Options.inSampleSize` if decoding by hand. Never `BitmapFactory.decodeFile` in `onBindViewHolder` — it is disk I/O plus a full decode on the main thread.

## 10. Off the main thread

- **Both** — heavy mapping, sorting, parsing or diffing: `withContext(Dispatchers.Default) { … }` or `flowOn(Dispatchers.Default)` in the ViewModel. `StrictMode` (debug) flags disk and network on the main thread.

## 11. Hot-path allocation

- **Compose** — no formatters, `Paint`, `Path` or lists allocated in composable bodies or draw lambdas; use `drawWithCache` and top-level constants.
- **Views** — `onDraw` allocates nothing (lint `DrawAllocation`); `Paint`, `Path`, `Rect` as fields. `onBindViewHolder` allocates nothing but the text it sets.

## 12. First-frame jank

- **Both** — baseline profiles (`androidx.baselineprofile` Gradle plugin, generated with `BaselineProfileRule`) precompile scroll and navigation paths.
- **Both** — R8 with `proguard-android-optimize.txt` and no broad `-keep class androidx.compose.**` rules. Newer AGP versions replace the old default ProGuard file; check the AGP release notes for the current optimization switch.

## 13. High refresh rate

- **Both** — on devices with adaptive refresh rate (Android 15 QPR1+ with hardware support), Views default to the "Normal" frame-rate category, typically about 60 Hz. A touch (`ACTION_DOWN`) boosts the rate; a fling lowers it step by step as it slows. RecyclerView 1.4.0 (with core 1.15.0) already reports fling velocity. Don't disable touch boost.
- **Views** — `View.setRequestedFrameRate(...)` (API 35) takes Hz or a `REQUESTED_FRAME_RATE_CATEGORY_*` constant (`HIGH` is a category, not a fixed 120 Hz). The highest vote wins; a `ViewGroup` does not pass its vote to children. Custom scrollers call `setFrameContentVelocity()` each frame.
- **Compose** — `Modifier.preferredFrameRate(Float)` / `Modifier.preferredFrameRate(FrameRateCategory)` (Compose UI 1.9+; earlier betas named it `requestedFrameRate`).
- **Surfaces** — `Surface.setFrameRate(rate, compatibility)` (API 30; the 3-argument overload with change strategy is API 31). `FRAME_RATE_COMPATIBILITY_FIXED_SOURCE` is for video; games and UI use `DEFAULT`.
- **Display mode** — prefer `setFrameRate` when only the rate should change. `WindowManager.LayoutParams.preferredDisplayModeId` also switches resolution; use it only for deliberate mode switches.
- **Capability checks** — `Display.hasArrSupport()` and `Display.getSuggestedFrameRate(Display.FRAME_RATE_CATEGORY_*)` are API 36; guard them. Use `context.display`, not the deprecated `windowManager.defaultDisplay`.
- **Games** — Android 15 defaults games to 60 Hz unless they request otherwise.
