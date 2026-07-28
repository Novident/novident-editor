import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_add_button.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col.dart';
import 'package:flutter/material.dart';

class TableView extends StatelessWidget {
  const TableView({
    super.key,
    required this.editorState,
    required this.tableNode,
    required this.tableStyle,
    required this.columnWidths,
    this.tableStyleDef,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final EditorState editorState;
  final TableNode tableNode;
  final TableBlockComponentMenuBuilder? menuBuilder;
  final List<TableActionMenuItem>? actionMenuItems;
  final TableStyle tableStyle;
  final List<double> columnWidths;

  /// Resolved [NovidentTableStyleDefinition] for this table.
  final NovidentTableStyleDefinition? tableStyleDef;

  @override
  Widget build(BuildContext context) {
    final totalBorders =
        tableNode.config.borderWidth * (tableNode.colsLen + 1);
    final totalWidth =
        columnWidths.fold<double>(0, (a, b) => a + b) + totalBorders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildColumns(context),
            ),
            if (tableStyle.showAddColumnButton)
              Positioned(
                right: -28,
                top: 0,
                child: TableActionButton(
                  padding: const EdgeInsets.only(left: 0),
                  icon: tableStyle.addIcon,
                  width: 28,
                  height: tableNode.colsHeight,
                  onPressed: () {
                    TableActions.add(
                      tableNode.node,
                      tableNode.colsLen,
                      editorState,
                      TableDirection.col,
                    );
                  },
                ),
              ),
          ],
        ),
        if (tableStyle.showAddRowButton)
          TableActionButton(
            padding: const EdgeInsets.only(top: 1, right: 0),
            icon: tableStyle.addIcon,
            height: 28,
            width: totalWidth,
            onPressed: () {
              TableActions.add(
                tableNode.node,
                tableNode.rowsLen,
                editorState,
                TableDirection.row,
              );
            },
          ),
      ],
    );
  }

  List<Widget> _buildColumns(BuildContext context) {
    return List.generate(
      tableNode.colsLen,
      (i) => TableCol(
        colIdx: i,
        colWidth: columnWidths[i],
        editorState: editorState,
        tableNode: tableNode,
        menuBuilder: menuBuilder,
        actionMenuItems: actionMenuItems,
        tableStyle: tableStyle,
        tableStyleDef: tableStyleDef,
      ),
    );
  }
}
