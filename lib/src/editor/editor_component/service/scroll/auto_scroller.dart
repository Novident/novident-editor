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
/// Builds the drag-target rect for a given pointer/caret [offset] and
/// [edgeOffset].
///
/// The resolver compares this rect against the viewport and triggers the
/// auto-scroll when one of its edges crosses the viewport edge. The rect is
/// therefore what defines the trigger band:
///
/// * `direction == AxisDirection.up` — a 1×`edgeOffset` rect whose top sits
///   `edgeOffset` above the pointer, so the band is `edgeOffset` from the top
///   edge.
/// * `direction == AxisDirection.down` — a 1×`edgeOffset` rect starting at the
///   pointer, so the band is `edgeOffset` from the bottom edge.
/// * `direction == null` (caret / finger can move either way) — a
///   `edgeOffset` rect centered on the pointer, so the band is `edgeOffset`
///   on **both** edges.
///
/// Extracted as a pure function so the edge policy is unit-testable in
/// isolation from the scroll driver.
Rect buildAutoScrollDragTarget(
  Offset offset,
  double edgeOffset,
  AxisDirection? direction,
) {
  if (direction == AxisDirection.up) {
    return Rect.fromLTWH(
      offset.dx,
      offset.dy - edgeOffset,
      1,
      edgeOffset,
    );
  }

  if (direction == AxisDirection.down) {
    return Rect.fromLTWH(
      offset.dx,
      offset.dy,
      1,
      edgeOffset,
    );
  }

  // No direction: the pointer can move toward either edge, so the rect must
  // extend `edgeOffset` on both sides. A rect of size `edgeOffset` centered on
  // the pointer would only extend `edgeOffset/2` each way — halving the
  // configured band (the bug this fixes).
  return Rect.fromCenter(
    center: offset,
    width: edgeOffset * 2,
    height: edgeOffset * 2,
  );
}

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
    _driver.start(
      buildAutoScrollDragTarget(
        offset,
        edgeOffset,
        direction,
      ),
      duration: duration,
    );
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
