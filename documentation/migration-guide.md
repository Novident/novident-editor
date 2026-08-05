# Migration Guide

This guide covers all breaking changes between the pre-extraction editor (monolith)
and the post-extraction architecture. Every change is listed with a before/after
example and a migration step.

---

## Dependency structure

The editor has been split into five independent packages. If your project depends
on `novident_editor` via a path dependency, update `pubspec.yaml`:

```yaml
# pubspec.yaml
dependencies:
  novident_editor:
    path: /path/to/novident-editor
  # The editor pubspec now lists its sub-packages via path as well.
  # If you publish packages independently, replace path with version constraints:
  # novident_core: ^0.1.0
  # novident_styles: ^0.1.0
  # novident_selection: ^0.1.0
  # novident_rich_text: ^0.1.0
  # novident_editor_document: ^1.0.2
```

The dependency graph is:

```
novident_document → novident_core → novident_styles → novident_selection → novident_rich_text → novident_editor
```

All five packages are re-exported from `package:novident_editor/novident_editor.dart`,
so existing imports that use the barrel continue to work. Direct imports to
editor-internal paths may break — see the import migration table below.

---

## Import migration

| Old import | New import |
|---|---|
| `import 'package:novident_editor/novident_editor.dart'` | Same (re-exports everything) |
| `.../src/core/location/position.dart` | `package:novident_core/novident_core.dart` |
| `.../src/core/location/selection.dart` | `package:novident_core/novident_core.dart` |
| `.../src/render/selection/selectable.dart` | `package:novident_core/novident_core.dart` |
| `.../src/core/style/novident_style_definition.dart` | `package:novident_styles/novident_styles.dart` |
| `.../src/core/style/novident_style_registry.dart` | `package:novident_styles/novident_styles.dart` |
| `.../src/core/style/novident_styles_config.dart` | `package:novident_styles/novident_styles.dart` |
| `.../src/core/style/novident_editor_styles.dart` | `package:novident_styles/novident_styles.dart` |
| `.../src/core/style/novident_font_provider.dart` | `package:novident_styles/novident_styles.dart` |
| `.../src/core/style/default_styles.dart` | `package:novident_styles/novident_styles.dart` |
| `.../src/core/style/novident_table_style_definition.dart` | `package:novident_styles/novident_styles.dart` |
| `.../cursor/cursor.dart` | `package:novident_selection/novident_selection.dart` |
| `.../block_selection_area.dart` | `package:novident_selection/novident_selection.dart` |
| `.../block_selection_container.dart` | `package:novident_selection/novident_selection.dart` |
| `.../rich_text/novident_rich_text.dart` | `package:novident_rich_text/novident_rich_text.dart` |
| `.../rich_text/default_selectable_mixin.dart` | `package:novident_rich_text/novident_rich_text.dart` |

---

## RichTextKeys unification

`NovidentRichTextKeys` has been removed. Use `RichTextKeys` from
`package:novident_editor_document/novident_editor_document.dart` instead.
All 14 constants have identical values and names.

```dart
// Before
import 'package:novident_editor/novident_editor.dart';
NovidentRichTextKeys.bold
NovidentRichTextKeys.italic

// After
import 'package:novident_editor_document/novident_editor_document.dart';
RichTextKeys.bold
RichTextKeys.italic
```

If you import through the editor barrel you can keep using the same import
line — the document package is re-exported.

---

## TextStyleConfiguration defaults

The `TextStyleConfiguration` constructor no longer provides a hardcoded
`text: TextStyle(fontSize: 16, color: Colors.black)` fallback. The default
is now a pure empty configuration.

```dart
// Before
const TextStyleConfiguration() // → TextStyle(fontSize: 16, color: Colors.black)

// After
const TextStyleConfiguration() // → all fields null; resolved by NovidentStyleDefinition
```

The text style is now resolved exclusively through `NovidentStyleDefinition`
and the `NovidentRichText` widget's `_buildBaseTextStyle()` method. If you
were relying on the implicit default, configure a `NovidentStylesConfig` with
a `defaultStyle` that carries your desired font size, family, and color.

---

## Vim mode

### Cursor rendering

The vim block cursor is now rendered through `VimSelectionRenderer`, passed
to `EditorStyle.desktop()` at construction time. The old approach of setting
`cursorAppearanceBuilder` on `EditorState` is removed.

```dart
// Before
final vimController = VimModeController();

NovidentEditor(
  editorState: editorState,
  commandShortcutEvents: [
    ...vimController.commandShortcutEvents,
    ...standardCommandShortcutEvents,
  ],
);

// After the editor is mounted:
vimController.attach(editorState);
// vimController.attach() used to set editorState.cursorAppearanceBuilder internally
```

```dart
// After
final vimController = VimModeController();

NovidentEditor(
  editorState: editorState,
  editorStyle: EditorStyle.desktop(
    selectionRenderer: VimSelectionRenderer(
      controller: vimController,
    ),
  ),
  commandShortcutEvents: [
    ...vimController.commandShortcutEvents,
    ...standardCommandShortcutEvents,
  ],
);

// After the editor is mounted:
vimController.attach(editorState);
```

`VimSelectionRenderer` delegates to `DefaultSelectionRenderer` in insert mode
automatically. The insert caret remains unchanged.

### Cursor style configuration

`VimCursorStyle.color` now defaults to `EditorStyle.cursorColor` instead of
a hardcoded cyan. Configure the block cursor through `VimModeConfiguration`:

```dart
final vimController = VimModeController(
  configuration: VimModeConfiguration(
    cursorStyle: VimCursorStyle(
      color: Colors.purple,
      opacity: 0.55,
      blink: false,
      blockWidth: null,            // null = auto-measure character width
      minBlockWidthFactor: 0.4,    // lower clamp × caret height
      maxBlockWidthFactor: 1.0,    // upper clamp × caret height
    ),
  ),
);
```

The style can be changed at runtime without rebuilding the editor:

```dart
vimController.configuration = vimController.configuration.copyWith(
  cursorStyle: const VimCursorStyle(blockWidth: 20, blink: true),
);
```

### attach / detach

`VimModeController.attach()` no longer mutates `editorState.editorStyle` or
`editorState.cursorAppearanceBuilder`. Callers are responsible for passing
`selectionRenderer` in `EditorStyle.desktop()`. The `attach()` method still
registers the IME interceptor and selection listener.

`VimModeController` no longer stores a `_previousCursorAppearanceBuilder`
reference — that field is removed.

---

## SelectionRenderer API

A new `SelectionRenderer` abstract class in `novident_selection` allows full
customisation of cursor and selection rendering. Configure it through
`EditorStyle.selectionRenderer`:

```dart
NovidentEditor(
  editorState: editorState,
  editorStyle: EditorStyle.desktop(
    selectionRenderer: MyCustomRenderer(),
  ),
);
```

`DefaultSelectionRenderer` replicates the standard editor behaviour exactly.
Implement `SelectionRenderer` to override any of its 20 methods (4 render,
6 movement, 2 transition, 4 lifecycle, 2 measurement, and 2 expanded-head
control). See `documentation/cursor-customization.md` for examples.

The legacy `CursorAppearanceBuilder` callback on `EditorState` is still
supported for backward compatibility — it is checked before the renderer
in the expanded-selection head path. Prefer `SelectionRenderer` for new code.

---

## BlockSelectionHost interface

`EditorState` now implements `BlockSelectionHost`. This interface decouples
`BlockSelectionArea` from the editor monolith, allowing the selection
infrastructure to work with any host:

```dart
// Before: BlockSelectionArea imported EditorState
class BlockSelectionArea extends StatefulWidget {
  final EditorState editorState;  // monolithic dependency
}

// After: BlockSelectionArea accepts any BlockSelectionHost
class BlockSelectionArea extends StatefulWidget {
  final BlockSelectionHost host;  // ~6 methods, editor-independent
}
```

If you implement custom block components, ensure your builder passes
`host: editorState` to `BlockSelectionContainer` (the existing block
components already do this).

---

## RichTextEditorConfig interface

`NovidentRichText` no longer takes an `editorState` parameter. Instead it
accepts an `editorConfig` parameter typed as `RichTextEditorConfig`:

```dart
// Before
NovidentRichText(
  editorState: editorState,
  node: node,
  delegate: this,
);

// After
NovidentRichText(
  editorConfig: editorState,   // EditorState implements RichTextEditorConfig
  node: node,
  delegate: this,
);
```

The 12 getters of `RichTextEditorConfig` cover all the properties
`NovidentRichText` needs (textScaleFactor, firstLineIndentFallback,
cursorColor, selectionColor, cursorWidth, textSpanDecorator,
textSpanOverlayBuilder, enableAutoComplete, autoCompleteTextProvider,
textStyleConfiguration, selectionNotifier, remoteSelections). All existing
block components pass `editorState` directly — no adapter needed.

---

## Painters

`SelectionAreaPainter` and `SelectionAreaPaint` now accept an optional
`minRectWidth` parameter (default 8.0) to control the width of zero-width
selection rects:

```dart
// Before
SelectionAreaPaint(rects: rects, selectionColor: color)

// After — with custom min-rect width
SelectionAreaPaint(rects: rects, selectionColor: color, minRectWidth: 12.0)
```

`AnimatedSelectionAreaPaint` now accepts `colors`, `duration`, and `curve`
parameters instead of hardcoding them:

```dart
// Before — everything hardcoded
AnimatedSelectionAreaPaint(rects: rects, withAnimation: true)

// After — fully customisable
AnimatedSelectionAreaPaint(
  rects: rects,
  withAnimation: true,
  colors: [Colors.red, Colors.orange, Colors.yellow],
  duration: const Duration(seconds: 2),
  curve: Curves.linear,
)
```

---

## Custom block components

All built-in block components (paragraph, heading, list items, quote, divider,
image, table, todo) now import from the package barrels instead of internal
editor paths. If you maintain custom block components, update these imports:

```dart
// Before
import 'package:novident_editor/src/editor/block_component/...';

// After
import 'package:novident_core/novident_core.dart';       // SelectableMixin, Position, Selection
import 'package:novident_styles/novident_styles.dart';   // StyleDefinition
import 'package:novident_selection/novident_selection.dart'; // BlockSelectionContainer, Cursor
import 'package:novident_rich_text/novident_rich_text.dart'; // NovidentRichText, DefaultSelectableMixin
```

The `blockComponentKey` constants (e.g., `ParagraphBlockKeys.type`) moved from
`lib/src/editor/block_component/base_component_keys.dart` to
`package:novident_core/novident_core.dart` (`BlockComponentKeys`).

---

## Testing

Package tests live alongside each package under `packages/*/test/`. Editor
tests remain in `test/`. Run all tests with:

```sh
flutter test test/ packages/*/test/
```

The `scripts/validate_phase.sh` and `scripts/validate_cursor.sh` utilities
have been removed. Use `dart analyze` and `flutter test` directly.
