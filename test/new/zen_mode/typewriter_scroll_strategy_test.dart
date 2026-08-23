import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../test_helper.dart';
import '../util/document_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EditorScrollController> pumpEditor(
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

  /// Returns the caret's viewport-local center (0 = viewport top).
  double caretCenterInViewport(
    EditorState editorState,
    ScrollableState scrollableState,
  ) {
    final rects = editorState.selectionRects();
    expect(rects, isNotEmpty, reason: 'caret rect must be measurable');
    final caret = rects.reduce((a, b) => a.expandToInclude(b));
    final scrollableRenderBox =
        scrollableState.context.findRenderObject() as RenderBox?;
    expect(scrollableRenderBox, isNotNull);
    final origin = scrollableRenderBox!.localToGlobal(Offset.zero);
    final top = caret.top - origin.dy;
    final bottom = caret.bottom - origin.dy;
    return (top + bottom) / 2;
  }

  testWidgets(
    'centers the cursor at the alignment on a collapsed selection',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 60; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // move to a block that is already built → the cursor must be centered.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [20])),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offsetNotifier.value, greaterThan(0));

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      expect(center, closeTo(0.45 * viewportHeight, 1.0));
    },
  );

  testWidgets(
    'keeps the cursor centered while moving within a tall block',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;

      // start at a middle offset (centering is possible — there is content
      // above), then move through the block; the cursor must stay centered.
      for (var offset = 4000; offset <= length; offset += 2000) {
        await editorState.updateSelectionWithReason(
          Selection.collapsed(
            Position(path: [0], offset: offset.clamp(0, length)),
          ),
        );
        await tester.pumpAndSettle();

        final scrollableState = editorState.scrollableState;
        expect(scrollableState, isNotNull);
        final viewportHeight = scrollableState!.position.viewportDimension;
        final center = caretCenterInViewport(editorState, scrollableState);
        expect(
          center,
          closeTo(0.45 * viewportHeight, 1.0),
          reason: 'caret must stay centered at offset $offset',
        );
      }

      expect(scrollController.offsetNotifier.value, greaterThan(0));
    },
  );

  testWidgets(
    'brings a far (not yet built) block into view',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 60; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // move to a far block that is not built yet → the strategy must jump to
      // it so it becomes visible (offset > 0).
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [30])),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offsetNotifier.value, greaterThan(0));
    },
  );

  testWidgets(
    'does not center the caret at the top of the document (clamped)',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 10; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // caret at the very top (element 0, offset 0): there is no content
      // above to scroll into, so centering is impossible — the scroll must
      // clamp to the top and the caret must NOT be centered.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offsetNotifier.value, 0);

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      expect(center, isNot(closeTo(0.45 * viewportHeight, 1.0)));
      expect(center, lessThan(0.45 * viewportHeight));
    },
  );

  testWidgets(
    'does not center the caret at the bottom of the document (clamped)',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;

      // caret at the very bottom (end of the tall block): there is no content
      // below to scroll into, so centering is impossible — the scroll must
      // clamp to the bottom and the caret must NOT be centered.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: length)),
      );
      await tester.pumpAndSettle();

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      expect(
        scrollController.offsetNotifier.value,
        scrollableState!.position.maxScrollExtent,
      );

      final viewportHeight = scrollableState.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      expect(center, isNot(closeTo(0.45 * viewportHeight, 1.0)));
      expect(center, greaterThan(0.45 * viewportHeight));
    },
  );

  testWidgets(
    'handles an empty document without crashing or scrolling',
    (tester) async {
      final editorState = EditorState(
        document: Document.blank(withInitialText: true),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // caret at the only (empty) paragraph, offset 0.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
      );
      await tester.pumpAndSettle();

      // no crash; there is no content to scroll, so the offset stays 0.
      expect(scrollController.offsetNotifier.value, closeTo(0, 0.001));
    },
  );

  testWidgets(
    'delegates a selection that crosses the viewport edge',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;

      // an expanded selection from the top to the end of a tall block
      // (crosses the viewport edge) → delegates to the edge-follow.
      await editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: length),
        ),
      );
      await tester.pumpAndSettle();

      // no crash; the default edge-follow keeps the selection end visible.
      expect(scrollController.offsetNotifier.value, greaterThan(0));
    },
  );

  testWidgets(
    'centers the caret in the middle of a tall block that does not fit',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      final middle = length ~/ 2;

      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: middle)),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offsetNotifier.value, greaterThan(0));

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      expect(center, closeTo(0.45 * viewportHeight, 1.0));
    },
  );

  testWidgets(
    'scroll offset is monotonic when changing nodes (no ping-pong)',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 40; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // move down through nodes → the offset must be non-decreasing (the
      // caret moves down, so the view scrolls down; a ping-pong would show
      // as a reversal).
      double? last;
      for (var i = 5; i <= 15; i++) {
        await editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: [i])),
        );
        await tester.pumpAndSettle();
        final offset = scrollController.offsetNotifier.value;
        if (last != null) {
          expect(
            offset,
            greaterThanOrEqualTo(last - 0.001),
            reason: 'ping-pong while moving down at node $i '
                '(offset went from $last to $offset)',
          );
        }
        last = offset;
      }

      // move up through nodes → the offset must be non-increasing.
      for (var i = 14; i >= 5; i--) {
        await editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: [i])),
        );
        await tester.pumpAndSettle();
        final offset = scrollController.offsetNotifier.value;
        expect(
          offset,
          lessThanOrEqualTo(last! + 0.001),
          reason: 'ping-pong while moving up at node $i '
              '(offset went from $last to $offset)',
        );
        last = offset;
      }
    },
  );

  testWidgets(
    'does not attempt to scroll when moving between initial nodes',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 10; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // move between the first few nodes (all near the top, no room to scroll
      // up) → the strategy must NOT attempt a scroll (offset stays 0).
      for (var i = 0; i < 4; i++) {
        await editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: [i])),
        );
        await tester.pumpAndSettle();
        expect(
          scrollController.offsetNotifier.value,
          closeTo(0, 0.001),
          reason: 'no scroll attempt at node $i',
        );
      }
    },
  );

  testWidgets(
    'does not over-correct when the caret moves slightly (no runaway)',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      final middle = length ~/ 2;

      // center the caret at a middle offset.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: middle)),
      );
      await tester.pumpAndSettle();
      final centeredOffset = scrollController.offsetNotifier.value;
      expect(centeredOffset, greaterThan(0));

      // move the caret by a tiny amount — the offset should track the caret
      // proportionally (roughly the caret's movement), not run away.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: middle + 1)),
      );
      await tester.pumpAndSettle();
      expect(
        scrollController.offsetNotifier.value,
        closeTo(centeredOffset, 20.0),
      );
    },
  );

  testWidgets(
    'does not oscillate when typing across line wraps',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(500, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;

      // start at a middle offset (centered).
      final start = length ~/ 2;
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: start)),
      );
      await tester.pumpAndSettle();
      final startOffset = scrollController.offsetNotifier.value;
      expect(startOffset, greaterThan(0));

      // type forward by inserting characters (crossing line wraps); the
      // offset must be non-decreasing (no oscillation).
      double? last = startOffset;
      var caret = start;
      for (var i = 0; i < 80; i++) {
        final transaction = editorState.transaction;
        transaction.insertText(node, caret, 'x');
        await editorState.apply(transaction);
        caret++;
        await tester.pumpAndSettle();
        final offset = scrollController.offsetNotifier.value;
        expect(
          offset,
          greaterThanOrEqualTo(last! - 1.0),
          reason: 'oscillation after insert $i '
              '(offset went from $last to $offset)',
        );
        last = offset;
      }
    },
  );

  testWidgets(
    'does not jump when typing rapidly (no settle between keys)',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      final start = length ~/ 2;

      // center the caret first.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: start)),
      );
      await tester.pumpAndSettle();
      final startOffset = scrollController.offsetNotifier.value;
      expect(startOffset, greaterThan(0));

      // type rapidly: insert a char and pump ONE frame (no settle), so the
      // scroll doesn't finish before the next keystroke — stale scrolls pile
      // up and would jump.
      var caret = start;
      double? last = startOffset;
      for (var i = 0; i < 60; i++) {
        final transaction = editorState.transaction;
        transaction.insertText(node, caret, 'x');
        await editorState.apply(transaction);
        caret++;
        await tester.pump();
        final offset = scrollController.offsetNotifier.value;
        // typing moves the caret down → the offset must not jump back up.
        expect(
          offset,
          greaterThanOrEqualTo(last! - 20.0),
          reason: 'jump at insert $i (offset went from $last to $offset)',
        );
        last = offset;
      }

      // flush pending timers (debounced save, scroll) so the framework is
      // happy at the end of the test.
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'does not accumulate stale scroll when keystrokes outpace frames',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      final scrollController = await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      final node = editorState.document.root.children.first;
      final length = node.delta?.toPlainText().length ?? 0;
      final start = length ~/ 2;

      // center the caret first.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: start)),
      );
      await tester.pumpAndSettle();
      final startOffset = scrollController.offsetNotifier.value;
      expect(startOffset, greaterThan(0));

      // burst: several inserts with NO frame in between — the render tree
      // stays frozen at the previous frame's offset while each jumpTo
      // advances the controller synchronously. Measuring the caret against
      // the frozen tree and scrolling by the same delta per keystroke piles
      // up stale corrections (the "go crazy" oscillation in large docs).
      var caret = start;
      for (var i = 0; i < 5; i++) {
        final transaction = editorState.transaction;
        transaction.insertText(node, caret, 'x');
        await editorState.apply(transaction);
        caret++;
      }
      // one frame: all the pending post-frame callbacks run against the SAME
      // frozen render box.
      await tester.pump();

      // the offset must reflect ONE correction (the caret only moved ~5
      // chars), not five piled-up ones.
      final burstOffset = scrollController.offsetNotifier.value;
      expect(
        burstOffset,
        lessThan(startOffset + 100),
        reason: 'stale scroll accumulated during the burst '
            '(offset went from $startOffset to $burstOffset)',
      );

      // settle: the caret must end up centered — no oscillation.
      await tester.pumpAndSettle();
      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      expect(center, closeTo(0.45 * viewportHeight, 2.0));
    },
  );

  testWidgets(
    'delegates to the default edge-follow on a non-collapsed selection',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 60; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // a collapsed selection centers the cursor.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [5])),
      );
      await tester.pumpAndSettle();

      // an expanded selection must NOT center — it delegates to the default
      // edge-follow (which keeps the selection visible, not centered).
      await editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [5]),
          end: Position(path: [5], offset: 3),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      // the caret is NOT forced to the center for an expanded selection.
      expect(center, isNot(closeTo(0.45 * viewportHeight, 1.0)));
    },
  );

  testWidgets(
    'delegates to the default edge-follow while a mobile drag is active',
    (tester) async {
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 60; i++) {
        editorState.document.addParagraph(initialText: 'paragraph $i');
      }
      await pumpEditor(
        tester,
        editorState,
        scrollStrategies: const [TypewriterScrollStrategy()],
      );

      // center the caret in block 5 first.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [5])),
      );
      await tester.pumpAndSettle();

      // simulate a mobile cursor drag across blocks: the selection updates
      // carry the drag mode. The strategy must NOT center against the
      // freely-moving caret — it delegates to the default edge-follow.
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [6])),
        extraInfo: {'selection_drag_mode': 'MobileSelectionDragMode.cursor'},
      );
      await tester.pumpAndSettle();

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final center = caretCenterInViewport(editorState, scrollableState);
      // the caret is NOT re-centered while dragging (it stays where the
      // drag left it, just off-center).
      expect(center, isNot(closeTo(0.45 * viewportHeight, 1.0)));
    },
  );
}