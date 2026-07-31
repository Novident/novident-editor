import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_action_bar.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col.dart';
import 'package:flutter/material.dart';

class NovidentTableStyleScope extends InheritedWidget {
  const NovidentTableStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  final NovidentTableStyleDefinition style;

  static NovidentTableStyleDefinition? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NovidentTableStyleScope>()
        ?.style;
  }

  @override
  bool updateShouldNotify(NovidentTableStyleScope oldWidget) =>
      !identical(style, oldWidget.style);
}

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
    final showBar = editorState.editorStyle.showTableActionBar;
    final style = tableStyleDef ?? kDefaultTableStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBar)
          TableActionBar(
            tableNode: tableNode,
            editorState: editorState,
            actionMenuItems: actionMenuItems,
            menuBuilder: menuBuilder,
          ),
        NovidentTableStyleScope(
          style: style,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildColumns(context),
          ),
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
