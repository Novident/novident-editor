import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col.dart';
import 'package:flutter/material.dart';

class TableView extends StatelessWidget {
  const TableView({
    super.key,
    required this.editorState,
    required this.tableNode,
    required this.columnWidths,
    this.tableStyleDef,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final EditorState editorState;
  final TableNode tableNode;
  final TableBlockComponentMenuBuilder? menuBuilder;
  final List<TableActionMenuItem>? actionMenuItems;
  final List<double> columnWidths;

  /// Resolved [NovidentTableStyleDefinition] for this table.
  final NovidentTableStyleDefinition? tableStyleDef;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildColumns(context),
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
        tableStyleDef: tableStyleDef,
      ),
    );
  }
}
