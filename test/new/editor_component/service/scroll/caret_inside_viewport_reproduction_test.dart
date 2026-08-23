import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/scroll_target_resolver.dart';

/// # Purpose
///
/// This test reproduces and pins a specific bug reported on a physical device:
/// the auto-scroll fires while the caret is **still inside the viewport** — it
/// never touches, let alone leaves, the viewport edge.
///
/// It exists to (a) document the bug with the exact device-log numbers, and (b)
/// verify the fix: with an **explicit `inset`** the trigger is predictable, and
/// with `inset = 0` the auto-scroll fires only once the caret actually crosses
/// the edge.
///
/// # The bug (root cause) and the fix
///
/// The old code inflated a drag-target rect with `edgeOffset` and compared the
/// **rect's** edge against the viewport edge, so it fired `edgeOffset` px before
/// the caret reached the edge. The fix replaces the rect with a **viewport-local
/// caret offset** and an **explicit symmetric `inset`** (dead zone):
///
/// ```
/// old:      caret + edgeOffset > viewportBottom      ← fires early (rect inflated)
/// new:      caretOffset      > viewportDimension - inset
/// fixed:    inset = 0  ⇒  fires only once caretOffset > viewportDimension
/// ```
///
/// # Source of truth (physical-device logs, `[scroll-driver]`)
///
/// ```
/// dragTargetTop=453.7  dragTargetBottom=473.7  caretCenterY=463.7
/// viewportTop=152.1    viewportBottom=471.1
/// resolved=overshoot=2.6 dir=increase
/// ```
///
/// Decoded into a clean 0..319 viewport-local frame: caret at `311.6` (7.4px
/// inside the bottom `319`), `edgeOffset = 10`, overshoot `2.6`.
void main() {
  const resolver = EdgeInsetResolver();

  // Mirrors the log numbers in a clean 0..319 viewport-local frame.
  const viewportDimension = 319.0;
  const caret = 311.6; // 7.4px INSIDE the viewport bottom

  group('BUG reproduction + fix — caret INSIDE the viewport', () {
    test('the caret is verifiably inside the viewport', () {
      expect(caret, lessThan(viewportDimension));
      expect(
        viewportDimension - caret,
        closeTo(7.4, 0.001),
        reason: 'the caret is 7.4px from the bottom edge',
      );
    });

    test('with inset=10 (the logged edgeOffset) it still fires — the band', () {
      // Reproduces the log: caret 7.4px inside, inset 10 → overshoot 2.6.
      final result = resolver.resolve(
        caretOffset: caret,
        viewportDimension: viewportDimension,
        inset: 10,
        axisDirection: AxisDirection.down,
        pixels: 45,
        minScrollExtent: 0,
        maxScrollExtent: 1000,
      );
      expect(result, isNotNull);
      expect(result!.overshoot, closeTo(2.6, 0.001)); // matches the log
      expect(result.direction, ScrollDirection.increase);
    });

    test('with inset=0 it does NOT fire while the caret is inside', () {
      // The fix: no dead zone means the caret must actually cross the edge.
      final result = resolver.resolve(
        caretOffset: caret,
        viewportDimension: viewportDimension,
        inset: 0,
        axisDirection: AxisDirection.down,
        pixels: 45,
        minScrollExtent: 0,
        maxScrollExtent: 1000,
      );
      expect(
        result,
        isNull,
        reason:
            'fixed: a caret 7.4px INSIDE the viewport must NOT trigger when inset=0',
      );
    });
  });

  group('BUG reproduction + fix — real scrollable', () {
    Future<(ScrollController, AutoScroller)> pumpAutoScroller(
      WidgetTester tester,
    ) async {
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
      return (
        controller,
        AutoScroller(scrollableState, animationDuration: Duration.zero),
      );
    }

    testWidgets(
        'inset=10: the scroll offset moves while the caret is 7px inside',
        (tester) async {
      final (controller, autoScroller) = await pumpAutoScroller(tester);
      final viewportHeight =
          tester.getSize(find.byType(Scrollable).first).height;
      final caretY = viewportHeight - 7; // 7px INSIDE

      autoScroller.startAutoScroll(Offset(200, caretY), inset: 10);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The band: with inset 10, a caret 7px inside still scrolls (the bug).
      expect(
        controller.offset,
        greaterThan(0),
        reason:
            'inset=10: a caret 7px inside is within the dead zone → scrolls',
      );
    });

    testWidgets(
        'inset=0: the scroll offset does NOT move while the caret is inside',
        (tester) async {
      final (controller, autoScroller) = await pumpAutoScroller(tester);
      final viewportHeight =
          tester.getSize(find.byType(Scrollable).first).height;
      final caretY = viewportHeight - 7; // 7px INSIDE

      autoScroller.startAutoScroll(Offset(200, caretY), inset: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        controller.offset,
        0,
        reason:
            'fixed: a caret 7px INSIDE the viewport must NOT scroll when inset=0',
      );
    });
  });
}
