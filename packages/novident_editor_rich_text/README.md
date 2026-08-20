# Novident Editor Rich Text

Paragraph rendering widget for the [Novident Editor](https://github.com/Novident/novident-editor).
`NovidentRichText`, `DefaultSelectableMixin`, and abstract configuration interfaces.

[![pub package](https://img.shields.io/pub/v/novident_editor_rich_text.svg)](https://pub.dev/packages/novident_editor_rich_text)

## Features

- **NovidentRichText** — the primary paragraph-rendering widget. Renders `RichText`
  from node deltas, resolves styles through `NovidentEditorStyles.maybeOf()`, and
  provides cursor/selection rect measurements via `SelectableMixin`.
- **DefaultSelectableMixin** — proxy mixin that wraps a forward `SelectableMixin`
  with coordinate offset shifting (used by list items, quotes, and nested blocks).
- **RichTextEditorConfig** — abstract interface (12 getters) that replaces the
  `EditorState` dependency. Any object implementing this interface can drive
  `NovidentRichText`.
- **RichTextAttributes** — extension on `Attributes` for reading delta formatting
  (bold, italic, underline, strikethrough, colour, background, href, font family,
  font size, code, auto-complete).
- **Span pipeline** — every span is produced through a replaceable 6-phase
  `NovidentTextSpanPipeline`; `DefaultNovidentTextSpanPipeline` reproduces the
  built-in behavior and can be extended per phase (e.g. spell-check marks).
- **Lightweight** — depends only on `novident_editor_document`, `novident_editor_core`,
  `novident_editor_styles`, `novident_editor_selection`, and Flutter. No editor
  services or infrastructure.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  novident_editor_rich_text: <latest>
```

## Usage

### Basic paragraph

```dart
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';

NovidentRichText(
  node: paragraphNode,
  delegate: this,               // your SelectableMixin
  editorConfig: myConfig,       // implements RichTextEditorConfig
);
```

### Implementing RichTextEditorConfig

```dart
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';

class MyConfig implements RichTextEditorConfig {
  @override double get textScaleFactor => 1.0;
  @override double? get firstLineIndentFallback => null;
  @override Color get cursorColor => Colors.black;
  @override Color get selectionColor => Colors.blue.withValues(alpha: 0.2);
  @override double get cursorWidth => 2.0;
  @override TextSpanDecoratorForAttribute? get textSpanDecorator => null;
  @override NovidentTextSpanOverlayBuilder? get textSpanOverlayBuilder => null;
  @override bool get enableAutoComplete => false;
  @override NovidentAutoCompleteTextProvider? get autoCompleteTextProvider => null;
  @override TextStyleConfiguration get textStyleConfiguration => const TextStyleConfiguration();
}
```

### Custom span pipeline

`NovidentRichText` delegates every per-span decision to a pipeline of six
phases, each receiving an immutable context:

```
resolveStyle → transformText → emitSpans → paintSelectionContrast
             → buildPlaceholder → adjustSpan
```

`DefaultNovidentTextSpanPipeline` implements all of them with the built-in
behavior. Extend it to add decorations without forking the widget — for
example, underlining delta ranges marked by an attribute (the pattern used
for spell-check marks in the main editor):

```dart
class MarkedWordPipeline extends DefaultNovidentTextSpanPipeline {
  MarkedWordPipeline({required this.markStyle});

  final TextStyle markStyle; // e.g. red wavy underline

  @override
  List<InlineSpan> emitSpans(SpanEmitContext ctx) {
    final marked = ctx.insert.attributes?['proofState'] == 'err';
    if (!marked) {
      return super.emitSpans(ctx);
    }
    // Split ctx into sub-segments and merge markStyle onto the marked ones.
    // Keep the offsets/textShift intact so caret math is unaffected.
    return emitWithStyle(ctx, markStyle);
  }
}
```

Plug it through the widget or the configuration:

```dart
NovidentRichText(
  node: paragraphNode,
  delegate: this,
  editorConfig: myConfig,
  spanPipeline: MarkedWordPipeline(
    markStyle: const TextStyle(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationColor: Colors.red,
    ),
  ),
);

// or globally:
class MyConfig implements RichTextEditorConfig {
  @override
  NovidentTextSpanPipeline? get spanPipeline => MarkedWordPipeline(...);
  // ...
}
```

Resolution order: `NovidentRichText.spanPipeline` →
`RichTextEditorConfig.spanPipeline` → `DefaultNovidentTextSpanPipeline`. The
pipeline runs on every rebuild, so it must stay cheap: the recommended pattern
is to read pre-computed attributes from the delta (as above) rather than
calling external services from `build`.

### DefaultSelectableMixin

```dart
class _MyListItemState extends State<MyListItem>
    with SelectableMixin<MyListItem>, DefaultSelectableMixin<MyListItem> {

  @override
  SelectableMixin<MyListItem> get forward =>
      forwardKey.currentState as SelectableMixin<MyListItem>;

  @override
  double baseOffset() => 24.0; // bullet/number width

  // All SelectableMixin methods are delegated to `forward` with
  // coordinate offset adjustment.
}
```

### RichTextAttributes

```dart
final attrs = node.delta?.first.attributes ?? {};
print(attrs.bold);        // true / false / null
print(attrs.italic);
print(attrs.textColor);   // '#000000'
print(attrs.fontSize);    // 12.0
print(attrs.href);        // 'https://example.com'
```

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0

This package is extracted from [novident_editor](https://pub.dev/packages/novident_editor)
(the full rich-text editor widget). Use it to render rich-text paragraphs in document
previews, export tools, or any surface that needs paragraph-level text rendering
without the full editor infrastructure.
