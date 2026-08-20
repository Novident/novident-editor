import 'package:flutter/material.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

/// A selection highlight widget that paints rectangles with an animated
/// gradient. The gradient rotates continuously when [withAnimation] is true.
///
/// All animation parameters are customizable:
/// - [colors]: the gradient colors (defaults to a purple→pink→gold rainbow)
/// - [duration]: one full rotation cycle (default 4 seconds)
/// - [curve]: easing curve for the rotation (default `bounceInOut`)
class AnimatedSelectionAreaPaint extends StatefulWidget {
  const AnimatedSelectionAreaPaint({
    super.key,
    required this.rects,
    this.withAnimation = false,
    this.colors = const [
      Color.fromARGB(255, 65, 88, 208),
      Color.fromARGB(255, 200, 80, 192),
      Color.fromARGB(255, 255, 204, 112),
    ],
    this.duration = const Duration(seconds: 4),
    this.curve = Curves.bounceInOut,
  });

  /// The rectangles to fill with the gradient.
  final List<Rect> rects;

  /// Whether the gradient rotates over time.
  final bool withAnimation;

  /// The gradient colors. Must have at least 2 colors.
  final List<Color> colors;

  /// Duration of one full gradient rotation cycle.
  final Duration duration;

  /// Easing curve applied to the rotation tween.
  final Curve curve;

  @override
  State<AnimatedSelectionAreaPaint> createState() =>
      _AnimatedSelectionAreaPaintState();
}

class _AnimatedSelectionAreaPaintState extends State<AnimatedSelectionAreaPaint>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    if (widget.withAnimation) {
      controller = AnimationController(
        duration: widget.duration,
        vsync: this,
      );
      animation = Tween<double>(begin: 0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: widget.curve,
        ),
      );
      controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget builder(double value) {
      return CustomPaint(
        painter: AnimatedSelectionAreaPainter(
          colors: widget.colors,
          animation: value,
          rects: widget.rects,
        ),
      );
    }

    if (!widget.withAnimation) {
      return builder(1.0);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) {
        return builder(animation.value);
      },
    );
  }

  @override
  void dispose() {
    if (widget.withAnimation) {
      controller.dispose();
    }

    super.dispose();
  }
}
