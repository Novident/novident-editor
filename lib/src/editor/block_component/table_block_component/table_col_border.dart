import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

class TableColBorder extends StatefulWidget {
  const TableColBorder({
    super.key,
    required this.tableNode,
    required this.editorState,
    required this.colIdx,
    required this.resizable,
    required this.borderColor,
    required this.colsHeight,
    this.tableStyleDef,
    this.borderHoverColor,
    this.currentColWidth,
  });

  final NovidentTableStyleDefinition? tableStyleDef;
  final bool resizable;
  final int colIdx;
  final TableNode tableNode;
  final EditorState editorState;

  final Color borderColor;
  final Color? borderHoverColor;
  final double colsHeight;

  /// The current rendered width in pixels of the column this border
  /// belongs to. Used to convert mouse drag pixels to proportional
  /// weight deltas.
  final double? currentColWidth;

  @override
  State<TableColBorder> createState() => _TableColBorderState();
}

class _TableColBorderState extends State<TableColBorder> {
  final GlobalKey _borderKey = GlobalKey();
  bool _borderHovering = false;
  bool _borderDragging = false;

  Offset initialOffset = const Offset(0, 0);

  NovidentTableStyleDefinition get tableStyle {
    return widget.tableStyleDef ?? kDefaultTableStyle;
  }

  @override
  Widget build(BuildContext context) {
    return widget.resizable
        ? buildResizableBorder(context)
        : buildFixedBorder(context);
  }

  MouseRegion buildResizableBorder(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _borderHovering = true),
      onExit: (_) => setState(() => _borderHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (DragStartDetails details) {
          setState(() => _borderDragging = true);
          initialOffset = details.globalPosition;
        },
        onHorizontalDragEnd: (_) {
          final transaction = widget.editorState.transaction;
          final col = widget.colIdx;
          final nextCol = col + 1;
          widget.tableNode.setColWeight(
            col,
            widget.tableNode.getColWeight(col, tableStyle),
            style: tableStyle,
            transaction: transaction,
            force: true,
          );
          if (nextCol < widget.tableNode.colsLen) {
            widget.tableNode.setColWeight(
              nextCol,
              widget.tableNode.getColWeight(nextCol, tableStyle),
              style: tableStyle,
              transaction: transaction,
              force: true,
            );
          }
          transaction.afterSelection = transaction.beforeSelection;
          widget.editorState.apply(transaction);
          setState(() => _borderDragging = false);
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          final col = widget.colIdx;
          final nextCol = col + 1;
          if (nextCol >= widget.tableNode.colsLen) return;

          // Convert pixel delta to weight delta using the actual
          // rendered column width for 1:1 pixel-to-visual mapping.
          final colWidth = widget.currentColWidth ?? TableDefaults.colWidth;
          final colWeight = widget.tableNode.getColWeight(col, tableStyle);
          final weightDelta = colWidth > 0
              ? details.delta.dx * colWeight / colWidth
              : details.delta.dx / TableDefaults.colWidth;

          // Calculate new weights: left grows, right shrinks.
          final leftWeight =
              widget.tableNode.getColWeight(col, tableStyle) + weightDelta;
          final rightWeight =
              widget.tableNode.getColWeight(nextCol, tableStyle) - weightDelta;

          // Clamp: neither column can go below minimum.
          final minWeight = tableStyle.colMinimumWidth / TableDefaults.colWidth;
          if (leftWeight < minWeight || rightWeight < minWeight) return;

          widget.tableNode.setColWeight(
            col,
            leftWeight,
            style: widget.tableStyleDef,
          );
          widget.tableNode.setColWeight(
            nextCol,
            rightWeight,
            style: widget.tableStyleDef,
          );
        },
        child: Container(
          key: _borderKey,
          width: tableStyle.borderWidth,
          height: widget.colsHeight,
          color: _borderHovering || _borderDragging
              ? widget.borderHoverColor
              : widget.borderColor,
        ),
      ),
    );
  }

  Container buildFixedBorder(BuildContext context) {
    return Container(
      width: tableStyle.borderWidth,
      height: widget.colsHeight,
      color: widget.borderColor,
    );
  }
}
