import 'dart:io';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infra/testable_editor.dart';
import '../../../util/util.dart';

// single | means the cursor
// double | means the selection
void main() async {
  group('arrowRight - widget test', () {
    const text = 'Welcome to Novident Editor 🔥!';

    // Before
    // Welcome to Novident Editor 🔥!|
    // After
    // Welcome to Novident Editor 🔥!|
    testWidgets('press the right arrow key at the ending of the document',
        (tester) async {
      final arrowLeftTest = ArrowTest(
        text: text,
        initialSel: Selection.collapsed(
          Position(path: [0], offset: text.length),
        ),
        expSel: Selection.collapsed(
          Position(path: [0], offset: text.length),
        ),
      );

      await runArrowRightTest(tester, arrowLeftTest);
    });

    // Before
    // |Welcome| to Novident Editor 🔥!
    // After
    // Welcome| to Novident Editor 🔥!
    testWidgets('press the right arrow key at the collapsed selection',
        (tester) async {
      final selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: 'Welcome'.length,
      );
      final arrowLeftTest = ArrowTest(
        text: text,
        initialSel: selection,
        expSel: selection.collapse(atStart: false),
      );

      await runArrowRightTest(tester, arrowLeftTest);
    });

    // Before
    // Welcome to Novident Editor 🔥!
    // Welcome to Novident Editor 🔥!|
    // After
    // |Welcome to Novident Editor 🔥!
    // Welcome to Novident Editor 🔥!
    testWidgets(
        'press the right arrow key until it reaches the ending of the document',
        (tester) async {
      final editor = tester.editor
        ..addParagraphs(
          2,
          initialText: text,
        );
      await editor.startTesting();

      final selection = Selection.collapsed(Position(path: [0]));
      await editor.updateSelection(selection);

      // move the cursor to the ending of node 0
      for (var i = 1; i < text.length; i++) {
        await editor.pressKey(key: LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(
        editor.selection,
        Selection.collapsed(Position(path: [0], offset: text.length)),
      );

      // move the cursor to the beginning of node 1
      await editor.pressKey(key: LogicalKeyboardKey.arrowRight);
      expect(editor.selection, Selection.collapsed(Position(path: [1])));

      // move the cursor to the ending of node 1
      for (var i = 1; i < text.length; i++) {
        await editor.pressKey(key: LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(
        editor.selection,
        Selection.collapsed(Position(path: [1], offset: text.length)),
      );

      await editor.dispose();
    });

    testWidgets('rtl text', (tester) async {
      final List<ArrowTest> tests = [
        ArrowTest(
          text: 'به ویرایشگر Novident خوش آمدید 🔥!',
          decorator: (i, n) => n.updateAttributes({
            blockComponentTextDirection: blockComponentTextDirectionRTL,
          }),
          initialSel: Selection.collapsed(Position(path: [0])),
          expSel: Selection.collapsed(Position(path: [0])),
        ),
        ArrowTest(
          text: 'به ویرایشگر Novident خوش آمدید 🔥!',
          decorator: (i, n) => n.updateAttributes({
            blockComponentTextDirection: blockComponentTextDirectionRTL,
          }),
          initialSel: Selection.single(
            path: [0],
            startOffset: 0,
            endOffset: 'به ویرایشگ'.length,
          ),
          expSel: Selection.collapsed(Position(path: [0])),
        ),
      ];

      for (var i = 0; i < tests.length; i++) {
        await runArrowRightTest(
          tester,
          tests[i],
          "Test $i: text='${tests[i].text}'",
        );
      }
    });

    // Before
    // Welcom|e to Novident Editor 🔥!
    // After
    // Welcom|e| to Novident Editor 🔥!
    testWidgets('press shift + arrow right to select right character',
        (tester) async {
      final editor = tester.editor
        ..addParagraph(
          initialText: text,
        );
      await editor.startTesting();

      const initialOffset = 'Welcom'.length;
      final selection =
          Selection.collapsed(Position(path: [0], offset: initialOffset));
      await editor.updateSelection(selection);

      await editor.pressKey(
        key: LogicalKeyboardKey.arrowRight,
        isShiftPressed: true,
      );

      expect(
        editor.selection,
        Selection.single(
          path: [0],
          startOffset: initialOffset,
          endOffset: initialOffset + 1,
        ),
      );

      await editor.dispose();
    });

    // Before
    // |Welcome to Novident Editor 🔥!
    // After on Mac
    // Welcome to Novident Editor 🔥!|
    // After on Windows & Linux
    // Welcome| to Novident Editor 🔥!
    testWidgets('''press the ctrl+arrow right key,
         on windows & linux it should move to the end of a word,
         on mac it should move the cursor to the end of the line
         ''', (tester) async {
      final editor = tester.editor
        ..addParagraphs(
          2,
          initialText: text,
        );
      await editor.startTesting();

      final selection = Selection.collapsed(Position(path: [1]));
      await editor.updateSelection(selection);

      await editor.pressKey(
        key: LogicalKeyboardKey.arrowRight,
        isControlPressed: Platform.isWindows || Platform.isLinux,
        isMetaPressed: Platform.isMacOS,
      );

      const expectedOffset = 'Welcome'.length;
      final expectedPosition = Position(
        path: [1],
        offset: Platform.isMacOS ? text.length : expectedOffset,
      );

      expect(
        editor.selection,
        Selection.collapsed(expectedPosition),
      );

      await editor.dispose();
    });

    // Before
    // |Welcome to Novident Editor 🔥!
    // After on Mac
    // |Welcome to Novident Editor 🔥!|
    // After on Windows & Linux
    // |Welcome| to Novident Editor 🔥!
    testWidgets('''press the ctrl+shift+arrow right key,
         on windows & linux it should move to the end of a word and select it,
         on mac it should move the cursor to the end of the line and select it
         ''', (tester) async {
      final editor = tester.editor
        ..addParagraphs(
          2,
          initialText: text,
        );
      await editor.startTesting();

      final selection = Selection.collapsed(Position(path: [1]));
      await editor.updateSelection(selection);

      await editor.pressKey(
        key: LogicalKeyboardKey.arrowRight,
        isControlPressed: Platform.isWindows || Platform.isLinux,
        isMetaPressed: Platform.isMacOS,
        isShiftPressed: true,
      );

      const expectedOffset = 'Welcome'.length;
      if (Platform.isMacOS) {
        expect(
          editor.selection,
          Selection.single(
            path: [1],
            startOffset: 0,
            endOffset: text.length,
          ),
        );
      } else {
        expect(
          editor.selection,
          Selection.single(
            path: [1],
            startOffset: 0,
            endOffset: expectedOffset,
          ),
        );
      }

      await editor.dispose();
    });
  });
}
