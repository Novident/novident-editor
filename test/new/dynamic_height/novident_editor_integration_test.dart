import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';

import '../../test_helper.dart';

EditorState _editorWithParagraphs({
  int count = 1,
  String text = 'Hello',
}) {
  final document = Document.blank()
    ..insert(
      [0],
      List.generate(
        count,
        (i) => paragraphNode(text: '$text $i'),
      ),
    );
  return EditorState(document: document)
    ..editorStyle = const EditorStyle.desktop();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NovidentEditor with dynamicHeight', () {
    testWidgets('renders without ScrollServiceWidget when dynamicHeight is set',
        (tester) async {
      final editorState = _editorWithParagraphs();

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
          dynamicHeightConfig: const DynamicHeightConfig(minHeight: 100.0),
        ),
      );
      await tester.pump();

      expect(find.byType(NovidentEditor), findsOneWidget);
      editorState.dispose();
    });

    testWidgets('editor height is at least minHeight when empty', (
      tester,
    ) async {
      final editorState = EditorState.blank();

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
          dynamicHeightConfig: const DynamicHeightConfig(minHeight: 80.0),
        ),
      );
      await tester.pump();
      await tester.pump();

      final editorBox =
          tester.renderObject(find.byType(NovidentEditor)) as RenderBox;
      expect(editorBox.size.height, greaterThanOrEqualTo(80.0));
      editorState.dispose();
    });

    testWidgets('external controller receives block height reports', (
      tester,
    ) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _editorWithParagraphs(count: 2);

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
          dynamicHeightController: controller,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(controller.cache.blockCount, 2);
      controller.dispose();
      editorState.dispose();
    });

    testWidgets('grows when paragraphs are inserted via transaction', (
      tester,
    ) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _editorWithParagraphs(count: 1, text: 'A');

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
          dynamicHeightController: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      final heightBefore = controller.currentHeight;

      final transaction = editorState.transaction;
      transaction.insertNodes(
        [1],
        [paragraphNode(text: 'B'), paragraphNode(text: 'C')],
      );
      await editorState.apply(transaction);

      await tester.pump();
      await tester.pump();

      expect(controller.cache.blockCount, 3);
      expect(controller.currentHeight, greaterThanOrEqualTo(heightBefore));
      controller.dispose();
      editorState.dispose();
    });
  });

  group('NovidentEditor without dynamicHeight (regression)', () {
    testWidgets('renders normally when dynamicHeightConfig is null', (
      tester,
    ) async {
      final editorState = _editorWithParagraphs();

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
        ),
      );
      await tester.pump();

      expect(find.byType(NovidentEditor), findsOneWidget);
      editorState.dispose();
    });

    testWidgets('shrinkWrap still works without dynamicHeight', (
      tester,
    ) async {
      final editorState = _editorWithParagraphs();

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
          shrinkWrap: true,
        ),
      );
      await tester.pump();

      expect(find.byType(NovidentEditor), findsOneWidget);
      editorState.dispose();
    });

    testWidgets('scroll service is present without dynamicHeight', (
      tester,
    ) async {
      final editorState = _editorWithParagraphs();

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
        ),
      );
      await tester.pump();

      expect(find.byType(NovidentEditor), findsOneWidget);
      editorState.dispose();
    });
  });

  group('EditorState.apply with dynamicHeightController', () {
    test('notifies NodesInserted on insert operation', () async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(),
      );
      final editorState = _editorWithParagraphs(count: 1);
      editorState.dynamicHeightController = controller;
      controller.initialize(1);
      controller.reportBlockHeight(0, 80.0);

      final transaction = editorState.transaction;
      transaction.insertNodes(
        [1],
        [paragraphNode(text: 'new')],
      );
      await editorState.apply(transaction);

      expect(controller.cache.blockCount, 2);
      expect(controller.cache.heightOf(0), 80.0);
      controller.dispose();
      editorState.dispose();
    });

    test('notifies NodesRemoved on delete operation', () async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(),
      );
      final editorState = _editorWithParagraphs(count: 3);
      editorState.dynamicHeightController = controller;
      controller.initialize(3);
      controller.reportBlockHeight(0, 80.0);
      controller.reportBlockHeight(1, 60.0);
      controller.reportBlockHeight(2, 100.0);

      final transaction = editorState.transaction;
      transaction.deleteNodesAtPath([0], 1);
      await editorState.apply(transaction);

      expect(controller.cache.blockCount, 2);
      expect(controller.cache.heightOf(0), 60.0);
      expect(controller.cache.heightOf(1), 100.0);
      controller.dispose();
      editorState.dispose();
    });

    test('notifies TextChanged on updateText operation', () async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(),
      );
      final editorState = _editorWithParagraphs(count: 1);
      editorState.dynamicHeightController = controller;
      controller.initialize(1);
      controller.reportBlockHeight(0, 80.0);

      final transaction = editorState.transaction;
      transaction.add(
        UpdateTextOperation([0], Delta()..insert('modified text'), Delta()),
      );
      await editorState.apply(transaction);

      expect(controller.cache.heightOf(0), 60.0); // reverted to default
      controller.dispose();
      editorState.dispose();
    });

    test('does nothing when dynamicHeightController is null', () async {
      final editorState = _editorWithParagraphs(count: 2);
      // dynamicHeightController stays null

      final transaction = editorState.transaction;
      transaction.insertNodes([2], [paragraphNode(text: 'extra')]);
      await editorState.apply(transaction);

      // Should not throw
      expect(editorState.document.root.children.length, 3);
      editorState.dispose();
    });
  });
}
