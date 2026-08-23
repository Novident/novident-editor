import 'package:flutter/material.dart';

import 'scroll_driver.dart';
import 'scroll_target_resolver.dart';
import 'scroll_velocity.dart';

abstract class AutoScrollerService {
  void startAutoScroll(
    Offset offset, {
    double inset = 200,
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
          resolver: const EdgeInsetResolver(),
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
  double? lastInset;

  /// Whether the auto scroll is in progress.
  bool get scrolling => _driver.isActive;

  @override
  void startAutoScroll(
    Offset offset, {
    double inset = 200,
    Duration? duration,
  }) {
    lastOffset = offset;
    lastDuration = duration;
    lastInset = inset;
    _driver.start(
      offset,
      inset: inset,
      duration: duration,
    );
  }

  @override
  void stopAutoScroll() {
    lastOffset = null;
    lastDuration = null;
    lastInset = null;
    _driver.stop();
  }

  void continueToAutoScroll() {
    if (lastOffset != null) {
      startAutoScroll(
        lastOffset!,
        inset: lastInset ?? 200,
        duration: lastDuration,
      );
    }
  }
}
