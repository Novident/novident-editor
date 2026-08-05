import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_core/novident_editor_core.dart';

/// Extension on [Path] for selection-related operations.
extension PathSelectionExtension on Path {
  /// Returns `true` when this path falls inside [selection].
  ///
  /// If [isSameDepth] is true, the path must also have the same depth
  /// as the selection start.
  bool inSelection(
    Selection? selection, {
    bool isSameDepth = false,
  }) {
    selection = selection?.normalized;
    bool result = selection != null &&
        selection.start.path <= this &&
        this <= selection.end.path;
    if (isSameDepth) {
      return result && selection.start.path.length == length;
    }
    return result;
  }
}
