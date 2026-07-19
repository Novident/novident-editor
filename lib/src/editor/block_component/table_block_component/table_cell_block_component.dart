import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_action_handler.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCellBlockKeys {
  const TableCellBlockKeys._();

  static const String type = 'table/cell';

  static const String rowPosition = 'rowPosition';

  static const String colPosition = 'colPosition';

  static const String height = 'height';

  static const String width = 'width';

  static const String rowBackgroundColor = 'rowBackgroundColor';

  static const String colBackgroundColor = 'colBackgroundColor';
}

typedef TableBlockCellComponentColorBuilder = Color? Function(
  BuildContext context,
  Node node,
);

Node tableCellNode(String text, int rowPosition, int colPosition) {
  return Node(
    type: TableCellBlockKeys.type,
    attributes: {
      TableCellBlockKeys.rowPosition: rowPosition,
      TableCellBlockKeys.colPosition: colPosition,
    },
    children: [
      paragraphNode(text: text),
    ],
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
    return TableCelBlockWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      menuBuilder: menuBuilder,
      colorBuilder: colorBuilder,
      padding: padding,
      actionMenuItems: actionMenuItems,
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
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableBlockCellComponentColorBuilder? colorBuilder;

  /// The padding around the content of the cell.
  final EdgeInsets padding;

  /// The entries of the default context menu of the row handler.
  final List<TableActionMenuItem>? actionMenuItems;

  @override
  State<TableCelBlockWidget> createState() => _TableCeBlockWidgetState();
}

class _TableCeBlockWidgetState extends State<TableCelBlockWidget> {
  late final editorState = Provider.of<EditorState>(context, listen: false);
  bool _rowActionVisibility = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _rowActionVisibility = true),
          onExit: (_) => setState(() => _rowActionVisibility = false),
          child: Container(
            constraints: BoxConstraints(
              minHeight: context.select((Node n) => n.cellHeight),
            ),
            color: context.select(
              (Node n) =>
                  widget.colorBuilder?.call(context, n) ??
                  (n.attributes[TableCellBlockKeys.colBackgroundColor]
                          as String?)
                      ?.tryToColor() ??
                  (n.attributes[TableCellBlockKeys.rowBackgroundColor]
                          as String?)
                      ?.tryToColor(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: widget.padding,
                  child: editorState.renderer.build(
                    context,
                    widget.node.children.first,
                  ),
                ),
              ],
            ),
          ),
        ),
        TableActionHandler(
          visible: _rowActionVisibility,
          node: widget.node.parent!,
          editorState: editorState,
          position: widget.node.attributes[TableCellBlockKeys.rowPosition],
          transform: context.select((Node n) {
            final int col = n.attributes[TableCellBlockKeys.colPosition];
            double left = -12;
            for (var i = 0; i < col; i++) {
              left -= getCellNode(n.parent!, i, 0)?.cellWidth ??
                  TableDefaults.colWidth;
              left -= n.parent!.attributes['borderWidth'] ??
                  TableDefaults.borderWidth;
            }

            return Matrix4.translationValues(left, 0.0, 0.0);
          }),
          alignment: Alignment.centerLeft,
          height: context.select((Node n) => n.cellHeight),
          menuBuilder: widget.menuBuilder,
          actionMenuItems: widget.actionMenuItems,
          dir: TableDirection.row,
        ),
      ],
    );
  }
}
