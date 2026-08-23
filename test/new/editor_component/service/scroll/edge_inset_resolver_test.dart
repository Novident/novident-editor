import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/scroll_target_resolver.dart';

/// Unit tests for [EdgeInsetResolver]: the edge policy expressed as an explicit
/// symmetric [inset] (dead zone) from each viewport edge, operating on the
/// caret's **viewport-local** offset (no rect inflation).
void main() {
  const resolver = EdgeInsetResolver();

  ScrollTarget? resolveDown({
    required double caretOffset,
    required double viewportDimension,
    required double inset,
    double pixels = 0,
    double minScrollExtent = 0,
    double maxScrollExtent = 1000,
  }) {
    return resolver.resolve(
      caretOffset: caretOffset,
      viewportDimension: viewportDimension,
      inset: inset,
      axisDirection: AxisDirection.down,
      pixels: pixels,
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
    );
  }

  group('EdgeInsetResolver', () {
    test('does not scroll when the caret is inside the dead zone', () {
      // viewport 0..600, inset 20 → dead zone is 20..580.
      expect(
        resolveDown(caretOffset: 300, viewportDimension: 600, inset: 20),
        isNull,
      );
      // exactly at the dead-zone boundary → no scroll.
      expect(
        resolveDown(caretOffset: 20, viewportDimension: 600, inset: 20),
        isNull,
      );
      expect(
        resolveDown(caretOffset: 580, viewportDimension: 600, inset: 20),
        isNull,
      );
    });

    test('scrolls down when the caret is closer than inset to the bottom', () {
      // caret at 590 (10px from bottom), inset 20 → 590 > 580 → scroll down.
      final result = resolveDown(
        caretOffset: 590,
        viewportDimension: 600,
        inset: 20,
      );
      expect(result, isNotNull);
      expect(result!.direction, ScrollDirection.increase);
      expect(result.overshoot, closeTo(10, 0.001)); // 590 - 580
    });

    test('scrolls up when the caret is closer than inset to the top', () {
      final result = resolveDown(
        caretOffset: 10,
        viewportDimension: 600,
        inset: 20,
        pixels: 500,
      );
      expect(result, isNotNull);
      expect(result!.direction, ScrollDirection.decrease);
      expect(result.overshoot, closeTo(10, 0.001)); // 20 - 10
    });

    test('inset = 0 fires only when the caret crosses the edge', () {
      // caret inside → no scroll.
      expect(
        resolveDown(caretOffset: 300, viewportDimension: 600, inset: 0),
        isNull,
      );
      // caret exactly at the bottom edge → no scroll (hasn't crossed).
      expect(
        resolveDown(caretOffset: 600, viewportDimension: 600, inset: 0),
        isNull,
      );
      // caret past the bottom → scroll down.
      final down = resolveDown(
        caretOffset: 605,
        viewportDimension: 600,
        inset: 0,
      );
      expect(down, isNotNull);
      expect(down!.direction, ScrollDirection.increase);
      expect(down.overshoot, closeTo(5, 0.001));
    });

    test('respects scroll-extent bounds', () {
      // at top with pixels == minScrollExtent → cannot scroll up.
      expect(
        resolveDown(
          caretOffset: 0,
          viewportDimension: 600,
          inset: 20,
        ),
        isNull,
      );
      // at bottom with pixels == maxScrollExtent → cannot scroll down.
      expect(
        resolveDown(
          caretOffset: 600,
          viewportDimension: 600,
          inset: 20,
          pixels: 1000,
        ),
        isNull,
      );
    });

    test('clamps overshoot to maxOvershoot', () {
      const maxed = EdgeInsetResolver(maxOvershoot: 5);
      final result = maxed.resolve(
        caretOffset: 650,
        viewportDimension: 600,
        inset: 0,
        axisDirection: AxisDirection.down,
        pixels: 0,
        minScrollExtent: 0,
        maxScrollExtent: 1000,
      );
      expect(result!.overshoot, closeTo(5, 0.001));
    });
  });
}