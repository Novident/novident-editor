import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/non_secure.dart';

import 'attributes.dart';
import 'delta/text_delta.dart';
import 'delta/text_document.dart';
import 'path.dart';

abstract class NodeExternalValues {
  const NodeExternalValues();
}

/// [Node] represents a node in the document tree.
///
/// It contains three parts:
///   - [type]: The type of the node to determine which block component to
///     render it.
///   - [data]: The data of the node to determine how to render it.
///   - [children]: The children of the node.
///
///
/// Json format:
/// ```
/// {
///   'type': String,
///   'data': Map<String, Object>
///   'children': List<Node>,
/// }
/// ```
///
final class Node extends ChangeNotifier with LinkedListEntry<Node> {
  Node({
    required this.type,
    String? id,
    this.parent,
    Attributes attributes = const {},
    Iterable<Node> children = const [],
  })  : _children = LinkedList<Node>(),
        _attributes = <String, dynamic>{...attributes},
        id = id ?? nanoid(6) {
    if (_attributes['td'] is Map) {
      _textDocument = TextDocument.fromNativeJson(
        Map<String, dynamic>.from(
          _attributes['td'],
        ),
      );
    }
    if (_attributes['td'] is TextDocument) {
      _textDocument = _attributes['td'];
    }
    if (_attributes['delta'] is List) {
      _textDocument ??= TextDocument.fromJson(_attributes['delta']);
      // Migrate to internal td format, drop legacy delta.
      _attributes['td'] = _textDocument;
    }
    if (_attributes['delta'] is Delta) {
      _textDocument ??= TextDocument.fromDelta(_attributes['delta']);
      // Migrate to internal td format, drop legacy delta.
      _attributes['td'] = _textDocument;
    }
    _attributes.remove('delta');
    _cacheChildren ??= [];
    int index = 0;
    for (final child in children) {
      if (child.parent != null) {
        child.unlink();
      }
      child.parent = this;
      child._indexCacheOwner = this;
      child._indexCacheVersion = _childrenVersion;
      child._cachedIndex = index;
      _cacheChildren!.add(child);
      _children.add(child);
      index++;
    }
  }

  /// Parses a [Map] into a [Node].
  ///
  /// Reads text from the `delta` key in `data` (legacy serialization
  /// format) and stores it internally as native `td` format for fast
  /// runtime access.  At runtime Delta is never used — it only exists
  /// as a serialization bridge in [toJson] / [fromJson].
  factory Node.fromJson(Map<String, Object> json) {
    return Node(
      id: json['id'] as String? ?? nanoid(6),
      type: json['type'] as String,
      attributes: json['data'] as Map<String, dynamic>? ??
          json['attributes'] as Map<String, dynamic>? ??
          <String, dynamic>{},
      children: (json['children'] as List? ?? []).map(
        (e) => Node.fromJson(Map<String, Object>.from(e)),
      ),
    );
  }

  /// The id of the node.
  final String id;

  /// The type of the node.
  final String type;

  /// The parent of the node.
  Node? parent;

  /// The children of the node.
  final LinkedList<Node> _children;
  List<Node> get children {
    _cacheChildren ??= _children.toList(growable: false);
    return _cacheChildren!;
  }

  int get length => children.length;

  int get textLength => textDocument?.length ?? -1;

  List<Node>? _cacheChildren;

  /// Bumped on every children mutation; used to validate the per-child
  /// index cache that keeps [path] cheap (see [_indexInParent]).
  int _childrenVersion = 0;

  // index-in-parent cache (owned by the parent's version).
  Node? _indexCacheOwner;
  int _indexCacheVersion = -1;
  int _cachedIndex = -1;

  /// Native treap-backed text storage — the source of truth for rich text.
  ///
  /// Lazily initialised from [attributes] on first access via [textDocument]
  /// or [delta].  Once parsed the treap stays in sync with [attributes]
  /// through [updateAttributes] and [applyTextDelta].
  TextDocument? _textDocument;

  // Legacy parsed-delta cache, now keyed on the td/delta attribute identity.
  // Kept for debugDeltaParseCount instrumentation and backward compat.
  Object? _cachedDeltaRaw;
  Delta? _cachedDelta;

  void _invalidateChildrenCache() {
    _cacheChildren = null;
    _childrenVersion++;
  }

  /// Test-only instrumentation: number of full sibling re-index sweeps
  /// performed by [_reindexChildren]. Lets tests prove that repeated
  /// [path] reads are cache hits (the counter must not move).
  @visibleForTesting
  static int debugReindexCount = 0;

  /// Test-only instrumentation: number of times a [Delta] was parsed from
  /// its raw attribute value — i.e. the cache misses of [delta].
  @visibleForTesting
  static int debugDeltaParseCount = 0;

  /// The attributes of the node.
  Attributes _attributes;

  /// Method not recommended for mutating attributes directly.
  ///
  /// Its use should be strictly limited to internal contexts where:
  /// - Safe access via [attributes] generates an excessive number of copies.
  /// - Performance is critical.
  ///
  /// Any mutation should be do it using [updateAttributes] method
  Attributes get attributes => _attributes;

  /// The native rich-text content of this node.
  ///
  /// Returns `null` for nodes that have no text (containers with only
  /// children, images, etc.).
  ///
  /// Eagerly parsed from the `td` or `delta` attribute during
  /// construction and kept in sync by [updateAttributes] and
  /// [applyTextDelta].  All mutations go through the treap directly.
  ///
  /// Prefer this over [delta] for new code — all operations are O(log n).
  TextDocument? get textDocument {
    if (_textDocument != null) return _textDocument;

    // Lazy fallback: parse from internal td or legacy delta.
    final tdRaw = _attributes['td'];
    if (tdRaw is TextDocument) {
      _textDocument = tdRaw;
      return _textDocument;
    }
    if (tdRaw is Map) {
      _textDocument =
          TextDocument.fromNativeJson(Map<String, dynamic>.from(tdRaw));
      return _textDocument;
    }
    final deltaRaw = _attributes['delta'];
    if (deltaRaw is List) {
      _textDocument = TextDocument.fromJson(deltaRaw);
      return _textDocument;
    }
    if (deltaRaw is Delta) {
      _textDocument = TextDocument.fromDelta(deltaRaw);
      return _textDocument;
    }
    return null;
  }

  /// The path of the node.
  Path get path => _computePath();

  NodeExternalValues? externalValues;

  /// this value is used to store temporary data,
  ///   and will be cleared after the node is rendered
  Map? extraInfos;

  // Render Part
  final key = GlobalKey();
  final layerLink = LayerLink();

  void notify() {
    notifyListeners();
  }

  /// Update the attributes of the node.
  ///
  /// When [attributes] contains a `delta` key the native [TextDocument]
  /// is re-parsed so that [textDocument] and [delta] stay in sync.
  void updateAttributes(Attributes attributes) {
    _attributes = composeAttributes(this.attributes, attributes) ?? {};

    // If text content changed, re-parse TextDocument.
    if (attributes.containsKey('td')) {
      final raw = attributes['td'];
      if (raw is Map<String, dynamic>) {
        _textDocument = TextDocument.fromNativeJson(raw);
      }
      if (raw is TextDocument) {
        _textDocument = raw;
      }
    } else if (attributes.containsKey('delta')) {
      // To maintain some type of retro-compatibility
      // we check if this element exists
      final raw = attributes['delta'];
      if (raw is List) {
        _textDocument = TextDocument.fromJson(raw);
        _attributes['td'] = _textDocument;
      }
      if (raw is Delta) {
        _textDocument = TextDocument.fromDelta(raw);
        _attributes['td'] = _textDocument;
      }
    }
    _attributes.remove('delta');

    // Invalidate the legacy Delta cache so the next [delta] read rebuilds
    // from the (possibly updated) TextDocument.
    _cachedDelta = null;
    _cachedDeltaRaw = null;

    notifyListeners();
  }

  /// Apply a [Delta] change to this node's text using the native
  /// [TextDocument] engine.
  ///
  /// This is the preferred mutation path for new code — it updates the
  /// treap in-place in O(log n) and writes the result back to [attributes]
  /// as native `td` JSON.  Legacy `delta` key in attributes is removed.
  ///
  /// If the node has no text yet an empty [TextDocument] is created first.
  void applyTextDelta(Delta change) {
    final td = textDocument ?? TextDocument();
    td.applyDelta(change);
    _textDocument = td;

    // Sync to attributes — native format only.
    final merged = Map<String, dynamic>.from(_attributes);
    merged['td'] = td;
    merged.remove('delta');
    _attributes = merged;

    _cachedDelta = null;
    _cachedDeltaRaw = null;
    notifyListeners();
  }

  /// Grabs the [Node] from this [Node]s children
  /// at a given index, if the index exists.
  ///
  Node? childAtIndexOrNull(int index) {
    if (length <= index || index < 0) {
      return null;
    }

    return children.elementAt(index);
  }

  Node? childAtPath(Path path) {
    // iterative on purpose: the recursive version allocated one
    // `path.sublist(1)` per level on one of the hottest lookup paths of
    // the editor (every selection check resolves nodes by path).
    Node? node = this;
    for (final index in path) {
      node = node?.childAtIndexOrNull(index);
      if (node == null) {
        return null;
      }
    }
    return node;
  }

  /// Inserts a [Node] at a given [index]
  ///
  /// If no [index] is supplied, inserts at the
  /// end of the [Node].
  ///
  void insert(Node entry, {int? index}) {
    final length = _children.length;
    index ??= length;

    entry._resetRelationshipIfNeeded();
    entry.parent = this;
    entry._indexCacheOwner = this;
    entry._indexCacheVersion = _childrenVersion;
    entry._cachedIndex = index;

    _invalidateChildrenCache();

    if (_children.isEmpty) {
      _children.add(entry);
      notifyListeners();
      return;
    }

    // If index is out of range, insert at the end.
    // If index is negative, insert at the beginning.
    // If index is positive, insert at the index.
    if (index >= length) {
      _children.last.insertAfter(entry);
    } else if (index <= 0) {
      _children.first.insertBefore(entry);
    } else {
      childAtIndexOrNull(index)?.insertBefore(entry);
    }
  }

  @override
  void insertAfter(Node entry) {
    entry._resetRelationshipIfNeeded();
    entry.parent = parent;
    entry._indexCacheOwner = parent;
    entry._indexCacheVersion = 0;
    entry._cachedIndex = next?._indexInParent() ?? _indexInParent() + 1;
    super.insertAfter(entry);

    parent?._invalidateChildrenCache();

    // Notifies the new node.
    parent?.notifyListeners();
  }

  @override
  void insertBefore(Node entry) {
    entry._resetRelationshipIfNeeded();
    entry.parent = parent;
    entry._indexCacheOwner = parent;
    entry._indexCacheVersion = 0;
    entry._cachedIndex = _indexInParent();
    super.insertBefore(entry);

    parent?._invalidateChildrenCache();

    // Notifies the new node.
    parent?.notifyListeners();
  }

  @override
  bool unlink() {
    // Add a null check to avoid unlink failure
    if (parent == null || list == null) {
      return false;
    }
    super.unlink();

    parent?._invalidateChildrenCache();

    parent?.notifyListeners();
    parent = null;
    return true;
  }

  // reset the relationship of the node before inserting it to another node
  //  to ensure it is not in the tree
  // otherwise, it will throw a state error
  //  'Bad state: LinkedNode is already in a LinkedList'
  void _resetRelationshipIfNeeded() {
    if (parent != null || list != null) {
      unlink();
    }
  }

  @override
  String toString() {
    return 'Node(id: $id, type: $type, attributes: $attributes, '
        'children: $children)';
  }

  /// Legacy rich-text accessor — delegates to [textDocument].
  ///
  /// Returns a [Delta] built from the native [TextDocument].  The result
  /// is identity-cached on the backing `td` / `delta` attribute so repeated
  /// reads on the same node are cheap.
  ///
  /// Treat the returned instance as immutable — its operations are shared
  /// with the cache and [Delta.add]/[Delta.insert] merge into the last
  /// operation IN PLACE. To derive a new value use `compose`/`slice`, or
  /// deep-copy first: `Delta.fromJson(node.delta!.toJson())`.
  Delta? get delta {
    final td = textDocument;
    if (td == null) return null;

    // Identity-cache on whichever attribute stores the text.
    final cacheKey = _attributes['td'] ?? _attributes['delta'];
    if (!identical(cacheKey, _cachedDeltaRaw)) {
      debugDeltaParseCount++;
      _cachedDeltaRaw = cacheKey;
      _cachedDelta = td.toDelta();
    }
    return _cachedDelta;
  }

  Map<String, Object> toJson({bool humanReadable = true}) {
    final map = <String, Object>{
      'id': id,
      'type': type,
    };
    if (children.isNotEmpty) {
      map['children'] = children
          .map(
            (node) => node.toJson(),
          )
          .toList(growable: false);
    }

    // Build the data map from attributes + native text.
    final data = <String, dynamic>{...attributes};

    // Ensure TextDocument is parsed if we have text attributes.
    final td = textDocument;

    // Write native text format, drop legacy delta.
    if (td != null && humanReadable) {
      data['delta'] = td.toDelta().toJson();
      data.remove('td');
    } else if (td != null) {
      data['td'] = td.toNativeJson();
      data.remove('delta');
    }

    if (data.isNotEmpty) {
      map['data'] = data;
    }
    return map;
  }

  /// Copy the node
  ///
  /// If the parameters are not provided, the original value will be used.
  ///
  /// Be careful of the children, they will be deep copied if not provided.
  Node copyWith({
    String? id,
    String? type,
    Iterable<Node>? children,
    Attributes? attributes,
    bool preserveId = true,
  }) {
    final node = Node(
      id: id ?? (preserveId ? this.id : nanoid(6)),
      type: type ?? this.type,
      attributes: attributes ?? {...this.attributes},
      children: children ?? [],
    );
    if (children == null && _children.isNotEmpty) {
      node._invalidateChildrenCache();
      node.adoptChildren(_children);
    }
    node.externalValues = externalValues;
    node.extraInfos = extraInfos;
    return node;
  }

  void adoptChildren(Iterable<Node> children) {
    if (children.isNotEmpty) {
      int index = 0;
      _cacheChildren = [];
      for (final child in children) {
        final copy = child.copyWith();
        copy
          ..parent = this
          .._indexCacheVersion = 0
          .._indexCacheOwner = this
          .._cachedIndex = index;
        _cacheChildren!.add(copy);
        _children.add(copy);
      }
    }
  }

  /// Deep copy the node
  ///
  /// This is a deep copy of the node, including the children.
  Node deepCopy() {
    return copyWith();
  }

  /// The index of this node inside [parent], amortized O(1).
  ///
  /// The first call after a children mutation re-indexes ALL siblings in
  /// one sweep, so computing the paths of n siblings costs O(n) instead
  /// of the former O(n²) of one `indexOf` per sibling — the editor
  /// resolves paths constantly (selections, rendering, transactions).
  int _indexInParent() {
    final parent = this.parent;
    if (parent == null) {
      return -1;
    }
    if (identical(_indexCacheOwner, parent) &&
        _indexCacheVersion == parent._childrenVersion) {
      return _cachedIndex;
    }
    parent._reindexChildren();
    if (identical(_indexCacheOwner, parent) &&
        _indexCacheVersion == parent._childrenVersion) {
      return _cachedIndex;
    }
    // not present in the parent's children (e.g. mid-unlink): preserve
    // the legacy `indexOf` behavior of returning -1.
    return -1;
  }

  void _reindexChildren() {
    debugReindexCount++;
    final list = children;
    for (var i = 0; i < list.length; i++) {
      final child = list[i];
      child._indexCacheOwner = this;
      child._indexCacheVersion = _childrenVersion;
      child._cachedIndex = i;
    }
  }

  Path _computePath([Path previous = const []]) {
    final parent = this.parent;
    if (parent == null) {
      return previous;
    }
    return parent._computePath(
      [
        _indexInParent(),
        ...previous,
      ],
    );
  }

  /// check the integrity of the document (for DEBUG only)
  void checkDocumentIntegrity() {
    // skip the root node
    if (path.isNotEmpty) {
      // if node is rendered in the tree, its parent should not be null
      final errorMessage =
          '''Please submit an issue to https://github.com/Novident/novident-editor/issues if you see this error!
          node = ${toJson()}''';
      assert(
        parent != null,
        errorMessage,
      );
      // also, its parent should contain this node
      assert(
        parent!.children.where((element) => element.id == id).length == 1,
        errorMessage,
      );
    }

    for (final child in children) {
      child.checkDocumentIntegrity();
    }
  }
}

extension NodeEquality on Iterable<Node> {
  bool equals(Iterable<Node> other) {
    if (length != other.length) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (!_nodeEquals(
        elementAt(i),
        other.elementAt(i),
      )) {
        return false;
      }
    }
    return true;
  }

  bool _nodeEquals<T, U>(T base, U other) =>
      identical(this, other) ||
      base is Node &&
          other is Node &&
          other.type == base.type &&
          other.children.equals(base.children);
}
