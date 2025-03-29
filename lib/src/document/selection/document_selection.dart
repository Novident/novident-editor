import 'package:novident_editor/src/document/selection/selection.dart';

class DocumentSelection {
  final NodeSelection start;
  final NodeSelection end;

  DocumentSelection({
    required this.start,
    required this.end,
  });

  bool get isCollapsed => start == end;

  DocumentSelection copyWith({NodeSelection? start, NodeSelection? end}) {
    return DocumentSelection(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}
