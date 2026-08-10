# Novident Editor Core

Core types and selection protocol for the [Novident Editor](https://github.com/Novident/novident-editor).
Position, Selection, SelectableMixin, and shared extensions — usable independently
of the full editor in any Dart or Flutter project.

[![pub package](https://img.shields.io/pub/v/novident_editor_core.svg)](https://pub.dev/packages/novident_editor_core)

## Features

- **Position and Selection** — lightweight location types (`Position`, `Selection`)
  with path-based addressing, normalisation, collapse, and JSON serialisation.
- **SelectableMixin** — the protocol contract for every block component. Declares
  cursor rect measurement, selection rect calculation, word boundaries, vertical/horizontal
  movement, and text direction.
- **CursorStyle** — enum (`verticalLine`, `borderLine`, `cover`) describing how
  the caret is rendered.
- **TextStyleConfiguration** — neutral, editor-independent description of text style
  attributes (bold, italic, underline, strikethrough, code, href, font size, etc.).
- **RemoteSelection** — data class for collaborative cursors: id, selection, colours.
- **Extensions** — `ColorExtension.tryToColor()`, `TextStyleExtensions.combine()`,
  `TextSpanExtensions.copyWith()`, `PathSelectionExtension.inSelection()`,
  `NodeSelectionExtension.findParent()`.
- **BlockComponentKeys** — 13 key constants for built-in block types, shared across
  the editor and all packages.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  novident_editor_core: <latest>
```

## Usage

### Platform 

```dart
import 'package:novident_editor_core/novident_editor_core.dart';

/// Returns true if the operating system is macOS and not running on Web platform.
final isMacOS = UniversalPlatform.isMacOS; 

/// Returns true if the operating system is macOS and running on Web platform.
final isWebOnMacOS = UniversalPlatform.isWebOnMacOS; 

final isDesktopOrWeb = UniversalPlatform.isDesktopOrWeb; 
```

### Position and Selection

```dart
import 'package:novident_editor_core/novident_editor_core.dart';

final start = Position(path: [0, 1], offset: 5, id: null);
final end = Position(path: [0, 1], offset: 12, id: null);

final collapsed = Selection.collapsed(start);
final range = Selection(start: start, end: end);

final normalised = range.normalized;   // start ≤ end
final isCollapsed = range.isCollapsed; // false
final head = range.end;                // moving head
```

### SelectableMixin

```dart
class MyBlock extends StatefulWidget {
  @override State<MyBlock> createState() => _MyBlockState();
}

class _MyBlockState extends State<MyBlock> with SelectableMixin<MyBlock> {
  @override
  Rect? getCursorRectInPosition(Position position) {
    // Return the pixel rect for the cursor at this position.
  }

  @override
  List<Rect> getRectsInSelection(Selection selection) {
    // Return paint rectangles for a text selection range.
  }

  @override
  Position? getWordBoundaryInPosition(Position position) {
    // Return the word boundary enclosing this position.
  }

  // ... 16 more methods
}
```

### TextStyleConfiguration

```dart
const config = TextStyleConfiguration(
  bold: true,
  italic: false,
  underline: false,
  strikethrough: false,
  code: false,
  href: null,
  fontSize: null,
);
```

### Extensions

```dart
// Color parsing
final color = '#FF5733'.tryToColor();
final hex = color?.toHex();

// Path selection check
final path = [0, 1];
final inside = path.inSelection(selection);           // true if path is within selection
final sameDepth = path.inSelection(selection, isSameDepth: true);

// Node tree navigation
final parent = node.findParent('heading');            // walk up to find a heading ancestor
final inTree = node.inSelection(selection);
```

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0

This package is extracted from [novident_editor](https://pub.dev/packages/novident_editor)
(the full rich-text editor widget) so you can use the core types and selection protocol
without pulling in the entire editor dependency tree.
