import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util/util.dart';
import '../test_character_shortcut.dart';

void main() async {
  group('formatDoubleQuoteToQuote', () {
    const text = 'Welcome to Novident Editor 🔥!';
    // Before
    // >|Welcome to Novident Editor 🔥!
    // After
    // [quote] Welcome to Novident Editor 🔥!
    test('mock inputting a ` ` after the > but not dot', () async {
      testFormatCharacterShortcut(
        formatDoubleQuoteToQuote,
        '"',
        1,
        (result, before, after, editorState) {
          expect(result, true);
          expect(after.delta!.toPlainText(), text);
          expect(after.type, 'quote');
        },
        text: text,
      );
    });

    // Before
    // >W|elcome to Novident Editor 🔥!
    // After
    // >W|elcome to Novident Editor 🔥!
    test('mock inputting a ` ` in the middle of the node', () async {
      testFormatCharacterShortcut(
        formatDoubleQuoteToQuote,
        '"',
        2,
        (result, before, after, editorState) {
          // nothing happens
          expect(result, false);
          expect(before.toJson(), after.toJson());
        },
        text: text,
      );
    });

    // Before
    // Welcome to Novident Editor 🔥!
    // >|Welcome to Novident Editor 🔥!
    // After
    // Welcome to Novident Editor 🔥!
    //[quote] Welcome to Novident Editor 🔥!
    test(
        'mock inputting a ` ` in the middle of the node, and there\'s a other node at the front of it.',
        () async {
      const text = 'Welcome to Novident Editor 🔥!';
      final document = Document.blank()
          .addParagraph(
            initialText: text,
          )
          .addParagraph(
            initialText: '"$text',
          );
      final editorState = EditorState(document: document);

      // Welcome to Novident Editor 🔥!
      // *|Welcome to Novident Editor 🔥!
      final selection = Selection.collapsed(
        Position(path: [1], offset: 1),
      );
      editorState.selection = selection;
      final result = await formatDoubleQuoteToQuote.execute(editorState);
      final after = editorState.getNodeAtPath([1])!;

      // the second line will be formatted as the bulleted list style
      expect(result, true);
      expect(after.type, 'quote');
      expect(after.delta!.toPlainText(), text);
    });
  });
}
