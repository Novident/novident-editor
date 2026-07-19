# Performance: selection areas — from per-frame polling to event-driven measurement

**File:** `lib/src/editor/block_component/base_component/selection/block_selection_area.dart`
**Severity of the original problem:** 🔴 **CRITICAL** — the single largest structural CPU cost of the editor, scaling linearly with document size, and paid on *every frame, forever, even while idle*.
**Field result after the fix:** documents of ~100k words / thousands of blocks edit with no perceptible lag (debug mode, desktop).

---

## 1. Background: what `BlockSelectionArea` does

Every block component wraps its content in a `BlockSelectionContainer`, which mounts **two** `BlockSelectionArea` widgets per block:

1. one restricted to `BlockSelectionType.selection` / `block` (painted *under* the content), and
2. one restricted to `BlockSelectionType.cursor` (painted *over* the content).

Each area caches the geometry it paints (`prevCursorRect`, `prevSelectionRects`, `prevBlockRect`) and re-measures it from the block's `SelectableMixin` after layout, because text reflows on every keystroke.

## 2. The problem: an unconditional per-frame polling loop

The original implementation kept those caches fresh like this:

```dart
// BEFORE
void _updateSelectionIfNeeded() {
  if (!mounted) return;

  // ... measure caret/selection rects, setState when they changed ...

  // ⚠️ unconditional: re-schedules itself on EVERY frame,
  // for EVERY mounted BlockSelectionArea, forever.
  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    _updateSelectionIfNeeded();
  });
}
```

`initState` scheduled the first pass, and from that moment on **each area re-registered a post-frame callback every single frame** for the whole lifetime of the widget — regardless of whether the block had anything to do with the current selection, or whether there was a selection at all.

### Why this explodes with document size

The document list keeps blocks mounted well beyond the viewport: the virtual list uses `cacheExtent = viewport × 2` on each side (see `_cacheExtent` in `scrollable_positioned_list.dart`), i.e. roughly **five screens worth of blocks are alive** at any time. Each mounted block contributes **two** areas.

Per frame, every area executed at minimum:

- `widget.listenable.value?.normalized` — `Selection.normalized` **allocates a new `Selection`** (plus `copyWith`) on every call;
- `path.inSelection(selection)` — path comparison;
- `context.read<EditorState>()` + branch checks;
- callback registration bookkeeping inside the framework.

### Cost model

| | callbacks / frame | callbacks / second (60 fps) | idle cost |
|---|---|---|---|
| **Before** | `2 × N` (N = mounted blocks) | `120 × N` | identical to active cost |
| **After** | `2 × S` (S = blocks in selection, usually 1) | `≈ 120` with a caret, **0** with no selection | **zero** |

With a large document (N ≈ 150–300 mounted blocks thanks to the cache extent), the old code registered and ran **18,000–72,000 post-frame callbacks per second**, each allocating a normalized `Selection`. That is continuous main-thread churn plus GC pressure — before a single character is typed. During typing it compounds with layout/paint of the edited block, which is what made large documents feel laggy: the frame budget was already half-spent on no-op polling.

An additional subtlety made it worse: the loop kept running even when the widget subtree was merely kept alive by the cache extent and **completely invisible**.

## 3. The fix: poll only who needs polling

Two observations make the loop almost entirely unnecessary:

1. **Blocks outside the selection paint nothing.** Their caches are empty; there is nothing that can go stale. They only need to wake up when the selection *changes* — and every area already listens to the selection notifier.
2. **Blocks inside the selection do need per-frame measurement** — their text reflows on every keystroke and on window resize, without any selection event. For them, polling is the correct tool; but "them" is normally **one block** (a collapsed caret), not every mounted block.

```dart
// AFTER
bool _pollScheduled = false;

/// Schedules one measurement pass for the next frame (deduplicated).
void _schedulePoll() {
  if (_pollScheduled || !mounted) return;
  _pollScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _pollScheduled = false;
    _updateSelectionIfNeeded();
  });
}

void _updateSelectionIfNeeded() {
  // ...same measurement branches as before...
  if (selection != null && path.inSelection(selection)) {
    // keep measuring while this block participates in the selection:
    // its layout can shift on every keystroke or window resize.
    _schedulePoll();                       // ← re-arm ONLY in this case
  } else if (/* caches not empty */) {
    setState(/* clear caches */);          // ← and STOP: no re-arm
  }
}

void _onSelectionChanged() {               // listener that already existed
  prevCursorRect = null;
  _schedulePoll();                         // ← re-arm on selection events
}
```

### Why correctness is preserved

- **Typing:** every transaction sets `afterSelection`, and the editor's `selectionNotifier` is a `PropertyValueNotifier` — it **notifies even when the value is identical**. Every edit therefore re-arms the loop through `_onSelectionChanged`, and the in-selection block keeps polling while the caret lives in it.
- **Window resize / reflow:** the affected block is by definition *in* the selection if anything is painted there — and in-selection blocks still poll per frame, exactly like before.
- **Selection moving away:** the next pass on the abandoned block finds `path ∉ selection`, clears its caches once, and goes silent.
- **Deduplication:** `_pollScheduled` guarantees at most one pending callback per area, even when `_onSelectionChanged` fires many times within one frame (e.g. mass paste).

## 4. Sibling hardening in the same file: never measure during build

The expanded-selection head caret (vim visual mode, `cursorAppearanceBuilder`) originally measured `getCursorRectInPosition` **inside `build()`**. Under mass edits with duplicated panes this hit render objects that still needed layout:

```
'package:flutter/src/rendering/paragraph.dart': Failed assertion:
line 1044 pos 12: '!debugNeedsLayout': is not true.
```

The fix moved the measurement into the same post-frame pass (`_expandedSelectionHeadRect()` caches into `prevCursorRect`), so `build()` only ever *reads* cached geometry. Rule enforced by this file now: **layout is queried after frames, never during builds.**

## 5. How to detect a regression

- DevTools → Performance: with the editor idle and no selection, the timeline must show **no recurring `postFrameCallbacks` storm**. Before the fix, every frame showed work proportional to the mounted block count.
- Instrument `_schedulePoll` with a counter: steady-state with a collapsed caret must be ~2 schedules/frame (one per area of the focused block), and **0** with `selection == null`.
- The regression suite exercising this file: selection/cursor tests under `test/new/`, vim cursor tests (`test/new/vim_mode/vim_mode_test.dart`, group *vim cursor appearance*).

## 6. Related document

The virtual-list lifecycle fixes discovered in the same stress test are documented in
[`performance-virtual-scroll.md`](performance-virtual-scroll.md).
