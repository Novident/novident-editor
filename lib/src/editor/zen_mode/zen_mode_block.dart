import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Wraps a top-level block and provides its zen dimming state.
///
/// Replaces the old opacity-based wrapper: for text blocks the dimming is
/// applied by [ZenSpanPipeline] through the [ZenModeScope] (a pure style
/// change, no widget). Only node types in [wrapNonTextTypes] (e.g. images,
/// which have no text spans to style) get a cheap static [Opacity] wrapper.
///
/// The widget subscribes to the current selection exposed by the controller
/// and only calls [State.setState] when **its own** dimmed state flips —
/// typing inside the same block never rebuilds it, and a focus change
/// rebuilds only the two affected blocks (O(1), not O(N)).
class ZenModeBlock extends StatefulWidget {
  const ZenModeBlock({
    super.key,
    required this.configuration,
    required this.selection,
    required this.node,
    required this.child,
    this.wrapNonTextTypes = const {ImageBlockKeys.type},
  });

  /// The zen mode configuration source, usually a `ZenModeController`.
  final ValueListenable<ZenModeConfiguration> configuration;

  /// The current selection exposed by the controller. The block is dimmed
  /// when its node is not in the selection (see [_ZenModeBlockState._isFocused]).
  final ValueListenable<Selection?> selection;

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

  /// The normalized selection start/end paths that determined [_dimmed].
  ///
  /// The dimmed state depends only on these paths (not the offsets), so when
  /// they are unchanged — e.g. typing inside the same block — the focus
  /// recompute is skipped entirely instead of re-running `inSelection` on
  /// every keystroke.
  (Path, Path)? _lastSelectionPaths;

  @override
  void initState() {
    super.initState();
    _dimmed = _computeDimmed();
    widget.configuration.addListener(_onChanged);
    widget.selection.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ZenModeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration) {
      oldWidget.configuration.removeListener(_onChanged);
      widget.configuration.addListener(_onChanged);
    }
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_onChanged);
      widget.selection.addListener(_onChanged);
    }
    // the node may have changed (virtualized list recycling) — force a
    // recompute against the new node.
    _lastSelectionPaths = null;
    _onChanged();
  }

  @override
  void dispose() {
    widget.configuration.removeListener(_onChanged);
    widget.selection.removeListener(_onChanged);
    super.dispose();
  }

  bool _computeDimmed() {
    final config = widget.configuration.value;
    final selection = widget.selection.value;
    if (!config.enabled || selection == null) {
      return false;
    }
    return !_isFocused(widget.node, selection);
  }

  bool _isFocused(Node node, Selection selection) {
    final path = node.path;
    final normalized = selection.normalized;
    return path.inSelection(selection) ||
        path.isAncestorOf(normalized.start.path) ||
        path.isAncestorOf(normalized.end.path);
  }

  void _onChanged() {
    final config = widget.configuration.value;
    final selection = widget.selection.value;
    if (!config.enabled || selection == null) {
      _setDimmed(false);
      _lastSelectionPaths = null;
      return;
    }
    final normalized = selection.normalized;
    final startPath = normalized.start.path;
    final endPath = normalized.end.path;
    // The dimmed state depends only on the selection's paths, not its
    // offsets. When they are unchanged (e.g. typing inside the same block),
    // skip the focus recompute entirely.
    if (_lastSelectionPaths != null &&
        _lastSelectionPaths!.$1.equals(startPath) &&
        _lastSelectionPaths!.$2.equals(endPath)) {
      return;
    }
    _lastSelectionPaths = (startPath, endPath);
    _setDimmed(!_isFocused(widget.node, selection));
  }

  void _setDimmed(bool dimmed) {
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
