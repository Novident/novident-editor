import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../../../test_helper.dart';
import '../../../util/document_util.dart';

/// Replicates the auto-scroll edge behavior with a **real drag** on the editor,
/// driven through the selection service's pan callbacks (`onPanStart` /
/// `onPanUpdate` / `onPanEnd`) — the same approach as
/// `test/new/zen_mode/mobile_cursor_drag_test.dart`. Driving the callbacks
/// directly (instead of synthesizing a pointer gesture) avoids the
/// `ScrollablePositionedList` gesture arena, which otherwise claims the drag.
///
/// Each drag direction is its own independent test. The invariant under test:
/// **auto-scroll starts BEFORE the finger touches the viewport edge** — as soon
/// as it enters the configured `edgeOffset` band. With `autoScrollEdgeOffset =
/// 100`, dragging the finger to 50px from the edge (inside the 100px band, but
/// not touching it) must already scroll.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const edgeOffset = 80.0;

  void forceMobile() {
    EditorPlatform.override = const EditorPlatformOverride(
      isMobile: true,
      isAndroid: true,
    );
    addTearDown(EditorPlatform.reset);
  }

  Future<EditorScrollController> pumpEditor(
    WidgetTester tester,
    EditorState editorState,
  ) async {
    final scrollController = EditorScrollController(editorState: editorState);
    await tester.buildAndPump(
      NovidentEditor(
        editorState: editorState,
        editorScrollController: scrollController,
        autoScrollEdgeOffset: edgeOffset,
      ),
    );
    return scrollController;
  }

  EditorState tallEditor() {
    final editorState = EditorState(document: Document.blank());
    editorState.document.addParagraph(
      initialText: List.filled(800, 'word').join(' '),
    );
    return editorState;
  }

  testWidgets(
    'drag DOWN: auto-scroll starts before the finger touches the bottom edge',
    (tester) async {
      forceMobile();
      final editorState = tallEditor();
      final scrollController = await pumpEditor(tester, editorState);

      // place the caret at the start so the drag has a selection to extend.
      editorState.service.selectionService.updateSelection(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();

      final viewportHeight =
          tester.getSize(find.byType(NovidentEditor)).height;
      expect(viewportHeight, greaterThan(0));

      final selectionService = editorState.service.selectionService;

      // start the drag on the text, then move the finger to 50px from the
      // bottom edge — inside the 100px band, NOT touching the edge.
      selectionService.onPanStart(
        DragStartDetails(globalPosition: Offset(400, viewportHeight / 2)),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();

      selectionService.onPanUpdate(
        DragUpdateDetails(
          globalPosition: Offset(400, viewportHeight - 50),
          delta: Offset(0, viewportHeight - 50 - viewportHeight / 2),
        ),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final offsetAfterDrag = scrollController.offsetNotifier.value;

      // release to stop the auto-scroll loop.
      selectionService.onPanEnd(
        DragEndDetails(),
        MobileSelectionDragMode.cursor,
      );
      await tester.pumpAndSettle();

      expect(
        offsetAfterDrag,
        greaterThan(0),
        reason:
            'dragging the finger to 50px from the bottom edge (inside the '
            'edgeOffset=80 band) must auto-scroll BEFORE touching the edge',
      );
    },
  );

  testWidgets(
    'drag UP: auto-scroll starts before the finger touches the top edge',
    (tester) async {
      forceMobile();
      final editorState = tallEditor();
      final scrollController = await pumpEditor(tester, editorState);

      // scroll down first so there is room to scroll back up.
      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: length)),
      );
      await tester.pumpAndSettle();
      final offsetAtBottom = scrollController.offsetNotifier.value;
      expect(offsetAtBottom, greaterThan(0));

      final viewportHeight =
          tester.getSize(find.byType(NovidentEditor)).height;

      final selectionService = editorState.service.selectionService;

      // start the drag on the text, then move the finger to 50px from the top
      // edge — inside the 100px band, NOT touching the edge.
      selectionService.onPanStart(
        DragStartDetails(globalPosition: Offset(400, viewportHeight / 2)),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();

      selectionService.onPanUpdate(
        DragUpdateDetails(
          globalPosition: Offset(400, 50),
          delta: Offset(0, 50 - viewportHeight / 2),
        ),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final offsetAfterDrag = scrollController.offsetNotifier.value;

      // release to stop the auto-scroll loop.
      selectionService.onPanEnd(
        DragEndDetails(),
        MobileSelectionDragMode.cursor,
      );
      await tester.pumpAndSettle();

      expect(
        offsetAfterDrag,
        lessThan(offsetAtBottom),
        reason:
            'dragging the finger to 50px from the top edge (inside the '
            'edgeOffset=80 band) must auto-scroll UP BEFORE touching the edge',
      );
    },
  );
}