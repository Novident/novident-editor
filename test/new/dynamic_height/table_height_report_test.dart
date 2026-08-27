import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:provider/provider.dart';

import '../../test_helper.dart';

/// Builds an [EditorState] whose document contains a single 2x2 table.
EditorState _editorWithTable() {
  final table = TableNode.fromList([
    ['A', 'B'],
    ['C', 'D'],
  ]);
  final document = Document.blank()..insert([0], [table.node]);
  return EditorState(document: document)
    ..editorStyle = const EditorStyle.desktop()
    ..renderer = BlockComponentRenderer(
      builders: standardBlockComponentBuilderMap,
    );
}

Widget _wrapWithProviders(EditorState editorState, Widget child) {
  return Provider<EditorState>.value(
    value: editorState,
    child: child,
  );
}

/// Settles post-frame callbacks, the async row-height synchronization in
/// [TableCol], and the controller-driven rebuilds.
Future<void> _settle(WidgetTester tester, {int frames = 15}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
    tester.takeException();
  }
}

Widget _layout(EditorState editorState, DynamicHeightController controller) {
  return _wrapWithProviders(
    editorState,
    DynamicHeightLayout(
      node: editorState.document.root,
      editorState: editorState,
      controller: controller,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Table height reporting in dynamic-height layout', () {
    testWidgets('reports the initial table height matching its real size', (
      tester,
    ) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _editorWithTable()
        ..dynamicHeightController = controller;

      await tester.buildAndPump(_layout(editorState, controller));
      await _settle(tester);

      final actual =
          tester.getSize(find.byType(TableBlockComponentWidget)).height;

      // The table must report its real rendered height (not the default
      // estimate, and not a nested cell paragraph's height).
      expect(
        controller.cache.heightOf(0),
        closeTo(actual, 1.0),
        reason: 'reported=${controller.cache.heightOf(0)} actual=$actual',
      );

      controller.dispose();
      editorState.dispose();
    });

    testWidgets('re-reports the table height when a cell grows', (
      tester,
    ) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _editorWithTable()
        ..dynamicHeightController = controller;

      await tester.buildAndPump(_layout(editorState, controller));
      await _settle(tester);

      final heightBefore = controller.cache.heightOf(0);

      // Grow the first cell's paragraph with enough text to wrap and
      // increase the measured row height.
      final tx = editorState.transaction;
      tx.add(
        UpdateTextOperation(
          [0, 0, 0], // table -> cell(0,0) -> paragraph
          Delta()
            ..insert(
              'grow grow grow grow grow grow grow grow grow grow grow grow '
              'grow grow grow grow grow grow grow grow grow grow grow grow '
              'grow grow grow grow grow grow grow grow grow grow grow grow '
              'grow grow grow grow grow grow grow grow grow grow grow grow',
            ),
          Delta(),
        ),
      );
      await editorState.apply(tx);
      await _settle(tester);

      final heightAfter = controller.cache.heightOf(0);
      final actual =
          tester.getSize(find.byType(TableBlockComponentWidget)).height;

      // The async row-height sync (an UpdateOperation on the cells) must
      // invalidate the table's cache entry and trigger a re-report.
      expect(
        heightAfter,
        greaterThan(heightBefore),
        reason: 'heightBefore=$heightBefore heightAfter=$heightAfter',
      );
      expect(
        heightAfter,
        closeTo(actual, 1.0),
        reason: 'reported=$heightAfter actual=$actual',
      );

      controller.dispose();
      editorState.dispose();
    });
  });

  group('EditorState.apply with dynamicHeightController', () {
    test('UpdateOperation on a nested node invalidates the top-level block',
        () async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(),
      );
      final editorState = _editorWithTable()
        ..dynamicHeightController = controller;
      editorState.dynamicHeightController = controller;
      controller.initialize(1);
      controller.reportBlockHeight(0, 100.0);

      var notified = 0;
      controller.addListener(() => notified++);

      // Simulates what TableNode.updateRowHeight does: an attribute update
      // on a cell (path [0, cellIdx]).
      final cell = editorState.document.root.children.first.children.first;
      final tx = editorState.transaction;
      tx.updateNode(cell, {TableCellBlockKeys.height: 150.0});
      await editorState.apply(tx);

      expect(
        notified,
        greaterThan(0),
        reason: 'The UpdateOperation must notify the dynamic-height '
            'controller so the table re-reports its height.',
      );
      // Height preserved until the block re-measures.
      expect(controller.cache.heightOf(0), 100.0);

      controller.dispose();
      editorState.dispose();
    });
  });
}

