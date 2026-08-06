import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

final _deepEqual = const DeepCollectionEquality().equals;

/// [BlockSelectionArea] is a widget that renders the selection area or the cursor of a block.
class BlockSelectionArea extends StatefulWidget {
  const BlockSelectionArea({
    super.key,
    required this.node,
    required this.delegate,
    required this.listenable,
    required this.host,
    required this.cursorColor,
    required this.selectionColor,
    required this.blockColor,
    this.renderer = const DefaultSelectionRenderer(),
    this.supportTypes = const [
      BlockSelectionType.cursor,
      BlockSelectionType.selection,
    ],
  });

  // get the cursor rect or selection rects from the delegate
  final SelectableMixin delegate;

  // get the selection from the listenable
  final ValueListenable<Selection?> listenable;

  /// Host providing editor-level state (selection mode, cursor customization, etc.)
  /// When null, host-dependent features are disabled.
  final BlockSelectionHost host;

  // the color of the cursor
  final Color cursorColor;

  // the color of the selection
  final Color selectionColor;

  final Color blockColor;

  /// Custom selection/cursor renderer. Defaults to [DefaultSelectionRenderer].
  final SelectionRenderer renderer;

  // the node of the block
  final Node node;

  final List<BlockSelectionType> supportTypes;

  @override
  State<BlockSelectionArea> createState() => _BlockSelectionAreaState();
}

class _BlockSelectionAreaState extends State<BlockSelectionArea> {
  // We need to keep the key to refresh the cursor status when typing continuously.
  late GlobalKey cursorKey = GlobalKey(
    debugLabel: 'cursor_${widget.node.path}',
  );

  // keep the previous cursor rect to avoid unnecessary rebuild
  Rect? prevCursorRect;
  // keep the previous selection rects to avoid unnecessary rebuild
  List<Rect>? prevSelectionRects;
  // keep the block selection rect to avoid unnecessary rebuild
  Rect? prevBlockRect;

  // whether a measurement pass is already scheduled for the next frame.
  bool _pollScheduled = false;

  @override
  void initState() {
    super.initState();

    _schedulePoll();
    widget.listenable.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onSelectionChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      key: ValueKey(widget.node.id + widget.supportTypes.toString()),
      valueListenable: widget.listenable,
      builder: ((context, value, child) {
        final sizedBox = child ?? const SizedBox.shrink();
        final selection = value?.normalized;

        if (selection == null) {
          return sizedBox;
        }

        final path = widget.node.path;
        if (!path.inSelection(selection)) {
          return sizedBox;
        }

        final host = widget.host;
        final renderer = host.selectionRenderer ?? widget.renderer;
        if (host.isBlockSelectionMode()) {
          if (!widget.supportTypes.contains(BlockSelectionType.block) ||
              !path.inSelection(selection, isSameDepth: true) ||
              prevBlockRect == null) {
            return sizedBox;
          }
          final padding = host.blockSelectionMargin(widget.node);
          final blockCtx = BlockSelectionContext(
            node: widget.node,
            rect: prevBlockRect!,
            color: widget.blockColor,
            margin: padding,
          );
          return renderer.buildBlockSelectionHighlight(blockCtx);
        }
        // show the cursor when the selection is collapsed
        else if (selection.isCollapsed) {
          if (!widget.supportTypes.contains(BlockSelectionType.cursor) ||
              prevCursorRect == null) {
            return sizedBox;
          }
          final host = widget.host;
          final dragMode = host.selectionDragModeValue();
          final renderer = host.selectionRenderer ?? widget.renderer;
          var rect = prevCursorRect!;
          var cursorStyle = widget.delegate.cursorStyle;
          var shouldBlink = widget.delegate.shouldCursorBlink &&
              dragMode != 'cursor';
          var color = widget.cursorColor;
          final appearance = host.customizeCursor(
            node: widget.node,
            selection: selection,
            position: selection.start,
          );
          if (appearance != null) {
            rect = appearance.rectBuilder?.call(rect) ?? rect;
            cursorStyle = appearance.style ?? cursorStyle;
            shouldBlink = appearance.shouldBlink ?? shouldBlink;
            color = appearance.color ?? color;
          }
          final cursorCtx = CursorPaintContext(
            node: widget.node,
            selection: selection,
            position: selection.start,
            rect: rect,
            color: color,
            style: cursorStyle,
            shouldBlink: shouldBlink,
            isExpandedHead: false,
            textDirection: widget.delegate.textDirection(),
            delegate: widget.delegate,
          );
          return renderer.buildCursor(cursorCtx);
        } else {
          // optionally paint the caret at the moving head of the expanded
          // selection (e.g. vim visual mode), above the block content.
          if (widget.supportTypes.contains(BlockSelectionType.cursor)) {
            final headCursor = _buildExpandedSelectionCursor(context, value);
            if (headCursor != null) {
              return headCursor;
            }
          }
          // show the selection area when the selection is not collapsed
          if (!widget.supportTypes.contains(BlockSelectionType.selection) ||
              prevSelectionRects == null ||
              prevSelectionRects!.isEmpty ||
              (prevSelectionRects!.length == 1 &&
                  prevSelectionRects!.first.width == 0)) {
            return sizedBox;
          }
          final selCtx = SelectionPaintContext(
            node: widget.node,
            selection: selection,
            rects: prevSelectionRects!,
            color: widget.selectionColor,
            textDirection: widget.delegate.textDirection(),
          );
          return renderer.buildSelectionHighlight(selCtx);
        }
      }),
      child: const SizedBox.shrink(),
    );
  }

  /// Paints the caret at the head of an expanded selection when the
  /// [EditorState.cursorAppearanceBuilder] requests it.
  ///
  /// [rawSelection] is the non-normalized selection: its end is the moving
  /// head. The rect itself comes from [prevCursorRect], measured in the
  /// post-frame pass (see [_updateSelectionIfNeeded]) — never during build,
  /// where the render objects may still need layout.
  Widget? _buildExpandedSelectionCursor(
    BuildContext context,
    Selection? rawSelection,
  ) {
    final head = rawSelection?.end;
    if (rawSelection == null ||
        head == null ||
        !head.path.equals(widget.node.path)) {
      return null;
    }
    final host = widget.host;
    final renderer = host.selectionRenderer ?? widget.renderer;
    final appearance = host.customizeCursor(
      node: widget.node,
      selection: rawSelection,
      position: head,
    );
    // Gate: either the legacy CursorAppearance pipeline or the new
    // SelectionRenderer requests painting of the expanded-selection head.
    final viaLegacy = appearance != null && appearance.paintOnExpandedSelection;
    final viaRenderer = renderer.paintExpandedHeadCursor;
    if (!viaLegacy && !viaRenderer) {
      return null;
    }
    final headRect = prevCursorRect;
    if (headRect == null) {
      return null;
    }
    final rect = appearance?.rectBuilder?.call(headRect) ?? headRect;
    final cursorCtx = CursorPaintContext(
      node: widget.node,
      selection: rawSelection,
      position: head,
      rect: rect,
      color: appearance?.color ?? widget.cursorColor,
      style: appearance?.style ?? widget.delegate.cursorStyle,
      shouldBlink: appearance?.shouldBlink ?? false,
      isExpandedHead: true,
      textDirection: widget.delegate.textDirection(),
      delegate: widget.delegate,
    );
    return renderer.buildExpandedHeadCursor(cursorCtx);
  }
  /// when the cursor customizer wants it painted (e.g. vim visual mode).
  ///
  /// Only called from the post-frame pass, where layout is complete.
  ///
  /// Returns both the effective target position and the measured rect,
  /// so the caller can use the same position for [onCursorRectMeasured].
  ({Position position, Rect rect})? _expandedSelectionHeadPositionAndRect() {
    final raw = widget.listenable.value;
    final head = raw?.end;
    if (raw == null ||
        head == null ||
        raw.isCollapsed ||
        !head.path.equals(widget.node.path)) {
      return null;
    }
    final host = widget.host;
    final renderer = host.selectionRenderer ?? widget.renderer;
    final appearance = host.customizeCursor(
      node: widget.node,
      selection: raw,
      position: head,
    );
    final viaLegacy = appearance != null && appearance.paintOnExpandedSelection;
    final viaRenderer = renderer.paintExpandedHeadCursor;
    if (!viaLegacy && !viaRenderer) {
      return null;
    }
    var target = appearance?.position ??
        (viaRenderer ? renderer.expandedHeadPosition(raw) : null) ??
        head;
    if (!target.path.equals(widget.node.path)) {
      target = head;
    }
    final rect = widget.delegate.getCursorRectInPosition(target);
    if (rect == null) return null;
    return (position: target, rect: rect);
  }

  /// Schedules one measurement pass for the next frame (deduplicated).
  void _schedulePoll() {
    if (_pollScheduled || !mounted) {
      return;
    }
    _pollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollScheduled = false;
      _updateSelectionIfNeeded();
    });
  }

  void _updateSelectionIfNeeded() {
    if (!mounted) {
      return;
    }

    final selection = widget.listenable.value?.normalized;
    final path = widget.node.path;

    // the current path is in the selection
    if (selection != null && path.inSelection(selection)) {
      if (widget.supportTypes.contains(BlockSelectionType.block) &&
          widget.host.isBlockSelectionMode()) {
        if (!path.inSelection(selection, isSameDepth: true)) {
          if (prevBlockRect != null) {
            setState(() {
              prevBlockRect = null;
              prevCursorRect = null;
              prevSelectionRects = null;
            });
          }
        } else {
          final rect = widget.delegate.getBlockRect();
          if (prevBlockRect != rect) {
            setState(() {
              prevBlockRect = rect;
              prevCursorRect = null;
              prevSelectionRects = null;
            });
          }
        }
      } else if (widget.supportTypes.contains(BlockSelectionType.cursor) &&
          selection.isCollapsed) {
        final rawRect = widget.delegate.getCursorRectInPosition(selection.start);
        var rect = rawRect;
        if (rect != null) {
          final measureCtx = CursorMeasureContext(
            node: widget.node,
            position: selection.start,
            delegate: widget.delegate,
            textDirection: widget.delegate.textDirection(),
            textShift: widget.delegate.textShift,
          );
          rect = (widget.host.selectionRenderer ?? widget.renderer).onCursorRectMeasured(measureCtx) ?? rect;
        }
        if (rect != prevCursorRect) {
          setState(() {
            prevCursorRect = rect;
            prevBlockRect = null;
            prevSelectionRects = null;
          });
        }
      } else if (widget.supportTypes.contains(BlockSelectionType.cursor) &&
          !selection.isCollapsed) {
        // expanded selection: cache the head caret rect for the cursor
        // customizer (e.g. vim visual mode). Measuring here — after the
        // frame — avoids touching render objects that need layout.
        final pr = _expandedSelectionHeadPositionAndRect();
        var rect = pr?.rect;
        if (rect != null && pr != null) {
          final measureCtx = CursorMeasureContext(
            node: widget.node,
            position: pr.position,
            delegate: widget.delegate,
            textDirection: widget.delegate.textDirection(),
            textShift: widget.delegate.textShift,
          );
          rect = (widget.host.selectionRenderer ?? widget.renderer)
                  .onCursorRectMeasured(measureCtx) ??
              rect;
        }
        if (rect != prevCursorRect) {
          setState(() {
            prevCursorRect = rect;
            prevBlockRect = null;
            prevSelectionRects = null;
          });
        }
      } else if (widget.supportTypes.contains(BlockSelectionType.selection)) {
        final rects = widget.delegate.getRectsInSelection(selection);
        if (!_deepEqual(rects, prevSelectionRects)) {
          setState(() {
            prevSelectionRects = rects;
            prevCursorRect = null;
            prevBlockRect = null;
          });
        }
      }
      // keep measuring while this block participates in the selection:
      // its layout can shift on every keystroke or window resize. Blocks
      // outside the selection stop polling (nothing painted, nothing to
      // track) and are re-armed by [_onSelectionChanged] — this turns the
      // former unconditional per-frame loop over EVERY mounted block into
      // O(selected blocks) work per frame.
      _schedulePoll();
    } else if (prevBlockRect != null ||
        prevSelectionRects != null ||
        prevCursorRect != null) {
      setState(() {
        prevBlockRect = null;
        prevSelectionRects = null;
        prevCursorRect = null;
      });
    }
  }

  void _onSelectionChanged() {
    // a selection change may bring this block into (or out of) the
    // selection: run one measurement pass on the next frame.
    _schedulePoll();
  }
}
