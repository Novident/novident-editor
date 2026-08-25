// Regression tests for the vendored `scrollable_positioned_list` position
// notification path (`_schedulePositionNotificationUpdate` in
// `positioned_list.dart`).
//
// These cover the observable behavior of the position reporting: correct
// leading/trailing edges, updates after scrolling, and — critically — that
// listeners are NOT re-notified when the computed positions are unchanged
// (the `_samePositions` guard that avoids waking the O(n) visible-range
// computation on every frame).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/flutter/scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  const viewportHeight = 300.0;
  const itemExtent = 50.0;

  Widget buildList({
    required int itemCount,
    required ItemPositionsListener positionsListener,
    ItemScrollController? itemScrollController,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: viewportHeight,
          child: ScrollablePositionedList.builder(
            itemCount: itemCount,
            itemPositionsListener: positionsListener,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) => SizedBox(
              height: itemExtent,
              child: Text('Item $index'),
            ),
          ),
        ),
      ),
    );
  }

  group('PositionedList position notification', () {
    testWidgets('reports correct leading/trailing edges for visible items',
        (tester) async {
      final positionsListener = ItemPositionsListener.create();

      await tester.pumpWidget(
        buildList(itemCount: 20, positionsListener: positionsListener),
      );
      await tester.pump();

      final positions = positionsListener.itemPositions.value.toList();
      expect(positions, isNotEmpty, reason: 'visible items must be reported');

      // The notifier only exposes items at least partially visible.
      for (final position in positions) {
        expect(position.itemLeadingEdge, lessThan(1));
        expect(position.itemTrailingEdge, greaterThan(0));
      }

      // First visible item is index 0, flush with the leading edge.
      expect(positions.first.index, 0);
      expect(positions.first.itemLeadingEdge, 0);

      // Items are laid out sequentially: each leading edge advances by
      // itemExtent / viewportDimension.
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i].index, positions[i - 1].index + 1);
        expect(
          positions[i].itemLeadingEdge,
          closeTo(
            positions[i - 1].itemLeadingEdge + itemExtent / viewportHeight,
            0.001,
          ),
        );
      }
    });

    testWidgets('updates positions after scrolling', (tester) async {
      final positionsListener = ItemPositionsListener.create();
      final itemScrollController = ItemScrollController();

      await tester.pumpWidget(
        buildList(
          itemCount: 100,
          positionsListener: positionsListener,
          itemScrollController: itemScrollController,
        ),
      );
      await tester.pump();

      final before = positionsListener.itemPositions.value.toList();
      expect(before.first.index, 0);

      // Jump to an item far down the list.
      itemScrollController.jumpTo(index: 50);
      await tester.pumpAndSettle();

      final after = positionsListener.itemPositions.value.toList();
      expect(after, isNotEmpty);
      // The visible window has moved: the first reported item is now near
      // index 50, not 0.
      expect(after.first.index, greaterThan(before.first.index));
      expect(after.first.index, greaterThanOrEqualTo(45));
    });

    testWidgets('does not re-notify when positions are unchanged',
        (tester) async {
      final positionsListener = ItemPositionsListener.create();
      var notificationCount = 0;
      positionsListener.itemPositions.addListener(() => notificationCount++);

      await tester.pumpWidget(
        buildList(itemCount: 10, positionsListener: positionsListener),
      );
      await tester.pump();

      final afterFirstBuild = notificationCount;
      expect(
        afterFirstBuild,
        greaterThan(0),
        reason: 'initial layout must notify once',
      );

      // Rebuild with an identical configuration: the scroll offset and layout
      // are unchanged, so the positions are identical and the listener must
      // NOT fire again (the `_samePositions` guard).
      await tester.pumpWidget(
        buildList(itemCount: 10, positionsListener: positionsListener),
      );
      await tester.pump();

      expect(
        notificationCount,
        afterFirstBuild,
        reason: 'unchanged positions must not re-notify listeners',
      );
    });

    testWidgets('exposes only visible items as a materialized list',
        (tester) async {
      final positionsListener = ItemPositionsListener.create();

      await tester.pumpWidget(
        buildList(itemCount: 20, positionsListener: positionsListener),
      );
      await tester.pump();

      final positions = positionsListener.itemPositions.value;
      // `_updatePositions` must hand consumers a concrete list, not a lazy
      // `.where(...)` iterable that re-evaluates the filter on every pass.
      expect(positions, isA<List<ItemPosition>>());
      expect(positions, isNotEmpty);
      // Only items at least partially visible are reported.
      for (final position in positions) {
        expect(position.itemLeadingEdge, lessThan(1));
        expect(position.itemTrailingEdge, greaterThan(0));
      }
    });

    testWidgets('shrink-wrap mode lays out without hanging', (tester) async {
      final positionsListener = ItemPositionsListener.create();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: ScrollablePositionedList.builder(
                  shrinkWrap: true,
                  itemCount: 10,
                  itemPositionsListener: positionsListener,
                  itemBuilder: (context, index) => SizedBox(
                    height: itemExtent,
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(positionsListener.itemPositions.value, isNotEmpty);
    });
  });
}
