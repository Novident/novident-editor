import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../util/util.dart';

void main() async {
  group('format the text surrounded by single tilde to strikethrough', () {
    // Before
    // ~Novident|
    // After
    // [strikethrough]Novident
    test('~Novident~ to strikethrough Novident', () async {
      const text = 'Novident';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()..insert('~$text'),
      );

      final editorState = EditorState(document: document);

      // add cursor in the end of the text
      final selection = Selection.collapsed(
        Position(path: [0], offset: text.length + 1),
      );
      editorState.selection = selection;
      // run targeted CharacterShortcutEvent
      final result = await formatTildeToStrikethrough.execute(editorState);

      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(after.delta!.toPlainText(), text);
      expect(after.delta!.toList()[0].attributes, {'strikethrough': true});
    });

    // Before
    // App~Flowy|
    // After
    // App[strikethrough]Flowy
    test('App~Flowy~ to App[strikethrough]Flowy', () async {
      const text1 = 'App';
      const text2 = 'Flowy';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()..insert('$text1~$text2'),
      );

      final editorState = EditorState(document: document);

      final selection = Selection.collapsed(
        Position(path: [0], offset: text1.length + text2.length + 1),
      );
      editorState.selection = selection;

      final result = await formatTildeToStrikethrough.execute(editorState);

      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(after.delta!.toPlainText(), '$text1$text2');
      expect(after.delta!.toList()[0].attributes, null);
      expect(after.delta!.toList()[1].attributes, {'strikethrough': true});
    });

    // Before
    // Novident~|
    // After
    // Novident~~| (last tilde used to trigger the formatTildeToStrikethrough)
    test('~~ double tilde change nothing', () async {
      const text = 'Novident~';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()..insert(text),
      );

      final editorState = EditorState(document: document);

      final selection = Selection.collapsed(
        Position(path: [0], offset: text.length),
      );
      editorState.selection = selection;

      final result = await formatTildeToStrikethrough.execute(editorState);

      expect(result, false);
      final after = editorState.getNodeAtPath([0])!;
      expect(after.delta!.toPlainText(), text);
    });

    // Before
    // <strikethrough>~Novident</strikethrough>
    // After
    // Novident
    test('remove the format', () async {
      const text = '~Novident';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()
          ..insert(
            text,
            attributes: {
              'strikethrough': true,
            },
          ),
      );

      final editorState = EditorState(document: document);

      final selection = Selection.collapsed(
        Position(path: [0], offset: text.length),
      );
      editorState.selection = selection;

      final result = await formatTildeToStrikethrough.execute(editorState);

      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(
        after.delta!.toPlainText(),
        text.substring(1),
      ); // remove the first underscore
      final isStrikethrough = after.delta!
          .everyAttributes((element) => element['strikethrough'] == true);
      expect(
        isStrikethrough,
        false,
      );
    });
  });
}
