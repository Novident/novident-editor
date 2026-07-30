import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/material.dart';

class TableActionBar extends StatefulWidget {
  const TableActionBar({
    super.key,
    required this.tableNode,
    required this.editorState,
    this.actionMenuItems,
    this.menuBuilder,
  });

  final TableNode tableNode;
  final EditorState editorState;
  final List<TableActionMenuItem>? actionMenuItems;
  final TableBlockComponentMenuBuilder? menuBuilder;

  @override
  State<TableActionBar> createState() => _TableActionBarState();
}

class _TableActionBarState extends State<TableActionBar> {
  Path? _cachedSelectionPath;
  Node? _cachedCellNode;
  int? _cachedCol;
  int? _cachedRow;

  @override
  void initState() {
    super.initState();
    widget.editorState.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    if (!mounted) return;
    final sel = widget.editorState.selection;
    final tablePath = widget.tableNode.node.path;
    final inTable = sel != null &&
        tablePath.isNotEmpty &&
        sel.start.path.first == tablePath.first;
    final wasInTable = _cachedCellNode != null;
    if (!inTable && !wasInTable) return;
    _cachedSelectionPath = null;
    _cachedCellNode = null;
    setState(() {});
  }

  bool get _isFocused {
    final sel = widget.editorState.selection;
    final tablePath = widget.tableNode.node.path;
    return sel != null &&
        tablePath.isNotEmpty &&
        sel.start.path.contains(tablePath.first);
  }

  int get effectiveCol => _resolvePosition().$1;
  int get effectiveRow => _resolvePosition().$2;

  (int, int) _resolvePosition() {
    final sel = widget.editorState.selection;
    if (sel == null) return _fallback();

    final path = sel.start.path;

    if (path == _cachedSelectionPath &&
        _cachedCellNode != null &&
        _cachedCellNode!.parent?.type == TableCellBlockKeys.type) {
      return (_cachedCol!, _cachedRow!);
    }

    Node? cellNode;
    for (var i = path.length - 1; i >= 0; i--) {
      final node = widget.editorState.getNodeAtPath(
        path.sublist(
          0,
          i + 1,
        ),
      );
      if (node?.type == TableCellBlockKeys.type) {
        cellNode = node;
        break;
      }
    }

    if (cellNode != null) {
      _cachedSelectionPath = path;
      _cachedCellNode = cellNode;
      _cachedCol = cellNode.attributes[TableCellBlockKeys.colPosition] as int?;
      _cachedRow = cellNode.attributes[TableCellBlockKeys.rowPosition] as int?;
      if (_cachedCol != null && _cachedRow != null) {
        return (_cachedCol!, _cachedRow!);
      }
    }

    return _fallback();
  }

  (int, int) _fallback() {
    _cachedSelectionPath = null;
    _cachedCellNode = null;
    _cachedCol = null;
    _cachedRow = null;
    return (widget.tableNode.colsLen, widget.tableNode.rowsLen);
  }

  //TODO: @CatHood0 We can make a cache for this
  NovidentTableStyleDefinition get tableStyle {
    final styles = NovidentEditorStyles.maybeOf(context);
    final resolved = styles?.resolveStyle(widget.tableNode.node);
    return resolved is NovidentTableStyleDefinition
        ? resolved
        : kDefaultTableStyle;
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _isFocused;
    final col = effectiveCol;
    final row = effectiveRow;
    final colAtEnd = col >= widget.tableNode.colsLen;
    final rowAtEnd = row >= widget.tableNode.rowsLen;

    return SizedBox(
      height: isFocused ? 32 : 0,
        child: isFocused
            ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(
                    context,
                    icon: Icons.view_column,
                    tooltip: 'Add column before',
                    onTap: () => TableActions.add(
                      widget.tableNode.node,
                      colAtEnd ? widget.tableNode.colsLen : col,
                      widget.editorState,
                      TableDirection.col,
                      tableStyle,
                    ),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.table_rows,
                    tooltip: 'Add row above',
                    onTap: () => TableActions.add(
                      widget.tableNode.node,
                      rowAtEnd ? widget.tableNode.rowsLen : row,
                      widget.editorState,
                      TableDirection.row,
                      tableStyle,
                    ),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.delete_outline,
                    tooltip: 'Delete column',
                    enabled: !colAtEnd && widget.tableNode.colsLen > 1,
                    onTap: () => TableActions.delete(
                      widget.tableNode.node,
                      col,
                      widget.editorState,
                      TableDirection.col,
                    ),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.delete_forever,
                    tooltip: 'Delete row',
                    enabled: !rowAtEnd && widget.tableNode.rowsLen > 1,
                    onTap: () => TableActions.delete(
                      widget.tableNode.node,
                      row,
                      widget.editorState,
                      TableDirection.row,
                    ),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.colorize,
                    tooltip: 'Column color',
                    enabled: !colAtEnd,
                    onTap: () => _showColorDropdown(
                      context,
                      col: col,
                      row: row,
                      dir: TableDirection.col,
                    ),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.format_paint,
                    tooltip: 'Row color',
                    enabled: !rowAtEnd,
                    onTap: () => _showColorDropdown(
                      context,
                      col: col,
                      row: row,
                      dir: TableDirection.row,
                    ),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.border_color,
                    tooltip: 'Border color',
                    onTap: () => _showColorDropdown(
                      context,
                      col: col,
                      row: row,
                      dir: TableDirection.col,
                      isBorder: true,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? Theme.of(context).iconTheme.color
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showColorDropdown(
    BuildContext context, {
    required int col,
    required int row,
    required TableDirection dir,
    bool isBorder = false,
  }) {
    final node = widget.tableNode.node;
    final position = isBorder ? 0 : (dir == TableDirection.col ? col : row);
    final cell = !isBorder && dir == TableDirection.col
        ? getCellNode(node, col, 0)
        : !isBorder && dir == TableDirection.row
            ? getCellNode(node, 0, row)
            : null;
    final key = isBorder
        ? null
        : dir == TableDirection.col
            ? TableCellBlockKeys.colBackgroundColor
            : TableCellBlockKeys.rowBackgroundColor;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonOffset = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonOffset.dx,
        buttonOffset.dy + buttonSize.height,
        buttonOffset.dx + buttonSize.width,
        buttonOffset.dy + buttonSize.height,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ColorPicker(
            title: isBorder
                ? 'Border color'
                : dir == TableDirection.col
                    ? 'Column color'
                    : 'Row color',
            selectedColorHex: isBorder
                ? node.attributes[TableBlockKeys.borderColor]
                : cell?.attributes[key],
            colorOptions: generateHighlightColorOptions(),
            onSubmittedColorHex: (color, _) {
              if (isBorder) {
                TableActions.setBorderColor(
                  node,
                  widget.editorState,
                  color: color,
                );
              } else {
                TableActions.setBgColor(
                  node,
                  position,
                  widget.editorState,
                  color,
                  dir,
                );
              }
              Navigator.of(context).pop();
            },
            resetText: 'Clear',
            resetIconName: 'clear',
          ),
        ),
      ],
    );
  }
}
