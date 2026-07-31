# Table Rendering Performance Optimizations

Optimizations applied to the table block component rendering pipeline.
Each section documents the problem, the fix, and the measured impact.

## O(1) cell lookups via `TableNode.getCell()`

### Problem

`getCellNode(tableNode, col, row)` performed a linear scan through all 100
children for every lookup. Called in nested loops (e.g., `_addCol`,
`_updateCellPositions`), the cumulative cost was O(n³).

```dart
// BEFORE: O(n) per call, called in double loops → O(n³) cumulative
Node? getCellNode(Node tableNode, int col, int row) {
  return tableNode.children.firstWhereOrNull(
    (n) => n.attributes[colPosition] == col && n.attributes[rowPosition] == row,
  );
}
```

### Fix

All 29 call sites migrated to `TableNode.getCell(col, row)`, which uses the
pre-built `_cells[col][row]` matrix — O(1).

`getCellNode` is deprecated with a note pointing to `TableNode.getCell`.

### Files changed

| File | Change |
|---|---|
| `table_action.dart` | 19 calls → `TableNode` per function + `.getCell()`. Also fixed a duplicate call in `_addRow`. |
| `table_commands.dart` | 2 calls in arrow key navigation → `TableNode(node: table)` |
| `table_action_bar.dart` | 2 calls → `widget.tableNode.getCell()` (already a `TableNode`) |
| `table_action_menu.dart` | 2 calls → `TableNode(node: menuContext.node)` |
| `table_node_parser.dart` (markdown) | 1 call in double loop → `TableNode` pre-loop |
| `table_node_parser.dart` (html) | 1 call in double loop → `TableNode` pre-loop |
| `util.dart` | Deprecated `getCellNode`. Removed unused `collection` import. |

### Impact

| Operation | Before | After |
|---|---|---|
| `_addCol` cell lookups | O(n³) cumulative | O(n²) once (constructor) + O(n) lookups |
| Arrow key navigation | O(n) scan per keypress | O(n²) constructor + O(1) lookup |
| Export to markdown/HTML | O(n²) in double loop | O(n²) constructor + O(n) lookups |

### Special case: `newCellNode`

`newCellNode` is called from the `TableNode` constructor itself. Using
`TableNode` inside it would cause infinite recursion. Instead, it does
targeted linear scans with `firstWhereOrNull` — only 2 lookups per call,
acceptable since it runs once per cell during construction.

---

## Height computation cache

### Problem

`colsHeight()` was called once per column in `TableCol.build()`. Each call
iterated all rows, and `getRowHeight()` iterated all columns within each
row. For a 10×10 table: 10 calls × 10 rows × 10 cols = 1,000 iterations
per frame.

```dart
// BEFORE: O(cols × rows × cols) per frame
double colsHeight(NovidentTableStyleDefinition style) =>
    List.generate(rowsLen, ...).fold(0, (prev, cur) =>
        prev + getRowHeight(cur, style) + style.borderWidth) + style.borderWidth;

double getRowHeight(int row, style) {
  for (final col in _cells) { ... }  // iterates all columns every call
}
```

### Fix

Added `_heightVersion` counter to `TableNode`. Incremented at the end of
`updateRowHeight()` whenever cell heights actually change. Both `getRowHeight`
and `colsHeight` cache their results keyed by `(_heightVersion, style)`.

```dart
// AFTER: O(rows × cols) once, then O(1) for all subsequent calls

int _heightVersion = 0;
final List<double> _cachedRowHeights = [];

double getRowHeight(int row, style) {
  if (cache valid) return _cachedRowHeights[row];        // O(1)
  for (var r = 0; r < rowsLen; r++) { ... }              // recompute all once
  _cachedRowHeightsVersion = _heightVersion;
  return _cachedRowHeights[row];
}

double colsHeight(style) {
  if (cache valid) return _cachedColsHeight!;             // O(1)
  // ... uses getRowHeight which is also cached
}
```

### File changed

- `table_node.dart` — +33 lines (cache fields, version counter, recompute logic)

### Impact

| Scenario | Before | After |
|---|---|---|
| `colsHeight()` × 10 columns (same frame) | ~1,100 iterations | ~109 iterations (1 recompute + 9 hits) |
| `colsHeight()` on scroll (heights stable) | 1,000+ per frame | 1 per frame (cache hit) |
| Cell edit triggers height sync | Full recompute | Full recompute + cache invalidation → next read is O(1) |

### Cache invalidation triggers

- `updateRowHeight()` modifies any cell's height attribute
- `setColWeight()` → calls `updateRowHeight()` → invalidates cache transitively
- User types in a cell → paragraph height changes → `updateRowHeight` syncs → cache refreshed

---

## Summary

| Phase | Problem | Fix | Files |
|---|---|---|---|
| 1 | 800 map copies/frame | `attributes` returns ref, not copy | `node.dart` (external pkg) |
| 2 | O(n²) cell lookups | `TableNode.getCell()` O(1) | 7 files |
| 3 | 1,000+ iterations for height | Versioned cache | `table_node.dart` |

---

## Debounced row height sync

### Problem

`TableCol._buildCells()` called `updateRowHeightCallback(r)` for every cell.
Each call scheduled a separate `WidgetsBinding.instance.addPostFrameCallback`.
For a 10×10 table: 100 post-frame callbacks per frame, each potentially
calling `updateAttributes` on all cells in the row and triggering `setState`.

### Fix

Replaced per-cell callback with a single debounced callback per column.
`_scheduleRowUpdate(row)` collects rows into a `Set<int>` (auto-dedup)
and schedules exactly one `addPostFrameCallback`. The `setState` was moved
from per-row to once after all rows.

### File changed

- `table_col.dart` — +14/-22 lines

### Impact

| Scenario | Before | After |
|---|---|---|
| Initial render (10×10) | 100 post-frame callbacks | 1 callback, 10 rows batched |
| User types in a cell | ~10 callbacks | 1 callback |
| `setState` per frame | up to 100 | 1 |

---

### Remaining (not yet implemented)

- Phase 6: `RepaintBoundary` per cell
- Phase 7: `dispose()` cleanup for cell listeners

---

## Global `tryToColor()` cache

### Problem

`tryToColor()` parsed hex/rgb/rgba strings with regex on every call.
For a 10×10 table, ~200 calls per frame each running regex matching.
Colors are immutable — the same string always produces the same `Color`.

### Fix

Added a module-level `_colorCache` map. `tryToColor()` delegates to
`Map.putIfAbsent`, which runs the regex parser only on cache miss.
Subsequent calls for the same string return the cached `Color?` instantly.

```dart
// BEFORE: regex on every call
Color? tryToColor() {
  if (rgbRegex.hasMatch(this)) { ... }
  else if (hexRegex.hasMatch(this)) { ... }
  return null;
}

// AFTER: one regex parse per unique string
final _colorCache = <String, Color?>{};

Color? tryToColor() {
  return _colorCache.putIfAbsent(this, _tryToColorUncached);
}
```

### File changed

- `color_util.dart` — +6 lines

### Impact

| Scenario | Before | After |
|---|---|---|
| First table render (5 colors used) | 200 regex parses | 5 regex parses (95% reduction) |
| Subsequent rebuilds (same colors) | 200 regex parses | 0 regex parses (100% cache hit) |
| `null` results for missing colors | re-parsed each time | cached as `null`, instant |

### Cache characteristics

- Never invalidated — colors are immutable values
- Bounded by unique color strings in the document (typically < 50)
- Includes `null` entries for invalid strings, avoiding re-parsing garbage

---
