import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

/// Applies the typewriter (centered) scrolling configured on
/// [EditorState.typewriter].
///
/// Keeps the focused block vertically centered in the viewport as the
/// selection moves, driving the [EditorScrollController]. It is independent
/// from zen mode: attach it with or without a `ZenModeController`.
///
/// Usage:
///
/// ```dart
/// final editorState = EditorState.blank();
/// editorState.typewriter = const TypewriterScrollConfig();
///
/// final typewriterController = TypewriterScrollController();
/// typewriterController.attach(
///   editorState: editorState,
///   scrollController: scrollController,
/// );
///
/// NovidentEditor(
///   editorState: editorState,
///   editorScrollController: scrollController,
///   // avoid fighting between the native caret auto-scroll and the
///   // typewriter centering.
///   disableAutoScroll: typewriterController.shouldDisableNativeAutoScroll,
/// );
/// ```
///
/// Remember to call [dispose] (or at least [detach]) when the editor goes
/// away.
class TypewriterScrollController {
  EditorState? _editorState;
  EditorScrollController? _scrollController;
  int? _lastTopLevelIndex;

  /// Whether the native caret auto-scroll should be disabled.
  ///
  /// Pass it to [NovidentEditor.disableAutoScroll] so the built-in
  /// follow-the-caret scrolling doesn't fight the typewriter centering.
  bool get shouldDisableNativeAutoScroll =>
      _editorState?.typewriter.enabled ?? false;

  /// Binds the controller to an [editorState] and, optionally, to the
  /// [EditorScrollController] used by the editor (required for the
  /// centering).
  void attach({
    required EditorState editorState,
    EditorScrollController? scrollController,
  }) {
    detach();
    _editorState = editorState;
    _scrollController = scrollController;
    editorState.selectionNotifier.addListener(_onSelectionChanged);
  }

  /// Unbinds the controller.
  void detach() {
    _editorState?.selectionNotifier.removeListener(_onSelectionChanged);
    _editorState = null;
    _scrollController = null;
    _lastTopLevelIndex = null;
  }

  /// Unbinds the controller. Call it when the editor goes away.
  void dispose() {
    detach();
  }

  /// Scrolls the editor so the top-level block at [topLevelIndex] is
  /// positioned at [TypewriterScrollConfig.centerAlignment] of the viewport.
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
        'TypewriterScrollController: centering is not supported '
        'in shrinkWrap mode',
      );
      return;
    }
    final itemScrollController = scrollController.itemScrollController;
    if (!itemScrollController.isAttached) {
      return;
    }

    final config = editorState.typewriter;
    // when a header is present, the list item index is shifted by one.
    final index =
        (topLevelIndex + (editorState.showHeader ? 1 : 0)).clamp(0, 1 << 31);
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
    final config = editorState.typewriter;
    if (!config.enabled) {
      _lastTopLevelIndex = null;
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
}