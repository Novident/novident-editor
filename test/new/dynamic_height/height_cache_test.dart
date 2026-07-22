import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/height_cache.dart';

void main() {
  group('HeightCache', () {
    late HeightCache cache;

    setUp(() {
      cache = HeightCache(defaultHeight: 60.0);
    });

    group('empty state', () {
      test('totalHeight is zero with no blocks', () {
        expect(cache.totalHeight, 0.0);
        expect(cache.blockCount, 0);
      });

      test('heightOf throws RangeError for negative index', () {
        expect(() => cache.heightOf(-1), throwsRangeError);
      });

      test('heightOf returns defaultHeight for any index when empty', () {
        expect(cache.heightOf(0), 60.0);
        expect(cache.heightOf(5), 60.0);
      });
    });

    group('reportHeight', () {
      test('updates totalHeight with delta after nodes are registered', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        expect(cache.totalHeight, 220.0); // 100 + 60 + 60
      });

      test('returns false when delta is less than 1.0 pixel', () {
        cache.onNodesInserted(0, 1);
        cache.reportHeight(0, 60.0);

        final changed = cache.reportHeight(0, 60.4);
        expect(changed, false);
        expect(cache.totalHeight, 60.0);
      });

      test('returns true when delta is 1.0 pixel or more', () {
        cache.onNodesInserted(0, 1);
        final changed = cache.reportHeight(0, 120.0);
        expect(changed, true);
        expect(cache.totalHeight, 120.0);
      });

      test('updating same block multiple times adjusts total correctly', () {
        cache.onNodesInserted(0, 1);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(0, 150.0);
        cache.reportHeight(0, 80.0);
        expect(cache.totalHeight, 80.0);
      });
    });

    group('onNodesInserted', () {
      test('shifts existing indices forward', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);

        cache.onNodesInserted(0, 1);

        expect(cache.heightOf(0), 60.0); // new block, default
        expect(cache.heightOf(1), 100.0); // shifted from index 0
        expect(cache.heightOf(2), 80.0); // shifted from index 1
        expect(cache.blockCount, 3);
      });

      test('inserting in the middle preserves surrounding heights', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(2, 120.0);

        cache.onNodesInserted(1, 1);

        expect(cache.heightOf(0), 100.0); // unchanged
        expect(cache.heightOf(1), 60.0); // new block
        expect(cache.heightOf(3), 120.0); // shifted from index 2
        expect(cache.blockCount, 4);
      });

      test('totalHeight includes defaults for new blocks', () {
        cache.onNodesInserted(0, 5);
        expect(cache.totalHeight, 300.0); // 5 × 60
      });

      test('appending at the end does not shift earlier indices', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);

        cache.onNodesInserted(2, 2);

        expect(cache.heightOf(0), 100.0);
        expect(cache.heightOf(1), 80.0);
        expect(cache.heightOf(2), 60.0); // new
        expect(cache.heightOf(3), 60.0); // new
        expect(cache.blockCount, 4);
        expect(cache.totalHeight, 300.0); // 100 + 80 + 60 + 60
      });
    });

    group('onNodesRemoved', () {
      test('removes entries and compacts indices', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        cache.onNodesRemoved(0, 1);

        expect(cache.blockCount, 2);
        expect(cache.heightOf(0), 80.0); // was index 1
        expect(cache.heightOf(1), 120.0); // was index 2
      });

      test('updates totalHeight by subtracting removed heights', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0); // total = 300

        cache.onNodesRemoved(0, 1);
        expect(cache.totalHeight, 200.0); // 80 + 120
      });

      test('subtracts defaultHeight for unmeasured removed blocks', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        // indices 1 and 2 stay at default

        cache.onNodesRemoved(1, 2);
        expect(cache.totalHeight, 100.0); // only index 0 remains
        expect(cache.blockCount, 1);
      });

      test('removing from the middle compacts correctly', () {
        cache.onNodesInserted(0, 4);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);
        cache.reportHeight(3, 90.0);

        cache.onNodesRemoved(1, 2); // remove indices 1 and 2

        expect(cache.blockCount, 2);
        expect(cache.heightOf(0), 100.0);
        expect(cache.heightOf(1), 90.0); // was index 3
      });
    });

    group('invalidateRange', () {
      test('marks range as dirty but preserves heights', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        cache.invalidateRange(0, 1);

        // Heights preserved until re-measured
        expect(cache.heightOf(0), 100.0);
        expect(cache.heightOf(1), 80.0);
        expect(cache.heightOf(2), 120.0); // unaffected
      });

      test('single index invalidation preserves that index', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);

        cache.invalidateRange(0, 0);

        expect(cache.heightOf(0), 100.0); // preserved
        expect(cache.heightOf(1), 80.0);
      });

      test('totalHeight unchanged after invalidation', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 200.0);
        cache.reportHeight(1, 200.0); // total = 400

        cache.invalidateRange(0, 1); // heights preserved, total stays 400
        expect(cache.totalHeight, 400.0);
      });

      test('end defaults to last block when not provided', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        cache.invalidateRange(0);

        // All heights preserved until re-measured
        expect(cache.heightOf(0), 100.0);
        expect(cache.heightOf(1), 80.0);
        expect(cache.heightOf(2), 120.0);
      });
    });

    group('accumulatedHeightUpTo', () {
      test('sums heights correctly from index 0', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        expect(cache.accumulatedHeightUpTo(0), 100.0);
        expect(cache.accumulatedHeightUpTo(1), 180.0);
        expect(cache.accumulatedHeightUpTo(2), 300.0);
      });

      test('caps at last block when upToIndex exceeds blockCount', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);

        expect(cache.accumulatedHeightUpTo(5), 180.0);
      });
    });

    group('listeners', () {
      test('notifyIfChanged calls listeners when changed is true', () {
        var callCount = 0;
        cache.addListener(() => callCount++);
        cache.addListener(() => callCount++);

        cache.notifyIfChanged(true);

        expect(callCount, 2);
      });

      test('notifyIfChanged skips listeners when changed is false', () {
        var callCount = 0;
        cache.addListener(() => callCount++);

        cache.notifyIfChanged(false);

        expect(callCount, 0);
      });

      test('removeListener stops notifications', () {
        var callCount = 0;
        void listener() => callCount++;

        cache.addListener(listener);
        cache.notifyIfChanged(true);
        expect(callCount, 1);

        cache.removeListener(listener);
        cache.notifyIfChanged(true);
        expect(callCount, 1); // unchanged
      });
    });

    group('lifecycle', () {
      test('clear resets everything to initial state', () {
        cache.onNodesInserted(0, 5);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);

        cache.clear();

        expect(cache.totalHeight, 0.0);
        expect(cache.blockCount, 0);
        expect(cache.heightOf(0), 60.0);
      });

      test('dispose clears listeners and data', () {
        var callCount = 0;
        cache.addListener(() => callCount++);
        cache.onNodesInserted(0, 3);

        cache.dispose();

        cache.notifyIfChanged(true);
        expect(callCount, 0); // listeners cleared
        expect(cache.totalHeight, 0.0); // data cleared
      });
    });

    group('real-world document editing scenarios', () {
      test('typing text makes a paragraph grow', () {
        cache.onNodesInserted(0, 1); // document has one paragraph

        cache.reportHeight(0, 60.0); // initial: one line
        expect(cache.totalHeight, 60.0);

        cache.invalidateRange(0, 0);
        cache.reportHeight(0, 90.0); // text wraps to two lines
        expect(cache.totalHeight, 90.0);

        cache.invalidateRange(0, 0);
        cache.reportHeight(0, 140.0); // three lines
        expect(cache.totalHeight, 140.0);
      });

      test('pressing Enter inserts a new paragraph and shifts cache', () {
        cache.onNodesInserted(0, 1);
        cache.reportHeight(0, 80.0);

        cache.onNodesInserted(1, 1); // Enter pressed → new paragraph at index 1

        expect(cache.blockCount, 2);
        expect(cache.heightOf(0), 80.0); // first paragraph unchanged
        expect(cache.heightOf(1), 60.0); // new paragraph, default

        cache.reportHeight(0, 30.0); // first paragraph shrinks (text moved to new)
        cache.reportHeight(1, 50.0); // new paragraph measured
        expect(cache.totalHeight, 80.0);
      });

      test('backspace at start of paragraph merges with previous', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 50.0);
        cache.reportHeight(1, 40.0);

        // merge: remove second paragraph, first paragraph grows
        cache.onNodesRemoved(1, 1);
        cache.invalidateRange(0, 0);
        cache.reportHeight(0, 70.0);

        expect(cache.blockCount, 1);
        expect(cache.totalHeight, 70.0);
      });

      test('deleting a paragraph in the middle reflows cache', () {
        cache.onNodesInserted(0, 4);
        cache.reportHeight(0, 60.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 40.0);
        cache.reportHeight(3, 100.0);

        cache.onNodesRemoved(1, 1); // delete paragraph at index 1

        expect(cache.blockCount, 3);
        expect(cache.heightOf(0), 60.0);
        expect(cache.heightOf(1), 40.0); // was index 2
        expect(cache.heightOf(2), 100.0); // was index 3
        expect(cache.totalHeight, 200.0);
      });

      test('pasting multiple paragraphs inserts and estimates', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 60.0);
        cache.reportHeight(1, 70.0);

        cache.onNodesInserted(1, 3); // paste 3 paragraphs at position 1

        expect(cache.blockCount, 5);
        expect(cache.heightOf(0), 60.0); // unchanged
        expect(cache.heightOf(1), 60.0); // new, default
        expect(cache.heightOf(2), 60.0); // new, default
        expect(cache.heightOf(3), 60.0); // new, default
        expect(cache.heightOf(4), 70.0); // was index 1, shifted
        expect(
          cache.totalHeight,
          310.0, // 60 + 60+60+60 + 70
        );

        // Blocks get measured as they become visible
        cache.reportHeight(1, 55.0);
        cache.reportHeight(2, 90.0);
        cache.reportHeight(3, 45.0);
        expect(cache.totalHeight, 320.0); // 60 + 55+90+45 + 70
      });

      test('font size change invalidates all blocks', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 60.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 40.0);
        expect(cache.totalHeight, 180.0);

        // User increases font size → all heights must be re-measured
        cache.invalidateRange(0, 2);
        expect(cache.totalHeight, 180.0); // preserved
        expect(cache.heightOf(0), 60.0); // preserved
        expect(cache.heightOf(1), 80.0); // preserved
        expect(cache.heightOf(2), 40.0); // preserved

        // Re-measured with larger font
        cache.reportHeight(0, 75.0);
        cache.reportHeight(1, 100.0);
        cache.reportHeight(2, 50.0);
        expect(cache.totalHeight, 225.0);
      });

      test('async image load updates block height after initial layout', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 60.0); // text paragraph
        cache.reportHeight(1, 20.0); // image placeholder
        cache.reportHeight(2, 60.0); // text paragraph
        expect(cache.totalHeight, 140.0);

        // Image loads → block grows
        cache.reportHeight(1, 300.0);
        expect(cache.totalHeight, 420.0);

        // Surrounding blocks unaffected
        expect(cache.heightOf(0), 60.0);
        expect(cache.heightOf(2), 60.0);
      });

      test('select-all + delete resets to empty document', () {
        cache.onNodesInserted(0, 5);
        cache.reportHeight(0, 60.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 40.0);
        cache.reportHeight(3, 100.0);
        cache.reportHeight(4, 70.0);

        cache.onNodesRemoved(0, 5);

        expect(cache.blockCount, 0);
        expect(cache.totalHeight, 0.0);
      });
    });
  });
}
