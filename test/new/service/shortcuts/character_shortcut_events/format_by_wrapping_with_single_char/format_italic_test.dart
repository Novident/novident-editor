import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../util/util.dart';

void main() async {
  group('format italic', () {
    group('by wrapping with single underscore', () {
      // Before
      // _Novident|
      // After
      // [italic]Novident
      test('_Novident_ to italic Novident', () async {
        const text = 'Novident';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('_$text'),
        );

        final editorState = EditorState(document: document);

        // add cursor in the end of the text
        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length + 1),
        );
        editorState.selection = selection;
        // run targeted CharacterShortcutEvent
        final result = await formatUnderscoreToItalic.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
        expect(after.delta!.toList()[0].attributes, {'italic': true});
      });

      // Before
      // App_Flowy|
      // After
      // App[italic]Flowy
      test('App_Flowy_ to App[italic]Flowy', () async {
        const text1 = 'App';
        const text2 = 'Flowy';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('${text1}_$text2'),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text1.length + text2.length + 1),
        );
        editorState.selection = selection;

        final result = await formatUnderscoreToItalic.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), '$text1$text2');
        expect(after.delta!.toList()[0].attributes, null);
        expect(after.delta!.toList()[1].attributes, {'italic': true});
      });

      // Before
      // Novident_|
      // After
      // Novident__| (last underscore used to trigger the formatUnderscoreToItalic)
      test('__double underscore change nothing', () async {
        const text = 'Novident_';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert(text),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length),
        );
        editorState.selection = selection;

        final result = await formatUnderscoreToItalic.execute(editorState);

        expect(result, false);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
      });
    });

    group('by wrapping with single asterisk', () {
      // Before
      // *Novident|
      // After
      // [italic]Novident
      test('*Novident* to italic Novident', () async {
        const text = 'Novident';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('*$text'),
        );

        final editorState = EditorState(document: document);

        // add cursor in the end of the text
        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length + 1),
        );
        editorState.selection = selection;
        // run targeted CharacterShortcutEvent
        final result = await formatAsteriskToItalic.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
        expect(after.delta!.toList()[0].attributes, {'italic': true});
      });

      // Before
      // App*Flowy|
      // After
      // App[italic]Flowy
      test('App*Flowy* to App[italic]Flowy', () async {
        const text1 = 'App';
        const text2 = 'Flowy';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('$text1*$text2'),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text1.length + text2.length + 1),
        );
        editorState.selection = selection;

        final result = await formatAsteriskToItalic.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        final afterDelta = after.delta!;
        expect(afterDelta.toPlainText(), '$text1$text2');
        final deltaList = afterDelta.toList();
        expect(deltaList.length, 2);
        expect(deltaList[0].attributes, null);
        expect(deltaList[1].attributes, {'italic': true});
      });

      // Before
      // Novident*|
      // After
      // Novident**| (last asterisk used to trigger the formatAsteriskToItalic)
      test('**doule asterisk change nothing', () async {
        const text = 'Novident*';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert(text),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length),
        );
        editorState.selection = selection;

        final result = await formatAsteriskToItalic.execute(editorState);

        expect(result, false);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
      });
    });

    // Before
    // <italic>_Novident</italic>
    // After
    // Novident
    test('remove the format', () async {
      const text = '_Novident';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()
          ..insert(
            text,
            attributes: {
              'italic': true,
            },
          ),
      );

      final editorState = EditorState(document: document);

      final selection = Selection.collapsed(
        Position(path: [0], offset: text.length),
      );
      editorState.selection = selection;

      final result = await formatUnderscoreToItalic.execute(editorState);

      expect(result, true);
      final after = editorState.getNodeAtPath([0])!;
      expect(
        after.delta!.toPlainText(),
        text.substring(1),
      ); // remove the first underscore
      final isItalic =
          after.delta!.everyAttributes((element) => element['italic'] == true);
      expect(
        isItalic,
        false,
      );
    });

    // skip the italic when the text is wrapped with code
    // Before
    // `App_Flowy|`
    // After
    // `App_Flowy_`
    test('skip the italic when the text is wrapped with code', () async {
      const text = 'App_Flowy';
      final document = Document.blank().addParagraphs(
        1,
        builder: (index) => Delta()
          ..insert(
            text,
            attributes: {
              NovidentRichTextKeys.code: true,
            },
          ),
      );
      final editorState = EditorState(document: document);
      final selection = Selection.collapsed(
        Position(path: [0], offset: text.length),
      );
      editorState.selection = selection;

      final result = await formatUnderscoreToItalic.execute(editorState);
      expect(result, false);
      final after = editorState.getNodeAtPath([0])!;
      expect(after.delta!.toPlainText(), text);
      final isItalic = after.delta!.any(
        (element) => element.attributes?[NovidentRichTextKeys.italic] == true,
      );
      expect(isItalic, false);
    });
  });
}
