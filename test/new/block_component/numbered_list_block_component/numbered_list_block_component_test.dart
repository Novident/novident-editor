import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/testable_editor.dart';
import '../../util/editor_text_finders.dart';

void main() async {
  group('numbered list component', () {
    const text = 'Welcome to Novident Editor 🔥!';
    // 100. Welcome to Novident Editor 🔥!
    // 101. Welcome to Novident Editor 🔥!
    // 102. Welcome to Novident Editor 🔥!
    testWidgets('the number of the numbered list should be ascending',
        (tester) async {
      final editor = tester.editor
        ..addNode(
          numberedListNode(delta: Delta()..insert(text), number: 100),
        )
        ..addNode(
          numberedListNode(delta: Delta()..insert(text)),
        )
        ..addNode(
          numberedListNode(delta: Delta()..insert(text), number: 200),
        );
      await editor.startTesting();

      expect(findEditorRichText('100.'), findsOneWidget);
      expect(findEditorRichText('101.'), findsOneWidget);
      expect(findEditorRichText('102.'), findsOneWidget);
      expect(findEditorRichText('200.'), findsNothing);

      await editor.dispose();
    });

    // Before
    // | <- insert new numbered list here
    // 100. Welcome to Novident Editor 🔥!
    // 101. Welcome to Novident Editor 🔥!
    // After
    // 1. Welcome to Novident Editor 🔥!
    // 2. Welcome to Novident Editor 🔥!
    // 3. Welcome to Novident Editor 🔥!
    testWidgets(
        'insert a new numbered list before the existing one, and the number should keep ascending',
        (tester) async {
      final editor = tester.editor
        ..addParagraph(initialText: text)
        ..addNode(
          numberedListNode(delta: Delta()..insert(text), number: 100),
        )
        ..addNode(
          numberedListNode(delta: Delta()..insert(text)),
        );
      await editor.startTesting();

      expect(findEditorRichText('100.'), findsOneWidget);
      expect(findEditorRichText('101.'), findsOneWidget);

      final selection = Selection.collapsed(Position(path: [0]));
      await editor.updateSelection(selection);

      await editor.ime.typeText('1.');
      await editor.ime.typeText(' ');

      expect(editor.nodeAtPath([0])!.type, NumberedListBlockKeys.type);
      expect(findEditorRichText('1.'), findsOneWidget);
      expect(findEditorRichText('2.'), findsOneWidget);
      expect(findEditorRichText('3.'), findsOneWidget);
      expect(findEditorRichText('100.'), findsNothing);
      expect(findEditorRichText('101.'), findsNothing);

      await editor.dispose();
    });

    // Before
    // 1. Welcome to Novident Editor 🔥!
    // | <- delete this line
    // 100. Welcome to Novident Editor 🔥!
    // 101. Welcome to Novident Editor 🔥!
    // After
    // 1. Welcome to Novident Editor 🔥!
    // 2. Welcome to Novident Editor 🔥!
    // 3. Welcome to Novident Editor 🔥!
    testWidgets(
        'delete the paragraph between two group of numbered lists, and the number of the following numbered list should keep ascending',
        (tester) async {
      final editor = tester.editor
        ..addNode(
          numberedListNode(delta: Delta()..insert(text), number: 1),
        )
        ..addEmptyParagraph()
        ..addNode(
          numberedListNode(delta: Delta()..insert(text), number: 100),
        )
        ..addNode(
          numberedListNode(delta: Delta()..insert(text)),
        );
      await editor.startTesting();

      expect(findEditorRichText('1.'), findsOneWidget);
      expect(findEditorRichText('100.'), findsOneWidget);
      expect(findEditorRichText('101.'), findsOneWidget);

      final selection = Selection.collapsed(Position(path: [1]));
      await editor.updateSelection(selection);

      await editor.pressKey(key: LogicalKeyboardKey.backspace);

      expect(editor.documentRootLen, 3);
      expect(findEditorRichText('1.'), findsOneWidget);
      expect(findEditorRichText('2.'), findsOneWidget);
      expect(findEditorRichText('3.'), findsOneWidget);
      expect(findEditorRichText('100.'), findsNothing);
      expect(findEditorRichText('101.'), findsNothing);

      await editor.ime.typeText('\n');
      await editor.ime.typeText('\n');
      // Each Enter inserts one paragraph node: [1.][para][para][100.][101.].
      expect(editor.documentRootLen, 5);
      expect(findEditorRichText('1.'), findsOneWidget);
      expect(findEditorRichText('2.'), findsNothing);
      expect(findEditorRichText('3.'), findsNothing);
      expect(findEditorRichText('100.'), findsOneWidget);
      expect(findEditorRichText('101.'), findsOneWidget);

      await editor.dispose();
    });

    testWidgets('number, latin and roman', (tester) async {
      final delta = Delta()..insert(text);
      final editor = tester.editor
        ..addNode(
          // 1.
          numberedListNode(
            delta: delta,
            children: [
              // a.
              numberedListNode(
                delta: delta,
                children: [
                  numberedListNode(delta: delta), // Ⅰ.
                  numberedListNode(delta: delta), // ⅠⅠ.
                  numberedListNode(delta: delta), // ⅠⅠⅠ.
                ],
              ),
              // b.
              numberedListNode(
                delta: delta,
                children: [
                  numberedListNode(delta: delta), // Ⅰ.
                  numberedListNode(delta: delta), // ⅠⅠ.
                  numberedListNode(delta: delta), // ⅠⅠⅠ.
                ],
              ),
            ],
          ),
        )
        ..addNode(
          // 2.
          numberedListNode(
            delta: delta,
          ),
        );

      await editor.startTesting();
      for (final number in ['1.', '2.']) {
        expect(findEditorRichText(number), findsOneWidget);
      }
      for (final latin in ['a.', 'b.']) {
        expect(findEditorRichText(latin), findsOneWidget);
      }
      for (final roman in ['I.', 'II.', 'III.']) {
        expect(findEditorRichText(roman), findsNWidgets(2));
      }
    });
  });
}
