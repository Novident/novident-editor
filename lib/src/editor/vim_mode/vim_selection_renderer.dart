import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart'
    show
        BlockSelectionContext,
        Cursor,
        CursorMeasureContext,
        CursorMoveContext,
        CursorPaintContext,
        CursorStyle,
        DefaultSelectionRenderer,
        FocusLifecycleContext,
        MoveAttemptContext,
        MoveCompletedContext,
        MoveIntention,
        Node,
        Position,
        SelectableMixin,
        Selection,
        SelectionLifecycleContext,
        SelectionMeasureContext,
        SelectionPaintContext,
        SelectionRenderer,
        VimCursorStyle,
        VimMode,
        VimModeController;

class VimSelectionRenderer implements SelectionRenderer {
  VimSelectionRenderer({
    required this.controller,
    this.fallback = const DefaultSelectionRenderer(),
  });

  final VimModeController controller;
  final SelectionRenderer fallback;

  VimCursorStyle get _style => controller.configuration.cursorStyle;

  /// Returns [fallback] in insert mode or when vim is disabled;
  /// returns `this` in normal/visual mode.
  bool get _isVimActive =>
      controller.enabled && controller.mode != VimMode.insert;

  /// In normal/visual mode, paint the block cursor at the moving head
  /// of an expanded selection (vim visual mode).
  @override
  bool get paintExpandedHeadCursor => _isVimActive;

  /// Vim paints the block cursor at `end-1` so it stays on the currently
  /// selected character, not past it.
  @override
  Position? expandedHeadPosition(Selection? rawSelection) {
    if (!_isVimActive || rawSelection == null) return null;
    final end = rawSelection.end;
    if (end.offset > 0) {
      return Position(path: end.path, offset: end.offset - 1);
    }
    return end;
  }

  @override
  Widget buildCursor(CursorPaintContext ctx) {
    if (!_isVimActive) return fallback.buildCursor(ctx);
    return VimBlockCursor(
      rect: ctx.rect,
      color: _resolveColor(_style, ctx.color),
      shouldBlink: _style.blink,
    );
  }

  @override
  Widget buildExpandedHeadCursor(CursorPaintContext ctx) {
    if (!_isVimActive) return fallback.buildExpandedHeadCursor(ctx);
    return VimBlockCursor(
      rect: ctx.rect,
      color: _resolveColor(_style, ctx.color),
      shouldBlink: false,
    );
  }

  @override
  Widget buildSelectionHighlight(SelectionPaintContext ctx) =>
      fallback.buildSelectionHighlight(ctx);

  @override
  Widget buildBlockSelectionHighlight(BlockSelectionContext ctx) =>
      fallback.buildBlockSelectionHighlight(ctx);

  @override
  Position? onVerticalMove(CursorMoveContext ctx) =>
      fallback.onVerticalMove(ctx);
  @override
  Position? onHorizontalMove(CursorMoveContext ctx, {bool byWord = false}) =>
      fallback.onHorizontalMove(ctx, byWord: byWord);
  @override
  Position? onMoveToLineStart(CursorMoveContext ctx) =>
      fallback.onMoveToLineStart(ctx);
  @override
  Position? onMoveToLineEnd(CursorMoveContext ctx) =>
      fallback.onMoveToLineEnd(ctx);
  @override
  Position? onPageUp(CursorMoveContext ctx) => fallback.onPageUp(ctx);
  @override
  Position? onPageDown(CursorMoveContext ctx) => fallback.onPageDown(ctx);

  @override
  MoveIntention? onTryMove(MoveAttemptContext ctx) => fallback.onTryMove(ctx);
  @override
  void onMoveCompleted(MoveCompletedContext ctx) =>
      fallback.onMoveCompleted(ctx);

  @override
  void onSelectionStarted(SelectionLifecycleContext ctx) =>
      fallback.onSelectionStarted(ctx);
  @override
  void onSelectionEnded(SelectionLifecycleContext ctx) =>
      fallback.onSelectionEnded(ctx);
  @override
  void onFocusGained(FocusLifecycleContext ctx) => fallback.onFocusGained(ctx);
  @override
  void onFocusLost(FocusLifecycleContext ctx) => fallback.onFocusLost(ctx);

  @override
  Rect? onCursorRectMeasured(CursorMeasureContext ctx) {
    if (!_isVimActive) return fallback.onCursorRectMeasured(ctx);
    return VimSelectionRenderer.vimBlockRect(
      ctx.node,
      ctx.position,
      ctx.delegate,
      _style,
    );
  }

  @override
  List<Rect>? onSelectionRectsMeasured(SelectionMeasureContext ctx) =>
      fallback.onSelectionRectsMeasured(ctx);

  Color _resolveColor(VimCursorStyle style, Color fallback) {
    if (style.color != null) {
      return style.color!.withValues(alpha: style.opacity);
    }
    return fallback.withValues(alpha: style.opacity);
  }

  static Rect? vimBlockRect(
    Node node,
    Position position,
    SelectableMixin delegate,
    VimCursorStyle style,
  ) {
    final caretRect = delegate.getCursorRectInPosition(position);
    if (caretRect == null) return null;

    final height = caretRect.height;
    var width = style.blockWidth;

    if (width == null) {
      double? measured;
      final delta = node.delta;
      if (delta != null && position.offset < delta.length) {
        final nextRect = delegate.getCursorRectInPosition(
          Position(path: position.path, offset: position.offset + 1),
        );
        if (nextRect != null) {
          final sameLine = (nextRect.top - caretRect.top).abs() < height / 2;
          if (sameLine && nextRect.left > caretRect.left) {
            measured = nextRect.left - caretRect.left;
          }
        }
      }
      final minWidth = height * style.minBlockWidthFactor;
      final maxWidth = height * style.maxBlockWidthFactor;
      width = (measured ?? minWidth).clamp(minWidth, maxWidth);
    }

    return Rect.fromLTWH(caretRect.left, caretRect.top, width, height);
  }
}

/// A vim-style block cursor that covers the character at the caret.
///
/// Unlike the standard [Cursor] widget (which hardcodes `alpha: 0.2` for
/// the [CursorStyle.cover] style), this widget respects the exact color
/// produced by [VimSelectionRenderer._resolveColor] — including the
/// configurable [VimCursorStyle.opacity].
class VimBlockCursor extends StatefulWidget {
  const VimBlockCursor({
    super.key,
    required this.rect,
    required this.color,
    this.shouldBlink = false,
    this.blinkingInterval = 0.5,
  });

  final Rect rect;
  final Color color;
  final bool shouldBlink;
  final double blinkingInterval;

  @override
  State<VimBlockCursor> createState() => _VimBlockCursorState();
}

class _VimBlockCursorState extends State<VimBlockCursor> {
  bool showCursor = true;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    timer = _initTimer();
  }

  @override
  void didUpdateWidget(VimBlockCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rect != oldWidget.rect) {
      show();
    }
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Timer _initTimer() {
    return Timer.periodic(
      Duration(milliseconds: (widget.blinkingInterval * 1000).toInt()),
      (timer) => setState(() => showCursor = !showCursor),
    );
  }

  void show() {
    setState(() {
      showCursor = true;
    });
    timer.cancel();
    timer = _initTimer();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        (widget.shouldBlink && !showCursor) ? Colors.transparent : widget.color;
    final size = widget.rect.size;
    return Positioned.fromRect(
      rect: widget.rect,
      child: IgnorePointer(
        child: Container(
          width: size.width,
          height: size.height,
          color: color,
        ),
      ),
    );
  }
}
