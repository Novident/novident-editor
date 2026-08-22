import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/selection/shared.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

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
///   blockWrapper: zenController.blockWrapper,
/// );
/// ```
///
/// The zen dimming is applied through the span pipeline: [attach] registers
/// a [ZenSpanPipeline] wrapper on the [EditorState] that composes over the
/// effective pipeline (spell check or default). No `textSpanDecorator` is
/// needed. Typewriter scrolling is a separate feature — see
/// [TypewriterScrollController].
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

  /// The top-level block range covered by the selection, updated only when
  /// it changes. Wrappers listen to this instead of the full selection
  /// notifier, so typing inside the same block never rebuilds them.
  final ValueNotifier<({int start, int end})?> _focusedTopLevelRange =
      ValueNotifier(null);

  /// The top-level block range covered by the selection, or `null` when no
  /// block is focused (zen disabled, no selection, or select-all).
  ValueListenable<({int start, int end})?> get focusedTopLevelRange =>
      _focusedTopLevelRange;

  ZenModeConfiguration get configuration => value;
  set configuration(ZenModeConfiguration configuration) =>
      value = configuration;

  bool get enabled => value.enabled;

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
      if (newValue.enabled) {
        // initialize the focused range from the current selection so the
        // wrappers dim correctly as soon as zen is turned on.
        _refreshFocusedRange();
      } else {
        _focusedTopLevelRange.value = null;
      }
    }
  }

  /// Binds the controller to an [editorState] and, optionally, to the
  /// [EditorScrollController] used by the editor (required to refresh only
  /// the visible blocks).
  void attach({
    required EditorState editorState,
    EditorScrollController? scrollController,
  }) {
    detach();
    _editorState = editorState;
    _scrollController = scrollController;
    editorState.selectionNotifier.addListener(_onSelectionChanged);

    // compose the zen dimming on top of the effective span pipeline
    // (spell check or default) without coupling to it.
    editorState.setSpanPipelineWrapper(
      (effective) => ZenSpanPipeline(effective),
    );

    // chain the global block background decorator so the block-level
    // `bgColor` attribute can be visually ignored without removing it.
    _previousBlockDecorator = blockComponentDecorator;
    blockComponentDecorator = _zenBlockBackgroundDecorator;
    _ownsBlockDecorator = true;
  }

  /// Unbinds the controller and restores the previous global block
  /// background decorator and the effective span pipeline.
  void detach() {
    _editorState?.selectionNotifier.removeListener(_onSelectionChanged);
    _editorState?.clearSpanPipelineWrapper();
    _editorState = null;
    _scrollController = null;
    if (_ownsBlockDecorator) {
      blockComponentDecorator = _previousBlockDecorator;
      _previousBlockDecorator = null;
      _ownsBlockDecorator = false;
    }
  }

  @override
  void dispose() {
    detach();
    _focusedTopLevelRange.dispose();
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
    return ZenModeBlock(
      configuration: this,
      focusedTopLevelRange: _focusedTopLevelRange,
      node: node,
      child: child,
    );
  }

  void _onSelectionChanged() {
    final editorState = _editorState;
    if (editorState == null) {
      return;
    }
    final config = value;
    if (!config.enabled) {
      _focusedTopLevelRange.value = null;
      return;
    }
    final selection = editorState.selection;
    if (selection == null) {
      _focusedTopLevelRange.value = null;
      return;
    }
    if (editorState.selectionUpdateReason == SelectionUpdateReason.selectAll) {
      // the whole document is selected — nothing is dimmed.
      _focusedTopLevelRange.value = null;
      return;
    }
    final normalized = selection.normalized;
    if (normalized.start.path.isEmpty || normalized.end.path.isEmpty) {
      _focusedTopLevelRange.value = null;
      return;
    }
    final start = normalized.start.path.first;
    final end = normalized.end.path.first;
    final range = (start: start, end: end);
    // only notify the wrappers when the focused range changes.
    if (_focusedTopLevelRange.value != range) {
      _focusedTopLevelRange.value = range;
    }
  }

  /// Recomputes [_focusedTopLevelRange] from the current selection.
  void _refreshFocusedRange() {
    final editorState = _editorState;
    if (editorState == null) {
      _focusedTopLevelRange.value = null;
      return;
    }
    final selection = editorState.selection;
    if (selection == null) {
      _focusedTopLevelRange.value = null;
      return;
    }
    final normalized = selection.normalized;
    if (normalized.start.path.isEmpty || normalized.end.path.isEmpty) {
      _focusedTopLevelRange.value = null;
      return;
    }
    _focusedTopLevelRange.value = (
      start: normalized.start.path.first,
      end: normalized.end.path.first,
    );
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

  /// Rebuilds the visible top-level blocks so the text spans and block
  /// decorations are regenerated with the current configuration.
  ///
  /// Only the visible nodes are notified (the virtualized list does not
  /// build off-screen blocks). When the visible range is not initialized,
  /// falls back to a platform-sized window centered on the focused block.
  void _refreshBlocks() {
    final editorState = _editorState;
    final scrollController = _scrollController;
    if (editorState == null) {
      return;
    }

    var nodes = scrollController != null
        ? editorState.getVisibleNodes(scrollController)
        : const <Node>[];

    if (nodes.isEmpty) {
      nodes = _fallbackNodes(editorState);
    }

    for (final node in nodes) {
      node.notify();
    }
  }

  /// Fallback when the visible range is not initialized: a platform-sized
  /// window centered on the focused block (or the first nodes when there is
  /// no selection). Mobile viewports fit ~300 blocks at most; desktop is
  /// more conservative (~700).
  List<Node> _fallbackNodes(EditorState editorState) {
    final children = editorState.document.root.children;
    if (children.isEmpty) {
      return const [];
    }
    final windowSize = EditorPlatform.isMobile ? 300 : 700;
    final half = windowSize ~/ 2;
    final selection = editorState.selection;
    int start;
    if (selection != null && selection.normalized.start.path.isNotEmpty) {
      final focusedIndex = selection.normalized.start.path.first;
      start = (focusedIndex - half).clamp(0, children.length - 1);
    } else {
      start = 0;
    }
    final end = (start + windowSize).clamp(0, children.length);
    return children.sublist(start, end);
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
