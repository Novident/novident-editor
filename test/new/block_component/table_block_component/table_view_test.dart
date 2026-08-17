import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/testable_editor.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('table_view.dart', () {
    testWidgets('row height changing base on cell height', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final row0beforeHeight = tableNode.getRowHeight(0, kDefaultTableStyle);
      final row1beforeHeight = tableNode.getRowHeight(1, kDefaultTableStyle);
      expect(row0beforeHeight == row1beforeHeight, true);

      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.ime.insertText('aaaaaaaaa');
      await tester.pumpAndSettle();

      final transaction = editor.editorState.transaction;
      tableNode.updateRowHeight(
        0,
        transaction: transaction,
        style: kDefaultTableStyle,
      );
      await editor.editorState.apply(transaction);
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      // Every column of row 0 converges to the same stored height.
      expect(
        cell10.attributes[TableCellBlockKeys.height],
        cell00.attributes[TableCellBlockKeys.height],
      );
      // The row is never shorter than its measured content.
      expect(
        tableNode.getRowHeight(0, kDefaultTableStyle),
        greaterThanOrEqualTo(cell10.children.first.rect.height),
      );
      expect(tableNode.getRowHeight(1, kDefaultTableStyle), row1beforeHeight);
      expect(
        tableNode.getRowHeight(1, kDefaultTableStyle) <
            tableNode.getRowHeight(0, kDefaultTableStyle),
        false,
      );
      await editor.dispose();
    });

    testWidgets('row height changing base on column width', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final row1beforeHeight = tableNode.getRowHeight(1, kDefaultTableStyle);

      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.ime.insertText('aaaaaaaaa');
      await tester.pumpAndSettle();

      Transaction transaction = editor.editorState.transaction;
      tableNode.updateRowHeight(
        0,
        transaction: transaction,
        style: kDefaultTableStyle,
      );
      await editor.editorState.apply(transaction);
      await tester.pumpAndSettle();

      transaction = editor.editorState.transaction;
      tableNode.setColWidth(
        1,
        302.5,
        transaction: transaction,
        style: kDefaultTableStyle,
      );
      await editor.editorState.apply(transaction);

      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      // After the width change, all columns of row 0 stay synchronized and
      // the stored height still covers the re-measured content.
      expect(
        cell10.attributes[TableCellBlockKeys.height],
        cell00.attributes[TableCellBlockKeys.height],
      );
      expect(
        tableNode.getRowHeight(0, kDefaultTableStyle),
        greaterThanOrEqualTo(cell10.children.first.rect.height),
      );
      expect(tableNode.getRowHeight(1, kDefaultTableStyle), row1beforeHeight);
      await editor.dispose();
    });
  });
}
