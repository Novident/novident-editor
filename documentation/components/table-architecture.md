# Table Architecture

Complete reference for the table block component system in NovidentEditor.

---

## Overview

Tables are rendered as a grid of cells, each containing a content node (paragraph or heading). The system is built around a **column-major** data model with **weight-based** layout, a reusable **style system**, and **ActionBar/Handler** widgets for row/column operations.

```
┌─────────────────────────────────────────────────────┐
│                     EditorState                      │
│  ┌───────────────────────────────────────────────┐  │
│  │            TableBlockComponentWidget          │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │           TableActionBar                │  │  │
│  │  │  [+ col] [+ row] [delete] ...           │  │  │
│  │  ├─────────────────────────────────────────┤  │  │
│  │  │              TableView                  │  │  │
│  │  │  ┌────────┬────────┬────────┐          │  │  │
│  │  │  │TableCol│TableCol│TableCol │          │  │  │
│  │  │  │ (col0) │ (col1) │ (col2)  │          │  │  │
│  │  │  │        │        │         │          │  │  │
│  │  │  │ cell   │ cell   │ cell    │          │  │  │
│  │  │  │ cell   │ cell   │ cell    │          │  │  │
│  │  │  │ cell   │ cell   │ cell    │          │  │  │
│  │  │  └────────┴────────┴────────┘          │  │  │
│  │  │    ↑ border (TableColBorder, resizable) │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 1. Data Model

### 1.1 TableNode

`TableNode` (`lib/.../table_block_component/table_node.dart`) is a thin wrapper around a `Node` of type `TableBlockKeys.type` (`'table'`). It provides typed accessors for layout dimensions and a `distributeColumnWidths` method.

**Node structure:**

```
Node type='table'
├── attributes
│   ├── colsLen: int          (number of columns)
│   ├── rowsLen: int          (number of rows)
├── children (column-major order)
│   ├── Node type='table/cell'  ← (col=0, row=0)
│   │   ├── attributes { colPosition: 0, rowPosition: 0, colWeight: 1.0 }
│   │   └── children [paragraphNode]
│   ├── Node type='table/cell'  ← (col=1, row=0)
│   ├── Node type='table/cell'  ← (col=0, row=1)
│   ├── Node type='table/cell'  ← (col=1, row=1)
│   └── ...
```

**Style-inherited layout properties**: `colDefaultWeight`,
`rowDefaultHeight`, `colMinimumWidth`, and `borderWidth` are defined in
[NovidentTableStyleDefinition](#41-novidenttablestyledefinition) — they
are NOT stored as node attributes (by default at the start for blank or new tables). The table reads them from the resolved
style at build time via `TableNode.getColWeight(i, style)` and similar
accessors. Per-table overrides for `borderWidth`, `borderColor`, and
`enableHorizontalScroll` can be set via
[TableActions](#51-tableactions) and stored as node attributes, but the
defaults always come from the style.

**Column-major ordering** is critical: cells are indexed as `col × numRows + row`. This enables O(1) cell lookup and is used throughout the mutation and navigation layers.

### 1.2 TableCellBlockKeys

Each cell node stores its position and layout properties:

| Attribute | Type | Description |
|---|---|---|
| `colPosition` | `int` | Column index (0-based) |
| `rowPosition` | `int` | Row index (0-based) |
| `colWeight` | `double` | Weight relative to other columns in the weight distribution algorithm (default: 1.0) |
| `height` | `double` | Explicit cell height (px) |
| `rowBackgroundColor` | `String` | Hex color for the entire row |
| `colBackgroundColor` | `String` | Hex color for the entire column |

### 1.3 TableBlockKeys

Table-level attributes:

| Attribute | Type | Description |
|---|---|---|
| `colsLen` | `int` | Number of columns |
| `rowsLen` | `int` | Number of rows |
| `borderWidth` | `double?` | Per-table override for border thickness (falls back to style) |
| `borderColor` | `String?` | Per-table override for border color (falls back to style) |
| `enableHorizontalScroll` | `bool?` | Per-table override for horizontal scroll (falls back to style) |

---

## 2. Layout Engine: Weight-Based Column Distribution

### 2.1 Algorithm

`TableNode.distributeColumnWidths(availableWidth, {noBorder, style})` distributes the available width proportionally by column weights:

```
totalWeight = Σ colWeight[i]
for each column i:
    ideal = availableWidth × (colWeight[i] / totalWeight)
    clamped[i] = max(ideal, colMinimumWidth)
    // Iterate: if clamping caused overflow, redistribute the
    // deficit among unclamped columns, up to 10 iterations.
```

This is iterated until convergence (max 10 rounds) to handle the case where clamping a column to its minimum forces other columns below their minimum.

### 2.2 Caching

The `_TableBlockComponentWidgetState` caches the computed column widths keyed by a hash of column weights + available width + border flag:

```dart
int _weightHash(TableNode t) {
  var h = t.colsLen;
  for (var i = 0; i < t.colsLen; i++) {
    h = h * 31 + (t.getColWeight(i, tableStyle) * 1000).round();
  }
  return h;
}
```

Cache is invalidated when weights or available width change, but survives rebuilds.

### 2.3 Horizontal Scroll

When `enableHorizontalScroll` is true AND the table's minimum intrinsic width exceeds the available width, the table renders inside a `SingleChildScrollView` at minimum widths. Otherwise, columns fill the available space.

Override per-table with `TableActions.setEnableHorizontalScroll` or via `node.attributes[enableHorizontalScroll]`.

---

## 3. Widget Tree

### 3.1 TableBlockComponentWidget

The top-level widget. On `build`:
1. **Resolves style**: calls `NovidentEditorStyles.resolveStyle(node)` → `NovidentTableStyleDefinition`
2. **LayoutBuilder**: computes available width
3. **Calls `_columnWidths`**: cached weight-based distribution
4. **Renders `TableView`**: passes column widths, style, action menu items

The widget also implements `SelectableMixin` for block-level selection.

### 3.2 TableView

The grid renderer (`table_view.dart`). Receives pre-computed `columnWidths` (a `List<double>`) and renders:

```
┌──────────────────────────────────┐
│  TableActionBar (conditionally)  │
├──────────────────────────────────┤
│  Row (for each row)              │
│  ├── TableCol (for each column)  │
│  └── ...                         │
│  Row                             │
│  ├── TableCol                    │
│  └── ...                         │
└──────────────────────────────────┘
```

Each row is a `Row` widget. Each `TableCol` receives its pre-computed width. Borders (`TableColBorder`) are rendered between columns with resize handles.

### 3.3 TableCol

Renders all cells in one column as a `Column` widget. Each cell is wrapped in its own container with the resolved background color (from style's `evenRowColor`/`oddRowColor`, header/footer style, or per-cell attributes).

Key responsibilities:
- Receives `colHeight` list for each row in the column
- Renders cell content using `editorState.renderer.build()`
- Reports row height changes back via `updateRowHeightCallback`

### 3.4 TableColBorder

Renders the vertical border between two columns. Supports:
- **Fixed border**: a simple `Container` with the border color
- **Resizable border**: a `GestureDetector` that handles horizontal drag for column resizing

Border color and width are resolved from:
1. Per-table override (`node.attributes[borderColor]` / `node.attributes[borderWidth]`)
2. Style definition (`NovidentTableStyleDefinition.borderColor` / `.borderWidth`)
3. `TableDefaults` hardcoded fallback

### 3.5 TableCellBlockComponentWidget

The widget builder for individual cells. Resolves:
- **Background color**: style's row colors → per-cell attributes → header/footer style
- **Min height**: from `cellHeight` attribute
- **Padding**: from cell padding (default: `EdgeInsets.symmetric(horizontal: 4)`)

Child content is rendered via `editorState.renderer.build(context, cell.children.first)`.

### 3.6 TableActionBar

A floating bar that appears **above the table** when the table or any cell inside it is focused. Displays quick actions:
- Add column left/right
- Add row above/below
- Delete current row/column
- Clear content
- Style quick-select

Visibility: shown when `node.hasFocus` or cursor is inside a cell. Hidden when focus leaves the table subtree.

Caches the cell position of the cursor to avoid rebuilding on every keystroke.

### 3.7 TableActionHandler

Hover-triggered action buttons that appear on column headers and row edges. Each handler:
- Appears on mouse hover over a row/column edge
- Shows a contextual menu (`showActionMenu`) with customizable items
- Menu items are `TableActionMenuItem` with `nameBuilder`, `iconBuilder`, `onPressed`, and optional `visible` predicate

---

## 4. Style System

### 4.1 NovidentTableStyleDefinition

Extends `NovidentStyleDefinition` — lives in the same `NovidentStyleRegistry` as paragraph styles. Resolution priority:

1. Per-node attributes (`TableBlockKeys`, `TableCellBlockKeys`)
2. Style referenced via `styleRef` node attribute
3. Default style for `'table'` block type (`defaultStylesByType['table']`)
4. `kDefaultTableStyle` global fallback

**Table-specific properties:**

| Property | Default | Description |
|---|---|---|
| `colDefaultWeight` | 1.0 | Default weight for columns |
| `rowDefaultHeight` | 40.0 | Default row height (px) |
| `colMinimumWidth` | 40.0 | Minimum column width (px) |
| `borderWidth` | 2.0 | Border thickness |
| `borderColor` | `null` | Border color (uses `TableDefaults`) |
| `noBorder` | `false` | Disable all borders |
| `cellPadding` | `null` | Cell content padding |
| `evenRowColor` | `null` | Background for even rows |
| `oddRowColor` | `null` | Background for odd rows |
| `headerRowCount` | 0 | Number of header rows |
| `headerStyle` | `null` | `NovidentTableRowStyle` for header |
| `footerRowCount` | 0 | Number of footer rows |
| `footerStyle` | `null` | `NovidentTableRowStyle` for footer |

**Text properties** (inherited from `NovidentStyleDefinition`): `bold`, `italic`, `fontSize`, `textColor`, `alignment`, `fontFamily`, etc.

### 4.2 NovidentTableRowStyle

Style for a row range (header, footer, or custom). Properties:

| Property | Type | Description |
|---|---|---|
| `backgroundColor` | `Color?` | Row background override |
| `bold` | `bool` | Text bold |
| `fontSize` | `double?` | Font size override |
| `textColor` | `Color?` | Text color override |
| `height` | `double?` | Explicit row height |
| `topBorderColor` | `Color?` | Top border color |
| `bottomBorderColor` | `Color?` | Bottom border color |
| `padding` | `EdgeInsets?` | Cell padding override |

### 4.3 Style Resolution for Table Cells

When a paragraph inside a table cell resolves its style (via `NovidentRichText.resolvedStyle`):

1. The paragraph's own style is resolved (`own`)
2. The parent table's style is resolved (`tableStyle`)
3. **If the cell's row is within `headerRowCount`**: `tableStyle.merge(own, isHeader: true)` is called
4. The `merge` method with `isHeader=true` applies `headerStyle` properties as overrides:
   - `bold`: `headerStyle.bold ?? this.bold || parent.bold`
   - `fontSize`: `headerStyle.fontSize ?? this.fontSize ?? parent.fontSize`
   - `textColor`: `headerStyle.textColor ?? this.textColor ?? parent.textColor`
   - `background`: `headerStyle.backgroundColor ?? this.blockBackgroundColor ?? parent.blockBackgroundColor`

The paragraph builder (`ParagraphBlockComponentWidget.buildComponent`) detects header cells by checking `cellParent.rowPosition < tableStyle.headerRowCount` and resolves `tableHeaderAlign` from the header style, placing it after toolbar alignment but before block style in the priority chain.

### 4.4 Merge Methods

Two merge methods handle different scenarios:

- **`_copyWithParent`**: when merging a non-table style (paragraph style) into a table style. Table props stay, text props resolved as `headerStyle > this > parent`.
- **`_mergeWithTable`**: when merging two table styles. The "other" style overrides table props; text props resolved as `headerStyle > other > this`.

---

## 5. CRUD Operations

### 5.1 TableActions

Static methods on `TableActions` (`table_action.dart`) for all mutations:

| Method | Parameters | Description |
|---|---|---|
| `add` | `node, position, editorState, dir, style` | Add column/row at position |
| `delete` | `node, position, editorState, dir` | Delete column/row |
| `duplicate` | `node, position, editorState, dir` | Duplicate column/row |
| `clear` | `node, position, editorState, dir` | Clear cell content |
| `setBgColor` | `node, position, editorState, color, dir` | Set background color |
| `setEnableHorizontalScroll` | `node, editorState, enable` | Toggle horizontal scroll |
| `setBorderColor` | `node, editorState, color` | Set border color |
| `setBorderWidth` | `node, editorState, width` | Set border width |

All mutations update `colPosition`/`rowPosition` attributes on affected cells, adjust `colsLen`/`rowsLen` on the table node, and apply via `editorState.apply(transaction)`.

### 5.2 newCellNode

Helper that initializes a new cell with default `height` and `colWeight`. Copies from existing cells in the same row/column when available; falls back to `style.rowDefaultHeight` and `style.colDefaultWeight`.

---

## 6. Keyboard Navigation

### 6.1 TableCommands

Registered as part of `standardCommandShortcutEvents`. Handles:

| Key | Behavior |
|---|---|
| **Enter** | Move to next cell in column-major order; exit table if at last cell |
| **Tab** | Move to next cell (column-major); wraps to first cell of next row |
| **Shift+Tab** | Move to previous cell; stops at first cell |
| **Backspace** | At beginning of cell: no-op (prevents deleting cell boundary). On multi-cell selection: clears selection |

### 6.2 moveVertical (Arrow Keys)

Arrow key navigation between cells is implemented in `position_extension.dart`'s `moveVertical` method — NOT in `TableCommands`. Key behaviors:

1. **Same cell**: Early return by path comparison — zero tree lookups (most common case)
2. **Same column, adjacent row**: O(1) cell lookup via `col × numRows + row` index, preserving column position
3. **Table edge**: Navigate out to the adjacent block via `_firstMatch(table.next)`, searching from the sibling node (avoids descending into table descendants)
4. **Column wrapping prevention**: Three guard layers (vloop, vskip, vfallback) ensure the pixel-based search never wraps to a different column

Full details in `documentation/table-navigation-performance.md`.

---

## 7. Table Creation

### 7.1 Programmatic

```dart
// From strings
final table = TableNode.fromList([
  ['Name', 'Role', 'Level'],
  ['Elara', 'Mage', '8'],
  ['Doran', 'Warrior', '6'],
], styleRef: 'my-style');

// From nodes (mixed content)
final table = TableNode.fromNodes([
  [headingNode(level: 3, text: 'Item'), paragraphNode(text: 'Price')],
  [paragraphNode(text: 'Potion'), paragraphNode(text: '15 gp')],
], styleRef: 'readme-striped');

// From JSON (document loading)
final table = TableNode.fromJson(jsonMap);
```

### 7.2 Slash Menu

The `tableMenuItem` selection menu item inserts a 3×2 empty table at the cursor position.
