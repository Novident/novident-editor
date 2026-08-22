import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'scroll_target_resolver.dart';
import 'scroll_velocity.dart';

/// Drives the scrollable toward a resolved [ScrollTarget] in small,
/// incremental ticks (the "follow" loop).
///
/// Each tick re-resolves the target against the current viewport geometry
/// (the scrollable moves, so the geometry changes), computes a delta via the
/// [physics], applies it clamped to the scroll extents, and recurses until the
/// target is back inside the dead zone.
///
/// This reproduces the recursive `_scroll()` loop that used to live inside
/// `EdgeDraggingAutoScroller`, with the edge-detection and velocity logic
/// extracted into [resolver] and [physics].
class ScrollDriver {
  ScrollDriver(
    this.scrollable, {
    required this.resolver,
    required this.physics,
    this.onScrollViewScrolled,
    this.animationDuration = const Duration(milliseconds: 5),
  });

  final ScrollableState scrollable;
  final ScrollTargetResolver resolver;
  final ScrollVelocity physics;
  final VoidCallback? onScrollViewScrolled;
  final Duration animationDuration;

  Duration? _currentDuration;
  Rect? _dragTargetRelatedToScrollOrigin;
  bool _scrolling = false;

  /// Whether a scroll session is in progress.
  bool get isActive => _scrolling;

  /// Starts (or continues) an auto-scroll toward [dragTarget] (in global
  /// coordinates). If a session is already running, the new target is picked
  /// up on the next tick.
  void start(Rect dragTarget, {Duration? duration}) {
    final Offset deltaToOrigin = scrollable.deltaToScrollOrigin;
    _dragTargetRelatedToScrollOrigin = dragTarget.translate(
      deltaToOrigin.dx,
      deltaToOrigin.dy,
    );
    _currentDuration = duration;
    if (_scrolling) {
      // The change will be picked up in the next scroll.
      return;
    }
    _scroll();
  }

  /// Stops any ongoing auto-scroll and clears smoothing state.
  void stop() {
    _scrolling = false;
    physics.reset();
    _currentDuration = null;
  }

  Future<void> _scroll() async {
    try {
      final RenderBox scrollRenderBox =
          scrollable.context.findRenderObject()! as RenderBox;
      final Matrix4 transform = scrollRenderBox.getTransformTo(null);
      final Rect globalRect = MatrixUtils.transformRect(
        transform,
        Rect.fromLTWH(
          0,
          0,
          scrollRenderBox.size.width,
          scrollRenderBox.size.height,
        ),
      );
      final Rect transformedDragTarget = MatrixUtils.transformRect(
        transform,
        _dragTargetRelatedToScrollOrigin!,
      );

      _scrolling = true;

      final Offset deltaToOrigin = scrollable.deltaToScrollOrigin;
      final Offset viewportOrigin =
          globalRect.topLeft.translate(deltaToOrigin.dx, deltaToOrigin.dy);
      final Rect viewport = viewportOrigin & globalRect.size;

      final ScrollTarget? target = resolver.resolve(
        target: transformedDragTarget,
        viewport: viewport,
        axisDirection: scrollable.axisDirection,
        pixels: scrollable.position.pixels,
        minScrollExtent: scrollable.position.minScrollExtent,
        maxScrollExtent: scrollable.position.maxScrollExtent,
      );

      if (target == null) {
        // Drag should not trigger scroll.
        _scrolling = false;
        return;
      }

      final double delta = physics.deltaFor(target.overshoot);
      final double sign =
          target.direction == ScrollDirection.increase ? 1.0 : -1.0;
      double newOffset = scrollable.position.pixels + sign * delta;
      newOffset = newOffset.clamp(
        scrollable.position.minScrollExtent,
        scrollable.position.maxScrollExtent,
      );

      final double currentPixels = scrollable.position.pixels;
      double deltaPixels = newOffset - currentPixels;
      if (deltaPixels.abs() < physics.minDelta) {
        if (deltaPixels.abs() <= precisionErrorTolerance) {
          _scrolling = false;
          return;
        }
        final double direction = deltaPixels.sign;
        final double targetOffset =
            (currentPixels + direction * physics.minDelta).clamp(
          scrollable.position.minScrollExtent,
          scrollable.position.maxScrollExtent,
        );
        newOffset = targetOffset.toDouble();
        deltaPixels = newOffset - currentPixels;
        if (deltaPixels.abs() <= precisionErrorTolerance) {
          _scrolling = false;
          return;
        }
      }

      await scrollable.position.moveTo(
        newOffset,
        duration: _currentDuration ?? animationDuration,
        curve: Curves.linear,
      );
      onScrollViewScrolled?.call();
      if (_scrolling) {
        await _scroll();
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _scrolling = false;
    }
  }
}

