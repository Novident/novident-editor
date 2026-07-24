# Novident Editor Document

Core document model for the [Novident Editor](https://github.com/Novident/novident-editor) —
tree nodes, rich-text deltas, paths, and attributes. Usable independently of the full
editor in any Dart or Flutter project.

[![pub package](https://img.shields.io/pub/v/novident_document.svg)](https://pub.dev/packages/novident_document)

## Features

- **Tree-structured document** — `Document` with `Node` children, insert/delete/update
  operations by path.
- **Rich-text Delta** — Quill-inspired `Delta` format: compose, diff, invert, and
  serialize text changes with formatting attributes.
- **Typed attributes** — `Attributes` (map-based) with compose, invert, and diff helpers.
- **Position paths** — `Path` (list of ints) with comparison operators, parent/child
  navigation, and ancestor checks.
- **Node iterator** — depth-first traversal in visual order.
- **JSON serialization** — full `toJson()`/`fromJson()` round-trip for documents,
  nodes, and deltas.
- **Minimal Flutter dependency** — only `package:flutter/foundation.dart` for
  equality helpers and `material.dart` for `ChangeNotifier` on `Node`.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  novident_editor_document: <latest>
```

## Usage

### Create a document

```dart
import 'package:novident_editor_document/novident_editor_document.dart';

// Blank document
final doc = Document.blank();

// With an empty paragraph
final doc = Document.blank(withInitialText: true);

// From JSON
final doc = Document.fromJson({
  'document': {
    'type': 'page',
    'children': [
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': 'Hello, World!'}
          ]
        }
      }
    ]
  }
});
```

### Manipulate the node tree

```dart
final doc = Document.blank();

// Insert nodes at a path
final paragraph = Node(
  type: 'paragraph',
  attributes: {'delta': (Delta()..insert('Hello')).toJson()},
);
doc.insert([0], [paragraph]);

// Update attributes
doc.update([0], {'align': 'center'});

// Delete nodes
doc.delete([0], 1);

// Traverse
final firstNode = doc.first;
final lastNode = doc.last;
final node = doc.nodeAtPath([0, 1]);
```

### Work with rich-text Deltas

```dart
final delta = Delta()
  ..insert('Gandalf', attributes: {'bold': true})
  ..insert(' the ')
  ..insert('Grey', attributes: {'color': '#ccc'});

// Compose changes
final change = Delta()
  ..retain(12)
  ..insert('White', attributes: {'color': '#fff'})
  ..delete(4);

final result = delta.compose(change);
print(result.toPlainText()); // "Gandalf the White"

// Serialize
final json = delta.toJson();
final restored = Delta.fromJson(json);
```

### Attributes helpers

```dart
final base = {'bold': true, 'italic': false};
final other = {'italic': true, 'color': 'red'};

final composed = composeAttributes(base, other);
// => {'bold': true, 'italic': true, 'color': 'red'}

final diff = diffAttributes(base, composed);
// => {'italic': true, 'color': 'red'}
```

### Path navigation

```dart
final path = [0, 2, 1];

final parent = path.parent;    // [0, 2]
final next = path.next;        // [0, 2, 2]
final previous = path.previous; // [0, 2, 0]
final isAncestor = parent.isAncestorOf(path); // true
```

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0 (same as the main editor)

This package is extracted from [novident_editor](https://pub.dev/packages/novident_editor)
(the full rich-text editor widget) so you can use the document model without pulling in the
entire editor dependency tree.
