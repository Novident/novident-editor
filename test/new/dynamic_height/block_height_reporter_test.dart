import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/block_height_reporter.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';

import '../../test_helper.dart';

class _TestBlockWidget extends StatefulWidget {
  const _TestBlockWidget({required this.node, required this.childHeight});

  final Node node;
  final double childHeight;

  @override
  State<_TestBlockWidget> createState() => _TestBlockWidgetState();
}

class _TestBlockWidgetState extends State<_TestBlockWidget>
    with BlockHeightReporter {
  @override
  Node get node => widget.node;

  @override
  void initState() {
    super.initState();
    scheduleHeightReport();
  }

  @override
  void didUpdateWidget(covariant _TestBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleHeightReport();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.childHeight,
      width: double.infinity,
      child: const Placeholder(),
    );
  }
}

Node _nodeInDocument() {
  final doc = Document.blank();
  final node = paragraphNode(text: 'test');
  doc.insert([0], [node]);
  return node;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockHeightReporter', () {
    late DynamicHeightController controller;

    setUp(() {
      controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('reports block height after layout', (tester) async {
      final node = _nodeInDocument();
      controller.initialize(1);

      await tester.buildAndPump(
        DynamicHeightControllerProvider(
          controller: controller,
          child: _TestBlockWidget(node: node, childHeight: 85.0),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.cache.heightOf(0), 85.0);
      expect(controller.currentHeight, 85.0);
    });

    testWidgets('reports updated height when block resizes', (tester) async {
      final node = _nodeInDocument();
      controller.initialize(1);

      await tester.buildAndPump(
        DynamicHeightControllerProvider(
          controller: controller,
          child: _TestBlockWidget(node: node, childHeight: 50.0),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.cache.heightOf(0), 50.0);

      await tester.buildAndPump(
        DynamicHeightControllerProvider(
          controller: controller,
          child: _TestBlockWidget(node: node, childHeight: 120.0),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.cache.heightOf(0), 120.0);
      expect(controller.currentHeight, 120.0);
    });

    testWidgets('does nothing when no controller in tree', (tester) async {
      final node = _nodeInDocument();

      await tester.buildAndPump(
        _TestBlockWidget(node: node, childHeight: 50.0),
      );
      await tester.pump();

      expect(find.byType(_TestBlockWidget), findsOneWidget);
    });
  });

  group('DynamicHeightControllerProvider', () {
    testWidgets('maybeOf returns controller from ancestor', (tester) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(),
      );

      DynamicHeightController? found;

      await tester.buildAndPump(
        DynamicHeightControllerProvider(
          controller: controller,
          child: Builder(
            builder: (context) {
              found = DynamicHeightControllerProvider.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(found, same(controller));
      controller.dispose();
    });

    testWidgets('maybeOf returns null when no provider in tree', (
      tester,
    ) async {
      DynamicHeightController? found;

      await tester.buildAndPump(
        Builder(
          builder: (context) {
            found = DynamicHeightControllerProvider.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(found, isNull);
    });
  });
}
