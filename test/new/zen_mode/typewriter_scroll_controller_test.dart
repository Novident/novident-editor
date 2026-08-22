import 'dart:ui';

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

    test('within-block selection changes do not crash', () async {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(3);
      final controller = TypewriterScrollController();
      controller.attach(editorState: state);

      // first selection centers block 0.
      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
      );
      // moving within the same block exercises the keep-in-view path.
      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 1)),
      );
      expect(controller.shouldDisableNativeAutoScroll, isTrue);
      controller.detach();
    });
  });

  group('TypewriterScrollController.targetOffsetToKeepInView', () {
    const viewportHeight = 600.0;
    const topMargin = 100.0;
    const bottomMargin = 160.0;

    test('returns null when the caret is fully inside the box', () {
      final offset = TypewriterScrollController.targetOffsetToKeepInView(
        caretRect: const Rect.fromLTWH(0, 200, 2, 20),
        viewportHeight: viewportHeight,
        currentOffset: 0,
        topMargin: topMargin,
        bottomMargin: bottomMargin,
      );
      expect(offset, isNull);
    });

    test('scrolls up when the caret is above the top margin', () {
      // caret top is 30px above the top margin → scroll up 30px.
      final offset = TypewriterScrollController.targetOffsetToKeepInView(
        caretRect: const Rect.fromLTWH(0, 70, 2, 20),
        viewportHeight: viewportHeight,
        currentOffset: 500,
        topMargin: topMargin,
        bottomMargin: bottomMargin,
      );
      expect(offset, 500 + 70 - topMargin);
    });

    test('scrolls down when the caret is below the bottom margin', () {
      // caret bottom (450) is 10px past the bottom margin line (440) → scroll
      // down 10px.
      final offset = TypewriterScrollController.targetOffsetToKeepInView(
        caretRect: const Rect.fromLTWH(0, 430, 2, 20),
        viewportHeight: viewportHeight,
        currentOffset: 1000,
        topMargin: topMargin,
        bottomMargin: bottomMargin,
      );
      expect(offset, 1000 + (430 + 20) - (viewportHeight - bottomMargin));
    });

    test('returns null when the caret is exactly at the box boundary', () {
      // caret top exactly at the top margin → no scroll needed.
      final offset = TypewriterScrollController.targetOffsetToKeepInView(
        caretRect: const Rect.fromLTWH(0, topMargin, 2, 20),
        viewportHeight: viewportHeight,
        currentOffset: 0,
        topMargin: topMargin,
        bottomMargin: bottomMargin,
      );
      expect(offset, isNull);
    });
  });
}