import 'package:flutter/material.dart'
    hide RichText, TextPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Regression tests for [SelectableMixin.moveVerticallyInText], which
/// uses [TextPainter.getLineBoundary] to navigate between visual lines.
///
/// These tests verify correct behaviour with mixed font sizes, first-line
/// indents, and edge cases — bugs that the previous pixel-estimation
/// algorithm could not handle.
void main() {
  group('moveVerticallyInText', () {
    late EditorState es;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await NovidentEditorLocalizations.load(const Locale('en'));
    });

    tearDown(() => es.dispose());

    // ── Helpers ─────────────────────────────────────────────────────

    /// Build editor with the given [delta] and return the node's
    /// [SelectableMixin] so we can call [moveVerticallyInText] directly.
    Future<SelectableMixin> build(WidgetTester tester, Delta delta) async {
      es = EditorState.blank(withInitialText: false);

      final tx = es.transaction;
      tx.insertNode([0], paragraphNode(delta: delta));
      await es.apply(tx);

      es.editorStyle = const EditorStyle.desktop(
        padding: EdgeInsets.symmetric(horizontal: 32),
        firstLineIndent: 30,
        maxWidth: 654,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 654,
              child: NovidentEditor(
                editorState: es,
                editorStyle: es.editorStyle,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return es.getNodeAtPath([0])!.selectable!;
    }

    // ── Tests ───────────────────────────────────────────────────────

    testWidgets('mixed font sizes (42px → 12px) — walk up from end',
        (tester) async {
      final delta = Delta()
        ..insert(
          'BIG HEADING TEXT — ',
          attributes: {RichTextKeys.fontSize: 42.0},
        )
        ..insert(
          'and now the body text continues with a much smaller font size. '
          'The quick brown fox jumps over the lazy dog. '
          'Pack my box with five dozen liquor jugs. '
          'How vexingly quick daft zebras jump! '
          'The five boxing wizards jump quickly. '
          'Sphinx of black quartz, judge my vow. '
          'Waltz, bad nymph, for quick jigs vex. '
          'and now the body text continues with a much smaller font size. '
          'The quick brown fox jumps over the lazy dog. ',
          attributes: {RichTextKeys.fontSize: 12.0},
        );

      final selectable = await build(tester, delta);
      final textLen = delta.length;

      // Walk from end to start.
      final offsets = <int>[textLen];
      var current = textLen;
      for (var i = 0; i < 15; i++) {
        final next = selectable.moveVerticallyInText(current, true);
        if (next == null) break;
        expect(next.offset, lessThan(current),
            reason: 'Step $i: must move upward ($current → ${next.offset})',);
        current = next.offset;
        offsets.add(current);
      }

      // We should have walked multiple lines.
      expect(offsets.length, greaterThan(3),
          reason: 'Expected at least 4 lines, got ${offsets.length}',);

      // No step should jump more than ~100 characters (one line).
      for (var i = 1; i < offsets.length; i++) {
        final diff = offsets[i - 1] - offsets[i];
        expect(diff, lessThan(120),
            reason:
                'Step $i: jump of $diff chars is too large '
                '(${offsets[i - 1]} → ${offsets[i]})',);
      }

      // Should reach the beginning.
      expect(offsets.last, lessThanOrEqualTo(20),
          reason:
              'Should walk close to offset 0, got ${offsets.last}. '
              'Full walk: $offsets',);
    });

    testWidgets('homogeneous font — walk up from end', (tester) async {
      const text =
          'The quick brown fox jumps over the lazy dog. '
          'Pack my box with five dozen liquor jugs. '
          'How vexingly quick daft zebras jump! '
          'The five boxing wizards jump quickly. '
          'Sphinx of black quartz, judge my vow. '
          'Waltz, bad nymph, for quick jigs vex. '
          'Glib jocks quiz nymph to vex dwarf. '
          'Jackdaws love my big sphinx of quartz. '
          'The quick brown fox jumps over the lazy dog. ';

      final delta = Delta()..insert(text);
      final selectable = await build(tester, delta);
      final textLen = delta.length;

      var current = textLen;
      var steps = 0;
      while (current > 0 && steps < 30) {
        final next = selectable.moveVerticallyInText(current, true);
        if (next == null) break;
        expect(next.offset, lessThan(current));
        current = next.offset;
        steps++;
      }

      // Should reach close to offset 0.
      expect(current, lessThanOrEqualTo(80),
          reason: 'Should walk close to start, stuck at $current',);
      expect(steps, greaterThan(2));
    });

    testWidgets('walk down from start', (tester) async {
      const text =
          'The quick brown fox jumps over the lazy dog. '
          'Pack my box with five dozen liquor jugs. '
          'How vexingly quick daft zebras jump! '
          'The five boxing wizards jump quickly. ';

      final delta = Delta()..insert(text);
      final selectable = await build(tester, delta);
      final textLen = delta.length;

      var current = 0;
      var steps = 0;
      while (current < textLen && steps < 30) {
        final next = selectable.moveVerticallyInText(current, false);
        if (next == null) break;
        expect(next.offset, greaterThan(current),
            reason: 'Step $steps: must move downward',);
        current = next.offset;
        steps++;
      }

      expect(steps, greaterThan(1));
      expect(current, greaterThan(textLen ~/ 2),
          reason: 'Should move past halfway, stuck at $current',);
    });

    testWidgets('single-line paragraph — returns null at boundaries',
        (tester) async {
      final delta = Delta()..insert('Short text.');
      final selectable = await build(tester, delta);

      // From start going up → null (no previous line).
      expect(selectable.moveVerticallyInText(0, true), isNull);

      // From end going down → null (no next line).
      expect(selectable.moveVerticallyInText(delta.length, false), isNull);
    });

    testWidgets('offset at 0 — returns null when going up', (tester) async {
      final delta = Delta()..insert('Line one\nLine two');
      final selectable = await build(tester, delta);

      expect(selectable.moveVerticallyInText(0, true), isNull);
    });

    testWidgets('offset at textLen — returns null when going down',
        (tester) async {
      final delta = Delta()..insert('Line one\nLine two');
      final selectable = await build(tester, delta);

      expect(selectable.moveVerticallyInText(delta.length, false), isNull);
    });

    testWidgets('consecutive steps are monotonic upward', (tester) async {
      final delta = Delta()
        ..insert(
          'BIG HEADING — ',
          attributes: {RichTextKeys.fontSize: 42.0},
        )
        ..insert(
          'Now this is the body text with a much smaller font. '
          'It should wrap across multiple lines. '
          'Each step up should move to the previous visual line. '
          'No jumping, no skipping, no getting stuck. '
          'The quick brown fox jumps over the lazy dog again and again. '
          'Pack my box with five dozen liquor jugs for the party tonight. ',
          attributes: {RichTextKeys.fontSize: 12.0},
        );

      final selectable = await build(tester, delta);
      final textLen = delta.length;

      var current = textLen;
      final offsets = <int>[current];
      for (var i = 0; i < 20; i++) {
        final next = selectable.moveVerticallyInText(current, true);
        if (next == null) break;
        expect(next.offset, lessThan(current),
            reason: 'Step $i must decrease: $current → ${next.offset}',);
        current = next.offset;
        offsets.add(current);
      }

      // Verify monotonic: each step reduces the offset.
      for (var i = 1; i < offsets.length; i++) {
        expect(offsets[i], lessThan(offsets[i - 1]));
      }

      // Should have walked multiple lines.
      expect(offsets.length, greaterThan(3));
    });
  });
}
