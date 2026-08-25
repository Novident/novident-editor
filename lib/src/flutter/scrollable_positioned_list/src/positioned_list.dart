// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// coverage:ignore-file

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'element_registry.dart';
import 'item_positions_listener.dart';
import 'item_positions_notifier.dart';
import 'scroll_view.dart';

/// A list of widgets similar to [ListView], except scroll control
/// and position reporting is based on index rather than pixel offset.
///
/// [PositionedList] lays out children in the same way as [ListView].
///
/// The list can be displayed with the item at [positionIndex] positioned at a
/// particular [alignment].  See [ItemScrollController.jumpTo] for an
/// explanation of alignment.
///
/// All other parameters are the same as specified in [ListView].
class PositionedList extends StatefulWidget {
  /// Create a [PositionedList].
  const PositionedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.controller,
    this.itemPositionsNotifier,
    this.positionedIndex = 0,
    this.alignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.cacheExtent,
    this.semanticChildCount,
    this.addSemanticIndexes = true,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  }) : assert((positionedIndex == 0) || (positionedIndex < itemCount));

  /// Number of items the [itemBuilder] can produce.
  final int itemCount;

  /// Called to build children for the list with
  /// 0 <= index < itemCount.
  final IndexedWidgetBuilder itemBuilder;

  /// If not null, called to build separators for between each item in the list.
  /// Called with 0 <= index < itemCount - 1.
  final IndexedWidgetBuilder? separatorBuilder;

  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  final ScrollController? controller;

  /// Notifier that reports the items laid out in the list after each frame.
  final ItemPositionsNotifier? itemPositionsNotifier;

  /// Index of an item to initially align to a position within the viewport
  /// defined by [alignment].
  final int positionedIndex;

  /// Determines where the leading edge of the item at [positionedIndex]
  /// should be placed.
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  final double alignment;

  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the view scrolls in the reading direction.
  ///
  /// Defaults to false.
  ///
  /// See [ScrollView.reverse].
  final bool reverse;

  /// Whether the extent of the scroll view in the [scrollDirection] should be
  /// determined by the contents being viewed.
  ///
  ///  Defaults to false.
  ///
  /// See [ScrollView.shrinkWrap].
  final bool shrinkWrap;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scrollable.cacheExtent}
  final double? cacheExtent;

  /// The number of children that will contribute semantic information.
  ///
  /// See [ScrollView.semanticChildCount] for more information.
  final int? semanticChildCount;

  /// Whether to wrap each child in an [IndexedSemantics].
  ///
  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// The amount of space by which to inset the children.
  final EdgeInsets? padding;

  /// Whether to wrap each child in a [RepaintBoundary].
  ///
  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  ///
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  @override
  State<StatefulWidget> createState() => _PositionedListState();
}

class _PositionedListState extends State<PositionedList> {
  final Key _centerKey = UniqueKey();

  final registeredElements = ValueNotifier<Set<Element>?>(null);
  late final ScrollController scrollController;

  /// Whether [scrollController] was created here. Externally provided
  /// controllers (e.g. the ping/pong pair owned by
  /// `ScrollablePositionedList`) must NOT be disposed by this state:
  /// they outlive it and are reused by the next transition.
  late final bool _ownsScrollController;

  bool updateScheduled = false;

  /// The last positions reported to [widget.itemPositionsNotifier], used to
  /// avoid re-notifying listeners (and the O(n) visible-range computation they
  /// trigger) on every frame when nothing actually moved.
  List<ItemPosition>? _lastPositions;

  @override
  void initState() {
    super.initState();
    _ownsScrollController = widget.controller == null;
    scrollController = widget.controller ?? ScrollController();
    scrollController.addListener(_schedulePositionNotificationUpdate);
    _schedulePositionNotificationUpdate();
  }

  @override
  void dispose() {
    scrollController.removeListener(_schedulePositionNotificationUpdate);
    if (_ownsScrollController) {
      scrollController.dispose();
    }
    registeredElements.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PositionedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePositionNotificationUpdate();
  }

  @override
  Widget build(BuildContext context) => RegistryWidget(
        elementNotifier: registeredElements,
        child: UnboundedCustomScrollView(
          anchor: widget.alignment,
          center: _centerKey,
          controller: scrollController,
          scrollDirection: widget.scrollDirection,
          reverse: widget.reverse,
          scrollCacheExtent: widget.cacheExtent == null
              ? null
              : ScrollCacheExtent.pixels(widget.cacheExtent!),
          physics: widget.physics,
          shrinkWrap: widget.shrinkWrap,
          semanticChildCount: widget.semanticChildCount ?? widget.itemCount,
          slivers: <Widget>[
            if (widget.positionedIndex > 0)
              SliverPadding(
                padding: _leadingSliverPadding,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => widget.separatorBuilder == null
                        ? _buildItem(
                            context,
                            widget.positionedIndex - (index + 1),
                          )
                        : _buildSeparatedListElement(
                            context,
                            2 * widget.positionedIndex - (index + 1),
                          ),
                    childCount: widget.separatorBuilder == null
                        ? widget.positionedIndex
                        : 2 * widget.positionedIndex,
                    addSemanticIndexes: false,
                    addRepaintBoundaries: widget.addRepaintBoundaries,
                    addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                  ),
                ),
              ),
            SliverPadding(
              key: _centerKey,
              padding: _centerSliverPadding,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => widget.separatorBuilder == null
                      ? _buildItem(context, index + widget.positionedIndex)
                      : _buildSeparatedListElement(
                          context,
                          index + 2 * widget.positionedIndex,
                        ),
                  childCount: widget.itemCount != 0 ? 1 : 0,
                  addSemanticIndexes: false,
                  addRepaintBoundaries: widget.addRepaintBoundaries,
                  addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                ),
              ),
            ),
            if (widget.positionedIndex >= 0 &&
                widget.positionedIndex < widget.itemCount - 1)
              SliverPadding(
                padding: _trailingSliverPadding,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => widget.separatorBuilder == null
                        ? _buildItem(
                            context,
                            index + widget.positionedIndex + 1,
                          )
                        : _buildSeparatedListElement(
                            context,
                            index + 2 * widget.positionedIndex + 1,
                          ),
                    childCount: widget.separatorBuilder == null
                        ? widget.itemCount - widget.positionedIndex - 1
                        : 2 * (widget.itemCount - widget.positionedIndex - 1),
                    addSemanticIndexes: false,
                    addRepaintBoundaries: widget.addRepaintBoundaries,
                    addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildSeparatedListElement(BuildContext context, int index) {
    if (index.isEven) {
      return _buildItem(context, index ~/ 2);
    } else {
      return widget.separatorBuilder!(context, index ~/ 2);
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    return RegisteredElementWidget(
      key: ValueKey(index),
      child: widget.addSemanticIndexes
          ? IndexedSemantics(
              index: index,
              child: widget.itemBuilder(context, index),
            )
          : widget.itemBuilder(context, index),
    );
  }

  EdgeInsets get _leadingSliverPadding =>
      (widget.scrollDirection == Axis.vertical
          ? widget.reverse
              ? widget.padding?.copyWith(top: 0)
              : widget.padding?.copyWith(bottom: 0)
          : widget.reverse
              ? widget.padding?.copyWith(left: 0)
              : widget.padding?.copyWith(right: 0)) ??
      const EdgeInsets.all(0);

  EdgeInsets get _centerSliverPadding => widget.scrollDirection == Axis.vertical
      ? widget.reverse
          ? widget.padding?.copyWith(
                top: widget.positionedIndex == widget.itemCount - 1
                    ? widget.padding!.top
                    : 0,
                bottom:
                    widget.positionedIndex == 0 ? widget.padding!.bottom : 0,
              ) ??
              const EdgeInsets.all(0)
          : widget.padding?.copyWith(
                top: widget.positionedIndex == 0 ? widget.padding!.top : 0,
                bottom: widget.positionedIndex == widget.itemCount - 1
                    ? widget.padding!.bottom
                    : 0,
              ) ??
              const EdgeInsets.all(0)
      : widget.reverse
          ? widget.padding?.copyWith(
                left: widget.positionedIndex == widget.itemCount - 1
                    ? widget.padding!.left
                    : 0,
                right: widget.positionedIndex == 0 ? widget.padding!.right : 0,
              ) ??
              const EdgeInsets.all(0)
          : widget.padding?.copyWith(
                left: widget.positionedIndex == 0 ? widget.padding!.left : 0,
                right: widget.positionedIndex == widget.itemCount - 1
                    ? widget.padding!.right
                    : 0,
              ) ??
              const EdgeInsets.all(0);

  EdgeInsets get _trailingSliverPadding =>
      widget.scrollDirection == Axis.vertical
          ? widget.reverse
              ? widget.padding?.copyWith(bottom: 0) ?? const EdgeInsets.all(0)
              : widget.padding?.copyWith(top: 0) ?? const EdgeInsets.all(0)
          : widget.reverse
              ? widget.padding?.copyWith(right: 0) ?? const EdgeInsets.all(0)
              : widget.padding?.copyWith(left: 0) ?? const EdgeInsets.all(0);

  void _schedulePositionNotificationUpdate() {
    if (!updateScheduled) {
      updateScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final elements = registeredElements.value;
        if (elements == null) {
          updateScheduled = false;
          return;
        }
        final positions = <ItemPosition>[];
        RenderAbstractViewport? viewport;
        for (final element in elements) {
          final RenderBox box = element.renderObject as RenderBox;
          viewport ??= RenderAbstractViewport.of(box);
          final ValueKey<int> key = element.widget.key as ValueKey<int>;
          // Skip this element if `box` has never been laid out.
          if (!box.hasSize) continue;
          // `localToGlobal` gives the item's leading edge relative to the
          // viewport's leading edge directly (it already accounts for the
          // scroll offset and the anchor), which is cheaper than
          // `getOffsetToReveal` — no `RevealedOffset` allocation, no sliver
          // chain walk, no alignment/pinned-sliver math — and matches the
          // horizontal branch below.
          final Offset global =
              box.localToGlobal(Offset.zero, ancestor: viewport);
          final double itemOffset =
              widget.scrollDirection == Axis.vertical ? global.dy : global.dx;
          if (!itemOffset.isFinite) continue;
          final double dimension = scrollController.position.viewportDimension;
          final double leading = itemOffset;
          final double trailing = widget.scrollDirection == Axis.vertical
              ? itemOffset + box.size.height
              : itemOffset + box.size.width;
          // For a reversed list the leading edge is the far edge, so mirror
          // the offsets around the viewport dimension.
          final double edge = widget.reverse ? dimension - trailing : leading;
          final double tail = widget.reverse ? dimension - leading : trailing;
          positions.add(
            ItemPosition(
              index: key.value,
              itemLeadingEdge: edge.round() / dimension,
              itemTrailingEdge: tail.round() / dimension,
            ),
          );
        }
        // Only notify listeners when the positions actually changed, so we
        // don't wake consumers (visible-range computation, PageStorage writes)
        // on every frame when nothing moved.
        if (!_samePositions(_lastPositions, positions)) {
          _lastPositions = positions;
          widget.itemPositionsNotifier?.itemPositions.value = positions;
        }
        updateScheduled = false;
      });
    }
  }

  bool _samePositions(List<ItemPosition>? previous, List<ItemPosition> next) {
    if (previous == null || previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i] != next[i]) return false;
    }
    return true;
  }
}
