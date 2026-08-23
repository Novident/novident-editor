import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Result of a scroll strategy for a selection-change event.
enum ScrollDecision {
  /// Not mine — let the next strategy (or the default edge-follow) handle it.
  ignored,

  /// I handled the scroll (or decided no scroll is needed) — stop dispatch.
  handled,
}

/// Persistent per-editor state shared by scroll strategies across selection
/// events.
///
/// Strategies are `const` and stateless by design (they are passed as
/// `const [MyStrategy()]`), so anything a strategy needs to remember between
/// events (e.g. the last measured caret position, to detect stale render-tree
/// measurements) lives here. The scroll service owns one instance per editor;
/// each strategy stores its own values under its runtime type.
class ScrollStrategyState {
  final Map<Type, Object> _values = {};

  /// Returns the strategy's stored value, creating it with [create] on first
  /// use.
  T getOrCreate<T>(T Function() create) =>
      _values.putIfAbsent(T, create as Object Function()) as T;

  /// Drops all stored values (used when the strategy needs a clean slate,
  /// e.g. after jumping to a different block).
  void reset() => _values.clear();
}

/// Context passed to scroll strategies on a selection change.
///
/// Carries everything a strategy needs to decide and act: the current
/// selection, the already-measured selection rects (measured once, cheap),
/// the scroll service (the "how" — `startAutoScroll`, `scrollTo`,
/// `jumpTo`, ...), and the per-editor [state].
class ScrollStrategyContext {
  ScrollStrategyContext({
    required this.editorState,
    required this.selection,
    required this.reason,
    required this.scrollService,
    required this.editorScrollController,
    required this.selectionRects,
    required this.state,
  });

  final EditorState editorState;
  final Selection selection;
  final SelectionUpdateReason reason;

  /// The scroll service the strategy can drive.
  final NovidentScrollService scrollService;

  /// The low-level scroll controller (for instant `jumpTo` / `animateTo`).
  final EditorScrollController editorScrollController;

  /// The selection rects, already measured once for this event.
  final List<Rect> selectionRects;

  /// Persistent per-editor state (owned by the scroll service).
  final ScrollStrategyState state;
}

/// Policy that decides how the editor scrolls in response to a selection
/// change.
///
/// The editor DELEGATES; the strategy decides. Implement this and pass it to
/// the editor to override the default caret-following behavior. The
/// [DefaultScrollStrategy] provides the standard edge-follow behavior.
///
/// Mirrors the `KeyboardStrategy` pattern: strategies are consulted in order
/// and the first one that returns [ScrollDecision.handled] wins.
abstract class ScrollStrategy {
  const ScrollStrategy();

  /// Decides what to do with a selection change.
  ///
  /// Return [ScrollDecision.handled] to take over the scroll (and stop
  /// dispatch), or [ScrollDecision.ignored] to let the next strategy (or the
  /// default edge-follow) handle it.
  ScrollDecision onSelectionChanged(ScrollStrategyContext ctx);
}

/// The default scroll policy: delegates to the built-in edge-follow (the
/// historical `ScrollServiceWidget` behavior).
///
/// Extend this to layer extra behavior on top of the default while keeping
/// the edge-follow as the fallback.
class DefaultScrollStrategy extends ScrollStrategy {
  const DefaultScrollStrategy();

  @override
  ScrollDecision onSelectionChanged(ScrollStrategyContext ctx) =>
      ScrollDecision.ignored;
}
