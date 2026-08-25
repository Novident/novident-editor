import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../util/node_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenModeController._refreshBlocks', () {
    test('notifies only the visible nodes when the range is initialized', () {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(10);
      final scrollController = EditorScrollController(editorState: state);
      final controller = ZenModeController();
      controller.attach(
        editorState: state,
        scrollController: scrollController,
      );

      final notified = <int>[];
      for (var i = 0; i < state.document.root.children.length; i++) {
        state.document.root.children[i].addListener(() => notified.add(i));
      }

      // visible range (2,5) → getVisibleNodes returns indices 1..5.
      scrollController.visibleRangeNotifier.value = (2, 5);
      controller.configuration = const ZenModeConfiguration(
        ignoreTextColor: false,
      );

      expect(notified, [1, 2, 3, 4, 5]);
      controller.dispose();
      scrollController.dispose();
    });

    test('falls back to a platform window when the range is empty', () {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(10);
      final scrollController = EditorScrollController(editorState: state);
      final controller = ZenModeController();
      controller.attach(
        editorState: state,
        scrollController: scrollController,
      );

      final notified = <int>[];
      for (var i = 0; i < state.document.root.children.length; i++) {
        state.document.root.children[i].addListener(() => notified.add(i));
      }

      // range not initialized (-1,-1) → fallback notifies the first window.
      controller.configuration = const ZenModeConfiguration(
        ignoreTextColor: false,
      );

      expect(notified, hasLength(10));
      controller.dispose();
      scrollController.dispose();
    });

    test('fallback window is centered on the focused block (mobile)', () async {
      EditorPlatform.override = const EditorPlatformOverride(isMobile: true);
      addTearDown(EditorPlatform.reset);

      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(400);
      final scrollController = EditorScrollController(editorState: state);
      final controller = ZenModeController();
      controller.attach(
        editorState: state,
        scrollController: scrollController,
      );

      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [350])),
      );

      final notified = <int>[];
      for (var i = 0; i < state.document.root.children.length; i++) {
        state.document.root.children[i].addListener(() => notified.add(i));
      }

      controller.configuration = const ZenModeConfiguration(
        ignoreTextColor: false,
      );

      // mobile window 300 centered on 350 → [200, 400).
      expect(notified.first, 200);
      expect(notified.last, 399);
      controller.dispose();
      scrollController.dispose();
    });
  });
}
