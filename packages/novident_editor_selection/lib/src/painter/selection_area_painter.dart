import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class SelectionAreaPainter extends CustomPainter {
  SelectionAreaPainter({
    required this.rects,
    required this.selectionColor,
    this.minRectWidth = 8.0,
  });

  final List<Rect> rects;
  final Color selectionColor;

  /// Width used for zero-width rects so the selection is still visible
  /// (e.g. at the end of a line with no content). Defaults to 8.0.
  final double minRectWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.fill;

    for (var rect in rects) {
      // if rect.width is 0, we draw a small rect to indicate the selection area
      if (rect.width <= 0) {
        rect = Rect.fromLTWH(
          rect.left,
          rect.top,
          minRectWidth,
          rect.height,
        );
      }
      canvas.drawRect(
        rect,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SelectionAreaPainter oldDelegate) {
    return selectionColor != oldDelegate.selectionColor ||
        minRectWidth != oldDelegate.minRectWidth ||
        !const DeepCollectionEquality().equals(rects, oldDelegate.rects);
  }
}
