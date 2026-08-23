import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Typewriter scroll policy: keeps the cursor **always centered** at
/// [alignment] of the viewport, instantly (no animation).
///
/// The document scrolls under the cursor. When the selection is **not
/// collapsed** (e.g. the user is selecting text), the strategy delegates to
/// the default edge-follow by returning [ScrollDecision.ignored].
///
/// Pass it to [NovidentEditor.scrollStrategies] to enable it:
///
/// ```dart
/// NovidentEditor(
///   editorState: editorState,
///   scrollStrategies: isTypewriterEnabled
///       ? const [TypewriterScrollStrategy()]
///       : const [],
/// );
/// ```
class TypewriterScrollStrategy extends DefaultScrollStrategy {
  const TypewriterScrollStrategy({
    this.alignment = 0.45,
    this.centerTolerance = 2,
    this.stalenessTolerance = 0.8,
  });

  /// Where the cursor is kept inside the viewport: 0.0 = top, 0.5 = center,
  /// 1.0 = bottom.
  final double alignment;

  /// Minimum distance (in logical pixels) the caret must be from the target
  /// center before the strategy scrolls.
  ///
  /// Avoids jitter while typing: when the caret is already (approximately)
  /// centered, sub-pixel measurement noise would otherwise make the scroll
  /// drift up/down on every keystroke.
  final double centerTolerance;

  /// How much the node's render box may have moved (in logical pixels) while
  /// the scroll offset changed before the measurement is considered stale.
  ///
  /// When keystrokes arrive faster than frames render (large documents), the
  /// render tree is frozen at the previous frame's scroll offset while the
  /// scroll controller already reports the new one. Measuring the caret
  /// against that frozen tree and scrolling by the resulting delta piles up
  /// stale corrections and makes the typewriter "go crazy". When the render
  /// box did not move with the scroll, the measurement is stale and the
  /// strategy skips the event (the next fresh measurement corrects).
  final double stalenessTolerance;

  @override
  ScrollDecision onSelectionChanged(ScrollStrategyContext ctx) {
    // expanded selection → delegate to the default edge-follow.
    if (!ctx.selection.isCollapsed) {
      return ScrollDecision.ignored;
    }

    final scrollableState = ctx.editorState.scrollableState;
    if (scrollableState == null) {
      return ScrollDecision.ignored;
    }
    if (ctx.editorScrollController.shrinkWrap) {
      // the ScrollOffsetController is not available in shrinkWrap mode.
      return ScrollDecision.ignored;
    }

    if (ctx.selectionRects.isEmpty) {
      // caret not measurable yet (target block not built) → jump to the block
      // by index to bring it into view; the next selection change centers it.
      final path = ctx.selection.normalized.start.path;
      if (path.isEmpty) {
        return ScrollDecision.ignored;
      }
      // the node changed: previous measurements no longer apply.
      ctx.state.reset();
      final index = path.first + (ctx.editorState.showHeader ? 1 : 0);
      ctx.editorScrollController.itemScrollController.jumpTo(index: index);
      return ScrollDecision.handled;
    }

    _center(ctx, ctx.selectionRects);
    return ScrollDecision.handled;
  }

  /// Scrolls instantly so the caret is centered at [alignment].
  ///
  /// The target offset is clamped to the scroll extents, so at the top/bottom
  /// of the document the caret is brought as close to the center as possible.
  /// No-op when the caret is already within [centerTolerance] of the (clamped)
  /// target — this avoids typing jitter and the pointless jump when there is
  /// no room to move.
  void _center(ScrollStrategyContext ctx, List<Rect> rects) {
    final scrollableState = ctx.editorState.scrollableState;
    if (scrollableState == null) {
      return;
    }

    // Compute the caret's viewport-local position from the node's render box
    // directly (not from `selectionRects()`, whose coordinate system is
    // inconsistent depending on whether the scroll has settled).
    final node = ctx.editorState.getNodeAtPath(ctx.selection.start.path);
    final selectable = node?.selectable;
    final renderBox = node?.renderBox;
    if (selectable == null || renderBox == null) {
      return;
    }
    final localRect = selectable.getCursorRectInPosition(
      ctx.selection.end,
      shiftWithBaseOffset: true,
    );
    if (localRect == null) {
      return;
    }

    final scrollableRenderBox =
        scrollableState.context.findRenderObject() as RenderBox?;
    if (scrollableRenderBox == null) {
      return;
    }
    final scrollableOrigin = scrollableRenderBox.localToGlobal(Offset.zero);
    final nodeGlobalTop = renderBox.localToGlobal(Offset.zero).dy;
    final nodeViewportTop = nodeGlobalTop - scrollableOrigin.dy;
    final caretCenter =
        nodeViewportTop + (localRect.top + localRect.bottom) / 2;

    final pixels = scrollableState.position.pixels;

    // Stale-measurement guard: when keystrokes arrive faster than frames
    // render, the render tree is frozen at the previous frame's offset while
    // the controller already reports the new one. If the scroll moved but the
    // node's render box did not follow, the caret position measured here is
    // from the previous frame — scrolling by its delta would pile up stale
    // corrections (the typewriter "goes crazy"). Skip the event; the next
    // fresh measurement (after the frame renders) corrects.
    final state = ctx.state.getOrCreate(
      _TypewriterScrollState.new,
    );
    final nodePath = ctx.selection.start.path;
    if (state.lastNodePath == null || !state.lastNodePath!.equals(nodePath)) {
      // different node → previous measurements don't apply. (listEquals:
      // paths are lists, and `==` on lists is identity — a fresh `[0]` from
      // the selection would reset the state on every keystroke.)
      state.reset();
      state.lastNodePath = nodePath;
    }
    final lastPixels = state.lastPixels;
    final lastNodeGlobalTop = state.lastNodeGlobalTop;
    if (lastPixels != null && lastNodeGlobalTop != null) {
      final pixelsDelta = pixels - lastPixels;
      final nodeDelta = nodeGlobalTop - lastNodeGlobalTop;
      if (pixelsDelta.abs() > stalenessTolerance &&
          nodeDelta.abs() <= stalenessTolerance) {
        // render box frozen while the scroll moved → stale measurement.
        return;
      }
    }

    final viewportHeight = scrollableState.position.viewportDimension;
    final targetCenter = alignment * viewportHeight;
    final targetOffset = pixels + (caretCenter - targetCenter);

    final minExtent = scrollableState.position.minScrollExtent;
    final maxExtent = scrollableState.position.maxScrollExtent;
    // never scroll above the top (minScrollExtent can be negative when the
    // list has a leading offset); scrolling negative corrupts the caret rect
    // measurement and makes the typewriter "go crazy".
    final clampedTarget = targetOffset
        .clamp(
          math.max(0.0, minExtent),
          maxExtent,
        )
        .toDouble();

    // record the fresh measurement (pre-jump pixels) so the next event can
    // tell fresh from stale.
    state.lastPixels = pixels;
    state.lastNodeGlobalTop = nodeGlobalTop;

    // already at the (clamped) target → no scroll. This covers both the
    // "already centered" case (typing jitter) and the "no room to move" case
    // (caret at the top/bottom with the offset already clamped there).
    if ((clampedTarget - pixels).abs() < centerTolerance) {
      return;
    }

    // instant centering — no animation (animation would ping-pong).
    ctx.editorScrollController.scrollOffsetController
        .jumpTo(offset: clampedTarget);
  }
}

/// Per-editor state for [TypewriterScrollStrategy], stored in
/// [ScrollStrategyState] (owned by the scroll service).
class _TypewriterScrollState {
  /// Scroll offset at the last FRESH measurement (pre-jump).
  double? lastPixels;

  /// Node's global top at the last FRESH measurement.
  double? lastNodeGlobalTop;

  /// Path of the node the measurements belong to.
  List<int>? lastNodePath;

  void reset() {
    lastPixels = null;
    lastNodeGlobalTop = null;
    lastNodePath = null;
  }
}

