import 'package:flutter/widgets.dart';

import 'zen_mode_configuration.dart';

/// Provides the zen dimming state of a top-level block to its descendants.
///
/// Created by [ZenModeBlock] (one per top-level block) and read by
/// [ZenSpanPipeline.resolveStyle] to apply the dimmed colors. Descendants
/// (including nested blocks) inherit the scope of their top-level ancestor.
class ZenModeScope extends InheritedWidget {
  const ZenModeScope({
    super.key,
    required this.dimmed,
    required this.unfocusedOpacity,
    required this.configuration,
    required super.child,
  });

  /// Whether this block is currently dimmed (zen enabled and not focused).
  final bool dimmed;

  /// Opacity factor used to compute the dimmed text color.
  final double unfocusedOpacity;

  /// The active zen configuration (ignore flags).
  final ZenModeConfiguration configuration;

  /// Reads the scope, registering a dependency so the caller rebuilds when
  /// the dimmed state changes.
  ///
  /// The text spans are resolved through [ZenSpanPipeline.resolveStyle], which
  /// is called during build; registering the dependency is what makes the text
  /// re-resolve when [ZenModeBlock] flips its dimmed state (a collapsed
  /// selection change does not rebuild the block component on its own).
  /// Returns `null` when [context] is null or no scope is present.
  static ZenModeScope? maybeOf(BuildContext? context) {
    if (context == null) {
      return null;
    }
    return context.dependOnInheritedWidgetOfExactType<ZenModeScope>();
  }

  @override
  bool updateShouldNotify(ZenModeScope oldWidget) =>
      dimmed != oldWidget.dimmed ||
      unfocusedOpacity != oldWidget.unfocusedOpacity ||
      configuration != oldWidget.configuration;
}