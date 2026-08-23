# Scroll Strategies API

The `ScrollStrategy` interface gives you full control over how the editor scrolls in response to a selection change. It mirrors the `KeyboardStrategy` pattern: **the editor delegates; the strategy decides.** The default behavior is the built-in edge-follow (scroll only when the caret leaves the viewport); a strategy can replace it entirely (e.g. always-center typewriter scrolling) or layer on top of it.

## Quick Start

Enable typewriter scrolling (the cursor stays vertically centered at 45% of the viewport, instantly — no animation):

```dart
final editor = NovidentEditor(
  editorState: state,
  // Keep the cursor centered while typing:
  scrollStrategies: const [TypewriterScrollStrategy()],
);
```

Pass an empty list (the default) to keep the built-in edge-follow:

```dart
NovidentEditor(
  editorState: state,
  scrollStrategies: const [], // default edge-follow
);
```

## The Interface

```dart
// Result of a strategy for a selection-change event.
enum ScrollDecision {
  ignored, // not mine — let the next strategy (or the default edge-follow) handle it
  handled, // I handled the scroll (or decided no scroll is needed) — stop dispatch
}

// Policy that decides how the editor scrolls on a selection change.
abstract class ScrollStrategy {
  const ScrollStrategy();

  ScrollDecision onSelectionChanged(ScrollStrategyContext ctx);
}

// The default policy: delegates to the built-in edge-follow.
// Extend this to layer extra behavior on top of the default.
class DefaultScrollStrategy extends ScrollStrategy {
  const DefaultScrollStrategy();
}
```

Return `ScrollDecision.handled` to take over the scroll (and stop dispatch), or `ScrollDecision.ignored` to let the next strategy — or the built-in edge-follow — handle it.

## How Dispatch Works

On every selection change (each keystroke, caret move, click, …) the editor:

1. Measures the selection rects **once** and builds a `ScrollStrategyContext`.
2. Consults the strategies **in order**; the first one that returns `ScrollDecision.handled` wins.
3. If none handles it, the built-in edge-follow runs (using the same already-measured rects).

So strategies are composed like `keyboardStrategies`: put the most specific one first.

## Context Objects

Every strategy receives a `ScrollStrategyContext` with everything it needs to decide and act:

| Field | Description |
|---|---|
| `editorState` | The `EditorState` — read the document, the selection, `scrollableState`, … |
| `selection` | The current `Selection` that triggered the event. |
| `reason` | Why the selection changed (`SelectionUpdateReason`). |
| `scrollService` | The `NovidentScrollService` — `startAutoScroll`, `scrollTo`, `jumpTo`, `dy`, … |
| `editorScrollController` | The low-level `EditorScrollController` — instant `scrollOffsetController.jumpTo` / `animateTo`, `itemScrollController`, … |
| `selectionRects` | The selection rects, already measured once for this event (cheap to reuse). |
| `state` | Persistent per-editor state shared across events (see below). |

### Persistent state (`ScrollStrategyState`)

Strategies are `const` and stateless by design (they are passed as `const [MyStrategy()]`), so anything a strategy needs to remember between events lives in `ctx.state` — a per-editor store owned by the scroll service. Each strategy keeps its own values under its runtime type:

```dart
class _MyState {
  double? lastPixels;
}

final state = ctx.state.getOrCreate(_MyState.new);
state.lastPixels = ctx.editorState.scrollableState?.position.pixels;
```

This is how `TypewriterScrollStrategy` detects stale render-tree measurements when keystrokes arrive faster than frames render (see below).

## TypewriterScrollStrategy

Keeps the cursor **always centered** at `alignment` of the viewport, instantly (no animation — animation would ping-pong). The document scrolls under the cursor. When the selection is **not collapsed** (e.g. the user is selecting text), it delegates to the default edge-follow.

```dart
const TypewriterScrollStrategy({
  this.alignment = 0.45,        // where the cursor sits: 0.0 = top, 0.5 = center, 1.0 = bottom
  this.centerTolerance = 1.0,   // min distance from the target before scrolling (avoids typing jitter)
  this.stalenessTolerance = 0.5, // render-box movement tolerance for the stale-measurement guard
});
```

### Why the stale-measurement guard exists

When keystrokes arrive faster than frames render (large documents), the render tree is frozen at the previous frame's scroll offset while the scroll controller already reports the new one. Measuring the caret against that frozen tree and scrolling by the resulting delta piles up stale corrections and makes the typewriter "go crazy". The strategy skips events where the render box did not move with the scroll, and corrects on the next fresh measurement. You normally don't need to touch `stalenessTolerance`.

## Examples

### Typewriter scrolling (built-in)

```dart
import 'package:novident_editor/novident_editor.dart';

final EditorState state = EditorState.blank();

final editor = NovidentEditor(
  editorState: state,
  scrollStrategies: const [TypewriterScrollStrategy()],
);
```

Tune the center point and jitter tolerance:

```dart
final EditorState state = EditorState.blank();
final editor = NovidentEditor(
  editorState: state,
  scrollStrategies: const [
    TypewriterScrollStrategy(
      alignment: 0.5,          // exact center
      centerTolerance: 2.0,    // don't scroll for sub-2px drift
    ),
  ],
);
```

### A custom strategy: "keep the caret in the top third"

A strategy that scrolls only when the caret leaves the top third of the viewport (a "focus mode" that is less aggressive than always-center):

```dart
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

class TopThirdScrollStrategy extends DefaultScrollStrategy {
  const TopThirdScrollStrategy();

  @override
  ScrollDecision onSelectionChanged(ScrollStrategyContext ctx) {
    // Expanded selection → let the default edge-follow handle it.
    if (!ctx.selection.isCollapsed) {
      return ScrollDecision.ignored;
    }

    final scrollableState = ctx.editorState.scrollableState;
    if (scrollableState == null || ctx.selectionRects.isEmpty) {
      return ScrollDecision.ignored;
    }

    // selectionRects are in global coordinates; subtract the scrollable origin
    // to get the caret's viewport-local position.
    final scrollableBox =
        scrollableState.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null) {
      return ScrollDecision.ignored;
    }
    final origin = scrollableBox.localToGlobal(Offset.zero).dy;
    final caretCenter = ctx.selectionRects.first.center.dy - origin;

    final viewportHeight = scrollableState.position.viewportDimension;
    final target = viewportHeight / 3;

    // Only scroll when the caret drifts below the top third.
    if ((caretCenter - target).abs() < 1.0) {
      return ScrollDecision.handled; // already in place — no scroll needed
    }

    final pixels = scrollableState.position.pixels;
    final targetOffset = (pixels + (caretCenter - target)).clamp(
      scrollableState.position.minScrollExtent,
      scrollableState.position.maxScrollExtent,
    );
    ctx.editorScrollController.scrollOffsetController.jumpTo(
      offset: targetOffset,
    );
    return ScrollDecision.handled;
  }
}
```

### Composing strategies

Strategies are consulted in order; the first `handled` wins. Put the most specific one first:

```dart
NovidentEditor(
  editorState: state,
  scrollStrategies: const [
    // Always-center wins when it applies…
    TypewriterScrollStrategy(),
    // …anything it ignores (e.g. expanded selections) falls through here.
    MyEdgePolicyStrategy(),
  ],
);
```

### Layering on top of the default

Extend `DefaultScrollStrategy` and return `ScrollDecision.ignored` for the cases you don't own — the built-in edge-follow then runs as the fallback (this is exactly what `TypewriterScrollStrategy` does for non-collapsed selections).

## Limitations

- **Strategies are consulted only on selection changes**, not on every scroll frame. Continuous behaviors (like the edge-follow's incremental auto-scroll) are driven through `ctx.scrollService.startAutoScroll` / `ctx.editorScrollController`, not by returning `handled` repeatedly.
- **`selectionRects` are measured once per event** and are in global coordinates. To get a viewport-local position, subtract the scrollable's global origin (see the example above). Re-measuring the caret yourself with `getCursorRectInPosition` is possible but more expensive — prefer reusing `ctx.selectionRects`.
- **`shrinkWrap` mode** has no `ScrollOffsetController`; strategies that need instant `jumpTo` should return `ScrollDecision.ignored` when `ctx.editorScrollController.shrinkWrap` is true (as `TypewriterScrollStrategy` does).
