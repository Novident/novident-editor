import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'table_view.dart';

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
    this.menuBuilder,
    this.actionMenuItems,
    this.tableStyleDef,
  });

  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu of the column handlers.
  ///
  /// Defaults to [defaultTableActionMenuItems]. Pass a custom list to add,
  /// remove or reorder entries without replacing the whole menu. Remember to
  /// pass the same list to `TableCellBlockComponentBuilder.actionMenuItems`
  /// so the row handlers stay in sync.
  final List<TableActionMenuItem>? actionMenuItems;

  /// An explicit [NovidentTableStyleDefinition] to use as fallback when
  /// [NovidentEditorStyles.resolveStyle] returns a non-table style or null.
  ///
  /// When omitted, [kDefaultTableStyle] is used. This is useful in tests
  /// that need to inject a style without a full [NovidentEditorStyles] setup.
  final NovidentTableStyleDefinition? tableStyleDef;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    final context = blockComponentContext.buildContext;

    // Resolve the effective style for this table node.
    final styles = NovidentEditorStyles.maybeOf(context);
    final resolved = styles?.resolveStyle(node);
    final effective = resolved is NovidentTableStyleDefinition
        ? resolved
        : (tableStyleDef ?? kDefaultTableStyle);

    return TableBlockComponentWidget(
      key: node.key,
      tableNode: TableNode(node: node),
      node: node,
      configuration: configuration,
      menuBuilder: menuBuilder,
      actionMenuItems: actionMenuItems,
      tableStyleDef: effective,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (
        context,
        state,
      ) =>
          actionTrailingBuilder(
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
    this.tableStyleDef,
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

  /// The resolved [NovidentTableStyleDefinition] for this table, if any.
  final NovidentTableStyleDefinition? tableStyleDef;

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

  NovidentTableStyleDefinition get tableStyle {
    return widget.tableStyleDef ?? kDefaultTableStyle;
  }

  double _cachedAvailableWidth = -1;
  int _cachedWeightHash = -1;
  List<double>? _cachedWidths;

  int _weightHash(TableNode t) {
    var h = t.colsLen;
    for (var i = 0; i < t.colsLen; i++) {
      h = h * 31 + (t.getColWeight(i, tableStyle) * 1000).round();
    }
    return h;
  }

  List<double> _columnWidths(
    double availableWidth,
    TableNode tableNode, {
    bool noBorder = false,
  }) {
    final hash = _weightHash(tableNode);
    if (availableWidth == _cachedAvailableWidth &&
        hash == _cachedWeightHash &&
        _cachedNoBorder == noBorder &&
        _cachedWidths != null &&
        _cachedWidths!.length == tableNode.colsLen) {
      return _cachedWidths!;
    }
    _cachedAvailableWidth = availableWidth;
    _cachedWeightHash = hash;
    _cachedNoBorder = noBorder;
    _cachedWidths = tableNode.distributeColumnWidths(
      availableWidth,
      noBorder: noBorder,
      style: tableStyle,
    );
    return _cachedWidths!;
  }

  bool _cachedNoBorder = false;

  @override
  Widget build(BuildContext context) {
    final style = tableStyle;
    final noBorder = style.noBorder;
    // Per-table override: node attribute > style default.
    final borderPx = noBorder
        ? 0.0
        : (widget.node.attributes[TableBlockKeys.borderWidth] as double?) ??
            style.verticalBorderWidth;

    final enableHorizontalScroll = context.select((Node n) {
          final value = n.attributes[TableBlockKeys.enableHorizontalScroll];
          return value is bool ? value : null;
        }) ??
        tableStyle.enableHorizontalScroll;

    Widget tableArea = LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableNode = widget.tableNode;
        final tablePadding = tableStyle.tablePadding;

        // Minimum total width: all columns at colMinimumWidth + borders.
        final minWidth = (tableStyle.colMinimumWidth * tableNode.colsLen) +
            borderPx * (tableNode.colsLen + 1);

        if (enableHorizontalScroll && availableWidth < minWidth) {
          // Content overflows — render at minimum intrinsic widths.
          final scrollWidths = _columnWidths(
            minWidth,
            tableNode,
            noBorder: noBorder,
          );
          return Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              padding: tablePadding,
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: minWidth,
                child: TableView(
                  tableNode: tableNode,
                  editorState: editorState,
                  menuBuilder: widget.menuBuilder,
                  actionMenuItems: widget.actionMenuItems,
                  tableStyleDef: tableStyle,
                  columnWidths: scrollWidths,
                ),
              ),
            ),
          );
        } else {
          // Content fits — distribute available width by weights.
          final contentWidth = availableWidth - tablePadding.horizontal;
          final fittedWidths = _columnWidths(
            contentWidth,
            tableNode,
            noBorder: noBorder,
          );
          return Padding(
            padding: tablePadding,
            child: TableView(
              tableNode: tableNode,
              editorState: editorState,
              menuBuilder: widget.menuBuilder,
              actionMenuItems: widget.actionMenuItems,
              tableStyleDef: tableStyle,
              columnWidths: fittedWidths,
            ),
          );
        }
      },
    );

    Widget child = Padding(
      key: tableKey,
      padding: padding,
      child: tableArea,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      host: editorState,
      renderer: editorState.editorStyle.selectionRenderer,
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
      ['', '', ''],
      ['', '', ''],
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
