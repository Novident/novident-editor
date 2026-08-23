import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';

/// Hypothesis-driven investigation of the mobile auto-scroll "not smooth" bug.
///
/// The follow loop (`ScrollDriver._scroll`) recurses with
/// `moveTo(newOffset, duration)`. Two knobs shape how the offset advances over
/// time:
/// * `animationDuration` — if `Duration.zero`, each `moveTo` is an instant
///   `jumpTo`, so the loop drains the whole overshoot in microtasks within a
///   single frame (a big jump), instead of animating over frames.
/// * `maxAutoScrollDelta` — the per-tick delta cap. Mobile uses `0.053` px.
///
/// These tests measure the per-frame deltas for different knob combinations to
/// confirm which change makes the scroll **smooth** (small, continuous deltas)
/// vs **sawtooth** (a big jump followed by stalls).
class DragMetrics {
  const DragMetrics(this.maxDelta, this.stalls, this.deltas);

  final double maxDelta;
  final int stalls;
  final List<double> deltas;
}

Future<DragMetrics> measureDrag(
  WidgetTester tester, {
  required Duration animationDuration,
  required double velocityScalar,
  required double maxDelta,
}) async {
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
    velocityScalar: velocityScalar,
    minimumAutoScrollDelta: 0.03,
    maxAutoScrollDelta: maxDelta,
    animationDuration: animationDuration,
  );

  final viewportHeight = tester.getSize(find.byType(Scrollable).first).height;

  // Hold the finger 5px from the bottom edge with inset 100 → overshoot ~95,
  // matching the real editor (autoScrollEdgeInset default is 100).
  autoScroller.startAutoScroll(Offset(200, viewportHeight - 5), inset: 100);

  const frames = 30;
  var lastOffset = controller.offset;
  var maxD = 0.0;
  var stalls = 0;
  final deltas = <double>[];
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final offset = controller.offset;
    final delta = offset - lastOffset;
    deltas.add(delta);
    if (delta.abs() > maxD) maxD = delta.abs();
    if (delta.abs() <= 0.001) stalls++;
    lastOffset = offset;
  }
  return DragMetrics(maxD, stalls, deltas);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'current mobile knobs (zero duration, maxDelta 0.053) produce a sawtooth',
    (tester) async {
      final m = await measureDrag(
        tester,
        animationDuration: Duration.zero,
        velocityScalar: 0.2,
        maxDelta: 0.053,
      );
      debugPrint('[hypothesis] current: ${m.deltas}');
      // Confirms the bug: one big jump, then stalls.
      expect(m.maxDelta, greaterThan(10));
    },
  );

  testWidgets(
    'animating per frame (16ms) with a reasonable maxDelta is smooth',
    (tester) async {
      final m = await measureDrag(
        tester,
        animationDuration: const Duration(milliseconds: 16),
        velocityScalar: 0.2,
        maxDelta: 3.0,
      );
      debugPrint('[hypothesis] proposed: ${m.deltas}');
      // No big per-frame jump: the ~95px overshoot is spread into ~3px steps.
      expect(m.maxDelta, lessThanOrEqualTo(10));
      // It keeps advancing instead of draining the whole overshoot in one
      // frame and stopping (the current behavior).
      expect(m.deltas.fold<double>(0, (a, b) => a + b), greaterThan(0));
    },
  );
}