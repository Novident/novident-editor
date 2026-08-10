# Novident Editor Styles

Named paragraph style system for the [Novident Editor](https://github.com/Novident/novident-editor).
`basedOn` inheritance chains, table styles, registry resolution, and a font provider —
usable independently of the full editor.

[![pub package](https://img.shields.io/pub/v/novident_editor_styles.svg)](https://pub.dev/packages/novident_editor_styles)

## Features

- **NovidentStyleDefinition** — named style with font family, font size, weight,
  italic, underline, spacing (before/after/line-height), indentation, alignment,
  colour, and more. Supports `basedOn` inheritance and `next` (auto-style for the
  following paragraph).
- **Style registry** — `NovidentStyleRegistry` resolves `basedOn` chains (with
  cycle detection via a configurable `onWarning` callback). `copyWith()` for
  immutable updates.
- **StylesConfig** — `NovidentStylesConfig` pairs a registry with a `defaultStyle`
  and `defaultStylesByType` map (e.g. `'paragraph' → body`, `'heading' → heading-1`).
- **EditorStyles (InheritedWidget)** — `NovidentEditorStyles` exposes the resolved
  style for any node through `maybeOf(context)?.resolveStyle(node)`.
- **Table styles** — `NovidentTableStyleDefinition` with zebra striping, coloured
  headers, border colours, width, weight-based column layout, and row-level overrides
  (`NovidentTableRowStyle`).
- **BlockStyleResolver** — resolves the effective `NovidentStyleDefinition` for a
  node by checking its `styleRef` attribute, then the type-based default, then the
  global default.
- **FontProvider** — `NovidentFontProvider` supplies the list of available font
  families and a guaranteed non-null default font. Customisable via
  `NovidentFontProvider.fromList()`.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  novident_editor_styles: <latest>
```

## Usage

### Define named styles

```dart
import 'package:novident_editor_styles/novident_editor_styles.dart';

final registry = NovidentStyleRegistry({
  'base': NovidentStyleDefinition(
    id: 'base',
    name: 'Base',
    fontSize: 12,
    fontFamily: 'Arial',
    textColor: Colors.black,
    indent: NovidentStyleIndent.defaultLineFilter(),
  ),
  'body': NovidentStyleDefinition.nextSame(
    id: 'body',
    name: 'Body',
    basedOn: 'base',
    spacing: NovidentStyleSpacing(after: 8),
  ),
  'heading-1': NovidentStyleDefinition(
    id: 'heading-1',
    name: 'Heading 1',
    basedOn: 'base',
    fontSize: 32,
    bold: true,
    spacing: NovidentStyleSpacing(before: 24, after: 12),
    next: 'body',
  ),
});

final config = NovidentStylesConfig(
  registry: registry,
  defaultStyle: /* your base style */,
  defaultStylesByType: {
    'paragraph': /* body style */,
    'heading': /* heading-1 style */,
  },
);
```

### Resolve a style for a node

```dart
final resolver = NovidentBlockStyleResolver(config);
final style = resolver.resolveStyle(node); // walks basedOn chain
```

### Table styles

```dart
final tableStyle = NovidentTableStyleDefinition(
  defaultRowStyle: NovidentTableRowStyle(
    backgroundColor: Colors.white,
    borderColor: Colors.grey.shade300,
  ),
  headerStyle: NovidentTableRowStyle(
    backgroundColor: Colors.blue.shade50,
    bold: true,
  ),
  zebraStripe: true,
  zebraStripeColor: Colors.grey.shade100,
  borderWidth: 1.0,
);
```

### Font provider

```dart
// During debug, you can use these methods to get standard fonts
// filtered by the platform
final fontProvider = NovidentFontProvider.fromList(
  getDefaultFonts(),
  defaultFamily: getDefaultFont(),
);

final resolvedFont = fontProvider.resolve('NonExistentFont');
// → 'Arial' (the guaranteed non-null fallback)
```

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0

This package is extracted from [novident_editor](https://pub.dev/packages/novident_editor)
(the full rich-text editor widget). Use it to build style configuration UIs, document
previews, or any tool that needs to resolve paragraph styles without the full editor.
