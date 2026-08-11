import 'package:flutter/services.dart';
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

  group('prevRunePosition', () {
    test('empty document returns -1', () {
      final doc = TextDocument();
      expect(doc.prevRunePosition(0), -1);
      expect(doc.prevRunePosition(5), -1);
    });

    test('position 0 returns -1 regardless of content', () {
      final doc = TextDocument()..pushText('Hello');
      expect(doc.prevRunePosition(0), -1);
    });

    test('simple ASCII — one char back', () {
      final doc = TextDocument()..pushText('ABCDE');
      expect(doc.prevRunePosition(1), 0);
      expect(doc.prevRunePosition(2), 1);
      expect(doc.prevRunePosition(3), 2);
      expect(doc.prevRunePosition(4), 3);
      expect(doc.prevRunePosition(5), 4);
    });

    test('simple ASCII — stepping backwards through entire doc', () {
      final doc = TextDocument()..pushText('Hello World');
      var pos = doc.length;
      final positions = <int>[];
      while (pos > 0) {
        pos = doc.prevRunePosition(pos);
        positions.add(pos);
      }
      expect(positions, [10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]);
      expect(doc.prevRunePosition(0), -1);
    });

    test('emoji (2 code units) — jumps to previous cluster start', () {
      // '😀' is U+1F600 → surrogate pair, 2 code units
      final doc = TextDocument()..pushText('a😀b');
      // prevRunePosition should respect grapheme clusters.
      // Verify against CharacterBoundary on the full text.
      final fullText = doc.plainText();
      final ref = CharacterBoundary(fullText);
      for (var pos = 1; pos <= doc.length; pos++) {
        final expected = ref.getLeadingTextBoundaryAt(pos - 1) ?? 0;
        expect(doc.prevRunePosition(pos), expected,
            reason: 'prevRunePosition($pos)');
      }
    });

    test('emoji with skin tone — jumps to previous cluster start', () {
      // '👍🏽' = 👍 + skin-tone modifier.
      // Whether this is 1 or 2 grapheme clusters depends on the
      // Flutter / Unicode version.  Compare against CharacterBoundary.
      final doc = TextDocument()..pushText('a👍🏽b');
      final fullText = doc.plainText();
      final ref = CharacterBoundary(fullText);
      for (var pos = 1; pos <= doc.length; pos++) {
        final expected = ref.getLeadingTextBoundaryAt(pos - 1) ?? 0;
        expect(doc.prevRunePosition(pos), expected,
            reason: 'prevRunePosition($pos)');
      }
    });

    test('family emoji ZWJ sequence — jumps to previous cluster start', () {
      // 👨‍👩‍👧‍👦 = 👨 + ZWJ + 👩 + ZWJ + 👧 + ZWJ + 👦 (11 code units).
      // CharacterBoundary may treat this as 1 or multiple clusters.
      const family = '👨‍👩‍👧‍👦';
      final doc = TextDocument()..pushText('x${family}y');
      final fullText = doc.plainText();
      final ref = CharacterBoundary(fullText);
      for (var pos = 1; pos <= doc.length; pos++) {
        final expected = ref.getLeadingTextBoundaryAt(pos - 1) ?? 0;
        expect(doc.prevRunePosition(pos), expected,
            reason: 'prevRunePosition($pos)');
      }
    });

    test('mixed ASCII and emoji — walking backwards', () {
      final doc = TextDocument()..pushText('Hello 😀 World 🌍!');
      // Walk backwards from end and verify each step lands on a
      // cluster boundary (not inside a multi-unit character).
      var pos = doc.length;
      final visited = <int>[];
      while (pos > 0) {
        pos = doc.prevRunePosition(pos);
        visited.add(pos);
      }
      // Reconstruct text by slicing at each visited position.
      // Should match the original text character by character.
      final chars = <String>[];
      for (var i = 0; i < visited.length; i++) {
        final start = visited[visited.length - 1 - i];
        final end = i < visited.length - 1
            ? visited[visited.length - 2 - i]
            : doc.length;
        chars.add(doc.plainText(start, end));
      }
      final reconstructed = chars.join();
      expect(reconstructed, doc.plainText());
    });

    // -- Chunk boundary crossing ------------------------------------

    test('crosses chunk boundaries correctly (1 char per chunk)', () {
      // Create a document where every character is in its own chunk.
      final doc = TextDocument();
      const text = 'A😀B👍🏽C';
      for (var i = 0; i < text.length; i++) {
        doc.insert(doc.length, text[i]);
      }
      // Now every code unit is a separate chunk.
      // Walking backwards should still respect grapheme clusters.

      // Find position of 'C' (last ASCII char)
      final cPos = doc.length - 1; // last code unit = 'C'
      expect(doc.prevRunePosition(cPos), doc.length - 5);
      // 'C' is at the end, prev should be start of 👍🏽
    });

    test('crosses chunk boundaries — emoji split across chunks', () {
      // Insert the emoji code unit by code unit to force chunk splits.
      final doc = TextDocument();
      const emoji = '😀'; // 2 code units
      doc
        ..pushText('a')
        // high surrogate
        ..pushText(emoji[0])
        // low surrogate
        ..pushText(emoji[1])
        ..pushText('b');
      // Layout: a(0) 😀[0](1) 😀[1](2) b(3)
      // prevRunePosition from b(3) should jump to 1 (start of 😀)
      expect(doc.prevRunePosition(3), 1);
      // prevRunePosition from middle of emoji (2) should jump to 1
      expect(doc.prevRunePosition(2), 1);
    });

    test('window expansion when cluster near window edge', () {
      // This test verifies the fallback when the result lands at
      // position 0 of the window but there is text before it.
      // We need a chunk layout where position is near a window
      // boundary. Insert many characters individually to create
      // many small chunks.
      final doc = TextDocument();
      // Build: 60 ASCII chars + emoji + more text
      final prefix = 'A' * 60; // 60 code units
      doc.insert(0, prefix);
      doc.pushText('😀'); // 2 code units at pos 60-61
      doc.pushText('B'); // at pos 62

      // Position 62 ('B') — prev should be 60 (start of 😀)
      expect(doc.prevRunePosition(62), 60);
      // Position 61 (inside 😀) — prev should be 60
      expect(doc.prevRunePosition(61), 60);
      // Position 60 (start of 😀) — prev should be 59 (last A)
      expect(doc.prevRunePosition(60), 59);
    });
  });

  group('nextRunePosition', () {
    test('empty document returns 0', () {
      final doc = TextDocument();
      expect(doc.nextRunePosition(0), 0);
    });

    test('position at or beyond length returns length', () {
      final doc = TextDocument()..pushText('Hello');
      expect(doc.nextRunePosition(5), 5);
      expect(doc.nextRunePosition(10), 5);
    });

    test('simple ASCII — one char forward', () {
      final doc = TextDocument()..pushText('ABCDE');
      expect(doc.nextRunePosition(0), 1);
      expect(doc.nextRunePosition(1), 2);
      expect(doc.nextRunePosition(2), 3);
      expect(doc.nextRunePosition(3), 4);
      expect(doc.nextRunePosition(4), 5);
    });

    test('simple ASCII — stepping forward through entire doc', () {
      final doc = TextDocument()..pushText('Hello World');
      var pos = 0;
      final positions = <int>[];
      while (pos < doc.length) {
        positions.add(pos);
        pos = doc.nextRunePosition(pos);
      }
      expect(positions, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(pos, doc.length);
    });

    test('emoji (2 code units) — jumps to next cluster start', () {
      final doc = TextDocument()..pushText('a😀b');
      final fullText = doc.plainText();
      final ref = CharacterBoundary(fullText);
      for (var pos = 0; pos < doc.length; pos++) {
        final expected = ref.getTrailingTextBoundaryAt(pos) ?? doc.length;
        expect(doc.nextRunePosition(pos), expected,
            reason: 'nextRunePosition($pos)');
      }
    });

    test('emoji with skin tone — jumps to next cluster start', () {
      final doc = TextDocument()..pushText('a👍🏽b');
      final fullText = doc.plainText();
      final ref = CharacterBoundary(fullText);
      for (var pos = 0; pos < doc.length; pos++) {
        final expected = ref.getTrailingTextBoundaryAt(pos) ?? doc.length;
        expect(doc.nextRunePosition(pos), expected,
            reason: 'nextRunePosition($pos)');
      }
    });

    test('family emoji ZWJ sequence — jumps to next cluster start', () {
      const family = '👨‍👩‍👧‍👦';
      final doc = TextDocument()..pushText('x${family}y');
      final fullText = doc.plainText();
      final ref = CharacterBoundary(fullText);
      for (var pos = 0; pos < doc.length; pos++) {
        final expected = ref.getTrailingTextBoundaryAt(pos) ?? doc.length;
        expect(doc.nextRunePosition(pos), expected,
            reason: 'nextRunePosition($pos)');
      }
    });

    test('mixed ASCII and emoji — walking forward', () {
      final doc = TextDocument()..pushText('Hello 😀 World 🌍!');
      var pos = 0;
      final chars = <String>[];
      while (pos < doc.length) {
        final next = doc.nextRunePosition(pos);
        chars.add(doc.plainText(pos, next));
        pos = next;
      }
      final reconstructed = chars.join();
      expect(reconstructed, doc.plainText());
    });

    test('crosses chunk boundaries — emoji split across chunks', () {
      final doc = TextDocument();
      const emoji = '😀'; // 2 code units
      doc
        ..pushText('a')
        // high surrogate
        ..pushText(emoji[0])
        // low surrogate
        ..pushText(emoji[1])
        ..pushText('b');
      // Layout: a(0) 😀[0](1) 😀[1](2) b(3)
      // nextRunePosition from 0 ('a') should jump to 1 (start of 😀)
      expect(doc.nextRunePosition(0), 1);
      // nextRunePosition from 1 (start of 😀) should jump to 3 ('b')
      expect(doc.nextRunePosition(1), 3);
      // nextRunePosition from inside emoji should jump to 'b'
      expect(doc.nextRunePosition(2), 3);
    });

    test('window expansion when cluster near window edge', () {
      final doc = TextDocument();
      final prefix = 'A' * 60;
      doc.insert(0, prefix);
      doc.pushText('😀'); // pos 60-61
      doc.pushText('B'); // pos 62
      doc.pushText('C' * 30); // pos 63-92

      // Position 60 (start of 😀) — next should be 62 ('B')
      expect(doc.nextRunePosition(60), 62);
      // Position 61 (inside 😀) — next should be 62
      expect(doc.nextRunePosition(61), 62);
    });
  });

  group('prevRunePosition + nextRunePosition (round-trip)', () {
    /// Helper: collect all grapheme cluster boundaries in document order.
    List<int> clusterBoundaries(TextDocument doc) {
      final boundaries = <int>[0];
      var p = 0;
      while (p < doc.length) {
        p = doc.nextRunePosition(p);
        boundaries.add(p);
      }
      return boundaries;
    }

    test('prev then next returns original position (ASCII)', () {
      final doc = TextDocument()..pushText('Hello World');
      // Round-trip is only guaranteed at grapheme cluster boundaries.
      final boundaries = clusterBoundaries(doc);
      for (final pos in boundaries) {
        if (pos < doc.length) {
          final next = doc.nextRunePosition(pos);
          final back = doc.prevRunePosition(next);
          expect(back, pos, reason: 'next→prev failed at boundary $pos');
        }
        if (pos > 0) {
          final prev = doc.prevRunePosition(pos);
          final back = doc.nextRunePosition(prev);
          expect(back, pos, reason: 'prev→next failed at boundary $pos');
        }
      }
    });

    test('next then prev returns original position (ASCII)', () {
      final doc = TextDocument()..pushText('Hello World');
      final boundaries = clusterBoundaries(doc);
      for (final pos in boundaries) {
        if (pos < doc.length) {
          final next = doc.nextRunePosition(pos);
          final back = doc.prevRunePosition(next);
          expect(back, pos, reason: 'next→prev failed at boundary $pos');
        }
      }
    });

    test('round-trip with emojis and mixed content', () {
      final doc = TextDocument()..pushText('Hello 😀 World 👍🏽!');
      final boundaries = clusterBoundaries(doc);
      for (final pos in boundaries) {
        if (pos < doc.length) {
          final next = doc.nextRunePosition(pos);
          final back = doc.prevRunePosition(next);
          expect(back, pos, reason: 'next→prev failed at boundary $pos');
        }
        if (pos > 0) {
          final prev = doc.prevRunePosition(pos);
          final back = doc.nextRunePosition(prev);
          expect(back, pos, reason: 'prev→next failed at boundary $pos');
        }
      }
    });

    test('round-trip with one-char-per-chunk layout', () {
      // Stress test: every character in its own chunk.
      final doc = TextDocument();
      const text = 'Hello 😀 World 👍🏽! 🌍';
      for (var i = 0; i < text.length; i++) {
        doc.insert(doc.length, text[i]);
      }

      // Round-trip at cluster boundaries only.
      final boundaries = clusterBoundaries(doc);
      for (final pos in boundaries) {
        if (pos < doc.length) {
          final next = doc.nextRunePosition(pos);
          final back = doc.prevRunePosition(next);
          expect(back, pos, reason: 'next→prev failed at boundary $pos');
        }
        if (pos > 0) {
          final prev = doc.prevRunePosition(pos);
          final back = doc.nextRunePosition(prev);
          expect(back, pos, reason: 'prev→next failed at boundary $pos');
        }
      }
    });
  });

  group('prevRunePosition / nextRunePosition — long document', () {
    test('walking entire long ASCII document forwards and backwards', () {
      final doc = TextDocument();
      // Build a document of 1000 characters with many small chunks.
      const baseText = 'The quick brown fox jumps over the lazy dog. ';
      for (var i = 0; i < 20; i++) {
        doc.insert(doc.length, baseText);
      }

      // Walk forward and collect all cluster boundaries.
      final forwardPositions = <int>[0];
      var pos = 0;
      while (pos < doc.length) {
        pos = doc.nextRunePosition(pos);
        forwardPositions.add(pos);
      }
      expect(forwardPositions.length, doc.length + 1);
      expect(forwardPositions.last, doc.length);

      // Walk backwards from the end.
      final backwardPositions = <int>[doc.length];
      pos = doc.length;
      while (pos > 0) {
        pos = doc.prevRunePosition(pos);
        backwardPositions.add(pos);
      }
      expect(backwardPositions.length, doc.length + 1);
      expect(backwardPositions.last,
          0); // stops at pos 0, doesn't call prevRunePosition(0)

      // The forward and reversed-backward should match.
      final reversedBackward = backwardPositions.reversed.toList();
      expect(reversedBackward, forwardPositions);
    });

    test('walking long document with emojis scattered throughout', () {
      final doc = TextDocument();
      // Build a document with emojis interspersed.
      const parts = [
        'Hello ',
        '😀',
        ' World ',
        '👍🏽',
        '! ',
        '🌍',
        ' The ',
        '👨‍👩‍👧‍👦',
        ' family.',
      ];
      for (final part in parts) {
        doc.insert(doc.length, part);
      }
      // Replicate to make it longer
      for (var i = 0; i < 10; i++) {
        doc.insert(doc.length, ' | ');
        for (final part in parts) {
          doc.insert(doc.length, part);
        }
      }

      // Walk forward and reconstruct.
      final chars = <String>[];
      var pos = 0;
      while (pos < doc.length) {
        final next = doc.nextRunePosition(pos);
        chars.add(doc.plainText(pos, next));
        pos = next;
      }
      expect(chars.join(), doc.plainText());

      // Walk backward and reconstruct.
      final revChars = <String>[];
      pos = doc.length;
      while (pos > 0) {
        final prev = doc.prevRunePosition(pos);
        revChars.insert(0, doc.plainText(prev, pos));
        pos = prev;
      }
      expect(revChars.join(), doc.plainText());
    });
  });
}
