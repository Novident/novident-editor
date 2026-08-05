import 'package:flutter/material.dart';
import 'package:novident_selection/novident_selection.dart';

/// Animated rainbow gradient selection highlight that cycles through
/// colors over time.
///
/// Uses [AnimatedSelectionAreaPaint] from novident_selection's painter
/// with a 4-second looped animation.
class RainbowSelectionRenderer extends DefaultSelectionRenderer {
  const RainbowSelectionRenderer();

  @override
  Widget buildSelectionHighlight(SelectionPaintContext ctx) {
    return AnimatedSelectionAreaPaint(
      rects: ctx.rects,
      withAnimation: true,
    );
  }
}
