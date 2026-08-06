# Novident Editor Selection

Selection and cursor rendering infrastructure for the [Novident Editor](https://github.com/Novident/novident-editor).
Cursor widget, block selection areas, remote selections, and the `SelectionRenderer` API.

[![pub package](https://img.shields.io/pub/v/novident_editor_selection.svg)](https://pub.dev/packages/novident_editor_selection)

## Features

- **Cursor widget** — `Cursor` with three styles (`verticalLine`, `borderLine`, `cover`)
  and configurable blink timer.
- **BlockSelectionArea** — stateful widget that measures and paints the cursor and
  selection highlights for a single block node. Polls selection rects in post-frame
  callbacks for zero-lag rendering.
- **BlockSelectionContainer** — `Stack`-based layout that layers selection highlights,
  block content, cursor, and remote selections in the correct z-order.
- **RemoteBlockSelectionsArea** — renders collaborative cursors and selections from
  `RemoteSelection` data.
- **SelectionAreaPaint** — `CustomPaint`-backed widget that fills a list of `Rect`s
  with a configurable colour. Accepts `minRectWidth` for zero-width rects.
- **AnimatedSelectionAreaPaint** — rotating gradient selection highlight with
  configurable colours, duration, and curve.
- **SelectionRenderer API** — 20-method abstract class for full cursor/selection
  customisation. Override render, movement, transition, lifecycle, and measurement
  behaviour.
- **BlockSelectionHost** — abstract interface (6 methods) that decouples selection
  rendering from the editor monolith. Any object implementing this interface can
  host a `BlockSelectionArea`.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  novident_editor_selection: <latest>
```

## Usage

### Cursor widget

```dart
import 'package:novident_editor_selection/novident_editor_selection.dart';

Cursor(
  rect: Rect.fromLTWH(100, 50, 2, 20),
  color: Colors.black,
  cursorStyle: CursorStyle.verticalLine,
  shouldBlink: true,
);
```

### Selection highlight

```dart
SelectionAreaPaint(
  rects: [Rect.fromLTWH(100, 50, 80, 20)],
  selectionColor: const Color(0x33448AFF),
  minRectWidth: 8.0,  // used when rect.width ≤ 0
);
```

### Animated gradient selection

```dart
AnimatedSelectionAreaPaint(
  rects: rects,
  withAnimation: true,
  colors: const [Colors.purple, Colors.pink, Colors.amber],
  duration: const Duration(seconds: 3),
  curve: Curves.easeInOut,
);
```

### Block selection rendering

```dart
BlockSelectionContainer(
  node: node,
  delegate: this,           // SelectableMixin
  listenable: selectionNotifier,
  host: editorState,        // implements BlockSelectionHost
  cursorColor: Colors.black,
  selectionColor: Colors.blue.withValues(alpha: 0.2),
  blockColor: Colors.blue.withValues(alpha: 0.1),
  supportTypes: const [
    BlockSelectionType.cursor,
    BlockSelectionType.selection,
    BlockSelectionType.block,
  ],
  child: myBlockContent,
);
```

### Custom SelectionRenderer

```dart
class MyRenderer extends DefaultSelectionRenderer {
  @override
  Widget buildCursor(CursorPaintContext ctx) {
    return Container(
      width: 4,
      height: ctx.rect.height,
      color: Colors.red,
    );
  }

  @override
  Widget buildSelectionHighlight(SelectionPaintContext ctx) {
    return AnimatedSelectionAreaPaint(
      rects: ctx.rects,
      withAnimation: true,
      colors: const [Colors.orange, Colors.red],
    );
  }
}

// Configure via EditorStyle:
EditorStyle.desktop(selectionRenderer: MyRenderer());
```

### BlockSelectionHost implementation

```dart
class MyHost implements BlockSelectionHost {
  @override bool isBlockSelectionMode() => false;

  @override CursorAppearance? customizeCursor({
    required Node node,
    required Selection? selection,
    required Position position,
  }) => null;

  @override EdgeInsets? blockSelectionMargin(Node node) => null;

  @override String? selectionDragModeValue() => null;

  @override SelectionRenderer? get selectionRenderer => myRenderer;
}
```

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0

This package is extracted from [novident_editor](https://pub.dev/packages/novident_editor)
(the full rich-text editor widget). Use it to render cursors and selections on any
surface that works with `Node`, `Position`, and `SelectableMixin`.
