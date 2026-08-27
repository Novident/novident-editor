import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';

import '../../test_helper.dart';

EditorState _editor({int paragraphs = 1, String text = 'A'}) {
  final doc = Document.blank()
    ..insert(
      [0],
      List.generate(paragraphs, (i) => paragraphNode(text: '$text $i')),
    );
  return EditorState(document: doc)..editorStyle = const EditorStyle.desktop();
}

Future<void> _typeText(
  WidgetTester tester,
  EditorState editorState,
  String text, {
  int pathIndex = 0,
}) async {
  final tx = editorState.transaction;
  tx.add(
    UpdateTextOperation(
      [pathIndex],
      Delta()..insert(text),
      Delta(),
    ),
  );
  tx.afterSelection = Selection.collapsed(
    Position(path: [pathIndex], offset: text.length),
  );
  await editorState.apply(tx);
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _insertParagraphs(
  WidgetTester tester,
  EditorState editorState,
  int atIndex,
  int count,
) async {
  final tx = editorState.transaction;
  tx.insertNodes(
    [atIndex],
    List.generate(count, (i) => paragraphNode(text: 'Para ${atIndex + i}')),
  );
  await editorState.apply(tx);
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Single editor', () {
    testWidgets('height changes when text content changes', (tester) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _editor(text: '');
      editorState.dynamicHeightController = controller;

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

      expect(controller.cache.blockCount, 1);
      final initialH = controller.currentHeight;

      await _typeText(tester, editorState, 'One short line.');
      final h1 = controller.currentHeight;

      await _typeText(
        tester,
        editorState,
        'One short line. Now with more text that should wrap to multiple lines.',
      );
      final h2 = controller.currentHeight;

      final allDifferent = h1 != initialH || h2 != h1 || h2 != initialH;
      expect(
        allDifferent,
        isTrue,
        reason: 'Height should change. '
            'initial=$initialH h1=$h1 h2=$h2',
      );

      controller.dispose();
      editorState.dispose();
    });

    testWidgets('adding paragraphs increases block count', (tester) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _editor(text: 'Single');
      editorState.dynamicHeightController = controller;

      await tester.buildAndPump(
        NovidentEditor(
          editorState: editorState,
          editable: true,
          dynamicHeightController: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.cache.blockCount, 1);
      await _insertParagraphs(tester, editorState, 1, 3);
      expect(controller.cache.blockCount, 4);

      controller.dispose();
      editorState.dispose();
    });

    testWidgets('enforces minHeight when empty', (tester) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 150.0),
      );
      final editorState = EditorState.blank()
        ..editorStyle = const EditorStyle.desktop();
      editorState.dynamicHeightController = controller;

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

      expect(controller.currentHeight, greaterThanOrEqualTo(150.0));
      controller.dispose();
      editorState.dispose();
    });
  });

  group('Multiple editors in a Column', () {
    testWidgets('render with dividers between them', (tester) async {
      final c1 = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final c2 = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final c3 = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final e1 = _editor(text: 'Editor 1');
      final e2 = _editor(text: 'Editor 2');
      final e3 = _editor(text: 'Editor 3');
      e1.dynamicHeightController = c1;
      e2.dynamicHeightController = c2;
      e3.dynamicHeightController = c3;

      await tester.buildAndPump(
        SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: 400,
                child: NovidentEditor(
                  editorState: e1,
                  editable: true,
                  dynamicHeightController: c1,
                ),
              ),
              const Divider(height: 1, thickness: 2),
              SizedBox(
                width: 400,
                child: NovidentEditor(
                  editorState: e2,
                  editable: true,
                  dynamicHeightController: c2,
                ),
              ),
              const Divider(height: 1, thickness: 2),
              SizedBox(
                width: 400,
                child: NovidentEditor(
                  editorState: e3,
                  editable: true,
                  dynamicHeightController: c3,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(NovidentEditor), findsNWidgets(3));
      expect(find.byType(Divider), findsNWidgets(2));
      expect(c1.cache.blockCount, 1);
      expect(c2.cache.blockCount, 1);
      expect(c3.cache.blockCount, 1);

      c1.dispose();
      c2.dispose();
      c3.dispose();
      e1.dispose();
      e2.dispose();
      e3.dispose();
    });

    testWidgets('each editor has independent block count', (tester) async {
      final c1 = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final c2 = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final e1 = _editor(text: 'Editor 1');
      final e2 = _editor(text: 'Editor 2');
      e1.dynamicHeightController = c1;
      e2.dynamicHeightController = c2;

      await tester.buildAndPump(
        SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: 400,
                child: NovidentEditor(
                  editorState: e1,
                  editable: true,
                  dynamicHeightController: c1,
                ),
              ),
              const Divider(height: 1, thickness: 2),
              SizedBox(
                width: 400,
                child: NovidentEditor(
                  editorState: e2,
                  editable: true,
                  dynamicHeightController: c2,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(c1.cache.blockCount, 1);
      expect(c2.cache.blockCount, 1);

      await _insertParagraphs(tester, e1, 1, 2);
      expect(c1.cache.blockCount, 3);
      expect(c2.cache.blockCount, 1);

      c1.dispose();
      c2.dispose();
      e1.dispose();
      e2.dispose();
    });
  });
}
