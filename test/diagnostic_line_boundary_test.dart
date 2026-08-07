import 'package:flutter/material.dart'
    hide RichText, TextPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';

/// Diagnostic: prove that [TextPainter.getLineBoundary] correctly
/// identifies line boundaries even with mixed font sizes, while the
/// current [moveVerticallyInText] fails.
void main() {
  group('getLineBoundary — mixed fonts diagnostic', () {
    late EditorState es;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await NovidentEditorLocalizations.load(const Locale('en'));
    });

    tearDown(() => es.dispose());

    testWidgets('print line boundaries for mixed-font paragraph',
        (tester) async {
      es = EditorState.blank(withInitialText: false);

      // ── Build a paragraph with BIG font first, then SMALL font ──
      // This mimics a heading + body in the same paragraph.
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

      final tx = es.transaction;
      tx.insertNode([0], paragraphNode(delta: delta));
      await es.apply(tx);

      es.editorStyle = const EditorStyle.desktop(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 0),
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

      // ── Get the RenderParagraph and its TextPainter ──
      final node = es.getNodeAtPath([0])!;
      final selectable = node.selectable!;
      final RenderParagraph? rp = selectable.getRenderParagraph();
      expect(rp, isNotNull, reason: 'RenderParagraph must be available');
      final tp = rp!.textPainter;

      final textLen = node.delta!.length;

      print('');
      print('══════════════════════════════════════════════════════');
      print('  DIAGNOSTIC: getLineBoundary with mixed fonts');
      print('  Text length: $textLen');
      print('  Max width: 654, padding: 32, firstLineIndent: 30');
      print('  Font: 42px (heading) → 12px (body)');
      print('══════════════════════════════════════════════════════');

      // ── 1. Print line metrics ──
      final numberOfLines = tp.numberOfLines;
      print('\n─── Line Metrics (${numberOfLines} lines) ───');
      for (var i = 0; i < numberOfLines; i++) {
        final lm = tp.lineMetricstAt(i);
        if (lm != null) {
          print(
            '  Line $i: baseline=${lm.baseline.toStringAsFixed(1)}, '
            'height=${lm.height.toStringAsFixed(1)}, '
            'left=${lm.left.toStringAsFixed(1)}, '
            'width=${lm.width.toStringAsFixed(1)}',
          );
        }
      }

      // ── 2. Print line boundaries for key offsets ──
      print('\n─── Line Boundaries ───');
      // Sample several offsets across the text
      final sampleOffsets = <int>[
        0,
        delta.length ~/ 4,
        delta.length ~/ 2,
        delta.length * 3 ~/ 4,
        delta.length,
      ];
      for (final off in sampleOffsets) {
        final clamped = off.clamp(0, textLen);
        final tpOffset = clamped + (selectable as dynamic).textShift as int;
        final lineRange = tp.getLineBoundary(TextPosition(offset: tpOffset));
        final lineNum = tp.getLineNumberAt(tpOffset);
        final caretOffset =
            tp.getOffsetForCaret(TextPosition(offset: tpOffset), Rect.zero);
        final lineHeight =
            tp.getFullHeightForCaret(TextPosition(offset: tpOffset), Rect.zero);
        print(
          '  editorOffset=$clamped → TextPainter.offset=$tpOffset: '
          'line=$lineNum, '
          'range=[${lineRange.start}, ${lineRange.end}), '
          'caret=(${caretOffset.dx.toStringAsFixed(1)},${caretOffset.dy.toStringAsFixed(1)}), '
          'lineHeight=${lineHeight.toStringAsFixed(1)}',
        );
      }

      // ── 3. TEST: walk from the last offset upward using getLineBoundary ──
      print('\n─── Walking UP from last offset using getLineBoundary ───');
      final textShift = (selectable as dynamic).textShift as int;
      var currentOffset = textLen;
      final walkOffsets = <int>[currentOffset];

      for (var step = 0; step < 10; step++) {
        final tpCurrent = currentOffset + textShift;

        // Get current line
        final currentLine = tp.getLineBoundary(TextPosition(offset: tpCurrent));
        if (currentLine.start <= textShift) {
          print(
              '  Step $step: at first line (start=${currentLine.start}), stop.');
          break;
        }

        // Get previous line
        final prevLine =
            tp.getLineBoundary(TextPosition(offset: currentLine.start - 1));

        // Get caret of first character of previous line
        final prevCaret = tp.getOffsetForCaret(
            TextPosition(offset: prevLine.start), Rect.zero);

        // Get caret of current position to preserve dx
        final currentCaret =
            tp.getOffsetForCaret(TextPosition(offset: tpCurrent), Rect.zero);

        // Target: same dx, previous line's caret dy
        final target = Offset(currentCaret.dx, prevCaret.dy);
        final newPos = tp.getPositionForOffset(target);
        final newOffset = (newPos.offset - textShift).clamp(0, textLen);

        final delta2 = currentOffset - newOffset;
        final prevLineHeight = tp.getFullHeightForCaret(
            TextPosition(offset: prevLine.start), Rect.zero);

        print(
          '  Step $step: $currentOffset → $newOffset '
          '(delta=$delta2 chars), '
          'prevLineHeight=$prevLineHeight, '
          'prevLine=[${prevLine.start}, ${prevLine.end}), '
          'target=(${currentCaret.dx.toStringAsFixed(1)},${prevCaret.dy.toStringAsFixed(1)})',
        );

        if (newOffset >= currentOffset) {
          print('  → stuck, no progress');
          break;
        }
        currentOffset = newOffset;
        walkOffsets.add(currentOffset);
      }

      print('\n  Full walk: ${walkOffsets.join(" → ")}');

      // ── 4. CONTRAST: walk using current moveVerticallyInText ──
      print('\n─── Walking UP using current moveVerticallyInText ───');
      final currentOffsets = <int>[textLen];
      var cur2 = textLen;
      for (var step = 0; step < 10; step++) {
        final result = selectable.moveVerticallyInText(cur2, true);
        if (result == null) {
          print('  Step $step: null (boundary)');
          break;
        }
        print(
          '  Step $step: $cur2 → ${result.offset} '
          '(delta=${cur2 - result.offset} chars)',
        );
        if (result.offset >= cur2) break;
        cur2 = result.offset;
        currentOffsets.add(cur2);
      }
      print('\n  Current walk: ${currentOffsets.join(" → ")}');

      // ── 5. Assert: getLineBoundary walk must not have massive jumps ──
      for (var i = 1; i < walkOffsets.length; i++) {
        final diff = walkOffsets[i - 1] - walkOffsets[i];
        expect(
          diff,
          lessThan(200),
          reason:
              'Step $i: jump of $diff chars is too large — getLineBoundary failed',
        );
      }

      print('\n══════════════════════════════════════════════════════');
      print('  DIAGNOSTIC COMPLETE');
      print('══════════════════════════════════════════════════════');
    });
  });
}
