import 'package:flutter/material.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

class SelectionAreaPaint extends StatelessWidget {
  const SelectionAreaPaint({
    super.key,
    required this.rects,
    required this.selectionColor,
    this.minRectWidth = 8.0,
    this.headRectIndex,
    this.headColor,
  });

  final List<Rect> rects;
  final Color selectionColor;

  /// Width used for zero-width rects so the selection is still visible.
  /// Defaults to 8.0.
  final double minRectWidth;

  /// The index of the head rect within [rects], or `null`. When non-null,
  /// that rect is painted with [headColor] instead of [selectionColor].
  final int? headRectIndex;

  /// The color for the head rect. Ignored if [headRectIndex] is `null`.
  final Color? headColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SelectionAreaPainter(
        rects: rects,
        selectionColor: selectionColor,
        minRectWidth: minRectWidth,
        headRectIndex: headRectIndex,
        headColor: headColor,
      ),
    );
  }
}
