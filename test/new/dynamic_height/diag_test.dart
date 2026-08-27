import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_block_component.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_layout.dart';
import 'package:provider/provider.dart';

import '../../test_helper.dart';

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

Future<void> _settle(WidgetTester tester, {int frames = 15}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
    tester.takeException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DIAGNOSTIC: table growth on cell text change', (tester) async {
    final controller = DynamicHeightController(
      config: const DynamicHeightConfig(minHeight: 0.0),
    );
    final editorState = _editorWithTable();
    final tableNode = TableNode(node: editorState.document.root.children.first);

    await tester.buildAndPump(
      _wrapWithProviders(
        editorState,
        DynamicHeightLayout(
          node: editorState.document.root,
          editorState: editorState,
          controller: controller,
        ),
      ),
    );
    await _settle(tester);

    final cell00 = tableNode.getCell(0, 0);
    final para00 = cell00.children.first;
    debugPrint('=== INITIAL ===');
    debugPrint('table heightOf(0): ${controller.cache.heightOf(0)}');
    debugPrint('para rect: ${para00.rect}');
    debugPrint('cell00 height attr: ${cell00.attributes[TableCellBlockKeys.height]}');
    debugPrint('row0 height: ${tableNode.getRowHeight(0, kDefaultTableStyle)}');
    debugPrint('actual table size: ${tester.getSize(find.byType(TableBlockComponentWidget))}');

    final tx = editorState.transaction;
    tx.add(
      UpdateTextOperation(
        [0, 0, 0],
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

    debugPrint('=== AFTER TEXT CHANGE ===');
    debugPrint('table heightOf(0): ${controller.cache.heightOf(0)}');
    debugPrint('para rect: ${para00.rect}');
    debugPrint('para delta: ${para00.delta?.toPlainText().length} chars');
    debugPrint('cell00 height attr: ${cell00.attributes[TableCellBlockKeys.height]}');
    debugPrint('row0 height: ${tableNode.getRowHeight(0, kDefaultTableStyle)}');
    debugPrint('actual table size: ${tester.getSize(find.byType(TableBlockComponentWidget))}');

    controller.dispose();
    editorState.dispose();
  });
}