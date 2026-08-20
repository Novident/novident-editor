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

    // selectionRects() is computed fresh on every call (global coords
    // depend on the scroll offset, so caching would go stale during scroll
    // animations). The invalidate test below documents that the values are
    // recomputed after the selection changes.
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

  group('EditorState.refreshSelection', () {
    EditorState buildEditor() {
      final document = Document.blank()
        ..insert(
          [0],
          [paragraphNode(text: 'refresh me')],
        );
      return EditorState(document: document)
        ..editorStyle = const EditorStyle.desktop();
    }

    test('notifies selection listeners without changing the selection', () {
      final editor = buildEditor();
      final selection = Selection.collapsed(
        Position(path: [0], offset: 2),
      );
      editor.selection = selection;

      var notifications = 0;
      editor.selectionNotifier.addListener(() => notifications++);

      // refreshSelection delivers a notification wave without touching the
      // value, the renderer or the update pipeline.
      editor.refreshSelection();
      expect(notifications, 1);
      editor.refreshSelection();
      expect(notifications, 2);

      // The value itself is untouched.
      expect(editor.selection, equals(selection));

      editor.dispose();
    });
  });
}
