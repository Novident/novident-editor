import 'package:flutter/material.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_selection/novident_selection.dart';

/// Vim-style block cursor that covers the character under the caret
/// with a semi-transparent background and inverts the text color.
///
/// Uses [CursorMeasureContext.renderParagraph] to measure the character
/// width for accurate block sizing when available.
class VimCursorRenderer extends DefaultSelectionRenderer {
  const VimCursorRenderer();

  @override
  Widget buildCursor(CursorPaintContext ctx) {
    final char = _charAtPosition(ctx.node, ctx.position.offset);
    return Positioned(
      left: ctx.rect.left,
      top: ctx.rect.top,
      child: Container(
        width: ctx.rect.width.clamp(8.0, 20.0),
        height: ctx.rect.height,
        color: ctx.color.withAlpha(60),
        alignment: Alignment.center,
        child: Text(
          char,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildExpandedHeadCursor(CursorPaintContext ctx) {
    return buildCursor(ctx);
  }

  String _charAtPosition(Node node, int offset) {
    final delta = node.delta;
    if (delta == null) return '';
    final text = delta.toPlainText();
    if (offset < 0 || offset >= text.length) return ' ';
    return text[offset];
  }
}
