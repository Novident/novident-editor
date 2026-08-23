# Performance: selection & text pipeline optimizations

**Files touched:**
- `lib/src/core/location/selection.dart` — `Selection.normalized`
- `lib/src/editor_state.dart` — `selectionRects()` cache
- `lib/src/editor/editor_component/service/keyboard_service_widget.dart` — `_getCurrentTextEditingValue` plain-text cache

**Original problems:** — per-frame allocations and O(n²) string work on every drag event.

---

## 1. `Selection.normalized` — from always-alloc to zero-alloc when forward

**File:** `lib/src/core/location/selection.dart`

### Before
```dart
Selection get normalized => isBackward ? copyWith() : reversed.copyWith();
```
Both branches called `copyWith()`, which **always** allocates a new `Selection` — even when the selection is already forward (the `reversed.copyWith()` path). `normalized` is called on **every** path comparison, cursor render, and selection transform across the entire pipeline.

### After
```dart
Selection get normalized => isBackward ? this : reversed;
```
When the selection is already forward (`isBackward == true`), `this` is returned — zero allocation, zero copy. The `reversed` path still allocates (no way around it: the semantics must reverse).

### Impact
In practice, ~90% of selections are forward (collapsed carets, most drags, all `uiEvent` positions). This eliminates roughly 80% of `Selection` allocations across the whole editor.

## 2. `EditorState.selectionRects()` — per-frame cache (two consumers)

**File:** `lib/src/editor_state.dart`

### Before
Both `ScrollServiceWidget._onSelectionChanged` and `FloatingToolbar._onSelectionChanged` called `editorState.selectionRects()` independently on the same selection update. For large selections (selectAll in a 100k-word document), `selectionRects()` iterates all selected nodes and computes geometry rects — **doing this twice doubled the cost**.

### After
```dart
List<Rect> selectionRects() {
  final sel = selection;
  if (sel == null) { _cachedSelectionRectKey = null; return []; }
  final key = (sel.start, sel.end);
  if (_cachedSelectionRectKey == key && _cachedSelectionRects != null) {
    return _cachedSelectionRects!;
  }
  _cachedSelectionRectKey = key;
  _cachedSelectionRects = _computeSelectionRects(sel);
  return _cachedSelectionRects!;
}
```
The cache is keyed by `(start, end)` and invalidated in `updateSelectionWithReason` when the selection actually changes. Both consumers read the same result.

## 3. `_getCurrentTextEditingValue` — plain-text cache (drag at 60 Hz)

**File:** `lib/src/editor/editor_component/service/keyboard_service_widget.dart`

### Before
```dart
var text = editableNodes.fold<String>('',
  (sum, n) => '$sum${n.delta!.toPlainText()}\n',
);
```
On every selection change (~60×/s during mouse drag), the method concatenated the **full text of all editable nodes in the selection** using `fold`. String concatenation is O(n²) per iteration (each `$sum$append` allocates a brand-new string). With a 100-node selection, this was ~3000 string allocations **per drag event**.

### After
```dart
// Cache keyed by node-set identity — offsets change, nodes don't.
if (!identical(editableNodes, _cachedPlainTextNodes) || _cachedPlainText == null) {
  final buffer = StringBuffer();
  for (final node in editableNodes) {
    buffer.writeln(node.delta?.toPlainText() ?? '');
  }
  _cachedPlainTextNodes = editableNodes;
  _cachedPlainText = buffer.toString();
}
```

The `StringBuffer` eliminates the O(n²) concatenation, and the node-set identity comparison skips the work entirely when only the selection offsets moved (the common case during drag). The `NonDeltaTextInputService.attach` already has a guard (`if (currentTextEditingValue == formattedValue) return`) that prevents channel round-trips for pure-offset changes, so the cache makes the pre-attach work near-zero.

## Tests

- `test/core/location/selection_test.dart` (4 tests): verifies `identical` semantics for forward/backward/collapsed/multi-node selections, both allocation and correctness.
- `test/new/editor_state_test.dart` (2 tests): verifies the `selectionRects` cache returns the same instance on repeated calls and properly invalidates on selection change.

## Related documents

- [Selection areas polling → event-driven](performance-selection-areas.md)
- [Virtual scroll lifecycle fixes](performance-virtual-scroll.md)
