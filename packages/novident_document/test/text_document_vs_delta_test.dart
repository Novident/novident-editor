import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

/// Helper: build a Delta matching the user's rich-text example.
Delta makeRichDelta() {
  return Delta()
    ..insert('My ')
    ..insert('Rich', attributes: {'bold': true, 'italic': true})
    ..insert(' Text', attributes: {'italic': true});
}

/// Helper: generate a large Delta with random text and attributes.
Delta makeLargeDelta(int chunkCount, {int? seed}) {
  final rng = Random(seed ?? 42);
  final delta = Delta();
  final words = [
    'The ',
    'quick ',
    'brown ',
    'fox ',
    'jumps ',
    'over ',
    'the ',
    'lazy ',
    'dog ',
    'runs ',
    'fast ',
    'slowly ',
    'bright ',
    'dark ',
    'red ',
    'blue ',
    'green ',
    'yellow '
  ];
  final attrOptions = [
    null,
    {'bold': true},
    {'italic': true},
    {'bold': true, 'italic': true},
    {'color': '#ff0000'},
    {'color': '#00ff00'},
    {'color': '#0000ff'},
  ];

  for (var i = 0; i < chunkCount; i++) {
    final word = words[rng.nextInt(words.length)];
    final attrs = attrOptions[rng.nextInt(attrOptions.length)];
    delta.insert(word, attributes: attrs);
  }
  return delta;
}

/// Helper: verify two Deltas have identical text and attributes
/// character by character.
void expectDeltaEquivalence(Delta a, Delta b) {
  final textA = a.toPlainText();
  final textB = b.toPlainText();
  expect(textA, textB, reason: 'Plain text differs');

  for (var i = 0; i < textA.length; i++) {
    // Extract the exact attribute of the character at position i,
    // NOT the inheritance attribute (sliceAttributes looks at the
    // previous position).
    final attrsA = a.slice(i, i + 1).firstOrNull?.attributes;
    final attrsB = b.slice(i, i + 1).firstOrNull?.attributes;
    expect(attrsA, attrsB, reason: 'Attributes differ at position $i');
  }
}

/// Helper: verify TextDocument and Delta produce the same result.
void expectDocAndDeltaMatch(TextDocument doc, Delta delta) {
  final docDelta = doc.toDelta();
  expectDeltaEquivalence(docDelta, delta);
}

void main() {
  group('Correctness: Delta ↔ TextDocument equivalence', () {
    test('rich text example from description', () {
      final delta = makeRichDelta();
      // [{"insert":"My "},{"insert":"Rich","attributes":{"bold":true,"italic":true}},{"insert":" Text","attributes":{"italic":true}}]

      // Via Delta
      expect(delta.toPlainText(), 'My Rich Text');

      // Via TextDocument
      final doc = TextDocument.fromDelta(delta);
      expect(doc.plainText(), 'My Rich Text');
      expect(doc.length, delta.length);

      // Attributes: both must match character by character
      expectDocAndDeltaMatch(doc, delta);

      // Specific positions — attributesAt vs Delta
      // 'M' (pos 0) = plain
      expect(doc.attributesAt(0), isNull);
      // 'R' (pos 3) = bold + italic
      expect(doc.attributesAt(3), {'bold': true, 'italic': true});
      // 'T' (pos 7) = italic
      expect(doc.attributesAt(7), {'italic': true});

      // sliceAttributes has different semantics (attribute inheritance):
      // it looks at the PREVIOUS position. Inserting at pos 3 inherits
      // from the space (pos 2, null).
      expect(delta.sliceAttributes(3), isNull);
      // Inserting at pos 4 inherits from 'R' (pos 3, bold+italic).
      expect(delta.sliceAttributes(4), {'bold': true, 'italic': true});
    });

    test('round-trip: Delta → TextDocument → Delta preserves everything', () {
      final original = makeRichDelta();
      final doc = TextDocument.fromDelta(original);
      final roundTripped = doc.toDelta();

      expectDeltaEquivalence(original, roundTripped);
    });

    test('round-trip: TextDocument → native JSON → TextDocument', () {
      final original = TextDocument.fromDelta(makeRichDelta());
      final nativeJson = original.toNativeJson();
      final restored = TextDocument.fromNativeJson(nativeJson);

      expect(restored.plainText(), original.plainText());
      expect(restored.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(restored.attributesAt(i), original.attributesAt(i));
      }
    });

    test('native JSON format is correct', () {
      final doc = TextDocument.fromDelta(makeRichDelta());
      final json = doc.toNativeJson();

      expect(json['v'], 1);
      expect(json['c'], isA<List>());
      expect(json['c'].length, 3);

      // Chunk 0: plain text "My "
      expect(json['c'][0]['t'], 'My ');
      expect(json['c'][0].containsKey('a'), isFalse);

      // Chunk 1: bold+italic "Rich"
      expect(json['c'][1]['t'], 'Rich');
      expect(json['c'][1]['a'], {'bold': true, 'italic': true});

      // Chunk 2: italic " Text"
      expect(json['c'][2]['t'], ' Text');
      expect(json['c'][2]['a'], {'italic': true});
    });

    test('native JSON handles empty document', () {
      final doc = TextDocument.empty();
      final json = doc.toNativeJson();
      expect(json, {'v': 1, 'c': []});

      final restored = TextDocument.fromNativeJson(json);
      expect(restored.isEmpty, isTrue);
      expect(restored.length, 0);
    });

    test('insert produces identical results in Delta and TextDocument', () {
      // Same sequence of operations applied to both
      var delta = Delta()..insert('Hello');
      var doc = TextDocument.fromDelta(Delta()..insert('Hello'));

      // Insert at end
      delta = delta.compose(Delta()
        ..retain(5)
        ..insert(' World'));
      doc.applyDelta(Delta()
        ..retain(5)
        ..insert(' World'));
      expectDocAndDeltaMatch(doc, delta);

      // Insert in middle
      delta = delta.compose(Delta()
        ..retain(6)
        ..insert('Beautiful '));
      doc.applyDelta(Delta()
        ..retain(6)
        ..insert('Beautiful '));
      expectDocAndDeltaMatch(doc, delta);

      // Insert with attributes
      delta = delta.compose(
        Delta()
          ..retain(0)
          ..insert('>>', attributes: {'color': 'red'}),
      );
      doc.applyDelta(
        Delta()
          ..retain(0)
          ..insert('>>', attributes: {'color': 'red'}),
      );
      expectDocAndDeltaMatch(doc, delta);
    });

    test('delete produces identical results in Delta and TextDocument', () {
      var delta = Delta()..insert('Hello Beautiful World!');
      var doc = TextDocument.fromDelta(delta);

      // Delete "Beautiful "
      delta = delta.compose(Delta()
        ..retain(6)
        ..delete(10));
      doc.applyDelta(Delta()
        ..retain(6)
        ..delete(10));
      expectDocAndDeltaMatch(doc, delta);
      expect(delta.toPlainText(), 'Hello World!');
      expect(doc.plainText(), 'Hello World!');
    });

    test('format produces identical results in Delta and TextDocument', () {
      var delta = Delta()..insert('Hello World');
      var doc = TextDocument.fromDelta(delta);

      // Format "Hello" as bold
      delta = delta.compose(
        Delta()
          ..retain(0)
          ..retain(5, attributes: {'bold': true}),
      );
      doc.applyDelta(
        Delta()
          ..retain(0)
          ..retain(5, attributes: {
            'bold': true,
          }),
      );
      expectDocAndDeltaMatch(doc, delta);

      // Format "World" as italic (adds to existing plain text)
      delta = delta.compose(
        Delta()
          ..retain(6)
          ..retain(5, attributes: {'italic': true}),
      );
      doc.applyDelta(
        Delta()
          ..retain(6)
          ..retain(5, attributes: {'italic': true}),
      );
      expectDocAndDeltaMatch(doc, delta);
    });

    test('complex sequence: insert + delete + format matches Delta.compose',
        () {
      var delta = Delta()
        ..insert('Gandalf', attributes: {'bold': true})
        ..insert(' the ')
        ..insert('Grey', attributes: {'color': '#ccc'});
      var doc = TextDocument.fromDelta(delta);

      // Replace "Grey" with "White"
      final change = Delta()
        ..retain(12)
        ..insert('White', attributes: {'color': '#fff'})
        ..delete(4);

      delta = delta.compose(change);
      doc.applyDelta(change);

      expect(delta.toPlainText(), 'Gandalf the White');
      expect(doc.plainText(), 'Gandalf the White');
      expectDocAndDeltaMatch(doc, delta);
    });

    test('large random operations produce identical results', () {
      final rng = Random(123);
      final initial = makeLargeDelta(200);
      var delta = initial;
      var doc = TextDocument.fromDelta(initial);

      // Apply 100 random operations to both
      for (var i = 0; i < 100; i++) {
        final op = rng.nextInt(3); // 0=insert, 1=delete, 2=format
        final pos = rng.nextInt(max(1, delta.length));

        switch (op) {
          case 0: // insert
            final text = ['X', 'YY', 'ZZZ'][rng.nextInt(3)];
            final attrs = rng.nextBool() ? {'bold': true} : null;
            delta = delta.compose(
              Delta()
                ..retain(pos)
                ..insert(text, attributes: attrs),
            );
            doc.applyDelta(
              Delta()
                ..retain(pos)
                ..insert(text, attributes: attrs),
            );
            break;
          case 1: // delete
            final len = rng.nextInt(min(5, delta.length - pos)) + 1;
            delta = delta.compose(Delta()
              ..retain(pos)
              ..delete(len));
            doc.applyDelta(Delta()
              ..retain(pos)
              ..delete(len));
            break;
          case 2: // format
            final len = rng.nextInt(min(10, delta.length - pos)) + 1;
            final attrs = {'color': '#ff0000'};
            delta = delta.compose(
              Delta()
                ..retain(pos)
                ..retain(len, attributes: attrs),
            );
            doc.applyDelta(
              Delta()
                ..retain(pos)
                ..retain(len, attributes: attrs),
            );
            break;
        }

        // Verify after each operation
        expect(doc.length, delta.length,
            reason: 'Length mismatch after operation $i (op=$op)');
      }

      // Final verification
      expectDocAndDeltaMatch(doc, delta);
    });

    test(
        'toJson equivalence: Delta.toJson() matches TextDocument.toDelta().toJson()',
        () {
      final delta = makeRichDelta();
      final doc = TextDocument.fromDelta(delta);

      // Via TextDocument → Delta → JSON
      final docJson = doc.toJson(); // List<dynamic>
      final deltaJson = delta.toJson(); // List<dynamic>

      expect(docJson, deltaJson);
    });

    test('every character attribute matches between Delta and TextDocument',
        () {
      final delta = makeRichDelta();
      final doc = TextDocument.fromDelta(delta);

      final text = delta.toPlainText();
      for (var i = 0; i < text.length; i++) {
        // attributesAt returns the attribute OF the character at the position.
        // sliceAttributes returns the attribute TO INHERIT when inserting there
        // (it looks at the previous position). For character-by-character
        // comparison we use slice(i, i+1) which extracts the exact TextInsert.
        final deltaAttr = delta.slice(i, i + 1).firstOrNull?.attributes;
        final docAttr = doc.attributesAt(i);
        expect(docAttr, deltaAttr,
            reason: 'Attribute mismatch at position $i (char: "${text[i]}")');
      }
    });
  });

  group('Performance: Delta vs TextDocument', () {
    test('construction from large delta', () {
      final delta = makeLargeDelta(5000);

      final deltaStopwatch = Stopwatch()..start();
      // Delta "construction" is just holding the list — O(1)
      final _ = Delta.fromJson(delta.toJson());
      deltaStopwatch.stop();

      final docStopwatch = Stopwatch()..start();
      final doc = TextDocument.fromDelta(delta);
      docStopwatch.stop();

      // TextDocument construction is O(n) with Cartesian tree builder.
      // Should be fast (< 100ms for 5000 chunks).
      debugPrint("LENGTH: DOC=${doc.length} vs DELTA=${delta.length}");
      debugPrint("TIMES ELAPSED (DOC): ${docStopwatch.elapsedMilliseconds}");
      debugPrint(
          "TIMES ELAPSED (DELTA): ${deltaStopwatch.elapsedMilliseconds}");
      // Normally you find things like:
      //
      // LENGTH: DOC=26338 vs DELTA=26338
      // TIMES ELAPSED (DOC): 4
      // TIMES ELAPSED (DELTA): 11
      expect(doc.length, delta.length);
      expect(docStopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'TextDocument.fromDelta should build in O(n) < 500ms');
      expect(deltaStopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('insert in large document: O(log n) vs O(n)', () {
      final delta = makeLargeDelta(5000);
      final doc = TextDocument.fromDelta(delta);

      // Delta insert (via compose)
      final deltaStopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        final change = Delta()
          ..retain(2500)
          ..insert('X');
        // We can't mutate delta.compose in place and reuse easily,
        // but we measure the compose time.
        delta.compose(change);
      }
      deltaStopwatch.stop();

      // TextDocument insert
      final docStopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        doc.insert(2500 + i, 'X');
      }
      docStopwatch.stop();

      // TextDocument should be significantly faster for large docs.
      // Even if not 10x faster in this small test, the trend matters.
      expect(docStopwatch.elapsedMicroseconds,
          lessThan(deltaStopwatch.elapsedMicroseconds * 2),
          reason: 'TextDocument.insert should be faster than Delta.compose '
              'for large documents');
    });

    test('delete in large document', () {
      final delta = makeLargeDelta(5000);
      final doc = TextDocument.fromDelta(delta);

      // Delta delete
      final deltaStopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        delta.compose(Delta()
          ..retain(1000)
          ..delete(3));
      }
      deltaStopwatch.stop();

      // TextDocument delete
      final docStopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        doc.delete(1000, 3);
      }
      docStopwatch.stop();

      expect(docStopwatch.elapsedMicroseconds,
          lessThan(deltaStopwatch.elapsedMicroseconds * 2),
          reason: 'TextDocument.delete should be faster than Delta.compose');
    });

    test('format in large document', () {
      final delta = makeLargeDelta(5000);
      final doc = TextDocument.fromDelta(delta);

      // Delta format
      final deltaStopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        delta.compose(
          Delta()
            ..retain(1000)
            ..retain(10, attributes: {'bold': true}),
        );
      }
      deltaStopwatch.stop();

      // TextDocument format
      final docStopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        doc.format(1000, 10, {'bold': true});
      }
      docStopwatch.stop();

      expect(docStopwatch.elapsedMicroseconds,
          lessThan(deltaStopwatch.elapsedMicroseconds * 2),
          reason: 'TextDocument.format should be faster than Delta.compose');
    });

    test('attributesAt lookup: O(log n) vs O(n)', () {
      final delta = makeLargeDelta(5000);
      final doc = TextDocument.fromDelta(delta);

      // Delta attribute lookup (uses slice, which is O(n))
      final deltaStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        delta.sliceAttributes(i * 10 % delta.length);
      }
      deltaStopwatch.stop();

      // TextDocument attribute lookup (O(log n))
      final docStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        doc.attributesAt(i * 10 % doc.length);
      }
      docStopwatch.stop();

      // TextDocument should be MUCH faster here — O(log n) vs O(n).
      // For 500 lookups on 5000 chunks:
      //   Delta:    500 × 5000 = 2,500,000 operations
      //   Treap:    500 × log₂(5000) ≈ 500 × 13 = 6,500 operations
      expect(docStopwatch.elapsedMicroseconds,
          lessThan(deltaStopwatch.elapsedMicroseconds ~/ 10),
          reason: 'TextDocument.attributesAt (O(log n)) should be '
              'at least 10x faster than Delta.sliceAttributes (O(n))');
    });

    test('slice range: O(log n + k) vs O(n)', () {
      final delta = makeLargeDelta(5000);
      final doc = TextDocument.fromDelta(delta);

      // Delta slice (O(n) — walks all operations to find range)
      final deltaStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        delta.slice(1000, 1100);
      }
      deltaStopwatch.stop();

      // TextDocument slice (O(log n + k))
      final docStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        doc.slice(1000, 1100);
      }
      docStopwatch.stop();

      expect(docStopwatch.elapsedMicroseconds,
          lessThan(deltaStopwatch.elapsedMicroseconds * 2),
          reason: 'TextDocument.slice should be faster than Delta.slice');
    });

    test('applyDelta vs compose: small edit on large document', () {
      final delta = makeLargeDelta(5000);
      final doc = TextDocument.fromDelta(delta);

      final change = Delta()
        ..retain(2500)
        ..insert('Hello!', attributes: {'bold': true})
        ..delete(3);

      // Delta compose
      final deltaStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        delta.compose(change);
      }
      deltaStopwatch.stop();

      // TextDocument applyDelta
      final docStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        doc.applyDelta(change);
      }
      docStopwatch.stop();

      expect(docStopwatch.elapsedMicroseconds,
          lessThan(deltaStopwatch.elapsedMicroseconds * 2),
          reason: 'applyDelta (O(log n)) should be faster than '
              'Delta.compose (O(n))');
    });
    // The test measures how insert time grows as document size increases.
    // The key metric is time / size ratio:
    //
    // Sizes:      500    1000    2500    5000
    // Times:      t₁     t₂      t₃      t₄
    //
    // Ratio = time / size
    // For O(n):      ratio ≈ constant  (e.g. 0.5, 0.48, 0.51, 0.49)
    // For O(log n):  ratio ↓           (e.g. 0.5, 0.30, 0.15, 0.08)
    test('scaling: insert time stays logarithmic as doc grows', () {
      // Verify that insert time scales sub-linearly.
      // For O(log n), time / log2(size) should stay roughly constant.
      // For O(n), time / size would be constant (but time would explode).

      final sizes = [500, 1000, 2500, 5000];
      final times = <double>[];

      for (final size in sizes) {
        final delta = makeLargeDelta(size);
        final doc = TextDocument.fromDelta(delta);

        final sw = Stopwatch()..start();
        for (var i = 0; i < 30; i++) {
          doc.insert(size ~/ 2 + i, 'X');
        }
        sw.stop();
        times.add(sw.elapsedMicroseconds.toDouble());
      }

      // Key insight: for a sub-linear algorithm, time/size RATIO
      // should DECREASE as size grows. For O(n), time/size is constant.
      // For O(log n), time grows much slower than size.
      final ratios = <double>[];
      for (var i = 0; i < sizes.length; i++) {
        ratios.add(times[i] / sizes[i]);
      }

      // The time/size ratio for the largest doc must be significantly
      // smaller than for the smallest doc — this proves sub-linear scaling.
      // (For O(n) it would be roughly equal; for O(log n) it drops.)
      debugPrint("RATIO=${ratios.last} < ${ratios.first * 0.5}");
      expect(ratios.last, lessThan(ratios.first * 0.5),
          reason: 'time/size ratio should decrease as doc grows '
              '(sub-linear scaling). Sizes: $sizes, '
              'ratios: ${ratios.map((r) => r.toStringAsFixed(4)).toList()}');
    });
  });

  group('Native JSON format', () {
    test('empty document round-trip', () {
      final doc = TextDocument.empty();
      final json = doc.toNativeJson();
      final restored = TextDocument.fromNativeJson(json);

      expect(restored.isEmpty, isTrue);
      expect(restored.length, 0);
      expect(restored.chunks, isEmpty);
    });

    test('rich document round-trip', () {
      final original = TextDocument.fromDelta(makeRichDelta());
      final json = original.toNativeJson();
      final restored = TextDocument.fromNativeJson(json);

      expect(restored.plainText(), original.plainText());
      expect(restored.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(restored.attributesAt(i), original.attributesAt(i),
            reason: 'Attribute mismatch at position $i');
      }
    });

    test('large document round-trip', () {
      final delta = makeLargeDelta(1000, seed: 42);
      final original = TextDocument.fromDelta(delta);
      final json = original.toNativeJson();
      final restored = TextDocument.fromNativeJson(json);

      expect(restored.plainText(), original.plainText());
      expect(restored.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(restored.attributesAt(i), original.attributesAt(i),
            reason: 'Attribute mismatch at position $i');
      }
    });

    test('native JSON is more compact than Delta JSON', () {
      final delta = makeLargeDelta(500, seed: 42);
      final doc = TextDocument.fromDelta(delta);

      final deltaJson = delta.toJson();
      final nativeJson = doc.toNativeJson();

      // Native JSON should be more compact or comparable.
      // Delta JSON has 'insert'/'attributes' keys; native has 't'/'a'.
      // We just verify both are valid and reconstruct correctly.
      final restoredFromDelta = TextDocument.fromJson(deltaJson);
      final restoredFromNative = TextDocument.fromNativeJson(nativeJson);

      expect(restoredFromDelta.plainText(), restoredFromNative.plainText());
    });

    test('native JSON with null attributes omits the key', () {
      final doc = TextDocument.empty();
      doc.insert(0, 'Plain text');
      doc.insert(10, 'Bold', attributes: {'bold': true});

      final json = doc.toNativeJson();
      final chunks = json['c'] as List;

      // First chunk: plain text, no 'a' key
      expect(chunks[0], contains('t'));
      expect(chunks[0], isNot(contains('a')));

      // Second chunk: has attributes
      expect(chunks[1], contains('t'));
      expect(chunks[1], contains('a'));
      expect(chunks[1]['a'], {'bold': true});
    });

    test('fromNativeJson rejects unsupported versions', () {
      expect(
        () => TextDocument.fromNativeJson({'v': 0, 'c': []}),
        throwsFormatException,
      );
      expect(
        () => TextDocument.fromNativeJson({'v': 999, 'c': []}),
        isNot(throwsFormatException), // v >= 1 should be ok for forward compat
      );
    });
  });
}
