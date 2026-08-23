import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';

/// Reproduces the "jump to the end" bug.
///
/// During a drag the finger is held at a fixed global position past the edge,
/// so its **viewport-local** offset is constant and the `overshoot` never
/// decreases. If the driver resolves against a fixed viewport-local offset, the
/// follow loop never converges and scrolls straight to `maxScrollExtent` in a
/// single burst — instead of advancing incrementally per tick.
///
/// Source of truth (physical-device log, before the crash):
///
/// ```
/// [scroll-driver] pixels=34.874 caretOffset=609.0 viewportDimension=603.0 inset=10.0
/// [scroll-driver] resolved=overshoot=16.0 dir=increase
/// ... (overshoot stays 16.0, pixels marches up ~0.053/tick until the end)
/// ```
///
/// The invariant under test: **one auto-scroll session advances the offset by a
/// small step (the overshoot), not the whole remaining extent.** The finger at
/// 6px past the bottom (overshoot 16 with inset 10) must move the offset by
/// ~tens of px, never straight to `maxScrollExtent`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a drag at the edge advances incrementally, not straight to the end',
    (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            controller: controller,
            children: const [SizedBox(height: 5000)],
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
      final maxScrollExtent = scrollableState.position.maxScrollExtent;
      expect(maxScrollExtent, greaterThan(viewportHeight));

      // Finger held 6px PAST the bottom edge (like the log: caretOffset 609 vs
      // viewportDimension 603). With inset 10 the overshoot is 16.
      autoScroller.startAutoScroll(
        Offset(200, viewportHeight + 6),
        inset: 10,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Must have scrolled a bit…
      expect(controller.offset, greaterThan(0));
      // …but NOT jumped to the very end in a single burst.
      expect(
        controller.offset,
        lessThan(maxScrollExtent),
        reason:
            'a drag at the edge must advance incrementally, not jump straight '
            'to the end of the list',
      );
    },
  );
}
