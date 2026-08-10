import 'dart:math';

import '../attributes.dart';
import 'text_delta.dart';

/// A contiguous run of text with uniform attributes.
///
/// The atomic building block of a [TextDocument]. Equivalent to a
/// [TextInsert] operation in the legacy [Delta] model — the same
/// `text + attributes` pair, stored in a treap instead of a flat list.
///
/// For building [TextSpan] widgets, iterate [TextDocument.chunks]:
/// ```dart
/// for (final chunk in doc.chunks) {
///   TextSpan(text: chunk.text, style: _toStyle(chunk.attributes));
/// }
/// ```
class TextChunk {
  /// The text content of this contiguous run.
  final String text;

  /// Formatting attributes applied to all characters in this run.
  ///
  /// `null` means plain text (no formatting applied).
  final Attributes? attributes;

  const TextChunk(this.text, {this.attributes});

  /// Number of characters in this chunk.
  int get length => text.length;

  @override
  String toString() => 'TextChunk("$text", attrs: $attributes)';
}

/// A node in the order-statistic treap that backs [TextDocument].
///
/// **Invariants:**
/// - **BST by position**: in-order traversal yields document order.
/// - **Max-Heap by priority**: `priority > left.priority && priority > right.priority`.
/// - **Augmented**: [subtreeLength] = total characters in this subtree.
class _TreapNode {
  /// The chunk stored at this node.
  TextChunk chunk;

  /// Random priority for probabilistic balance (max-heap).
  final int priority;

  /// Left child — all nodes whose text comes before this one.
  _TreapNode? left;

  /// Right child — all nodes whose text comes after this one.
  _TreapNode? right;

  /// Total text length of this node + all descendants.
  int subtreeLength;

  _TreapNode(this.chunk)
      : priority = _TreapNode._nextPriority(),
        subtreeLength = chunk.length;

  /// Recompute [subtreeLength] from children and own chunk.
  void _update() {
    subtreeLength =
        chunk.length + (left?.subtreeLength ?? 0) + (right?.subtreeLength ?? 0);
  }

  static final _random = Random();
  static int _nextPriority() => _random.nextInt(1 << 30);
}

/// Split the treap rooted at [node] into two treaps:
/// - `left`  contains positions `[0, pos)`.
/// - `right` contains positions `[pos, total)`.
({_TreapNode? left, _TreapNode? right}) _split(_TreapNode? node, int pos) {
  if (node == null) {
    return (left: null, right: null);
  }

  final leftLen = node.left?.subtreeLength ?? 0;

  if (pos <= leftLen) {
    final sub = _split(node.left, pos);
    node.left = sub.right;
    node._update();
    return (left: sub.left, right: node);
  }

  if (pos >= leftLen + node.chunk.length) {
    final sub = _split(node.right, pos - leftLen - node.chunk.length);
    node.right = sub.left;
    node._update();
    return (left: node, right: sub.right);
  }

  // Split point is INSIDE this node's chunk — cut the chunk in two.
  final offset = pos - leftLen;

  final leftChunk = TextChunk(
    node.chunk.text.substring(0, offset),
    attributes: node.chunk.attributes,
  );
  final rightChunk = TextChunk(
    node.chunk.text.substring(offset),
    attributes: node.chunk.attributes,
  );

  final rightNode = _TreapNode(rightChunk)
    ..right = node.right
    .._update();

  // This node becomes the left part.
  node.chunk = leftChunk;
  node.right = null;
  node._update();

  return (left: node, right: rightNode);
}

/// Merge two treaps where every position in [left] comes before
/// every position in [right].
_TreapNode? _merge(_TreapNode? left, _TreapNode? right) {
  if (left == null) return right;
  if (right == null) return left;

  if (left.priority > right.priority) {
    left.right = _merge(left.right, right);
    left._update();
    return left;
  } else {
    right.left = _merge(left, right.left);
    right._update();
    return right;
  }
}

/// Find the node and offset that contain [pos].
///
/// Returns the leaf node whose chunk covers [pos], together with
/// the local offset inside that chunk (0-based).
///
/// The caller must ensure `0 <= pos < totalLength`.
({_TreapNode node, int offset}) _nodeAt(_TreapNode node, int pos) {
  _TreapNode current = node;
  while (true) {
    final leftLen = current.left?.subtreeLength ?? 0;

    if (pos < leftLen) {
      current = current.left!;
    } else if (pos < leftLen + current.chunk.length) {
      return (node: current, offset: pos - leftLen);
    } else {
      pos -= leftLen + current.chunk.length;
      current = current.right!;
    }
  }
}

/// Apply [attrs] (via [composeAttributes]) to every chunk in the
/// subtree rooted at [node]. Returns the updated root.
_TreapNode? _applyAttributes(_TreapNode? node, Attributes attrs) {
  if (node == null) return null;

  final merged = composeAttributes(node.chunk.attributes, attrs);
  node.chunk = TextChunk(node.chunk.text, attributes: merged);
  node.left = _applyAttributes(node.left, attrs);
  node.right = _applyAttributes(node.right, attrs);
  node._update();
  return node;
}

/// Collect all chunks in-order into [out].
void _collectChunks(_TreapNode? node, List<TextChunk> out) {
  if (node == null) return;
  _collectChunks(node.left, out);
  out.add(node.chunk);
  _collectChunks(node.right, out);
}

/// Walk the subtree in-order, appending to [delta].
void _collectDelta(_TreapNode? node, Delta delta) {
  if (node == null) return;
  _collectDelta(node.left, delta);
  delta.insert(node.chunk.text, attributes: node.chunk.attributes);
  _collectDelta(node.right, delta);
}

/// In-order traversal of the range `[start, end)`, appending matching
/// sub-chunks to [delta].
///
/// Returns the accumulated position after visiting [node]'s subtree.
int _sliceRange(
  _TreapNode? node,
  int start,
  int end,
  int currentPos,
  Delta result,
) {
  if (node == null) return currentPos;

  final leftLen = node.left?.subtreeLength ?? 0;

  if (end > currentPos && start < currentPos + leftLen) {
    currentPos = _sliceRange(
      node.left,
      start,
      end,
      currentPos,
      result,
    );
  } else {
    currentPos += leftLen;
  }

  final nodeStart = currentPos;
  final nodeEnd = currentPos + node.chunk.length;

  if (nodeStart < end && nodeEnd > start) {
    final chunkStart = start > nodeStart ? start - nodeStart : 0;
    final chunkEnd = end < nodeEnd ? end - nodeStart : node.chunk.length;
    result.insert(
      node.chunk.text.substring(chunkStart, chunkEnd),
      attributes: node.chunk.attributes,
    );
  }

  currentPos = nodeEnd;

  final rightLen = node.right?.subtreeLength ?? 0;
  if (currentPos < end && start < currentPos + rightLen) {
    currentPos = _sliceRange(
      node.right,
      start,
      end,
      currentPos,
      result,
    );
  } else {
    currentPos += rightLen;
  }

  return currentPos;
}

/// In-order traversal of the range `[start, end)`, writing matching
/// substrings to [buf].
int _plainTextRange(
  _TreapNode? node,
  int start,
  int end,
  int currentPos,
  StringBuffer buf,
) {
  if (node == null) return currentPos;

  final leftLen = node.left?.subtreeLength ?? 0;

  if (end > currentPos && start < currentPos + leftLen) {
    currentPos = _plainTextRange(node.left, start, end, currentPos, buf);
  } else {
    currentPos += leftLen;
  }

  final nodeEnd = currentPos + node.chunk.length;
  if (currentPos < end && nodeEnd > start) {
    final cs = start > currentPos ? start - currentPos : 0;
    final ce = end < nodeEnd ? end - currentPos : node.chunk.length;
    buf.write(node.chunk.text.substring(cs, ce));
  }

  currentPos = nodeEnd;

  final rightLen = node.right?.subtreeLength ?? 0;
  if (currentPos < end && start < currentPos + rightLen) {
    currentPos = _plainTextRange(node.right, start, end, currentPos, buf);
  } else {
    currentPos += rightLen;
  }

  return currentPos;
}

/// An optimized, tree-backed rich-text document fragment.
///
/// [TextDocument] replaces the legacy flat-list [Delta] as the primary
/// in-memory representation of a node's text content. It uses a
/// **treap** (randomized balanced binary search tree) augmented with
/// subtree character counts to achieve **O(log n)** for all
/// position-based operations (insert, delete, format, attribute lookup).
///
/// ## Relationship with Delta
///
/// | Concern           | [TextDocument]          | [Delta] (legacy)       |
/// |-------------------|-------------------------|------------------------|
/// | Storage           | Treap of [TextChunk]   | `List<TextOperation>`  |
/// | Insert at pos     | O(log n)               | O(n) compose           |
/// | Delete range      | O(log n)               | O(n) compose           |
/// | Format range      | O(log n + k)           | O(n) compose           |
/// | Attribute lookup  | O(log n)               | O(n) via slice         |
/// | Serialization     | `toDelta().toJson()`    | `toJson()`             |
/// | Modification API  | `applyDelta()`         | `compose()`            |
///
/// ## Backward compatibility
///
/// - **Loading**: `TextDocument.fromDelta(legacy)` / `fromJson(json)`.
/// - **Saving**: `toDelta().toJson()` always produces legacy JSON.
/// - **Modifying**: `applyDelta(change)` translates a legacy Delta
///   change into O(log n) treap mutations.
///
/// ## Usage
///
/// ```dart
/// // Construction from legacy data
/// final doc = TextDocument.fromDelta(node.delta!);
///
/// // Native API (preferred for new code)
/// doc.insert(5, 'Hello', attributes: {bold: true});
/// doc.format(5, 5, {italic: true});
/// doc.delete(2, 3);
///
/// // Legacy modification (bridge during migration)
/// doc.applyDelta(Delta()..retain(2)..delete(3));
///
/// // Serialization
/// final json = doc.toJson(); // legacy-compatible
/// ```
class TextDocument {
  /// All the supported format versions are stored here.
  /// Versions >= [currentVersion] are accepted for forward compatibility.
  static const int _currentVersion = 1;
  _TreapNode? _root;

  /// Creates an empty document.
  TextDocument() : _root = null;

  /// Build a [TextDocument] from a legacy [Delta].
  ///
  /// Only [TextInsert] operations are consumed — the document
  /// representation is always insert-only. [TextRetain] and
  /// [TextDelete] in the source are ignored (they don't describe
  /// content).
  ///
  /// Uses a Cartesian tree algorithm to build the treap in O(n).
  factory TextDocument.fromDelta(Delta delta) {
    final chunks = <TextChunk>[];
    for (final op in delta.operations) {
      if (op is TextInsert) {
        chunks.add(TextChunk(op.text, attributes: op.attributes));
      }
    }
    return TextDocument._fromChunks(chunks);
  }

  /// Build a [TextDocument] from legacy JSON (the `delta` attribute
  /// value on a [Node]).
  factory TextDocument.fromJson(List<dynamic> json) {
    return TextDocument.fromDelta(Delta.fromJson(json));
  }

  /// Build a [TextDocument] from its native JSON representation.
  ///
  /// This is the preferred format for persistence once the breaking
  /// change to [TextDocument] is made — it avoids the intermediate
  /// [Delta] entirely and reconstructs the treap in O(n).
  ///
  /// Expected format:
  /// ```json
  /// {
  ///   "v": 1,
  ///   "c": [
  ///     {"t": "Hello ", "a": {"bold": true}},
  ///     {"t": "World"}
  ///   ]
  /// }
  /// ```
  factory TextDocument.fromNativeJson(Map<String, dynamic> json) {
    final version = json['v'] as int?;
    if (version == null || version < _currentVersion) {
      throw FormatException('Unsupported native format version: $version');
    }
    final rawChunks = json['c'] as List<dynamic>?;
    if (rawChunks == null) {
      return TextDocument();
    }
    final chunks = rawChunks.map((c) {
      final map = c as Map<String, dynamic>;
      final attrs = map['a'] as Map<String, dynamic>?;
      return TextChunk(
        map['t'] as String? ?? '',
        attributes: attrs != null ? Map<String, dynamic>.from(attrs) : null,
      );
    }).toList(growable: false);
    return TextDocument._fromChunks(chunks);
  }

  /// Build a treap from an in-order list of chunks in O(n) time.
  ///
  /// Uses the Cartesian tree algorithm: a single left-to-right pass
  /// with a stack that maintains the right spine of the tree.
  /// Each node gets a fresh random priority.
  TextDocument._fromChunks(List<TextChunk> chunks) {
    if (chunks.isEmpty) {
      _root = null;
      return;
    }

    final nodes = chunks
        .map(
          (c) => _TreapNode(c),
        )
        .toList(growable: false);

    // Cartesian tree construction in O(n) using a stack.
    // Invariant: stack contains the right spine, with increasing
    // priorities from bottom to top (max-heap).
    final stack = <_TreapNode>[];

    for (final node in nodes) {
      _TreapNode? lastPopped;

      // Pop nodes with lower priority — they become the left child
      // of the current node.
      while (stack.isNotEmpty && stack.last.priority < node.priority) {
        lastPopped = stack.removeLast();
      }

      node.left = lastPopped;

      // The current node becomes the right child of the new stack top.
      if (stack.isNotEmpty) {
        stack.last.right = node;
      }

      stack.add(node);
    }

    // The root is the first (bottom-most) node in the stack.
    _root = stack.first;

    // Compute subtreeLengths bottom-up via post-order.
    _updateSubtreeLengths(_root!);
  }

  /// Post-order traversal to compute [subtreeLength] for all nodes.
  static int _updateSubtreeLengths(_TreapNode node) {
    final leftLen = node.left != null ? _updateSubtreeLengths(node.left!) : 0;
    final rightLen =
        node.right != null ? _updateSubtreeLengths(node.right!) : 0;
    node.subtreeLength = node.chunk.length + leftLen + rightLen;
    return node.subtreeLength;
  }

  /// Total number of characters in the document.
  int get length => _root?.subtreeLength ?? 0;

  /// Whether the document has no content.
  bool get isEmpty => _root == null;

  /// All chunks in document order.
  ///
  /// Useful for building [TextSpan] widgets:
  /// ```dart
  /// List<TextSpan> spans = doc.chunks
  ///   .map((c) => TextSpan(text: c.text, style: _style(c.attributes)))
  ///   .toList();
  /// ```
  List<TextChunk> get chunks {
    final result = <TextChunk>[];
    _collectChunks(_root, result);
    return result;
  }

  /// Insert [text] at [position] with optional [attributes].
  ///
  /// Throws [RangeError] if [position] is out of bounds.
  /// Does nothing if [text] is empty.
  void insert(int position, String text, {Attributes? attributes}) {
    _assertInsertBounds(position, 'insert');
    if (text.isEmpty) return;

    final splitResult = _split(_root, position);
    _root = _merge(
      _merge(splitResult.left,
          _TreapNode(TextChunk(text, attributes: attributes))),
      splitResult.right,
    );
  }

  /// Insert [text] at with optional [attributes].
  void pushText(String text, {Attributes? attributes}) {
    final position = (length - 1).clamp(0, length);
    _assertInsertBounds(position, 'insert');
    if (text.isEmpty) return;

    final splitResult = _split(_root, position);
    _root = _merge(
      _merge(splitResult.left,
          _TreapNode(TextChunk(text, attributes: attributes))),
      splitResult.right,
    );
  }

  /// Delete [length] characters starting at [position].
  ///
  /// Throws [RangeError] if the range is invalid.
  /// Does nothing if [length] is 0.
  void delete(int position, int length) {
    _assertRange(position, length, 'delete');
    if (length == 0) return;

    final split1 = _split(_root, position);
    final split2 = _split(split1.right, length);
    _root = _merge(split1.left, split2.right);
  }

  /// Apply [attributes] to the range `[position, position + length)`.
  ///
  /// Merges with existing attributes on each chunk using
  /// [composeAttributes].
  ///
  /// Throws [RangeError] if the range is invalid.
  /// Does nothing if [length] is 0 or [attributes] is empty.
  void format(int position, int length, Attributes attributes) {
    _assertRange(position, length, 'format');
    if (length == 0 || attributes.isEmpty) return;

    final split1 = _split(_root, position);
    final split2 = _split(split1.right, length);

    final formatted = _applyAttributes(split2.left, attributes);

    _root = _merge(_merge(split1.left, formatted), split2.right);
  }

  /// The formatting attributes active at [position].
  ///
  /// Returns `null` for plain text. Throws [RangeError] if
  /// [position] is out of bounds or the document is empty.
  Attributes? attributesAt(int position) {
    if (_root == null) {
      throw RangeError.range(position, 0, 0, 'position', 'Document is empty');
    }
    _assertReadBounds(position, 'attributesAt');
    final found = _nodeAt(_root!, position);
    return found.node.chunk.attributes;
  }

  /// Extract a [Delta] covering `[start, end)`.
  ///
  /// Returns a legacy [Delta] for compatibility with existing code.
  /// For building [TextSpan] widgets, prefer [chunks] or iterate
  /// directly.
  Delta slice(int start, [int? end]) {
    final endPos = end ?? length;
    _assertRange(start, endPos - start, 'slice');
    if (start == endPos) return Delta();

    final result = Delta();
    _sliceRange(_root, start, endPos, 0, result);
    return result;
  }

  /// Plain text in the range `[start, end)`.
  ///
  /// Omitting both arguments returns the full text.
  String plainText([int? start, int? end]) {
    final s = start ?? 0;
    final e = end ?? length;
    _assertRange(s, e - s, 'plainText');
    if (s == e) return '';

    final buf = StringBuffer();
    _plainTextRange(_root, s, e, 0, buf);
    return buf.toString();
  }

  /// Export to a legacy [Delta].
  ///
  /// The result is insert-only and semantically identical to the
  /// original Delta that produced this document (modulo chunk
  /// boundaries — adjacent chunks with identical attributes may
  /// not be merged).
  Delta toDelta() {
    final delta = Delta();
    _collectDelta(_root, delta);
    return delta;
  }

  /// Export to legacy JSON (the `delta` attribute value on a [Node]).
  List<dynamic> toJson() => toDelta().toJson();

  /// Export to the native [TextDocument] JSON format.
  ///
  /// This is a compact, tree-native representation that can be
  /// deserialized via [TextDocument.fromNativeJson] in O(n) without
  /// depending on the legacy [Delta] format.
  ///
  /// Format:
  /// ```json
  /// {
  ///   "v": 1,
  ///   "c": [
  ///     {"t": "Hello ", "a": {"bold": true}},
  ///     {"t": "World"}
  ///   ]
  /// }
  /// ```
  ///
  /// Keys: `v` = format version, `c` = chunks array.
  /// Each chunk: `t` = text (String), `a` = attributes (Map or absent).
  Map<String, dynamic> toNativeJson() {
    final chunkList = <Map<String, dynamic>>[];
    for (final chunk in chunks) {
      final entry = <String, dynamic>{'t': chunk.text};
      if (chunk.attributes != null && chunk.attributes!.isNotEmpty) {
        entry['a'] = chunk.attributes;
      }
      chunkList.add(entry);
    }
    return {'v': _currentVersion, 'c': chunkList};
  }

  /// Apply a legacy [Delta] change to this document.
  ///
  /// Each [TextOperation] in [change] is translated to the
  /// corresponding native treap operation:
  ///
  /// | Delta operation              | Native call                  |
  /// |------------------------------|------------------------------|
  /// | `Retain(N)`                  | cursor += N                  |
  /// | `Retain(N, attrs: A)`        | `format(cursor, N, A)`       |
  /// | `Insert(text, attrs: A)`     | `insert(cursor, text, A)`    |
  /// | `Delete(N)`                  | `delete(cursor, N)`          |
  ///
  /// Complexity: **O(|change| × log N)** instead of the O(N)
  /// of `Delta.compose()`.
  ///
  /// Returns `this` for chaining.
  TextDocument applyDelta(Delta change) {
    int cursor = 0;

    for (final op in change.operations) {
      if (op is TextInsert) {
        insert(cursor, op.text, attributes: op.attributes);
        cursor += op.text.length;
      } else if (op is TextRetain) {
        if (op.attributes != null) {
          format(cursor, op.length, op.attributes!);
        }
        cursor += op.length;
      } else if (op is TextDelete) {
        delete(cursor, op.length);
      }
    }

    return this;
  }

  void _assertInsertBounds(int pos, String method) {
    final len = length;
    if (pos < 0 || pos > len) {
      throw RangeError.range(pos, 0, len, 'position', '$method: out of bounds');
    }
  }

  void _assertReadBounds(int pos, String method) {
    final len = length;
    if (pos < 0 || pos >= len) {
      throw RangeError.range(
          pos, 0, len - 1, 'position', '$method: out of bounds');
    }
  }

  void _assertRange(int start, int len, String method) {
    final total = length;
    if (start < 0 || start > total) {
      throw RangeError.range(
          start, 0, total, 'start', '$method: out of bounds');
    }
    if (len < 0 || start + len > total) {
      throw RangeError.range(
        start + len,
        start,
        total,
        'end',
        '$method: range exceeds document',
      );
    }
  }

  @override
  String toString() {
    if (_root == null) return 'TextDocument(empty)';
    return 'TextDocument(len: $length, chunks: $chunks)';
  }
}
