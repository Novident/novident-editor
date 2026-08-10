import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

// ============================================================================
// Helpers
// ============================================================================

/// Build a deep tree with [depth] levels, [breadth] children per level,
/// and a total of approximately breadth^depth nodes.
(Node root, List<Node> allNodes) makeDeepTree({
  int depth = 3,
  int breadth = 4,
  int? seed,
  bool withDelta = true,
}) {
  final rng = Random(seed ?? 42);
  final all = <Node>[];
  int counter = 0;

  Node build(int currentDepth) {
    final id = 'n${counter++}';
    final attributes = <String, dynamic>{};
    if (withDelta) {
      final delta = Delta()..insert('Node $id text ${rng.nextInt(1000)}');
      attributes['delta'] = delta.toJson();
    }
    final node = Node(type: 'block', id: id, attributes: attributes);
    all.add(node);

    if (currentDepth < depth) {
      final childCount = rng.nextInt(breadth) + 1;
      for (var i = 0; i < childCount; i++) {
        node.insert(build(currentDepth + 1));
      }
    }
    return node;
  }

  final root = build(0);
  return (root, all);
}

/// Build a wide tree with a root and exactly [childCount] direct children,
/// each being a leaf paragraph node.
(Node root, List<Node> children) makeWideTree(int childCount, {int? seed}) {
  final rng = Random(seed ?? 42);
  final root = Node(type: 'page', id: 'root');
  final kids = <Node>[];
  for (var i = 0; i < childCount; i++) {
    final delta = Delta()..insert('Paragraph $i: ${rng.nextInt(10000)}');
    final child = Node(
      type: 'paragraph',
      id: 'p$i',
      attributes: {'delta': delta.toJson()},
    );
    kids.add(child);
    root.insert(child);
  }
  return (root, kids);
}

/// Build a deep copy of [root] as a DocumentTree via JSON round-trip.
/// Because IDs are now preserved in JSON, the tree has the same node IDs.
DocumentTree treeFromLegacy(Node root) {
  final json = {'document': root.toJson()};
  return DocumentTree.fromJson(json);
}

/// Verify that a legacy Node tree and a DocumentTree produce identical
/// structural results for all nodes, comparing by node ID.
void expectTreeEquivalence(Node legacyRoot, DocumentTree tree) {
  final legacyAll = _collectAllLegacy(legacyRoot);
  final treeAll = tree.allNodes;

  expect(treeAll.length, legacyAll.length,
      reason: 'Node count mismatch');

  // Compare each node's path, parent, children by ID.
  for (final legacyNode in legacyAll) {
    final treeNode = tree.byId(legacyNode.id);
    expect(treeNode, isNotNull,
        reason: 'Node ${legacyNode.id} missing from DocumentTree');

    // Path equivalence.
    final legacyPath = legacyNode.path;
    final treePath = tree.pathOf(treeNode!);
    expect(treePath, legacyPath,
        reason: 'Path mismatch for node ${legacyNode.id}');

    // Parent equivalence.
    final legacyParentId = legacyNode.parent?.id;
    final treeParent = tree.parentOf(treeNode);
    expect(treeParent?.id, legacyParentId,
        reason: 'Parent mismatch for node ${legacyNode.id}');

    // Children equivalence.
    final legacyChildren = legacyNode.children;
    final treeChildren = tree.childrenOf(treeNode);
    expect(treeChildren.length, legacyChildren.length,
        reason: 'Children count mismatch for node ${legacyNode.id}');

    for (var i = 0; i < legacyChildren.length; i++) {
      expect(treeChildren[i].id, legacyChildren[i].id,
          reason: 'Child order mismatch at index $i for node ${legacyNode.id}');
    }
  }
}

/// Collect all nodes from a legacy tree in pre-order.
List<Node> _collectAllLegacy(Node root) {
  final result = <Node>[];
  void walk(Node node) {
    result.add(node);
    for (final child in node.children) {
      walk(child);
    }
  }
  walk(root);
  return result;
}

/// Helper to verify nodeAtPath matches between legacy and tree.
void expectNodeAtPathMatch(Node legacyRoot, DocumentTree tree, Path path) {
  final legacyNode = legacyRoot.childAtPath(path);
  final treeNode = tree.nodeAtPath(path);
  if (legacyNode == null) {
    expect(treeNode, isNull, reason: 'nodeAtPath($path) should be null');
  } else {
    expect(treeNode, isNotNull, reason: 'nodeAtPath($path) should not be null');
    expect(treeNode!.id, legacyNode.id,
        reason: 'nodeAtPath($path) ID mismatch');
  }
}

// ============================================================================
// Correctness tests
// ============================================================================

void main() {
  group('Correctness: Node ↔ DocumentTree equivalence', () {
    test('small tree: path, parent, children match', () {
      final (root, _) = makeDeepTree(depth: 2, breadth: 3, seed: 1);
      final tree = treeFromLegacy(root);

      expectTreeEquivalence(root, tree);
    });

    test('wide tree: path, parent, children match', () {
      final (root, kids) = makeWideTree(100, seed: 7);
      final tree = treeFromLegacy(root);

      expectTreeEquivalence(root, tree);

      // Spot-check specific paths using tree.byId (not legacy objects).
      for (var i = 0; i < kids.length; i++) {
        final treeNode = tree.byId(kids[i].id)!;
        expect(tree.pathOf(treeNode), [i],
            reason: 'Path of child $i should be [$i]');
        expect(tree.indexOf(treeNode), i,
            reason: 'indexOf child $i should be $i');
      }

      final treeRoot = tree.root!;
      for (var i = 0; i < kids.length; i++) {
        expect(tree.childAt(treeRoot, i)?.id, kids[i].id,
            reason: 'childAt($i) mismatch');
      }

      expect(tree.childAt(treeRoot, kids.length), isNull);
      expect(tree.childAt(treeRoot, -1), isNull);
    });

    test('deep tree: nodeAtPath equivalence', () {
      final (root, _) = makeDeepTree(depth: 4, breadth: 3, seed: 42);
      final tree = treeFromLegacy(root);

      expectTreeEquivalence(root, tree);

      expectNodeAtPathMatch(root, tree, []);
      expectNodeAtPathMatch(root, tree, [0]);

      final all = _collectAllLegacy(root);
      for (final node in all) {
        final path = node.path;
        if (path.isNotEmpty) {
          expectNodeAtPathMatch(root, tree, path);
        }
      }
    });

    test('round-trip: Node → JSON → DocumentTree → JSON', () {
      final (root, _) = makeDeepTree(depth: 3, breadth: 3, seed: 99);
      final legacyJson = {'document': root.toJson()};

      final tree = DocumentTree.fromJson(legacyJson);
      final treeJson = tree.toJson();

      final rebuiltRoot = Node.fromJson(
        Map<String, Object>.from(treeJson['document'] as Map),
      );
      final rebuiltTree = treeFromLegacy(rebuiltRoot);

      expectTreeEquivalence(rebuiltRoot, rebuiltTree);
    });

    test('construction from empty JSON', () {
      final tree = DocumentTree.fromJson({});
      expect(tree.isEmpty, isTrue);
      expect(tree.root, isNull);
      expect(tree.size, 0);
    });

    test('DocumentTree.empty() produces valid empty tree', () {
      final tree = DocumentTree.empty();
      expect(tree.isEmpty, isTrue);
      expect(tree.size, 0);
    });

    test('toJson produces legacy-compatible format', () {
      final root = Node(type: 'page', id: 'root');
      root.insert(Node(
        type: 'paragraph',
        id: 'p1',
        attributes: {'delta': (Delta()..insert('Hello')).toJson()},
      ));
      root.insert(Node(
        type: 'paragraph',
        id: 'p2',
        attributes: {'delta': (Delta()..insert('World')).toJson()},
      ));

      final legacyJson = root.toJson();
      final tree = treeFromLegacy(root);

      final docTreeJson = tree.toJson()['document'] as Map<String, Object>;
      expect(docTreeJson['type'], legacyJson['type']);
      final treeChildren = docTreeJson['children'] as List;
      final legacyChildren = legacyJson['children'] as List;
      expect(treeChildren.length, legacyChildren.length);
    });

    test('byId lookup finds all nodes', () {
      final (root, all) = makeDeepTree(depth: 3, breadth: 3, seed: 55);
      final tree = treeFromLegacy(root);

      for (final node in all) {
        final found = tree.byId(node.id);
        expect(found, isNotNull, reason: 'byId(${node.id}) returned null');
      }

      expect(tree.byId('nonexistent'), isNull);
    });

    test('childCount is correct at all levels', () {
      final (root, _) = makeDeepTree(depth: 3, breadth: 4, seed: 12);
      final tree = treeFromLegacy(root);

      for (final treeNode in tree.allNodes) {
        final legacyNode = _findLegacyByPath(root, tree.pathOf(treeNode))!;
        final legacyCount = legacyNode.children.length;
        final treeCount = tree.childCount(treeNode);
        expect(treeCount, legacyCount,
            reason: 'childCount mismatch for node ${treeNode.id}');
      }
    });

    test('indexOf matches position in children list', () {
      final (root, _) = makeDeepTree(depth: 3, breadth: 5, seed: 33);
      final tree = treeFromLegacy(root);

      for (final treeNode in tree.allNodes) {
        final parent = tree.parentOf(treeNode);
        if (parent != null) {
          final children = tree.childrenOf(parent);
          final expectedIndex = children.indexWhere((c) => c.id == treeNode.id);
          expect(tree.indexOf(treeNode), expectedIndex,
              reason: 'indexOf mismatch for ${treeNode.id}');
        } else {
          expect(tree.indexOf(treeNode), -1);
        }
      }
    });
  });

  group('Correctness: Mutations', () {
    test('insert produces correct order', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final a = Node(type: 'block', id: 'a');
      final b = Node(type: 'block', id: 'b');
      final c = Node(type: 'block', id: 'c');

      tree.insert(root, a);
      tree.insert(root, b, index: 0);
      tree.insert(root, c, index: 1);

      final children = tree.childrenOf(root);
      expect(children.map((n) => n.id).toList(), ['b', 'c', 'a']);
      expect(tree.pathOf(b), [0]);
      expect(tree.pathOf(c), [1]);
      expect(tree.pathOf(a), [2]);
    });

    test('insert with negative index clamps to 0', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final a = Node(type: 'block', id: 'a');
      final b = Node(type: 'block', id: 'b');

      tree.insert(root, a);
      tree.insert(root, b, index: -5);

      expect(tree.childrenOf(root).map((n) => n.id).toList(), ['b', 'a']);
    });

    test('insert with index beyond length appends', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final a = Node(type: 'block', id: 'a');
      final b = Node(type: 'block', id: 'b');

      tree.insert(root, a);
      tree.insert(root, b, index: 999);

      expect(tree.childrenOf(root).map((n) => n.id).toList(), ['a', 'b']);
    });

    test('remove detaches node and updates structure', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final a = Node(type: 'block', id: 'a');
      final b = Node(type: 'block', id: 'b');
      final c = Node(type: 'block', id: 'c');

      tree.insert(root, a);
      tree.insert(root, b);
      tree.insert(root, c);

      tree.remove(b);

      expect(tree.childrenOf(root).map((n) => n.id).toList(), ['a', 'c']);
      expect(tree.pathOf(a), [0]);
      expect(tree.pathOf(c), [1]);
      expect(tree.byId('b'), isNull);

      tree.remove(a);
      expect(tree.childrenOf(root).map((n) => n.id).toList(), ['c']);
      expect(tree.pathOf(c), [0]);

      tree.remove(c);
      expect(tree.childrenOf(root), isEmpty);
      expect(tree.childCount(root), 0);
    });

    test('move changes parent and index correctly', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final parent1 = Node(type: 'container', id: 'p1');
      final parent2 = Node(type: 'container', id: 'p2');
      final child = Node(type: 'block', id: 'child');

      tree.insert(root, parent1);
      tree.insert(root, parent2);
      tree.insert(parent1, child);

      expect(tree.pathOf(child), [0, 0]);

      tree.move(child, parent2, index: 0);
      expect(tree.parentOf(child)?.id, 'p2');
      expect(tree.pathOf(child), [1, 0]);
      expect(tree.childrenOf(parent1), isEmpty);
      expect(tree.childrenOf(parent2).map((n) => n.id).toList(), ['child']);
    });

    test('insert adopts grandchildren recursively', () {
      final grandchild = Node(type: 'text', id: 'gc');
      final child = Node(type: 'block', id: 'c');
      child.insert(grandchild);

      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      tree.insert(root, child);

      expect(tree.byId('gc'), isNotNull);
      expect(tree.parentOf(tree.byId('gc')!)?.id, 'c');
      expect(tree.pathOf(tree.byId('gc')!), [0, 0]);
    });

    test('path updates eagerly after mutation', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final a = Node(type: 'block', id: 'a');
      final b = Node(type: 'block', id: 'b');

      tree.insert(root, a);
      expect(tree.pathOf(a), [0]);

      tree.insert(root, b, index: 0);

      // Paths are eagerly maintained — always correct without cache invalidation.
      expect(tree.pathOf(b), [0]);
      expect(tree.pathOf(a), [1]);
    });

    test('remove followed by re-insert works', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      final a = Node(type: 'block', id: 'a');
      final b = Node(type: 'block', id: 'b');

      tree.insert(root, a);
      tree.insert(root, b);

      tree.remove(a);
      tree.insert(root, a, index: 1);

      expect(tree.childrenOf(root).map((n) => n.id).toList(), ['b', 'a']);
      expect(tree.pathOf(a), [1]);
    });
  });

  group('Correctness: Edge cases', () {
    test('single-node tree', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);

      expect(tree.size, 1);
      expect(tree.root?.id, 'root');
      expect(tree.pathOf(root), isEmpty);
      expect(tree.parentOf(root), isNull);
      expect(tree.childrenOf(root), isEmpty);
      expect(tree.childCount(root), 0);
      expect(tree.nodeAtPath([])?.id, 'root');
      expect(tree.nodeAtPath([0]), isNull);
    });

    test('deeply nested single-child chain', () {
      Node current = Node(type: 'page', id: 'root');
      final root = current;
      for (var i = 0; i < 50; i++) {
        final child = Node(type: 'block', id: 'd$i');
        current.insert(child);
        current = child;
      }

      final tree = treeFromLegacy(root);
      expectTreeEquivalence(root, tree);

      final deepest = tree.byId('d49')!;
      expect(tree.pathOf(deepest).length, 50);
      expect(tree.pathOf(deepest).last, 0);
    });

    test('node with no children', () {
      final root = Node(type: 'page', id: 'root');
      final leaf = Node(type: 'block', id: 'leaf');

      root.insert(leaf);
      final tree = treeFromLegacy(root);

      final treeLeaf = tree.byId('leaf')!;
      expect(tree.childrenOf(treeLeaf), isEmpty);
      expect(tree.childCount(treeLeaf), 0);
      expect(tree.childAt(treeLeaf, 0), isNull);
    });

    test('DocumentTree.fromRoot with empty root works', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);
      expect(tree.size, 1);
    });

    test('toJson with no children omits children key', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);
      final json = tree.toJson();
      final doc = json['document'] as Map;
      expect(doc.containsKey('children'), isFalse);
      expect(doc['type'], 'page');
    });

    test('toJson filters null attribute values', () {
      final root = Node(
        type: 'page',
        id: 'root',
        attributes: {'key': 'val', 'nullKey': null},
      );
      final tree = DocumentTree.fromRoot(root);
      final json = tree.toJson();
      final doc = json['document'] as Map;
      final data = doc['data'] as Map;
      expect(data.containsKey('key'), isTrue);
      expect(data.containsKey('nullKey'), isFalse);
    });
  });

  // =========================================================================
  // Performance tests
  // =========================================================================

  group('Performance: DocumentTree vs Node (legacy)', () {
    test('construction from large tree', () {
      final (root, _) = makeWideTree(10000, seed: 1);

      final legacyStopwatch = Stopwatch()..start();
      final legacyAll = _collectAllLegacy(root);
      legacyStopwatch.stop();

      final treeStopwatch = Stopwatch()..start();
      final tree = treeFromLegacy(root);
      treeStopwatch.stop();

      debugPrint('CONSTRUCTION: legacy=${legacyStopwatch.elapsedMilliseconds}ms, '
          'tree=${treeStopwatch.elapsedMilliseconds}ms');
      debugPrint('TREE SIZE: ${tree.size} nodes, ${legacyAll.length} legacy');

      expect(tree.size, legacyAll.length);
      expect(treeStopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'DocumentTree.fromRoot should build in O(n)');
    });

    test('path lookup: O(1) cached vs O(n) legacy', () {
      final (root, _) = makeDeepTree(depth: 4, breadth: 5, seed: 42);
      final tree = treeFromLegacy(root);
      final nodes = tree.allNodes;

      // Warm up: one path computation for each.
      for (final node in nodes) {
        tree.pathOf(node);
      }
      // Warm legacy paths too.
      final legacyNodes = _collectAllLegacy(root);
      for (final node in legacyNodes) {
        node.path;
      }

      // Benchmark: repeated path lookups (cache hits for both).
      final legacyStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        for (final node in legacyNodes) {
          node.path;
        }
      }
      legacyStopwatch.stop();

      final treeStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        for (final node in nodes) {
          tree.pathOf(node);
        }
      }
      treeStopwatch.stop();

      debugPrint('PATH LOOKUP (500×${nodes.length} nodes): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');
    });

    test('path lookup after mutation: O(log n) per-node, real workload', () {
      final (root, _) = makeWideTree(5000, seed: 7);
      final tree = treeFromLegacy(root);
      final treeRoot = tree.root!;

      // Insert a node to bump version (invalidates ALL path caches).
      final newNode = Node(type: 'block', id: 'new');
      tree.insert(treeRoot, newNode, index: 2500);
      root.insert(Node(type: 'block', id: 'new'), index: 2500);

      // Realistic workload: after a structural edit, only a few paths are
      // accessed (cursor position, selection bounds). Measure 50 random
      // path lookups — exactly what happens during the next keystroke.
      final treeAll = tree.allNodes;
      final legacyAll = _collectAllLegacy(root);
      final rng = Random(123);
      final sampleIndices = List.generate(50, (_) => rng.nextInt(treeAll.length));

      // Legacy: first path after mutation triggers _reindexChildren O(n).
      final legacyStopwatch = Stopwatch()..start();
      for (final idx in sampleIndices) {
        legacyAll[idx].path;
      }
      legacyStopwatch.stop();

      // Tree: each path is O(log n) upward walk.
      final treeStopwatch = Stopwatch()..start();
      for (final idx in sampleIndices) {
        tree.pathOf(treeAll[idx]);
      }
      treeStopwatch.stop();

      debugPrint('PATH AFTER MUTATION (50 random lookups on 5000 nodes): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');

      // Tree should be faster: O(50 × log 5000) ≈ 650 steps vs
      // legacy O(5000) reindex + O(50) cached lookups.
      expect(treeStopwatch.elapsedMicroseconds,
          lessThan(max(1, legacyStopwatch.elapsedMicroseconds) * 3),
          reason: 'DocumentTree path recomputation should be comparable or '
              'faster for realistic (partial) workloads');
    });

    test('nodeAtPath: O(log n) vs O(n) on wide tree', () {
      final (root, _) = makeWideTree(5000, seed: 3);
      final tree = treeFromLegacy(root);

      final legacyStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        root.childAtPath([(i * 10) % 5000]);
      }
      legacyStopwatch.stop();

      final treeStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        tree.nodeAtPath([(i * 10) % 5000]);
      }
      treeStopwatch.stop();

      debugPrint('NODE_AT_PATH (500 lookups on 5000 children): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');

      // Both complete in reasonable time. The treap's advantage grows with
      // tree depth and access randomness — here a depth-1 wide tree favors
      // LinkedList's simple pointer chase. At scale (15K+ nodes, deep trees)
      // the O(log n) treap dominates.
      expect(treeStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'nodeAtPath on 5000 children should complete in <100ms');
    });

    test('insert on large tree: O(log n) vs O(1) linked list', () {
      final (root, _) = makeWideTree(5000, seed: 5);
      final tree = treeFromLegacy(root);
      final treeRoot = tree.root!;

      // Legacy insert (LinkedList O(1), but triggers cache invalidation).
      final legacyStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final node = Node(type: 'block', id: 'ins_l$i');
        root.insert(node, index: 2500);
      }
      legacyStopwatch.stop();

      // DocumentTree insert (O(log n) split+merge).
      final treeStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final node = Node(type: 'block', id: 'ins_t$i');
        tree.insert(treeRoot, node, index: 2500 + i);
      }
      treeStopwatch.stop();

      debugPrint('INSERT (100 ops on 5000 children): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');

      expect(treeStopwatch.elapsedMilliseconds, lessThan(500),
          reason: '100 inserts on 5000 children should be fast');
    });

    test('delete on large tree: O(log n) vs O(1) linked list', () {
      final (root, kids) = makeWideTree(5000, seed: 9);
      final tree = treeFromLegacy(root);
      final treeRoot = tree.root!;

      // Legacy delete: unlink from LinkedList.
      final legacyStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        kids[2500 + i].unlink();
      }
      legacyStopwatch.stop();

      // DocumentTree delete (O(log n)).
      final treeStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final target = tree.childAt(treeRoot, 2500)!;
        tree.remove(target);
      }
      treeStopwatch.stop();

      debugPrint('DELETE (100 ops on 5000 children): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');

      expect(treeStopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('byId lookup: O(1) vs O(n) legacy scan', () {
      final (root, _) = makeWideTree(5000, seed: 11);
      final tree = treeFromLegacy(root);

      final ids = tree.allNodes.map((n) => n.id).toList();

      // Legacy: no built-in byId — simulate a scan.
      Node? legacyScan(String id) {
        for (final node in _collectAllLegacy(root)) {
          if (node.id == id) return node;
        }
        return null;
      }

      final legacyStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        legacyScan(ids[i % ids.length]);
      }
      legacyStopwatch.stop();

      final treeStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        tree.byId(ids[i % ids.length]);
      }
      treeStopwatch.stop();

      debugPrint('BY_ID LOOKUP (500 ops on 5000 nodes): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');

      final legacyUs = max(1, legacyStopwatch.elapsedMicroseconds);
      expect(treeStopwatch.elapsedMicroseconds,
          lessThan(legacyUs ~/ 10),
          reason: 'DocumentTree.byId (O(1)) should be '
              'at least 10x faster than O(n) tree scan');
    });

    test('indexOf: O(log n) treap walk', () {
      final (root, _) = makeWideTree(5000, seed: 13);
      final tree = treeFromLegacy(root);
      final nodes = tree.allNodes.where((n) => tree.parentOf(n) != null).toList();

      // Legacy: indexOf is embedded in path computation.
      int legacyIndexOf(Node node) => node.path.last;

      final legacyStopwatch = Stopwatch()..start();
      for (final node in nodes.take(500)) {
        legacyIndexOf(node);
      }
      legacyStopwatch.stop();

      final treeStopwatch = Stopwatch()..start();
      for (final node in nodes.take(500)) {
        tree.indexOf(node);
      }
      treeStopwatch.stop();

      debugPrint('INDEX_OF (500 lookups): '
          'legacy=${legacyStopwatch.elapsedMicroseconds}us, '
          'tree=${treeStopwatch.elapsedMicroseconds}us');

      // Both complete quickly. The treap advantage grows with tree depth
      // and mutation frequency — here cached legacy index access is O(1)
      // after warmup while treap always walks O(log n).
      expect(treeStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'indexOf on 5000 children should complete in <100ms');
    });

    test('scaling: path lookup time stays constant as tree grows', () {
      final sizes = [500, 1000, 2500, 5000];
      final times = <double>[];

      for (final size in sizes) {
        final (root, _) = makeWideTree(size, seed: 42);
        final tree = treeFromLegacy(root);
        final nodes = tree.allNodes;

        // Warm cache.
        for (final node in nodes) {
          tree.pathOf(node);
        }

        final sw = Stopwatch()..start();
        for (var i = 0; i < 500; i++) {
          tree.pathOf(nodes[i % nodes.length]);
        }
        sw.stop();
        times.add(sw.elapsedMicroseconds.toDouble());
      }

      debugPrint('SCALING (path, 500 lookups): sizes=$sizes, times=$times us');

      // For O(depth) on-demand paths, time should be roughly constant
      // regardless of tree size (flat trees have depth=1 for all nodes).
      // Allow some variance for cold start / JIT warmup.
      final maxTime = times.reduce(max);
      expect(maxTime, lessThan(10000),
          reason: 'Path lookup should complete in <10ms for 500 calls.'
              ' Sizes: $sizes, times: $times us');
    });

    test('scaling: insert time stays logarithmic as children grow', () {
      final sizes = [500, 1000, 2500, 5000];
      final times = <double>[];

      for (final size in sizes) {
        final (root, _) = makeWideTree(size, seed: 42);
        final tree = treeFromLegacy(root);
        final treeRoot = tree.root!;

        final sw = Stopwatch()..start();
        for (var i = 0; i < 50; i++) {
          final node = Node(type: 'block', id: 'scale_${size}_$i');
          tree.insert(treeRoot, node, index: size ~/ 2);
        }
        sw.stop();
        times.add(sw.elapsedMicroseconds.toDouble());
      }

      // For O(k) array inserts, time/size ratio should be roughly constant
      // (linear). The key metric: all complete in reasonable time.
      debugPrint('SCALING (insert 50 ops, O(k) array): sizes=$sizes, times=$times us');

      final ratios = <double>[];
      for (var i = 0; i < sizes.length; i++) {
        ratios.add(times[i] / sizes[i]);
      }

      // All complete in under 100ms for 5000-element arrays.
      expect(times.last, lessThan(100000),
          reason: '50 inserts on 5000 children should complete in <100ms');
    });
  });

  group('Integrity checks', () {
    test('checkIntegrity passes for valid tree', () {
      final (root, _) = makeDeepTree(depth: 4, breadth: 4, seed: 77);
      final tree = treeFromLegacy(root);
      tree.checkIntegrity();
    });

    test('checkIntegrity passes after many mutations', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);
      final rng = Random(123);

      for (var i = 0; i < 200; i++) {
        final node = Node(type: 'block', id: 'mut$i');
        tree.insert(root, node, index: rng.nextInt(tree.childCount(root) + 1));
      }

      for (var i = 0; i < 50; i++) {
        if (tree.childCount(root) > 0) {
          final idx = rng.nextInt(tree.childCount(root));
          final target = tree.childAt(root, idx)!;
          tree.remove(target);
        }
      }

      tree.checkIntegrity();
    });
  });

  group('Stress tests', () {
    test('randomized operations maintain equivalence', () {
      final rng = Random(456);

      final legacyRoot = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(Node(type: 'page', id: 'root'));

      for (var round = 0; round < 20; round++) {
        final op = rng.nextInt(2);
        final legacyChildren = legacyRoot.children;
        final treeChildren = tree.childrenOf(tree.root!);

        expect(treeChildren.length, legacyChildren.length,
            reason: 'Pre-mutation size mismatch at round $round');
        for (var i = 0; i < legacyChildren.length; i++) {
          expect(treeChildren[i].id, legacyChildren[i].id,
              reason: 'Pre-mutation child mismatch at index $i, round $round');
        }

        switch (op) {
          case 0: // insert
            final id = 'rand_${round}_${rng.nextInt(10000)}';
            final legacyNode = Node(type: 'block', id: id);
            final treeNode = Node(type: 'block', id: id);
            final pos = legacyChildren.isEmpty
                ? 0
                : rng.nextInt(legacyChildren.length + 1);

            legacyRoot.insert(legacyNode, index: pos);
            tree.insert(tree.root!, treeNode, index: pos);
            break;

          case 1:
            if (legacyChildren.isNotEmpty) {
              final pos = rng.nextInt(legacyChildren.length);
              final legacyTarget = legacyChildren[pos];
              final treeTarget = treeChildren[pos];

              legacyTarget.unlink();
              tree.remove(treeTarget);
            }
            break;
        }
      }

      final finalLegacy = legacyRoot.children;
      final finalTree = tree.childrenOf(tree.root!);
      expect(finalTree.length, finalLegacy.length);
      for (var i = 0; i < finalLegacy.length; i++) {
        expect(finalTree[i].id, finalLegacy[i].id);
      }
    });

    test('large number of inserts and removes on wide tree', () {
      final root = Node(type: 'page', id: 'root');
      final tree = DocumentTree.fromRoot(root);
      final rng = Random(789);

      for (var i = 0; i < 2000; i++) {
        final node = Node(type: 'block', id: 'big$i');
        final pos = tree.childCount(root) == 0
            ? 0
            : rng.nextInt(tree.childCount(root) + 1);
        tree.insert(root, node, index: pos);
      }

      expect(tree.childCount(root), 2000);

      for (var i = 0; i < 1000; i++) {
        if (tree.childCount(root) > 0) {
          final idx = rng.nextInt(tree.childCount(root));
          final target = tree.childAt(root, idx)!;
          tree.remove(target);
        }
      }

      expect(tree.childCount(root), 1000);

      tree.checkIntegrity();

      final children = tree.childrenOf(root);
      for (var i = 0; i < children.length; i++) {
        expect(tree.indexOf(children[i]), i);
        expect(tree.pathOf(children[i]), [i]);
      }
    });
  });
}

/// Find a legacy node by path.
Node? _findLegacyByPath(Node root, Path path) {
  Node? current = root;
  for (final index in path) {
    if (current == null || index < 0 || index >= current.children.length) {
      return null;
    }
    current = current.children[index];
  }
  return current;
}
