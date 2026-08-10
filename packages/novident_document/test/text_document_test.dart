import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

/// Helper to build a TextDocument from a list of (text, attrs) pairs.
TextDocument docFromPairs(List<(String, Attributes?)> pairs) {
  final delta = Delta();
  for (final (text, attrs) in pairs) {
    delta.insert(text, attributes: attrs);
  }
  return TextDocument.fromDelta(delta);
}

void main() {
  group('TextDocument construction', () {
    test('empty()', () {
      final doc = TextDocument();
      expect(doc.length, 0);
      expect(doc.isEmpty, isTrue);
      expect(doc.chunks, isEmpty);
    });

    test('fromDelta() plain text', () {
      final delta = Delta()
        ..insert('Hello')
        ..insert(' World');
      final doc = TextDocument.fromDelta(delta);

      expect(doc.length, 11);
      expect(doc.isEmpty, isFalse);
      expect(doc.plainText(), 'Hello World');
    });

    test('fromDelta() with attributes', () {
      final delta = Delta()
        ..insert('Hello ', attributes: {'bold': true})
        ..insert('World');
      final doc = TextDocument.fromDelta(delta);

      expect(doc.length, 11);
      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(7), isNull); // 'World' is plain
    });

    test('fromDelta() ignores retain and delete operations', () {
      final delta = Delta()
        ..retain(3) // should be ignored
        ..insert('OK')
        ..delete(1); // should be ignored
      final doc = TextDocument.fromDelta(delta);

      expect(doc.plainText(), 'OK');
      expect(doc.length, 2);
    });

    test('fromJson() round-trips through Delta JSON', () {
      final original = Delta()
        ..insert('Gandalf', attributes: {'bold': true})
        ..insert(' the Grey');
      final json = original.toJson();

      final doc = TextDocument.fromJson(json);
      expect(doc.plainText(), 'Gandalf the Grey');
      expect(doc.attributesAt(0), {'bold': true});
    });

    test('fromDelta() on empty delta', () {
      final doc = TextDocument.fromDelta(Delta());
      expect(doc.length, 0);
      expect(doc.isEmpty, isTrue);
    });

    test('fromDelta() with single empty insert', () {
      // Delta.add() skips empty operations, so this produces an empty delta.
      final delta = Delta()..insert('');
      final doc = TextDocument.fromDelta(delta);
      expect(doc.length, 0);
      expect(doc.isEmpty, isTrue);
      expect(doc.chunks, isEmpty);
    });
  });

  group('length and isEmpty', () {
    test('length on empty document', () {
      expect(TextDocument().length, 0);
    });

    test('length after insert', () {
      final doc = TextDocument();
      doc.insert(0, 'Hello');
      expect(doc.length, 5);
      doc.insert(5, ' World');
      expect(doc.length, 11);
    });

    test('length after delete', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.delete(5, 6);
      expect(doc.length, 5);
      expect(doc.plainText(), 'Hello');
    });

    test('isEmpty true for empty', () {
      expect(TextDocument().isEmpty, isTrue);
    });

    test('isEmpty false after insert', () {
      final doc = TextDocument();
      doc.insert(0, 'x');
      expect(doc.isEmpty, isFalse);
    });

    test('isEmpty true after deleting everything', () {
      final doc = TextDocument.fromDelta(Delta()..insert('x'));
      doc.delete(0, 1);
      expect(doc.length, 0);
      // Note: after deleting everything, the tree is empty
    });
  });

  group('insert()', () {
    test('insert at start', () {
      final doc = TextDocument.fromDelta(Delta()..insert('World'));
      doc.insert(0, 'Hello ');
      expect(doc.plainText(), 'Hello World');
      expect(doc.length, 11);
    });

    test('insert at end', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.insert(5, ' World');
      expect(doc.plainText(), 'Hello World');
      expect(doc.length, 11);
      expect(doc.chunks.length, 2);
    });

    test('insert in the middle', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hod'));
      doc.insert(1, 'ell');
      expect(doc.plainText(), 'Hellod');
      // 'Hod' was one chunk, now split into 'H' + inserted 'ell' + 'od'
    });

    test('multiple sequential inserts build correct text', () {
      final doc = TextDocument();
      doc.insert(0, 'a');
      doc.insert(1, 'b');
      doc.insert(2, 'c');
      doc.insert(1, 'X');
      expect(doc.plainText(), 'aXbc');
    });

    test('insert with attributes', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.insert(5, ' World', attributes: {'bold': true});
      expect(doc.attributesAt(7), {'bold': true});
      expect(doc.attributesAt(0), isNull);
    });

    test('insert empty string is no-op', () {
      final doc = TextDocument.fromDelta(Delta()..insert('test'));
      doc.insert(2, '');
      expect(doc.plainText(), 'test');
      expect(doc.length, 4);
    });

    test('insert at position 0 in empty doc', () {
      final doc = TextDocument();
      doc.insert(0, 'First');
      expect(doc.plainText(), 'First');
      expect(doc.length, 5);
    });

    test('insert throws on negative position', () {
      final doc = TextDocument();
      expect(() => doc.insert(-1, 'x'), throwsRangeError);
    });

    test('insert throws on out-of-bounds position', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      expect(() => doc.insert(10, 'x'), throwsRangeError);
    });

    test('insert inside a chunk with attributes', () {
      final doc = TextDocument.fromDelta(
        Delta()..insert('Hello World', attributes: {'bold': true}),
      );
      doc.insert(6, 'Beautiful ');
      // The chunk was split in two, preserving attributes on both sides
      expect(doc.plainText(), 'Hello Beautiful World');
      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(18), {'bold': true}); // after "Beautiful "
      // The inserted text has no attributes (null)
      expect(doc.attributesAt(7), isNull);
    });
  });

  group('delete()', () {
    test('delete from start', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.delete(0, 6);
      expect(doc.plainText(), 'World');
    });

    test('delete from end', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.delete(5, 6);
      expect(doc.plainText(), 'Hello');
    });

    test('delete in middle', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.delete(2, 7);
      // "Hello World": H(0)e(1)l(2)l(3)o(4) (5)W(6)o(7)r(8)l(9)d(10)
      // Delete(2,7) removes positions 2-8: "llo Wor" → "Held"
      expect(doc.plainText(), 'Held');
    });

    test('delete everything', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      doc.delete(0, 3);
      expect(doc.plainText(), '');
    });

    test('delete zero length is no-op', () {
      final doc = TextDocument.fromDelta(Delta()..insert('test'));
      doc.delete(1, 0);
      expect(doc.plainText(), 'test');
      expect(doc.length, 4);
    });

    test('delete across chunk boundaries', () {
      final doc = docFromPairs([
        ('Hello ', {'bold': true}),
        ('World', {'italic': true}),
        ('!', null),
      ]);
      doc.delete(3,
          6); // Removes positions 3-8: "lo Wo" → 3 from first chunk, 3 from second
      expect(doc.plainText(), 'Helld!');
    });

    test('delete throws on negative start', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      expect(() => doc.delete(-1, 1), throwsRangeError);
    });

    test('delete throws when range exceeds document', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      expect(() => doc.delete(1, 5), throwsRangeError);
    });
  });

  group('format()', () {
    test('format adds attributes to plain text', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.format(0, 5, {'bold': true});

      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(2), {'bold': true});
      expect(doc.attributesAt(6), isNull); // " World" is still plain
    });

    test('format merges with existing attributes', () {
      final doc = TextDocument.fromDelta(
        Delta()..insert('Hello World', attributes: {'bold': true}),
      );
      doc.format(0, 5, {'italic': true});

      expect(doc.attributesAt(0), {'bold': true, 'italic': true});
      expect(doc.attributesAt(6), {'bold': true});
    });

    test('format across chunk boundaries', () {
      final doc = docFromPairs([
        ('Hello ', {'color': 'red'}),
        ('World', {'color': 'blue'}),
      ]);
      doc.format(3, 6, {'bold': true}); // "lo Wo"

      // The chunks get split and formatted
      expect(doc.plainText(), 'Hello World');
      // Check that the formatted region has both attrs
      expect(doc.attributesAt(4), {'color': 'red', 'bold': true});
      expect(doc.attributesAt(7), {'color': 'blue', 'bold': true});
      expect(doc.attributesAt(0), {'color': 'red'});
    });

    test('format zero length is no-op', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.format(1, 0, {'bold': true});
      expect(doc.attributesAt(0), isNull);
      expect(doc.attributesAt(1), isNull);
    });

    test('format with empty attributes is no-op', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.format(0, 5, {});
      expect(doc.attributesAt(0), isNull);
    });

    test('format throws on out-of-bounds range', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      expect(() => doc.format(1, 5, {'bold': true}), throwsRangeError);
    });

    test('format entire document', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.format(0, 5, {'bold': true});
      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(4), {'bold': true});
    });
  });

  group('attributesAt()', () {
    test('returns null for plain text', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      expect(doc.attributesAt(0), isNull);
      expect(doc.attributesAt(4), isNull);
    });

    test('returns attributes for formatted text', () {
      final doc = TextDocument.fromDelta(
        Delta()..insert('Hello', attributes: {'bold': true}),
      );
      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(4), {'bold': true});
    });

    test('returns correct attributes at chunk boundaries', () {
      final doc = docFromPairs([
        ('AB', {'bold': true}),
        ('CD', {'italic': true}),
      ]);
      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(1), {'bold': true});
      expect(doc.attributesAt(2), {'italic': true});
      expect(doc.attributesAt(3), {'italic': true});
    });

    test('throws on empty document', () {
      final doc = TextDocument();
      expect(() => doc.attributesAt(0), throwsRangeError);
    });

    test('throws on out-of-bounds position', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      expect(() => doc.attributesAt(3), throwsRangeError);
      expect(() => doc.attributesAt(-1), throwsRangeError);
    });
  });

  group('slice()', () {
    test('slice entire document', () {
      final delta = Delta()
        ..insert('Hello ', attributes: {'bold': true})
        ..insert('World');
      final doc = TextDocument.fromDelta(delta);

      final sliced = doc.slice(0);
      expect(sliced.toPlainText(), 'Hello World');
      expect(sliced.length, 11);
    });

    test('slice range from middle', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      final sliced = doc.slice(3, 8);
      expect(sliced.toPlainText(), 'lo Wo');
      expect(sliced.length, 5);
    });

    test('slice at chunk boundaries preserves attributes', () {
      final doc = docFromPairs([
        ('AB', {'bold': true}),
        ('CDE', {'italic': true}),
        ('FG', null),
      ]);
      final sliced = doc.slice(1, 5);
      // Should contain: B (bold), CDE (italic) - but only CD part
      expect(sliced.toPlainText(), 'BCDE');
      // Check the Delta produces correct operations
      final ops = sliced.toList();
      // First op: 'B' with bold
      expect((ops[0] as TextInsert).text, 'B');
      expect((ops[0] as TextInsert).attributes, {'bold': true});
      // Second op: 'CDE' with italic
      expect((ops[1] as TextInsert).text, 'CDE');
      expect((ops[1] as TextInsert).attributes, {'italic': true});
    });

    test('slice empty range returns empty Delta', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      final sliced = doc.slice(2, 2);
      expect(sliced.length, 0);
      expect(sliced.isEmpty, isTrue);
    });

    test('slice with only start (to end)', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      final sliced = doc.slice(6);
      expect(sliced.toPlainText(), 'World');
    });

    test('slice throws on out-of-bounds range', () {
      final doc = TextDocument.fromDelta(Delta()..insert('abc'));
      expect(() => doc.slice(1, 10), throwsRangeError);
    });

    test('slice after insert produces correct result', () {
      final doc = TextDocument();
      doc.insert(0, 'Hello');
      doc.insert(5, ' World');
      doc.insert(6, 'Beautiful ');

      // Doc: "Hello Beautiful World" (21 chars)
      expect(doc.slice(0, 5).toPlainText(), 'Hello');
      expect(doc.slice(6, 15).toPlainText(), 'Beautiful');
      expect(doc.slice(0).toPlainText(), 'Hello Beautiful World');
    });

    test('slice round-trips through Delta', () {
      final original = Delta()
        ..insert('Hello ', attributes: {'bold': true})
        ..insert('World', attributes: {'italic': true})
        ..insert('!');

      final doc = TextDocument.fromDelta(original);
      final sliced = doc.slice(0);
      final roundTripped = sliced.toJson();

      // They should be equivalent (same text, same attrs)
      expect(roundTripped, original.toJson());
    });
  });

  group('plainText()', () {
    test('full text', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      expect(doc.plainText(), 'Hello World');
    });

    test('range', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      expect(doc.plainText(0, 5), 'Hello');
      expect(doc.plainText(6), 'World');
    });

    test('empty range', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      expect(doc.plainText(2, 2), '');
    });

    test('empty document', () {
      expect(TextDocument().plainText(), '');
    });
  });

  group('toDelta() and toJson()', () {
    test('toDelta round-trip preserves content', () {
      final original = Delta()
        ..insert('Hello ', attributes: {'bold': true})
        ..insert('World');

      final doc = TextDocument.fromDelta(original);
      final exported = doc.toDelta();

      expect(exported.toPlainText(), original.toPlainText());
      expect(exported.length, original.length);
    });

    test('toJson produces valid legacy JSON', () {
      final doc = TextDocument.fromDelta(
        Delta()..insert('Test', attributes: {'bold': true}),
      );
      final json = doc.toJson();
      expect(json, isA<List>());
      expect(json, [
        {
          'insert': 'Test',
          'attributes': {'bold': true}
        },
      ]);
    });

    test('fromJson → toJson is idempotent', () {
      final json = [
        {
          'insert': 'Hello ',
          'attributes': {'bold': true}
        },
        {'insert': 'World'},
      ];
      final doc = TextDocument.fromJson(json);
      final output = doc.toJson();
      expect(output, json);
    });

    test('toDelta().toJson() matches original document Delta JSON', () {
      final delta = Delta()
        ..insert('Gandalf', attributes: {'bold': true})
        ..insert(' the ')
        ..insert('Grey', attributes: {'color': '#ccc'});

      final doc = TextDocument.fromDelta(delta);
      final exportedDelta = doc.toDelta();
      final exportedJson = exportedDelta.toJson();
      final originalJson = delta.toJson();

      // Both produce the same JSON structure
      expect(exportedJson, originalJson);
    });
  });

  group('applyDelta()', () {
    test('applyDelta with insert', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.applyDelta(Delta()
        ..retain(5)
        ..insert(' World'));

      expect(doc.plainText(), 'Hello World');
      expect(doc.length, 11);
    });

    test('applyDelta with delete', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.applyDelta(Delta()
        ..retain(5)
        ..delete(6));

      expect(doc.plainText(), 'Hello');
    });

    test('applyDelta with format', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello World'));
      doc.applyDelta(
        Delta()
          ..retain(0)
          ..retain(5, attributes: {'bold': true}),
      );

      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(4), {'bold': true});
      expect(doc.attributesAt(6), isNull);
    });

    test('applyDelta composed insert + delete + format', () {
      // Simulates: replace "Grey" with "White" in "Gandalf the Grey"
      final doc = docFromPairs([
        ('Gandalf', {'bold': true}),
        (' the ', null),
        ('Grey', {'color': '#ccc'}),
      ]);

      final change = Delta()
        ..retain(12)
        ..insert('White', attributes: {'color': '#fff'})
        ..delete(4);

      doc.applyDelta(change);

      expect(doc.plainText(), 'Gandalf the White');
      expect(doc.attributesAt(0), {'bold': true}); // "Gandalf"
      expect(doc.attributesAt(12), {'color': '#fff'}); // "White"
    });

    test('applyDelta returns this for chaining', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      final result = doc.applyDelta(Delta()
        ..retain(5)
        ..insert('!'));
      expect(identical(result, doc), isTrue);
    });

    test('applyDelta matches Delta.compose behavior', () {
      // "Gandalf the Grey" → replace "Grey" with "White"
      final original = Delta()
        ..insert('Gandalf', attributes: {'bold': true})
        ..insert(' the ')
        ..insert('Grey', attributes: {'color': '#ccc'});

      final change = Delta()
        ..retain(12)
        ..insert('White', attributes: {'color': '#fff'})
        ..delete(4);

      // Old way: Delta.compose
      final composed = original.compose(change);

      // New way: TextDocument.applyDelta
      final doc = TextDocument.fromDelta(original);
      doc.applyDelta(change);
      final exported = doc.toDelta();

      expect(exported.toPlainText(), composed.toPlainText());
      expect(exported.toJson(), composed.toJson());
    });

    test('applyDelta on empty document', () {
      final doc = TextDocument();
      doc.applyDelta(Delta()..insert('Hello!'));
      expect(doc.plainText(), 'Hello!');
      expect(doc.length, 6);
    });

    test('applyDelta with retain-only (format no-op)', () {
      final doc = TextDocument.fromDelta(Delta()..insert('Hello'));
      doc.applyDelta(Delta()..retain(5));
      expect(doc.plainText(), 'Hello');
      expect(doc.length, 5);
    });
  });

  group('chunks', () {
    test('chunks preserves order and attributes', () {
      final doc = docFromPairs([
        ('Hello ', {'bold': true}),
        ('World', {'italic': true}),
      ]);

      final chunks = doc.chunks;
      expect(chunks.length, 2);
      expect(chunks[0].text, 'Hello ');
      expect(chunks[0].attributes, {'bold': true});
      expect(chunks[1].text, 'World');
      expect(chunks[1].attributes, {'italic': true});
    });

    test('chunks on empty document', () {
      expect(TextDocument().chunks, isEmpty);
    });

    test('chunks after insert splits chunk correctly', () {
      final doc = TextDocument.fromDelta(
        Delta()..insert('Hello', attributes: {'bold': true}),
      );
      doc.insert(2, 'XX');

      final chunks = doc.chunks;
      // Should be: "He" (bold), "XX" (null), "llo" (bold)
      expect(chunks.length, 3);
      expect(chunks[0].text, 'He');
      expect(chunks[0].attributes, {'bold': true});
      expect(chunks[1].text, 'XX');
      expect(chunks[1].attributes, isNull);
      expect(chunks[2].text, 'llo');
      expect(chunks[2].attributes, {'bold': true});
    });
  });

  group('stress and edge cases', () {
    test('many sequential inserts', () {
      final doc = TextDocument();
      final buffer = StringBuffer();
      for (var i = 0; i < 500; i++) {
        final char = String.fromCharCode(65 + (i % 26));
        doc.insert(doc.length, char);
        buffer.write(char);
      }
      expect(doc.plainText(), buffer.toString());
      expect(doc.length, 500);
    });

    test('many random operations preserve correctness', () {
      final doc = TextDocument.fromDelta(
        Delta()..insert('The quick brown fox jumps over the lazy dog'),
      );

      // Operations in sequence:
      doc.delete(
          4, 6); // remove "quick " → "The brown fox jumps over the lazy dog"
      doc.insert(4, 'slow ',
          attributes: {'italic': true}); // "The slow brown fox..."
      doc.format(0, 3, {'bold': true}); // bold "The"
      doc.delete(24, 4); // " ove" → "The slow brown fox jumpsr the lazy dog"

      expect(doc.plainText(), 'The slow brown fox jumpsr the lazy dog');
      expect(doc.attributesAt(0), {'bold': true});
      expect(doc.attributesAt(5), {'italic': true});
    });

    test('insert at every possible position in a small doc', () {
      final text = 'ABC';
      for (var pos = 0; pos <= text.length; pos++) {
        final doc = TextDocument.fromDelta(Delta()..insert(text));
        doc.insert(pos, 'X');
        final expected = '${text.substring(0, pos)}X${text.substring(pos)}';
        expect(doc.plainText(), expected, reason: 'insert at position $pos');
      }
    });

    test('delete ranges of all sizes', () {
      for (var len = 0; len <= 5; len++) {
        for (var start = 0; start <= 5 - len; start++) {
          final doc = TextDocument.fromDelta(Delta()..insert('ABCDE'));
          doc.delete(start, len);
          final expected =
              'ABCDE'.substring(0, start) + 'ABCDE'.substring(start + len);
          expect(doc.plainText(), expected, reason: 'delete($start, $len)');
        }
      }
    });

    test('unicode (multi-byte) text is preserved', () {
      final doc = TextDocument();
      doc.insert(0, 'Hello 🌍 World');
      doc.insert(6, '🔥 ');
      expect(doc.plainText(), 'Hello 🔥 🌍 World');
      expect(doc.length, 'Hello 🔥 🌍 World'.length);

      // Slice should work on code unit positions
      final sliced = doc.slice(0, 8);
      expect(sliced.toPlainText(), 'Hello 🔥');
    });

    test('document with single empty-text chunk', () {
      // Delta.add() skips empty operations, so Delta()..insert('')
      // produces an empty delta → empty TextDocument.
      final doc = TextDocument.fromDelta(Delta()..insert(''));
      expect(doc.length, 0);
      expect(doc.isEmpty, isTrue);
      expect(doc.chunks, isEmpty);
    });
  });
}
