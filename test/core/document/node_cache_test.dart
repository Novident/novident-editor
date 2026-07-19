import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Regression tests for the Node-level caches (children list, index-in-
/// parent used by [Node.path], and the parsed [Node.delta]):
///
/// every structural mutation — inserting in the middle, deleting, MOVING a
/// block (delete + insert, exactly what transactions do), nested edits —
/// must invalidate the affected caches, while non-structural updates must
/// keep them (that's the whole point of caching).
void main() {
  Document buildDocument(int count) {
    return Document(
      root: pageNode(
        children: <Node>[
          for (var i = 0; i < count; i++) paragraphNode(text: 'p$i'),
        ],
      ),
    );
  }

  /// Warms every cache the way the editor does: paths, lookups, deltas.
  void warmCaches(Document document) {
    for (final node in document.root.children) {
      node.path;
      node.delta;
    }
  }

  /// The invariant the editor relies on everywhere: for every child i,
  /// `path == [.., i]` and `childAtPath(path)` resolves to that same node.
  void expectConsistentTree(Document document) {
    void verify(Node node) {
      final children = node.children;
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        expect(child.path.last, i);
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

  group('Node caches under structural mutations', () {
    test('inserting in the middle shifts the paths of later siblings', () {
      final document = buildDocument(5);
      warmCaches(document);

      document.insert([2], [paragraphNode(text: 'X')]);

      expect(document.root.children.length, 6);
      expect(document.nodeAtPath([2])!.delta!.toPlainText(), 'X');
      expect(document.nodeAtPath([3])!.delta!.toPlainText(), 'p2');
      expectConsistentTree(document);
    });

    test('deleting in the middle shifts the paths of later siblings', () {
      final document = buildDocument(5);
      warmCaches(document);

      document.delete([1]);

      expect(document.root.children.length, 4);
      expect(document.nodeAtPath([1])!.delta!.toPlainText(), 'p2');
      expect(document.nodeAtPath([3])!.delta!.toPlainText(), 'p4');
      expectConsistentTree(document);
    });

    test('moving a block (delete + insert) keeps every lookup consistent',
        () {
      // exactly what a transaction-based move (drag to reorder, cut +
      // paste of a block) does through editor_state.apply.
      final document = buildDocument(5);
      warmCaches(document);

      final moved = document.nodeAtPath([1])!;
      document.delete([1]);
      document.insert([3], [moved]);

      expect(
        document.root.children.map((n) => n.delta!.toPlainText()).toList(),
        ['p0', 'p2', 'p3', 'p1', 'p4'],
      );
      expect(moved.path, [3]);
      expect(identical(document.nodeAtPath([3]), moved), true);
      expectConsistentTree(document);
    });

    test('mass paste in the middle (multi-node insert) stays consistent',
        () {
      final document = buildDocument(3);
      warmCaches(document);

      document.insert(
        [1],
        [for (var i = 0; i < 50; i++) paragraphNode(text: 'pasted $i')],
      );

      expect(document.root.children.length, 53);
      expect(document.nodeAtPath([1])!.delta!.toPlainText(), 'pasted 0');
      expect(document.nodeAtPath([50])!.delta!.toPlainText(), 'pasted 49');
      expect(document.nodeAtPath([51])!.delta!.toPlainText(), 'p1');
      expectConsistentTree(document);
    });

    test('nested children paths stay correct after top-level mutations', () {
      final document = Document(
        root: pageNode(
          children: <Node>[
            paragraphNode(text: 'a'),
            paragraphNode(
              text: 'parent',
              children: <Node>[paragraphNode(text: 'nested')],
            ),
          ],
        ),
      );
      warmCaches(document);
      expect(document.nodeAtPath([1, 0])!.delta!.toPlainText(), 'nested');

      // shift the parent by inserting a sibling before it.
      document.insert([0], [paragraphNode(text: 'first')]);

      expect(document.nodeAtPath([2, 0])!.delta!.toPlainText(), 'nested');
      expect(document.nodeAtPath([2, 0])!.path, [2, 0]);
      expectConsistentTree(document);
    });
  });

  group('Node.delta cache', () {
    test('repeated reads return the same cached instance', () {
      final document = buildDocument(1);
      final node = document.nodeAtPath([0])!;

      final first = node.delta;
      expect(first, isNotNull);
      expect(identical(node.delta, first), true);
    });

    test('updateText refreshes the cache (new identity, new content)', () {
      final document = buildDocument(1);
      final node = document.nodeAtPath([0])!;
      final before = node.delta!;

      document.updateText(
        [0],
        Delta()
          ..retain(2)
          ..insert('XX'),
      );

      final after = node.delta!;
      expect(identical(after, before), false);
      expect(after.toPlainText(), 'p0XX');
      // and the new value is cached again.
      expect(identical(node.delta, after), true);
    });

    test('attribute updates that do not touch the delta keep the cache', () {
      final document = buildDocument(1);
      final node = document.nodeAtPath([0])!;
      final before = node.delta!;

      document.update([0], {'customKey': 42});

      expect(node.attributes['customKey'], 42);
      // the raw delta list identity is preserved by composeAttributes, so
      // the parsed delta stays cached.
      expect(identical(node.delta, before), true);
      expect(node.delta!.toPlainText(), 'p0');
    });
  });
}
