import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_add_button.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col.dart';
import 'package:flutter/material.dart';

class TableView extends StatefulWidget {
  const TableView({
    super.key,
    required this.editorState,
    required this.tableNode,
    required this.tableStyle,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final EditorState editorState;
  final TableNode tableNode;
  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu of the column handlers.
  final List<TableActionMenuItem>? actionMenuItems;

  final TableStyle tableStyle;

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          // `start` keeps the add-row button (whose width comes from the
          // `tableWidth` computation) anchored to the left edge of the grid.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // `start` keeps the add-column button (whose height comes from
              // the `colsHeight` attribute) anchored to the top of the grid.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildColumns(context),
                if (widget.tableStyle.showAddColumnButton)
                  TableActionButton(
                    padding: const EdgeInsets.only(left: 0),
                    icon: widget.tableStyle.addIcon,
                    width: 28,
                    height: widget.tableNode.colsHeight,
                    onPressed: () {
                      TableActions.add(
                        widget.tableNode.node,
                        widget.tableNode.colsLen,
                        widget.editorState,
                        TableDirection.col,
                      );
                    },
                  ),
              ],
            ),
            if (widget.tableStyle.showAddRowButton)
              TableActionButton(
                padding: const EdgeInsets.only(top: 1, right: 30),
                icon: widget.tableStyle.addIcon,
                height: 28,
                width: widget.tableNode.tableWidth,
                onPressed: () {
                  TableActions.add(
                    widget.tableNode.node,
                    widget.tableNode.rowsLen,
                    widget.editorState,
                    TableDirection.row,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildColumns(BuildContext context) {
    return List.generate(
      widget.tableNode.colsLen,
      (i) => TableCol(
        colIdx: i,
        editorState: widget.editorState,
        tableNode: widget.tableNode,
        menuBuilder: widget.menuBuilder,
        actionMenuItems: widget.actionMenuItems,
        tableStyle: widget.tableStyle,
      ),
    );
  }
}
