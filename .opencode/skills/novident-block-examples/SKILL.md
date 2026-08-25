---
name: novident-block-examples
description: >-
  Create example content for the Novident Editor (Flutter rich-text editor,
  fork of AppFlowy Editor) — any supported block, in both its JSON document
  form and its Dart node-factory form. Use this skill whenever the user asks
  to generate, show, or explain examples of editor blocks (paragraph, heading,
  bulleted/numbered/todo list, quote, image, divider, table, columns), to
  build a sample document, to write Dart code that constructs nodes via the
  factory methods (paragraphNode, headingNode, TableNode.fromList, …), or to
  produce the JSON that a Novident document is stored/loaded as. It is
  self-contained: it documents every block type, its JSON shape, its factory
  signature, and how to assemble a Document and apply it through an
  EditorState transaction, so you do NOT need to search the codebase. Trigger
  even if the user only says "create an example of a table" or "show me a
  todo list block" without naming the editor or the library.
---

# Novident Editor — Block Examples

This skill lets you produce example content for the **Novident Editor**, a
Flutter rich-text editor forked from AppFlowy Editor. For any supported block
you can emit **two equivalent forms**:

1. **JSON** — the serialized document shape (what `Document.toJson()` produces
   and `Document.fromJson()` consumes).
2. **Dart node-factory** — the idiomatic way to build the same node in code
   using the public factory functions (e.g. `paragraphNode(...)`).

Everything you need is documented here. **Do not search the codebase** — the
full reference is below. If you are asked for a block not listed here, say so
and ask which custom block they mean.

---

## 1. The mental model (three layers)

```
Document      →  a tree of Node objects rooted at a `page` node. Pure data.
EditorState   →  the single mutable state (document + selection + services).
NovidentEditor→  the widget that renders the document.
```

- A **`Node`** is one block. It has three parts:
  - `type` — a string key that selects which block component renders it
    (e.g. `'paragraph'`, `'heading'`, `'table'`).
  - `attributes` — a `Map<String, Object>` of node-level data. Rich text
    lives in the `delta` attribute; other attributes drive block behavior
    (alignment, indentation, heading level, checked state…).
  - `children` — a list of child `Node`s (for nesting: lists, table cells,
    columns).
- **Rich text** is a Quill-style **`Delta`** (a list of insert/retain/delete
  operations with optional inline attributes) stored in the node's `delta`
  attribute. It is the single source of truth for text and inline formatting
  (bold, italic, color, links…).
- **All mutations flow through `EditorState.apply(Transaction)`.** Direct
  document mutation is possible but bypasses undo/redo and selection updates.

---

## 2. The JSON document format

A `Document` serializes to:

```json
{
  "document": {
    "type": "page",
    "children": [
      { "type": "paragraph", "data": { "delta": [ { "insert": "Hello" } ] } }
    ]
  }
}
```

A single `Node` serializes to:

```json
{
  "type": "paragraph",
  "data": { "delta": [ { "insert": "Hello" } ] },
  "children": []
}
```

Rules:
- `type` is always present.
- `data` holds the node's **attributes** map. It is omitted when empty.
- `children` is omitted when empty.
- The rich-text content is the `delta` attribute: a JSON array of Quill ops.
- `Node.fromJson` reads `type`, `data`, and `children`; `Document.fromJson`
  expects the outer `{ "document": { ... } }` wrapper.

### Delta (rich text) format

A delta is a list of operations. Each op is one of:

| Op | JSON | Meaning |
|---|---|---|
| Insert | `{ "insert": "text", "attributes": {…} }` | insert text (with optional inline formatting) |
| Retain | `{ "retain": 5, "attributes": {…} }` | keep N chars (optionally change formatting) |
| Delete | `{ "delete": 3 }` | delete N chars |

**Inline formatting attribute keys** (go inside `attributes` of an insert):

| Key | Value | Meaning |
|---|---|---|
| `bold` | `true` | bold |
| `italic` | `true` | italic |
| `underline` | `true` | underline |
| `strikethrough` | `true` | strikethrough |
| `font_color` | hex string | text color |
| `bg_color` | hex string | background color |
| `code` | `true` | inline code |
| `href` | url string | hyperlink |
| `font_family` | string | font family |
| `font_size` | number | font size |

Example delta with mixed formatting:

```json
"delta": [
  { "insert": "Hello " },
  { "insert": "bold", "attributes": { "bold": true } },
  { "insert": " and " },
  { "insert": "link", "attributes": { "href": "https://example.com" } }
]
```

### Block-level attribute keys

These live in the node's `data` map (alongside `delta`):

| Key | Value | Meaning |
|---|---|---|
| `textDirection` | `"ltr"` / `"rtl"` / `"auto"` | text direction (text blocks only) |
| `align` | `"left"` / `"right"` / `"center"` | block alignment |
| `styleRef` | string | reference to a named `NovidentStyleDefinition` |
| `bgColor` | hex string | block background color |

---

## 3. The Dart node-factory methods

Every standard block has a public factory function that returns a `Node`.
They live in `lib/src/editor/block_component/<type>_block_component/` and are
re-exported from the public barrel `package:novident_editor/novident_editor.dart`.
**Use these factories — never construct a raw `Node(type: …)` by hand** for
standard blocks; the factories set the correct type string and attributes.

The root of every document is a `page` node built with `pageNode(...)`.

### Reference table

| Block | Type string | Factory | Required / notable params |
|---|---|---|---|
| Page (root) | `page` | `pageNode({required Iterable<Node> children, Attributes attributes})` | `children` |
| Paragraph | `paragraph` | `paragraphNode({text, delta, textDirection, attributes, styleRef, children})` | `text` **or** `delta` |
| Heading | `heading` | `headingNode({required int level, text, delta, textDirection, attributes, styleRef})` | `level` (1–6) |
| Bulleted list | `bulleted_list` | `bulletedListNode({text, delta, textDirection, attributes, styleRef, children})` | `text` **or** `delta` |
| Numbered list | `numbered_list` | `numberedListNode({delta, attributes, number, textDirection, styleRef, children})` | — |
| Todo list | `todo_list` | `todoListNode({required bool checked, text, delta, textDirection, attributes, styleRef, children})` | `checked` |
| Quote | `quote` | `quoteNode({delta, textDirection, attributes, styleRef, children})` | — |
| Image | `image` | `imageNode({required String url, align = 'center', height, width, styleRef})` | `url` |
| Divider | `divider` | `dividerNode({styleRef})` | — |
| Table | `table` | `TableNode.fromList(cols, {styleRef})` / `TableNode.fromNodes(cols, {styleRef})` | grid of strings / nodes |
| Table cell | `table/cell` | `tableCellNode({required rowPosition, required colPosition, required child, …})` | positions + child |
| Columns | `columns` | `columnsNode({children})` | — |
| Column | `column` | `columnNode({children, width})` | — |

Notes:
- `text` is a convenience that builds a delta with a single plain insert.
  Pass `delta:` instead when you need inline formatting.
- `styleRef` applies a named style; `textDirection` and `attributes` are
  optional extras merged into the node's attribute map.
- `children` lets you nest blocks (list items, table cells, columns).

---

## 4. Per-block examples (JSON + Dart)

### Page (root)

```json
{ "type": "page", "children": [] }
```

```dart
pageNode(children: [ /* blocks */ ])
```

### Paragraph

```json
{
  "type": "paragraph",
  "data": { "delta": [ { "insert": "Hello world" } ] }
}
```

```dart
paragraphNode(text: 'Hello world')
```

With inline formatting:

```json
{
  "type": "paragraph",
  "data": {
    "delta": [
      { "insert": "Hello " },
      { "insert": "world", "attributes": { "bold": true, "italic": true } }
    ]
  }
}
```

```dart
paragraphNode(
  delta: Delta()
    ..insert('Hello ')
    ..insert('world', attributes: {'bold': true, 'italic': true}),
)
```

### Heading

```json
{
  "type": "heading",
  "data": {
    "delta": [ { "insert": "Chapter One" } ],
    "level": 1
  }
}
```

```dart
headingNode(level: 1, text: 'Chapter One')
```

`level` must be 1–6 (the factory clamps it).

### Bulleted list

```json
{
  "type": "bulleted_list",
  "data": { "delta": [ { "insert": "First item" } ] }
}
```

```dart
bulletedListNode(text: 'First item')
```

Nested list (children become sub-items):

```dart
bulletedListNode(
  text: 'Parent',
  children: [bulletedListNode(text: 'Child')],
)
```

### Numbered list

```json
{
  "type": "numbered_list",
  "data": { "delta": [ { "insert": "Step one" } ] }
}
```

```dart
numberedListNode(delta: Delta()..insert('Step one'))
```

An optional `number` attribute sets the starting number:

```dart
numberedListNode(delta: Delta()..insert('Start at 5'), number: 5)
```

### Todo list

```json
{
  "type": "todo_list",
  "data": {
    "delta": [ { "insert": "Buy milk" } ],
    "checked": false
  }
}
```

```dart
todoListNode(checked: false, text: 'Buy milk')
```

### Quote

```json
{
  "type": "quote",
  "data": { "delta": [ { "insert": "To be or not to be" } ] }
}
```

```dart
quoteNode(delta: Delta()..insert('To be or not to be'))
```

### Image

```json
{
  "type": "image",
  "data": {
    "url": "https://example.com/pic.png",
    "align": "center",
    "width": 400,
    "height": 300
  }
}
```

```dart
imageNode(url: 'https://example.com/pic.png', align: 'center', width: 400, height: 300)
```

`align` is one of `left` / `center` / `right` (default `center`).

### Divider

```json
{ "type": "divider" }
```

```dart
dividerNode()
```

### Table

A table is a `table` node whose children are `table/cell` nodes, each cell
containing a content node (usually a paragraph). The idiomatic builders are
`TableNode.fromList` (grid of plain strings) and `TableNode.fromNodes` (grid
of any nodes). **Column-major order**: the outer list is columns, each inner
list is the rows of that column.

`TableNode.fromList`:

```json
{
  "type": "table",
  "data": { "colsLen": 2, "rowsLen": 2 },
  "children": [
    { "type": "table/cell", "data": { "colPosition": 0, "rowPosition": 0 }, "children": [ { "type": "paragraph", "data": { "delta": [ { "insert": "Name" } ] } } ] },
    { "type": "table/cell", "data": { "colPosition": 0, "rowPosition": 1 }, "children": [ { "type": "paragraph", "data": { "delta": [ { "insert": "Elara" } ] } } ] },
    { "type": "table/cell", "data": { "colPosition": 1, "rowPosition": 0 }, "children": [ { "type": "paragraph", "data": { "delta": [ { "insert": "Role" } ] } } ] },
    { "type": "table/cell", "data": { "colPosition": 1, "rowPosition": 1 }, "children": [ { "type": "paragraph", "data": { "delta": [ { "insert": "Mage" } ] } } ] }
  ]
}
```

```dart
final table = TableNode.fromList([
  ['Name', 'Elara'],   // column 0
  ['Role', 'Mage'],    // column 1
]);
// renders as: | Name | Role  |
//             | Elara| Mage  |
```

`TableNode.fromNodes` (any node type per cell, e.g. a heading):

```dart
final table = TableNode.fromNodes([
  [headingNode(level: 3, text: 'Name'), paragraphNode(text: 'Elara')], // col 0
  [paragraphNode(text: 'Role'),          paragraphNode(text: 'Mage')],  // col 1
]);
```

For full per-cell control (width, background, padding), build cells with
`tableCellNode(...)` and pass them to `TableNode.fromNodes`:

```dart
final table = TableNode.fromNodes([
  [
    tableCellNode(
      rowPosition: 0,
      colPosition: 0,
      child: paragraphNode(text: 'Name'),
      colWeight: 1.5,
    ),
    paragraphNode(text: 'Elara'),
  ],
  [paragraphNode(text: 'Role'), paragraphNode(text: 'Mage')],
]);
```

The table node is `table.node` — pass that into the document.

### Columns

A `columns` node wraps two or more `column` nodes, each holding content:

```json
{
  "type": "columns",
  "children": [
    {
      "type": "column",
      "children": [ { "type": "paragraph", "data": { "delta": [ { "insert": "Left" } ] } } ]
    },
    {
      "type": "column",
      "children": [ { "type": "paragraph", "data": { "delta": [ { "insert": "Right" } ] } } ]
    }
  ]
}
```

```dart
columnsNode(
  children: [
    columnNode(children: [paragraphNode(text: 'Left')]),
    columnNode(children: [paragraphNode(text: 'Right')]),
  ],
)
```

`columnNode` accepts an optional `width` (double) to fix the column width;
without it the column expands to share the available space.

---

## 5. Assembling a complete Document

Wrap the blocks in a `pageNode` and hand it to `Document`:

```dart
final document = Document(
  root: pageNode(
    children: [
      headingNode(level: 1, text: 'My Document'),
      paragraphNode(text: 'Intro paragraph.'),
      bulletedListNode(text: 'First bullet'),
      bulletedListNode(text: 'Second bullet'),
      todoListNode(checked: false, text: 'A task'),
      dividerNode(),
      TableNode.fromList([
        ['Name', 'Role'],
        ['Elara', 'Mage'],
      ]).node,
    ],
  ),
);
```

You can also load a document from JSON:

```dart
final document = Document.fromJson({
  'document': {
    'type': 'page',
    'children': [
      {'type': 'paragraph', 'data': {'delta': [{'insert': 'Hello'}]}},
    ],
  },
});
```

---

## 6. Applying content through an EditorState transaction

To render and edit the document, create an `EditorState` and pass it to
`NovidentEditor`. To **insert** blocks at runtime, build a `Transaction` and
apply it:

```dart
final editorState = EditorState(document: document);

// Insert a paragraph at the start of the document (path [0]).
final transaction = editorState.transaction
  ..insertNode([0], paragraphNode(text: 'Inserted first'));
editorState.apply(transaction);

// Insert several nodes at the end.
final tx = editorState.transaction
  ..insertNodes([document.root.children.length], [
    headingNode(level: 2, text: 'Section'),
    paragraphNode(text: 'Body text'),
  ]);
editorState.apply(tx);
```

Useful `Transaction` methods:
- `insertNode(Path path, Node node)` — insert one node.
- `insertNodes(Path path, Iterable<Node> nodes)` — insert several.
- `updateNode(Node node, Attributes attributes)` — merge attributes.
- `deleteNode(Node node)` / `deleteNodes(Iterable<Node>)` — remove nodes.

A `Path` is a list of child indices from the root (e.g. `[0]` is the first
top-level block, `[0, 2]` is the third child of the first block).

Render it:

```dart
NovidentEditor(
  editorState: editorState,
  // optional: editorScrollController, keyboardStrategies, editorStyle, …
)
```

---

## 7. Workflow for answering a request

When asked to create an example of a block (or a whole document):

1. **Identify the block(s)** requested. Map the request to the reference
   table in §3.
2. **Produce the JSON form** (§4) — the serialized node(s), wrapped in
   `{ "document": { "type": "page", "children": […] } }` when it is a full
   document.
3. **Produce the Dart form** (§4) — using the factory method, wrapped in
   `pageNode(...)` + `Document(...)` when it is a full document.
4. If the user wants it **applied**, show the `EditorState` + `Transaction`
   snippet (§6).
5. If the request is ambiguous (e.g. "a list" could be bulleted or numbered),
   pick the most common interpretation and note the alternative.

Always show **both** the JSON and the Dart factory form unless the user asks
for only one — that is the core value of this skill.