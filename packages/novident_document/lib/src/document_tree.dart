import 'node.dart';
import 'path.dart';

/// A chunk of up to 128 children within a [_ChunkedList].
///
/// Each chunk tracks its [startIndex] (global position of its first element)
/// and a [localPos] map for O(1) position lookup within the chunk.
class _Chunk {
  final List<Node> nodes;
  int startIndex;
  final Map<Node, int> localPos;

  _Chunk(this.nodes, this.startIndex) : localPos = {} {
    for (var i = 0; i < nodes.length; i++) {
      localPos[nodes[i]] = i;
    }
  }

  int get length => nodes.length;
}

/// A chunked array for ordered [Node] children with O(1) [indexOf].
///
/// Splits the list into [_Chunk]s of up to 128 elements. Insertions and
/// deletions touch only one chunk (O(B) writes) plus update [startIndex]
/// of subsequent chunks (O(chunks) integer additions).
///
/// For small lists (≤128 elements, the 99% case), this degenerates to
/// a single chunk with direct array access — no binary search overhead.
class _ChunkedList {
  static const int _maxChunk = 128;
  static const int _minChunk = 32;

  final List<_Chunk> _chunks = [];
  final Map<Node, _Chunk> _nodeToChunk = {};
  int _size = 0;

  int get length => _size;
  bool get isEmpty => _size == 0;

  /// Positional access via chunk lookup.
  ///
  /// Single-chunk fast path avoids binary search for the common case.
  Node operator [](int index) {
    if (_chunks.length == 1) return _chunks[0].nodes[index];
    final ci = _chunkIndex(index);
    return _chunks[ci].nodes[index - _chunks[ci].startIndex];
  }

  /// Binary search on chunk [startIndex] values. O(log n/B).
  int _chunkIndex(int index) {
    assert(index >= 0 && index < _size);
    int lo = 0;
    int hi = _chunks.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_chunks[mid].startIndex <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// O(1) position lookup via chunk-local [localPos] map.
  int indexOf(Node node) {
    if (_chunks.length == 1) return _chunks[0].localPos[node] ?? -1;
    final chunk = _nodeToChunk[node];
    if (chunk == null) return -1;
    final local = chunk.localPos[node];
    if (local == null) return -1;
    return chunk.startIndex + local;
  }

  /// Collect all elements in order into [out].
  void collectInto(List<Node> out) {
    for (final chunk in _chunks) {
      out.addAll(chunk.nodes);
    }
  }

  /// Insert [node] at [index]. O(B + log n/B).
  void insert(int index, Node node) {
    if (_chunks.isEmpty) {
      final chunk = _Chunk([node], 0);
      _chunks.add(chunk);
      _nodeToChunk[node] = chunk;
      _size = 1;
      return;
    }

    final ci = index == _size ? _chunks.length - 1 : _chunkIndex(index);
    final chunk = _chunks[ci];
    final localPos = index - chunk.startIndex;

    chunk.nodes.insert(localPos, node);
    chunk.localPos[node] = localPos;
    _nodeToChunk[node] = chunk;
    _size++;

    _fixLocalFrom(chunk, localPos + 1);
    _bumpStartsFrom(ci + 1, 1);

    if (chunk.nodes.length > _maxChunk * 2) _splitChunk(ci);
  }

  /// Remove and return the element at [index]. O(B + log n/B).
  Node removeAt(int index) {
    final ci = _chunkIndex(index);
    final chunk = _chunks[ci];
    final localPos = index - chunk.startIndex;

    final removed = chunk.nodes.removeAt(localPos);
    chunk.localPos.remove(removed);
    _nodeToChunk.remove(removed);
    _size--;

    if (chunk.nodes.isEmpty) {
      _chunks.removeAt(ci);
      _bumpStartsFrom(ci, 0);
    } else {
      _fixLocalFrom(chunk, localPos);
      _bumpStartsFrom(ci + 1, -1);
      if (chunk.nodes.length < _minChunk && _chunks.length > 1) {
        _mergeChunk(ci);
      }
    }

    return removed;
  }

  void clear() {
    _chunks.clear();
    _nodeToChunk.clear();
    _size = 0;
  }

  /// Batch-adopt [nodes] in chunk-sized groups. O(n).
  void adoptAll(List<Node> nodes) {
    clear();
    if (nodes.isEmpty) return;

    int start = 0;
    for (var i = 0; i < nodes.length; i += _maxChunk) {
      final end = (i + _maxChunk).clamp(0, nodes.length);
      final sub = nodes.sublist(i, end);
      final chunk = _Chunk(sub, start);
      _chunks.add(chunk);
      for (final node in sub) {
        _nodeToChunk[node] = chunk;
      }
      start += sub.length;
    }
    _size = nodes.length;
  }

  void _fixLocalFrom(_Chunk chunk, int from) {
    for (var i = from; i < chunk.nodes.length; i++) {
      chunk.localPos[chunk.nodes[i]] = i;
    }
  }

  void _bumpStartsFrom(int ci, int delta) {
    if (ci <= 0) {
      if (_chunks.isNotEmpty) {
        _chunks[0].startIndex = 0;
        ci = 1;
      } else {
        return;
      }
    }
    for (var i = ci; i < _chunks.length; i++) {
      _chunks[i].startIndex =
          _chunks[i - 1].startIndex + _chunks[i - 1].nodes.length;
    }
  }

  void _splitChunk(int ci) {
    final chunk = _chunks[ci];
    final mid = chunk.nodes.length ~/ 2;
    final rightNodes = chunk.nodes.sublist(mid);
    chunk.nodes.removeRange(mid, chunk.nodes.length);
    _fixLocalFrom(chunk, 0);

    final rightStart = chunk.startIndex + chunk.nodes.length;
    final rightChunk = _Chunk(rightNodes, rightStart);
    _chunks.insert(ci + 1, rightChunk);
    for (final node in rightNodes) {
      _nodeToChunk[node] = rightChunk;
    }
    _bumpStartsFrom(ci + 1, 0);
  }

  void _mergeChunk(int ci) {
    if (ci > 0 &&
        _chunks[ci - 1].nodes.length + _chunks[ci].nodes.length <=
            _maxChunk * 2) {
      final left = _chunks[ci - 1];
      final right = _chunks[ci];
      for (final node in right.nodes) {
        _nodeToChunk[node] = left;
      }
      left.nodes.addAll(right.nodes);
      _fixLocalFrom(left, left.nodes.length - right.nodes.length);
      _chunks.removeAt(ci);
      _bumpStartsFrom(ci, 0);
      return;
    }
    if (ci < _chunks.length - 1 &&
        _chunks[ci].nodes.length + _chunks[ci + 1].nodes.length <=
            _maxChunk * 2) {
      final left = _chunks[ci];
      final right = _chunks[ci + 1];
      for (final node in right.nodes) {
        _nodeToChunk[node] = left;
      }
      left.nodes.addAll(right.nodes);
      _fixLocalFrom(left, left.nodes.length - right.nodes.length);
      _chunks.removeAt(ci + 1);
      _bumpStartsFrom(ci, 0);
    }
  }
}

/// A fast, chunked-list-backed index for [Node] document trees.
///
/// [DocumentTree] wraps a legacy [Node] tree and provides O(1) lookups
/// for [byId], [parentOf], [indexOf], and [childAt] via internal
/// [HashMap]s and chunked-lists. [pathOf] is computed on-demand in
/// O(depth) from the parent chain.
///
/// This is an auxiliary index used by [Document] — the legacy [Node]
/// tree (LinkedList-based) remains the canonical storage. [DocumentTree]
/// accelerates the operations where the legacy tree is O(n):
///
/// | Operation     | Legacy (no cache) | DocumentTree |
/// |---------------|-------------------|--------------|
/// | [byId]        | O(n) tree scan    | O(1)         |
/// | [indexOf]     | O(n) list scan    | O(1)         |
/// | [parentOf]    | O(1) field        | O(1)         |
/// | [pathOf]      | O(d) parent chain | O(d) parent chain |
/// | [nodeAtPath]  | O(d × n)          | O(d × log n/B) |
/// | [childAt]     | O(n)              | O(log n/B)   |
/// | [insert]      | O(1) linked list  | O(B)         |
/// | [remove]      | O(1) unlink       | O(B)         |
///
/// Children are stored in [_ChunkedList] per parent — chunked arrays
/// of up to 128 elements. This gives O(B) insert/delete (B = chunk size)
/// instead of the O(k) global-index-sweep of a flat list.
///
/// [pathOf] is on-demand (not cached) — it walks the [_parentOf] chain
/// and calls [indexOf] at each level. This avoids eager path recomputation
/// after mutations at the cost of O(depth) per call (depth ≤ 4 in practice).
///
/// The [syncInsert] and [syncRemove] methods are used by [Document] to
/// keep the index in sync with legacy-tree mutations without recursively
/// adopting descendants (the legacy tree already manages them).
class DocumentTree {
  DocumentTree.empty() : _rootNode = null;

  /// Build an index wrapping an existing [root] tree in O(n).
  factory DocumentTree.fromRoot(Node root) {
    final tree = DocumentTree._();
    tree._rootNode = root;
    tree._adoptRecursive(root, null);
    return tree;
  }

  /// Build an index from a JSON document in O(n).
  factory DocumentTree.fromJson(Map<String, Object> json) {
    final document = json['document'] as Map<String, Object>?;
    if (document == null) return DocumentTree.empty();
    final root = Node.fromJson(Map<String, Object>.from(document));
    return DocumentTree.fromRoot(root);
  }

  DocumentTree._() : _rootNode = null;

  Node? _rootNode;

  final Map<String, Node> _byId = {};
  final Map<Node, Node?> _parentOf = {};
  final Map<Node, _ChunkedList> _childrenOf = {};

  /// The root node, or null if the tree is empty.
  Node? get root => _rootNode;

  /// Total number of nodes including root.
  int get size => _byId.length;

  /// Whether the tree has no root.
  bool get isEmpty => _rootNode == null;

  void _adoptRecursive(Node node, Node? parent) {
    _byId[node.id] = node;
    _parentOf[node] = parent;

    final legacyChildren = _readLegacyChildren(node);
    if (legacyChildren.isNotEmpty) {
      final cl = _ChunkedList();
      cl.adoptAll(legacyChildren);
      _childrenOf[node] = cl;
      for (final child in legacyChildren) {
        _adoptRecursive(child, node);
      }
    }
  }

  void _adoptNewNode(Node node, Node parent) {
    _byId[node.id] = node;
    _parentOf[node] = parent;

    final legacyChildren = _readLegacyChildren(node);
    if (legacyChildren.isNotEmpty) {
      final cl = _ChunkedList();
      cl.adoptAll(legacyChildren);
      _childrenOf[node] = cl;
      for (final child in legacyChildren) {
        _adoptRecursive(child, node);
      }
    }
  }

  static List<Node> _readLegacyChildren(Node node) {
    final list = node.children;
    return list.isEmpty ? const [] : list;
  }

  static void _detachFromLegacy(Node node) {
    if (node.parent != null) {
      node.unlink();
      node.parent = null;
    }
  }

  /// The path of [node] from the root. O(depth).
  ///
  /// Walks up the [_parentOf] chain, collecting indices via [indexOf]
  /// at each level. Returns `[]` for the root or detached nodes.
  Path pathOf(Node node) {
    final parent = _parentOf[node];
    if (parent == null) return const [];

    final indices = <int>[];
    Node? current = node;
    while (current != null) {
      final p = _parentOf[current];
      if (p == null) break;
      final cl = _childrenOf[p]!;
      indices.add(cl.indexOf(current));
      current = p;
    }
    return indices.reversed.toList(growable: false);
  }

  /// The node at [path], or null if the path is invalid. O(depth × log n/B).
  Node? nodeAtPath(Path path) {
    if (_rootNode == null || path.isEmpty) return _rootNode;
    Node? current = _rootNode;
    for (final index in path) {
      final cl = _childrenOf[current];
      if (cl == null || index < 0 || index >= cl.length) return null;
      current = cl[index];
    }
    return current;
  }

  /// The parent of [node], or null. O(1).
  Node? parentOf(Node node) => _parentOf[node];

  /// All children of [node] in document order. Returns a new list. O(c).
  List<Node> childrenOf(Node node) {
    final cl = _childrenOf[node];
    if (cl == null || cl.isEmpty) return const [];
    final result = <Node>[];
    cl.collectInto(result);
    return result;
  }

  /// The child of [node] at [index], or null. O(log n/B).
  Node? childAt(Node node, int index) {
    final cl = _childrenOf[node];
    if (cl == null || index < 0 || index >= cl.length) return null;
    return cl[index];
  }

  /// The index of [node] within its parent's children. O(1).
  int indexOf(Node node) {
    final parent = _parentOf[node];
    if (parent == null) return -1;
    final cl = _childrenOf[parent];
    if (cl == null) return -1;
    return cl.indexOf(node);
  }

  /// Number of direct children. O(1).
  int childCount(Node node) => _childrenOf[node]?.length ?? 0;

  /// Look up a node by its ID. O(1).
  Node? byId(String id) => _byId[id];

  /// Insert [child] into [parent] at [index]. O(B + log n/B).
  ///
  /// If [index] is omitted, appends to the end. Clamps out-of-bounds.
  void insert(Node parent, Node child, {int? index}) {
    assert(_childrenOf.containsKey(parent) || _parentOf.containsKey(parent),
        'Parent must already be in the tree: ${parent.id}');
    assert(!_parentOf.containsKey(child) || _parentOf[child] == null,
        'Child is already in the tree: ${child.id}');

    _detachFromLegacy(child);

    final cl = _childrenOf.putIfAbsent(parent, () => _ChunkedList());
    final pos = (index ?? cl.length).clamp(0, cl.length);

    _adoptNewNode(child, parent);
    cl.insert(pos, child);
  }

  /// Remove [node] from the tree. O(B + log n/B).
  ///
  /// Recursively removes all descendants first.
  void remove(Node node) {
    final parent = _parentOf[node];
    if (parent == null) return;

    final cl = _childrenOf[node];
    if (cl != null && !cl.isEmpty) {
      final ids = <String>[];
      for (var i = 0; i < cl.length; i++) {
        ids.add(cl[i].id);
      }
      for (final id in ids) {
        remove(_byId[id]!);
      }
    }

    final siblings = _childrenOf[parent]!;
    siblings.removeAt(siblings.indexOf(node));

    _parentOf.remove(node);
    _byId.remove(node.id);
    _childrenOf.remove(node);

    if (siblings.isEmpty) {
      _childrenOf.remove(parent);
    }
  }

  /// Move [node] to [newParent] at [index]. O(B + log n/B).
  void move(Node node, Node newParent, {int? index}) {
    final oldParent = _parentOf[node];
    if (oldParent == null) return;

    final oldSiblings = _childrenOf[oldParent]!;
    oldSiblings.removeAt(oldSiblings.indexOf(node));

    if (oldSiblings.isEmpty) {
      _childrenOf.remove(oldParent);
    }

    _parentOf[node] = newParent;
    final newSiblings =
        _childrenOf.putIfAbsent(newParent, () => _ChunkedList());
    final pos = (index ?? newSiblings.length).clamp(0, newSiblings.length);
    newSiblings.insert(pos, node);
  }

  /// Synchronize a node insertion that already happened in the legacy tree.
  ///
  /// Only updates chunked list and maps — does NOT recursively adopt
  /// descendants. Used by [Document.insert] to keep the index fresh.
  void syncInsert(Node parent, Node child, int index) {
    _byId[child.id] = child;
    _parentOf[child] = parent;
    final cl = _childrenOf.putIfAbsent(parent, () => _ChunkedList());
    cl.insert(index, child);
  }

  /// Synchronize a node removal that already happened in the legacy tree.
  ///
  /// Only updates chunked list and maps. Used by [Document.delete].
  void syncRemove(Node parent, Node child) {
    _parentOf.remove(child);
    _byId.remove(child.id);
    _childrenOf.remove(child);
    final cl = _childrenOf[parent];
    if (cl != null) {
      cl.removeAt(cl.indexOf(child));
      if (cl.isEmpty) _childrenOf.remove(parent);
    }
  }

  /// All nodes in pre-order (root first). O(n).
  List<Node> get allNodes {
    if (_rootNode == null) return const [];
    final result = <Node>[];
    _collectPreOrder(_rootNode!, result);
    return result;
  }

  void _collectPreOrder(Node node, List<Node> out) {
    out.add(node);
    final cl = _childrenOf[node];
    if (cl != null) {
      for (var i = 0; i < cl.length; i++) {
        _collectPreOrder(cl[i], out);
      }
    }
  }

  /// Serialize to legacy-compatible JSON. O(n).
  Map<String, Object> toJson() {
    if (_rootNode == null) {
      return {
        'document': <String, Object>{
          'type': 'page',
          'children': <Object>[]
        }
      };
    }
    return {'document': _nodeToJson(_rootNode!)};
  }

  Map<String, Object> _nodeToJson(Node node) {
    final map = <String, Object>{'type': node.type};
    final cl = _childrenOf[node];
    if (cl != null && !cl.isEmpty) {
      final kids = <Map<String, Object>>[];
      for (var i = 0; i < cl.length; i++) {
        kids.add(_nodeToJson(cl[i]));
      }
      map['children'] = kids;
    }
    if (node.attributes.isNotEmpty) {
      final data = Map<String, dynamic>.from(node.attributes);
      data.removeWhere((_, value) => value == null);
      if (data.isNotEmpty) map['data'] = data;
    }
    return map;
  }

  /// Verify internal consistency. Debug-only.
  void checkIntegrity() {
    if (_rootNode == null) return;
    _checkNode(_rootNode!, null, 0);
  }

  int _checkNode(Node node, Node? expectedParent, int depth) {
    assert(_parentOf[node] == expectedParent,
        'Parent mismatch: ${node.id} depth=$depth');
    assert(_byId[node.id] == node, 'byId mismatch for ${node.id}');

    final parent = _parentOf[node];
    if (parent != null) {
      final cl = _childrenOf[parent]!;
      final idx = cl.indexOf(node);
      assert(idx >= 0, 'Node ${node.id} not found in parent chunked list');
      assert(cl[idx] == node, 'Index mismatch: ${node.id}');
    }

    final cl = _childrenOf[node];
    int total = 1;
    if (cl != null) {
      for (var i = 0; i < cl.length; i++) {
        final child = cl[i];
        assert(cl.indexOf(child) == i,
            'Chunk indexOf mismatch: ${child.id} expected=$i got=${cl.indexOf(child)}');
        total += _checkNode(child, node, depth + 1);
      }
    }
    return total;
  }
}
