# Cursor Customization API

The `SelectionRenderer` interface in `novident_selection` gives you full control over how the editor paints cursors, selections, and block highlights, as well as how cursor movement behaves — including animated transitions between positions.

## Quick Start

```dart
final editor = NovidentEditor(
  editorState: state,
  editorStyle: EditorStyle.desktop(
    padding: const EdgeInsets.all(20),
    cursorColor: Colors.blue,
    selectionColor: Colors.blue.withAlpha(50),
    // Your custom renderer:
    selectionRenderer: MyCustomRenderer(),
  ),
);
```

## The Interface

```dart
abstract class SelectionRenderer {
  // ── Render (4 methods) ──
  Widget buildCursor(CursorPaintContext ctx);

  @Deprecated(
      'Use shouldPaintHeadRect + SelectionPaintContext.headColor instead. '
      'Will be removed in a future version.')
  Widget buildExpandedHeadCursor(CursorPaintContext ctx);
  Widget buildSelectionHighlight(SelectionPaintContext ctx);
  Widget buildBlockSelectionHighlight(BlockSelectionContext ctx);

  /// Called during the [editorState.updateSelectionWithReason]. Provides
  /// the values that let us decide which will be the new selection for
  /// the editor
  Future<Selection?> updateSelectionWithReason(
    BlockSelectionHost state,
    Selection? selection, {
    SelectionUpdateReason reason = SelectionUpdateReason.transaction,
    Map? extraInfo,
    SelectionType? customSelectionType,
  }) async =>
      null;

  /// Whether the selection painter should differentiate the moving head
  /// of an expanded selection by painting its rect in cursor color.
  bool get shouldPaintHeadRect => false;

  /// Whether the [NovidentRichText] should take in account the moving head
  /// of an expanded selection to compute the correct character constrast color.
  bool get headWrapsCharacter => false;

  /// Whether the [EditorState] should take in account the [start] and [end] positions
  /// of the selection and collapse if them starts at the same point.
  bool get shouldCollapseIfSharePositions => true;

  @Deprecated(
      'Use shouldPaintHeadRect instead. Will be removed in a future version.')
  bool get paintExpandedHeadCursor => false;

  @Deprecated('The painter handles head positioning via shouldPaintHeadRect. '
      'Will be removed in a future version.')
  Position? expandedHeadPosition(Selection? rawSelection) => null;

  // ── Movement (6 methods) ──
  Position? onVerticalMove(CursorMoveContext ctx);
  Position? onHorizontalMove(CursorMoveContext ctx, {bool byWord = false});
  Position? onMoveToLineStart(CursorMoveContext ctx);
  Position? onMoveToLineEnd(CursorMoveContext ctx);
  Position? onPageUp(CursorMoveContext ctx);
  Position? onPageDown(CursorMoveContext ctx);

  // ── Transition (2 methods) ──
  MoveIntention? onTryMove(MoveAttemptContext ctx);
  void onMoveCompleted(MoveCompletedContext ctx);

  // ── Lifecycle (4 methods) ──
  void onSelectionStarted(SelectionLifecycleContext ctx);
  void onSelectionEnded(SelectionLifecycleContext ctx);
  void onFocusGained(FocusLifecycleContext ctx);
  void onFocusLost(FocusLifecycleContext ctx);

  // ── Measurement (2 methods) ──
  Rect? onCursorRectMeasured(CursorMeasureContext ctx);
  List<Rect>? onSelectionRectsMeasured(SelectionMeasureContext ctx);
}
```

Return `null` from any movement or measurement method to use the default behavior. Return a widget from render methods — the [DefaultSelectionRenderer] provides the standard look.

## Context Objects

Every method receives a context object with all the data you need:

| Context | Key fields |
|---|---|
| `CursorPaintContext` | `node`, `selection`, `position`, `rect`, `color`, `style`, `shouldBlink`, `isExpandedHead`, `textDirection`, `delegate` |
| `SelectionPaintContext` | `node`, `selection`, `rects`, `color`, `textDirection` |
| `BlockSelectionContext` | `node`, `rect`, `color`, `margin` |
| `CursorMoveContext` | `node`, `currentOffset`, `caretLocalDx`, `textDirection`, `delegate`, `renderParagraph`, `textShift`, `delta` |
| `MoveAttemptContext` | `currentNode`/`Position`/`CursorRect`, `targetNode`/`Position`/`CursorRect`, `direction`, `crossesBlockBoundary` |
| `MoveCompletedContext` | `node`, `fromPosition`, `toPosition`, `direction` |
| `CursorMeasureContext` | `node`, `position`, `textDirection`, `delegate`, `renderParagraph`, `textShift` |

All paint and move contexts include `textDirection` and `delegate` ([SelectableMixin]) for word boundary queries and other measurements.

## MoveIntention

Control how the editor handles cursor transitions. Note that **cursor position animations are not supported** due to the polling-based measurement architecture — `BlockSelectionArea` rebuilds the cursor widget every frame via post-frame callbacks, which resets any widget-level animation state. The `MoveIntention` API controls *where* the cursor moves, not how the visual transition is rendered.

```dart
// Let the editor move normally
return const MoveIntention.pass();

// Cancel the movement entirely
return const MoveIntention.cancel();
```

When `takeFullControl` is `true`, the editor skips its default movement — you're responsible for updating the selection via [EditorState].

## Limitations

- **Cursor animations are not possible.** `BlockSelectionArea` uses per-frame polling (`_updateSelectionIfNeeded` via post-frame callbacks) to measure the cursor rect, then calls `setState()` which rebuilds the widget tree. Any `AnimatedContainer` or similar widget-level animation is reset on each rebuild. Use `onCursorRectMeasured` to adjust positioning, but visual transitions between positions won't animate.
- The `renderParagraph` field in context objects is `null` when the context is created from `BlockSelectionArea` — it doesn't have direct access to the text's [RenderParagraph]. Use `ctx.delegate` to reach it if needed.

## Examples

All examples are in `example/lib/cursor_renderers/`.

```dart
import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

class RainbowSelectionRenderer extends DefaultSelectionRenderer {
  const RainbowSelectionRenderer({
    this.colors = const [
      Color(0xFF4158D0), // blue
      Color(0xFFC850C0), // pink
      Color(0xFFFFCC70), // gold
    ],
    this.duration = const Duration(seconds: 3),
    this.curve = Curves.easeInOut,
  });

  /// The gradient colors used for the animated selection highlight.
  /// Must have at least 2 colors.
  final List<Color> colors;

  /// Duration of one full gradient rotation cycle.
  final Duration duration;

  /// Easing curve for the rotation animation.
  final Curve curve;

  @override
  Widget buildSelectionHighlight(SelectionPaintContext ctx) {
    return AnimatedSelectionAreaPaint(
      rects: ctx.rects,
      colors: colors,
      duration: duration,
      curve: curve,
      withAnimation: true,
    );
  }

  @override
  Widget buildCursor(CursorPaintContext ctx) {
    // Use a thin colored cursor that matches the rainbow theme.
    return Cursor(
      rect: ctx.rect,
      color: colors.first.withValues(alpha: 0.9),
      cursorStyle: CursorStyle.verticalLine,
      shouldBlink: ctx.shouldBlink,
    );
  }
}
```
