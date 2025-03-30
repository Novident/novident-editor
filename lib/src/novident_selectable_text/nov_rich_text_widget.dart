import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:novident_editor/src/common/mixins/selection_capability_mixin.dart';
import 'package:novident_editor/src/document/delta/delta.dart';
import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';
import 'package:novident_editor/src/document/selection/selection.dart';

class NovRichTextWidget extends StatefulWidget {
  final Node node;
  final double? cursorHeight;
  final double cursorWidth;

  const NovRichTextWidget({
    super.key,
    required this.node,
    this.cursorHeight,
    this.cursorWidth = 2.0,
  });

  @override
  State<NovRichTextWidget> createState() => _NovRichTextWidgetState();
}

class _NovRichTextWidgetState extends State<NovRichTextWidget>
    with SelectionCapabilityMixin {
  final GlobalKey _richKey = GlobalKey();

  RenderParagraph? get _paragraph =>
      _richKey.currentContext?.findRenderObject() as RenderParagraph;

  @override
  Widget build(BuildContext context) {
    final Delta delta = widget.node.delta ?? Delta();
    // by now we only add plain text
    return RichText(
      key: _richKey,
      softWrap: true,
      text: TextSpan(
        text: delta.toPlainText(),
      ),
    );
  }

  @override
  NodeSelection end() {
    return NodeSelection(
      selection: TextPosition(offset: widget.node.delta?.toPlainText().length ?? 0),
      nodeId: widget.node.id,
      nodeIndex: widget.node.index,
    );
  }

  @override
  NodeSelection start() {
    return NodeSelection(
      selection: TextPosition(offset: 0),
      nodeId: widget.node.id,
      nodeIndex: widget.node.index,
    );
  }

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(NodeSelection selectionPosition,
      {bool shiftWithBaseOffset = false}) {
    if (kDebugMode && _paragraph?.debugNeedsLayout == true) {
      return null;
    }

    final delta = widget.node.delta;
    if (selectionPosition.offset < 0 ||
        (delta != null && selectionPosition.offset > delta.textLength)) {
      return null;
    }

    final textPosition = TextPosition(offset: selectionPosition.offset);
    /*double? placeholderCursorHeight =
        _placeholderRenderParagraph?.getFullHeightForCaret(textPosition);
    Offset? placeholderCursorOffset = _placeholderRenderParagraph?.getOffsetForCaret(
          textPosition,
          Rect.zero,
        ) ??
        Offset.zero;
    if (textDirection() == TextDirection.rtl) {
       if (widget.placeholderText.trim().isNotEmpty) {
        placeholderCursorOffset = placeholderCursorOffset.translate(
          _placeholderRenderParagraph?.size.width ?? 0,
          0,
        );
      }
    }
       */

    double? cursorHeight = _paragraph?.getFullHeightForCaret(textPosition);
    Offset? cursorOffset =
        _paragraph?.getOffsetForCaret(textPosition, Rect.zero) ?? Offset.zero;
    /*


    if (placeholderCursorHeight != null) {
      cursorHeight = max(cursorHeight ?? 0, placeholderCursorHeight);
    }

    if (delta?.isEmpty == true) {
      cursorOffset = placeholderCursorOffset;
    }
    */

    if (widget.cursorHeight != null && cursorHeight != null) {
      cursorOffset = Offset(
        cursorOffset.dx,
        cursorOffset.dy + (cursorHeight - widget.cursorHeight!) / 2,
      );
      cursorHeight = widget.cursorHeight;
    }
    final rect = Rect.fromLTWH(
      math.max<double>(0, cursorOffset.dx - (widget.cursorWidth / 2.0)),
      cursorOffset.dy,
      widget.cursorWidth,
      cursorHeight ?? 16.0,
    );
    return rect;
  }

  @override
  List<Rect> getRectsInSelection(
    DocumentSelection selection, {
    bool shiftWithBaseOffset = false,
    RenderParagraph? paragraph,
  }) {
    paragraph ??= _paragraph;
    if (kDebugMode && paragraph?.debugNeedsLayout == true) {
      return [];
    }
    final TextSelection? textSelection = textSelectionFromEditorSelection(selection);
    if (textSelection == null) {
      return [];
    }
    final List<Rect>? rects = paragraph
        ?.getBoxesForSelection(
          textSelection,
          boxHeightStyle: BoxHeightStyle.max,
        )
        .map((box) => box.toRect())
        .toList(growable: false);
    if (rects == null || rects.isEmpty) {
      /// If the rich text widget does not contain any text,
      /// there will be no selection boxes,
      /// so we need to return to the default selection.
      Offset position = Offset.zero;
      double height = paragraph?.size.height ?? 0.0;
      double width = 0;
      if (!selection.isCollapsed) {
        /// while selecting for an empty character, return a selection area
        /// with width of 2
        final TextPosition textPosition = TextPosition(offset: textSelection.baseOffset);
        position = paragraph?.getOffsetForCaret(
              textPosition,
              Rect.zero,
            ) ??
            position;
        height = paragraph?.getFullHeightForCaret(textPosition) ?? height;
        width = 2;
      }
      return <Rect>[
        Rect.fromLTWH(
          position.dx,
          position.dy,
          width,
          height,
        ),
      ];
    }
    return rects;
  }

  @override
  DocumentSelection getSelectionInRange(Offset start, Offset end) {
    final Delta? delta = widget.node.delta;
    if (delta == null) {
      return DocumentSelection.same(
        index: widget.node.index,
        nodeId: widget.node.id,
        startOffset: 0,
        endOffset: 0,
      );
    }
    final Offset localStart = _paragraph?.globalToLocal(start) ?? Offset.zero;
    final Offset localEnd = _paragraph?.globalToLocal(end) ?? Offset.zero;
    final int baseOffset = _paragraph?.getPositionForOffset(localStart).offset ?? -1;
    final int extentOffset = _paragraph?.getPositionForOffset(localEnd).offset ?? -1;
    return DocumentSelection.same(
      index: widget.node.index,
      nodeId: widget.node.id,
      startOffset: baseOffset,
      endOffset: extentOffset,
    );
  }

  @override
  NodeSelection getSelectionPositionInOffset(Offset start) {
    final Offset offset = _paragraph?.globalToLocal(start) ?? Offset.zero;
    final int baseOffset = _paragraph?.getPositionForOffset(offset).offset ?? -1;
    return NodeSelection(
      nodeIndex: widget.node.index,
      nodeId: widget.node.id,
      selection: TextPosition(offset: baseOffset),
    );
  }

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    return _paragraph?.localToGlobal(offset) ?? Offset.zero;
  }

  @override
  DocumentSelection? getWordBoundaryInOffset(Offset offset) {
    final Offset localOffset = _paragraph?.globalToLocal(offset) ?? Offset.zero;
    final TextPosition textPosition =
        _paragraph?.getPositionForOffset(localOffset) ?? const TextPosition(offset: 0);
    final TextRange textRange =
        _paragraph?.getWordBoundary(textPosition) ?? TextRange.empty;
    final NodeSelection start = NodeSelection(
      nodeIndex: widget.node.index,
      nodeId: widget.node.id,
      selection: TextPosition(
        offset: textRange.start,
      ),
    );
    final NodeSelection end = NodeSelection(
      nodeIndex: widget.node.index,
      nodeId: widget.node.id,
      selection: TextPosition(
        offset: textRange.end,
      ),
    );
    return DocumentSelection(start: start, end: end);
  }

  @override
  DocumentSelection? getWordBoundaryInPosition(NodeSelection position) {
    final TextPosition textPosition = TextPosition(offset: position.offset);
    final TextRange textRange =
        _paragraph?.getWordBoundary(textPosition) ?? TextRange.empty;
    final NodeSelection start = NodeSelection(
      nodeIndex: widget.node.index,
      nodeId: widget.node.id,
      selection: TextPosition(
        offset: textRange.start,
      ),
    );
    final NodeSelection end = NodeSelection(
      nodeIndex: widget.node.index,
      nodeId: widget.node.id,
      selection: TextPosition(
        offset: textRange.end,
      ),
    );
    return DocumentSelection(start: start, end: end);
  }

  @override
  DocumentSelection? getWordEdgeInOffset(Offset offset) {
    final Offset localOffset = _paragraph?.globalToLocal(offset) ?? Offset.zero;
    final TextPosition textPosition =
        _paragraph?.getPositionForOffset(localOffset) ?? const TextPosition(offset: 0);
    final TextRange textRange =
        _paragraph?.getWordBoundary(textPosition) ?? TextRange.empty;
    final int wordEdgeOffset =
        textPosition.offset <= textRange.start ? textRange.start : textRange.end;

    return DocumentSelection.collapsed(
      selection: NodeSelection(
        nodeIndex: widget.node.index,
        nodeId: widget.node.id,
        selection: TextPosition(
          offset: wordEdgeOffset,
        ),
      ),
    );
  }

  TextSelection? textSelectionFromEditorSelection(DocumentSelection? selection) {
    if (selection == null) {
      return null;
    }

    final DocumentSelection normalized = selection.normalized;
    final int index = widget.node.index;
    if (index < normalized.start.nodeIndex || index > normalized.end.nodeIndex) {
      return null;
    }

    final int? length = widget.node.delta?.length;
    if (length == null) {
      return null;
    }

    TextSelection? textSelection;

    if (normalized.isSingle) {
      if (index == normalized.start.nodeIndex) {
        if (normalized.isCollapsed) {
          textSelection = TextSelection.collapsed(
            offset: normalized.startIndex,
          );
        } else {
          textSelection = TextSelection(
            baseOffset: normalized.startIndex,
            extentOffset: normalized.endIndex,
          );
        }
      }
    } else {
      if (index == normalized.start.nodeIndex) {
        textSelection = TextSelection(
          baseOffset: normalized.startIndex,
          extentOffset: length,
        );
      } else if (index == normalized.end.nodeIndex) {
        textSelection = TextSelection(
          baseOffset: 0,
          extentOffset: normalized.endIndex,
        );
      } else {
        textSelection = TextSelection(
          baseOffset: 0,
          extentOffset: length,
        );
      }
    }
    return textSelection;
  }
}
