import 'package:novident_document/novident_document.dart';
import 'package:novident_editor/src/core/location/selection.dart';

/// Editor-specific extension on [Path] that depends on [Selection].
///
/// This was extracted from the core [Path] definition so that the
/// `novident_document` package does not need to know about the
/// editor-level [Selection] type.
extension DocumentPathExtensions on Path {
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
