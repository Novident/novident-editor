import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'table_view.dart';

class TableBlockKeys {
  const TableBlockKeys._();

  static const String type = 'table';

  static const String colDefaultWidth = 'colDefaultWidth';

  static const String rowDefaultHeight = 'rowDefaultHeight';

  static const String colMinimumWidth = 'colMinimumWidth';

  static const String borderWidth = 'borderWidth';

  static const String colsLen = 'colsLen';

  static const String rowsLen = 'rowsLen';

  static const String colsHeight = 'colsHeight';

  /// Per-table override of [TableStyle.enableHorizontalScroll].
  ///
  /// When the attribute is absent, the style value is used. Set it through
  /// [TableActions.setEnableHorizontalScroll].
  static const String enableHorizontalScroll = 'enableHorizontalScroll';

  /// Per-table override of [TableStyle.borderColor], stored as a hex color
  /// string (e.g. `0xFF9C27B0`).
  ///
  /// When the attribute is absent, the style value is used. Set it through
  /// [TableActions.setBorderColor].
  static const String borderColor = 'borderColor';
}

class TableStyle {
  final double colWidth;
  final double rowHeight;
  final double colMinimumWidth;
  final double borderWidth;
  final Widget addIcon;
  final Widget handlerIcon;
  final Color borderColor;
  final Color borderHoverColor;

  /// Extra vertical space added to the measured height of a cell's content
  /// when synchronizing the row heights.
  ///
  /// Defaults to 8 — the default vertical padding of a paragraph block. If
  /// you customize the vertical padding of the blocks rendered inside the
  /// cells (or the cell padding itself), adjust this value accordingly,
  /// otherwise the vertical borders will not match the real column height.
  final double cellVerticalPadding;

  /// Whether the table gets its own internal horizontal scroll view.
  ///
  /// When false, the table is laid out at its intrinsic width without an
  /// internal `SingleChildScrollView`/`Scrollbar`, letting the consumer
  /// decide how to handle the overflow (e.g. an external scroll view or a
  /// constrained layout).
  final bool enableHorizontalScroll;

  /// The padding around the table content.
  final EdgeInsets tablePadding;

  /// Whether the trailing "add column" button is shown.
  final bool showAddColumnButton;

  /// Whether the trailing "add row" button is shown.
  final bool showAddRowButton;

  const TableStyle({
    this.colWidth = 160,
    this.rowHeight = 40,
    this.colMinimumWidth = 40,
    this.borderWidth = 2,
    this.addIcon = TableDefaults.addIcon,
    this.handlerIcon = TableDefaults.handlerIcon,
    this.borderColor = TableDefaults.borderColor,
    this.borderHoverColor = TableDefaults.borderHoverColor,
    this.cellVerticalPadding = 8.0,
    this.enableHorizontalScroll = true,
    this.tablePadding = const EdgeInsets.only(top: 10, left: 10, bottom: 4),
    this.showAddColumnButton = true,
    this.showAddRowButton = true,
  });
}

class TableDefaults {
  const TableDefaults._();

  static double colWidth = 160.0;

  static double rowHeight = 40.0;

  static double colMinimumWidth = 40.0;

  static double borderWidth = 2.0;

  /// See [TableStyle.cellVerticalPadding].
  static double cellVerticalPadding = 8.0;

  static const Widget addIcon = Icon(Icons.add, size: 20);

  static const Widget handlerIcon = Icon(Icons.drag_indicator);

  static const Color borderColor = Colors.grey;

  static const Color borderHoverColor = Colors.blue;
}

enum TableDirection { row, col }

typedef TableBlockComponentMenuBuilder = Widget Function(
  Node,
  EditorState,
  int,
  TableDirection,
  VoidCallback?,
  VoidCallback?,
);

class TableBlockComponentBuilder extends BlockComponentBuilder {
  TableBlockComponentBuilder({
    super.configuration,
    this.tableStyle = const TableStyle(),
    this.menuBuilder,
    this.actionMenuItems,
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableStyle tableStyle;

  /// The entries of the default context menu of the column handlers.
  ///
  /// Defaults to [defaultTableActionMenuItems]. Pass a custom list to add,
  /// remove or reorder entries without replacing the whole menu. Remember to
  /// pass the same list to `TableCellBlockComponentBuilder.actionMenuItems`
  /// so the row handlers stay in sync.
  final List<TableActionMenuItem>? actionMenuItems;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    TableDefaults.colWidth = tableStyle.colWidth;
    TableDefaults.rowHeight = tableStyle.rowHeight;
    TableDefaults.colMinimumWidth = tableStyle.colMinimumWidth;
    TableDefaults.borderWidth = tableStyle.borderWidth;
    TableDefaults.cellVerticalPadding = tableStyle.cellVerticalPadding;
    return TableBlockComponentWidget(
      key: node.key,
      tableNode: TableNode(node: node),
      node: node,
      configuration: configuration,
      menuBuilder: menuBuilder,
      actionMenuItems: actionMenuItems,
      tableStyle: tableStyle,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) {
        // check the node is valid
        if (node.attributes.isEmpty) {
          NovidentEditorLog.editor
              .debug('TableBlockComponentBuilder: node is empty');
          return false;
        }

        // check the node has rowPosition and colPosition
        if (!node.attributes.containsKey(TableBlockKeys.colsLen) ||
            !node.attributes.containsKey(TableBlockKeys.rowsLen)) {
          NovidentEditorLog.editor.debug(
            'TableBlockComponentBuilder: node has no colsLen or rowsLen',
          );
          return false;
        }

        final colsLen = node.attributes[TableBlockKeys.colsLen];
        final rowsLen = node.attributes[TableBlockKeys.rowsLen];

        // check its children
        final children = node.children;
        if (children.isEmpty) {
          NovidentEditorLog.editor
              .debug('TableBlockComponentBuilder: children is empty');
          return false;
        }

        if (children.length != colsLen * rowsLen) {
          NovidentEditorLog.editor.debug(
            'TableBlockComponentBuilder: children length(${children.length}) is not equal to colsLen * rowsLen($colsLen * $rowsLen)',
          );
          return false;
        }

        // all children should contain rowPosition and colPosition
        for (var i = 0; i < colsLen; i++) {
          for (var j = 0; j < rowsLen; j++) {
            final child = children.where(
              (n) =>
                  n.attributes[TableCellBlockKeys.colPosition] == i &&
                  n.attributes[TableCellBlockKeys.rowPosition] == j,
            );
            if (child.isEmpty) {
              NovidentEditorLog.editor.debug(
                'TableBlockComponentBuilder: child($i, $j) is empty',
              );
              return false;
            }

            // should only contains one child
            if (child.length != 1) {
              NovidentEditorLog.editor.debug(
                'TableBlockComponentBuilder: child($i, $j) is not unique',
              );
              return false;
            }
          }
        }

        return true;
      };
}

class TableBlockComponentWidget extends BlockComponentStatefulWidget {
  const TableBlockComponentWidget({
    super.key,
    required this.tableNode,
    required super.node,
    this.tableStyle = const TableStyle(),
    this.menuBuilder,
    this.actionMenuItems,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  final TableNode tableNode;

  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu of the column handlers.
  final List<TableActionMenuItem>? actionMenuItems;

  final TableStyle tableStyle;

  @override
  State<TableBlockComponentWidget> createState() =>
      _TableBlockComponentWidgetState();
}

class _TableBlockComponentWidgetState extends State<TableBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  late final editorState = Provider.of<EditorState>(context, listen: false);
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final tableView = TableView(
      tableNode: widget.tableNode,
      editorState: editorState,
      menuBuilder: widget.menuBuilder,
      actionMenuItems: widget.actionMenuItems,
      tableStyle: widget.tableStyle,
    );

    // per-table override of the style value; see
    // [TableBlockKeys.enableHorizontalScroll].
    final enableHorizontalScroll = context.select((Node n) {
          final value = n.attributes[TableBlockKeys.enableHorizontalScroll];
          return value is bool ? value : null;
        }) ??
        widget.tableStyle.enableHorizontalScroll;

    Widget child;
    if (enableHorizontalScroll) {
      child = Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          padding: widget.tableStyle.tablePadding,
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: tableView,
        ),
      );
    } else {
      child = Padding(
        padding: widget.tableStyle.tablePadding,
        child: tableView,
      );
    }

    child = Padding(
      key: tableKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
      ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }

  final tableKey = GlobalKey();

  RenderBox get _renderBox => context.findRenderObject() as RenderBox;

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = context.findRenderObject();
    final tableBox = tableKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && tableBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? tableBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            tableBox.size,
      ];
    }
    return [Offset.zero & _renderBox.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) =>
      _renderBox.localToGlobal(offset);

  @override
  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    return getRectsInSelection(Selection.invalid()).first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final size = _renderBox.size;
    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }
}

SelectionMenuItem tableMenuItem = SelectionMenuItem(
  getName: () => NovidentEditorL10n.current.table,
  icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
    icon: Icons.table_view,
    isSelected: isSelected,
    style: style,
  ),
  keywords: ['table'],
  handler: (editorState, _, __) {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }

    final currentNode = editorState.getNodeAtPath(selection.end.path);
    if (currentNode == null) {
      return;
    }

    final tableNode = TableNode.fromList([
      ['', ''],
      ['', ''],
    ]);

    final transaction = editorState.transaction;
    final delta = currentNode.delta;
    if (delta != null && delta.isEmpty) {
      transaction
        ..insertNode(selection.end.path, tableNode.node)
        ..deleteNode(currentNode);
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: selection.end.path + [0, 0],
          offset: 0,
        ),
      );
    } else {
      transaction.insertNode(selection.end.path.next, tableNode.node);
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: selection.end.path.next + [0, 0],
          offset: 0,
        ),
      );
    }

    editorState.apply(transaction);
  },
);
