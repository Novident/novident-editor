import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Root layout widget for the editor in dynamic height mode.
///
/// Replaces [PageBlockComponent] when the editor is configured with
/// [DynamicHeightConfig]. The layout consists of a [Column] with
/// [MainAxisSize.min] inside a [ConstrainedBox] that enforces
/// [DynamicHeightConfig.minHeight].
///
/// Each block is wrapped with padding and max-width constraints from
/// [EditorStyle]. Header and footer widgets are rendered before and
/// after the blocks, respectively.
///
/// The [DynamicHeightController] is provided to the block subtree via
/// [DynamicHeightControllerProvider]. If no external controller is
/// given, one is created internally and disposed with this widget.
class DynamicHeightLayout extends StatefulWidget {
  /// Creates a dynamic height layout for the editor.
  ///
  /// At least one of [controller] or [config] must be provided. If only
  /// [config] is given, a [DynamicHeightController] is created internally.
  const DynamicHeightLayout({
    super.key,
    required this.node,
    required this.editorState,
    this.header,
    this.footer,
    this.wrapper,
    this.controller,
    this.config,
  });

  /// Root node of the document (type 'page').
  final Node node;

  /// The editor state.
  final EditorState editorState;

  /// Optional widget rendered before the blocks.
  final Widget? header;

  /// Optional widget rendered after the blocks.
  final Widget? footer;

  /// Optional wrapper around each block.
  final BlockComponentWrapper? wrapper;

  /// External controller for dynamic height.
  final DynamicHeightController? controller;

  /// Configuration used when no external controller is provided.
  final DynamicHeightConfig? config;

  @override
  State<DynamicHeightLayout> createState() => _DynamicHeightLayoutState();
}

class _DynamicHeightLayoutState extends State<DynamicHeightLayout> {
  DynamicHeightController? _controller;
  bool _ownsController = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _createInternalController();
    _controller!.addListener(_onHeightChanged);
    widget.node.addListener(_onNodeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && mounted) {
      _initialized = true;
      _controller!.initialize(widget.node.children.length);
    }
  }

  @override
  void didUpdateWidget(covariant DynamicHeightLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) _controller?.dispose();
      _controller?.removeListener(_onHeightChanged);
      _controller = widget.controller ?? _createInternalController();
      _controller!.addListener(_onHeightChanged);
      _initialized = false;
    }
  }

  @override
  void dispose() {
    widget.node.removeListener(_onNodeChanged);
    _controller?.removeListener(_onHeightChanged);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  void _onNodeChanged() {
    if (mounted) setState(() {});
  }

  void _onHeightChanged() {
    if (mounted) setState(() {});
  }

  DynamicHeightController _createInternalController() {
    _ownsController = true;
    return DynamicHeightController(
      config: widget.config ?? const DynamicHeightConfig(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.node.children;

    // Always a plain Column: the ListView.builder branch was dead code
    // (hasMeasuredBlocks never became true) and, once it would, it broke
    // the editor's initial IntrinsicHeight pass ("RenderViewport does not
    // support returning intrinsic dimensions").
    final Widget blockList = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items
          .map((e) => _buildBlock(context, e))
          .toList(growable: false),
    );

    return DynamicHeightControllerProvider(
      controller: _controller!,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: _controller!.config.minHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) widget.header!,
            blockList,
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, Node node) {
    Widget child = widget.editorState.renderer.build(context, node);

    if (widget.wrapper != null) {
      child = widget.wrapper!(context, node: node, child: child);
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: widget.editorState.editorStyle.maxWidth ?? double.infinity,
      ),
      padding: widget.editorState.editorStyle.padding,
      child: child,
    );
  }
}
