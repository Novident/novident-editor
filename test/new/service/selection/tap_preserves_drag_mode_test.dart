import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../../test_helper.dart';
import '../../util/document_util.dart';

/// Regression test for the "auto-scroll dies mid-drag" bug.
///
/// # The bug
///
/// While the finger is held at the viewport edge during an auto-scroll drag,
/// the *content* scrolls under a *stationary* finger. The `TapGestureRecognizer`
/// therefore wins the gesture arena and fires `onTapUp` (`_onTapUpAndroid`).
/// That handler called `updateSelectionWithReason` **without** `extraInfo`,
/// which reset `selectionExtraInfo[selectionDragModeKey]` to `null`. With the
/// drag mode gone, `_onScrollViewScrolled` stopped scheduling
/// `continueToAutoScroll`, so the auto-scroll converged and died — the user
/// could no longer scroll until forcing a manual scroll.
///
/// # The fix
///
/// `_onTapUpAndroid` (and `_onTapUpIOS`) preserve `selectionDragModeKey` when a
/// drag is already in progress, so a spurious tap-up no longer tears down the
/// auto-scroll.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void forceMobile() {
    EditorPlatform.override = const EditorPlatformOverride(
      isMobile: true,
      isAndroid: true,
    );
    addTearDown(EditorPlatform.reset);
  }

  testWidgets(
    'a tap-up during a cursor drag preserves the drag mode',
    (tester) async {
      forceMobile();

      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 50; i++) {
        editorState.document.addParagraph(initialText: 'line $i');
      }
      final scrollController = EditorScrollController(editorState: editorState);
      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editorScrollController: scrollController,
          editorStyle: EditorStyle.mobile(),
        ),
      );
      await tester.pumpAndSettle();

      editorState.service.selectionService.updateSelection(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();

      final selectionService = editorState.service.selectionService;
      final viewportHeight = tester.getSize(find.byType(NovidentEditor)).height;
      expect(viewportHeight, greaterThan(0));

      // Start a cursor drag and move the finger toward the bottom edge.
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

      // The drag mode is now active.
      expect(
        editorState.selectionDragModeValue(),
        MobileSelectionDragMode.cursor,
      );

      // A spurious tap-up fires during the drag.
      await tester.tap(find.byType(NovidentEditor), warnIfMissed: false);
      await tester.pumpAndSettle();

      // The drag mode must be preserved, otherwise the auto-scroll is torn
      // down by the tap.
      expect(
        editorState.selectionDragModeValue(),
        MobileSelectionDragMode.cursor,
        reason: 'a tap-up during a cursor drag must not reset the drag mode',
      );

      // Clean up the drag.
      selectionService.onPanEnd(
        DragEndDetails(),
        MobileSelectionDragMode.cursor,
      );
      await tester.pumpAndSettle();
    },
  );
}
