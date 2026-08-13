import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class SelectionAreaPainter extends CustomPainter {
  SelectionAreaPainter({
    required this.rects,
    required this.selectionColor,
    this.minRectWidth = 8.0,
    this.headRectIndex,
    this.headColor,
  });

  final List<Rect> rects;
  final Color selectionColor;

  /// Width used for zero-width rects so the selection is still visible
  /// (e.g. at the end of a line with no content). Defaults to 8.0.
  final double minRectWidth;

  /// The index of the head rect within [rects], or `null`. When non-null,
  /// loops in [rects] and using [headRectIndex] is painted with [headColor] instead of
  /// [selectionColor].
  ///
  /// Flutter only returns 1 [Rect] covering the exact positions
  /// using `getBoxesForSelection`. So, the [head] need to be added 
  /// manually that specific [Rect]
  final int? headRectIndex;

  /// The color for the head rect. Ignored if [headRectIndex] is `null`.
  final Color? headColor;

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveHeadColor = headColor;
    final effectiveHeadIndex = headRectIndex;

    final defaultPaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.fill;

    final headPaint = (effectiveHeadIndex != null && effectiveHeadColor != null)
        ? (Paint()
          ..color = effectiveHeadColor
          ..style = PaintingStyle.fill)
        : null;

    for (var i = 0; i < rects.length; i++) {
      var rect = rects[i];
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
        i == effectiveHeadIndex ? (headPaint ?? defaultPaint) : defaultPaint,
      );
    }
  }

  @override
  bool shouldRepaint(SelectionAreaPainter oldDelegate) {
    return selectionColor != oldDelegate.selectionColor ||
        minRectWidth != oldDelegate.minRectWidth ||
        headRectIndex != oldDelegate.headRectIndex ||
        headColor != oldDelegate.headColor ||
        !const DeepCollectionEquality().equals(rects, oldDelegate.rects);
  }
}
