import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCellBlockKeys {
  const TableCellBlockKeys._();

  static const String type = 'table/cell';

  static const String rowPosition = 'rowPosition';

  static const String colPosition = 'colPosition';

  static const String height = 'height';

  /// Relative weight of the column this cell belongs to.
  ///
  /// Columns with higher [colWeight] get proportionally more horizontal
  /// space. A column without an explicit [colWeight] defaults to 1.0.
  ///
  /// Replaces the legacy [width] attribute for layout purposes, though
  /// [width] is still stored for backward compatibility.
  static const String colWeight = 'colWeight';

  /// Legacy absolute pixel width. Still written by the resize logic for
  /// backward compatibility, but no longer used for layout. Use [colWeight]
  /// instead.
  static const String width = 'width';

  static const String rowBackgroundColor = 'rowBackgroundColor';

  static const String colBackgroundColor = 'colBackgroundColor';

  /// Per-cell border override. Stored as Map with keys:
  /// `top`, `bottom`, `left`, `right` — each a Map of
  /// `color` (String hex), `width` (double), `style` (String).
  static const String cellBorder = 'cellBorder';

  /// Per-cell padding override. Map with `top`, `bottom`,
  /// `left`, `right` double values.
  static const String cellPadding = 'cellPadding';

  /// Horizontal text alignment for this cell. Stored as String
  /// matching [TextAlign] enum values.
  static const String cellAlignment = 'cellAlignment';

  /// Vertical content alignment. Stored as String matching
  /// [CrossAxisAlignment] enum values.
  static const String cellVerticalAlignment = 'cellVerticalAlignment';

  /// Text overflow behavior. Stored as String matching
  /// [TextOverflow] enum values.
  static const String cellTextOverflow = 'cellTextOverflow';

  /// Background color override for this specific cell (overrides
  /// row/col/even-odd striping). Stored as hex String.
  static const String cellBackgroundColor = 'cellBackgroundColor';
}

typedef TableBlockCellComponentColorBuilder = Color? Function(
  BuildContext context,
  Node node,
);

/// Serializes a [Border] to a JSON-compatible [Map] for node storage.
Map<String, dynamic> borderToMap(Border border) => {
      'top': _borderSideToMap(border.top),
      'bottom': _borderSideToMap(border.bottom),
      'left': _borderSideToMap(border.left),
      'right': _borderSideToMap(border.right),
    };

Map<String, dynamic> _borderSideToMap(BorderSide side) => {
      'color': side.color.toHex(),
      'width': side.width,
      'style': side.style.name,
    };

/// Deserializes a [Border] from node attribute map.
Border? borderFromMap(Map<String, dynamic>? map) {
  if (map == null) return null;
  return Border(
    top: _borderSideFromMap(map['top'] as Map<String, dynamic>?),
    bottom: _borderSideFromMap(map['bottom'] as Map<String, dynamic>?),
    left: _borderSideFromMap(map['left'] as Map<String, dynamic>?),
    right: _borderSideFromMap(map['right'] as Map<String, dynamic>?),
  );
}

BorderSide _borderSideFromMap(Map<String, dynamic>? map) {
  if (map == null) return BorderSide.none;
  return BorderSide(
    color: (map['color'] as String?)?.tryToColor() ?? Colors.black,
    width: (map['width'] as num?)?.toDouble() ?? 1.0,
    style: BorderStyle.values.firstWhere(
      (s) => s.name == map['style'],
      orElse: () => BorderStyle.solid,
    ),
  );
}

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
  Border? cellBorder,
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
      if (cellBorder != null)
        TableCellBlockKeys.cellBorder: borderToMap(cellBorder),
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
    final tableStyle = NovidentTableStyleScope.of(context) ?? kDefaultTableStyle;
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
    return Container(
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
    );
  }
}
