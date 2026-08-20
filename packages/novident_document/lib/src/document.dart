import 'dart:collection';

import 'node.dart';
import 'node_iterator.dart';
import 'path.dart';
import 'attributes.dart';
import 'delta/text_delta.dart';
import 'delta_change.dart';

/// [Document] represents an Novident Editor document structure.
///
/// It stores the root of the document.
///
/// **DO NOT** directly mutate the properties of a [Document] object.
///
class Document {
  Document({
    required this.root,
  });

  /// Constructs a [Document] from a JSON structure.
  ///
  /// _Example of a [Document] in JSON format:_
  /// ```
  /// {
  ///   'document': {
  ///     'type': 'page',
  ///     'children': [
  ///       {
  ///         'type': 'paragraph',
  ///         'data': {
  ///           'delta': [
  ///             { 'insert': 'Welcome ' },
  ///             { 'insert': 'to ' },
  ///             { 'insert': 'Novident!' }
  ///           ]
  ///         }
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  ///
  factory Document.fromJson(Map<String, dynamic> json) {
    assert(json['document'] is Map);

    final document = Map<String, Object>.from(json['document'] as Map);
    final root = Node.fromJson(document);
    return Document(root: root);
  }

  /// Creates a blank [Document] containing an empty root [Node].
  ///
  /// If [withInitialText] is true, the document will contain an empty
  /// paragraph [Node].
  ///
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
    return Document(
      root: root,
    );
  }

  /// The root [Node] of the [Document]
  final Node root;

  /// First node of the document.
  Node? get first => root.children.firstOrNull;

  /// Last node of the document.
  Node? get last {
    Node? current = root.children.lastOrNull;
    while (current != null && current.children.isNotEmpty) {
      current = current.children.last;
    }
    return current;
  }

  /// Must call this method when the [Document] is no longer needed.
  void dispose() {
    final nodes = NodeIterator(document: this, startNode: root).toList();
    for (final node in nodes) {
      node.dispose();
    }
  }

  /// Returns the node at the given [path].
  Node? nodeAtPath(Path path) {
    return root.childAtPath(path);
  }

  /// Inserts a [Node]s at the given [Path].
  bool insert(Path path, Iterable<Node> nodes) {
    if (path.isEmpty || nodes.isEmpty) {
      return false;
    }

    final target = nodeAtPath(path);
    if (target != null) {
      for (final node in nodes) {
        target.insertBefore(node);
      }
      return true;
    }

    final parent = nodeAtPath(path.parent);
    if (parent != null) {
      for (var i = 0; i < nodes.length; i++) {
        parent.insert(nodes.elementAt(i), index: path.last + i);
      }
      return true;
    }

    return false;
  }

  /// Deletes the [Node]s at the given [Path].
  bool delete(Path path, [int length = 1]) {
    if (path.isEmpty || length <= 0) {
      return false;
    }
    var target = nodeAtPath(path);
    if (target == null) {
      return false;
    }
    while (target != null && length > 0) {
      final next = target.next;
      target.unlink();
      target = next;
      length--;
    }
    return true;
  }

  /// Updates the [Node] at the given [Path]
  bool update(Path path, Attributes attributes) {
    // if the path is empty, it means the root node.
    if (path.isEmpty) {
      root.updateAttributes(attributes);
      return true;
    }
    final target = nodeAtPath(path);
    if (target == null) {
      return false;
    }
    target.updateAttributes(attributes);
    return true;
  }

  /// Updates the [Node] with [Delta] at the given [Path]
  bool updateText(Path path, Delta delta) {
    if (path.isEmpty) {
      return false;
    }
    final target = nodeAtPath(path);
    final targetDelta = target?.delta;
    if (target == null || targetDelta == null) {
      return false;
    }
    target.updateAttributes({'delta': (targetDelta.compose(delta)).toJson()});
    return true;
  }

  /// Returns whether the root [Node] does not contain
  /// any text.
  ///
  bool get isEmpty {
    if (root.children.isEmpty) {
      return true;
    }

    if (root.children.length > 1) {
      return false;
    }

    final node = root.children.first;
    final delta = node.delta;
    if (delta != null && (delta.isEmpty || delta.toPlainText().isEmpty)) {
      return true;
    }

    return false;
  }

  final List<void Function(DeltaChangeEvent)> _deltaChangeListeners = [];

  /// Subscribes to delta changes emitted by transactions.
  ///
  /// The callback receives one event per changed node, after the change has
  /// been applied to the document. An empty [DeltaChangeEvent.changes] list
  /// means the change arrived without local metadata (remote updates or
  /// full-text replacements).
  void listenDeltaChanges(void Function(DeltaChangeEvent) listener) =>
      _deltaChangeListeners.add(listener);

  /// Removes a listener registered with [listenDeltaChanges].
  void removeDeltaChangesListener(void Function(DeltaChangeEvent) listener) =>
      _deltaChangeListeners.remove(listener);

  int _deltaChangeOrder = 0;

  /// Issues the next monotonic order number for a [DeltaChange].
  int nextDeltaChangeOrder() => _deltaChangeOrder++;

  /// Emits [changes] for [node] to all delta-change listeners.
  ///
  /// Called by transactions after they are applied; never by the document's
  /// own mutation methods, so direct attribute writes (e.g. the spell-check
  /// service injecting its marks) never emit.
  void emitChanges(Node node, List<DeltaChange> changes) {
    final event = DeltaChangeEvent(node, List.unmodifiable(changes));
    // Copy: allows add/remove during a callback.
    for (final listener in List.of(_deltaChangeListeners)) {
      listener(event);
    }
  }

  /// Encodes the [Document] into a JSON structure.
  ///
  Map<String, Object> toJson() {
    return {
      'document': root.toJson(),
    };
  }
}
