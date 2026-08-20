# Performance: Table Keystroke Rebuilds

## Problem

Every keystroke inside a table cell triggered a **full rebuild of the entire
`TableBlockComponentWidget`**. Typing `"hello"` (5 characters) caused 5
complete widget tree reconstructions — layout, paint, the whole pipeline.

The logs confirmed it (added only while we test of this issue):

```
Table builds: 1, 2, 3, 4, 5...  ← growing with every keystroke
```

## Root Cause

The chain of events on each keystroke:

```
1. Text changes in a cell
2. Cell height changes → node notifies listeners
3. updateRowHeight() syncs row heights (correct, needed)
4. updateRowHeight() writes colsHeight to node.attributes
5. node.notifyListeners() fires
6. Consumer<Node> in BlockComponentContainer detects change
7. Full TableBlockComponentWidget rebuild ← THE PROBLEM
```

Step 4 was unnecessary. The `colsHeight` value is already available as a
computed getter on `TableNode`. Writing it back to the node's attributes
only existed to make `context.select` pick it up — but `context.select`
was only used by `TableColBorder` to size the vertical border lines.

The `Consumer<Node>` in `BlockComponentContainer` cannot distinguish
between "`colsHeight` changed" and "something important changed". Any
`notifyListeners()` from the table node triggers a full rebuild.

## Solution

**Stop writing `colsHeight` to the node.** Pass it as a widget prop instead.

Before:

```dart
// table_node.dart — updateRowHeight
node.updateAttributes({TableBlockKeys.colsHeight: colsHeight});

// table_col_border.dart — reads from node
height: context.select(
  (Node n) => n.attributes[TableBlockKeys.colsHeight],
),
```

After:

```dart
// table_node.dart — updateRowHeight
// (no longer writes colsHeight to node)

// table_col.dart — reads from computed getter, passes as prop
final colsHeight = widget.tableNode.colsHeight;
TableColBorder(colsHeight: colsHeight, ...)

// table_col_border.dart — uses prop directly
height: widget.colsHeight,
```

To keep the border height reactive, `TableCol.updateRowHeightCallback`
now calls `setState()` after syncing row heights. This causes `TableCol`
(and only `TableCol`) to rebuild, passing the fresh `colsHeight` to
`TableColBorder`.

## Why This Works

- `TableNode.colsHeight` is a **computed getter** — it iterates over all
  rows and sums `getRowHeight(i) + borderWidth`. No storage needed.

- `TableCol` already has listeners on every cell node for row height
  sync. The `setState()` in the callback is cheap — it only rebuilds
  one column's widget tree, not the entire table.

- The table node itself **never notifies** of `colsHeight` changes.
  `Consumer<Node>` sees no change → skips the rebuild.

## Result

```
Before:  Table builds: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10...
After:   Table builds: 1, 10, 20, 30, 40...
```

The table block widget now only rebuilds when something (usually the row height) changes
the table structure — column resize, style change, add/remove columns.
Typing inside a cell only rebuilds the cell and its column.

## Files Changed

| File | Change |
|------|--------|
| `table_node.dart` | Removed `node.updateAttributes({colsHeight})` from `updateRowHeight` |
| `table_col.dart` | `updateRowHeightCallback` calls `setState()`; passes `colsHeight` prop to borders |
| `table_col_border.dart` | `colsHeight` added as required prop; `context.select` replaced with `widget.colsHeight`; removed `provider` import |
