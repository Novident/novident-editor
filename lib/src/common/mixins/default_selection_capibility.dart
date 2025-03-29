import 'package:flutter/widgets.dart';
import 'package:novident_editor/src/common/mixins/selection_capability_mixin.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';
import 'package:novident_editor/src/document/selection/selection.dart';

mixin DefaultSelectionCapibility {
  GlobalKey get forwardKey;
  GlobalKey get containerKey;
  GlobalKey get blockComponentKey;

  SelectionCapabilityMixin<StatefulWidget> get forward =>
      forwardKey.currentState as SelectionCapabilityMixin<StatefulWidget>;

  Offset baseOffset({
    bool shiftWithBaseOffset = false,
  }) {
    if (shiftWithBaseOffset) {
      final RenderObject? parentBox = containerKey.currentContext?.findRenderObject();
      final RenderObject? childBox = forwardKey.currentContext?.findRenderObject();
      if (parentBox is RenderBox && childBox is RenderBox) {
        return childBox.localToGlobal(Offset.zero, ancestor: parentBox);
      }
    }
    return Offset.zero;
  }

  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = containerKey.currentContext?.findRenderObject();
    final childBox = blockComponentKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && childBox is RenderBox) {
      final offset = childBox.localToGlobal(Offset.zero, ancestor: parentBox);
      final size = parentBox.size;
      if (shiftWithBaseOffset) {
        return offset & (size - offset as Size);
      }
      return Offset.zero & (size - offset as Size);
    }
    return Rect.zero;
  }

  NodeSelection getSelectionPositionInOffset(Offset start) =>
      forward.getSelectionPositionInOffset(start);

  Rect? getCursorRectInPosition(
    NodeSelection selectionPosition, {
    bool shiftWithBaseOffset = false,
  }) =>
      forward.getCursorRectInPosition(selectionPosition)?.shift(
            baseOffset(
              shiftWithBaseOffset: shiftWithBaseOffset,
            ),
          );

  List<Rect> getRectsInSelection(
    DocumentSelection selection, {
    bool shiftWithBaseOffset = false,
  }) =>
      forward
          .getRectsInSelection(selection)
          .map(
            (rect) => rect.shift(
              baseOffset(
                shiftWithBaseOffset: shiftWithBaseOffset,
              ),
            ),
          )
          .toList(growable: false);

  DocumentSelection getSelectionInRange(Offset start, Offset end) =>
      forward.getSelectionInRange(start, end);

  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) =>
      forward.localToGlobal(offset) -
      baseOffset(
        shiftWithBaseOffset: shiftWithBaseOffset,
      );

  DocumentSelection? getWordEdgeInOffset(Offset offset) =>
      forward.getWordEdgeInOffset(offset);

  DocumentSelection? getWordBoundaryInOffset(Offset offset) =>
      forward.getWordBoundaryInOffset(offset);

  DocumentSelection? getWordBoundaryInPosition(NodeSelection selectionPosition) =>
      forward.getWordBoundaryInPosition(selectionPosition);

  NodeSelection start() => forward.start();

  NodeSelection end() => forward.end();

  TextDirection textDirection() =>
      forwardKey.currentState != null ? forward.textDirection() : TextDirection.ltr;
}
