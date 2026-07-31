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

  final Set<int> _pendingRowUpdates = {};
  bool _updateScheduled = false;

  void _scheduleRowUpdate(int row) {
    _pendingRowUpdates.add(row);
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      final rows = Set<int>.from(_pendingRowUpdates);
      _pendingRowUpdates.clear();
      for (final r in rows) {
        if (r >= widget.tableNode.rowsLen) continue;
        _applyRowHeightSync(r);
      }
      setState(() {});
    });
  }

  void _applyRowHeightSync(int row) {
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
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.tableStyleDef ?? kDefaultTableStyle;
    final noBorder = style.noBorder;
    final effective = style.effectiveBorder;

    final borderColor = noBorder
        ? null
        : context.select((Node n) {
              final value = n.attributes[TableBlockKeys.borderColor];
              return value is String ? value.tryToColor() : null;
            }) ??
            effective.left.color;

    final double colsHeight = widget.tableNode.colsHeight(style);

    final borderWidth = noBorder
        ? 0.0
        : (widget.tableNode.node.attributes[TableBlockKeys.borderWidth]
                as double?) ??
            style.verticalBorderWidth;

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
          borderWidth: borderWidth,
          tableStyleDef: style,
          borderHoverColor:
              widget.tableStyleDef?.borderHoverColor ?? Colors.transparent,
        ),
      );
    }

    children.addAll(
      [
        SizedBox(
          width: widget.colWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildCells(context),
          ),
        ),
        if (!noBorder && borderColor != null)
          TableColBorder(
            resizable: widget.colIdx + 1 < widget.tableNode.colsLen,
            tableNode: widget.tableNode,
            editorState: widget.editorState,
            colIdx: widget.colIdx,
            currentColWidth: widget.colWidth,
            colsHeight: colsHeight,
            borderWidth: borderWidth,
            tableStyleDef: style,
            borderColor: borderColor,
            borderHoverColor: widget.tableStyleDef?.borderHoverColor,
          ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _buildCells(BuildContext context) {
    final style = widget.tableStyleDef ?? kDefaultTableStyle;
    final noBorder = style.noBorder;
    final rowsLen = widget.tableNode.rowsLen;
    final List<Widget> cells = [];

    final borderWidth = noBorder
        ? 0.0
        : (widget.tableNode.node.attributes[TableBlockKeys.borderWidth]
                as double?) ??
            style.horizontalBorderWidth;

    final cellBorder = noBorder
        ? const SizedBox.shrink()
        : Container(
            height: borderWidth,
            color: style.effectiveBorder.top.color,
          );

    for (var r = 0; r < rowsLen; r++) {
      final node = widget.tableNode.getCell(widget.colIdx, r);
      final cellColor = _cellBackgroundColor(r, style);
      _scheduleRowUpdate(r);
      addListener(node, r);
      //TODO: @Cathood0 this is part of the cell using only one child instead of all available
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

    listeners[node.id] = () => _scheduleRowUpdate(row);
    node.addListener(listeners[node.id]!);
  }
}
