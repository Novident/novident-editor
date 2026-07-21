import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'dynamic_height_controller.dart';

/// Mixin for block component [State] classes that report their measured
/// height to a [DynamicHeightController] after every layout pass.
///
/// The controller is obtained from the widget tree via
/// [DynamicHeightControllerProvider]. If no controller is found, the
/// reporter silently does nothing.
///
/// Requirements for the using class:
/// - Must provide a [node] getter returning the block's [Node].
/// - Must call [scheduleHeightReport] in [State.initState] and
///   [State.didUpdateWidget].
mixin BlockHeightReporter<T extends StatefulWidget> on State<T> {
  /// The node associated with this block.
  Node get node;

  DynamicHeightController? _controller;
  double? _lastReportedHeight;

  DynamicHeightController? _findController() {
    if (_controller != null) return _controller;
    final provider = context
        .findAncestorWidgetOfExactType<DynamicHeightControllerProvider>();
    if (provider != null) {
      _controller = provider.controller;
    }
    return _controller;
  }

  /// Schedules a height report for after the current frame's layout.
  ///
  /// Safe to call multiple times within the same frame; duplicate
  /// callbacks are harmless (the cache ignores unchanged values).
  void scheduleHeightReport() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportHeightIfChanged();
    });
  }

  void _reportHeightIfChanged() {
    final controller = _findController();
    if (controller == null || !mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final nodeIndex = _getNodeIndex();
    if (nodeIndex < 0) return;

    final height = renderBox.size.height;

    if (_lastReportedHeight != null &&
        (_lastReportedHeight! - height).abs() < 1.0) {
      return;
    }

    _lastReportedHeight = height;
    controller.reportBlockHeight(nodeIndex, height);
  }

  int _getNodeIndex() {
    final parent = node.parent;
    if (parent == null) return -1;
    return parent.children.indexOf(node);
  }
}

/// [InheritedWidget] that provides a [DynamicHeightController] to the
/// block subtree.
///
/// Placed at the root of the editor layout by [DynamicHeightLayout].
class DynamicHeightControllerProvider extends InheritedWidget {
  /// Creates a provider for the given [controller].
  const DynamicHeightControllerProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The controller available to descendant blocks.
  final DynamicHeightController controller;

  /// Returns the controller from the nearest ancestor provider, or null.
  static DynamicHeightController? maybeOf(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<
        DynamicHeightControllerProvider>();
    return provider?.controller;
  }

  /// Returns the controller from the nearest ancestor provider.
  ///
  /// Throws an assertion error in debug mode if no provider is found.
  static DynamicHeightController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'DynamicHeightControllerProvider not found in widget tree',
    );
    return controller!;
  }

  @override
  bool updateShouldNotify(DynamicHeightControllerProvider oldWidget) {
    return controller != oldWidget.controller;
  }
}
