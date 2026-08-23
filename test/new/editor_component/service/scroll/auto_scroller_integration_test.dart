import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';

/// Integration test for the auto-scroll edge band, driving the exact code path
/// a drag triggers (`AutoScroller.startAutoScroll` → `ScrollDriver` →
/// `EdgeScrollTargetResolver`) against a **real scrollable**.
///
/// This is deterministic (no gesture arena, no layout timing): we construct an
/// `AutoScroller` over a real `ListView`, feed it a caret/finger offset, and
/// assert whether the scrollable moves. The invariant under test is the same as
/// the unit tests: **the configured `edgeOffset` is the trigger band** — a
/// caret within `edgeOffset` of the edge scrolls, one beyond it does not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const inset = 100.0;

  Future<ScrollController> pumpScrollable(WidgetTester tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: const [SizedBox(height: 2000)],
        ),
      ),
    );
    return controller;
  }

  AutoScroller buildAutoScroller(WidgetTester tester) {
    final scrollableState =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    return AutoScroller(
      scrollableState,
      animationDuration: Duration.zero,
    );
  }

  testWidgets(
    'AutoScroller scrolls when the caret is within edgeOffset of the bottom edge',
    (tester) async {
      final controller = await pumpScrollable(tester);
      final autoScroller = buildAutoScroller(tester);

      final viewportHeight = tester.getSize(find.byType(Scrollable).first).height;
      expect(viewportHeight, greaterThan(0));

      // caret 50px from the bottom edge → within edgeOffset(100) → must scroll.
      autoScroller.startAutoScroll(
        Offset(200, viewportHeight - 50),
        inset: inset,
      );
      // bounded pumps: the recursive follow loop terminates at maxScrollExtent.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        controller.offset,
        greaterThan(0),
        reason: 'a caret within edgeOffset of the bottom edge must auto-scroll',
      );
    },
  );

  testWidgets(
    'AutoScroller does NOT scroll when the caret is beyond edgeOffset of the edge',
    (tester) async {
      final controller = await pumpScrollable(tester);
      final autoScroller = buildAutoScroller(tester);

      final viewportHeight = tester.getSize(find.byType(Scrollable).first).height;

      // caret 150px from the bottom edge → beyond edgeOffset(100) → no scroll.
      autoScroller.startAutoScroll(
        Offset(200, viewportHeight - 150),
        inset: inset,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        controller.offset,
        0,
        reason: 'a caret beyond edgeOffset of the edge must NOT auto-scroll',
      );
    },
  );

  testWidgets(
    'AutoScroller scrolls up when the caret is within edgeOffset of the top edge',
    (tester) async {
      final controller = await pumpScrollable(tester);
      final autoScroller = buildAutoScroller(tester);

      // scroll down first so there is room to scroll back up.
      controller.jumpTo(500);
      await tester.pump();

      // caret 50px from the top edge → within edgeOffset(100) → must scroll up.
      autoScroller.startAutoScroll(
        Offset(200, 50),
        inset: inset,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        controller.offset,
        lessThan(500),
        reason: 'a caret within edgeOffset of the top edge must auto-scroll up',
      );
    },
  );
}