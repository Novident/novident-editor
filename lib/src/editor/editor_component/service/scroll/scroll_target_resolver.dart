import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Direction in which the scrollable must move to bring the target back
/// inside the dead zone.
enum ScrollDirection {
  /// Increase the scroll offset (scroll down / right).
  increase,

  /// Decrease the scroll offset (scroll up / left).
  decrease,
}

/// The result of resolving a drag target against the viewport: which edge it
/// overflows and by how much.
class ScrollTarget {
  const ScrollTarget({required this.overshoot, required this.direction});

  /// How far (in logical pixels) the target overflows the viewport edge,
  /// clamped to the resolver's max overshoot.
  final double overshoot;

  /// Which way the scrollable must move to bring the target back inside.
  final ScrollDirection direction;
}

/// Decides whether a drag target (caret / selection rect, in scroll-origin
/// coordinates) is outside the viewport's "dead zone" and, if so, in which
/// direction and by how much the scrollable should move.
///
/// Pure and injectable: a strategy can swap this to change the edge policy
/// (e.g. a wider dead zone, or "always center" instead of "follow edge").
abstract class ScrollTargetResolver {
  const ScrollTargetResolver();

  /// Returns `null` when [target] is inside the dead zone (no scroll needed).
  ScrollTarget? resolve({
    required Rect target,
    required Rect viewport,
    required AxisDirection axisDirection,
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
  });
}

/// The default edge-follow resolver: scrolls only when the target overflows
/// the viewport edge, by an amount capped at [maxOvershoot].
///
/// This reproduces the edge-detection logic that used to live inside
/// `EdgeDraggingAutoScroller._scroll()`.
class EdgeScrollTargetResolver extends ScrollTargetResolver {
  const EdgeScrollTargetResolver({this.maxOvershoot = 20.0});

  /// Maximum overshoot (in logical pixels) considered per resolution.
  final double maxOvershoot;

  @override
  ScrollTarget? resolve({
    required Rect target,
    required Rect viewport,
    required AxisDirection axisDirection,
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) {
    final axis = axisDirectionToAxis(axisDirection);
    final viewportStart = _offsetExtent(viewport.topLeft, axis);
    final viewportEnd = viewportStart + _sizeExtent(viewport.size, axis);
    final proxyStart = _offsetExtent(target.topLeft, axis);
    final proxyEnd = _offsetExtent(target.bottomRight, axis);

    switch (axisDirection) {
      case AxisDirection.up:
      case AxisDirection.left:
        if (proxyEnd > viewportEnd && pixels > minScrollExtent) {
          return ScrollTarget(
            overshoot: math.min(proxyEnd - viewportEnd, maxOvershoot),
            direction: ScrollDirection.decrease,
          );
        }
        if (proxyStart < viewportStart && pixels < maxScrollExtent) {
          return ScrollTarget(
            overshoot: math.min(viewportStart - proxyStart, maxOvershoot),
            direction: ScrollDirection.increase,
          );
        }
        break;
      case AxisDirection.right:
      case AxisDirection.down:
        if (proxyStart < viewportStart && pixels > minScrollExtent) {
          return ScrollTarget(
            overshoot: math.min(viewportStart - proxyStart, maxOvershoot),
            direction: ScrollDirection.decrease,
          );
        }
        if (proxyEnd > viewportEnd && pixels < maxScrollExtent) {
          return ScrollTarget(
            overshoot: math.min(proxyEnd - viewportEnd, maxOvershoot),
            direction: ScrollDirection.increase,
          );
        }
        break;
    }
    return null;
  }

  double _offsetExtent(Offset offset, Axis axis) {
    return switch (axis) {
      Axis.horizontal => offset.dx,
      Axis.vertical => offset.dy,
    };
  }

  double _sizeExtent(Size size, Axis axis) {
    return switch (axis) {
      Axis.horizontal => size.width,
      Axis.vertical => size.height,
    };
  }
}