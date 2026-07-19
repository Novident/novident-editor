import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/base_component/selection/selection_area_painter.dart';
import 'package:novident_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart';
import 'package:novident_editor/src/render/selection/cursor.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final _deepEqual = const DeepCollectionEquality().equals;

enum BlockSelectionType {
  cursor,
  selection,
  block,
}

/// [BlockSelectionArea] is a widget that renders the selection area or the cursor of a block.
class BlockSelectionArea extends StatefulWidget {
  const BlockSelectionArea({
    super.key,
    required this.node,
    required this.delegate,
    required this.listenable,
    required this.cursorColor,
    required this.selectionColor,
    required this.blockColor,
    this.supportTypes = const [
      BlockSelectionType.cursor,
      BlockSelectionType.selection,
    ],
  });

  // get the cursor rect or selection rects from the delegate
  final SelectableMixin delegate;

  // get the selection from the listenable
  final ValueListenable<Selection?> listenable;

  // the color of the cursor
  final Color cursorColor;

  // the color of the selection
  final Color selectionColor;

  final Color blockColor;

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

        final editorState = context.read<EditorState>();
        if (editorState.selectionType == SelectionType.block) {
          if (!widget.supportTypes.contains(BlockSelectionType.block) ||
              !path.inSelection(selection, isSameDepth: true) ||
              prevBlockRect == null) {
            return sizedBox;
          }
          final builder = editorState.service.rendererService
              .blockComponentBuilder(widget.node.type);
          final padding = builder?.configuration.blockSelectionAreaMargin(
            widget.node,
          );
          return Positioned.fromRect(
            rect: prevBlockRect!,
            child: Container(
              margin: padding,
              decoration: BoxDecoration(
                color: widget.blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }
        // show the cursor when the selection is collapsed
        else if (selection.isCollapsed) {
          if (!widget.supportTypes.contains(BlockSelectionType.cursor) ||
              prevCursorRect == null) {
            return sizedBox;
          }
          final editorState = context.read<EditorState>();
          final dragMode =
              editorState.selectionExtraInfo?[selectionDragModeKey];
          var rect = prevCursorRect!;
          var cursorStyle = widget.delegate.cursorStyle;
          var shouldBlink = widget.delegate.shouldCursorBlink &&
              dragMode != MobileSelectionDragMode.cursor;
          var color = widget.cursorColor;
          // consult the optional caret customizer (e.g. vim block cursor).
          final appearance = editorState.cursorAppearanceBuilder?.call(
            widget.node,
            selection,
            selection.start,
          );
          if (appearance != null) {
            rect = appearance.rectBuilder?.call(rect) ?? rect;
            cursorStyle = appearance.style ?? cursorStyle;
            shouldBlink = appearance.shouldBlink ?? shouldBlink;
            color = appearance.color ?? color;
          }
          final cursor = Cursor(
            key: cursorKey,
            rect: rect,
            shouldBlink: shouldBlink,
            cursorStyle: cursorStyle,
            color: color,
          );
          // force to show the cursor
          cursorKey.currentState?.unwrapOrNull<CursorState>()?.show();
          return cursor;
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
          return SelectionAreaPaint(
            rects: prevSelectionRects!,
            selectionColor: widget.selectionColor,
          );
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
    final editorState = context.read<EditorState>();
    final appearance = editorState.cursorAppearanceBuilder?.call(
      widget.node,
      rawSelection,
      head,
    );
    if (appearance == null || !appearance.paintOnExpandedSelection) {
      return null;
    }
    final headRect = prevCursorRect;
    if (headRect == null) {
      return null;
    }
    return Cursor(
      key: cursorKey,
      rect: appearance.rectBuilder?.call(headRect) ?? headRect,
      shouldBlink: appearance.shouldBlink ?? false,
      cursorStyle: appearance.style ?? widget.delegate.cursorStyle,
      color: appearance.color ?? widget.cursorColor,
    );
  }

  /// Measures the caret rect at the moving head of an expanded selection
  /// when the cursor customizer wants it painted (e.g. vim visual mode).
  ///
  /// Only called from the post-frame pass, where layout is complete.
  Rect? _expandedSelectionHeadRect() {
    final raw = widget.listenable.value;
    final head = raw?.end;
    if (raw == null ||
        head == null ||
        raw.isCollapsed ||
        !head.path.equals(widget.node.path)) {
      return null;
    }
    final editorState = context.read<EditorState>();
    final appearance = editorState.cursorAppearanceBuilder?.call(
      widget.node,
      raw,
      head,
    );
    if (appearance == null || !appearance.paintOnExpandedSelection) {
      return null;
    }
    // the appearance may re-anchor the painted head (e.g. vim keeps the
    // block on the last selected character); only honored within this
    // same block.
    var target = appearance.position ?? head;
    if (!target.path.equals(widget.node.path)) {
      target = head;
    }
    return widget.delegate.getCursorRectInPosition(target);
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
          context.read<EditorState>().selectionType == SelectionType.block) {
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
        final rect = widget.delegate.getCursorRectInPosition(selection.start);
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
        final rect = _expandedSelectionHeadRect();
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
    prevCursorRect = null;
    // a selection change may bring this block into (or out of) the
    // selection: run one measurement pass on the next frame.
    _schedulePoll();
  }
}
