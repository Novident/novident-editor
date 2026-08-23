# Auto-scroll edge calculation: from rects to exact offsets

How the auto-scroll edge detection changed between `appflowy-editor` and this editor. The original implementation edge policy operated on **rectangles** (an inflated rect compared against the viewport). The current implementation replaces that with **exact offsets** (the caret's viewport-local position compared against an explicit `inset`), which removes an off-by-`edgeOffset/2` error and a fragile coordinate conversion.

---

## Before: rect-based edge detection

The logic lived in the vendored Flutter `EdgeDraggingAutoScroller`
(`lib/src/flutter/scrollable_helpers.dart`) and `AutoScroller`
(`service/scroll/auto_scroller.dart`).

### The trigger was an inflated rectangle

`AutoScroller.startAutoScroll` turned the caret/finger offset into a **rect**
whose size depended on `edgeOffset` and `direction`:

```dart
// auto_scroller.dart
void startAutoScroll(Offset offset, {double edgeOffset = 200, AxisDirection? direction, ...}) {
  if (direction == AxisDirection.up) {
    return startAutoScrollIfNecessary(
        Rect.fromLTWH(offset.dx, offset.dy - edgeOffset, 1, edgeOffset), ...);
  }
  if (direction == AxisDirection.down) {
    return startAutoScrollIfNecessary(
        Rect.fromLTWH(offset.dx, offset.dy, 1, edgeOffset), ...);
  }
  // direction == null → a rect of size edgeOffset centered on the caret
  final dragTarget = Rect.fromCenter(center: offset, width: edgeOffset, height: edgeOffset);
  startAutoScrollIfNecessary(dragTarget, ...);
}
```

The resolver then compared the **rectangle's edges** — `proxyStart`/`proxyEnd` —
against the viewport's edges:

```dart
// scrollable_helpers.dart (EdgeDraggingAutoScroller._scroll)
final double proxyStart = _offsetExtent(_dragTargetRelatedToScrollOrigin.topLeft, _scrollDirection);
final double proxyEnd   = _offsetExtent(_dragTargetRelatedToScrollOrigin.bottomRight, _scrollDirection);

switch (_axisDirection) {
  case AxisDirection.down:
    if (proxyStart < viewportStart && pixels > minScrollExtent) { /* scroll up */ }
    else if (proxyEnd > viewportEnd && pixels < maxScrollExtent) { /* scroll down */ }
}
```

Two problems follow directly from using a rect:

1. **Off-by-`edgeOffset/2`.** For `direction == null` the rect is `edgeOffset`
   tall and centered, so its edges sit `edgeOffset/2` above and below the caret.
   The trigger fired when `caret ± edgeOffset/2` crossed the viewport edge —
   i.e. `edgeOffset/2` px **before** the caret actually reached the edge. The
   band was also asymmetric: `edgeOffset/2` for the caret, but `edgeOffset` for
   the `up`/`down` handles (whose rects were not centered).

2. **A fragile coordinate conversion.** The rect was converted through two
   frames that mean different things:

   ```dart
   // startAutoScrollIfNecessary
   _dragTargetRelatedToScrollOrigin = dragTarget.translate(deltaToOrigin.dx, deltaToOrigin.dy); // − pixels

   // _scroll
   final Matrix4 transform = scrollRenderBox.getTransformTo(null); // viewport→global, NO scroll
   final Rect transformedDragTarget = MatrixUtils.transformRect(transform, _dragTargetRelatedToScrollOrigin);
   final Rect viewport = (globalRect.topLeft.translate(deltaToOrigin)) & globalRect.size;
   ```

   `deltaToScrollOrigin` (`(0, -pixels)`) is how far the **content** scrolled;
   `getTransformTo(null)` is the **viewport's** transform to global (which does
   *not* include the scroll). Mixing them only looked correct because the
   `-pixels` cancelled out in the relative comparison — a coincidence that broke
   under keyboard resize, nested scrollables, DPR ≠ 1, or a transformed ancestor.

---

## We change it to use now: exact offsets

The edge policy was moved into a dedicated `EdgeInsetResolver`
(`service/scroll/scroll_target_resolver.dart`), and the follow loop into
`ScrollDriver` (`service/scroll/scroll_driver.dart`).

### The trigger is now an exact caret offset

The caret's **viewport-local offset** (`0` = start, `viewportDimension` = end) is
compared directly against an explicit symmetric `inset`, with no rect:

```dart
// scroll_target_resolver.dart (EdgeInsetResolver)
ScrollTarget? resolve({
  required double caretOffset,       // viewport-local, 0..viewportDimension
  required double viewportDimension,
  required double inset,
  required AxisDirection axisDirection,
  required double pixels,
  required double minScrollExtent,
  required double maxScrollExtent,
}) {
  switch (axisDirection) {
    case AxisDirection.down:
      if (caretOffset < inset && pixels > minScrollExtent) {
        return ScrollTarget(overshoot: min(inset - caretOffset, maxOvershoot),
            direction: ScrollDirection.decrease);
      }
      if (caretOffset > viewportDimension - inset && pixels < maxScrollExtent) {
        return ScrollTarget(
            overshoot: min(caretOffset - (viewportDimension - inset), maxOvershoot),
            direction: ScrollDirection.increase);
      }
      break;
    // up / left / right mirror the logic.
  }
  return null;
}
```

### The conversion is now explicit and correct

`ScrollDriver` converts the global target with `RenderBox.globalToLocal` once,
anchors it in **document** space, and re-derives the viewport-local offset per
tick (so the overshoot converges):

```dart
// scroll_driver.dart
void start(Offset globalTarget, {required double inset, Duration? duration}) {
  final RenderBox box = scrollable.context.findRenderObject()! as RenderBox;
  final Offset caretLocal = box.globalToLocal(globalTarget);   // correct, once
  _caretDocumentOffset =
      scrollable.position.pixels + _offsetExtent(caretLocal, axis);
  ...
}

Future<void> _scroll() async {
  final position = scrollable.position;
  final double caretOffset = _caretDocumentOffset! - position.pixels; // converges
  final double viewportDimension = position.viewportDimension;
  ...
}
```

The `direction` parameter was removed from the whole chain: direction is now a
**result** of resolving which edge the caret is near, not an input that changes
the geometry.

---

## The key difference, side by side

| Aspect | `appflowy-editor` (rects) | `novident-editor` (offsets) |
|---|---|---|
| What is compared | `proxyStart` / `proxyEnd` — the **rect's** edges | `caretOffset` — the caret's **exact** position |
| Dead zone | implicit: half the rect size (`edgeOffset/2`) | explicit: `inset` |
| Band symmetry | `edgeOffset/2` (caret) vs `edgeOffset` (handles) | `inset`, symmetric everywhere |
| Trigger condition | `caret ± edgeOffset/2 > viewportEdge` | `caretOffset > viewportDimension - inset` |
| "Fire only at the edge" | impossible | `inset = 0` |
| Coordinate conversion | `deltaToScrollOrigin` + `getTransformTo(null)` (two mixed frames) | `globalToLocal` once + document-space anchor |
| Direction | input (`up`/`down`/`null` → different rects) | resolved by the resolver |

The exact-offset approach removes the off-by-`edgeOffset/2` error (the caret now
triggers at `inset` px from the edge, not `edgeOffset/2`), makes the dead zone
explicit and symmetric, and replaces the accidental coordinate cancellation with
a correct, deterministic conversion.
