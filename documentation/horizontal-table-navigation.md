# Horizontal Movement Between Blocks and Table Cells

How `moveCursor` and `moveHorizontal` were made table-aware for left/right arrow navigation.

---

## Problem

Horizontal navigation (arrow left/right) had three distinct failure modes when the cursor was inside a table cell:

1. **Tree-walk wrapping at table edges**: `moveCursor` used `previousNodeWhere` / `nextNodeWhere` to find adjacent blocks. Both methods search **descendants first** — when called on a paragraph inside a cell, they would find another cell's paragraph before finding the block outside the table. Arrow left at column 0 would wrap to the last column's last cell instead of exiting.

2. **Character navigation stuck at cell boundaries**: When at offset 0 of a cell and pressing ←, `delta.prevRunePosition(0)` returned `0` — the cursor stayed in place. No cross-cell movement occurred. Same for → at the last character.

3. **Word navigation completely unaware of tables**: The word-range commands (`Ctrl+←/→`, `Alt+←/→`) called `Position.moveHorizontal()` directly, which only operates within a single node's text (`getWordBoundaryInPosition`). At a cell's edge, no word boundary exists beyond the cell — the cursor was trapped. Word selection (`Ctrl+Shift+←/→`) suffered from the same limitation.

---

## Solution by Layer

### Layer 1: Reusable TableNode extensions

All horizontal navigation was consolidated into two extension methods on `TableNode` (`table_node.dart`), eliminating duplicated math and tree traversal:

**`adjacentCellRowMajor(col, row, forward)`** — finds the next cell in visual left-to-right, top-to-bottom order. Row-major index: `row × numCols + col`. Returns `null` at the table boundary.

**`nodeOutside(upwards)`** — navigates out of the table. For the downward case, searches from `table.next` (the sibling) with `_firstMatch`, never descending into the table's own children.

**`cellAt(col, row)`** — O(1) cell lookup via `col × numRows + row` index, with linear scan fallback for corrupted sort order.

```dart
extension TableCellNavigation on TableNode {
  Node? adjacentCellRowMajor(int col, int row, {required bool forward}) {
    final flatIdx = row * numCols + col;
    final nextIdx = forward ? flatIdx + 1 : flatIdx - 1;
    if (nextIdx < 0 || nextIdx >= numCols * numRows) return null;
    final nextRow = nextIdx ~/ numCols;
    final nextCol = nextIdx % numCols;
    return cellAt(nextCol, nextRow);
  }
}

extension TableExitNavigation on TableNode {
  Node? nodeOutside(bool upwards) {
    if (upwards) {
      final prev = node.previous;
      if (prev == null) return null;
      var out = prev.lastChildWhere((n) => n.selectable != null);
      out ??= prev.selectable != null ? prev : null;
      return out;
    }
    final next = node.next;
    if (next == null) return null;
    return _firstMatch(next, (n) => n.selectable != null);
  }
}
```

### Layer 2: `_navigateToAdjacentBlock` in `selection_commands.dart`

The `moveCursor` method handles **character-range** and **line-range** (Home/End) navigation. Its edge-detection block fires whenever the cursor is at the start or end of a node and the direction would take it beyond. Previously it used `previousNodeWhere` / `nextNodeWhere`.

The replacement detects table cells and routes through the `TableNode` extensions:

```dart
void _navigateToAdjacentBlock(Node node, {
  required bool upwards,
  required Position? Function(Node, bool) textPosAt,
}) {
  final cellParent = node.parent;
  if (cellParent?.type == TableCellBlockKeys.type) {
    final t = TableNode(node: cellParent!.parent!);
    final col = cellParent.attributes[colPosition] as int?;
    final row = cellParent.attributes[rowPosition] as int?;
    if (col != null && row != null) {
      // Try adjacent cell in row-major order first.
      final nextCell = t.adjacentCellRowMajor(col, row, forward: !upwards);
      if (nextCell != null) { /* enter adjacent cell */ return; }
      // At the table boundary — exit to the block above/below.
      final outNode = t.nodeOutside(upwards);
      if (outNode != null) { /* enter outside block */ return; }
    }
  }
  // Fallback: original tree-walk for non-table nodes.
}
```

**Impact:** Character navigation at cell boundaries now:
- ← at column 0, row 0, char 0 → exits the table to the block above.
- → at last cell, last char → exits to the block below.
- ← at column 1, char 0 → navigates to the previous cell in row-major order.
- → at column 1, last char → navigates to the next cell in row-major order.

### Layer 3: `_horizontalCellNavigate` in `position_extension.dart`

`moveHorizontal` handles **word-range** navigation and is called directly by the word command handlers (`_moveCursorToLeftWordCommandHandler`, `_moveCursorToRightWordCommandHandler`) — bypassing `moveCursor`. The function operates on text within a single node and had no table awareness.

Three insertion points were added:

| Trigger | Condition | Action |
|---|---|---|
| **At node start** | `forward && offset == 0` | If inside cell: `_horizontalCellNavigate(forwards: false, atStart: false)` → previous cell (end of text) or block above (end) |
| **At node end** | `!forward && offset >= end.offset` | If inside cell: `_horizontalCellNavigate(forwards: true, atStart: true)` → next cell (start) or block below (start) |
| **Character stuck** | `newOffset == offset` after `prevRunePosition`/`nextRunePosition` | If inside cell: navigate to adjacent cell |
| **Word stuck** | `target.offset == offset` after `getWordBoundaryInPosition` | If inside cell: navigate to adjacent cell |

The helper `_horizontalCellNavigate` reuses the same `TableNode` extensions:

```dart
Position? _horizontalCellNavigate(
  EditorState editorState, Node cell, {
  required bool forwards,
  required bool atStart,
}) {
  final t = TableNode(node: cell.parent!);
  final col = cell.attributes[colPosition] as int?;
  final row = cell.attributes[rowPosition] as int?;
  if (col == null || row == null) return null;
  // Try adjacent cell in row-major.
  final nextCell = t.adjacentCellRowMajor(col, row, forward: forwards);
  if (nextCell != null) { /* return position in next cell */ }
  // At boundary — exit table.
  final outNode = t.nodeOutside(forwards);
  if (outNode != null) { /* return position in outside block */ }
  return null;
}
```

**Impact:** Word navigation (`Ctrl+←/→`) now crosses cell boundaries:
- Ctrl+← at first word of a cell → previous cell's last word (or block above).
- Ctrl+→ at last word of a cell → next cell's first word (or block below).
- Word selection (`Ctrl+Shift+←/→`) extends across cells via the same `moveHorizontal` path.

---

## Refactor: Elimination of Duplication

Before the refactor, table navigation logic was duplicated across three files:

| Logic | `position_extension.dart` | `selection_commands.dart` | `table_node.dart` |
|---|---|---|---|
| Cell lookup O(1) | `cellAt` | — | — |
| Row count | `numRows` | — | — |
| Column-major navigation | `navigateToCell` | — | — |
| Row-major navigation | — | Manual math + `firstWhereOrNull` | — |
| Exit table (up) | `navigateOutOfTable` | Manual `lastChildWhere` | — |
| Exit table (down) | `navigateOutOfTable` | Manual `_firstMatch` | — |
| DFS helper | `firstMatch` | `_firstMatch` | — |

After:

| Logic | All files |
|---|---|
| Cell lookup O(1) | `TableNode.cellAt(col, row)` |
| Row-major navigation | `TableNode.adjacentCellRowMajor(col, row, forward:)` |
| Column-major navigation | `TableNode.adjacentCellColumnMajor(col, row, upwards)` |
| Exit table | `TableNode.nodeOutside(upwards)` |
| DFS helper | `_firstMatch` (top-level in `table_node.dart`) |

**position_extension.dart** went from 5 local helpers to 2 thin wrappers that delegate to `TableNode`. **selection_commands.dart** went from ~60 lines of manual math + tree traversal to ~20 lines calling `TableNode` extensions.

---

## Net Result

| Scenario | Before | After |
|---|---|---|
| ← at col 0, row 0, char 0 | Wrapped to last cell | Exits table to block above |
| → at last cell, last char | Wrapped to first cell | Exits table to block below |
| Ctrl+← at first word of cell | Stuck in cell | Navigates to previous cell or block |
| Ctrl+→ at last word of cell | Stuck in cell | Navigates to next cell or block |
| Ctrl+Shift+←/→ across cells | Selection stops at cell boundary | Selection extends across cells |
| ←/→ between cells | Wrapped columns | Row-major visual order |
| Duplicated navigation code | 3 copies | 1 source of truth (`TableNode` extensions) |
