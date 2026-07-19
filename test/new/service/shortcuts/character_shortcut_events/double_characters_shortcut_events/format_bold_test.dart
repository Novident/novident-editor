import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../util/util.dart';

void main() async {
  group('format the text to bold', () {
    group('by wrapping with double asterisks', () {
      // Before
      // **Novident*|
      // After
      // [bold]Novident
      test('**Novident** to bold Novident', () async {
        const text = 'Novident';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('**$text*'),
        );

        final editorState = EditorState(document: document);

        // add cursor in the end of the text
        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length + 3),
        );
        editorState.selection = selection;
        //run targeted CharacterShortcutEvent = mock adding a * in the end of the text
        final result = await formatDoubleAsterisksToBold.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
        expect(after.delta!.toList()[0].attributes, {'bold': true});
      });

      // Before
      // App**Flowy*|
      // After
      // App[bold]Flowy
      test('App**Flowy** to App[bold]Flowy', () async {
        const text1 = 'App';
        const text2 = 'Flowy';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('$text1**$text2*'),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text1.length + text2.length + 3),
        );
        editorState.selection = selection;

        final result = await formatDoubleAsterisksToBold.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), '$text1$text2');
        expect(after.delta!.toList()[0].attributes, null);
        expect(after.delta!.toList()[1].attributes, {'bold': true});
      });

      // Before
      // ***Novident*|
      // After
      // *[bold]Novident
      test('***Novident** to *[bold]Novident', () async {
        const text1 = '*';
        const text2 = 'Novident';

        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('**$text1$text2*'),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text1.length + text2.length + 3),
        );
        editorState.selection = selection;

        final result = await formatDoubleAsterisksToBold.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;

        expect(after.delta!.toPlainText(), text1 + text2);
        expect(after.delta!.toList()[0].attributes, null);
        expect(after.delta!.toList()[1].attributes, {'bold': true});
      });

      test('**** nothing changes', () async {
        const text = '***`';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert(text),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length),
        );
        editorState.selection = selection;

        final result = await formatDoubleAsterisksToBold.execute(editorState);

        expect(result, false);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
      });
    });

    group('by wrapping with double underscores', () {
      // Before
      // __Novident_|
      // After
      // [bold]Novident
      test('__Novident__ to bold Novident', () async {
        const text = 'Novident';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('__${text}_'),
        );

        final editorState = EditorState(document: document);

        // add cursor in the end of the text
        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length + 3),
        );
        editorState.selection = selection;
        //run targeted CharacterShortcutEvent = mock adding a _ in the end of the text
        final result = await formatDoubleUnderscoresToBold.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
        expect(after.delta!.toList()[0].attributes, {'bold': true});
      });

      // Before
      // App__Flowy_|
      // After
      // App[bold]Flowy
      test('App__Flowy__ to App[bold]Flowy', () async {
        const text1 = 'App';
        const text2 = 'Flowy';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('${text1}__${text2}_'),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text1.length + text2.length + 3),
        );
        editorState.selection = selection;

        final result = await formatDoubleUnderscoresToBold.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), '$text1$text2');
        expect(after.delta!.toList()[0].attributes, null);
        expect(after.delta!.toList()[1].attributes, {'bold': true});
      });

      // Before
      // ___Novident_|
      // After
      // _[bold]Novident
      test('___Novident__ to _[bold]Novident', () async {
        const text1 = '_';
        const text2 = 'Novident';

        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert('__$text1${text2}_'),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text1.length + text2.length + 3),
        );
        editorState.selection = selection;

        final result = await formatDoubleUnderscoresToBold.execute(editorState);

        expect(result, true);
        final after = editorState.getNodeAtPath([0])!;

        expect(after.delta!.toPlainText(), text1 + text2);
        expect(after.delta!.toList()[0].attributes, null);
        expect(after.delta!.toList()[1].attributes, {'bold': true});
      });

      test('____ nothing changes', () async {
        const text = '___`';
        final document = Document.blank().addParagraphs(
          1,
          builder: (index) => Delta()..insert(text),
        );

        final editorState = EditorState(document: document);

        final selection = Selection.collapsed(
          Position(path: [0], offset: text.length),
        );
        editorState.selection = selection;

        final result = await formatDoubleUnderscoresToBold.execute(editorState);

        expect(result, false);
        final after = editorState.getNodeAtPath([0])!;
        expect(after.delta!.toPlainText(), text);
      });
    });
  });
}
