import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_core/novident_editor_core.dart';

/// Extension on [Node] for selection-related operations.
extension NodeSelectionExtension on Node {
  /// Returns `true` when this node's path falls inside [selection].
  bool inSelection(Selection selection) {
    final nodePath = path;
    if (selection.start.path <= selection.end.path) {
      return selection.start.path <= nodePath && nodePath <= selection.end.path;
    } else {
      return selection.end.path <= nodePath && nodePath <= selection.start.path;
    }
  }

  /// Walks up the tree to find the first ancestor (or self) matching [test].
  Node? findParent(bool Function(Node element) test) {
    if (test(this)) return this;
    final parent = this.parent;
    return parent?.findParent(test);
  }
}
