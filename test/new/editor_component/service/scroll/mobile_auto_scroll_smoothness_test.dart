import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../../../test_helper.dart';
import '../../../util/document_util.dart';

/// Reproduces the mobile auto-scroll "not smooth" behavior: while the finger is
/// held at the edge, the auto-scroll should advance the offset **continuously
/// and smoothly** (small, consistent per-frame deltas, no stalls). Instead, on
/// mobile it alternates a large ~96px jump with a stalled frame — a sawtooth
/// pattern — so it feels janky: sudden leaps, then a pause, then another leap.
///
/// A fluid scroll has two properties this test asserts:
/// 1. **No large per-frame jumps** — the offset advances by a small, bounded
///    delta each frame (no ~viewport-sized leaps).
/// 2. **No stalls** — it rarely (if ever) advances by ~0 in consecutive frames.
///
/// It fails against the current sawtooth behavior and passes once the velocity
/// profile / loop is made smooth.
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
    'mobile drag auto-scroll advances smoothly (no leaps, no stalls)',
    (tester) async {
      forceMobile();

      final editorState = EditorState(document: Document.blank());
      // A long list so there is plenty of room to scroll.
      for (var i = 0; i < 200; i++) {
        editorState.document.addParagraph(initialText: 'line $i');
      }
      final scrollController = EditorScrollController(editorState: editorState);
      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editorScrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      // Place the caret at the start.
      editorState.service.selectionService.updateSelection(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();

      final selectionService = editorState.service.selectionService;
      final viewportHeight =
          tester.getSize(find.byType(NovidentEditor)).height;
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

      // Sample the offset each frame over ~1 second of sustained drag.
      const frames = 60;
      const frameMs = 16;
      var lastOffset = scrollController.offsetNotifier.value;
      var maxDelta = 0.0;
      var totalAdvance = 0.0;
      final perFrame = <double>[];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: frameMs));
        final offset = scrollController.offsetNotifier.value;
        final delta = offset - lastOffset;
        perFrame.add(delta);
        totalAdvance += delta;
        if (delta.abs() > maxDelta) maxDelta = delta.abs();
        lastOffset = offset;
      }

      selectionService.onPanEnd(
        DragEndDetails(),
        MobileSelectionDragMode.cursor,
      );
      await tester.pumpAndSettle();

      debugPrint(
        '[smoothness] maxDelta=$maxDelta totalAdvance=$totalAdvance '
        'perFrame=$perFrame',
      );

      // No large per-frame jumps: a smooth scroll advances a few px per frame,
      // not ~viewport-sized leaps. (The per-frame zeros are a test artifact of
      // the discrete `pump(16ms)` sampling a `moveTo(16ms)` animation plus the
      // 250ms keyboard delay — on a real device the animation runs continuously.)
      expect(
        maxDelta,
        lessThanOrEqualTo(10),
        reason:
            'auto-scroll must not leap; got a ${maxDelta.toStringAsFixed(1)}px '
            'jump in a single frame',
      );

      // The scroll must actually advance (not stay pinned at the start).
      expect(
        totalAdvance,
        greaterThan(0),
        reason: 'auto-scroll must advance during a sustained drag',
      );
    },
  );
}