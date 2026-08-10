import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

/// Helper: creates a text node via the constructor with legacy delta attribute.
Node _textNode(String text, {Attributes? extra}) {
  final attrs = <String, dynamic>{
    'td': TextDocument()..pushText(text),
  };
  if (extra != null) attrs.addAll(extra);
  return Node(type: 'paragraph', attributes: attrs);
}

void main() {
  group('Node.textDocument — construction', () {
    test('lazy parse from legacy delta attribute', () {
      final node = _textNode('Hello');

      // textDocument is null until first access
      expect(node.textDocument, isNotNull);
      expect(node.textDocument!.length, 5);
      expect(node.textDocument!.plainText(), 'Hello');
    });

    test('lazy parse from native td attribute', () {
      final native = TextDocument()..pushText('Native');
      final node = Node(
        type: 'paragraph',
        attributes: {'td': native.toNativeJson()},
      );

      expect(node.textDocument, isNotNull);
      expect(node.textDocument!.plainText(), 'Native');
    });

    test('returns null for non-text nodes', () {
      final node = Node(type: 'container', attributes: {});
      expect(node.textDocument, isNull);
    });

    test('fromJson parses legacy delta', () {
      final node = Node.fromJson({
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': 'Legacy'},
          ],
        },
      });

      expect(node.textDocument, isNotNull);
      expect(node.textDocument!.plainText(), 'Legacy');
    });

    test('fromJson prefers native td over legacy delta', () {
      final native = TextDocument();
      native.insert(0, 'Native');
      final node = Node.fromJson({
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': 'Legacy'},
          ],
          'td': native.toNativeJson(),
        },
      });

      // Should use native td, not legacy delta
      expect(node.textDocument!.plainText(), 'Native');
    });

    test('fromJson handles empty td', () {
      final node = Node.fromJson({
        'type': 'paragraph',
        'data': {
          'td': {'v': 1, 'c': []},
        },
      });

      expect(node.textDocument, isNotNull);
      expect(node.textDocument!.isEmpty, isTrue);
    });
  });

  group('Node.delta — backward compat bridge', () {
    test('returns Delta from TextDocument', () {
      final node = _textNode('Bridge');
      final d = node.delta;
      expect(d, isNotNull);
      expect(d!.toPlainText(), 'Bridge');
    });

    test('returns Delta even for empty text', () {
      final node = _textNode('');
      final d = node.delta;
      expect(d, isNotNull);
      expect(d!.isEmpty, isTrue);
    });

    test('returns null for nodes without text', () {
      final node = Node(type: 'image', attributes: {'src': 'pic.png'});
      expect(node.delta, isNull);
    });

    test('cached across repeated reads', () {
      Node.debugDeltaParseCount = 0;
      final node = _textNode('Cache');
      final countBefore = Node.debugDeltaParseCount;

      // First access — should parse
      final d1 = node.delta;
      final countAfterFirst = Node.debugDeltaParseCount;
      expect(countAfterFirst, greaterThan(countBefore));

      // Second access — should be cache hit
      final d2 = node.delta;
      expect(Node.debugDeltaParseCount, countAfterFirst);
      expect(identical(d1, d2), isTrue);
    });

    test('changes after updateAttributes with new delta', () {
      final node = _textNode('Before');
      expect(node.delta!.toPlainText(), 'Before');

      node.updateAttributes({
        'delta': (Delta()..insert('After')).toJson(),
      });

      expect(node.delta!.toPlainText(), 'After');
    });
  });

  group('Node.applyTextDelta', () {
    test('inserts text on empty node', () {
      final node = Node(type: 'paragraph');
      node.applyTextDelta(Delta()..insert('Hello'));

      expect(node.textDocument!.plainText(), 'Hello');
      expect(node.delta!.toPlainText(), 'Hello');
    });

    test('inserts at position', () {
      final node = _textNode('Hello');
      node.applyTextDelta(Delta()
        ..retain(5)
        ..insert(' World'));

      expect(node.textDocument!.plainText(), 'Hello World');
    });

    test('deletes range', () {
      final node = _textNode('Hello World');
      node.applyTextDelta(Delta()
        ..retain(5)
        ..delete(6));

      expect(node.textDocument!.plainText(), 'Hello');
    });

    test('formats range', () {
      final node = _textNode('Hello');
      node.applyTextDelta(
        Delta()..retain(5, attributes: {'bold': true}),
      );

      expect(node.textDocument!.attributesAt(0), {'bold': true});
    });

    test('formats range with the new TextDocument', () {
      final node = _textNode('Hello');
      node.textDocument!.format(
        0,
        5,
        {'bold': true},
      );

      expect(node.textDocument!.attributesAt(0), {'bold': true});
    });

    test('multiple operations in sequence', () {
      final node = _textNode('abc');

      node.applyTextDelta(Delta()
        ..retain(3)
        ..insert('def'));
      expect(node.textDocument!.plainText(), 'abcdef');

      node.applyTextDelta(Delta()
        ..retain(0)
        ..delete(3));
      expect(node.textDocument!.plainText(), 'def');
    });

    test('syncs to attributes as native td', () {
      final node = _textNode('old');
      node.applyTextDelta(Delta()
        ..retain(3)
        ..insert('+new'));

      // Attributes should have td, not delta
      expect(node.attributes.containsKey('td'), isTrue);
      expect(node.attributes.containsKey('delta'), isFalse);
    });

    test('notifies listeners', () {
      final node = _textNode('before');
      var notified = false;
      node.addListener(() => notified = true);

      node.applyTextDelta(Delta()
        ..retain(6)
        ..insert('!'));

      expect(notified, isTrue);
    });
  });

  group('Node.toJson / fromJson — round-trip', () {
    test('writes native td format', () {
      final node = _textNode('Serialize');
      final json = node.toJson(humanReadable: false);

      expect(json['data'], isA<Map>());
      final data = json['data'] as Map;
      expect(data.containsKey('td'), isTrue);
      expect(data.containsKey('delta'), isFalse);
    });

    test('writes delta format', () {
      final node = _textNode('Serialize');
      final json = node.toJson(humanReadable: true);

      expect(json['data'], isA<Map>());
      final data = json['data'] as Map;
      expect(data.containsKey('td'), isFalse);
      expect(data.containsKey('delta'), isTrue);
    });

    test('round-trip preserves text', () {
      final original = _textNode('Round-trip');
      final json = original.toJson();
      final restored = Node.fromJson(json);

      expect(restored.textDocument!.plainText(),
          original.textDocument!.plainText());
      expect(restored.delta!.toJson(), original.delta!.toJson());
    });

    test('round-trip with formatting', () {
      final node = _textNode('');
      node.applyTextDelta(Delta()..insert('Bold', attributes: {'bold': true}));
      node.applyTextDelta(
        Delta()
          ..retain(4)
          ..insert('Italic', attributes: {'italic': true}),
      );

      final json = node.toJson();
      final restored = Node.fromJson(json);

      expect(restored.textDocument!.plainText(), 'BoldItalic');
      expect(restored.textDocument!.attributesAt(0), {'bold': true});
      expect(restored.textDocument!.attributesAt(4), {'italic': true});
    });

    test('round-trip preserves attributes alongside text', () {
      final node = _textNode('Text', extra: {'align': 'center'});
      final json = node.toJson();
      final restored = Node.fromJson(json);

      expect(restored.textDocument!.plainText(), 'Text');
      expect(restored.attributes['align'], 'center');
    });

    test('toJson without text omits both td and delta', () {
      final node = Node(type: 'container', attributes: {'color': 'red'});
      final json = node.toJson();

      final data = json['data'] as Map;
      expect(data.containsKey('td'), isFalse);
      expect(data.containsKey('delta'), isFalse);
      expect(data['color'], 'red');
    });

    test('toJson with empty text still writes td', () {
      final node = _textNode('');
      final json = node.toJson(humanReadable: false);

      final data = json['data'] as Map;
      // Empty text is still a valid TextDocument — it should be serialized
      expect(data.containsKey('td'), isTrue);
      expect(data.containsKey('delta'), isFalse);
    });
  });

  group('Node.updateAttributes — TextDocument sync', () {
    test('delta key triggers TextDocument re-parse', () {
      final node = _textNode('First');
      expect(node.textDocument!.plainText(), 'First');

      node.updateAttributes({
        'delta': (Delta()..insert('Second')).toJson(),
      });

      expect(node.textDocument!.plainText(), 'Second');
    });

    test('td key triggers TextDocument re-parse', () {
      final native = TextDocument()..pushText('Native');
      final node = _textNode('Old');

      node.updateAttributes({'td': native});

      expect(node.textDocument!.plainText(), 'Native');
    });

    test('non-text keys do not invalidate TextDocument', () {
      final node = _textNode('Keep');
      final docBefore = node.textDocument;

      node.updateAttributes({'align': 'center'});

      expect(identical(node.textDocument, docBefore), isTrue);
      expect(node.textDocument!.plainText(), 'Keep',
          reason: 'not found textDocument: ${node.toJson()}');
      expect(node.attributes['align'], 'center');
    });

    test('increments debugDeltaParseCount on delta change', () {
      Node.debugDeltaParseCount = 0;
      final node = _textNode('First');
      node.delta; // trigger first parse
      final afterFirst = Node.debugDeltaParseCount;

      node.updateAttributes({
        'delta': (Delta()..insert('Second')).toJson(),
      });
      node.delta; // trigger re-parse

      expect(Node.debugDeltaParseCount, greaterThan(afterFirst));
    });
  });

  group('Node TextDocument — edge cases', () {
    test('copyWith preserves text', () {
      final original = _textNode('Copy me');
      final copy = original.copyWith();

      // Text is preserved via lazy parse from the copied delta attribute.
      expect(copy.textDocument, isNotNull);
      expect(copy.textDocument!.plainText(), 'Copy me');
    });

    test('copyWith with new attributes still has text', () {
      final original = _textNode('Original');
      // Serialize first so td key is populated in attributes.
      final json = original.toJson(humanReadable: false);
      final td = (json['data'] as Map<String, dynamic>)['td'];

      final copy = original.copyWith(
        attributes: {
          'align': 'right',
          'td': td,
        },
      );

      expect(copy.textDocument!.plainText(), 'Original');
      expect(copy.attributes['align'], 'right');
    });

    test('node without text then applyTextDelta', () {
      final node = Node(type: 'paragraph');
      expect(node.textDocument, isNull);
      expect(node.delta, isNull);

      node.applyTextDelta(Delta()..insert('Now I exist'));

      expect(node.textDocument!.plainText(), 'Now I exist');
      expect(node.delta!.toPlainText(), 'Now I exist');
    });

    test('unicode text round-trip', () {
      final node = _textNode('Hello 👋 世界 🌍');
      final json = node.toJson();
      final restored = Node.fromJson(json);

      expect(restored.textDocument!.plainText(), 'Hello 👋 世界 🌍');
    });

    test('large text round-trip', () {
      final bigText = List.generate(1000, (i) => 'word$i ').join();
      final node = _textNode(bigText);
      final json = node.toJson();
      final restored = Node.fromJson(json);

      expect(restored.textDocument!.plainText(), bigText);
    });

    test('updateAttributes with delta creates TextDocument eager', () {
      final node = Node(type: 'paragraph');
      expect(node.textDocument, isNull);

      node.updateAttributes({
        'delta': (Delta()..insert('eager')).toJson(),
      });

      // TextDocument should be available immediately after updateAttributes
      expect(node.textDocument, isNotNull);
      expect(node.textDocument!.plainText(), 'eager');
    });
  });
}
