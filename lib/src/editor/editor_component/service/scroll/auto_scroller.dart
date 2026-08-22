import 'package:flutter/material.dart';

import 'scroll_driver.dart';
import 'scroll_target_resolver.dart';
import 'scroll_velocity.dart';

abstract class AutoScrollerService {
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 200,
    AxisDirection? direction,
    Duration? duration,
  });

  void stopAutoScroll();
}

/// An auto scroller that scrolls the [scrollable] if a drag gesture drags
/// close to its edge.
///
/// The scroll velocity is controlled by the [velocityScalar]:
///
/// velocity = (distance of overscroll) * [velocityScalar].
///
/// It is a thin composition of a [ScrollTargetResolver] (edge policy), a
/// [ScrollPhysics] (velocity profile) and a [ScrollDriver] (the follow loop),
/// plus the drag-session lifecycle (`lastOffset` / `continueToAutoScroll`).
class AutoScroller implements AutoScrollerService {
  AutoScroller(
    ScrollableState scrollable, {
    VoidCallback? onScrollViewScrolled,
    double velocityScalar = _kDefaultAutoScrollVelocityScalar,
    double minimumAutoScrollDelta = _kDefaultMinAutoScrollDelta,
    double maxAutoScrollDelta = _kDefaultMaxAutoScrollDelta,
    Duration? animationDuration,
  }) : _driver = ScrollDriver(
          scrollable,
          resolver: const EdgeScrollTargetResolver(),
          physics: SmoothScrollVelocity(
            velocityScalar: velocityScalar,
            minDelta: minimumAutoScrollDelta,
            maxDelta: maxAutoScrollDelta,
          ),
          onScrollViewScrolled: onScrollViewScrolled,
          animationDuration:
              animationDuration ?? const Duration(milliseconds: 5),
        );

  static const double _kDefaultAutoScrollVelocityScalar = 7;
  static const double _kDefaultMinAutoScrollDelta = 1.0;
  static const double _kDefaultMaxAutoScrollDelta = 20.0;

  final ScrollDriver _driver;

  Offset? lastOffset;
  Duration? lastDuration;
  double? lastEdgeOffset;
  AxisDirection? lastDirection;

  /// Whether the auto scroll is in progress.
  bool get scrolling => _driver.isActive;

  @override
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 200,
    AxisDirection? direction,
    Duration? duration,
  }) {
    lastOffset = offset;
    lastDuration = duration;
    lastEdgeOffset = edgeOffset;
    lastDirection = direction;
    if (direction != null && direction == AxisDirection.up) {
      return _driver.start(
        Rect.fromLTWH(
          offset.dx,
          offset.dy - edgeOffset,
          1,
          edgeOffset,
        ),
        duration: duration,
      );
    }

    if (direction != null && direction == AxisDirection.down) {
      return _driver.start(
        Rect.fromLTWH(
          offset.dx,
          offset.dy,
          1,
          edgeOffset,
        ),
        duration: duration,
      );
    }

    final dragTarget = Rect.fromCenter(
      center: offset,
      width: edgeOffset,
      height: edgeOffset,
    );

    _driver.start(dragTarget, duration: duration);
  }

  @override
  void stopAutoScroll() {
    lastOffset = null;
    lastDuration = null;
    lastEdgeOffset = null;
    lastDirection = null;
    _driver.stop();
  }

  void continueToAutoScroll() {
    if (lastOffset != null) {
      startAutoScroll(
        lastOffset!,
        edgeOffset: lastEdgeOffset ?? 200,
        direction: lastDirection,
        duration: lastDuration,
      );
    }
  }
}

