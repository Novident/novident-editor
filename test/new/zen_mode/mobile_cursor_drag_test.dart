import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../test_helper.dart';
import '../util/document_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EditorScrollController> pumpMobileEditor(
    WidgetTester tester,
    EditorState editorState, {
    List<ScrollStrategy> scrollStrategies = const [],
  }) async {
    final scrollController = EditorScrollController(editorState: editorState);
    await tester.buildAndPump(
      NovidentEditor(
        editorState: editorState,
        editorScrollController: scrollController,
        scrollStrategies: scrollStrategies,
      ),
    );
    return scrollController;
  }

  testWidgets(
    'mobile cursor drag scrolls smoothly (no typewriter ping-pong)',
    (tester) async {
      // Force the mobile selection service (the drag-handle path).
      EditorPlatform.override = const EditorPlatformOverride(
        isMobile: true,
        isAndroid: true,
      );
      addTearDown(EditorPlatform.reset);

      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 60; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpMobileEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // Place the caret. Going through the selection service keeps
      // `currentSelection` in sync (the drag handle path).
      editorState.service.selectionService.updateSelection(
        Selection.collapsed(Position(path: [5])),
      );
      await tester.pumpAndSettle();

      // The exact global rect of the caret (where the drag handle sits).
      final caretRects = editorState.selectionRects();
      expect(caretRects, isNotEmpty, reason: 'caret rect must be measurable');
      final caretCenter = caretRects.first.center;
      debugPrint('DIAG caretCenter=$caretCenter '
          'selection=${editorState.selection}');

      final startOffset = scrollController.offsetNotifier.value;
      debugPrint('DIAG startOffset=$startOffset');

      // Simulate a FAST, JERKY drag: large alternating vertical moves, with
      // a frame between each so we can see how the scroll evolves as the
      // pending selection changes resolve. A typewriter ping-pong shows
      // large alternating deltas.
      final selectionService = editorState.service.selectionService;
      // lastPanOffset is null before the drag starts.
      expect(
        selectionService.lastPanOffset,
        isNull,
        reason: 'no finger position before drag',
      );
      selectionService.onPanStart(
        DragStartDetails(globalPosition: caretCenter),
        MobileSelectionDragMode.cursor,
      );
      await tester.pump();

      double? lastOffset = startOffset;
      var position = caretCenter;
      for (var i = 0; i < 20; i++) {
        // jerky: large alternating vertical moves (down/up/down/up...).
        final dy = i.isEven ? 120.0 : -60.0;
        position = position.translate(0, dy);
        selectionService.onPanUpdate(
          DragUpdateDetails(
            globalPosition: position,
            delta: Offset(0, dy),
          ),
          MobileSelectionDragMode.cursor,
        );
        await tester.pump();
        // The finger position is tracked so the edge-follow can fall back to
        // it when the caret leaves the viewport (selectionRects empty).
        expect(
          selectionService.lastPanOffset,
          position,
          reason: 'finger position tracked during drag at step $i',
        );
        final offset = scrollController.offsetNotifier.value;
        final delta = offset - (lastOffset ?? offset);
        debugPrint('DIAG step=$i dy=$dy offset=$offset delta=$delta '
            'dragMode=${editorState.selectionDragModeValue()} '
            'pixels=${editorState.scrollableState?.position.pixels}');
        expect(
          delta.abs(),
          lessThan(200),
          reason: 'scroll jumped at step $i (delta=$delta)',
        );
        lastOffset = offset;
      }

      selectionService.onPanEnd(
        DragEndDetails(),
        MobileSelectionDragMode.cursor,
      );
      await tester.pumpAndSettle();
      // The finger position is cleared once the drag ends.
      expect(
        selectionService.lastPanOffset,
        isNull,
        reason: 'finger position cleared after drag',
      );
      debugPrint('DIAG endOffset=${scrollController.offsetNotifier.value}');
    },
  );
}
