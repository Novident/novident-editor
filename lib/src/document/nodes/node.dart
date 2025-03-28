import 'dart:collection';

final class Node extends LinkedListEntry<Node> {
  NodeContainer? owner;
  Object data;

  Node({
    required this.data,
  });

  int get length => data is String ? data.toString().length : 1;

  bool get isFirst => previous == null;
  bool get isLast => next == null;

  int? _offset;

  void clearOffsetCache() {
    _offset = null;
    final next = this.next;
    if (next != null) {
      next.clearOffsetCache();
    }
  }

  /// Offset in characters of this node relative to [parent] node.
  ///
  /// To get offset of this node in the document see [documentOffset].
  int get offset {
    if (_offset != null) {
      return _offset!;
    }

    if (list == null || isFirst) {
      return 0;
    }
    int offset = 0;
    for (final Node node in list!) {
      if (node == this) {
        break;
      }
      offset += node.length;
    }

    _offset = offset;
    return _offset!;
  }

  /// Offset in characters of this node in the document.
  int get documentOffset {
    if (owner == null) {
      return offset;
    }
    final int parentOffset = owner!.start(global: true);
    return parentOffset + offset;
  }

  /// Returns `true` if this node contains character at specified [offset] in
  /// the document.
  bool containsOffset(int offset) {
    final int o = documentOffset;
    return o <= offset && offset < o + length;
  }

  @override
  void insertBefore(Node entry) {
    assert(entry.owner == null && owner != null);
    entry.owner = owner;
    super.insertBefore(entry);
    entry.owner?.clearLengthCache();
  }

  @override
  void insertAfter(Node entry) {
    assert(entry.owner == null && owner != null);
    entry.owner = owner;
    super.insertAfter(entry);
    entry.owner?.clearLengthCache();
  }

  @override
  void unlink() {
    assert(owner != null, 'The owner cannot be null when this Node is being unlinked');
    owner!.clearLengthCache();
    owner = null;
    super.unlink();
  }
}

final class NodeContainer extends LinkedListEntry<NodeContainer> {
  final LinkedList<Node> _children = LinkedList<Node>();
  Map<String, dynamic> attributes;

  NodeContainer({
    required List<Node> children,
    required this.attributes,
  }) {
    for (final Node child in children) {
      child.owner = this;
    }
  }

  int? _start;
  int? _end;
  int? _length;

  void clearLengthCache() {
    _length = null;
  }

  int get length => _length ??= _children.fold(
        0,
        (int? a, Node b) => (a ?? 0) + b.length,
      )!;

  int start({bool global = false}) {
    if (!global) {
      return 0;
    }
    return _start ??= () {
      NodeContainer? previousNode = super.previous;
      int start = previousNode?.start() ?? 0;
      while (previousNode != null) {
        previousNode = previousNode.previous;
        start += previousNode!.start();
      }
      return start;
    }.call();
  }

  int end({bool global = false}) {
    if (!global) {
      return length;
    }
    return _end ??= () {
      NodeContainer? nextNode = super.next;
      int start = nextNode?.start(global: true) ?? 0;
      while (nextNode != null) {
        nextNode = nextNode.next;
        start += nextNode!.end();
      }
      return start;
    }.call();
  }
}
