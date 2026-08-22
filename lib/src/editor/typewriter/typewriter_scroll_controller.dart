import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

const int _maxInt = 1 << 31;

/// Applies the typewriter (centered) scrolling configured on
/// [EditorState.typewriter].
///
/// Keeps the focused block vertically centered in the viewport as the
/// selection moves, driving the [EditorScrollController]. It is independent
/// from zen mode: attach it with or without a `ZenModeController`.
///
/// The strategy:
///
/// 1. When the focused top-level block **changes**, the view centers itself
///    relative to the caret's position at
///    [TypewriterScrollConfig.centerAlignment], in a single scroll. Centering
///    the caret (rather than the block's leading edge) never hides it, and a
///    single scroll avoids the two-step jump of center-then-correct.
/// 2. When the caret moves **within the same block**, the editor does not
///    re-center (that would ping-pong on every keystroke). Instead it keeps
///    the caret inside a vertical "dead zone" box — the central region
///    bounded by [TypewriterScrollConfig.keepInViewTopMargin] and
///    [TypewriterScrollConfig.keepInViewBottomMargin] — and only scrolls when
///    the caret leaves that box, bringing it back just enough to stay inside.
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

  /// Last scroll offset this controller asked the editor to reach. Used to
  /// avoid re-issuing a scroll toward the same target on consecutive selection
  /// changes (which would otherwise fight the in-flight animation and cause a
  /// ping-pong effect).
  double? _lastTargetOffset;

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
    _lastTargetOffset = null;
  }

  /// Unbinds the controller. Call it when the editor goes away.
  void dispose() {
    detach();
  }

  /// Computes the scroll offset (in pixels) that brings [caretRect] — expressed
  /// in viewport-local coordinates, where `0` is the top edge of the viewport
  /// and [viewportHeight] its height — back inside the "dead zone" box
  /// `[topMargin, viewportHeight - bottomMargin]`, given the current
  /// [currentOffset].
  ///
  /// Returns `null` when the caret is already fully inside the box, so no
  /// scroll is needed.
  static double? targetOffsetToKeepInView({
    required Rect caretRect,
    required double viewportHeight,
    required double currentOffset,
    required double topMargin,
    required double bottomMargin,
  }) {
    if (caretRect.top < topMargin) {
      return currentOffset + caretRect.top - topMargin;
    }
    if (caretRect.bottom > viewportHeight - bottomMargin) {
      return currentOffset + caretRect.bottom - (viewportHeight - bottomMargin);
    }
    return null;
  }

  /// Computes the scroll offset (in pixels) that centers [caretRect] —
  /// expressed in viewport-local coordinates — at [centerAlignment] of the
  /// viewport, given the current [currentOffset].
  static double targetOffsetToCenterCaret({
    required Rect caretRect,
    required double viewportHeight,
    required double currentOffset,
    required double centerAlignment,
  }) {
    final center = (caretRect.top + caretRect.bottom) / 2;
    final targetCenter = centerAlignment * viewportHeight;
    return currentOffset + (center - targetCenter);
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
    final index = (topLevelIndex + (editorState.showHeader ? 1 : 0)).clamp(
      0,
      _maxInt,
    );
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
    final previousIndex = _lastTopLevelIndex;
    // only re-center the block when the focused top-level block changes.
    if (previousIndex == topLevelIndex) {
      // caret moved within the same block: keep it inside the dead-zone box
      // instead of re-centering the whole block on every keystroke.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _keepCaretInView();
      });
      return;
    }
    _lastTopLevelIndex = topLevelIndex;
    // a new block invalidates the previous keep-in-view target.
    _lastTargetOffset = null;

    // On a block change, center the view relative to the caret's position in a
    // single scroll (centering the caret never hides it, unlike centering the
    // block's leading edge, and it avoids the two-step jump of center-then-
    // correct).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCaretInView();
    });
  }

  /// Scrolls the editor so the caret is centered at
  /// [TypewriterScrollConfig.centerAlignment] of the viewport, in a single
  /// scroll.
  ///
  /// Used on block changes: centering the caret (rather than the block's
  /// leading edge) never hides it, and doing it in one scroll avoids the
  /// two-step jump of center-then-correct.
  void _centerCaretInView() {
    final editorState = _editorState;
    final scrollController = _scrollController;
    if (editorState == null || scrollController == null) {
      return;
    }
    if (scrollController.shrinkWrap) {
      return;
    }
    final scrollableState = editorState.scrollableState;
    if (scrollableState == null) {
      return;
    }

    final caretInViewport = _caretRectInViewport(editorState, scrollableState);
    if (caretInViewport == null) {
      return;
    }

    final viewportHeight = scrollableState.position.viewportDimension;
    final config = editorState.typewriter;
    final targetOffset = targetOffsetToCenterCaret(
      caretRect: caretInViewport,
      viewportHeight: viewportHeight,
      currentOffset: scrollableState.position.pixels,
      centerAlignment: config.centerAlignment,
    );
    if (targetOffset == _lastTargetOffset) {
      return;
    }
    _lastTargetOffset = targetOffset;

    if (config.scrollDuration > Duration.zero) {
      scrollController.animateTo(
        offset: targetOffset,
        duration: config.scrollDuration,
        curve: config.scrollCurve,
      );
    } else {
      scrollController.scrollOffsetController.jumpTo(offset: targetOffset);
    }
  }

  /// Measures the caret's rect in viewport-local coordinates (relative to the
  /// viewport's top-left), or `null` when it can't be measured.
  static Rect? _caretRectInViewport(
    EditorState editorState,
    ScrollableState scrollableState,
  ) {
    final rects = editorState.selectionRects();
    if (rects.isEmpty) {
      return null;
    }
    final caretRect = rects.reduce((a, b) => a.expandToInclude(b));
    final deltaToOrigin = scrollableState.deltaToScrollOrigin;
    return caretRect.shift(Offset(-deltaToOrigin.dx, -deltaToOrigin.dy));
  }

  /// Scrolls the editor just enough to keep the caret inside the dead-zone
  /// box, without re-centering the whole block.
  ///
  /// No-op when the caret is already inside the box, when no scroll controller
  /// is attached, in shrinkWrap mode, or when the scrollable is not mounted.
  void _keepCaretInView() {
    final editorState = _editorState;
    final scrollController = _scrollController;
    if (editorState == null ||
        scrollController == null ||
        editorState.selection == null ||
        !editorState.selection!.isCollapsed) {
      return;
    }
    if (scrollController.shrinkWrap) {
      return;
    }
    final scrollableState = editorState.scrollableState;
    if (scrollableState == null) {
      return;
    }

    final caretInViewport = _caretRectInViewport(editorState, scrollableState);
    if (caretInViewport == null) {
      return;
    }

    final viewportHeight = scrollableState.position.viewportDimension;
    final config = editorState.typewriter;
    final targetOffset = targetOffsetToKeepInView(
      caretRect: caretInViewport,
      viewportHeight: viewportHeight,
      // `position.pixels` is the authoritative, always-current scroll offset;
      // it stays consistent with the caret rect measured above even while a
      // previous animation is still running.
      currentOffset: scrollableState.position.pixels,
      topMargin: config.keepInViewTopMargin,
      bottomMargin: config.keepInViewBottomMargin,
    );
    if (targetOffset == null) {
      return;
    }
    // skip when we are already scrolling toward this exact offset: re-issuing
    // it would restart the animation and fight the caret movement.
    if (targetOffset == _lastTargetOffset) {
      return;
    }
    _lastTargetOffset = targetOffset;

    if (config.scrollDuration > Duration.zero) {
      scrollController.animateTo(
        offset: targetOffset,
        duration: config.scrollDuration,
        curve: config.scrollCurve,
      );
    } else {
      scrollController.scrollOffsetController.jumpTo(offset: targetOffset);
    }
  }
}
