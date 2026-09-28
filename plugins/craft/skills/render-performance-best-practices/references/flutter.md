# Flutter

**Currency stamp: 2026-09-26 (checked against Flutter 3.47).** Sections follow the rule numbers in `SKILL.md`. Check the project's SDK version (`flutter --version`, `pubspec.lock`) — scroll, sliver and renderer APIs changed in 3.27–3.47.

## 1. Measure

- **Two runs, two modes.** Frame timing needs `flutter run --profile` on a real device; debug mode uses a just-in-time compiler with assertions and is not representative. Rebuild counts (DevTools → Performance → Rebuild Stats / Frame Analysis) only work in **debug** — so measure rebuilds in debug and frame times in profile.
- DevTools → Performance frame chart splits the **UI** work (build, layout, paint recording) from **Raster** (GPU drawing). UI over budget → build/layout. Raster over budget → paint cost. Dark-red frames are shader compilation.
- "Track widget builds", "Track layouts" and "Track paints" (Enhance tracing) slow frames down; switch them on only while investigating, never while reading frame times.
- To find what the raster thread pays for, turn off "Render Clip / Opacity / Physical Shape layers" under DevTools → More debugging options and compare raster time.
- `MaterialApp(showPerformanceOverlay: true)` graphs both on device. `checkerboardOffscreenLayers: true` flashes each `saveLayer`. `debugInvertOversizedImages = true` (asserts on) inverts images decoded far larger than shown.
- Budget: the Flutter docs say that at 60 Hz, when latency matters, keep build under 8 ms and raster under 8 ms; at 120 Hz keep the whole frame under 8 ms. Read the display rate from `View.of(context).display.refreshRate` instead of hard-coding 16 ms (on iOS it reports the panel maximum).
- Field monitoring: `SchedulerBinding.instance.addTimingsCallback` gives `FrameTiming` with `buildDuration`, `rasterDuration` and `totalSpan`; reports are batched (about once a second in release) and cost almost nothing.
- Automated: `IntegrationTestWidgetsFlutterBinding.traceAction` + `flutter drive --profile` writes a `TimelineSummary` JSON with frame percentiles.
- Perfetto: `flutter run --profile --trace-to-file=<path>`, or `--trace-systrace` with a system capture. Mark your own spans with `Timeline.startSync`/`finishSync` in `try/finally` and `TimelineTask` for async work. Since 3.29 on Android and iOS, Dart runs on the platform main thread, so Dart work appears on the app's main thread, not a separate `ui` thread.

## 2. Zero calculation in build

- Sorting, filtering, grouping, `DateFormat(...)` / `NumberFormat(...)` / `RegExp(...)` creation and string formatting never in `build`. Do it in the state layer (ChangeNotifier, Bloc, Riverpod Notifier) when data changes and expose a render-ready list; formatters as `static final` or top-level `final`.
- `FutureBuilder(future: api.load())` / `StreamBuilder(stream: …)` created in `build` restarts the work on every rebuild; create the future/stream once in `initState` or the state layer.
- Don't create `GlobalKey`s in `build`; a new key forces the subtree to be recreated.

## 3. Collections in build

- `authors.firstWhere((u) => u.id == a.authorId)` inside a row is a linear scan per row; build `Map<Id, Author>` in the state layer.
- `articles.where(...).toList()..sort(...)` in `build` allocates and sorts the whole list every frame the widget rebuilds; keep the sorted list in state.
- `ListView(children: items.map(...).toList())` builds every row up front; `ListView.builder(itemCount: n, itemBuilder: (c, i) => Row(items[i]))` builds only visible ones.
- Selector-based rebuilds (`context.select`, `Selector`, `BlocSelector`, `ref.watch(p.select(...))`) compare with `==`; returning a new list each time rebuilds every time. Select a field, or keep list identity stable until contents change.

## 4. Rebuild scope

- Split big `build` methods into separate `StatelessWidget` classes, not helper methods: a class gets its own element, can be `const`, and the framework stops rebuilding when it meets the same `const` instance again. (`Container` has no const constructor — use `const Padding`, `DecoratedBox`, `SizedBox`.) The `prefer_const_constructors` lint is not in `flutter_lints` defaults since 5.0.0; enable it explicitly.
- `setState` rebuilds the whole `State`'s subtree. Push fast-changing state into the smallest widget, or wrap only the leaf in `ValueListenableBuilder` / `ListenableBuilder`.
- Subscribe narrowly: `context.select((M m) => m.field)`, `ref.watch(p.select((s) => s.field))`, `BlocSelector`.
- `MediaQuery.sizeOf(context)`, `paddingOf`, `viewInsetsOf`, etc. subscribe to one aspect; `MediaQuery.of(context)` rebuilds on every change, including every frame of the keyboard animation.
- `AnimatedBuilder` / `ListenableBuilder`: pass the static subtree as `child:` and use it inside `builder`.
- Never `setState` from a `ScrollController` listener at page level; drive the one widget that changes (section 8).
- `Offstage` keeps its subtree's tickers running; remove the subtree or wrap it in `TickerMode(enabled: false)`.

## 5. Lists and slivers

- Lazy builders: `ListView.builder`, `GridView.builder`, `SliverList.builder`, `SliverGrid.builder`.
- Give sizes when known: `itemExtent`, `prototypeItem`, or `itemExtentBuilder` (3.16+); `SliverFixedExtentList` / `SliverVariedExtentList` in slivers. Known extents make fast flings and jump-to-index cheap.
- **Mixed content = one `CustomScrollView`**: `SliverAppBar`, `SliverPersistentHeader`, `PinnedHeaderSliver` / `SliverResizingHeader` (3.24+), `SliverFloatingHeader` (3.27+), `SliverList.builder`, `SliverGrid.builder`, `SliverToBoxAdapter` for single widgets. Never nest `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` inside another scroll view — `shrinkWrap` lays out every child.
- Keys: `ValueKey(item.id)` on rows that can move, plus `findChildIndexCallback` on `.builder` constructors so keyed rows keep state after reorder. On `.separated` constructors use `findItemIndexCallback` (counts items, not separators); `findChildIndexCallback` there is deprecated.
- `ListView` wraps each child in a `RepaintBoundary` and handles keep-alive by default. Making every row `AutomaticKeepAliveClientMixin` keeps them all in memory.
- Pre-build distance: `cacheExtent` is deprecated since 3.44; use `scrollCacheExtent: ScrollCacheExtent.pixels(…)` or `ScrollCacheExtent.viewport(…)`. Raising it smooths fast flings at the cost of more build work — fix a slow row before raising it.
- `SliverChildBuilderDelegate.shouldRebuild` always returns true: a new delegate means rows are rebuilt, so keep row builds cheap.

## 6. Layout

- `IntrinsicHeight` / `IntrinsicWidth` add a speculative layout pass over their subtree; nested or inside rows they can grow quadratically. Use fixed sizes or a custom layout.
- `LayoutBuilder` re-runs its builder on every constraint change; keep that builder small.
- Avoid `Wrap` / `Flow` with hundreds of children; use a sliver grid.

## 7. Paint and raster

- `Opacity` on a subtree creates a `saveLayer` (offscreen buffer). `FadeTransition` / `AnimatedOpacity` still composite an opacity layer while the value is between 0 and 1 — what they save is the rebuild and repaint of the child on every tick, not the offscreen pass. Keep faded areas small, and let the value settle at exactly 0 or 1; for a static image use `Image(opacity: const AlwaysStoppedAnimation(0.5))` or a color with alpha. For slivers, `SliverOpacity` / `SliverFadeTransition` — values between 0 and 1 use an offscreen buffer, 0.0 skips paint.
- Hidden `saveLayer` sources: `ShaderMask`, `ColorFiltered`, `Clip.antiAliasWithSaveLayer`, `Chip` with `disabledColorAlpha != 0xff`, `Text` with `TextOverflow.fade`.
- Rounded corners: `BoxDecoration(borderRadius:)`, or `ClipRRect` with its default `Clip.antiAlias`.
- `BackdropFilter` over a scrolling list re-blurs every frame.
- `RepaintBoundary` around widgets that repaint on their own (spinner, chart, video, Lottie, clock); check with DevTools "Highlight repaints". Don't blanket the tree.
- `CustomPainter`: precise `shouldRepaint`, and `CustomPaint(painter: P(repaint: controller))` repaints from a `Listenable` **without rebuilding**. Create `Paint`, `Path`, `TextPainter` once, not in `paint()`.

## 8. Animation

- Transition widgets (`FadeTransition`, `SlideTransition`, `ScaleTransition`, `RotationTransition`, `SizeTransition`) listen at render-object level and don't rebuild their child.
- Implicit animations (`AnimatedContainer`, `AnimatedOpacity`) rebuild only themselves; fine for small widgets.
- Scroll effects: `SliverAppBar` / `SliverPersistentHeader`, or a `FadeTransition` / `Transform` driven from the `ScrollController` on the one widget that changes.
- `AnimationController(vsync: this)` is time-based; don't step values per frame yourself.

## 9. Images

- `Image.network(url, cacheWidth: (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round())` or `ResizeImage` decodes at display size. `cached_network_image` supports `memCacheWidth` / `memCacheHeight`.
- `precacheImage(provider, context)` for the next screen's hero image.

## 10. Off the UI thread

- `await Isolate.run(() => parse(body))` (Dart 2.19+) or `compute(fn, arg)` for parsing, sorting or searching big collections; any sendable function works, closures included. Results are copied back — return compact data.
- On the web, `compute` runs on the main thread and gives no relief.
- Since 3.29 (Android/iOS) Dart runs on the platform main thread: a slow synchronous platform-channel handler now blocks frames. Run heavy native handlers on a background task queue (`makeBackgroundTaskQueue`).

## 11. Hot-path allocation

- No `Paint`, `Path`, `TextPainter`, formatter or `RegExp` created in `build`, `paint()`, item builders or animation listeners. Hoist to fields, `static final`, or one-time setup. In release, `Timeline` calls are near zero cost, but building their `arguments` map is not — build it only when `!kReleaseMode`.

## 12. First-frame and shader jank

- Impeller precompiles shaders, removing most first-run shader jank. It is the only renderer on iOS, the default on Android API 29+ (older or non-Vulkan devices fall back to OpenGL), and the default on macOS, Linux and Windows as of 3.47. SkSL warm-up flags (`--cache-sksl`, `--bundle-sksl-path`) no longer exist.
- `precacheImage` for images the next route shows immediately.

## 13. High refresh rate

- **iOS ProMotion**: the Flutter view is capped at 60 Hz on iPhone unless `CADisableMinimumFrameDurationOnPhone` is `true` in `ios/Runner/Info.plist`. New projects have it since Flutter 3.0 and the tool migrates older ones — check it is present, especially in add-to-app hosts. iPad Pro needs no key.
- **Android**: Flutter follows the display mode the system gives the window, and some devices keep apps at 60 Hz (flutter/flutter#160952). `flutter_displaymode` can request the highest mode; call it in the root `initState`, it lasts only for the session, and it does nothing on variable-refresh (LTPO) panels. Confirm the rate on device from `View.of(context).display.refreshRate` and the frame interval in DevTools; the performance overlay shows frame times, not the display's refresh rate.
