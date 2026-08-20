// Tests for `EditorStateSelection.getVisibleNodes` (in
// `lib/src/editor/editor_component/service/selection/shared.dart`).
//
// Two layers are covered:
//  1. Integration: a real editor (via `TestableEditor`) whose visible range is
//     populated by the scroll-position pipeline, verifying `getVisibleNodes`
//     returns exactly the document children in the reported range.
//  2. Deterministic mapping: the pure range -> nodes logic, including the
//     `max(min - 1, 0)` leading-edge clamp and the invalid-range early return.

import 'dart:math' as math;

import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/selection/shared.dart';
import 'package:novident_editor/src/flutter/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../infra/testable_editor.dart';
import '../../util/document_util.dart';

void main() {
  group('EditorStateSelection.getVisibleNodes', () {
    group('with a real editor (integration)', () {
      testWidgets(
        'returns the document children matching the visible range',
        (tester) async {
          final editor = tester.editor;
          for (var i = 0; i < 40; i++) {
            editor.addParagraph(initialText: 'Paragraph $i');
          }
          await editor.startTesting();
          await tester.pumpAndSettle();

          final scrollController = _readScrollController(tester);
          final (min, max) = scrollController.visibleRangeNotifier.value;
          expect(min, greaterThanOrEqualTo(0),
              reason: 'visible range must be populated after layout',);
          expect(max, greaterThanOrEqualTo(min));

          final visibleNodes =
              editor.editorState.getVisibleNodes(scrollController);
          final start = math.max(min - 1, 0);
          final expected =
              editor.document.root.children.sublist(start, max + 1);

          expect(visibleNodes, isNotEmpty);
          _expectSameNodes(visibleNodes, expected);
        },
      );

      testWidgets(
        'returns the last nodes after scrolling to the bottom',
        (tester) async {
          final editor = tester.editor;
          for (var i = 0; i < 100; i++) {
            editor.addParagraph(initialText: 'Paragraph $i');
          }
          await editor.startTesting();
          await tester.pumpAndSettle();

          final scrollController = _readScrollController(tester);
          final before = editor.editorState.getVisibleNodes(scrollController);

          scrollController.jumpToBottom();
          await tester.pumpAndSettle();

          final after = editor.editorState.getVisibleNodes(scrollController);
          final (min, max) = scrollController.visibleRangeNotifier.value;

          expect(after, isNotEmpty);
          // The visible window moved towards the end of the document.
          final beforeIndex =
              editor.document.root.children.indexOf(before.first);
          final afterIndex = editor.document.root.children.indexOf(after.first);
          expect(afterIndex, greaterThan(beforeIndex));
          // The range -> nodes mapping still holds after scrolling.
          final start = math.max(min - 1, 0);
          _expectSameNodes(
            after,
            editor.document.root.children.sublist(start, max + 1),
          );
        },
      );
    });

    group('mapping logic (deterministic)', () {
      late EditorState editorState;
      late EditorScrollController controller;

      setUp(() {
        editorState = EditorState.blank(withInitialText: false);
        editorState.document.addParagraphs(10, initialText: 'P');
        controller = EditorScrollController(
          editorState: editorState,
          shrinkWrap: true,
        );
      });

      tearDown(() {
        controller.dispose();
        editorState.dispose();
      });

      test('returns empty when the range is invalid', () {
        controller.visibleRangeNotifier.value = (-1, -1);
        expect(editorState.getVisibleNodes(controller), isEmpty);
      });

      test('returns a single node for a collapsed range at the start', () {
        controller.visibleRangeNotifier.value = (0, 0);
        final nodes = editorState.getVisibleNodes(controller);
        expect(nodes.length, 1);
        expect(
          identical(nodes.single, editorState.document.root.children[0]),
          isTrue,
        );
      });

      test('includes one node before the visible range (min - 1 buffer)', () {
        controller.visibleRangeNotifier.value = (3, 3);
        _expectSameNodes(
          editorState.getVisibleNodes(controller),
          editorState.document.root.children.sublist(2, 4),
        );
      });

      test('returns the slice from max(min - 1, 0) to max', () {
        controller.visibleRangeNotifier.value = (2, 5);
        _expectSameNodes(
          editorState.getVisibleNodes(controller),
          editorState.document.root.children.sublist(1, 6),
        );
      });

      test('clamps min - 1 to 0', () {
        controller.visibleRangeNotifier.value = (0, 4);
        _expectSameNodes(
          editorState.getVisibleNodes(controller),
          editorState.document.root.children.sublist(0, 5),
        );
      });

      test('returns all children for the full range', () {
        controller.visibleRangeNotifier.value = (0, 9);
        _expectSameNodes(
          editorState.getVisibleNodes(controller),
          editorState.document.root.children,
        );
      });
    });
  });
}

/// Reads the [EditorScrollController] that the pumped editor provides to its
/// descendants via [ScrollServiceWidget]. The provider sits above the
/// [ScrollablePositionedList], so reading from that widget's context resolves
/// it.
EditorScrollController _readScrollController(WidgetTester tester) {
  final context = tester.element(find.byType(ScrollablePositionedList));
  return context.read<EditorScrollController>();
}

/// Asserts that [actual] and [expected] contain the same [Node] instances in
/// the same order (identity, not value, equality).
void _expectSameNodes(List<Node> actual, List<Node> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    expect(
      identical(actual[i], expected[i]),
      isTrue,
      reason:
          'node at index $i must be the same instance as the document child',
    );
  }
}
