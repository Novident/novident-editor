import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_core/src/selection.dart';

/// Extension on [Node] for selection-related operations.
extension NodeSelectionExtension on Node {
  /// Returns `true` when this node's path falls inside [selection].
  bool inSelection(Selection selection) {
    if (selection.start.path <= selection.end.path) {
      return selection.start.path <= path && path <= selection.end.path;
    } else {
      return selection.end.path <= path && path <= selection.start.path;
    }
  }
}
