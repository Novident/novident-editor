import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/clipboard_test.dart';
import '../new/infra/testable_editor.dart';
import '../new/util/editor_text_finders.dart';

void main() async {
  late MockClipboard mockClipboard;
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockClipboard = const MockClipboard(html: null, text: null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
      switch (message.method) {
        case "Clipboard.getData":
          return mockClipboard.getData;
        case "Clipboard.setData":
          final args = message.arguments as Map<String, dynamic>;
          mockClipboard = mockClipboard.copyWith(
            text: args['text'],
          );
      }
      return null;
    });
  });
  group('context menu test', () {
    void rightClickAt(Offset position) {
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(
          position: position,
          buttons: kSecondaryMouseButton,
        ),
      );

      GestureBinding.instance.handlePointerEvent(
        const PointerUpEvent(),
      );
    }

    testWidgets('context menu test', (tester) async {
      const text = 'Welcome to Novident';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      expect(find.byType(ContextMenu), findsNothing);
      await editor.updateSelection(
        Selection.single(path: [0], startOffset: 0, endOffset: text.length),
      );
      final position = tester.getCenter(findEditorRichText(text));
      rightClickAt(position);
      await tester.pumpAndSettle();
      expect(find.byType(ContextMenu), findsOneWidget);
      await editor.dispose();
    });

    testWidgets('context menu copy and paste test', (tester) async {
      const text = 'Welcome to Novident';
      final editor = tester.editor
        ..addParagraph(initialText: text)
        ..addParagraph(initialText: 'Hello');
      await editor.startTesting();
      expect(
        findEditorRichText(text),
        findsOneWidget,
      );
      await editor.updateSelection(
        Selection(
          start: Position(path: [1]),
          end: Position(path: [1], offset: 5),
        ),
      );
      final copiedText =
          editor.editorState.getTextInSelection(editor.selection).join('/n');
      final position = tester.getCenter(findEditorRichText('Hello'));
      rightClickAt(position);
      await tester.pumpAndSettle();
      final copyButton = find.text('Copy');
      expect(copyButton, findsOneWidget);
      await tester.tap(copyButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        findEditorRichText('Welcome to Novident'),
        findsOneWidget,
      );
      final clipBoardData = await NovidentClipboard.getData();
      expect(clipBoardData.text, copiedText);
      await editor.updateSelection(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: 7),
        ),
      );
      final newPosition = tester.getTopLeft(findEditorRichText(text));
      rightClickAt(newPosition);
      await tester.pumpAndSettle();
      final pasteButton = find.text('Paste');
      expect(pasteButton, findsOneWidget);
      await tester.tap(pasteButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        findEditorRichText('Hello to Novident'),
        findsOneWidget,
      );
      await editor.dispose();
    });
  });
}
