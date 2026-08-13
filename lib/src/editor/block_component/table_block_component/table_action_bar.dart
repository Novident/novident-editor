import 'package:novident_editor/novident_editor.dart';
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
    widget.editorState.editableNotifier.addListener(_onEditableChange);
  }

  void _onEditableChange() {
    if (!mounted) return;
    _safeUpdate();
  }

  @override
  void dispose() {
    widget.editorState.editableNotifier.removeListener(_onEditableChange);
    widget.editorState.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    if (!mounted) return;
    final inTable = _isSelectionInTable;
    final wasInTable = _cachedCellNode != null;
    if (!inTable && !wasInTable) return;
    _cachedSelectionPath = null;
    _cachedCellNode = null;
    _safeUpdate();
  }

  void _safeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  bool get _isVisible {
    if (!widget.editorState.editorStyle.showTableActionBar) return false;
    if (!widget.editorState.editable) return false;
    return true;
  }

  bool get _isSelectionInTable {
    final sel = widget.editorState.selection;
    final tablePath = widget.tableNode.node.path;
    return sel != null &&
        tablePath.isNotEmpty &&
        sel.isSingle &&
        sel.start.path.first == tablePath.first;
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
    //TODO: @CatHood0 isn't using getNodeAtPath into a for loop too expensive?
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
    final resolved = styles?.resolveStyleForNode(widget.tableNode.node);
    return resolved is NovidentTableStyleDefinition
        ? resolved
        : kDefaultTableStyle;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.actionMenuItems;
    final isFocused = _isVisible;

    if (items == null || items.isEmpty || !isFocused) {
      return const SizedBox.shrink();
    }

    final List<Widget> actionButtons;
    actionButtons = _buildActionButtonsFromItems(context, items);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 32,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: actionButtons,
        ),
      ),
    );
  }

  /// Builds buttons from the provided [TableActionMenuItem] list.
  ///
  /// Each item is rendered once. Direction-aware items use their
  /// [TableActionMenuItem.direction] to resolve the target position
  /// and direction context. Direction-agnostic items (direction: null)
  /// are rendered once with a neutral column context.
  List<Widget> _buildActionButtonsFromItems(
    BuildContext context,
    List<TableActionMenuItem> items,
  ) {
    final isInTable = _isSelectionInTable;
    final col = effectiveCol;
    final row = effectiveRow;
    final colAtEnd = col >= widget.tableNode.colsLen;
    final rowAtEnd = row >= widget.tableNode.rowsLen;
    final node = widget.tableNode.node;

    final List<Widget> buttons = [];

    for (final TableActionMenuItem item in items) {
      final isCol = item.direction == TableDirection.col;
      final position = isCol ? col : row;
      final atEnd = isCol ? colAtEnd : rowAtEnd;
      final minCount =
          isCol ? widget.tableNode.colsLen : widget.tableNode.rowsLen;
      final direction = item.direction ?? TableDirection.col;

      // Respect the item's visibility predicate
      final isVisible = item.visible?.call(node, position) ?? true;
      if (!isVisible) continue;

      final icon = item.icon;
      final tooltip = item.name;
      final enabled = item.direction != null
          ? isInTable && !atEnd && minCount > 0
          : isInTable;

      buttons.add(
        Builder(
          builder: (buttonContext) {
            return item.builder?.call(
                  buttonContext,
                  icon: icon,
                  tooltip: tooltip,
                  enabled: enabled,
                  onTap: () {
                    _defaultOnTap(
                      buttonContext,
                      item,
                      node,
                      position,
                      direction,
                    );
                  },
                ) ??
                _actionButton(
                  context,
                  icon: icon,
                  tooltip: tooltip,
                  enabled: enabled,
                  onTap: () {
                    _defaultOnTap(
                      buttonContext,
                      item,
                      node,
                      position,
                      direction,
                    );
                  },
                );
          },
        ),
      );
    }

    return buttons;
  }

  void _defaultOnTap(
    BuildContext buttonContext,
    TableActionMenuItem item,
    Node node,
    int position,
    TableDirection direction,
  ) {
    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    // Compute position for secondary overlays (e.g. color pickers)
    final editorRenderBox = widget.editorState.renderBox!;
    final editorOffset = editorRenderBox.localToGlobal(Offset.zero);
    final editorHeight = editorRenderBox.size.height;
    final threshold = editorOffset.dy + editorHeight - 200;
    double? overlayTop;
    double? overlayBottom;
    if (buttonOffset.dy > threshold) {
      overlayBottom = editorOffset.dy + editorHeight - buttonOffset.dy - 5;
    } else {
      overlayTop = buttonOffset.dy + buttonSize.height + 5;
    }
    final overlayLeft = buttonOffset.dx + 10;

    item.onPressed(
      TableActionMenuContext(
        buildContext: buttonContext,
        node: node,
        editorState: widget.editorState,
        position: position,
        dir: direction,
        dismiss: () {},
        top: overlayTop,
        bottom: overlayBottom,
        left: overlayLeft,
      ),
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
}
