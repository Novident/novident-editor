import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/desktop_scroll_service.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/mobile_scroll_service.dart';
import 'package:novident_editor/src/editor/toolbar/mobile/utils/keyboard_height_observer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScrollServiceWidget extends StatefulWidget {
  const ScrollServiceWidget({
    super.key,
    required this.editorScrollController,
    this.scrollStrategies = const [],
    required this.child,
  });

  final EditorScrollController editorScrollController;

  /// Scroll strategies consulted on each selection change, in order. The
  /// first one that returns [ScrollDecision.handled] wins; if none does, the
  /// built-in edge-follow runs.
  final List<ScrollStrategy> scrollStrategies;

  final Widget child;

  @override
  State<ScrollServiceWidget> createState() => _ScrollServiceWidgetState();
}

class _ScrollServiceWidgetState extends State<ScrollServiceWidget>
    implements NovidentScrollService {
  final _forwardKey =
      GlobalKey(debugLabel: 'forward_to_platform_scroll_service');
  late NovidentScrollService forward =
      _forwardKey.currentState as NovidentScrollService;

  late EditorState editorState = context.read<EditorState>();

  /// Per-editor state shared by the scroll strategies across events (owned
  /// here so it is naturally reset when the editor is rebuilt).
  final ScrollStrategyState _strategyState = ScrollStrategyState();

  @override
  late ScrollController scrollController = ScrollController();

  Selection? lastSelection;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    editorState.selectionNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: widget.editorScrollController,
      child: Builder(
        builder: (context) {
          if (PlatformExtension.isDesktopOrWeb) {
            return _buildDesktopScrollService(context);
          } else if (PlatformExtension.isMobile) {
            return _buildMobileScrollService(context);
          }
          throw UnimplementedError();
        },
      ),
    );
  }

  Widget _buildDesktopScrollService(
    BuildContext context,
  ) {
    return DesktopScrollService(
      key: _forwardKey,
      child: widget.child,
    );
  }

  Widget _buildMobileScrollService(
    BuildContext context,
  ) {
    return MobileScrollService(
      key: _forwardKey,
      child: widget.child,
    );
  }

  void _onSelectionChanged() {
    // should auto scroll after the cursor or selection updated.
    final selection = editorState.selection;
    if (selection == null ||
        [SelectionUpdateReason.selectAll]
            .contains(editorState.selectionUpdateReason)) {
      return;
    }

    // Wait two frames before measuring: the text insertion (IME) updates the
    // document and selection synchronously, but the rebuild that lays out the
    // new text happens in the NEXT frame. A single post-frame callback would
    // measure the caret at its OLD position and scroll to a stale target (the
    // typewriter "goes crazy" on word-wrap). The second post-frame runs after
    // that rebuild, so the caret rect is accurate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final selectionRects = editorState.selectionRects();

        final ctx = ScrollStrategyContext(
          editorState: editorState,
          selection: selection,
          reason: editorState.selectionUpdateReason,
          scrollService: this,
          editorScrollController: widget.editorScrollController,
          selectionRects: selectionRects,
          state: _strategyState,
        );

        // consult the strategies in order; the first that handles wins.
        for (final strategy in widget.scrollStrategies) {
          if (strategy.onSelectionChanged(ctx) == ScrollDecision.handled) {
            return;
          }
        }

        // no strategy handled it → run the built-in edge-follow (needs rects).
        if (selectionRects.isEmpty) {
          return;
        }
        _defaultEdgeFollow(selection, selectionRects);
      });
    });
  }

  /// The built-in edge-follow: follows the caret / selection edge via the
  /// AutoScroller. This is the fallback when no strategy handles the event.
  void _defaultEdgeFollow(Selection selection, List<Rect> selectionRects) {
    Rect targetRect;
    AxisDirection? direction;
    final dynamic dragMode =
        editorState.selectionExtraInfo?['selection_drag_mode'];

    // For desktop: if auto-scroller is already scrolling (from drag-to-select),
    // don't override it here. The desktop_selection_service handles drag scrolling.
    if (PlatformExtension.isDesktopOrWeb &&
        (editorState.autoScroller?.scrolling ?? false)) {
      return;
    }

    switch (dragMode?.toString()) {
      case 'MobileSelectionDragMode.leftSelectionHandle':
        targetRect = selectionRects.first;
        direction = AxisDirection.up;
        break;
      case 'MobileSelectionDragMode.rightSelectionHandle':
        targetRect = selectionRects.last;
        direction = AxisDirection.down;
        break;
      default:
        targetRect = selectionRects.last;

        /// sometimes moving up in a long single node may be not working
        /// so we need to special handle this case.
        final isInSingleNode = (lastSelection?.isSingle ?? false) &&
            lastSelection?.start.path == selection.start.path;
        if (selection.isForward && isInSingleNode) {
          targetRect = selectionRects.first;
        }
    }

    lastSelection = selection;

    final endTouchPoint = targetRect.centerRight;

    if (PlatformExtension.isMobile) {
      // Determine if this is a drag operation
      final bool isDragOperation = dragMode != null &&
          (dragMode.toString() ==
                  'MobileSelectionDragMode.leftSelectionHandle' ||
              dragMode.toString() ==
                  'MobileSelectionDragMode.rightSelectionHandle');

      // Use animation for drag operations, instant for others
      final scrollDuration =
          isDragOperation ? const Duration(milliseconds: 2) : Duration.zero;

      // soft keyboard
      // workaround: wait for the soft keyboard to show up
      //TODO: @Cathood0 we need to replace the current keyboard height plugin
      // to another that supports all platforms
      final keyboardDelay = KeyboardHeightObserver.currentKeyboardHeight == 0
          ? const Duration(milliseconds: 250)
          : Duration.zero;

      Future.delayed(keyboardDelay, () {
        if (_forwardKey.currentContext == null) {
          return;
        }
        // Mobile needs to continuously update scroll position/direction during drag
        // Don't skip even if already scrolling, because direction may have changed
        startAutoScroll(
          endTouchPoint,
          edgeOffset: editorState.autoScrollEdgeOffset,
          direction: direction,
          duration: scrollDuration,
        );
      });
    } else {
      if (_forwardKey.currentContext == null) {
        return;
      }
      startAutoScroll(
        endTouchPoint,
        edgeOffset: editorState.autoScrollEdgeOffset,
        direction: direction,
        duration: Duration.zero,
      );
    }
  }

  @override
  void disable() => forward.disable();

  @override
  double get dy => forward.dy;

  @override
  void enable() => forward.enable();

  @override
  double get maxScrollExtent => forward.maxScrollExtent;

  @override
  double get minScrollExtent => forward.minScrollExtent;

  @override
  double? get onePageHeight => forward.onePageHeight;

  @override
  int? get page => forward.page;

  @override
  void scrollTo(
    double dy, {
    Duration duration = const Duration(milliseconds: 150),
  }) =>
      forward.scrollTo(dy, duration: duration);

  @override
  void jumpTo(int index) => forward.jumpTo(index);

  @override
  void jumpToTop() {
    forward.jumpToTop();
  }

  @override
  void jumpToBottom() {
    forward.jumpToBottom();
  }

  @override
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 100,
    AxisDirection? direction,
    Duration? duration,
  }) {
    forward.startAutoScroll(
      offset,
      edgeOffset: edgeOffset,
      direction: direction,
      duration: duration,
    );
  }

  @override
  void stopAutoScroll() => forward.stopAutoScroll();

  @override
  void goBallistic(double velocity) => forward.goBallistic(velocity);
}
