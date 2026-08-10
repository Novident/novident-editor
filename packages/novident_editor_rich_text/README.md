# Novident Editor Rich Text

Paragraph rendering widget for the [Novident Editor](https://github.com/Novident/novident-editor).
`NovidentRichText`, `DefaultSelectableMixin`, and abstract configuration interfaces.

[![pub package](https://img.shields.io/pub/v/novident_editor_rich_text.svg)](https://pub.dev/packages/novident_editor_rich_text)

## Features

- **NovidentRichText** — the primary paragraph-rendering widget. Renders `RichText`
  from node `TextDocument`, resolves styles through `NovidentEditorStyles.maybeOf()`, and
  provides cursor/selection rect measurements via `SelectableMixin`.
- **DefaultSelectableMixin** — proxy mixin that wraps a forward `SelectableMixin`
  with coordinate offset shifting (used by list items, quotes, and nested blocks).
- **RichTextEditorConfig** — abstract interface (12 getters) that replaces the
  `EditorState` dependency. Any object implementing this interface can drive
  `NovidentRichText`.
- **RichTextAttributes** — extension on `Attributes` for reading delta/text-doc formatting
  (bold, italic, underline, strikethrough, colour, background, href, font family,
  font size, code, auto-complete).
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
final attrs = node.textDocument?.attributesAt(0) ?? {};
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
