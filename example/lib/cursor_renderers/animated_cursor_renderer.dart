import 'package:flutter/material.dart';
import 'package:novident_selection/novident_selection.dart';

/// Smooth animated cursor using [AnimatedPositioned] that transitions
/// between positions with [Curves.easeOut] over 150ms.
///
/// Uses the node ID and position as a key so Flutter preserves the
/// widget across rebuilds and animates the position transition.
class AnimatedCursorRenderer extends DefaultSelectionRenderer {
  const AnimatedCursorRenderer();

  @override
  Widget buildCursor(CursorPaintContext ctx) {
    return Positioned.fill(
      child: Stack(
        children: [
          AnimatedPositioned(
            key: ValueKey('cursor_${ctx.node.id}'),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            left: ctx.rect.left,
            top: ctx.rect.top,
            width: ctx.rect.width,
            height: ctx.rect.height,
            child: Container(color: ctx.color),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildExpandedHeadCursor(CursorPaintContext ctx) {
    return AnimatedPositioned(
      key: ValueKey('head_${ctx.node.id}'),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      left: ctx.rect.left,
      top: ctx.rect.top,
      width: ctx.rect.width,
      height: ctx.rect.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ctx.color, width: 2),
        ),
      ),
    );
  }
}
