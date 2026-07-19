import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/util.dart';

void main() async {
  group('allSatisfyInSelection - node', () {
    const welcome = 'Welcome ';
    const toNovident = 'to Novident';
    const editor = ' Editor 🔥!';

    // Welcome <b>|to Novident</b> Editor 🔥!
    test('the selection is collapsed', () async {
      final document = Document.blank().addParagraph(
        builder: (index) => Delta()
          ..insert(welcome)
          ..insert(
            toNovident,
            attributes: {
              'bold': true,
            },
          )
          ..insert(editor),
      );
      final editorState = EditorState(document: document);

      // Welcome |to Novident| Editor 🔥!
      final selection = Selection.collapsed(
        Position(path: [0], offset: welcome.length),
      );
      editorState.selection = selection;
      final node = editorState.getNodeAtPath([0]);
      final result = node!.allSatisfyInSelection(selection, (delta) {
        final textInserts = delta.whereType<TextInsert>();
        return textInserts
            .every((element) => element.attributes?['bold'] == true);
      });
      expect(result, false);
    });

    // Welcome |<b>to Novident</b>| Editor 🔥!
    test('the selection is single and not collapsed - 1', () async {
      final document = Document.blank().addParagraph(
        builder: (index) => Delta()
          ..insert(welcome)
          ..insert(
            toNovident,
            attributes: {
              'bold': true,
            },
          )
          ..insert(editor),
      );
      final editorState = EditorState(document: document);

      // Welcome |to Novident| Editor 🔥!
      final selection = Selection.single(
        path: [0],
        startOffset: welcome.length,
        endOffset: welcome.length + toNovident.length,
      );
      editorState.selection = selection;
      final node = editorState.getNodeAtPath([0]);
      final result = node!.allSatisfyInSelection(selection, (delta) {
        final textInserts = delta.whereType<TextInsert>();
        return textInserts
            .every((element) => element.attributes?['bold'] == true);
      });

      expect(result, true);
    });

    // |Welcome <b>to Novident</b>| Editor 🔥!
    test('the selection is single and not collapsed - 2', () async {
      final document = Document.blank().addParagraph(
        builder: (index) => Delta()
          ..insert(welcome)
          ..insert(
            toNovident,
            attributes: {
              'bold': true,
            },
          )
          ..insert(editor),
      );
      final editorState = EditorState(document: document);

      // Welcome |to Novident| Editor 🔥!
      final selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: welcome.length + toNovident.length,
      );
      editorState.selection = selection;
      final node = editorState.getNodeAtPath([0]);
      final result = node!.allSatisfyInSelection(selection, (delta) {
        final textInserts = delta.whereType<TextInsert>();
        return textInserts
            .every((element) => element.attributes?['bold'] == true);
      });
      expect(result, false);
    });
  });

  group('allSatisfyInSelection - nodes', () {
    const welcome = 'Welcome ';
    const toNovident = 'to Novident';
    const editor = ' Editor 🔥!';

    // Welcome <b>|to Novident Editor 🔥!</b>
    // <b>Welcome to Novident|</b> Editor 🔥!
    test('the selection is not collapsed and not single - 1', () async {
      final document = Document.blank().addParagraph(
        builder: (index) => Delta()
          ..insert(welcome)
          ..insert(
            toNovident + editor,
            attributes: {
              'bold': true,
            },
          ),
      )..addParagraph(
          builder: (index) => Delta()
            ..insert(
              welcome + toNovident,
              attributes: {
                'bold': true,
              },
            )
            ..insert(
              editor,
            ),
        );
      final editorState = EditorState(document: document);

      // Welcome <b>|to Novident Editor 🔥!</b>
      // <b>Welcome to Novident|</b> Editor 🔥!
      final selection = Selection(
        start: Position(path: [0], offset: welcome.length),
        end: Position(path: [1], offset: welcome.length + toNovident.length),
      );
      editorState.selection = selection;
      final nodes = editorState.getNodesInSelection(selection);
      final result = nodes.allSatisfyInSelection(selection, (delta) {
        final textInserts = delta.whereType<TextInsert>();
        return textInserts
            .every((element) => element.attributes?['bold'] == true);
      });
      expect(result, true);
    });

    // |Welcome <b>to Novident Editor 🔥!</b>
    // <b>Welcome to Novident</b> Editor 🔥!|
    test('the selection is not collapsed and not single - 2', () async {
      final document = Document.blank().addParagraph(
        builder: (index) => Delta()
          ..insert(welcome)
          ..insert(
            toNovident + editor,
            attributes: {
              'bold': true,
            },
          ),
      )..addParagraph(
          builder: (index) => Delta()
            ..insert(
              welcome + toNovident,
              attributes: {
                'bold': true,
              },
            )
            ..insert(
              editor,
            ),
        );
      final editorState = EditorState(document: document);

      // |Welcome <b>to Novident Editor 🔥!</b>
      // <b>Welcome to Novident</b> Editor 🔥!|
      final selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(
          path: [1],
          offset: welcome.length + toNovident.length + editor.length,
        ),
      );
      editorState.selection = selection;
      final nodes = editorState.getNodesInSelection(selection);
      final result = nodes.allSatisfyInSelection(selection, (delta) {
        final textInserts = delta.whereType<TextInsert>();
        return textInserts
            .every((element) => element.attributes?['bold'] == true);
      });
      expect(result, false);
    });

    test('2 non-empty nodes with 1 empty node', () {
      final document = Document.blank()
        ..addParagraph(
          builder: (index) => Delta()
            ..insert(
              'Hello',
              attributes: {NovidentRichTextKeys.bold: true},
            ),
        )
        ..addParagraph(
          builder: (index) => Delta(),
        )
        ..addParagraph(
          builder: (index) => Delta()
            ..insert(
              'World',
              attributes: {
                NovidentRichTextKeys.bold: true,
              },
            ),
        );
      final editorState = EditorState(document: document);
      final selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [2], offset: 5),
      );
      final nodes = editorState.getNodesInSelection(selection);
      final isHighlight = nodes.allSatisfyInSelection(
        selection,
        (delta) =>
            delta.isNotEmpty &&
            delta.everyAttributes(
              (attr) => attr[NovidentRichTextKeys.bold] == true,
            ),
      );
      expect(isHighlight, true);
    });
  });
}
