import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../../../test_helper.dart';
import '../../../util/document_util.dart';

/// Measures how long the auto-scroll takes to stop after the cursor returns
/// INSIDE the viewport, following a sustained edge drag.
///
/// The bug: hold the finger at the edge so recursive scroll events pile up
/// (~2s). Then drag the cursor back inside the viewport — the auto-scroll
/// should stop almost immediately, but instead it keeps scrolling for a while,
/// proportional to how many events accumulated.
///
/// The scroll ALWAYS stops eventually; the defect is the *latency* — how many
/// frames elapse between "cursor is back inside" and "offset stops advancing".
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
    'measures auto-scroll stop latency after sustained edge drag returns inside',
    (tester) async {
      forceMobile();

      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 2000; i++) {
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

      // Start the drag and hold the finger 5px from the bottom edge.
      selectionService.onPanStart(
        DragStartDetails(globalPosition: Offset(400, viewportHeight / 2)),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();
      selectionService.onPanUpdate(
        DragUpdateDetails(
          globalPosition: Offset(400, viewportHeight - 5),
          delta: Offset(0, viewportHeight - 5 - viewportHeight / 2),
        ),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();

      // Sustain the edge drag for ~2s to accumulate recursive events.
      const sustainFrames = 125;
      for (var i = 0; i < sustainFrames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final offsetAtEdge = scrollController.offsetNotifier.value;
      expect(offsetAtEdge, greaterThan(0),
          reason: 'sustained edge drag must advance the scroll');

      // Drag the cursor back inside the viewport (center).
      selectionService.onPanUpdate(
        DragUpdateDetails(
          globalPosition: Offset(400, viewportHeight / 2),
          delta: Offset(0, viewportHeight / 2 - (viewportHeight - 5)),
        ),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();

      // Measure how many frames elapse until the offset stops advancing.
      const maxFrames = 120;
      var lastOffset = scrollController.offsetNotifier.value;
      var lastAdvanceFrame = -1;
      for (var i = 0; i < maxFrames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final offset = scrollController.offsetNotifier.value;
        final delta = offset - lastOffset;
        if (delta.abs() > 0.001) {
          lastAdvanceFrame = i;
        }
        lastOffset = offset;
      }

      selectionService.onPanEnd(
        DragEndDetails(),
        MobileSelectionDragMode.cursor,
      );
      await tester.pumpAndSettle();

      final stopLatencyFrames = lastAdvanceFrame + 1;

      // The auto-scroll must stop within a couple frames of the cursor
      // re-entering the viewport. A large latency means accumulated recursive
      // events are still driving the scroll.
      expect(
        stopLatencyFrames,
        lessThanOrEqualTo(3),
        reason:
            'auto-scroll must stop within 3 frames after returning inside; '
            'it took $stopLatencyFrames frames (${stopLatencyFrames * 16}ms)',
      );
    },
  );
}
