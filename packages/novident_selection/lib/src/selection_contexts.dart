import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:novident_core/novident_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import 'move_types.dart';

/// Context passed to [SelectionRenderer.buildCursor] and
/// [SelectionRenderer.buildExpandedHeadCursor] with everything needed
/// to render a custom cursor widget.
class CursorPaintContext {
  const CursorPaintContext({
    required this.node,
    required this.selection,
    required this.position,
    required this.rect,
    required this.color,
    required this.style,
    required this.shouldBlink,
    required this.isExpandedHead,
    required this.textDirection,
    required this.delegate,
    this.renderParagraph,
    this.placeholderRenderParagraph,
  });

  /// The document node the cursor belongs to.
  final Node node;

  /// The full editor selection. May be collapsed or expanded.
  final Selection selection;

  /// The exact position where the cursor is painted.
  final Position position;

  /// Pre-measured cursor rectangle in local coordinates.
  final Rect rect;

  /// Cursor color from editor configuration.
  final Color color;

  /// Preferred cursor visual style.
  final CursorStyle style;

  /// Whether the cursor should blink.
  final bool shouldBlink;

  /// When `true`, this cursor is being painted at the moving head of an
  /// expanded selection rather than at a collapsed caret.
  final bool isExpandedHead;

  /// Text direction resolved from block configuration or ambient [Directionality].
  final TextDirection textDirection;

  /// The block's [SelectableMixin] for accessing additional measurement
  /// methods like [SelectableMixin.getWordBoundaryInPosition].
  final SelectableMixin delegate;

  /// The [RenderParagraph] that lays out the text content.
  /// May be `null` — use [delegate] to reach the paragraph.
  final RenderParagraph? renderParagraph;

  /// The placeholder [RenderParagraph] for empty lines.
  final RenderParagraph? placeholderRenderParagraph;
}

/// Context passed to [SelectionRenderer.buildSelectionHighlight]
/// for painting text selection backgrounds.
class SelectionPaintContext {
  const SelectionPaintContext({
    required this.node,
    required this.selection,
    required this.rects,
    required this.color,
    required this.textDirection,
  });

  /// The document node containing the selection.
  final Node node;

  /// The full selection being highlighted.
  final Selection selection;

  /// Pre-measured selection rectangles in local coordinates.
  final List<Rect> rects;

  /// Selection highlight color from editor configuration.
  final Color color;

  /// Text direction for the block.
  final TextDirection textDirection;
}

/// Context passed to [SelectionRenderer.buildBlockSelectionHighlight]
/// for painting block-level selection indicators.
class BlockSelectionContext {
  const BlockSelectionContext({
    required this.node,
    required this.rect,
    required this.color,
    this.margin,
  });

  /// The document node being selected at block level.
  final Node node;

  /// Pre-measured block rectangle in local coordinates.
  final Rect rect;

  /// Block selection color.
  final Color color;

  /// Optional margin to inset the highlight from block edges,
  /// resolved from the block component builder configuration.
  final EdgeInsets? margin;
}

/// Context passed to movement methods like
/// [SelectionRenderer.onVerticalMove] and
/// [SelectionRenderer.onHorizontalMove].
class CursorMoveContext {
  const CursorMoveContext({
    required this.node,
    required this.currentOffset,
    required this.caretLocalDx,
    required this.textDirection,
    required this.delegate,
    required this.renderParagraph,
    required this.textShift,
    this.delta,
  });

  /// The node the cursor is currently in.
  final Node node;

  /// Current text offset within the node.
  final int currentOffset;

  /// X position of the caret in local (scroll-independent) coordinates.
  final double caretLocalDx;

  /// Text direction for the current block.
  final TextDirection textDirection;

  /// The block's [SelectableMixin].
  final SelectableMixin delegate;

  /// The [RenderParagraph] that lays out this node's text.
  final RenderParagraph renderParagraph;

  /// Number of [WidgetSpan]s prepended before the first character
  /// (used for first-line indent offset).
  final int textShift;

  /// The text delta for this node, if any.
  final Delta? delta;
}

/// Context passed to [SelectionRenderer.onTryMove] BEFORE a cursor
/// movement happens. Provides both the current state and the target
/// the editor would move to by default.
///
/// Use this to redirect, cancel, or animate cursor transitions —
/// especially useful for cross-block animations.
class MoveAttemptContext {
  const MoveAttemptContext({
    required this.currentNode,
    required this.currentPosition,
    required this.currentCursorRect,
    required this.textDirection,
    required this.currentDelegate,
    required this.targetNode,
    required this.targetPosition,
    required this.targetCursorRect,
    this.targetDelegate,
    required this.direction,
    required this.crossesBlockBoundary,
    this.renderParagraph,
  });

  /// The node the cursor is currently in.
  final Node currentNode;

  /// The current cursor position.
  final Position currentPosition;

  /// The current cursor rectangle in local coordinates.
  final Rect currentCursorRect;

  /// Text direction for the current block.
  final TextDirection textDirection;

  /// The [SelectableMixin] for the current node.
  final SelectableMixin currentDelegate;

  /// The node the cursor would move to by default.
  final Node targetNode;

  /// The position the cursor would move to by default.
  final Position targetPosition;

  /// The cursor rectangle at the target position.
  final Rect targetCursorRect;

  /// The [SelectableMixin] for the target node. May be `null` for non-text blocks.
  final SelectableMixin? targetDelegate;

  /// What triggered the move.
  final MoveDirection direction;

  /// Whether the move crosses from one block to another.
  final bool crossesBlockBoundary;

  /// The [RenderParagraph] for the current node, if available.
  final RenderParagraph? renderParagraph;
}

/// Context passed to [SelectionRenderer.onMoveCompleted] AFTER
/// a cursor movement has finished.
class MoveCompletedContext {
  const MoveCompletedContext({
    required this.node,
    required this.fromPosition,
    required this.toPosition,
    required this.direction,
  });

  /// The node the cursor is now in.
  final Node node;

  /// Previous cursor position.
  final Position fromPosition;

  /// New cursor position.
  final Position toPosition;

  /// What triggered the move.
  final MoveDirection direction;
}

/// Context passed to [SelectionRenderer.onSelectionStarted] and
/// [SelectionRenderer.onSelectionEnded] when the user starts or
/// finishes a selection drag.
class SelectionLifecycleContext {
  const SelectionLifecycleContext({
    required this.selection,
    this.startNode,
    this.endNode,
    required this.isCollapsed,
  });

  /// The current selection state.
  final Selection selection;

  /// The node at the start of the selection.
  final Node? startNode;

  /// The node at the end of the selection.
  final Node? endNode;

  /// Whether the selection is collapsed (caret) or expanded.
  final bool isCollapsed;
}

/// Context passed to [SelectionRenderer.onFocusGained] and
/// [SelectionRenderer.onFocusLost] when the editor gains or loses
/// input focus.
class FocusLifecycleContext {
  const FocusLifecycleContext({
    this.focusedNode,
    required this.hasSelection,
    this.selection,
  });

  /// The node that has (or had) focus.
  final Node? focusedNode;

  /// Whether the editor had an active selection when focus changed.
  final bool hasSelection;

  /// The selection at the time of focus change, if any.
  final Selection? selection;
}

/// Context passed to [SelectionRenderer.onCursorRectMeasured] after
/// the default cursor rect has been calculated. Return a different
/// [Rect] to override, or `null` to keep the default.
class CursorMeasureContext {
  const CursorMeasureContext({
    required this.node,
    required this.position,
    required this.textDirection,
    required this.delegate,
    this.renderParagraph,
    this.placeholderRenderParagraph,
    required this.textShift,
  });

  /// The node the cursor is in.
  final Node node;

  /// The position being measured.
  final Position position;

  /// Text direction for the block.
  final TextDirection textDirection;

  /// The block's [SelectableMixin].
  final SelectableMixin delegate;

  /// The content [RenderParagraph], if available.
  final RenderParagraph? renderParagraph;

  /// The placeholder [RenderParagraph] for empty lines, if available.
  final RenderParagraph? placeholderRenderParagraph;

  /// Number of [WidgetSpan]s prepended before the first character.
  final int textShift;
}

/// Context passed to [SelectionRenderer.onSelectionRectsMeasured]
/// after the default selection rectangles have been calculated. Return
/// a different list to override, or `null` to keep the defaults.
class SelectionMeasureContext {
  const SelectionMeasureContext({
    required this.node,
    required this.selection,
    required this.textDirection,
    required this.delegate,
    this.renderParagraph,
  });

  /// The node containing the selection.
  final Node node;

  /// The selection being measured.
  final Selection selection;

  /// Text direction for the block.
  final TextDirection textDirection;

  /// The block's [SelectableMixin].
  final SelectableMixin delegate;

  /// The [RenderParagraph] for this node, if available.
  final RenderParagraph? renderParagraph;
}
