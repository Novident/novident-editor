import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../../../test_helper.dart';
import '../../../util/document_util.dart';

/// Regression tests that freeze the **native** caret auto-scroll behavior
/// (the default edge-follow driven by `ScrollServiceWidget` +
/// `AutoScroller`/`EdgeDraggingAutoScroller`).
///
/// These run with the typewriter DISABLED (no `TypewriterScrollController`
/// attached, `disableAutoScroll` left at its default `false`), so they
/// exercise exactly the behavior that the `DefaultScrollStrategy` must
/// preserve after the scroll-strategy refactor.
///
/// The invariant under test: **when the caret moves out of the visible
/// area, the editor scrolls to bring it back into view.** We assert this
/// through the scroll offset (robust), not through fragile per-pixel caret
/// measurements that depend on layout timing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EditorScrollController> pumpEditor(
    WidgetTester tester,
    EditorState editorState,
  ) async {
    final scrollController = EditorScrollController(editorState: editorState);
    await tester.buildAndPump(
      NovidentEditor(
        editorState: editorState,
        editorScrollController: scrollController,
      ),
    );
    return scrollController;
  }

  testWidgets(
    'native auto-scroll scrolls down when the caret moves below the viewport',
    (tester) async {
      // a single tall block (many wrapped lines) so the caret can move far
      // below the visible area while staying in the same top-level block.
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(tester, editorState);

      // caret at the start -> nothing to scroll.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();
      final offsetAtStart = scrollController.offsetNotifier.value;

      // move the caret to the end of the tall block (far below the viewport).
      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: length)),
      );
      await tester.pumpAndSettle();

      // the editor must have scrolled down to follow the caret.
      expect(
        scrollController.offsetNotifier.value,
        greaterThan(offsetAtStart),
        reason: 'moving the caret below the viewport must scroll down',
      );
    },
  );

  testWidgets(
    'native auto-scroll does not scroll when the caret stays in view',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 5; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpEditor(tester, editorState);

      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();
      final offsetBefore = scrollController.offsetNotifier.value;

      // move the caret within the first block — it stays well inside the
      // viewport, so the editor must not scroll.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 3)),
      );
      await tester.pumpAndSettle();

      expect(
        scrollController.offsetNotifier.value,
        offsetBefore,
        reason: 'a caret that stays in view must not trigger a scroll',
      );
    },
  );

  testWidgets(
    'native auto-scroll scrolls up when the caret moves above the viewport',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(tester, editorState);

      // scroll down to the end of the tall block first.
      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: length)),
      );
      await tester.pumpAndSettle();
      final offsetAtEnd = scrollController.offsetNotifier.value;
      expect(offsetAtEnd, greaterThan(0));

      // move the caret back to the start (now above the viewport).
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();

      // the editor must have scrolled up to bring the caret back into view.
      expect(
        scrollController.offsetNotifier.value,
        lessThan(offsetAtEnd),
        reason: 'moving the caret above the viewport must scroll up',
      );
    },
  );
}