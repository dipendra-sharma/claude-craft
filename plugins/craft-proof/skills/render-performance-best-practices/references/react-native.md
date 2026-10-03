# React Native

**Currency stamp: 2026-09-26.** Sections follow the rule numbers in `SKILL.md`. Check `package.json`, the lockfile, the React Native version and whether the New Architecture is on before relying on a version-specific claim. React web rules in `web.md` (React Compiler, `memo`, context, selectors) apply here too.

## Threads

The JavaScript thread runs React (renders, handlers, most business logic). The UI (main) thread runs native views, layout commits and native-driven animations. Either missing the budget drops frames: a busy JavaScript thread makes touches and JavaScript-driven animation lag; a busy UI thread makes scrolling itself stutter.

## 1. Measure

- Measure a **release build**: React Native command line `npx react-native run-android --mode release`; Expo `npx expo run:ios --configuration Release` / `npx expo run:android --variant release`. Development mode adds checks and warnings.
- The in-app Perf Monitor shows JavaScript-thread and UI-thread fps separately.
- React Native DevTools → Profiler for component render cost.
- Flashlight (Android): `flashlight measure` for a live, hand-driven audit; `flashlight test` for scripted runs over several iterations with an fps and CPU score.
- Native tools still apply: Android Studio / Perfetto (`android.md`), Instruments (`apple.md`).
- Strip `console.*` from release builds (for example `babel-plugin-transform-remove-console`); console calls are a JavaScript-thread bottleneck.

## 2. Zero calculation in build

- Component bodies re-run on every render: no `products.filter(...)`, sorting, `toFixed`/`Intl` formatting of whole lists, or formatter construction there. Prepare render-ready data in the data layer (store, query `select`, or a memoized selector) and module-scope formatters.

## 3. Collections in build

- `favorites.includes(item.id)` in `renderItem` is a linear scan per row; keep a `Set`.
- `data={products.filter(p => p.inStock)}` passes a new array every render, which makes the list re-evaluate every row; keep the filtered array stable until inputs change.
- Pass rows booleans (`isFav`) and primitives, not whole collections.

## 4. Rebuild scope

- Never `setState` from `onScroll`; scroll position goes into a Reanimated shared value (section 8).
- Row components: `React.memo` unless React Compiler is enabled; a stable `renderItem` (module scope or `useCallback`); props that keep identity between renders.
- Never define a component inside another component's body (remounts every render).

## 5. Lists

- **FlashList** (`@shopify/flash-list`) recycles row views instead of unmounting them. v2 is New-Architecture only and no longer needs `estimatedItemSize`. Provide a stable `keyExtractor` (strongly recommended in v2) and `getItemType` for mixed rows so each type recycles into the same type.
- Recycled rows are reused for different items, so **local `useState` in a row leaks between items**. Derive row state from props, or use `useRecyclingState(initial, [item.id])`, which resets when its dependencies change. With `expo-image`, pass `recyclingKey={item.id}` so the old image does not flash.
- **FlatList** if staying on it: `keyExtractor` with stable ids; `getItemLayout` for fixed heights (skips measurement, enables instant scroll-to-index); tune `initialNumToRender`, `maxToRenderPerBatch`, `windowSize`; `removeClippedSubviews` for long lists of simple rows.
- Never render long data with `ScrollView` + `.map()`, and never put a `FlatList`/`FlashList` inside a `ScrollView` of the same orientation — it disables virtualization. Use `ListHeaderComponent` / `ListFooterComponent` or `SectionList`.

## 6. Layout

- Animating `width`, `height`, `top`, `left` or `margin` re-runs Yoga layout and commits every frame; animate `transform` of a fixed-size box instead.
- Fixed image and card sizes let the list skip measurement.

## 7. Paint

- Large shadows (`shadow*` on iOS, `elevation` on Android) and blur views on many rows are costly on the UI thread; apply them to a simple background view, not a complex row.

## 8. Animation and gestures

- **Reanimated**: `useSharedValue` + `useAnimatedStyle` run as worklets on the UI thread, so animation stays smooth when the JavaScript thread is busy. Scroll effects via `useAnimatedScrollHandler` + `Animated.ScrollView` / `Animated.FlatList` (or FlashList wrapped with `Animated.createAnimatedComponent`). Reanimated 4 moved thread helpers to `react-native-worklets`: `scheduleOnRN` (was `runOnJS`), `scheduleOnUI` (was `runOnUI`).
- **react-native-gesture-handler** gestures run on the UI thread and can drive shared values directly.
- Legacy `Animated`: `useNativeDriver: true` moves animation to native, but only for non-layout props (`transform`, `opacity`).
- Use durations or springs, never per-frame increments.

## 9. Images

- `expo-image` (memory and disk cache, `recyclingKey`, placeholders) or another caching loader; request images close to their display size from the server or CDN rather than decoding full-size photos into 160-pixel cards.

## 10. Off the JavaScript thread

- Move heavy transforms (large JSON reshaping, sorting, search indexing) out of render, into the data layer, a native module, or a separate worklet runtime: `scheduleOnRuntime(createWorkletRuntime({ name }), fn, ...args)` from `react-native-worklets` (`runOnRuntime` is deprecated).
- Defer non-urgent work with `requestIdleCallback`. `InteractionManager` was removed in React Native 0.87.

## 11. Hot-path allocation

- No formatter construction, inline style objects rebuilt per row, or temporary arrays inside `renderItem`, gesture callbacks or worklets. `StyleSheet.create` at module scope.

## 12. First-frame jank

- Hermes (the default engine) precompiles JavaScript to bytecode at build time. Keep the first screen's list short (`initialNumToRender` / FlashList's defaults) and prefetch its images.

## 13. High refresh rate

- iOS ProMotion needs `CADisableMinimumFrameDurationOnPhone` = `YES` in `Info.plist`. Current React Native and Expo templates already include it — check older or add-to-app projects.
- Android: the app runs at the display mode the system picks; see `android.md` section 13 for frame-rate APIs. Verify on device with the Perf Monitor.
