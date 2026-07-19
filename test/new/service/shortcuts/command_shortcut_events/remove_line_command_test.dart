import 'dart:io';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../infra/testable_editor.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('remove_line_command.dart ', () {
    testWidgets('works properly and deletes a sentence', (tester) async {
      const text = 'Welcome to Novident 😁';
      final editor = tester.editor..addParagraphs(3, initialText: text);

      await editor.startTesting();
      await editor.updateSelection(
        Selection.single(path: [0], startOffset: text.length),
      );
      //Welcome to Novident 😁|

      await editor.pressKey(
        key: LogicalKeyboardKey.backspace,
        isControlPressed: Platform.isWindows || Platform.isLinux,
        isAltPressed: Platform.isWindows || Platform.isLinux,
        isMetaPressed: Platform.isMacOS,
      );

      //fetching all the text that is still on the editor.
      final selection = editor.selection!;
      final node = editor.editorState.getNodeAtPath(selection.end.path)!;

      expect(node.delta!.toPlainText().isEmpty, true);

      await editor.dispose();
    });

    testWidgets('works in the middle of a word', (tester) async {
      const text = 'Welcome to Novident 😁';
      final editor = tester.editor..addParagraph(initialText: text);

      await editor.startTesting();
      await editor.updateSelection(
        Selection.single(path: [0], startOffset: 14),
      );
      //Welcome to App|flowy 😁

      await editor.pressKey(
        key: LogicalKeyboardKey.backspace,
        isControlPressed: Platform.isWindows || Platform.isLinux,
        isAltPressed: Platform.isWindows || Platform.isLinux,
        isMetaPressed: Platform.isMacOS,
      );

      //fetching all the text that is still on the editor.
      final selection = editor.selection!;
      final node = editor.editorState.getNodeAtPath(selection.end.path)!;

      const expectedText = 'flowy 😁';
      expect(node.delta!.toPlainText(), expectedText);

      await editor.dispose();
    });
  });
}
