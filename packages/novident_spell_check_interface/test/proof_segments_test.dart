import 'package:flutter_test/flutter_test.dart';
import 'package:novident_spell_check_interface/novident_spell_check_interface.dart';

import 'helpers/fake_spell_checker.dart';

void main() {
  group('buildProofSegments', () {
    // Helper: build segments from the raw text using the fake checker
    // (integration through the public contract).
    List<ProofSegment> segmentsOf(String text, {FakeSpellChecker? checker}) {
      final engine = checker ?? FakeSpellChecker();
      return buildProofSegments(text, engine.check(text));
    }

    group('trivial inputs', () {
      test('empty text produces no segments', () {
        expect(buildProofSegments('', []), isEmpty);
        expect(segmentsOf(''), isEmpty);
      });

      test('no issues produces a single valid segment covering everything', () {
        const text = 'hello world albert';
        final segments = buildProofSegments(text, const []);
        expect(segments, hasLength(1));
        expect(segments.single.isError, false);
        expect(segments.single.startOffset, 0);
        expect(segments.single.endOffset, text.length);
      });

      test('fully valid text produces one valid segment', () {
        final segments = segmentsOf('hello world');
        expect(segments, hasLength(1));
        expect(segments.single.isError, false);
        expect(segments.single.text, 'hello world');
      });
    });

    group('issue placement', () {
      test('error at the start', () {
        final segments = segmentsOf('wrld hello');
        expect(segments, hasLength(2));
        expect(segments[0].isError, true);
        expect(segments[0].startOffset, 0);
        expect(segments[0].endOffset, 4);
        expect(segments[0].text, 'wrld');
        expect(segments[1].isError, false);
        expect(segments[1].text, ' hello');
      });

      test('error at the end', () {
        final segments = segmentsOf('hello wrld');
        expect(segments, hasLength(2));
        expect(segments[0].isError, false);
        expect(segments[0].text, 'hello ');
        expect(segments[1].isError, true);
        expect(segments[1].startOffset, 6);
        expect(segments[1].endOffset, 10);
        expect(segments[1].text, 'wrld');
      });

      test('error in the middle', () {
        final segments = segmentsOf('hello wrld albert');
        expect(segments, hasLength(3));
        expect(segments[0].isError, false);
        expect(segments[1].isError, true);
        expect(segments[1].text, 'wrld');
        expect(segments[2].isError, false);
        expect(segments[2].text, ' albert');
      });

      test('multiple errors separated by valid text', () {
        final segments = segmentsOf('wrd hello wrd');
        expect(segments, hasLength(3));
        expect(
          segments.map((s) => s.isError).toList(),
          [true, false, true],
        );
        expect(segments[0].text, 'wrd');
        expect(segments[1].text, ' hello ');
        expect(segments[2].text, 'wrd');
      });

      test('adjacent errors produce two consecutive error segments', () {
        final segments = buildProofSegments(
          'wrd wrd',
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 3, word: 'wrd'),
            SpellCheckIssue(startOffset: 4, endOffset: 7, word: 'wrd'),
          ],
        );
        expect(segments, hasLength(3));
        expect(segments[0].isError, true);
        expect(segments[0].text, 'wrd');
        expect(segments[1].isError, false);
        expect(segments[1].text, ' ');
        expect(segments[2].isError, true);
        expect(segments[2].text, 'wrd');
      });

      test('back-to-back errors with no gap', () {
        final segments = buildProofSegments(
          'wrda',
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 2, word: 'wr'),
            SpellCheckIssue(startOffset: 2, endOffset: 4, word: 'da'),
          ],
        );
        expect(segments, hasLength(2));
        expect(segments[0].isError, true);
        expect(segments[0].endOffset, 2);
        expect(segments[1].isError, true);
        expect(segments[1].startOffset, 2);
        expect(segments[1].endOffset, 4);
      });
    });

    group('normalization of hostile issues', () {
      test('unsorted issues are sorted', () {
        final segments = buildProofSegments(
          'aa bb',
          const [
            SpellCheckIssue(startOffset: 3, endOffset: 5, word: 'bb'),
            SpellCheckIssue(startOffset: 0, endOffset: 2, word: 'aa'),
          ],
        );
        expect(segments.first.startOffset, 0);
        expect(segments.first.isError, true);
        expect(segments.last.startOffset, 3);
        expect(segments.last.isError, true);
      });

      test('duplicated issues collapse into one segment', () {
        final segments = buildProofSegments(
          'wrd',
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 3, word: 'wrd'),
            SpellCheckIssue(startOffset: 0, endOffset: 3, word: 'wrd'),
          ],
        );
        expect(segments, hasLength(1));
        expect(segments.single.isError, true);
      });

      test('partially overlapping issues: first wins, second is truncated', () {
        final segments = buildProofSegments(
          'abcdef',
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 4, word: 'abcd'),
            SpellCheckIssue(startOffset: 2, endOffset: 6, word: 'cdef'),
          ],
        );
        expect(segments, hasLength(2));
        expect(segments[0].isError, true);
        expect(segments[0].startOffset, 0);
        expect(segments[0].endOffset, 4);
        expect(segments[1].isError, true);
        expect(segments[1].startOffset, 4);
        expect(segments[1].endOffset, 6);
      });

      test('issue fully contained in another is dropped', () {
        final segments = buildProofSegments(
          'abcdef',
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 6, word: 'abcdef'),
            SpellCheckIssue(startOffset: 2, endOffset: 4, word: 'cd'),
          ],
        );
        expect(segments, hasLength(1));
        expect(segments.single.startOffset, 0);
        expect(segments.single.endOffset, 6);
      });

      test('zero-length issues are dropped', () {
        final segments = buildProofSegments(
          'ab',
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 0, word: ''),
            SpellCheckIssue(startOffset: 0, endOffset: 1, word: 'a'),
          ],
        );
        expect(segments, hasLength(2));
        expect(segments[0].isError, true);
        expect(segments[0].length, 1);
        expect(segments[1].isError, false);
        expect(segments[1].text, 'b');
      });

      test('negative start is clamped to 0', () {
        final segments = buildProofSegments(
          'ab',
          [
            SpellCheckIssue(startOffset: -2, endOffset: 1, word: 'a'),
          ],
        );
        expect(segments.first.startOffset, 0);
        expect(segments.first.endOffset, 1);
        expect(segments.first.isError, true);
      });

      test('end beyond text length is clamped', () {
        final segments = buildProofSegments(
          'ab',
          const [
            SpellCheckIssue(startOffset: 1, endOffset: 99, word: 'b'),
          ],
        );
        expect(segments.last.startOffset, 1);
        expect(segments.last.endOffset, 2);
        expect(segments.last.isError, true);
      });

      test('issue entirely out of range is dropped', () {
        final segments = buildProofSegments(
          'ab',
          const [
            SpellCheckIssue(startOffset: 5, endOffset: 9, word: 'x'),
          ],
        );
        expect(segments, hasLength(1));
        expect(segments.single.isError, false);
      });
    });

    group('unicode', () {
      test('offsets are UTF-16 code units: emoji counts as 2 units', () {
        const text = 'hi 😀 wrld';
        // 'hi ' = 3 units, '😀' = 2 units, ' ' = 1 unit → 'wrld' starts at 6.
        final segments = segmentsOf(text);
        final error = segments.firstWhere((s) => s.text == 'wrld');
        expect(error.startOffset, 6);
        expect(error.endOffset, 10);
        expect(error.text, 'wrld');
      });

      test('accented words are preserved', () {
        // 'camión' no está en el diccionario del fake.
        final segments = segmentsOf('el camión');
        final error = segments.firstWhere((s) => s.text == 'camión');
        expect(error.startOffset, 3);
      });

      test('apostrophe words keep their full extent', () {
        final segments = buildProofSegments(
          "it's",
          const [
            SpellCheckIssue(startOffset: 0, endOffset: 4, word: "it's"),
          ],
        );
        expect(segments, hasLength(1));
        expect(segments.single.isError, true);
        expect(segments.single.text, "it's");
      });
    });

    group('coverage invariants', () {
      const samples = [
        'hello world',
        'wrd hello wrd albert',
        'a wrd',
        'wrd',
        'wrd wrd',
        '  spaces  everywhere  ',
        'punctuation, only! here...',
        'el camión llegó, pero 123 no.',
        '😀 hola 😀 wrd',
        'x',
      ];

      for (final text in samples) {
        test('segments are contiguous and rebuild "$text"', () {
          final segments = segmentsOf(text);
          // Contiguity: each segment starts where the previous ended.
          var cursor = 0;
          for (final segment in segments) {
            expect(segment.startOffset, cursor,
                reason: 'gap or overlap at "$text"');
            cursor = segment.endOffset;
          }
          expect(cursor, text.length);
          // Round-trip: concatenation reproduces the original text exactly.
          final rebuilt = segments.map((s) => s.text).join();
          expect(rebuilt, text);
        });
      }
    });
  });
}
