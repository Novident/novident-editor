import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'zen_mode_configuration.dart';
import 'zen_mode_scope.dart';

/// Wraps a top-level block and provides its zen dimming state.
///
/// Replaces the old opacity-based wrapper: for text blocks the dimming is
/// applied by [ZenSpanPipeline] through the [ZenModeScope] (a pure style
/// change, no widget). Only node types in [wrapNonTextTypes] (e.g. images,
/// which have no text spans to style) get a cheap static [Opacity] wrapper.
///
/// The widget subscribes to the focused top-level range exposed by the
/// controller and only calls [State.setState] when **its own** dimmed state
/// flips — typing inside the same block never rebuilds it, and a focus
/// change rebuilds only the two affected blocks (O(1), not O(N)).
class ZenModeBlock extends StatefulWidget {
  const ZenModeBlock({
    super.key,
    required this.configuration,
    required this.focusedTopLevelRange,
    required this.node,
    required this.child,
    this.wrapNonTextTypes = const {ImageBlockKeys.type},
  });

  /// The zen mode configuration source, usually a `ZenModeController`.
  final ValueListenable<ZenModeConfiguration> configuration;

  /// The top-level block range covered by the selection, exposed by the
  /// controller as a `ValueNotifier<({int start, int end})?>`.
  final ValueListenable<({int start, int end})?> focusedTopLevelRange;

  /// The top-level node wrapped by this widget.
  final Node node;

  final Widget child;

  /// Node types that need a visual wrapper because they have no text spans
  /// to dim via the pipeline (e.g. images). Customize to add more.
  final Set<String> wrapNonTextTypes;

  @override
  State<ZenModeBlock> createState() => _ZenModeBlockState();
}

class _ZenModeBlockState extends State<ZenModeBlock> {
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    _dimmed = _computeDimmed();
    widget.configuration.addListener(_onChanged);
    widget.focusedTopLevelRange.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ZenModeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration) {
      oldWidget.configuration.removeListener(_onChanged);
      widget.configuration.addListener(_onChanged);
    }
    if (oldWidget.focusedTopLevelRange != widget.focusedTopLevelRange) {
      oldWidget.focusedTopLevelRange.removeListener(_onChanged);
      widget.focusedTopLevelRange.addListener(_onChanged);
    }
    // re-evaluate with the new widget (e.g. a different node).
    _onChanged();
  }

  @override
  void dispose() {
    widget.configuration.removeListener(_onChanged);
    widget.focusedTopLevelRange.removeListener(_onChanged);
    super.dispose();
  }

  bool _computeDimmed() {
    final config = widget.configuration.value;
    final range = widget.focusedTopLevelRange.value;
    if (!config.enabled || range == null) {
      return false;
    }
    final index = widget.node.path.first;
    return !(range.start <= index && index <= range.end);
  }

  void _onChanged() {
    final dimmed = _computeDimmed();
    if (dimmed != _dimmed) {
      setState(() => _dimmed = dimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration.value;
    Widget child = ZenModeScope(
      dimmed: _dimmed,
      unfocusedOpacity: config.unfocusedOpacity,
      configuration: config,
      child: widget.child,
    );
    if (_dimmed && widget.wrapNonTextTypes.contains(widget.node.type)) {
      child = Opacity(
        opacity: config.unfocusedOpacity,
        child: child,
      );
    }
    return child;
  }
}