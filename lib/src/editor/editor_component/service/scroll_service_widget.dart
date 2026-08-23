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
          final child = _withEdgeZoneDebugOverlay(widget.child);
          if (PlatformExtension.isDesktopOrWeb) {
            return _buildDesktopScrollService(context, child);
          } else if (PlatformExtension.isMobile) {
            return _buildMobileScrollService(context, child);
          }
          throw UnimplementedError();
        },
      ),
    );
  }

  /// DEBUG overlay: paints the auto-scroll edge band (the area at
  /// `edgeOffset` from the top and bottom of the viewport where the
  /// auto-scroll kicks in) so the edge can be calibrated visually.
  Widget _withEdgeZoneDebugOverlay(Widget child) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _EdgeZoneDebugPainter(
                edgeOffset: editorState.autoScrollEdgeOffset,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopScrollService(
    BuildContext context,
    Widget child,
  ) {
    return DesktopScrollService(
      key: _forwardKey,
      child: child,
    );
  }

  Widget _buildMobileScrollService(
    BuildContext context,
    Widget child,
  ) {
    return MobileScrollService(
      key: _forwardKey,
      child: child,
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

    debugPrint('[scroll] _onSelectionChanged '
        'sel=${selection.start.path}/${selection.start.offset} '
        'reason=${editorState.selectionUpdateReason} '
        'dragMode=${editorState.selectionDragModeValue()}');

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
          final decision = strategy.onSelectionChanged(ctx);
          debugPrint('[scroll] strategy=${strategy.runtimeType} '
              'decision=$decision');
          if (decision == ScrollDecision.handled) {
            return;
          }
        }

        // no strategy handled it → run the built-in edge-follow (needs rects).
        // During a mobile drag the caret may have jumped outside the viewport,
        // leaving the rects empty — still run the edge-follow so it can fall
        // back to the finger position (see _defaultEdgeFollow).
        if (selectionRects.isEmpty &&
            editorState.selectionDragModeValue() == null) {
          debugPrint('[scroll] edge-follow: no rects');
          return;
        }
        debugPrint('[scroll] edge-follow');
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

    // During a mobile drag the caret can jump to a node that is not laid out
    // yet (or is outside the viewport), leaving [selectionRects] empty. The
    // finger position is always inside the viewport, so use it as the
    // auto-scroll target instead of giving up — otherwise the caret escapes
    // the viewport and the drag stops scrolling.
    if (selectionRects.isEmpty && dragMode != null) {
      final finger = editorState.service.selectionService.lastPanOffset;
      if (finger != null) {
        debugPrint('[scroll] edge-follow: no rects, using finger $finger');
        _startAutoScrollForDrag(finger, dragMode, direction);
        return;
      }
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
    _startAutoScrollForDrag(endTouchPoint, dragMode, direction);
  }

  /// Starts the auto-scroll toward [endTouchPoint] (global coordinates),
  /// applying the mobile keyboard delay and drag animation duration.
  void _startAutoScrollForDrag(
    Offset endTouchPoint,
    dynamic dragMode,
    AxisDirection? direction,
  ) {
    NovidentEditorLog.scroll.debug(
      'startAutoScrollForDrag point=$endTouchPoint '
      'edgeOffset=${editorState.autoScrollEdgeOffset} direction=$direction',
    );
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

/// DEBUG painter: fills the auto-scroll edge band (the area at `edgeOffset`
/// from the top and bottom of the viewport). When the caret / finger enters
/// this band the auto-scroll starts, so this shows exactly where the edge is.
class _EdgeZoneDebugPainter extends CustomPainter {
  _EdgeZoneDebugPainter({required this.edgeOffset});

  final double edgeOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final band = edgeOffset;
    final paint = Paint()
      ..color = const Color(0x66FF0000) // semi-transparent red
      ..style = PaintingStyle.fill;

    // top band
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, band),
      paint,
    );
    // bottom band
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - band, size.width, band),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EdgeZoneDebugPainter oldDelegate) =>
      oldDelegate.edgeOffset != edgeOffset;
}
