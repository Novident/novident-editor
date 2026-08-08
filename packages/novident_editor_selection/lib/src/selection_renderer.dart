import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';

import 'cursor/cursor.dart';
import 'painter/selection_area_paint_widget.dart';
import 'move_types.dart';
import 'selection_contexts.dart';

/// Full control over cursor and selection rendering, movement behavior,
/// transition animations, and lifecycle events.
///
/// Implement this interface and pass it to [EditorStyle.selectionRenderer]
/// to customize every aspect of how the cursor and selection are displayed
/// and how they respond to user input.
///
/// The [DefaultSelectionRenderer] provides the standard editor behavior
/// and is used when no custom renderer is configured.
abstract class SelectionRenderer {
  /// Build the widget that represents a collapsed cursor (caret).
  ///
  /// The default implementation returns a [Cursor] widget using the
  /// values from [ctx] — rect, color, style, and blink state.
  Widget buildCursor(CursorPaintContext ctx);

  /// Build the widget that represents the cursor at the moving head of
  /// an expanded selection (e.g. where the user is still dragging).
  ///
  /// The default implementation returns a [Cursor] with blinking disabled.
  Widget buildExpandedHeadCursor(CursorPaintContext ctx);

  /// Build the widget that paints the selection highlight background
  /// behind selected text.
  ///
  /// The default implementation returns a [SelectionAreaPaint] using
  /// the pre-measured [SelectionPaintContext.rects].
  Widget buildSelectionHighlight(SelectionPaintContext ctx);

  /// Build the widget that paints a block-level selection indicator
  /// (used when [SelectionType.block] is active).
  ///
  /// The default implementation returns a [Positioned.fromRect] with
  /// a rounded [Container].
  Widget buildBlockSelectionHighlight(BlockSelectionContext ctx);

  /// Called when the user presses arrow up or down. Return a [Position]
  /// to override the default vertical movement, or `null` to use the
  /// standard [SelectableMixin.moveVerticallyInText] logic.
  Position? onVerticalMove(CursorMoveContext ctx);

  /// Called when the user presses arrow left or right. If [byWord] is
  /// `true`, the movement should respect word boundaries.
  ///
  /// Return a [Position] to override, or `null` to use default behavior.
  /// The default implementation handles word boundaries via
  /// [SelectableMixin.getWordBoundaryInPosition] when [byWord] is true.
  Position? onHorizontalMove(CursorMoveContext ctx, {bool byWord = false});

  /// Called when the user presses the Home key.
  Position? onMoveToLineStart(CursorMoveContext ctx);

  /// Called when the user presses the End key.
  Position? onMoveToLineEnd(CursorMoveContext ctx);

  /// Called when the user presses Page Up.
  Position? onPageUp(CursorMoveContext ctx);

  /// Called when the user presses Page Down.
  Position? onPageDown(CursorMoveContext ctx);

  /// Called BEFORE a cursor movement is applied. Provides both the
  /// current state and the target state the editor would move to.
  ///
  /// Return a [MoveIntention] to redirect, cancel, or animate the
  /// transition. Return `null` to let the editor move normally.
  ///
  /// Use [MoveIntention.animated] to request a smooth cursor animation
  /// between positions — especially useful for cross-block transitions.
  MoveIntention? onTryMove(MoveAttemptContext ctx);

  /// Called AFTER a cursor movement has completed successfully.
  void onMoveCompleted(MoveCompletedContext ctx);

  /// Called when the user begins a selection drag (mouse down / touch start).
  void onSelectionStarted(SelectionLifecycleContext ctx);

  /// Called when the user ends a selection drag (mouse up / touch end).
  void onSelectionEnded(SelectionLifecycleContext ctx);

  /// Called when the editor gains input focus.
  void onFocusGained(FocusLifecycleContext ctx);

  /// Called when the editor loses input focus.
  void onFocusLost(FocusLifecycleContext ctx);

  /// Whether this renderer should paint the cursor at the moving head of
  /// an expanded selection (e.g. vim visual mode).
  ///
  /// When `true`, [buildExpandedHeadCursor] is called for the selection
  /// head even when no [CursorAppearance] is configured on the host.
  /// Defaults to `false`.
  bool get paintExpandedHeadCursor => false;

  /// Returns a custom position for the expanded-selection head cursor,
  /// or null to use the raw selection end position.
  ///
  /// Override to re-anchor the head cursor — e.g. vim paints at `end-1`
  /// so the block stays on the currently selected character.
  /// Only consulted when [paintExpandedHeadCursor] returns `true`.
  Position? expandedHeadPosition(Selection? rawSelection) => null;

  /// Called after the default cursor rect has been measured via
  /// [SelectableMixin.getCursorRectInPosition].
  ///
  /// Return a different [Rect] to override the measured position, or
  /// `null` to keep the default. Use this to adjust cursor placement
  /// without replacing the entire widget.
  Rect? onCursorRectMeasured(CursorMeasureContext ctx);

  /// Called after the default selection rectangles have been measured via
  /// [SelectableMixin.getRectsInSelection].
  ///
  /// Return a different list of [Rect]s to override, or `null` to keep
  /// the defaults.
  List<Rect>? onSelectionRectsMeasured(SelectionMeasureContext ctx);
}

/// The default [SelectionRenderer] implementation that replicates the
/// standard editor cursor and selection behavior exactly.
///
/// - Cursor: [Cursor] widget with vertical line / border / cover styles
/// - Selection: [SelectionAreaPaint] with filled rectangles
/// - Block selection: rounded [Container] with configurable margin
/// - Movement: delegates to [SelectableMixin] methods
/// - Word movement: uses [SelectableMixin.getWordBoundaryInPosition]
/// - All lifecycle and measurement overrides are no-ops by default
class DefaultSelectionRenderer implements SelectionRenderer {
  const DefaultSelectionRenderer();

  @override
  Widget buildCursor(CursorPaintContext ctx) {
    return Cursor(
      rect: ctx.rect,
      color: ctx.color,
      cursorStyle: ctx.style,
      shouldBlink: ctx.shouldBlink,
    );
  }

  @override
  Widget buildExpandedHeadCursor(CursorPaintContext ctx) {
    return Cursor(
      rect: ctx.rect,
      color: ctx.color,
      cursorStyle: ctx.style,
      shouldBlink: false,
    );
  }

  @override
  Widget buildSelectionHighlight(SelectionPaintContext ctx) {
    return SelectionAreaPaint(
      rects: ctx.rects,
      selectionColor: ctx.color,
      minRectWidth: 8,
    );
  }

  @override
  Widget buildBlockSelectionHighlight(BlockSelectionContext ctx) {
    return Positioned.fromRect(
      rect: ctx.rect,
      child: Container(
        margin: ctx.margin,
        decoration: BoxDecoration(
          color: ctx.color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  @override
  Position? onVerticalMove(CursorMoveContext ctx) => null;

  @override
  Position? onHorizontalMove(CursorMoveContext ctx, {bool byWord = false}) =>
      null;

  @override
  Position? onMoveToLineStart(CursorMoveContext ctx) => null;

  @override
  Position? onMoveToLineEnd(CursorMoveContext ctx) => null;

  @override
  Position? onPageUp(CursorMoveContext ctx) => null;

  @override
  Position? onPageDown(CursorMoveContext ctx) => null;

  @override
  MoveIntention? onTryMove(MoveAttemptContext ctx) => null;

  @override
  void onMoveCompleted(MoveCompletedContext ctx) {}

  @override
  void onSelectionStarted(SelectionLifecycleContext ctx) {}

  @override
  void onSelectionEnded(SelectionLifecycleContext ctx) {}

  @override
  void onFocusGained(FocusLifecycleContext ctx) {}

  @override
  void onFocusLost(FocusLifecycleContext ctx) {}

  @override
  bool get paintExpandedHeadCursor => false;

  @override
  Position? expandedHeadPosition(Selection? rawSelection) => null;

  @override
  Rect? onCursorRectMeasured(CursorMeasureContext ctx) => null;

  @override
  List<Rect>? onSelectionRectsMeasured(SelectionMeasureContext ctx) => null;
}
