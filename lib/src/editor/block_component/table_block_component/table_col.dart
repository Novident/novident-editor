import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_action_handler.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCol extends StatefulWidget {
  const TableCol({
    super.key,
    required this.tableNode,
    required this.editorState,
    required this.colIdx,
    required this.tableStyle,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final int colIdx;
  final EditorState editorState;
  final TableNode tableNode;

  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu of the column handler.
  final List<TableActionMenuItem>? actionMenuItems;

  final TableStyle tableStyle;

  @override
  State<TableCol> createState() => _TableColState();
}

class _TableColState extends State<TableCol> {
  bool _colActionVisiblity = false;

  Map<String, void Function()> listeners = {};

  @override
  Widget build(BuildContext context) {
    // per-table override of the style border color; see
    // [TableBlockKeys.borderColor].
    final borderColor = context.select((Node n) {
          final value = n.attributes[TableBlockKeys.borderColor];
          return value is String ? value.tryToColor() : null;
        }) ??
        widget.tableStyle.borderColor;

    List<Widget> children = [];
    if (widget.colIdx == 0) {
      children.add(
        TableColBorder(
          resizable: false,
          tableNode: widget.tableNode,
          editorState: widget.editorState,
          colIdx: widget.colIdx,
          borderColor: borderColor,
          borderHoverColor: widget.tableStyle.borderHoverColor,
        ),
      );
    }

    children.addAll([
      SizedBox(
        width: context.select(
          (Node n) => getCellNode(n, widget.colIdx, 0)?.cellWidth,
        ),
        child: Stack(
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _colActionVisiblity = true),
              onExit: (_) => setState(() => _colActionVisiblity = false),
              child: Column(children: _buildCells(context, borderColor)),
            ),
            TableActionHandler(
              visible: _colActionVisiblity,
              node: widget.tableNode.node,
              editorState: widget.editorState,
              position: widget.colIdx,
              transform: Matrix4.translationValues(0.0, -12, 0.0),
              alignment: Alignment.topCenter,
              menuBuilder: widget.menuBuilder,
              actionMenuItems: widget.actionMenuItems,
              dir: TableDirection.col,
            ),
          ],
        ),
      ),
      TableColBorder(
        resizable: true,
        tableNode: widget.tableNode,
        editorState: widget.editorState,
        colIdx: widget.colIdx,
        borderColor: borderColor,
        borderHoverColor: widget.tableStyle.borderHoverColor,
      ),
    ]);

    // `start` keeps the vertical borders (whose height comes from the
    // `colsHeight` attribute) anchored to the top of the column. With the
    // default `center` alignment, any transient mismatch between the
    // attribute and the real column height splits the gap between the top
    // and bottom corners of the grid.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _buildCells(BuildContext context, Color borderColor) {
    final rowsLen = widget.tableNode.rowsLen;
    final List<Widget> cells = [];
    final Widget cellBorder = Container(
      height: widget.tableNode.config.borderWidth,
      color: borderColor,
    );

    for (var i = 0; i < rowsLen; i++) {
      final node = widget.tableNode.getCell(widget.colIdx, i);
      updateRowHeightCallback(i);
      addListener(node, i);
      addListener(node.children.first, i);

      cells.addAll([
        widget.editorState.renderer.build(
          context,
          node,
        ),
        cellBorder,
      ]);
    }

    return [
      cellBorder,
      ...cells,
    ];
  }

  void addListener(Node node, int row) {
    if (listeners.containsKey(node.id)) {
      return;
    }

    listeners[node.id] = () => updateRowHeightCallback(row);
    node.addListener(listeners[node.id]!);
  }

  void updateRowHeightCallback(int row) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (row >= widget.tableNode.rowsLen) {
          return;
        }

        final transaction = widget.editorState.transaction;
        widget.tableNode.updateRowHeight(
          row,
          editorState: widget.editorState,
          transaction: transaction,
        );
        if (transaction.operations.isNotEmpty) {
          transaction.afterSelection = transaction.beforeSelection;
          widget.editorState.apply(transaction);
        }
      });
}
