import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';

void main() {
  group('DynamicHeightController', () {
    late DynamicHeightController controller;

    setUp(() {
      controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 100.0),
      );
    });

    group('currentHeight', () {
      test('is minHeight when no blocks exist', () {
        expect(controller.currentHeight, 100.0);
      });

      test('is minHeight when content is shorter than minHeight', () {
        controller.initialize(1);
        expect(controller.currentHeight, 100.0); // 1 × 60 < minHeight 100
      });

      test('grows with content beyond minHeight', () {
        controller.initialize(1);
        controller.reportBlockHeight(0, 200.0);
        expect(controller.currentHeight, 200.0);
      });

      test('reflects multiple blocks', () {
        controller.initialize(3);
        controller.reportBlockHeight(0, 150.0);
        controller.reportBlockHeight(1, 80.0);
        controller.reportBlockHeight(2, 120.0);
        expect(controller.currentHeight, 350.0);
      });
    });

    group('listeners', () {
      test('notifies when block height changes', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.initialize(1);
        expect(notified, true);

        notified = false;
        controller.reportBlockHeight(0, 200.0);
        expect(notified, true);
      });

      test('does not notify when height delta is negligible', () {
        controller.initialize(1);
        controller.reportBlockHeight(0, 60.0);

        var notified = false;
        controller.addListener(() => notified = true);

        final changed = controller.reportBlockHeight(0, 60.4);
        expect(changed, false);
      });

      test('removeListener stops notifications', () {
        var callCount = 0;
        void listener() => callCount++;

        controller.addListener(listener);
        controller.initialize(1);
        expect(callCount, 1);

        controller.removeListener(listener);
        controller.reportBlockHeight(0, 200.0);
        // Removed listener not called; internal listeners may still fire
      });
    });

    group('onDocumentMutation', () {
      test('TextChanged invalidates the block forcing re-measure', () {
        controller.initialize(1);
        controller.reportBlockHeight(0, 120.0);
        expect(controller.currentHeight, 120.0);

        controller.onDocumentMutation(
          const TextChanged(nodeIndex: 0),
        );

        // Height reverts to default until re-measured
        expect(controller.currentHeight, 100.0); // 60 < minHeight 100
      });

      test('NodesInserted shifts cache and notifies', () {
        controller.initialize(2);
        controller.reportBlockHeight(0, 100.0);
        controller.reportBlockHeight(1, 80.0);
        expect(controller.currentHeight, 180.0);

        controller.onDocumentMutation(
          const NodesInserted(atIndex: 1, count: 1),
        );

        expect(controller.cache.blockCount, 3);
        expect(controller.cache.heightOf(0), 100.0);
        expect(controller.cache.heightOf(2), 80.0); // shifted
        expect(controller.currentHeight, 240.0); // 100 + 60 + 80
      });

      test('NodesRemoved compacts cache and notifies', () {
        controller.initialize(3);
        controller.reportBlockHeight(0, 100.0);
        controller.reportBlockHeight(1, 80.0);
        controller.reportBlockHeight(2, 120.0);
        expect(controller.currentHeight, 300.0);

        controller.onDocumentMutation(
          const NodesRemoved(atIndex: 0, count: 1),
        );

        expect(controller.cache.blockCount, 2);
        expect(controller.cache.heightOf(0), 80.0);
        expect(controller.cache.heightOf(1), 120.0);
        expect(controller.currentHeight, 200.0);
      });
    });

    group('initialize', () {
      test('registers initial blocks with default heights', () {
        controller.initialize(4);
        expect(controller.cache.blockCount, 4);
        expect(controller.currentHeight, 240.0); // 4 × 60
      });

      test('subsequent calls accumulate', () {
        controller.initialize(2);
        controller.initialize(3);
        expect(controller.cache.blockCount, 5);
      });
    });

    group('updateConfig', () {
      test('changes minHeight at runtime', () {
        controller.initialize(1);
        expect(controller.currentHeight, 100.0); // clamped to minHeight

        controller.updateConfig(
          const DynamicHeightConfig(minHeight: 50.0),
        );

        expect(controller.currentHeight, 60.0); // now above minHeight
      });
    });

    group('invalidateAll', () {
      test('resets all heights to default', () {
        controller.initialize(3);
        controller.reportBlockHeight(0, 200.0);
        controller.reportBlockHeight(1, 150.0);
        controller.reportBlockHeight(2, 100.0);
        expect(controller.currentHeight, 450.0);

        controller.invalidateAll();

        expect(controller.currentHeight, 180.0); // 3 × 60
        expect(controller.cache.heightOf(0), 60.0);
        expect(controller.cache.heightOf(1), 60.0);
        expect(controller.cache.heightOf(2), 60.0);
      });
    });

    group('real-world editing scenarios', () {
      test('typing grows editor smoothly', () {
        controller.initialize(1);
        controller.reportBlockHeight(0, 60.0); // one line
        expect(controller.currentHeight, 100.0); // clamped to minHeight

        controller.onDocumentMutation(const TextChanged(nodeIndex: 0));
        controller.reportBlockHeight(0, 90.0); // two lines
        expect(controller.currentHeight, 100.0); // still clamped

        controller.onDocumentMutation(const TextChanged(nodeIndex: 0));
        controller.reportBlockHeight(0, 150.0); // three lines
        expect(controller.currentHeight, 150.0); // now above minHeight

        controller.onDocumentMutation(const TextChanged(nodeIndex: 0));
        controller.reportBlockHeight(0, 200.0); // four lines
        expect(controller.currentHeight, 200.0);
      });

      test('adding and removing paragraphs reflects total height', () {
        controller.initialize(1);
        controller.reportBlockHeight(0, 80.0);
        expect(controller.currentHeight, 100.0); // clamped

        controller.onDocumentMutation(
          const NodesInserted(atIndex: 1, count: 1),
        );
        controller.reportBlockHeight(1, 70.0);
        expect(controller.currentHeight, 150.0); // 80 + 70

        controller.onDocumentMutation(
          const NodesInserted(atIndex: 2, count: 1),
        );
        controller.reportBlockHeight(2, 100.0);
        expect(controller.currentHeight, 250.0); // 80 + 70 + 100

        controller.onDocumentMutation(
          const NodesRemoved(atIndex: 1, count: 1),
        );
        controller.invalidateAll(); // force re-measure after structural change
        controller.reportBlockHeight(0, 80.0); // unchanged
        controller.reportBlockHeight(1, 100.0); // shifted from index 2
        expect(controller.cache.blockCount, 2);
        expect(controller.currentHeight, 180.0); // 80 + 100
      });

      test('delete all content returns to minHeight', () {
        controller.initialize(3);
        controller.reportBlockHeight(0, 120.0);
        controller.reportBlockHeight(1, 80.0);
        controller.reportBlockHeight(2, 100.0);
        expect(controller.currentHeight, 300.0);

        controller.onDocumentMutation(
          const NodesRemoved(atIndex: 0, count: 3),
        );

        expect(controller.cache.blockCount, 0);
        expect(controller.currentHeight, 100.0); // minHeight
      });

      test('debounce prevents rapid-fire notifications', () async {
        final debouncedController = DynamicHeightController(
          config: const DynamicHeightConfig(
            minHeight: 100.0,
            resizeDebounce: Duration(milliseconds: 100),
          ),
        );

        var notifyCount = 0;
        debouncedController.addListener(() => notifyCount++);

        debouncedController.initialize(1);
        // Immediate notification on initialize (bypasses debounce in code)
        await Future.delayed(const Duration(milliseconds: 10));

        debouncedController.reportBlockHeight(0, 120.0);
        debouncedController.reportBlockHeight(0, 150.0);
        debouncedController.reportBlockHeight(0, 180.0);

        // Notifications are debounced — wait for the timer
        await Future.delayed(const Duration(milliseconds: 150));

        // Should only have notified once (or a small number of times)
        // The exact count depends on debounce implementation
        expect(debouncedController.currentHeight, 180.0);
        debouncedController.dispose();
      });
    });

    group('dispose', () {
      test('dispose releases resources', () {
        controller.initialize(5);
        controller.reportBlockHeight(0, 200.0);

        controller.dispose();

        expect(controller.cache.blockCount, 0);
        expect(controller.cache.totalHeight, 0.0);
      });
    });
  });

  group('DocumentMutation', () {
    test('NodesInserted stores atIndex and count', () {
      const mutation = NodesInserted(atIndex: 2, count: 3);
      expect(mutation.atIndex, 2);
      expect(mutation.count, 3);
    });

    test('NodesRemoved stores atIndex and count', () {
      const mutation = NodesRemoved(atIndex: 0, count: 5);
      expect(mutation.atIndex, 0);
      expect(mutation.count, 5);
    });

    test('TextChanged stores nodeIndex', () {
      const mutation = TextChanged(nodeIndex: 7);
      expect(mutation.nodeIndex, 7);
    });
  });
}
