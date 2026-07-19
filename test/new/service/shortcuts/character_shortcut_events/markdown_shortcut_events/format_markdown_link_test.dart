import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../util/util.dart';

void main() async {
  group('format the text in markdown link syntax to appflowy href', () {
    // Before
    // [Novident](appflowy.com|
    // After
    // [href:appflowy.com]Novident
    test('[Novident](appflowy.com) to format Novident as link', () async {
      const text = 'Novident';
      const link = 'appflowy.com';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()..insert('[$text]($link'),
      );

      final editorState = EditorState(document: document);

      // add cursor in the end of the text
      final selection = Selection.collapsed(
        Position(path: [0], offset: '[$text]($link'.length),
      );
      editorState.selection = selection;
      // run targeted CharacterShortcutEvent
      final result = await formatMarkdownLinkToLink.execute(editorState);

      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(after.delta!.toPlainText(), text);
      expect(
        after.delta!.toList()[0].attributes,
        {NovidentRichTextKeys.href: link},
      );
    });

    // Before
    // App[Flowy](flowy.com|
    // After
    // App[href:appflowy.com]Flowy
    test('App[Flowy](appflowy.com) to App[href:appflowy.com]Flowy', () async {
      const text1 = 'App';
      const text2 = '[Flowy](appflowy.com';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()..insert(text1 + text2),
      );

      final editorState = EditorState(document: document);

      final selection = Selection.collapsed(
        Position(path: [0], offset: text1.length + text2.length),
      );
      editorState.selection = selection;

      final result = await formatMarkdownLinkToLink.execute(editorState);

      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(after.delta!.toPlainText(), 'AppFlowy');
      expect(after.delta!.toList()[0].attributes, null);
      expect(
        after.delta!.toList()[1].attributes,
        {NovidentRichTextKeys.href: 'appflowy.com'},
      );
    });

    // Before
    // Novident[](|
    // After
    // Novident[]()|
    test('empty text change nothing', () async {
      const text = 'Novident[](';
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
    // Hello [Novident](appflowy.com World
    // After
    // Hello [Novident](appflowy.com) World
    test('format the text in markdown link syntax to appflowy href', () async {
      const text1 = 'Hello [Novident](appflowy.com';
      const text2 = ' World';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()..insert(text1 + text2),
      );
      final editorState = EditorState(document: document);
      final selection = Selection.collapsed(
        Position(path: [0], offset: text1.length),
      );
      editorState.selection = selection;
      final result = await formatMarkdownLinkToLink.execute(editorState);
      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(
        after.delta!.toJson(),
        [
          {'insert': 'Hello '},
          {
            'insert': 'Novident',
            'attributes': {'href': 'appflowy.com'},
          },
          {'insert': ' World'},
        ],
      );
    });
  });
}
