import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/scroll_target_resolver.dart';

/// Freezes the auto-scroll **edge policy**: the relationship between the
/// configured `edgeOffset` and the viewport band at which the auto-scroll
/// actually kicks in.
///
/// The invariant under test: **the configured `edgeOffset` IS the trigger
/// band.** The auto-scroll must start when the caret / finger is within
/// `edgeOffset` of a viewport edge — not `edgeOffset/2` (the pre-fix behavior,
/// where the drag-target rect was sized `edgeOffset` and centered on the
/// pointer, so it only overhung the edge by `edgeOffset/2`).
///
/// These are pure unit tests: they exercise `buildAutoScrollDragTarget` (the
/// rect the `AutoScroller` feeds the resolver) together with
/// `EdgeScrollTargetResolver.resolve`, so they pin the exact geometry without
/// any layout timing.
void main() {
  const resolver = EdgeScrollTargetResolver();

  const viewportWidth = 400.0;
  const viewportHeight = 600.0;
  const edgeOffset = 100.0;

  Rect viewport() => Rect.fromLTWH(0, 0, viewportWidth, viewportHeight);

  ScrollTarget? resolveDown(Rect target, {double pixels = 0}) {
    return resolver.resolve(
      target: target,
      viewport: viewport(),
      axisDirection: AxisDirection.down,
      pixels: pixels,
      minScrollExtent: 0,
      maxScrollExtent: 1000,
    );
  }

  group('buildAutoScrollDragTarget', () {
    const offset = Offset(200, 300);

    test('no direction: rect extends edgeOffset on BOTH sides of the pointer', () {
      final rect = buildAutoScrollDragTarget(offset, edgeOffset, null);
      expect(rect.top, 300 - edgeOffset, reason: 'top edge = pointer - edgeOffset');
      expect(rect.bottom, 300 + edgeOffset, reason: 'bottom edge = pointer + edgeOffset');
      expect(rect.height, edgeOffset * 2, reason: 'full height = 2 * edgeOffset');
    });

    test('AxisDirection.down: rect extends edgeOffset BELOW the pointer', () {
      final rect = buildAutoScrollDragTarget(
        offset,
        edgeOffset,
        AxisDirection.down,
      );
      expect(rect.top, 300);
      expect(rect.bottom, 300 + edgeOffset);
    });

    test('AxisDirection.up: rect extends edgeOffset ABOVE the pointer', () {
      final rect = buildAutoScrollDragTarget(offset, edgeOffset, AxisDirection.up);
      expect(rect.top, 300 - edgeOffset);
      expect(rect.bottom, 300);
    });
  });

  group('EdgeScrollTargetResolver — configured edgeOffset is the trigger band', () {
    test('scrolls down when the caret is just inside edgeOffset of the bottom edge', () {
      // caret at viewportHeight - edgeOffset + 0.5 → 500.5. The drag-target
      // bottom edge is 500.5 + edgeOffset = 600.5 > 600 → must scroll down.
      final caret = Offset(200, viewportHeight - edgeOffset + 0.5);
      final target = buildAutoScrollDragTarget(caret, edgeOffset, null);
      final result = resolveDown(target);
      expect(result, isNotNull, reason: 'caret within edgeOffset of the bottom edge must trigger');
      expect(result!.direction, ScrollDirection.increase);
    });

    test('does NOT scroll when the caret is exactly edgeOffset from the bottom edge', () {
      // caret at 500 → bottom edge 600 == viewport end → boundary, no scroll.
      final caret = Offset(200, viewportHeight - edgeOffset);
      final target = buildAutoScrollDragTarget(caret, edgeOffset, null);
      expect(resolveDown(target), isNull);
    });

    test('scrolls down when the caret is at the very bottom edge', () {
      final caret = Offset(200, viewportHeight - 1);
      final target = buildAutoScrollDragTarget(caret, edgeOffset, null);
      final result = resolveDown(target);
      expect(result, isNotNull);
      expect(result!.direction, ScrollDirection.increase);
    });

    test('scrolls up when the caret is just inside edgeOffset of the top edge', () {
      // caret at edgeOffset - 0.5 → 99.5. The drag-target top edge is
      // 99.5 - edgeOffset = -0.5 < 0 → must scroll up (decrease). pixels > 0
      // so the scrollable is not already pinned to the top.
      final caret = Offset(200, edgeOffset - 0.5);
      final target = buildAutoScrollDragTarget(caret, edgeOffset, null);
      final result = resolveDown(target, pixels: 500);
      expect(result, isNotNull, reason: 'caret within edgeOffset of the top edge must trigger');
      expect(result!.direction, ScrollDirection.decrease);
    });

    test('does NOT scroll when the caret is exactly edgeOffset from the top edge', () {
      final caret = Offset(200, edgeOffset);
      final target = buildAutoScrollDragTarget(caret, edgeOffset, null);
      expect(resolveDown(target, pixels: 500), isNull);
    });

    test('does NOT scroll when the caret is well inside the viewport', () {
      final caret = Offset(200, viewportHeight / 2);
      final target = buildAutoScrollDragTarget(caret, edgeOffset, null);
      expect(resolveDown(target), isNull);
    });
  });
}