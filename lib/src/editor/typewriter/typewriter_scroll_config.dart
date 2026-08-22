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
  }) : assert(
          centerAlignment >= 0.0 && centerAlignment <= 1.0,
          'centerAlignment must be between 0.0 and 1.0',
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

  TypewriterScrollConfig copyWith({
    bool? enabled,
    double? centerAlignment,
    Duration? scrollDuration,
    Curve? scrollCurve,
  }) {
    return TypewriterScrollConfig(
      enabled: enabled ?? this.enabled,
      centerAlignment: centerAlignment ?? this.centerAlignment,
      scrollDuration: scrollDuration ?? this.scrollDuration,
      scrollCurve: scrollCurve ?? this.scrollCurve,
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
        other.scrollCurve == scrollCurve;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        centerAlignment,
        scrollDuration,
        scrollCurve,
      );
}