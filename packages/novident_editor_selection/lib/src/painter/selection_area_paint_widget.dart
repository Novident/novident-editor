import 'package:flutter/material.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

class SelectionAreaPaint extends StatelessWidget {
  const SelectionAreaPaint({
    super.key,
    required this.rects,
    required this.selectionColor,
    this.minRectWidth = 8.0,
  });

  final List<Rect> rects;
  final Color selectionColor;

  /// Width used for zero-width rects so the selection is still visible.
  /// Defaults to 8.0.
  final double minRectWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SelectionAreaPainter(
        rects: rects,
        selectionColor: selectionColor,
        minRectWidth: minRectWidth,
      ),
    );
  }
}
