# Tables

Novident Editor includes a fully-featured table block component. Tables are
stored as regular document nodes and rendered with a weight-based column layout
that fills available horizontal space.

---

## Creating tables

### From plain strings (`fromList`)

```dart
import 'package:novident_editor/novident_editor.dart';

final table = TableNode.fromList([
  ['Name',  'Elara',   'Doran'],    // column 0
  ['Role',  'Mage',    'Warrior'],  // column 1
  ['Level', '8',       '6'],        // column 2
]);
editorState.insertNode(path, table.node);
```

The outer list represents **columns** (column-major order). Each inner list
contains the rows for that column. Every cell is automatically wrapped in a
`paragraphNode`.

### From nodes (`fromNodes`)

```dart
final table = TableNode.fromNodes([
  [headingNode(level: 3, text: 'Feature'), paragraphNode(text: 'Tables')],
  [paragraphNode(text: 'Status'),          paragraphNode(text: 'Done')],
]);
editorState.insertNode(path, table.node);
```

Accepts any node type: `headingNode`, styled `paragraphNode`, or custom block
components. Pass `styleRef` to reference a registered table style:

```dart
final table = TableNode.fromNodes(
  [...],
  styleRef: 'my-table-style',
);
```

### With per-cell attributes (`tableCellNode`)

```dart
TableNode.fromNodes([
  [
    tableCellNode(
      child: paragraphNode(text: 'Header'),
      colWeight: 2.0,
      rowBackgroundColor: '0xFFE3F2FD',
    ),
  ],
]);
```

`tableCellNode` creates a cell wrapper with explicit `colWeight`, `width`,
`height`, `rowBackgroundColor`, and `colBackgroundColor`. When passed to
`fromNodes`, the positions are overridden but all other attributes are preserved.

---

## Table styles (`NovidentTableStyleDefinition`)

Table styles extend `NovidentStyleDefinition` and live in the same
`NovidentStyleRegistry`. They inherit all text formatting properties
(font family, size, bold, colour, spacing, alignment) plus table-specific
layout properties.

### Defining a style

```dart
const myTableStyle = NovidentTableStyleDefinition.nextSame(
  id: 'my-table',
  name: 'My Table',
  basedOn: '__novident_table__',   // inherit defaults
  borderColor: Color(0xFF2196F3),
  borderWidth: 1.0,
  colDefaultWeight: 1.0,
  rowDefaultHeight: 40,
  evenRowColor: Color(0xFFEEEEEE),
  oddRowColor: Color(0xFFFFFFFF),
  headerRowCount: 1,
  headerStyle: NovidentTableRowStyle(
    bold: true,
    alignment: TextAlign.center,
    backgroundColor: Color(0xFF1976D2),
    textColor: Colors.white,
  ),
);
```

### Registering

```dart
NovidentEditor(
  styles: NovidentStylesConfig(
    registry: NovidentStyleRegistry({
      ...kDefaultStyleRegistry.styles,
      'my-table': myTableStyle,
    }),
    defaultStyle: kDefaultBaseStyle,
    defaultStylesByType: {
      'table': kDefaultTableStyle,
    },
  ),
);
```

### Resolution priority

| Priority | Source |
|----------|--------|
| 1 | Per-node attributes (`borderColor`, `enableHorizontalScroll`, etc.) |
| 2 | `styleRef` attribute referencing a registered `NovidentTableStyleDefinition` |
| 3 | `defaultStylesByType['table']` |
| 4 | `kDefaultTableStyle` global fallback |
| 5 | `TableDefaults` hardcoded constants |

### Text inheritance

Cells inside a table automatically inherit text formatting from the resolved
table style. A cell's own `styleRef` takes priority, falling back to the
table style, then the global default.

---

## Style properties reference

### Table layout

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `colDefaultWeight` | `double` | `1.0` | Default weight for columns without explicit `colWeight` |
| `rowDefaultHeight` | `double` | `40.0` | Default row height in pixels |
| `colMinimumWidth` | `double` | `40.0` | Minimum column width in pixels |
| `borderWidth` | `double` | `2.0` | Border thickness |
| `borderColor` | `Color?` | `null` | Border colour |
| `borderHoverColor` | `Color?` | `null` | Border colour on hover |
| `borderLineStyle` | `BorderStyle` | `solid` | Border line style (solid, dashed, etc.) |
| `borderRadius` | `BorderRadius?` | `null` | Outer corner radius |
| `noBorder` | `bool` | `false` | Hide all borders entirely |
| `innerBorderColor` | `Color?` | `null` | Inner cell divider colour (falls back to `borderColor`) |
| `outerBorderColor` | `Color?` | `null` | Outer perimeter colour (falls back to `borderColor`) |
| `enableHorizontalScroll` | `bool` | `true` | Enable horizontal scroll when content overflows |
| `showAddColumnButton` | `bool` | `true` | Show the add-column button |
| `showAddRowButton` | `bool` | `true` | Show the add-row button |
| `tablePadding` | `EdgeInsets` | `top:10, left:10, bottom:4` | Padding around the table |

### Cell defaults

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `cellPadding` | `EdgeInsets?` | `null` | Default padding inside every cell |
| `cellAlignment` | `TextAlign?` | `null` | Default horizontal text alignment |
| `cellVerticalAlignment` | `CrossAxisAlignment?` | `null` | Default vertical content alignment |
| `cellTextOverflow` | `TextOverflow?` | `null` | Overflow behaviour for cell text |
| `cellVerticalPadding` | `double` | `8.0` | Extra vertical space for row height synchronisation |

### Row striping

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `evenRowColor` | `Color?` | `null` | Background for even-numbered rows (0, 2, 4...) |
| `oddRowColor` | `Color?` | `null` | Background for odd-numbered rows (1, 3, 5...) |

### Header & footer

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `headerRowCount` | `int` | `0` | Number of header rows at the top |
| `headerStyle` | `NovidentTableRowStyle?` | `null` | Style applied to header rows |
| `footerRowCount` | `int` | `0` | Number of footer rows at the bottom |
| `footerStyle` | `NovidentTableRowStyle?` | `null` | Style applied to footer rows |

### `NovidentTableRowStyle`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `backgroundColor` | `Color?` | `null` | Row background colour |
| `bold` | `bool` | `false` | Bold text |
| `fontSize` | `double?` | `null` | Font size override |
| `textColor` | `Color?` | `null` | Text colour |
| `alignment` | `TextAlign?` | `null` | Text alignment |
| `height` | `double?` | `null` | Explicit row height |
| `padding` | `EdgeInsets?` | `null` | Padding override |
| `topBorderColor` | `Color?` | `null` | Colour of the border above this row |
| `topBorderWidth` | `double?` | `null` | Thickness of the border above this row |
| `bottomBorderColor` | `Color?` | `null` | Colour of the border below this row |
| `bottomBorderWidth` | `double?` | `null` | Thickness of the border below this row |

### Per-column / per-row defaults

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `columnWeights` | `Map<int, double>?` | `null` | Default weights keyed by column index |
| `rowHeights` | `Map<int, double>?` | `null` | Default heights keyed by row index |

### Selection

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `selectionHighlightColor` | `Color?` | `null` | Highlight colour when cells are selected |

---

## Column weights

Columns are sized proportionally by weight, not by fixed pixels. A column
with `colWeight: 2.0` gets twice the width of a column with `colWeight: 1.0`.

```dart
tableCellNode(
  child: paragraphNode(text: 'Wide column'),
  colWeight: 2.0,
),
```

When the user drags a column border, only the two adjacent columns change
size — the rest stay exactly as they were.

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `Tab` | Move to next cell |
| `Shift+Tab` | Move to previous cell |
| `Enter` | Move to cell below (or create new paragraph after table on last row) |
| `Backspace` | At start of cell — no-op (preserves table structure) |
| Arrow keys | Navigate between cells preserving column/row alignment |

---

## Column-major ordering

Both `fromList` and `fromNodes` use column-major order: the outer list
represents columns, and each inner list contains rows for that column.

```
fromList([
  ['A', 'C'],   // column 0: A (row 0), C (row 1)
  ['B', 'D'],   // column 1: B (row 0), D (row 1)
]);
// Renders:  | A | B |
//           | C | D |
```

This means the first sublist is the first visual column (leftmost), and
its first element is the topmost cell in that column.

---

## Full example

See `example/lib/common/constants/contents/readme_document.dart` for a
complete document containing five tables demonstrating `fromList`,
`fromNodes`, `noBorder`, zebra striping, and coloured headers.
