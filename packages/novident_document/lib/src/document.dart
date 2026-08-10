import 'package:flutter/foundation.dart';

import 'document_tree.dart';
import 'node.dart';
import 'path.dart';
import 'attributes.dart';
import 'delta/text_delta.dart';

/// [Document] represents an Novident Editor document structure.
///
/// It stores the root of the document.
///
/// **DO NOT** directly mutate the properties of a [Document] object.
///
class Document {
  Document({
    required this.root,
  }) : tree = DocumentTree.fromRoot(root);

  /// Constructs a [Document] from a JSON structure.
  factory Document.fromJson(Map<String, dynamic> json) {
    assert(json['document'] is Map);

    final document = Map<String, Object>.from(json['document'] as Map);
    final root = Node.fromJson(document);
    return Document(root: root);
  }

  /// Creates a blank [Document] containing an empty root [Node].
  factory Document.blank({bool withInitialText = false}) {
    final root = Node(
      type: 'page',
      children: withInitialText
          ? [
              Node(
                type: 'paragraph',
                attributes: {
                  'delta': (Delta()..insert('')).toJson(),
                },
              )
            ]
          : [],
    );
    return Document(root: root);
  }

  /// The root [Node] of the [Document]
  final Node root;

  /// Fast index for O(1)/O(log n) lookups. Kept in sync with [root].
  @visibleForTesting
  final DocumentTree tree;

  /// First node of the document. O(1).
  Node? get first => tree.childAt(root, 0);

  /// Last node of the document. O(depth).
  Node? get last {
    final rootKids = tree.childrenOf(root);
    if (rootKids.isEmpty) return null;
    Node? current = rootKids.last;
    while (true) {
      final kids = tree.childrenOf(current!);
      if (kids.isEmpty) return current;
      current = kids.last;
    }
  }

  /// Must call this method when the [Document] is no longer needed.
  void dispose() {
    for (final node in tree.allNodes) {
      node.dispose();
    }
  }

  /// Returns the node at the given [path].
  Node? nodeAtPath(Path path) {
    return root.childAtPath(path);
  }

  /// Inserts [Node]s at the given [Path].
  ///
  /// Updates both the legacy [Node] tree AND the [DocumentTree] index.
  bool insert(Path path, Iterable<Node> nodes, {String id = ''}) {
    if (path.isEmpty || nodes.isEmpty) return false;

    final parent = tree.byId(id) ?? nodeAtPath(path.parent);
    if (parent == null) return false;

    for (var i = 0; i < nodes.length; i++) {
      final child = nodes.elementAt(i);
      final index = path.last + i;

      // 1. Update legacy tree.
      parent.insert(child, index: index);

      // 2. Sync DocumentTree index.
      tree.syncInsert(parent, child, index);
    }
    return true;
  }

  /// Deletes the [Node]s at the given [Path].
  ///
  /// Updates both the legacy [Node] tree AND the [DocumentTree] index.
  bool delete(Path path, [int length = 1, String id = '']) {
    if (path.isEmpty || length <= 0) return false;

    var target = tree.byId(id) ?? nodeAtPath(path);
    if (target == null) return false;

    while (target != null && length > 0) {
      final next = target.next;
      final parent = target.parent!;

      // 1. Update legacy tree.
      target.unlink();

      // 2. Sync DocumentTree index.
      tree.syncRemove(parent, target);

      target = next;
      length--;
    }
    return true;
  }

  /// Updates the [Node] at the given [Path].
  bool update(Path path, Attributes attributes) {
    if (path.isEmpty) {
      root.updateAttributes(attributes);
      return true;
    }
    final target = nodeAtPath(path);
    if (target == null) return false;
    target.updateAttributes(attributes);
    return true;
  }

  /// Updates the [Node] with [Delta] at the given [Path].
  ///
  /// Uses the native [TextDocument.applyDelta] path for O(log n)
  /// mutation instead of the legacy compose + re-serialize round-trip.
  bool updateText(Path path, Delta delta, {String? id}) {
    if (path.isEmpty) return false;
    final target = tree.byId(id ?? '') ?? tree.nodeAtPath(path);
    if (target == null) return false;
    target.applyTextDelta(delta);
    return true;
  }

  /// Returns whether the root [Node] does not contain any text.
  bool get isEmpty {
    final kids = tree.childrenOf(root);
    if (kids.isEmpty) return true;
    if (kids.length > 1) return false;

    final node = kids.first;
    final delta = node.delta;
    if (delta != null && (delta.isEmpty || delta.toPlainText().isEmpty)) {
      return true;
    }
    return false;
  }

  /// Encodes the [Document] into a JSON structure.
  Map<String, Object> toJson() {
    return {'document': root.toJson()};
  }
}
