import 'dart:io';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infra/testable_editor.dart';
import '../../../util/util.dart';

// single | means the cursor
// double | means the selection
void main() async {
  setUpAll(() {
    if (kDebugMode) {
      activateLog();
    }
  });

  tearDownAll(() {
    if (kDebugMode) {
      deactivateLog();
    }
  });

  const text = 'Welcome to Novident Editor 🔥!';

  group('remove word commands - widget test', () {
    group('remove the left word ', () {
      // Before
      // |Welcome to Novident Editor 🔥!
      // After
      // |Welcome to Novident Editor 🔥!
      testWidgets('at the start of line', (tester) async {
        final editor = tester.editor
          ..addParagraph(
            initialText: text,
          );
        await editor.startTesting();

        final selection = Selection.collapsed(Position(path: [0]));
        await editor.updateSelection(selection);

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isAltPressed: Platform.isMacOS,
          isControlPressed: Platform.isWindows || Platform.isLinux,
        );
        await tester.pumpAndSettle();

        // the left word should be deleted.
        expect(
          editor.nodeAtPath([0])?.delta?.toPlainText(),
          text,
        );

        await editor.dispose();
      });

      // Before
      // Welcome| to Novident Editor 🔥!
      // After
      // | to Novident Editor 🔥!
      testWidgets('at the end of a word', (tester) async {
        final editor = tester.editor
          ..addParagraph(
            initialText: text,
          );
        await editor.startTesting();

        // Welcome| to Novident Editor 🔥!
        const welcome = 'Welcome';
        final selection =
            Selection.collapsed(Position(path: [0], offset: welcome.length));
        await editor.updateSelection(selection);

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isAltPressed: Platform.isMacOS,
          isControlPressed: Platform.isWindows || Platform.isLinux,
        );
        await tester.pumpAndSettle();

        // the left word should be deleted.
        expect(
          editor.nodeAtPath([0])?.delta?.toPlainText(),
          text.substring(welcome.length),
        );

        await editor.dispose();
      });

      // Before
      // Welcome |to Novident Editor 🔥!
      // After
      // |to Novident Editor 🔥!
      testWidgets('at the end of a word and whitespace', (tester) async {
        final editor = tester.editor
          ..addParagraph(
            initialText: text,
          );
        await editor.startTesting();

        // Welcome |to Novident Editor 🔥!
        const welcome = 'Welcome';
        final selection = Selection.collapsed(
          Position(path: [0], offset: welcome.length + 1),
        );
        await editor.updateSelection(selection);

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isAltPressed: Platform.isMacOS,
          isControlPressed: Platform.isWindows || Platform.isLinux,
        );
        await tester.pumpAndSettle();

        // the left word should be deleted.
        expect(
          editor.nodeAtPath([0])?.delta?.toPlainText(),
          text.substring(welcome.length + 1),
        );

        await editor.dispose();
      });

      testWidgets('repeatedly till line is empty', (tester) async {
        List<String> words = ["Welcome", " ", "to", " ", "Novident", " ", "😁"];
        final text = words.join();
        final editor = tester.editor..addParagraph(initialText: text);

        await editor.startTesting();
        await editor.updateSelection(
          Selection.single(path: [0], startOffset: text.length),
        );

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isControlPressed: Platform.isWindows || Platform.isLinux,
          isAltPressed: Platform.isMacOS,
        );

        //fetching all the text that is still on the editor.
        final selection = editor.selection!;
        assert(selection.isSingle, true);
        var node = editor.nodeAtPath(selection.end.path)!;

        words.removeLast();
        //expected: Welcome_to_Novident_
        //here _ actually represents ' '
        expect(node.delta!.toPlainText(), words.join());

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isControlPressed: Platform.isWindows || Platform.isLinux,
          isAltPressed: Platform.isMacOS,
        );

        //fetching all the text that is still on the editor.
        node = editor.nodeAtPath(selection.end.path)!;

        //removes the whitespace
        words.removeLast();
        words.removeLast();
        //expected is: Welcome_to_
        expect(node.delta!.toPlainText(), words.join());

        //we divide words.length by 2 becuase we know half words are whitespaces.
        for (var i = 0; i < words.length / 2; i++) {
          await editor.pressKey(
            key: LogicalKeyboardKey.backspace,
            isControlPressed: Platform.isWindows || Platform.isLinux,
            isAltPressed: Platform.isMacOS,
          );
        }

        node = editor.nodeAtPath(selection.end.path)!;

        expect(node.delta!.toPlainText(), '');

        await editor.dispose();
      });

      testWidgets('at the middle of a word', (tester) async {
        const text = 'Welcome to Novident 😁';
        final editor = tester.editor..addParagraph(initialText: text);

        await editor.startTesting();
        await editor.updateSelection(
          Selection.single(path: [0], startOffset: 0),
        );

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isControlPressed: Platform.isWindows || Platform.isLinux,
          isAltPressed: Platform.isMacOS,
        );

        //fetching all the text that is still on the editor.
        final selection = editor.selection!;
        var node = editor.editorState.getNodeAtPath(selection.end.path)!;

        //nothing happens when there is no words to the left of the cursor
        expect(node.delta!.toPlainText(), text);

        await editor.updateSelection(
          Selection.single(path: [0], startOffset: 14),
        );
        //Welcome to App|flowy 😁

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isControlPressed: Platform.isWindows || Platform.isLinux,
          isAltPressed: Platform.isMacOS,
        );

        //fetching all the text that is still on the editor.
        node = editor.editorState.getNodeAtPath(selection.end.path)!;

        const expectedText = 'Welcome to flowy 😁';
        expect(node.delta!.toPlainText(), expectedText);

        await editor.dispose();
      });

      testWidgets('works properly with only single whitespace', (tester) async {
        //edge case that checks if pressing ctrl+backspace on null value
        //after removing a whitespace, does not throw an exception.
        const text = ' ';
        final editor = tester.editor..addParagraph(initialText: text);

        await editor.startTesting();

        await editor.updateSelection(
          Selection.single(path: [0], startOffset: text.length),
        );
        // |

        await editor.pressKey(
          key: LogicalKeyboardKey.backspace,
          isControlPressed: Platform.isWindows || Platform.isLinux,
          isAltPressed: Platform.isMacOS,
        );

        //fetching all the text that is still on the editor.
        final selection = editor.selection!;
        final node = editor.editorState.getNodeAtPath(selection.end.path)!;

        expect(node.delta!.toPlainText().isEmpty, true);

        await editor.dispose();
      });
    });

    group('remove the right word ', () {
      // Before
      // Welcome to Novident Editor 🔥!|
      // After
      // Welcome to Novident Editor 🔥!|
      testWidgets('at the end of line', (tester) async {
        final editor = tester.editor
          ..addParagraph(
            initialText: text,
          );
        await editor.startTesting();

        final selection =
            Selection.collapsed(Position(path: [0], offset: text.length));
        await editor.updateSelection(selection);

        await editor.pressKey(
          key: LogicalKeyboardKey.delete,
          isAltPressed: Platform.isMacOS,
          isControlPressed: Platform.isWindows || Platform.isLinux,
        );
        await tester.pumpAndSettle();

        // nothing happens
        expect(
          editor.nodeAtPath([0])?.delta?.toPlainText(),
          text,
        );

        await editor.dispose();
      });

      // Before
      // |Welcome to Novident Editor 🔥!
      // After
      // | to Novident Editor 🔥!
      testWidgets('at the start of a word', (tester) async {
        final editor = tester.editor
          ..addParagraph(
            initialText: text,
          );
        await editor.startTesting();

        // |Welcome to Novident Editor 🔥!
        const welcome = 'Welcome';
        final selection = Selection.collapsed(Position(path: [0]));
        await editor.updateSelection(selection);

        await editor.pressKey(
          key: LogicalKeyboardKey.delete,
          isAltPressed: Platform.isMacOS,
          isControlPressed: Platform.isWindows || Platform.isLinux,
        );
        await tester.pumpAndSettle();

        // the right word should be deleted.
        expect(
          editor.nodeAtPath([0])?.delta?.toPlainText(),
          text.substring(welcome.length),
        );

        await editor.dispose();
      });

      // Before
      // Welcome| to Novident Editor 🔥!
      // After
      // Welcome| Novident Editor 🔥!
      testWidgets('at the end of a word and whitespace', (tester) async {
        final editor = tester.editor
          ..addParagraph(
            initialText: text,
          );
        await editor.startTesting();

        // Welcome| to Novident Editor 🔥!
        const welcome = 'Welcome';
        final selection =
            Selection.collapsed(Position(path: [0], offset: welcome.length));
        await editor.updateSelection(selection);

        await editor.pressKey(
          key: LogicalKeyboardKey.delete,
          isAltPressed: Platform.isMacOS,
          isControlPressed: Platform.isWindows || Platform.isLinux,
        );
        await tester.pumpAndSettle();

        // the right word should be deleted.
        const expectedString = "Welcome Novident Editor 🔥!";
        expect(
          editor.nodeAtPath([0])?.delta?.toPlainText(),
          expectedString,
        );

        await editor.dispose();
      });
    });
  });
}
