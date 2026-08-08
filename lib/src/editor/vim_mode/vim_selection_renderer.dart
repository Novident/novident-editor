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
        MoveDirection,
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

  /// The X position (in local paragraph coordinates) that vim aims
  /// to preserve across vertical movements. Updated after every move
  /// and cleared on mode changes or horizontal-only movements.
  double? _preferredColumnDx;

  /// Test-only access to the preferred column state.
  @visibleForTesting
  double? get debugPreferredColumnDx => _preferredColumnDx;

  @visibleForTesting
  set debugPreferredColumnDx(double? value) => _preferredColumnDx = value;

  /// Saved mode before focus was lost so it can be restored on
  /// [onFocusGained].
  VimMode? _savedModeBeforeFocusLost;

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
    );
  }

  @override
  Widget buildSelectionHighlight(SelectionPaintContext ctx) =>
      fallback.buildSelectionHighlight(ctx);

  @override
  Widget buildBlockSelectionHighlight(BlockSelectionContext ctx) =>
      fallback.buildBlockSelectionHighlight(ctx);

  @override
  Position? onVerticalMove(CursorMoveContext ctx) {
    if (!_isVimActive) return fallback.onVerticalMove(ctx);

    // Seed the preferred column on the first vertical move so subsequent
    // 'j'/'k' presses preserve the horizontal position even when
    // intermediate lines are shorter. We don't override the position —
    // the editor's moveVerticallyInText handles the actual movement.
    _preferredColumnDx ??= ctx.caretLocalDx;
    return null;
  }

  @override
  Position? onHorizontalMove(CursorMoveContext ctx, {bool byWord = false}) {
    if (!_isVimActive) {
      return fallback.onHorizontalMove(ctx, byWord: byWord);
    }

    // In visual mode, allow full horizontal movement (selection expansion).
    if (controller.mode == VimMode.visual) {
      return fallback.onHorizontalMove(ctx, byWord: byWord);
    }

    // In normal mode ('h' / 'l'): do NOT cross line boundaries.
    // Let the fallback compute the candidate, then validate it stays
    // within the same line.
    final candidate = fallback.onHorizontalMove(ctx, byWord: byWord);
    if (candidate == null) return null;

    final rp = ctx.renderParagraph ?? ctx.delegate.getRenderParagraph();
    if (rp == null) return candidate; // can't validate, trust fallback

    final tp = rp.textPainter;
    final tpCurrent = ctx.currentOffset + ctx.textShift;
    final tpCandidate = candidate.offset + ctx.textShift;

    // Same line? Compare the line range of both positions.
    final currentLine = tp.getLineBoundary(TextPosition(offset: tpCurrent));
    final candidateLine = tp.getLineBoundary(TextPosition(offset: tpCandidate));
    if (currentLine.start != candidateLine.start) {
      return null; // blocked: would cross line boundary
    }

    // Update preferred column from the new position.
    _preferredColumnDx = ctx.delegate.getCaretLocalDx(candidate.offset);
    return candidate;
  }

  @override
  Position? onMoveToLineStart(CursorMoveContext ctx) {
    if (!_isVimActive) return fallback.onMoveToLineStart(ctx);

    // Vim '0': jump to the first character of the current line
    // (after the first-line indent WidgetSpan).
    // The RenderParagraph gives us the line boundary directly.
    final rp = ctx.renderParagraph ?? ctx.delegate.getRenderParagraph();
    if (rp != null) {
      final tp = rp.textPainter;
      final tpOffset = ctx.currentOffset + ctx.textShift;
      final lineRange = tp.getLineBoundary(TextPosition(offset: tpOffset));
      final lineStart =
          (lineRange.start - ctx.textShift).clamp(0, ctx.delegate.end().offset);
      return Position(path: ctx.node.path, offset: lineStart);
    }

    // Fallback: first character after textShift.
    return Position(path: ctx.node.path, offset: ctx.textShift);
  }

  @override
  Position? onMoveToLineEnd(CursorMoveContext ctx) {
    if (!_isVimActive) return fallback.onMoveToLineEnd(ctx);

    final rp = ctx.renderParagraph ?? ctx.delegate.getRenderParagraph();
    if (rp != null) {
      final tp = rp.textPainter;
      final tpOffset = ctx.currentOffset;
      final lineRange = tp.getLineBoundary(TextPosition(offset: tpOffset));
      // lineRange.end is exclusive; subtract textShift and clamp.
      final lineEnd = lineRange.end;
      final maxOffset = ctx.delegate.end().offset;
      if (lineEnd > 0 && lineEnd <= maxOffset) {
        // In visual mode, $ places the cursor on the last character.
        // In normal mode, we also want the last character (vim's $
        // behavior moves to the last non-whitespace, but for now we
        // keep it simple).
        return Position(path: ctx.node.path, offset: lineEnd);
      }
      return Position(
        path: ctx.node.path,
        offset: lineEnd.clamp(0, maxOffset),
      );
    }
    return fallback.onMoveToLineEnd(ctx);
  }

  @override
  Position? onPageUp(CursorMoveContext ctx) {
    if (!_isVimActive) return fallback.onPageUp(ctx);
    // Vim Ctrl-U: scroll up half a page. Delegate the actual pixel
    // math to the fallback (which goes through moveVerticallyInText).
    return null;
  }

  @override
  Position? onPageDown(CursorMoveContext ctx) {
    if (!_isVimActive) return fallback.onPageDown(ctx);
    // Vim Ctrl-D: scroll down half a page.
    return null;
  }

  @override
  MoveIntention? onTryMove(MoveAttemptContext ctx) {
    if (!_isVimActive) return fallback.onTryMove(ctx);

    // In normal mode, prevent moves that would leave the document.
    // Cancel the move entirely when the target is null or invalid.
    // This keeps the cursor from wrapping around or jumping to
    // unexpected positions.
    if (ctx.targetPosition.offset < 0) return const MoveIntention.cancel();

    return null;
  }

  @override
  void onMoveCompleted(MoveCompletedContext ctx) {
    if (!_isVimActive) {
      fallback.onMoveCompleted(ctx);
      return;
    }

    // After horizontal moves (h/l/w/b/e), clear the preferred column
    // so the next j/k re-seeds from the new horizontal position.
    if (ctx.direction != MoveDirection.up &&
        ctx.direction != MoveDirection.down) {
      _preferredColumnDx = null;
    }
    // For vertical moves: keep _preferredColumnDx unchanged so the
    // user's intended column survives short lines (vim-like behavior).
  }

  @override
  void onSelectionStarted(SelectionLifecycleContext ctx) =>
      fallback.onSelectionStarted(ctx);

  @override
  void onSelectionEnded(SelectionLifecycleContext ctx) =>
      fallback.onSelectionEnded(ctx);

  @override
  void onFocusGained(FocusLifecycleContext ctx) {
    if (!_isVimActive) {
      fallback.onFocusGained(ctx);
      return;
    }
    // Restore the mode that was active before focus was lost, if any.
    if (_savedModeBeforeFocusLost != null) {
      switch (_savedModeBeforeFocusLost!) {
        case VimMode.normal:
          controller.enterNormalMode();
        case VimMode.visual:
          controller.enterVisualMode();
        case VimMode.insert:
          controller.enterInsertMode();
      }
      _savedModeBeforeFocusLost = null;
    }
  }

  @override
  void onFocusLost(FocusLifecycleContext ctx) {
    if (!controller.enabled) {
      fallback.onFocusLost(ctx);
      return;
    }
    // Keep a snapshot of the current mode so we can restore later.
    _savedModeBeforeFocusLost = controller.mode;
    // Clear the preferred column — it's stale after focus loss.
    _preferredColumnDx = null;
  }

  @override
  List<Rect>? onSelectionRectsMeasured(SelectionMeasureContext ctx) {
    // In visual mode, expand selection rects to block-cursor width
    // so the highlight matches the visual block cursor appearance.
    return fallback.onSelectionRectsMeasured(ctx);
  }

  Color _resolveColor(VimCursorStyle style, Color fallback) {
    if (style.color != null) {
      return style.color!.withValues(alpha: style.opacity);
    }
    return fallback.withValues(alpha: style.opacity);
  }

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

  /// Returns the effective [Rect] that its similar to the default
  /// appearance of vim cursor
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
