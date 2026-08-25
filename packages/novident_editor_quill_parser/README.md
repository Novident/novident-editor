# Novident Editor Quill Parser

Bidirectional conversion between the Quill Delta format and the [Novident Editor](https://github.com/Novident/novident-editor)
document model — encode documents to Quill Delta and decode Quill Delta back to documents. Usable independently of the full editor.

[![pub package](https://img.shields.io/pub/v/novident_editor_quill_parser.svg)](https://pub.dev/packages/novident_editor_quill_parser)

## Features

- **Two directions** — `QuillDeltaFromNovident` encodes a novident `Document` into a flat
  Quill Delta; `QuillDeltaToNovident` decodes a Quill Delta back into a `Document`.
- **Block types** — paragraph, heading (levels 1–6), quote, bulleted list, numbered list,
  todo list (checked/unchecked), and image embeds.
- **Nested lists** — flat Quill `indent` levels are reconstructed into a nested node tree.
- **Inline formatting** — bold, italic, underline, strikethrough, inline code, links,
  text/background colour, font family, and font size.
- **Colour conversion** — novident hex colours (`0xAARRGGBB`) are converted to Quill
  colours (`#RRGGBB` / `rgba(...)`) and back.
- **AST-based parsing** — the decoder uses `flutter_quill_delta_easy_parser` to turn the
  delta into an easily-consumable AST before mapping it to nodes.
- **Extensible** — register custom converters for custom block types and embeds via
  constructor maps, or subclass and override `converterFor` for full control.
- **Linear-time** — both directions scale linearly with document size; large documents
  are converted without quadratic blow-up.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  novident_editor_quill_parser: <latest>
```

## Usage

### Encode a document to Quill Delta

```dart
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

final document = Document.fromJson({
  'document': {
    'type': 'page',
    'children': [
      {
        'type': 'heading',
        'data': {
          'delta': [
            {'insert': 'Title'}
          ],
          'level': 1,
        },
      },
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': 'Hello, World!'}
          ]
        },
      },
    ],
  },
});

final delta = QuillDeltaFromNovident().fromDocument(document);
// => [
//      {'insert': 'Title'},
//      {'insert': '\n', 'attributes': {'header': 1}},
//      {'insert': 'Hello, World!'},
//      {'insert': '\n'},
//    ]
```

### Decode Quill Delta to a document

```dart
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

final decoder = QuillDeltaToNovident();

final document = decoder.fromJson([
  {'insert': 'Hello'},
  {'insert': '\n'},
  {
    'insert': 'World',
    'attributes': {'bold': true},
  },
  {'insert': '\n'},
]);
```

When you already hold a `dart_quill_delta.Delta`, pass it to `convert` instead:

```dart
final document = QuillDeltaToNovident().convert(delta);
```

### Round-trip

Encoding and decoding are inverse operations, so a document survives a full
round-trip without losing structure:

```dart
final original = /* a novident Document */;
final delta = QuillDeltaFromNovident().fromDocument(original);
final restored = QuillDeltaToNovident().convert(delta);
```

### Custom blocks (encode)

Register a converter for a node type the built-ins don't know about:

```dart
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

class CustomBlockToDelta extends NodeToQuill {
  @override
  List<Operation> toQuill(Node node, {Map<String, dynamic>? extra}) {
    return [
      Operation.insert({'my_custom': node.attributes['value']}),
      Operation.insert('\n'),
    ];
  }

  @override
  bool validate(Node node) => node.type == 'my_custom_block';
}

final encoder = QuillDeltaFromNovident(
  converters: {'my_custom_block': CustomBlockToDelta()},
);
```

Or subclass and override `converterFor` for full control over resolution.

### Custom embeds (decode)

Register a converter for an embed the built-ins don't handle:

```dart
import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

class CustomEmbedToNode extends DeltaToNode {
  @override
  List<Node> toNodes(Paragraph paragraph) {
    final embed = paragraph.lines.first.fragments.first.getEmbedValue();
    return [
      Node(
        type: 'my_custom_block',
        attributes: {'value': embed['my_custom']},
      ),
    ];
  }
}

final decoder = QuillDeltaToNovident(
  embedConverters: {'my_custom': CustomEmbedToNode()},
);
```

## Limitations & lossy conversions

The Quill Delta format is a flat list of text/embed operations, while Novident
splits content into a tree of typed nodes. Not everything survives a conversion
in both directions. Where a value has no equivalent on the other side it is
dropped or, when there is no sensible mapping at all, the converter throws
[`UnsupportedError`]. The following lists are the known gaps to design around.

### Node → Delta

- **Unsupported block types** — `table`, `table/cell`, `divider`, `columns` and
  `column` have no standard Quill Delta representation and throw
  [`UnsupportedError`]. Register a custom `NodeToQuill` if you need them.
- **Block-level attributes dropped** — `bgColor` (block background) and
  `styleRef` (named style) are not emitted; only `align` and `textDirection`
  map to Quill block attributes.
- **Ordered-list start number** — `NumberedListBlockKeys.number` has no Quill
  Delta equivalent and is dropped.
- **Image alignment** — novident stores image alignment as `align`; Quill uses a
  CSS `style` string. Only `url`, `width` and `height` are preserved.
- **Editor-internal inline attributes dropped** — `proofState` (spell-check
  marks), `find_bg_color`, `auto_complete` and `transparent` are discarded.

### Delta → Node

- **`code-block`** — there is no code-block node type in Novident; it falls back
  to a plain paragraph, losing the code formatting.
- **Non-image embeds** — `video` and any other embed object throw
  [`UnsupportedError`]; register a custom `DeltaToNode` to handle them.
- **Indented non-list blocks** — an `indent` without a `list` is ignored
  (Novident only nests lists).
- **Named font sizes** — Quill `size` values like `small`/`large`/`huge` are kept
  as a raw string because Novident's `font_size` is numeric.
- **Image CSS style** — the Quill `style` string is not reconstructed into
  `align`/`width`/`height`; `align: justify` is also passed through verbatim.
- **Trailing empty paragraph** — Novident has no "empty final paragraph" concept,
  so the terminating `\n` is trimmed and a document consisting solely of one
  empty paragraph decodes to an empty document.

### Both directions

- **Node ids are not preserved** — every conversion regenerates node ids; only
  structure and content round-trip, not identity.
- **Colour alpha** — `rgba(...)` with partial alpha is converted to the nearest
  8-bit alpha when round-tripped through novident's `0xAARRGGBB` encoding.
- **Unknown attributes** — any attribute key not listed above (inline or block)
  is silently dropped rather than preserved.

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0 (same as the main editor)

This package is extracted from [novident_editor](https://pub.dev/packages/novident_editor)
(the full rich-text editor widget). Use it to import/export documents through the Quill
Delta format — in sync engines, file importers, or any surface that exchanges rich text —
without pulling in the entire editor dependency tree.
