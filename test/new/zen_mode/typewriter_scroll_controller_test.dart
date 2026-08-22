import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../util/node_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TypewriterScrollController', () {
    test('shouldDisableNativeAutoScroll reflects editorState.typewriter', () {
      final state = EditorState(document: Document.blank());
      final controller = TypewriterScrollController();
      controller.attach(editorState: state);

      expect(controller.shouldDisableNativeAutoScroll, isTrue);

      state.typewriter = const TypewriterScrollConfig(enabled: false);
      expect(controller.shouldDisableNativeAutoScroll, isFalse);

      controller.detach();
    });

    test('detach clears the binding', () {
      final state = EditorState(document: Document.blank());
      final controller = TypewriterScrollController();
      controller.attach(editorState: state);
      controller.detach();
      expect(controller.shouldDisableNativeAutoScroll, isFalse);
    });

    test('centerBlockAt without attach is a no-op', () {
      final controller = TypewriterScrollController();
      expect(() => controller.centerBlockAt(0), returnsNormally);
    });

    test('selection changes do not crash when typewriter is disabled', () async {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(3);
      state.typewriter = const TypewriterScrollConfig(enabled: false);
      final controller = TypewriterScrollController();
      controller.attach(editorState: state);

      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [2])),
      );
      expect(controller.shouldDisableNativeAutoScroll, isFalse);
      controller.detach();
    });

    test('selection changes with typewriter enabled do not crash', () async {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(3);
      final controller = TypewriterScrollController();
      controller.attach(editorState: state);

      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [2])),
      );
      expect(controller.shouldDisableNativeAutoScroll, isTrue);
      controller.detach();
    });
  });
}