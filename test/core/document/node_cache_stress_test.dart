import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Stress tests for the Node-level caches under COMPLEX tree surgery:
///
/// * instrumented cache-hit proofs ([Node.debugReindexCount] /
///   [Node.debugDeltaParseCount] must not move on repeated reads);
/// * cross-container movements: list items into table cells, cell
///   paragraphs out to the root, whole tables relocated, nested subtrees
///   reparented across branches;
/// * a seeded randomized fuzz of 150 arbitrary moves over the whole tree,
///   validating the full path/lookup invariant after every single move.
void main() {
  /// Heterogeneous document: headings, quote, 3-level nested lists, a
  /// 3x3 table (cells contain paragraph children at depth 3) and a
  /// paragraph subtree 4 levels deep — ~70 nodes total.
  Document buildComplexDocument() {
    final table = TableNode.fromList([
      ['t00', 't01', 't02'],
      ['t10', 't11', 't12'],
      ['t20', 't21', 't22'],
    ]).node;

    return Document(
      root: pageNode(
        children: <Node>[
          headingNode(level: 1, text: 'title'),
          paragraphNode(text: 'intro'),
          quoteNode(delta: Delta()..insert('a quote')),
          bulletedListNode(
            text: 'list A',
            children: <Node>[
              bulletedListNode(
                text: 'list A.0',
                children: <Node>[
                  bulletedListNode(text: 'list A.0.0'),
                  bulletedListNode(text: 'list A.0.1'),
                ],
              ),
              bulletedListNode(text: 'list A.1'),
            ],
          ),
          numberedListNode(
            delta: Delta()..insert('num B'),
            children: <Node>[
              numberedListNode(delta: Delta()..insert('num B.0')),
              numberedListNode(
                delta: Delta()..insert('num B.1'),
                children: <Node>[
                  paragraphNode(text: 'num B.1.0'),
                ],
              ),
            ],
          ),
          table,
          paragraphNode(
            text: 'deep 0',
            children: <Node>[
              paragraphNode(
                text: 'deep 1',
                children: <Node>[
                  paragraphNode(
                    text: 'deep 2',
                    children: <Node>[paragraphNode(text: 'deep 3')],
                  ),
                ],
              ),
            ],
          ),
          for (var i = 0; i < 12; i++) paragraphNode(text: 'filler $i'),
        ],
      ),
    );
  }

  List<Node> allNodes(Document document) {
    final result = <Node>[];
    void visit(Node node) {
      for (final child in node.children) {
        result.add(child);
        visit(child);
      }
    }

    visit(document.root);
    return result;
  }

  /// The invariant the whole editor relies on.
  void expectConsistentTree(Document document) {
    void verify(Node node) {
      final children = node.children;
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        expect(child.path.last, i);
        expect(identical(child.parent, node), true);
        expect(
          identical(document.nodeAtPath(child.path), child),
          true,
          reason: 'childAtPath(${child.path}) must resolve to the same node',
        );
        verify(child);
      }
    }

    verify(document.root);
  }

  void warmPaths(Document document) {
    for (final node in allNodes(document)) {
      node.path;
    }
  }

  bool isInSubtree(Node candidate, Node root) {
    Node? current = candidate;
    while (current != null) {
      if (identical(current, root)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Moves [node] to [targetParent] at [index] the way transactions do:
  /// document.delete at the source path, then insert at the target.
  void move(Document document, Node node, Node targetParent, int index) {
    document.delete(node.path);
    targetParent.insert(node, index: index);
  }

  group('instrumented path cache hits', () {
    test('repeated path reads perform ZERO re-index sweeps', () {
      final document = buildComplexDocument();
      warmPaths(document);

      final before = Node.debugReindexCount;
      for (var round = 0; round < 5; round++) {
        warmPaths(document);
      }
      expect(Node.debugReindexCount, before,
          reason: 'warm path reads must be pure cache hits');
    });

    test('one top-level insert costs exactly ONE re-index sweep', () {
      final document = buildComplexDocument();
      warmPaths(document);

      document.insert([3], [paragraphNode(text: 'wedge')]);

      final before = Node.debugReindexCount;
      warmPaths(document);
      expect(Node.debugReindexCount, before + 1,
          reason: 'only the root children changed: one sweep, '
              'untouched branches stay cached');
    });

    test('a cross-parent move costs exactly TWO re-index sweeps', () {
      final document = buildComplexDocument();
      warmPaths(document);

      // list A.0.0 → into num B (two distinct parents mutate).
      final source = document.nodeAtPath([3, 0, 0])!;
      final targetParent = document.nodeAtPath([4])!;
      move(document, source, targetParent, 1);

      final before = Node.debugReindexCount;
      warmPaths(document);
      expect(Node.debugReindexCount, before + 2,
          reason: 'source parent + target parent, nothing else');
      expectConsistentTree(document);
    });
  });

  group('delta cache across movements', () {
    test('moving nodes never invalidates their parsed delta', () {
      final document = buildComplexDocument();
      // warm deltas.
      final deltas = <Node, Delta?>{
        for (final node in allNodes(document)) node: node.delta,
      };

      // list item → INTO a table cell.
      final listItem = document.nodeAtPath([3, 1])!;
      final cell = document.nodeAtPath([5, 4])!; // some table/cell
      move(document, listItem, cell, cell.children.length);

      // cell paragraph → OUT to the root.
      final cellParagraph = document.nodeAtPath([5, 0, 0])!;
      move(document, cellParagraph, document.root, 2);

      final parsesBefore = Node.debugDeltaParseCount;
      for (final entry in deltas.entries) {
        expect(identical(entry.key.delta, entry.value), true,
            reason: 'a move must not drop the cached delta '
                '(${entry.value?.toPlainText()})');
      }
      expect(Node.debugDeltaParseCount, parsesBefore,
          reason: 'zero re-parses after pure structural moves');
      expectConsistentTree(document);
    });
  });

  group('complex cross-container movements', () {
    test('table ↔ outside, lists ↔ branches, deep subtrees relocated', () {
      final document = buildComplexDocument();
      warmPaths(document);
      final totalNodes = allNodes(document).length;

      // 1. nested list item (depth 3) → INTO a table cell (depth 3).
      final deepListItem = document.nodeAtPath([3, 0, 1])!;
      final cellA = document.nodeAtPath([5, 0])!;
      move(document, deepListItem, cellA, cellA.children.length);
      expectConsistentTree(document);

      // 2. a cell's paragraph → OUT of the table, to the root middle.
      final cellParagraph = document.nodeAtPath([5, 8, 0])!;
      move(document, cellParagraph, document.root, 1);
      expectConsistentTree(document);

      // 3. the WHOLE table (big subtree) relocated to the end of root.
      final table = allNodes(document)
          .firstWhere((n) => n.type == TableBlockKeys.type);
      move(document, table, document.root, document.root.children.length - 1);
      expectConsistentTree(document);
      expect(table.path.length, 1);

      // 4. a nested list PARENT with its whole subtree → inside the deep
      //    paragraph chain (reparent subtree under another subtree).
      final listA0 = allNodes(document).firstWhere(
        (n) => n.delta?.toPlainText() == 'list A.0',
      );
      final deep2 = allNodes(document).firstWhere(
        (n) => n.delta?.toPlainText() == 'deep 2',
      );
      move(document, listA0, deep2, 0);
      expectConsistentTree(document);
      // its grandchildren moved with it and resolve at their new depth.
      final a00 = allNodes(document).firstWhere(
        (n) => n.delta?.toPlainText() == 'list A.0.0',
      );
      expect(identical(document.nodeAtPath(a00.path), a00), true);
      expect(a00.path.length, greaterThanOrEqualTo(4));

      // 5. deep → shallow → deep round trip of the same node.
      final deep3 = allNodes(document).firstWhere(
        (n) => n.delta?.toPlainText() == 'deep 3',
      );
      move(document, deep3, document.root, 0);
      expectConsistentTree(document);
      expect(deep3.path, [0]);
      final backTarget = allNodes(document).firstWhere(
        (n) => n.delta?.toPlainText() == 'num B.1',
      );
      move(document, deep3, backTarget, 0);
      expectConsistentTree(document);
      expect(deep3.path.length, greaterThanOrEqualTo(3));

      // no node lost or duplicated through all of it.
      expect(allNodes(document).length, totalNodes);
    });
  });

  group('randomized move fuzz', () {
    test('150 seeded random moves keep every lookup consistent', () {
      final document = buildComplexDocument();
      final random = Random(42);
      final totalNodes = allNodes(document).length;

      // witnesses: nodes we never move; their cached delta must survive
      // the whole storm untouched (no spurious invalidation).
      final witnesses = <Node, Delta?>{};
      for (final node in allNodes(document)) {
        final text = node.delta?.toPlainText() ?? '';
        if (text.startsWith('filler')) {
          witnesses[node] = node.delta;
        }
      }
      expect(witnesses.length, greaterThanOrEqualTo(10));

      for (var i = 0; i < 150; i++) {
        final nodes = allNodes(document);

        // source: any non-witness node.
        final source = nodes[random.nextInt(nodes.length)];
        if (witnesses.containsKey(source)) {
          continue;
        }

        // target parent: any node (root included) OUTSIDE the source's
        // subtree — a node cannot be moved into itself.
        final candidates = <Node>[document.root, ...nodes]
            .where((n) => !isInSubtree(n, source))
            .toList();
        final targetParent = candidates[random.nextInt(candidates.length)];
        final index = random.nextInt(targetParent.children.length + 1);

        move(document, source, targetParent, index);

        // full invariant after EVERY move.
        expectConsistentTree(document);
      }

      // nothing lost, nothing duplicated.
      expect(allNodes(document).length, totalNodes);

      // witnesses kept their cached delta identity through 150 moves.
      for (final entry in witnesses.entries) {
        expect(identical(entry.key.delta, entry.value), true);
      }

      // and the whole tree still serializes/deserializes losslessly.
      final json = document.toJson();
      final roundTrip = Document.fromJson(json).toJson();
      expect(const DeepCollectionEquality().equals(json, roundTrip), true);
    });
  });
}
