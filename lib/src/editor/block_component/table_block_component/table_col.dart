import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCol extends StatefulWidget {
  const TableCol({
    super.key,
    required this.tableNode,
    required this.editorState,
    required this.colIdx,
    required this.colWidth,
    this.tableStyleDef,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final int colIdx;
  final EditorState editorState;
  final TableNode tableNode;

  /// Pre-calculated width in pixels (from
  /// [TableNode.distributeColumnWidths]).
  final double colWidth;

  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu of the column handler.
  final List<TableActionMenuItem>? actionMenuItems;

  /// Resolved [NovidentTableStyleDefinition] for this table.
  final NovidentTableStyleDefinition? tableStyleDef;

  @override
  State<TableCol> createState() => _TableColState();
}

class _TableColState extends State<TableCol> {
  Map<String, VoidCallback> listeners = <String, VoidCallback>{};

  @override
  Widget build(BuildContext context) {
    // per-table override of the style border color; see
    // [TableBlockKeys.borderColor].
    final style = widget.tableStyleDef ?? kDefaultTableStyle;
    final noBorder = style.noBorder;

    final borderColor = noBorder
        ? null
        : context.select((Node n) {
              final value = n.attributes[TableBlockKeys.borderColor];
              return value is String ? value.tryToColor() : null;
            }) ??
            style.borderColor;

    final colsHeight = widget.tableNode.colsHeight;

    List<Widget> children = [];
    if (widget.colIdx == 0 && !noBorder && borderColor != null) {
      children.add(
        TableColBorder(
          resizable: false,
          tableNode: widget.tableNode,
          editorState: widget.editorState,
          colIdx: widget.colIdx,
          borderColor: borderColor,
          colsHeight: colsHeight,
          tableStyleDef: style,
          borderHoverColor:
              widget.tableStyleDef?.borderHoverColor ?? Colors.transparent,
        ),
      );
    }

    children.addAll([
      SizedBox(
        width: widget.colWidth,
        child: Column(
          children: _buildCells(context, borderColor),
        ),
      ),
      if (!noBorder && borderColor != null)
        TableColBorder(
          resizable: true,
          tableNode: widget.tableNode,
          editorState: widget.editorState,
          colIdx: widget.colIdx,
          currentColWidth: widget.colWidth,
          colsHeight: colsHeight,
          tableStyleDef: style,
          borderColor: borderColor,
          borderHoverColor: widget.tableStyleDef?.borderHoverColor,
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

  List<Widget> _buildCells(BuildContext context, Color? borderColor) {
    final style = widget.tableStyleDef;
    final noBorder = style?.noBorder ?? false;
    final rowsLen = widget.tableNode.rowsLen;
    final List<Widget> cells = [];

    final cellBorder = noBorder || borderColor == null
        ? const SizedBox.shrink()
        : Container(
            height: widget.tableNode.config.borderWidth,
            color: borderColor,
          );

    for (var r = 0; r < rowsLen; r++) {
      final node = widget.tableNode.getCell(widget.colIdx, r);
      final cellColor = _cellBackgroundColor(r, style);
      updateRowHeightCallback(r);
      addListener(node, r);
      addListener(node.children.first, r);

      cells.addAll([
        if (cellColor != null)
          ColoredBox(
            color: cellColor,
            child: widget.editorState.renderer.build(context, node),
          )
        else
          widget.editorState.renderer.build(context, node),
        cellBorder,
      ]);
    }

    final topBorder = noBorder ? const SizedBox.shrink() : cellBorder;
    return [
      topBorder,
      ...cells,
    ];
  }

  /// Returns the background color for row [r] based on the table style.
  Color? _cellBackgroundColor(int r, NovidentTableStyleDefinition? style) {
    if (style == null) return null;

    // Header rows take priority.
    if (r < style.headerRowCount) {
      return style.headerStyle?.backgroundColor;
    }
    // Footer rows.
    final footerStart = widget.tableNode.rowsLen - style.footerRowCount;
    if (r >= footerStart) {
      return style.footerStyle?.backgroundColor;
    }
    // Zebra striping.
    if (r.isEven && style.evenRowColor != null) return style.evenRowColor;
    if (r.isOdd && style.oddRowColor != null) return style.oddRowColor;

    return null;
  }

  void addListener(Node node, int row) {
    if (listeners.containsKey(node.id)) {
      return;
    }

    listeners[node.id] = () => updateRowHeightCallback(row);
    node.addListener(listeners[node.id]!);
  }

  void updateRowHeightCallback(int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (row >= widget.tableNode.rowsLen) return;

      final transaction = widget.editorState.transaction;
      widget.tableNode.updateRowHeight(
        row,
        style: widget.tableStyleDef ?? kDefaultTableStyle,
        editorState: widget.editorState,
        transaction: transaction,
      );
      if (transaction.operations.isNotEmpty) {
        transaction.afterSelection = transaction.beforeSelection;
        widget.editorState.apply(transaction);
      }
      if (mounted) setState(() {});
    });
  }
}