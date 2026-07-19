# Stability & performance: the virtual scroll list under mass edits

**Files:**
- `lib/src/flutter/scrollable_positioned_list/src/scrollable_positioned_list.dart`
- `lib/src/flutter/scrollable_positioned_list/src/positioned_list.dart`

**Trigger scenario:** stress-pasting thousands of blocks into a document opened in **two split panes at once** (both panes share the same content store; each external change rebuilds the sibling pane's editor — including its `EditorScrollController` — in the middle of a frame).

Two independent bugs surfaced. Both are lifecycle bugs in the vendored `scrollable_positioned_list` (the engine that virtualizes the document: it is **not** a `ListView.builder` — it is a lazy `SliverList` driven by a ping/pong pair of internal lists to support index-based long jumps).

---

## Bug A — double dispose of the ping/pong scroll controllers

**Severity:** 🔴 **CRITICAL** — deterministic crash, inherited from upstream, latent in *every* long-distance `scrollTo` transition; the mass-edit storm merely made it frequent.

### Anatomy

`ScrollablePositionedList` owns two `ScrollController`s for its ping/pong transition scheme:

```dart
class _ListDisplayDetails {
  final scrollController = ScrollController(keepScrollOffset: false); // parent-owned
}
```

They are handed down to the child `PositionedList` widgets. But the child treated every controller as its own:

```dart
// BEFORE — _PositionedListState
@override
void dispose() {
  scrollController.removeListener(_schedulePositionNotificationUpdate);
  scrollController.dispose();          // ⚠️ disposes the PARENT's controller
  ...
}
```

The secondary (pong) list only exists while `_isTransitioning`. Sequence of the crash:

1. A long `scrollTo` mounts the secondary `PositionedList` with `secondary.scrollController`.
2. The transition ends → the secondary list unmounts → **its state disposes the parent's controller**.
3. The next transition mounts a new secondary list **reusing that same, now-disposed controller**:

```
A ScrollController was used after being disposed.
#3  _PositionedListState.initState  (positioned_list.dart:149  addListener)
```

The parent even carried a fossil of this bug — a workaround, not a fix:

```dart
// BEFORE — parent dispose
if (secondary.scrollController.hasClients) {   // "don't double-dispose what the
  secondary.scrollController.dispose();        //  child probably already killed"
}
// primary.scrollController: never disposed by the parent at all —
// it silently relied on the child's wrongful dispose.
```

### Fix: explicit ownership

```dart
// AFTER — _PositionedListState
late final bool _ownsScrollController;

void initState() {
  _ownsScrollController = widget.controller == null;
  scrollController = widget.controller ?? ScrollController();
  ...
}

void dispose() {
  scrollController.removeListener(_schedulePositionNotificationUpdate);
  if (_ownsScrollController) {
    scrollController.dispose();        // only what we created
  }
  ...
}
```

```dart
// AFTER — parent dispose: the owner releases both, unconditionally.
// (children unmount before their parent, so the ordering is safe)
primary.scrollController.dispose();
secondary.scrollController.dispose();
```

| | Before | After |
|---|---|---|
| pong transition → next transition | crash (`used after being disposed`) | reusable, by design |
| `primary` controller at teardown | leaked by parent / freed by wrong owner | released by its owner |
| ownership rule | implicit, violated | explicit (`_ownsScrollController`) |

---

## Bug B — in-flight async scrolls touching dead controllers

**Severity:** 🟠 **HIGH** — *unhandled* exception (kills the zone, not just a red box), racing window proportional to document size: bigger documents → longer frames → more time for an editor swap to land between an async scroll's steps.

### Anatomy

`_scrollTo` / `_startScroll` are asynchronous and defer work across frames (`addPostFrameCallback`, awaited `animateTo`s). When an external content sync replaces the whole editor mid-frame (dual-pane scenario), those pending callbacks resume against a state that is disposed, or controllers with no attached position:

```
Unhandled Exception: 'ScrollController not attached to any scroll views'
#2 ScrollController.position
#3 _ScrollablePositionedListState._startScroll   (line ~579)
#4 _ScrollablePositionedListState._scrollTo.<closure>  (deferred post-frame)
```

### Fix: teardown guards at every async resumption point

Four surgical guards — none changes behavior on the happy path:

```dart
void _jumpTo(...) {
  _stopScroll(canceled: true);
  if (!mounted || !primary.scrollController.hasClients) return;   // ← new
  ...
}

// _scrollTo, deferred branch:
SchedulerBinding.instance.addPostFrameCallback((_) async {
  if (mounted) {                                                   // ← new
    await _startScroll(...);
  }
  scrollCompleter.complete();          // always complete: no dangling awaits
});

Future<void> _startScroll(...) async {
  if (!mounted || !primary.scrollController.hasClients) return;    // ← new
  ...
}

// startAnimationCallback (ping/pong transition kick-off):
SchedulerBinding.instance.addPostFrameCallback((_) {
  startAnimationCallback = () {};
  if (!mounted ||
      !primary.scrollController.hasClients ||
      !secondary.scrollController.hasClients) {
    startCompleter.complete();         // ← new: resolve BOTH completers so the
    endCompleter.complete();           //   `await Future.wait([...])` upstream
    return;                            //   finishes instead of hanging forever
  }
  ...
});
```

Note the completer discipline: bailing out **must** still complete `startCompleter`/`endCompleter`, otherwise the `await Future.wait(...)` inside `_startScroll` would leak a permanently-pending future.

| | Before | After |
|---|---|---|
| editor swapped while a scroll is in flight | unhandled exception, zone killed | scroll silently cancelled |
| pending `scrollTo` future on teardown | could hang forever | resolves |
| happy path | — | byte-identical behavior |

---

## Why this mattered for large documents

Neither bug is a *throughput* cost by itself — they are stability failures whose **probability scales with document size and edit volume**:

- more blocks → more geometry per frame → longer frames → wider race windows for Bug B;
- programmatic scrolls (typewriter/zen centering, jump-to-index, scroll restoration) trigger the ping/pong transition of Bug A far more often on long documents, where targets are rarely inside the cached window.

Combined with the elimination of the per-frame polling loop (see
[`performance-selection-areas.md`](performance-selection-areas.md)), the observed field result is: **~100k-word documents with thousands of blocks editing with no perceptible lag and no teardown crashes**, including the dual-pane mass-paste stress test that originally reproduced both bugs (debug mode, desktop).

## How to detect a regression

- Stress recipe: open the same document in two panes, paste thousands of blocks repeatedly, and interleave long `scrollTo` jumps (e.g. `g` / `shift+g` in vim mode, or zen typewriter centering). Before these fixes this reliably produced both signatures above.
- Grep-able crash signatures: `used after being disposed` + `positioned_list.dart` (Bug A); `not attached to any scroll views` + `_startScroll` (Bug B).
- Ownership invariant to preserve in reviews: **a widget must never dispose a controller it did not create** — `_ownsScrollController` is the guard rail for the child; the parent's `dispose()` is the single release point for the ping/pong pair.
