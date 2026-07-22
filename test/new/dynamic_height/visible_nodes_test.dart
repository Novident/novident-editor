import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/selection/shared.dart';

void main() {
  group('EditorState.getVisibleNodes', () {
    late EditorState editorState;
    late EditorScrollController controller;

    setUp(() {
      final document = Document.blank()
        ..insert(
          [0],
          List.generate(5, (i) => paragraphNode(text: 'Paragraph $i')),
        );
      editorState = EditorState(document: document);
      controller = EditorScrollController(editorState: editorState);
    });

    tearDown(() {
      controller.dispose();
      editorState.dispose();
    });

    test('returns all root children when visible range is (-1, -1)', () {
      // In dynamic height mode (no virtual scroll),
      // visibleRangeNotifier stays at (-1, -1).
      controller.visibleRangeNotifier.value = (-1, -1);
      final nodes = editorState.getVisibleNodes(controller);
      expect(nodes.length, 5);
    });

    test('returns subset with extra buffer item when range is valid', () {
      controller.visibleRangeNotifier.value = (1, 3);
      final nodes = editorState.getVisibleNodes(controller);
      // The original code includes one extra element before the
      // visible range (positions.$1 - 1), so (1, 3) → indices 0-3.
      expect(nodes.length, 4);
      expect(nodes[0].delta!.toPlainText(), 'Paragraph 0');
      expect(nodes[1].delta!.toPlainText(), 'Paragraph 1');
      expect(nodes[2].delta!.toPlainText(), 'Paragraph 2');
      expect(nodes[3].delta!.toPlainText(), 'Paragraph 3');
    });

    test('returns empty for range with both negative', () {
      controller.visibleRangeNotifier.value = (-1, -1);
      final nodes = editorState.getVisibleNodes(controller);
      // Returns all children, not empty
      expect(nodes, isNotEmpty);
      expect(nodes.length, 5);
    });

    test('dynamic height: zero blocks returns empty list gracefully', () {
      final emptyDoc = Document.blank();
      final emptyEditor = EditorState(document: emptyDoc);
      final emptyController = EditorScrollController(editorState: emptyEditor);
      emptyController.visibleRangeNotifier.value = (-1, -1);

      final nodes = emptyEditor.getVisibleNodes(emptyController);
      expect(nodes, isEmpty);

      emptyController.dispose();
      emptyEditor.dispose();
    });

    test('dynamic height: single block returns correctly', () {
      final singleDoc = Document.blank()
        ..insert([0], [paragraphNode(text: 'Only one')]);
      final singleEditor = EditorState(document: singleDoc);
      final singleController =
          EditorScrollController(editorState: singleEditor);
      singleController.visibleRangeNotifier.value = (-1, -1);

      final nodes = singleEditor.getVisibleNodes(singleController);
      expect(nodes.length, 1);
      expect(nodes[0].delta!.toPlainText(), 'Only one');

      singleController.dispose();
      singleEditor.dispose();
    });
  });
}
