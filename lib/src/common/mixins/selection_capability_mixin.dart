import 'package:flutter/widgets.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';
import 'package:novident_editor/src/document/selection/selection.dart';

mixin SelectionCapabilityMixin<T extends StatefulWidget> on State<T> {
  /// Returns the [Rect] representing the block selection in current widget.
  ///
  /// Normally, the rect should not include the action menu area.
  Rect getBlockRect({bool shiftWithBaseOffset = false});

  /// Returns the [NodeSelection] surrounded by start and end
  ///   in current widget.
  ///
  /// [start] and [end] are the offsets under the global coordinate system.
  ///
  DocumentSelection getSelectionInRange(Offset start, Offset end);

  /// Returns a [List] of the [Rect] area within selection
  ///   in current widget.
  ///
  /// The return result must be a [List] of the [Rect]
  ///   under the local coordinate system.
  List<Rect> getRectsInSelection(
    DocumentSelection selection, {
    bool shiftWithBaseOffset = false,
  });

  /// Returns [Position] for the offset in current widget.
  ///
  /// [start] is the offset of the global coordination system.
  NodeSelection getSelectionPositionInOffset(Offset start);

  /// Returns [Rect] for the position in current widget.
  ///
  /// The return result must be an offset of the local coordinate system.
  Rect? getCursorRectInPosition(
    NodeSelection selectionPosition, {
    bool shiftWithBaseOffset = false,
  }) {
    return null;
  }

  /// Return global offset from local offset.
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  });

  NodeSelection start();
  NodeSelection end();

  /// For [TextNode] only.
  ///
  /// Only the widget rendered by [TextNode] need to implement the detail,
  ///   and the rest can return null.
  TextSelection? getTextSelectionInSelection(DocumentSelection selection) => null;

  /// For [TextNode] only.
  ///
  /// Only the widget rendered by [TextNode] need to implement the detail,
  ///   and the rest can return null.
  DocumentSelection? getWordEdgeInOffset(Offset start) => null;

  /// For [TextNode] only.
  ///
  /// Only the widget rendered by [TextNode] need to implement the detail,
  ///   and the rest can return null.
  DocumentSelection? getWordBoundaryInOffset(Offset start) => null;

  /// For [TextNode] only.
  ///
  /// Only the widget rendered by [TextNode] need to implement the detail,
  ///   and the rest can return null.
  DocumentSelection? getWordBoundaryInPosition(NodeSelection position) => null;

  bool get shouldCursorBlink => true;

  Rect transformRectToGlobal(
    Rect r, {
    bool shiftWithBaseOffset = false,
  }) {
    final Offset topLeft = localToGlobal(
      r.topLeft,
      shiftWithBaseOffset: shiftWithBaseOffset,
    );
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      r.width,
      r.height,
    );
  }

  TextDirection textDirection() => TextDirection.ltr;
}
