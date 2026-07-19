import 'package:flutter/material.dart';

/// Configuration for the zen (focus) mode.
///
/// Zen mode helps the user focus on the block being edited by:
///
/// 1. Dimming every top-level block that is **not** focused
///    (see [unfocusedOpacity]).
/// 2. Visually ignoring the text color (`font_color`), highlight color
///    (`bg_color`) and block background color (`bgColor`) attributes.
///    The attributes are **not** removed from the document — they are only
///    ignored while zen mode is enabled.
/// 3. Keeping the focused block vertically centered in the viewport
///    (typewriter-like scrolling).
///
/// This configuration is immutable — use [copyWith] to derive a new one and
/// assign it to a `ZenModeController` to apply changes at runtime.
@immutable
class ZenModeConfiguration {
  const ZenModeConfiguration({
    this.enabled = true,
    this.unfocusedOpacity = 0.35,
    this.fadeDuration = const Duration(milliseconds: 220),
    this.fadeCurve = Curves.easeOut,
    this.ignoreTextColor = true,
    this.ignoreHighlightColor = true,
    this.ignoreBlockBackgroundColor = true,
    this.centerFocusedBlock = true,
    this.centerAlignment = 0.45,
    this.scrollDuration = const Duration(milliseconds: 240),
    this.scrollCurve = Curves.easeOutCubic,
  })  : assert(
          unfocusedOpacity >= 0.0 && unfocusedOpacity <= 1.0,
          'unfocusedOpacity must be between 0.0 and 1.0',
        ),
        assert(
          centerAlignment >= 0.0 && centerAlignment <= 1.0,
          'centerAlignment must be between 0.0 and 1.0',
        );

  /// Whether zen mode is active.
  final bool enabled;

  /// Opacity applied to the top-level blocks that are not focused.
  ///
  /// A block is focused when the current selection starts, ends or passes
  /// through it (including any of its nested children).
  final double unfocusedOpacity;

  /// Duration of the opacity animation when the focus changes.
  final Duration fadeDuration;

  /// Curve of the opacity animation when the focus changes.
  final Curve fadeCurve;

  /// Whether the `font_color` text attribute should be visually ignored.
  ///
  /// The attribute is kept in the document; the text is simply rendered
  /// with the default text color while zen mode is enabled.
  final bool ignoreTextColor;

  /// Whether the `bg_color` (highlight) text attribute should be visually
  /// ignored.
  ///
  /// The attribute is kept in the document; the highlight is simply not
  /// painted while zen mode is enabled. The find & replace highlight
  /// (`find_bg_color`) is never ignored.
  final bool ignoreHighlightColor;

  /// Whether the block-level `bgColor` attribute should be visually ignored.
  ///
  /// The attribute is kept in the document; the block decoration is simply
  /// not painted while zen mode is enabled.
  final bool ignoreBlockBackgroundColor;

  /// Whether the focused block should be kept vertically centered
  /// (typewriter scrolling).
  final bool centerFocusedBlock;

  /// Where the leading edge of the focused block is aligned inside the
  /// viewport when centering: 0.0 = top, 0.5 = center, 1.0 = bottom.
  final double centerAlignment;

  /// Duration of the centering scroll animation.
  final Duration scrollDuration;

  /// Curve of the centering scroll animation.
  final Curve scrollCurve;

  ZenModeConfiguration copyWith({
    bool? enabled,
    double? unfocusedOpacity,
    Duration? fadeDuration,
    Curve? fadeCurve,
    bool? ignoreTextColor,
    bool? ignoreHighlightColor,
    bool? ignoreBlockBackgroundColor,
    bool? centerFocusedBlock,
    double? centerAlignment,
    Duration? scrollDuration,
    Curve? scrollCurve,
  }) {
    return ZenModeConfiguration(
      enabled: enabled ?? this.enabled,
      unfocusedOpacity: unfocusedOpacity ?? this.unfocusedOpacity,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      fadeCurve: fadeCurve ?? this.fadeCurve,
      ignoreTextColor: ignoreTextColor ?? this.ignoreTextColor,
      ignoreHighlightColor: ignoreHighlightColor ?? this.ignoreHighlightColor,
      ignoreBlockBackgroundColor:
          ignoreBlockBackgroundColor ?? this.ignoreBlockBackgroundColor,
      centerFocusedBlock: centerFocusedBlock ?? this.centerFocusedBlock,
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
    return other is ZenModeConfiguration &&
        other.enabled == enabled &&
        other.unfocusedOpacity == unfocusedOpacity &&
        other.fadeDuration == fadeDuration &&
        other.fadeCurve == fadeCurve &&
        other.ignoreTextColor == ignoreTextColor &&
        other.ignoreHighlightColor == ignoreHighlightColor &&
        other.ignoreBlockBackgroundColor == ignoreBlockBackgroundColor &&
        other.centerFocusedBlock == centerFocusedBlock &&
        other.centerAlignment == centerAlignment &&
        other.scrollDuration == scrollDuration &&
        other.scrollCurve == scrollCurve;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        unfocusedOpacity,
        fadeDuration,
        fadeCurve,
        ignoreTextColor,
        ignoreHighlightColor,
        ignoreBlockBackgroundColor,
        centerFocusedBlock,
        centerAlignment,
        scrollDuration,
        scrollCurve,
      );
}
