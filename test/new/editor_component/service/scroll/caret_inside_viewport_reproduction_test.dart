import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/scroll_target_resolver.dart';

/// # Purpose
///
/// This test EXISTS to **reproduce and freeze a specific bug** reported on a
/// physical device: the auto-scroll fires while the caret is **still inside the
/// viewport** — it never touches, let alone leaves, the viewport edge.
///
/// It is a **regression-reproduction test**: it asserts the CURRENT (buggy)
/// behavior on purpose, so the bug is documented and cannot silently change
/// without someone noticing. When the bug is eventually fixed, THIS test must
/// be updated (or inverted) to assert the DESIRED behavior instead.
///
/// # The bug (root cause)
///
/// `edgeOffset` does not mean "distance the caret may overshoot the edge". It
/// is used to **inflate the drag-target rect** around the caret, and the
/// trigger compares the **inflated rect's** edge against the viewport edge.
/// So the auto-scroll fires `edgeOffset` px *before* the caret reaches the
/// edge — i.e. while the caret is still comfortably inside the viewport.
///
/// ```
/// trigger: caret + edgeOffset > viewportBottom   ← current (buggy)
/// desired: caret            > viewportBottom   ← fires only after the caret
///                                                actually crosses the edge
/// ```
///
/// On mobile with the keyboard up, the viewport shrinks (~319px), so a small
/// `edgeOffset` (10px ≈ 3%) makes the auto-scroll feel aggressively early.
///
/// # Source of truth (physical-device logs, `[scroll-driver]`)
///
/// ```
/// dragTargetTop=453.7  dragTargetBottom=473.7  caretCenterY=463.7
/// viewportTop=152.1    viewportBottom=471.1
/// resolved=overshoot=2.6 dir=increase
/// ```
///
/// Decoded:
/// * `edgeOffset = 10` (drag target is `2×10 = 20px` tall, centered on the caret).
/// * The caret (`463.7`) is **7.4px INSIDE** the viewport bottom (`471.1`).
/// * Yet `resolved=overshoot=2.6` — the auto-scroll fires anyway, because the
///   trigger compares the **inflated** drag-target bottom (`caret + edgeOffset
///   = 473.7`) against the viewport bottom (`471.1`), not the caret itself.
///
/// # How to read this file
///
/// * The **unit group** pins the exact geometry from the log (caret 7.4px
///   inside, `edgeOffset=10`, overshoot 2.6).
/// * The **widget test** proves the same thing end-to-end: a real scrollable
///   moves its offset even though the caret is 7px inside the viewport.
///
/// Both assert the buggy behavior. If the semantic of `edgeOffset` is ever
/// changed to "fire only once the caret crosses the edge", update the
/// assertions here accordingly.
void main() {
  const resolver = EdgeScrollTargetResolver();
  const edgeOffset = 10.0;

  group('BUG reproduction — caret INSIDE the viewport still triggers', () {
    // Mirrors the log numbers, mapped into a clean 0..319 viewport-local frame:
    // viewport height 319, caret at 311.6 → 7.4px from the bottom.
    const viewportHeight = 319.0;
    const caret = Offset(200, 311.6); // 7.4px INSIDE the viewport bottom

    test('the caret is verifiably inside the viewport', () {
      expect(
        caret.dy,
        lessThan(viewportHeight),
        reason: 'precondition: the caret has NOT touched the viewport edge',
      );
      expect(
        viewportHeight - caret.dy,
        closeTo(7.4, 0.001),
        reason: 'the caret is 7.4px from the bottom edge',
      );
    });

    test('yet resolve() returns a ScrollTarget (auto-scroll fires)', () {
      final dragTarget = buildAutoScrollDragTarget(caret, edgeOffset, null);

      // The drag target is inflated by edgeOffset: bottom = caret + 10 = 321.6,
      // which is BELOW the viewport bottom (319).
      expect(dragTarget.bottom, closeTo(321.6, 0.001));
      expect(dragTarget.bottom - viewportHeight, closeTo(2.6, 0.001));

      final result = resolver.resolve(
        target: dragTarget,
        viewport: Rect.fromLTWH(0, 0, 400, viewportHeight),
        axisDirection: AxisDirection.down,
        pixels: 45,
        minScrollExtent: 0,
        maxScrollExtent: 1000,
      );

      expect(
        result,
        isNotNull,
        reason:
            'BUG: auto-scroll triggers even though the caret (311.6) is '
            '7.4px INSIDE the viewport bottom (319)',
      );
      // Matches the log's overshoot=2.6 exactly.
      expect(result!.overshoot, closeTo(2.6, 0.001));
      expect(result.direction, ScrollDirection.increase);
    });
  });

  group('BUG reproduction — real scrollable scrolls with the caret inside', () {
    testWidgets(
      'AutoScroller moves the scroll offset while the caret is 7px inside',
      (tester) async {
        final controller = ScrollController();
        await tester.pumpWidget(
          MaterialApp(
            home: ListView(
              controller: controller,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        );
        final scrollableState =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        final autoScroller = AutoScroller(
          scrollableState,
          animationDuration: Duration.zero,
        );

        final viewportHeight =
            tester.getSize(find.byType(Scrollable).first).height;

        // caret 7px from the bottom edge — INSIDE the viewport.
        final caretY = viewportHeight - 7;
        expect(caretY, lessThan(viewportHeight));

        autoScroller.startAutoScroll(
          Offset(200, caretY),
          edgeOffset: edgeOffset,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          controller.offset,
          greaterThan(0),
          reason:
              'BUG: the scroll offset moved even though the caret was '
              '7px INSIDE the viewport (never touched the edge)',
        );
      },
    );
  });
}