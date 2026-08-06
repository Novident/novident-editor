import 'package:novident_editor_selection/novident_editor_selection.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:flutter/material.dart';

/// Changes cursor color and style based on the node type where the
/// cursor is positioned.
///
/// - Headings → orange, thicker
/// - Quotes → purple, border style
/// - Code blocks → green
/// - Default → editor color
class BlockAwareCursorRenderer extends DefaultSelectionRenderer {
  const BlockAwareCursorRenderer();

  Color _colorForNode(String? type, Color fallback) {
    return switch (type) {
      'heading' => Colors.orange,
      'quote' => Colors.purple,
      'code' => Colors.green,
      _ => fallback,
    };
  }

  CursorStyle _styleForNode(String? type) {
    return switch (type) {
      'quote' => CursorStyle.borderLine,
      _ => CursorStyle.verticalLine,
    };
  }

  @override
  Widget buildCursor(CursorPaintContext ctx) {
    return Cursor(
      rect: ctx.rect,
      color: _colorForNode(ctx.node.type, ctx.color),
      cursorStyle: _styleForNode(ctx.node.type),
      shouldBlink: ctx.shouldBlink,
    );
  }

  @override
  Widget buildExpandedHeadCursor(CursorPaintContext ctx) {
    return Cursor(
      rect: ctx.rect,
      color: _colorForNode(ctx.node.type, ctx.color),
      cursorStyle: _styleForNode(ctx.node.type),
      shouldBlink: false,
    );
  }
}
