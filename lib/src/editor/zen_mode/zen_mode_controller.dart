import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Coordinates the zen (focus) mode of the editor.
///
/// The controller is a [ValueNotifier] of [ZenModeConfiguration], so any
/// widget can listen to it to react to configuration changes.
///
/// Usage:
///
/// ```dart
/// final zenController = ZenModeController();
/// final scrollController = EditorScrollController(editorState: editorState);
///
/// zenController.attach(
///   editorState: editorState,
///   scrollController: scrollController,
/// );
///
/// NovidentEditor(
///   editorState: editorState,
///   editorScrollController: scrollController,
///   // avoid fighting between the native caret auto-scroll and the
///   // zen typewriter scrolling (desktop only).
///   disableAutoScroll: zenController.shouldDisableNativeAutoScroll,
///   blockWrapper: zenController.blockWrapper,
///   editorStyle: EditorStyle.desktop(
///     textSpanDecorator: zenController.textSpanDecorator(),
///   ),
/// );
/// ```
///
/// Remember to call [dispose] (or at least [detach]) when the editor goes
/// away.
class ZenModeController extends ValueNotifier<ZenModeConfiguration> {
  ZenModeController({
    ZenModeConfiguration configuration = const ZenModeConfiguration(),
  }) : super(configuration);

  EditorState? _editorState;
  EditorScrollController? _scrollController;
  BlockComponentBackgroundColorDecorator? _previousBlockDecorator;
  bool _ownsBlockDecorator = false;
  int? _lastTopLevelIndex;

  ZenModeConfiguration get configuration => value;
  set configuration(ZenModeConfiguration configuration) =>
      value = configuration;

  bool get enabled => value.enabled;

  /// Whether the native caret auto-scroll should be disabled.
  ///
  /// Pass it to [NovidentEditor.disableAutoScroll] so the built-in
  /// follow-the-caret scrolling doesn't fight the zen typewriter scrolling.
  bool get shouldDisableNativeAutoScroll =>
      value.enabled && value.centerFocusedBlock;

  void toggle() => value = value.copyWith(enabled: !value.enabled);

  @override
  set value(ZenModeConfiguration newValue) {
    final oldValue = super.value;
    super.value = newValue;
    if (oldValue == newValue) {
      return;
    }

    // color neutralization is applied while building the text spans and the
    // block decoration, so the visible blocks must be rebuilt when any of
    // the structural options changes.
    if (_needsBlockRefresh(oldValue, newValue)) {
      _refreshBlocks();
    }

    if (oldValue.enabled != newValue.enabled) {
      _lastTopLevelIndex = null;
      if (newValue.enabled && newValue.centerFocusedBlock) {
        // re-center the block that owns the current selection.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final path = _editorState?.selection?.normalized.start.path;
          if (path != null && path.isNotEmpty) {
            centerBlockAt(path.first);
          }
        });
      }
    }
  }

  /// Binds the controller to an [editorState] and, optionally, to the
  /// [EditorScrollController] used by the editor (required for the
  /// typewriter centering).
  void attach({
    required EditorState editorState,
    EditorScrollController? scrollController,
  }) {
    detach();
    _editorState = editorState;
    _scrollController = scrollController;
    editorState.selectionNotifier.addListener(_onSelectionChanged);

    // chain the global block background decorator so the block-level
    // `bgColor` attribute can be visually ignored without removing it.
    _previousBlockDecorator = blockComponentDecorator;
    blockComponentDecorator = _zenBlockBackgroundDecorator;
    _ownsBlockDecorator = true;
  }

  /// Unbinds the controller and restores the previous global block
  /// background decorator.
  void detach() {
    _editorState?.selectionNotifier.removeListener(_onSelectionChanged);
    _editorState = null;
    _scrollController = null;
    _lastTopLevelIndex = null;
    if (_ownsBlockDecorator) {
      blockComponentDecorator = _previousBlockDecorator;
      _previousBlockDecorator = null;
      _ownsBlockDecorator = false;
    }
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  /// A [BlockComponentWrapper] that dims the unfocused top-level blocks.
  ///
  /// Pass it (as a tear-off) to [NovidentEditor.blockWrapper].
  Widget blockWrapper(
    BuildContext context, {
    required Node node,
    required Widget child,
  }) {
    final editorState =
        _editorState ?? Provider.of<EditorState>(context, listen: false);
    return ZenModeBlockWrapper(
      editorState: editorState,
      configuration: this,
      node: node,
      child: child,
    );
  }

  /// A [TextSpanDecoratorForAttribute] that visually ignores the text and
  /// highlight color attributes while zen mode is enabled.
  ///
  /// Pass it to [EditorStyle.textSpanDecorator]. The [inner] decorator is
  /// invoked afterwards and defaults to
  /// [defaultTextSpanDecoratorForAttribute] to keep the built-in link
  /// behavior.
  TextSpanDecoratorForAttribute textSpanDecorator({
    TextSpanDecoratorForAttribute? inner = defaultTextSpanDecoratorForAttribute,
  }) {
    return zenModeTextSpanDecorator(configuration: this, inner: inner);
  }

  /// Scrolls the editor so the top-level block at [topLevelIndex] is
  /// positioned at [ZenModeConfiguration.centerAlignment] of the viewport.
  ///
  /// Requires a non-shrinkWrap [EditorScrollController] passed to [attach];
  /// otherwise this is a no-op.
  void centerBlockAt(int topLevelIndex, {bool animated = true}) {
    final editorState = _editorState;
    final scrollController = _scrollController;
    if (editorState == null || scrollController == null) {
      return;
    }
    if (scrollController.shrinkWrap) {
      // the ItemScrollController is not available in shrinkWrap mode.
      NovidentEditorLog.editor.debug(
        'ZenModeController: centering is not supported in shrinkWrap mode',
      );
      return;
    }
    final itemScrollController = scrollController.itemScrollController;
    if (!itemScrollController.isAttached) {
      return;
    }

    // when a header is present, the list item index is shifted by one.
    final index =
        (topLevelIndex + (editorState.showHeader ? 1 : 0)).clamp(0, 1 << 31);
    final config = value;
    if (animated && config.scrollDuration > Duration.zero) {
      itemScrollController.scrollTo(
        index: index,
        alignment: config.centerAlignment,
        duration: config.scrollDuration,
        curve: config.scrollCurve,
      );
    } else {
      itemScrollController.jumpTo(
        index: index,
        alignment: config.centerAlignment,
      );
    }
  }

  void _onSelectionChanged() {
    final editorState = _editorState;
    if (editorState == null) {
      return;
    }
    final config = value;
    if (!config.enabled || !config.centerFocusedBlock) {
      return;
    }
    final selection = editorState.selection;
    if (selection == null) {
      _lastTopLevelIndex = null;
      return;
    }
    if (editorState.selectionUpdateReason == SelectionUpdateReason.selectAll) {
      return;
    }
    final path = selection.normalized.start.path;
    if (path.isEmpty) {
      return;
    }
    final topLevelIndex = path.first;
    // only re-center when the focused top-level block changes.
    if (_lastTopLevelIndex == topLevelIndex) {
      return;
    }
    _lastTopLevelIndex = topLevelIndex;

    // wait for the layout of the new selection before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      centerBlockAt(topLevelIndex);
    });
  }

  bool _needsBlockRefresh(
    ZenModeConfiguration oldValue,
    ZenModeConfiguration newValue,
  ) {
    return oldValue.enabled != newValue.enabled ||
        oldValue.ignoreTextColor != newValue.ignoreTextColor ||
        oldValue.ignoreHighlightColor != newValue.ignoreHighlightColor ||
        oldValue.ignoreBlockBackgroundColor !=
            newValue.ignoreBlockBackgroundColor;
  }

  /// Rebuilds every top-level block so the text spans and block decorations
  /// are regenerated with the current configuration.
  void _refreshBlocks() {
    final editorState = _editorState;
    if (editorState == null) {
      return;
    }
    for (final node in editorState.document.root.children) {
      node.notify();
    }
  }

  Decoration? _zenBlockBackgroundDecorator(Node node, String colorString) {
    if (value.enabled && value.ignoreBlockBackgroundColor) {
      // neutral decoration: the attribute is kept in the document, only its
      // paint is skipped. Returning null here would fall back to the default
      // BoxDecoration(color: ...) of BlockComponentBackgroundColorMixin.
      return const BoxDecoration();
    }
    return _previousBlockDecorator?.call(node, colorString);
  }
}
