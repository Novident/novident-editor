import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

enum SelectionUpdateReason {
  /// like mouse click, keyboard event
  uiEvent,

  /// like insert, delete, format
  transaction,

  /// like remote selection
  remote,
  selectAll,

  /// Highlighting search results
  searchHighlight,
}

enum SelectionType {
  inline,
  block,
}

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
  const SelectionRenderer();

  /// Build the widget that represents a collapsed cursor (caret).
  ///
  /// The default implementation returns a [Cursor] widget using the
  /// values from [ctx] — rect, color, style, and blink state.
  Widget buildCursor(CursorPaintContext ctx);

  /// Build the widget that represents the cursor at the moving head of
  /// an expanded selection (e.g. where the user is still dragging).
  ///
  /// The default implementation returns a [Cursor] with blinking disabled.
  @Deprecated(
      'Use shouldPaintHeadRect + SelectionPaintContext.headColor instead. '
      'Will be removed in a future version.')
  Widget buildExpandedHeadCursor(CursorPaintContext ctx) =>
      const SizedBox.shrink();

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

  /// Called during the [editorState.updateSelectionWithReason]. Provides
  /// the values that let us decide which will be the new selection for
  /// the editor
  Future<Selection?> updateSelectionWithReason(
    BlockSelectionHost state,
    Selection? selection, {
    SelectionUpdateReason reason = SelectionUpdateReason.transaction,
    Map? extraInfo,
    SelectionType? customSelectionType,
  }) async =>
      null;

  /// Called when the user begins a selection drag (mouse down / touch start).
  void onSelectionStarted(SelectionLifecycleContext ctx);

  /// Called when the user ends a selection drag (mouse up / touch end).
  void onSelectionEnded(SelectionLifecycleContext ctx);

  /// Called when the editor gains input focus.
  void onFocusGained(FocusLifecycleContext ctx);

  /// Called when the editor loses input focus.
  void onFocusLost(FocusLifecycleContext ctx);

  /// Whether the selection painter should differentiate the moving head
  /// of an expanded selection by painting its rect in cursor color.
  ///
  /// When `true`, [BlockSelectionArea] sets [SelectionPaintContext.headColor]
  /// to the cursor color and [SelectionPaintContext.headRectIndex] to the
  /// index of the last rect. The painter paints that rect with
  /// [SelectionPaintContext.headColor] instead of [SelectionPaintContext.color],
  /// giving the visual effect of a cursor at the selection head without a
  /// separate widget.
  bool get shouldPaintHeadRect => false;

  /// Whether the [NovidentRichText] should take in account the moving head
  /// of an expanded selection to compute the correct character constrast color.
  bool get headWrapsCharacter => false;

  @Deprecated(
      'Use shouldPaintHeadRect instead. Will be removed in a future version.')
  bool get paintExpandedHeadCursor => false;

  @Deprecated('The painter handles head positioning via shouldPaintHeadRect. '
      'Will be removed in a future version.')
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
class DefaultSelectionRenderer extends SelectionRenderer {
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

  @Deprecated(
      'Use shouldPaintHeadRect + SelectionPaintContext.headColor instead. '
      'Will be removed in a future version.')
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
      headRectIndex: ctx.headRectIndex,
      headColor: ctx.headColor,
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
  bool get shouldPaintHeadRect => false;

  @Deprecated(
      'Use shouldPaintHeadRect instead. Will be removed in a future version.')
  @override
  bool get paintExpandedHeadCursor => false;

  @Deprecated('The painter handles head positioning via shouldPaintHeadRect. '
      'Will be removed in a future version.')
  @override
  Position? expandedHeadPosition(Selection? rawSelection) => null;

  @override
  Rect? onCursorRectMeasured(CursorMeasureContext ctx) => null;

  @override
  List<Rect>? onSelectionRectsMeasured(SelectionMeasureContext ctx) => null;
}
