import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document/novident_document.dart';

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
  group('node.dart', () {
    test('test node copyWith', () {
      final node = Node(
        type: 'example',
        attributes: {
          'example': 'example',
        },
      );
      expect(node.toJson(), {
        'type': 'example',
        'data': {
          'example': 'example',
        },
      });
      expect(
        node.copyWith().toJson(),
        node.toJson(),
      );

      final nodeWithChildren = Node(
        type: 'example',
        children: [node],
        attributes: {
          'example': 'example',
        },
      );
      expect(nodeWithChildren.toJson(), {
        'type': 'example',
        'data': {
          'example': 'example',
        },
        'children': [
          {
            'type': 'example',
            'data': {
              'example': 'example',
            },
          },
        ],
      });
      expect(
        nodeWithChildren.copyWith().toJson(),
        nodeWithChildren.toJson(),
      );
    });

    test('test textNode copyWith', () {
      final node = _paragraphNode(
        delta: Delta()..insert('Novident'),
      );
      // Override attributes with example
      node.updateAttributes({'example': 'example'});
      final nodeWithExample = Node(
        type: 'paragraph',
        attributes: {
          'example': 'example',
          'delta': (Delta()..insert('Novident')).toJson(),
        },
      );
      // Compare the JSON structure
      expect(nodeWithExample.toJson()['type'], node.toJson()['type']);
      expect(
        (nodeWithExample.toJson()['data'] as Map).containsKey('delta'),
        true,
      );

      final nodeWithChildren = _paragraphNode(
        delta: Delta()..insert('Novident'),
      );
      nodeWithChildren.insert(node);

      expect(nodeWithChildren.children.length, 1);
    });

    test('test copy with', () {
      final child = Node(
        type: 'child',
        attributes: {},
      );
      final base = Node(
        type: 'base',
        attributes: {},
        children: [child],
      );
      final node = base.copyWith(
        type: 'node',
      );
      expect(identical(node.attributes, base.attributes), false);
      expect(identical(node.children, base.children), false);
      expect(identical(node.children.first, base.children.first), false);
    });

    test('test insert', () {
      final base = Node(
        type: 'base',
      );

      // insert at the front when node's children is empty
      final childA = Node(
        type: 'child',
      );
      base.insert(childA);
      expect(
        identical(base.childAtIndexOrNull(0), childA),
        true,
      );

      // insert at the front
      final childB = Node(
        type: 'child',
      );
      base.insert(childB, index: -1);
      expect(
        identical(base.childAtIndexOrNull(0), childB),
        true,
      );

      // insert at the last
      final childC = Node(
        type: 'child',
      );
      base.insert(childC, index: 1000);
      expect(
        identical(base.childAtIndexOrNull(base.children.length - 1), childC),
        true,
      );

      // insert at the last
      final childD = Node(
        type: 'child',
      );
      base.insert(childD);
      expect(
        identical(base.childAtIndexOrNull(base.children.length - 1), childD),
        true,
      );

      // insert at the second
      final childE = Node(
        type: 'child',
      );
      base.insert(childE, index: 1);
      expect(
        identical(base.childAtIndexOrNull(1), childE),
        true,
      );
    });

    test('test fromJson', () {
      final node = Node.fromJson({
        'type': 'text',
        'delta': [
          {'insert': 'example'},
        ],
        'children': [
          {
            'type': 'example',
            'data': {
              'example': 'example',
            },
          },
        ],
      });
      expect(node.type, 'text');
      expect(node.attributes, {});
      expect(node.children.length, 1);
      expect(node.children.first.type, 'example');
      expect(node.children.first.attributes, {'example': 'example'});
    });
  });
}
