import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef TableBlockCellComponentColorBuilder = Color? Function(
  BuildContext context,
  Node node,
);

/// Creates a table-cell [Node] with full control over its attributes.
///
/// The [child] is the content node rendered inside the cell (typically a
/// [paragraphNode] or [headingNode]).
///
/// Example:
/// ```dart
/// tableCellNode(
///   rowPosition: 0,
///   colPosition: 1,
///   child: paragraphNode(text: 'Hello'),
///   width: 120,
///   rowBackgroundColor: '0xFFE3F2FD',
/// )
/// ```
Node tableCellNode({
  required int rowPosition,
  required int colPosition,
  required Node child,
  double? colWeight,
  double? width,
  double? height,
  String? rowBackgroundColor,
  String? colBackgroundColor,
  EdgeInsets? cellPadding,
  TextAlign? cellAlignment,
  CrossAxisAlignment? cellVerticalAlignment,
  TextOverflow? cellTextOverflow,
  String? cellBackgroundColor,
}) {
  return Node(
    type: TableCellBlockKeys.type,
    attributes: {
      TableCellBlockKeys.rowPosition: rowPosition,
      TableCellBlockKeys.colPosition: colPosition,
      if (colWeight != null) TableCellBlockKeys.colWeight: colWeight,
      if (width != null) TableCellBlockKeys.width: width,
      if (height != null) TableCellBlockKeys.height: height,
      if (rowBackgroundColor != null)
        TableCellBlockKeys.rowBackgroundColor: rowBackgroundColor,
      if (colBackgroundColor != null)
        TableCellBlockKeys.colBackgroundColor: colBackgroundColor,
      if (cellPadding != null)
        TableCellBlockKeys.cellPadding: {
          'top': cellPadding.top,
          'bottom': cellPadding.bottom,
          'left': cellPadding.left,
          'right': cellPadding.right,
        },
      if (cellAlignment != null)
        TableCellBlockKeys.cellAlignment: cellAlignment.name,
      if (cellVerticalAlignment != null)
        TableCellBlockKeys.cellVerticalAlignment: cellVerticalAlignment.name,
      if (cellTextOverflow != null)
        TableCellBlockKeys.cellTextOverflow: cellTextOverflow.name,
      if (cellBackgroundColor != null)
        TableCellBlockKeys.cellBackgroundColor: cellBackgroundColor,
    },
    children: [child],
  );
}

class TableCellBlockComponentBuilder extends BlockComponentBuilder {
  TableCellBlockComponentBuilder({
    super.configuration,
    this.menuBuilder,
    this.colorBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
    this.actionMenuItems,
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableBlockCellComponentColorBuilder? colorBuilder;

  /// The entries of the default context menu of the row handlers.
  ///
  /// Defaults to [defaultTableActionMenuItems]. Pass the same list used in
  /// `TableBlockComponentBuilder.actionMenuItems` so rows and columns stay
  /// in sync.
  final List<TableActionMenuItem>? actionMenuItems;

  /// The padding around the content of every cell.
  ///
  /// Note: when adding vertical padding here, adjust
  /// [TableStyle.cellVerticalPadding] accordingly so the row height
  /// synchronization accounts for the extra space.
  final EdgeInsets padding;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    final context = blockComponentContext.buildContext;
    final tableStyle =
        NovidentTableStyleScope.of(context) ?? kDefaultTableStyle;
    return TableCelBlockWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      menuBuilder: menuBuilder,
      colorBuilder: colorBuilder,
      padding: padding,
      actionMenuItems: actionMenuItems,
      tableStyleDef: tableStyle,
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
  BlockComponentValidate get validate => (node) =>
      node.attributes.isNotEmpty &&
      node.attributes.containsKey(TableCellBlockKeys.rowPosition) &&
      node.attributes.containsKey(TableCellBlockKeys.colPosition);
}

class TableCelBlockWidget extends BlockComponentStatefulWidget {
  const TableCelBlockWidget({
    super.key,
    required super.node,
    this.menuBuilder,
    this.colorBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
    this.actionMenuItems,
    this.tableStyleDef,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableBlockCellComponentColorBuilder? colorBuilder;

  final EdgeInsets padding;

  final List<TableActionMenuItem>? actionMenuItems;

  final NovidentTableStyleDefinition? tableStyleDef;

  @override
  State<TableCelBlockWidget> createState() => _TableCeBlockWidgetState();
}

class _TableCeBlockWidgetState extends State<TableCelBlockWidget> {
  late final editorState = Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final style = widget.tableStyleDef ?? kDefaultTableStyle;
    final cellPadding = _resolveCellPadding(widget.node, widget.padding, style);

    return Container(
      constraints: BoxConstraints(
        minHeight: context.select((Node n) => n.cellHeight),
      ),
      color: context.select(
        (Node n) =>
            widget.colorBuilder?.call(context, n) ??
            (n.attributes[TableCellBlockKeys.colBackgroundColor] as String?)
                ?.tryToColor() ??
            (n.attributes[TableCellBlockKeys.rowBackgroundColor] as String?)
                ?.tryToColor(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: cellPadding,
            child: editorState.renderer.build(
              context,
              widget.node.children.first,
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets _resolveCellPadding(
    Node node,
    EdgeInsets builderPadding,
    NovidentTableStyleDefinition style,
  ) {
    final map = node.attributes[TableCellBlockKeys.cellPadding]
        as Map<String, dynamic>?;
    if (map != null) {
      return EdgeInsets.fromLTRB(
        (map['left'] as num?)?.toDouble() ?? 0,
        (map['top'] as num?)?.toDouble() ?? 0,
        (map['right'] as num?)?.toDouble() ?? 0,
        (map['bottom'] as num?)?.toDouble() ?? 0,
      );
    }
    return style.cellPadding ?? builderPadding;
  }
}
