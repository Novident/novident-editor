import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/selection/selection.dart';

class DocumentSelection {
  final NodeSelection start;
  final NodeSelection end;

  DocumentSelection({
    required this.start,
    required this.end,
  });

  DocumentSelection.same({
    required String nodeId,
    required int index,
    required int startOffset,
    int? endOffset,
  })  : start = NodeSelection.collapsed(
          nodeId: nodeId,
          nodeIndex: index,
          offset: startOffset,
        ),
        end = NodeSelection.collapsed(
          nodeId: nodeId,
          nodeIndex: index,
          offset: endOffset ?? startOffset,
        );

  DocumentSelection.collapsed({required NodeSelection selection})
      : start = selection,
        end = selection;

  DocumentSelection.invalid()
      : start = NodeSelection.invalid(),
        end = NodeSelection.invalid();

  DocumentSelection copyWith({NodeSelection? start, NodeSelection? end}) {
    return DocumentSelection(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  String toString() => 'start = $start, end = $end';

  bool isNodeSelected(Node node) => start.nodeId == node.id || end.nodeId == node.id;

  /// Returns a Boolean indicating whether the selection's start and end points
  /// are at the same position.
  bool get isCollapsed => start == end;

  /// Returns a Boolean indicating whether the selection's start and end points
  /// are at the same nodeIndex.
  bool get isSingle => start.nodeIndex == end.nodeIndex;

  /// Returns a Boolean indicating whether the selection is forward.
  bool get isForward =>
      (start.nodeIndex > end.nodeIndex) ||
      (isSingle && start.selection.offset > end.selection.offset);

  /// Returns a Boolean indicating whether the selection is backward.
  bool get isBackward =>
      (start.nodeIndex < end.nodeIndex) ||
      (isSingle && start.selection.offset < end.selection.offset);

  /// Returns a normalized selection that direction is forward.
  DocumentSelection get normalized => isBackward ? copyWith() : reversed.copyWith();

  /// Returns a reversed selection.
  DocumentSelection get reversed => copyWith(start: end, end: start);

  /// Returns the offset in the starting position under the normalized selection.
  int get startIndex => normalized.start.selection.offset;

  /// Returns the offset in the ending position under the normalized selection.
  int get endIndex => normalized.end.selection.offset;

  int get length => endIndex - startIndex;

  /// Collapses the current selection to a single point.
  ///
  /// If [atStart] is true, the selection will be collapsed to the start point.
  /// If [atStart] is false, the selection will be collapsed to the end point.
  DocumentSelection collapse({bool atStart = false}) {
    if (atStart) {
      return copyWith(end: start);
    } else {
      return copyWith(start: end);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.toJson(),
      'end': end.toJson(),
    };
  }

  DocumentSelection shift(int offset) {
    return copyWith(
      start: start.copyWith(offset: start.offset + offset),
      end: end.copyWith(offset: end.offset + offset),
    );
  }
}
