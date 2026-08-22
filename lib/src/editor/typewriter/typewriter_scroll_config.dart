import 'package:flutter/material.dart';

/// Configuration for the typewriter (centered) scrolling behavior.
///
/// Keeps the focused block vertically centered in the viewport. It is a
/// separate, optional feature from zen mode: zen dims unfocused blocks,
/// while this config controls how the editor scrolls to follow the caret.
///
/// This configuration is immutable — use [copyWith] to derive a new one.
@immutable
class TypewriterScrollConfig {
  const TypewriterScrollConfig({
    this.enabled = true,
    this.centerAlignment = 0.45,
    this.scrollDuration = const Duration(milliseconds: 240),
    this.scrollCurve = Curves.easeOutCubic,
    this.keepInViewTopMargin = 100.0,
    this.keepInViewBottomMargin = 160.0,
  }) : assert(
          centerAlignment >= 0.0 && centerAlignment <= 1.0,
          'centerAlignment must be between 0.0 and 1.0',
        ),
        assert(
          keepInViewTopMargin >= 0.0,
          'keepInViewTopMargin must be non-negative',
        ),
        assert(
          keepInViewBottomMargin >= 0.0,
          'keepInViewBottomMargin must be non-negative',
        );

  /// Whether the typewriter centering is active.
  final bool enabled;

  /// Where the leading edge of the focused block is aligned inside the
  /// viewport when centering: 0.0 = top, 0.5 = center, 1.0 = bottom.
  final double centerAlignment;

  /// Duration of the centering scroll animation.
  final Duration scrollDuration;

  /// Curve of the centering scroll animation.
  final Curve scrollCurve;

  /// Top margin (in logical pixels) of the vertical "dead zone" box.
  ///
  /// While the caret stays inside the box
  /// `[keepInViewTopMargin, viewportHeight - keepInViewBottomMargin]` the
  /// editor does not scroll at all. Only when the caret leaves that box does
  /// the editor scroll just enough to bring it back inside.
  final double keepInViewTopMargin;

  /// Bottom margin (in logical pixels) of the vertical "dead zone" box.
  ///
  /// It defaults to a larger value than [keepInViewTopMargin] because, when
  /// scrolling down, the caret tends to outrun the scroll more easily (the
  /// caret is drawn near the top of its line while the box check uses the line
  /// bottom). A larger bottom margin keeps the caret comfortably above the
  /// viewport bottom.
  final double keepInViewBottomMargin;

  TypewriterScrollConfig copyWith({
    bool? enabled,
    double? centerAlignment,
    Duration? scrollDuration,
    Curve? scrollCurve,
    double? keepInViewTopMargin,
    double? keepInViewBottomMargin,
  }) {
    return TypewriterScrollConfig(
      enabled: enabled ?? this.enabled,
      centerAlignment: centerAlignment ?? this.centerAlignment,
      scrollDuration: scrollDuration ?? this.scrollDuration,
      scrollCurve: scrollCurve ?? this.scrollCurve,
      keepInViewTopMargin: keepInViewTopMargin ?? this.keepInViewTopMargin,
      keepInViewBottomMargin:
          keepInViewBottomMargin ?? this.keepInViewBottomMargin,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TypewriterScrollConfig &&
        other.enabled == enabled &&
        other.centerAlignment == centerAlignment &&
        other.scrollDuration == scrollDuration &&
        other.scrollCurve == scrollCurve &&
        other.keepInViewTopMargin == keepInViewTopMargin &&
        other.keepInViewBottomMargin == keepInViewBottomMargin;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        centerAlignment,
        scrollDuration,
        scrollCurve,
        keepInViewTopMargin,
        keepInViewBottomMargin,
      );
}