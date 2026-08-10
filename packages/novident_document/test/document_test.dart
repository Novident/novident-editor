import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

/// Helper: creates a paragraph-like node with a delta attribute.
Node _paragraphNode({String? text, Delta? delta}) {
  return Node(
    type: 'paragraph',
    attributes: {
      'delta': (delta ?? (Delta()..insert(text ?? ''))).toJson(),
    },
  );
}

void main() async {
  group('document.dart', () {
    test('insert', () {
      final document = Document.blank();

      expect(document.insert([-1], []), false);
      expect(document.insert([100], []), false);

      final node0 = Node(type: '0');
      final node1 = Node(type: '1');
      final node2 = Node(type: '2');
      expect(document.insert([0], [node0, node1]), true);
      expect(document.nodeAtPath([0])?.type, '0');
      expect(document.nodeAtPath([1])?.type, '1');

      expect(document.insert([0], [node2]), true);
      expect(document.nodeAtPath([0])?.type, '2');
      expect(document.nodeAtPath([1])?.type, '0');
      expect(document.nodeAtPath([2])?.type, '1');
    });

    test('delete', () {
      final document = Document(root: Node(type: 'root'));

      expect(document.delete([-1], 1), false);
      expect(document.delete([100], 1), false);

      for (var i = 0; i < 10; i++) {
        final node = Node(type: '$i');
        document.insert([i], [node]);
      }

      document.delete([0], 10);
      expect(document.root.children.isEmpty, true);
    });

    test('update', () {
      final firstRootAttr = {'b': 'c'};

      final node = Node(type: 'example', attributes: {'a': 'a'});
      final document =
          Document(root: Node(type: 'root', attributes: firstRootAttr));
      document.insert([0], [node]);

      final rootAttributes = {'b': 'b'};
      final attributes = {'a': 'b', 'b': 'c'};

      expect(document.nodeAtPath([])?.attributes, firstRootAttr);
      expect(document.update([], rootAttributes), true);
      expect(document.nodeAtPath([])?.attributes, rootAttributes);

      expect(document.update([0], attributes), true);
      expect(document.nodeAtPath([0])?.attributes, attributes);

      expect(document.update([-1], attributes), false);
    });

    test('updateText', () {
      final delta = Delta()..insert('Editor');
      final textNode = _paragraphNode(delta: delta);
      final document = Document.blank();
      document.insert([0], [textNode]);
      document.updateText([0], Delta()..insert('Novident'));
      expect(
        document.nodeAtPath([0])?.delta?.toPlainText(),
        'NovidentEditor',
      );
    });

    test('isEmpty', () {
      expect(
        true,
        Document.fromJson({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'paragraph',
                'data': {'delta': []},
              }
            ],
          },
        }).isEmpty,
      );

      expect(
        true,
        Document.fromJson({
          'document': {
            'type': 'page',
            'children': [],
          },
        }).isEmpty,
      );

      expect(
        true,
        Document.fromJson({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [{'insert': ''}],
                },
              }
            ],
          },
        }).isEmpty,
      );

      expect(
        false,
        Document.fromJson({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [{'insert': 'Welcome to Novident!'}],
                },
              }
            ],
          },
        }).isEmpty,
      );
    });
  });

  test('first', () {
    const firstLine = 'Welcome to Novident!';

    final document = Document.fromJson({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [{'insert': firstLine}],
            },
          }
        ],
      },
    });

    final first = document.first;
    expect(first!.delta!.toPlainText(), firstLine);
  });

  test('last', () {
    const firstLine = 'Welcome to Novident!';
    const firstChild = 'Hello';
    const secondChild = 'World';

    final document = Document.fromJson({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [{'insert': firstLine}],
            },
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [{'insert': firstChild}],
                },
              },
              {
                'type': 'paragraph',
                'data': {
                  'delta': [{'insert': secondChild}],
                },
              }
            ],
          }
        ],
      },
    });

    final last = document.last!;
    expect(last.delta!.toPlainText(), secondChild);
  });

  test('Document.blank().first is null', () {
    final document = Document.blank();
    expect(document.first, isNull);
  });

  test('Document.blank().last is null', () {
    final document = Document.blank();
    expect(document.last, isNull);
  });

  // ==========================================================================
  // Document ↔ DocumentTree dual-sync tests
  // ==========================================================================

  group('Document ↔ DocumentTree sync', () {
    test('nodeAtPath returns correct nodes after insert', () {
      final doc = Document.blank();

      final a = Node(type: 'a', id: 'a');
      final b = Node(type: 'b', id: 'b');
      final c = Node(type: 'c', id: 'c');

      doc.insert([0], [a]);
      doc.insert([1], [b]);
      doc.insert([0], [c]);

      expect(doc.nodeAtPath([0])?.id, 'c');
      expect(doc.nodeAtPath([1])?.id, 'a');
      expect(doc.nodeAtPath([2])?.id, 'b');
      expect(doc.nodeAtPath([3]), isNull);
    });

    test('nodeAtPath returns correct nodes after delete', () {
      final doc = Document.blank();

      for (var i = 0; i < 5; i++) {
        doc.insert([i], [Node(type: '$i', id: '$i')]);
      }

      doc.delete([2], 2);

      expect(doc.nodeAtPath([0])?.id, '0');
      expect(doc.nodeAtPath([1])?.id, '1');
      expect(doc.nodeAtPath([2])?.id, '4');
      expect(doc.nodeAtPath([3]), isNull);
    });

    test('legacy and tree agree on children after insert', () {
      final doc = Document.blank();
      final node = Node(type: 'block', id: 'x');
      doc.insert([0], [node]);

      expect(node.path, [0]);

      final treeKids = doc.tree.childrenOf(doc.root);
      final legacyKids = doc.root.children;
      expect(treeKids.length, legacyKids.length);
      for (var i = 0; i < legacyKids.length; i++) {
        expect(treeKids[i].id, legacyKids[i].id);
      }
    });

    test('legacy and tree agree on children after delete', () {
      final doc = Document.blank();
      for (var i = 0; i < 5; i++) {
        doc.insert([i], [Node(type: '$i', id: '$i')]);
      }

      doc.delete([1], 2);

      final treeKids = doc.tree.childrenOf(doc.root);
      final legacyKids = doc.root.children;
      expect(treeKids.length, legacyKids.length);
      expect(treeKids.length, 3);
      for (var i = 0; i < legacyKids.length; i++) {
        expect(treeKids[i].id, legacyKids[i].id);
      }
    });

    test('byId lookup covers all nodes', () {
      final doc = Document.blank();
      for (var i = 0; i < 10; i++) {
        doc.insert([i], [Node(type: '$i', id: '$i')]);
      }

      for (final node in _collectAll(doc.root)) {
        final found = doc.tree.byId(node.id);
        expect(found, isNotNull, reason: 'byId(${node.id}) is null');
        expect(found!.id, node.id);
      }
    });

    test('syncMove works correctly', () {
      final doc = Document.blank();

      final parent1 = Node(type: 'container', id: 'p1');
      final parent2 = Node(type: 'container', id: 'p2');
      final child = Node(type: 'block', id: 'c');

      doc.insert([0], [parent1]);
      doc.insert([1], [parent2]);
      doc.insert([0, 0], [child]);

      child.unlink();
      parent2.insert(child, index: 0);
      doc.tree.syncRemove(parent1, child);
      doc.tree.syncInsert(parent2, child, 0);

      expect(doc.tree.parentOf(child)?.id, 'p2');
      expect(doc.tree.pathOf(child), [1, 0]);
      expect(doc.tree.childrenOf(parent1).length, 0);
      expect(doc.tree.childrenOf(parent2).length, 1);
      expect(doc.tree.childrenOf(parent2)[0].id, 'c');
    });

    test('nested structure: pathOf matches legacy', () {
      final doc = Document.blank();

      final grandchild = Node(type: 'text', id: 'gc');
      final child = Node(type: 'block', id: 'c');

      doc.insert([0], [child]);
      child.insert(grandchild);
      doc.tree.syncInsert(child, grandchild, 0);

      expect(grandchild.path, [0, 0]);
      expect(doc.tree.pathOf(grandchild), [0, 0]);
      expect(doc.tree.parentOf(grandchild)?.id, 'c');
      expect(doc.tree.parentOf(child)?.id, doc.root.id);
    });

    test('nodeAtPath on nested structure', () {
      final doc = Document.blank();

      final a = Node(type: 'a', id: 'a');
      final b = Node(type: 'b', id: 'b');
      final c = Node(type: 'c', id: 'c');

      doc.insert([0], [a]);
      doc.insert([0, 0], [b]);
      doc.insert([0, 0, 0], [c]);

      expect(doc.nodeAtPath([])?.id, doc.root.id);
      expect(doc.nodeAtPath([0])?.id, 'a');
      expect(doc.nodeAtPath([0, 0])?.id, 'b');
      expect(doc.nodeAtPath([0, 0, 0])?.id, 'c');
      expect(doc.nodeAtPath([0, 0, 0, 0]), isNull);
    });

    test('performance: insert 1000 nodes via Document', () {
      final doc = Document.blank();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        doc.insert([i], [Node(type: 'block', id: 'n$i')]);
      }
      sw.stop();

      debugPrint('DOC INSERT 1000: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: '1000 inserts should complete in <5s');

      doc.tree.checkIntegrity();

      final treeKids = doc.tree.childrenOf(doc.root);
      final legacyKids = doc.root.children;
      expect(treeKids.length, 1000);
      expect(legacyKids.length, 1000);
      for (var i = 0; i < 1000; i++) {
        expect(treeKids[i].id, legacyKids[i].id,
            reason: 'Mismatch at index $i');
      }
    });

    test('performance: delete 500 nodes via Document', () {
      final doc = Document.blank();
      for (var i = 0; i < 1000; i++) {
        doc.insert([i], [Node(type: 'block', id: 'n$i')]);
      }

      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        doc.delete([500], 1);
      }
      sw.stop();

      debugPrint('DOC DELETE 500: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: '500 deletes should complete in <5s');

      doc.tree.checkIntegrity();
      expect(doc.root.children.length, 500);
    });

    test('first and last via Document', () {
      final doc = Document.blank();

      expect(doc.first, isNull);
      expect(doc.last, isNull);

      for (var i = 0; i < 10; i++) {
        doc.insert([i], [Node(type: '$i', id: '$i')]);
      }

      expect(doc.first?.id, '0');
      expect(doc.last?.id, '9');
    });

    test('toJson round-trip preserves structure', () {
      final doc = Document.blank();
      doc.insert([0], [
        Node(
          type: 'paragraph',
          id: 'p1',
          attributes: {
            'delta': (Delta()..insert('Hello')).toJson(),
          },
        ),
      ]);
      doc.insert([1], [
        Node(
          type: 'paragraph',
          id: 'p2',
          attributes: {
            'delta': (Delta()..insert('World')).toJson(),
          },
        ),
      ]);

      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.nodeAtPath([0])?.type, 'paragraph');
      expect(restored.nodeAtPath([1])?.type, 'paragraph');
      expect(restored.nodeAtPath([0])?.delta?.toPlainText(), 'Hello');
      expect(restored.nodeAtPath([1])?.delta?.toPlainText(), 'World');

      restored.tree.checkIntegrity();
    });
  });
}

List<Node> _collectAll(Node root) {
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
