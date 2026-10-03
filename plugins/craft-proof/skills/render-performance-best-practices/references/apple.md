# Apple — SwiftUI and UIKit

**Currency stamp: 2026-09-26.** Sections follow the rule numbers in `SKILL.md`. Check the deployment target before using an API marked with an OS version. iPhones and iPads top out at 120 Hz; 144–240 Hz only applies to Mac apps on external displays.

## 1. Measure

- **Both** — profile a **Release** build on a real device with Instruments.
- **Both** — first decide which kind of hitch it is. A **commit hitch** is the app's main thread finishing layout, body updates or drawing too late. A **render hitch** is the render server failing to draw a complex layer tree (offscreen passes, blurs, masks) in time. Different fixes.
- **Both** — Animation Hitches template: hitch time ratio in ms of hitch per second of motion. Under 5 ms/s is good, 5–10 ms/s is a warning, 10 ms/s or more is critical.
- **SwiftUI** — the Xcode 26 SwiftUI instrument has lanes for Update Groups, Long View Body Updates, Long Representable Updates and Other Long Updates, coloured by how likely each update is to cause a hitch, plus a **Cause & Effect Graph** that traces each body update back to the state change that caused it.
- **SwiftUI** — `let _ = Self._printChanges()` inside `body` (debug only) prints which property made the view re-evaluate.
- **Both** — `OSSignposter` (iOS 15+) intervals around your own work; `makeSignpostID()` for overlapping intervals; for async work use `beginInterval`/`endInterval` (the `withIntervalSignpost` closure is synchronous).
- **Both** — XCTest: `measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric])` (iOS 15; replaces the deprecated `scrollDecelerationMetric`) for scroll hitch regressions; `XCTOSSignpostMetric(subsystem:category:name:)` for your own signposts.
- **Both** — MetricKit reports field hitch rates. `MXAnimationMetric` is being replaced by `MetricResult` with a `HitchTimeMetric` case in the newest SDKs; check the deployment target.
- **UIKit** — Simulator → Debug → Color Off-screen Rendered / Color Blended Layers.

## 2. Zero calculation in build

- **SwiftUI** — `body` can run many times per second. No sorting, filtering, grouping, or `DateFormatter()` / `NumberFormatter()` creation inside it. Sort once in the model when data changes; use `static let` formatters or `Text(date, format: .dateTime.day().month())`.
- **UIKit** — `cellForItemAt` / cell registration handlers assign precomputed strings and images only; no formatter creation, file reads or decoding. Do one-time layer setup (corner radius, shadow) in the cell's initializer — `init(frame:)` for code cells, `awakeFromNib` / `init(coder:)` for storyboard or XIB cells; never `fatalError` in `init(coder:)` if the cell may come from a storyboard.
- **Both** — `DateFormatter` and `NumberFormatter` are thread-safe on current iOS, so one `static let` can be shared by background row-building code.

## 3. Collections in build

- **SwiftUI** — never call `model.posts.sorted { … }` in `body` (once per evaluation, or worse, once per row). Store the sorted array in the model.
- **SwiftUI** — `likedIDs.contains(post.id)` on an array is a linear scan per row; use a `Set`.
- **SwiftUI** — with `@Observable`, a row that reads a shared collection (even indirectly, via `model.likedIDs`) is invalidated whenever that collection changes. For per-item flags such as favorites, give each row its own small `@Observable` item model, or pass the row a plain `Bool`.
- **UIKit** — diffable snapshots are keyed by identifiers; build them from the model's array once per data change, not per scroll.

## 4. Rebuild scope

- **SwiftUI** — prefer `@Observable` (iOS 17+) over `ObservableObject`: a view is invalidated only when a property it read in `body` changes. With `ObservableObject` + `@Published`, any published change invalidates every observing view — a 30 Hz `uploadProgress` redraws the whole feed.
- **SwiftUI** — split large views into small `View` structs so SwiftUI can compare inputs and skip unchanged ones. Keep fast-changing values out of the Environment: every view reading the Environment is checked on any change.
- **SwiftUI** — keep view identity stable: switching between different view types in `if/else` destroys and recreates state; for a style change use one view with a ternary modifier value. Avoid `AnyView` in hot paths.
- **SwiftUI** — `.equatable()` / `EquatableView` for an expensive view whose inputs have a cheap `==`.
- **UIKit** — `snapshot.reconfigureItems(_:)` (iOS 15+) updates an existing cell in place instead of dequeuing a new one.

## 5. Lists

- **SwiftUI** — `List`, or `LazyVStack` / `LazyVGrid` inside `ScrollView`, for long content. A plain `VStack` in `ScrollView` builds every row.
- **SwiftUI** — `ForEach(items) { … }` with `Identifiable` models and stable, unique ids. Avoid `ForEach(items.indices, id: \.self)` — identity follows position, so inserts reset row state.
- **SwiftUI** — in `List`, each `ForEach` element must produce a **constant number of views**. `AnyView` or an `if` that sometimes produces nothing makes the count unknown and `List` builds every row up front. Filter the data, not the rows.
- **UIKit** — `UICollectionViewDiffableDataSource` + snapshots instead of `reloadData()`. Since iOS 15, applying a snapshot without animation diffs rather than reloading everything.
- **UIKit** — building with the iOS 15+ SDK turns on automatic cell prefetching, which gives each cell up to twice the time to prepare. Add `prefetchDataSource` (`UICollectionViewDataSourcePrefetching`) to start image loads early.
- **UIKit** — `UICollectionViewCompositionalLayout` for sections, grids and orthogonal scrolling in one collection view instead of nesting.

## 6. Layout

- **SwiftUI** — avoid `GeometryReader` in every row. Use `onGeometryChange(for:of:action:)` (iOS 16+) to react to a size only when it changes, and `containerRelativeFrame` (iOS 17+) for relative sizing.
- **SwiftUI** — `Layout` methods, `Shape.path` and `onGeometryChange` transforms may run off the main thread: keep them pure and free of shared mutable state.
- **UIKit** — change constraints by updating `constant` in place; deactivating and reactivating constraints ("churn") is the expensive path. Prefer `setNeedsLayout()` over `layoutIfNeeded()`. Toggle `isHidden` instead of adding and removing subviews. Remove empty `draw(_:)` overrides.
- **UIKit** — self-sizing cells cost a layout pass each; give accurate estimated sizes.

## 7. Paint

- **UIKit** — the four sources of offscreen passes: **shadows, masks, rounded corners with clipping, and blur/vibrancy views.** Set `layer.shadowPath` explicitly (without it, Core Animation renders offscreen to find the shape). For rounded cards, give the view a background color and `cornerRadius` without `masksToBounds`; if content must be clipped, clip an inner view and put the shadow on an outer one.
- **UIKit** — `layer.shouldRasterize = true` only for static, complex content, with `rasterizationScale` set to the screen scale. On changing content it re-rasterizes every frame.
- **SwiftUI** — `.shadow` on a large row with many subviews is costly; apply it to a simple background shape instead of the whole row.
- **SwiftUI** — `.drawingGroup()` composites a subtree into one offscreen Metal image: helps for many overlapping shapes and gradients, not for simple views. It shows a placeholder for UIKit/AppKit-backed views. Use `Canvas` for dynamic drawing of many shapes that don't need to be individually tappable.

## 8. Animation

- **SwiftUI** — built-in animatable effects (opacity, offset, scale, rotation) are interpolated off the main thread without calling your view code. A custom `Animatable` conformance runs `body` every frame — keep it tiny.
- **SwiftUI** — scroll effects: `.scrollTransition { content, phase in … }` and `.visualEffect { content, proxy in … }` (iOS 17+) apply per-frame changes without writing scroll position into state. Their closures may run off the main thread; keep them pure.
- **SwiftUI** — `TimelineView(.animation)` + `Canvas` for custom per-frame drawing. Precompile custom shaders with `Shader.compile(as:)` (iOS 18+) so the first frame doesn't stall.
- **UIKit** — Core Animation and `UIViewPropertyAnimator` interpolate in the render server. Never drive motion with a `Timer`.

## 9. Images

- **Both** — downsample before display: ImageIO `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize` and `kCGImageSourceCreateThumbnailFromImageAlways`, or `UIImage.byPreparingThumbnail(ofSize:)` / `preparingThumbnail(of:)` (iOS 15+). A 12 MP photo decoded full size is about 48 MB per image.
- **Both** — size the thumbnail from the view's real bounds times the screen scale (`displayScale` / `traitCollection.displayScale`), not a fixed pixel count. Cancel the load in `prepareForReuse` (UIKit) or when the row's `.task(id:)` restarts (SwiftUI), and allow a few decodes in parallel.
- **Both** — decode off the main thread: `UIImage.prepareForDisplay(completionHandler:)` / `byPreparingForDisplay()`. Never `UIImage(contentsOfFile:)` inside `body` or `cellForItemAt` — that is disk I/O plus a decode on the main thread at draw time.
- **SwiftUI** — for feeds, use an image loader with memory caching rather than relying on `AsyncImage`.

## 10. Off the main thread

- **Both** — views and `@Observable` models are usually main-actor isolated. In Swift 6.2 with `NonisolatedNonsendingByDefault`, a plain `nonisolated async` function runs on the **caller's** actor, so it does not leave the main actor. Mark heavy work `@concurrent` (or move it into a separate actor) and assign the result back on the main actor.
- **Both** — no disk, network, large JSON decoding or image decoding on the main thread.

## 11. Hot-path allocation

- **Both** — formatters, `NSAttributedString` construction, `UIBezierPath` building and image loading never inside `body`, `cellForItemAt`, `draw(_:)`, `layoutSubviews` or display-link callbacks. Hoist to `static let`, the model, or one-time setup.

## 12. First-frame jank

- **SwiftUI** — `Shader.compile(as:)` for Metal shader effects; prepare the first screen's images with `byPreparingThumbnail(ofSize:)` before showing it.
- **Both** — `CAMetalLayer.presentsWithTransaction = true` when Metal content must stay in sync with UIKit overlays during animation.

## 13. High refresh rate (ProMotion)

- **iPhone** — add `CADisableMinimumFrameDurationOnPhone` = `YES` (Boolean) to `Info.plist`, or `CADisplayLink` and `CAAnimation` frame-rate requests above 60 Hz are ignored. iPad Pro does not need the key. System scrolling and UIKit/SwiftUI animations pace themselves.
- **Request** — `CADisplayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)` (iOS 15+); `CAAnimation.preferredFrameRateRange` for layer animations. The system may give you less (Low Power Mode, thermal state, the Accessibility "Limit Frame Rate" setting caps at 60 Hz).
- **Ask for the lowest rate that looks right.** 80–120 Hz only for high-impact motion (fast scrolls, drags, full-screen transitions); fades and small movements look fine lower, and 120 Hz costs battery. Share one `CADisplayLink` among animations with similar timing.
- **Expect any rate**: iPad Pro offers 120/60/40/30/24 Hz; iPhone adds 80/48/20/16/15/12/10 Hz.
- **Time** — drive motion from `targetTimestamp`; time left in the current frame is `targetTimestamp - CACurrentMediaTime()`. Read `CADisplayLink.duration` for the current interval; `UIScreen.maximumFramesPerSecond` reports 120 even in Low Power Mode.
- **Screen access** — `UIScreen.main` is deprecated in iOS 26; use `view.window?.windowScene?.screen`.
