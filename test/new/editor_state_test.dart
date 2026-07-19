import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorState.selectionRects cache', () {
    EditorState buildEditor() {
      final document = Document.blank()
        ..insert(
          [0],
          [
            paragraphNode(text: 'line one'),
            paragraphNode(text: 'line two'),
            paragraphNode(text: 'line three'),
          ],
        );
      return EditorState(document: document)
        ..editorStyle = const EditorStyle.desktop();
    }

    test('returns the same list instance on repeated calls', () {
      final editor = buildEditor();
      editor.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 2)),
        reason: SelectionUpdateReason.uiEvent,
      );

      final first = editor.selectionRects();
      for (var i = 0; i < 10; i++) {
        expect(identical(editor.selectionRects(), first), true);
      }

      editor.dispose();
    });

    test('invalidates when the selection changes', () {
      final editor = buildEditor();
      editor.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 2)),
        reason: SelectionUpdateReason.uiEvent,
      );

      final first = editor.selectionRects();
      editor.updateSelectionWithReason(
        Selection.collapsed(Position(path: [1], offset: 2)),
        reason: SelectionUpdateReason.uiEvent,
      );
      final second = editor.selectionRects();
      expect(identical(second, first), false);

      editor.dispose();
    });
  });
}
