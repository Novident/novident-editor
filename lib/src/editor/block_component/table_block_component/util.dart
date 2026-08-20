import 'package:novident_editor/novident_editor.dart';

@Deprecated(
  'Use TableNode.getCell(col, row) instead — it is O(1) indexed lookup',
)
Node? getCellNode(Node tableNode, int col, int row) {
  final table = TableNode(node: tableNode);
  if (col < 0 || col >= table.colsLen || row < 0 || row >= table.rowsLen) {
    return null;
  }
  return table.getCell(col, row);
}

extension TableCellNodeDynamicExtension on dynamic {
  double toDouble({double defaultValue = 0.0}) {
    if (this is int) {
      return this.toDouble();
    } else if (this is double) {
      return this;
    } else {
      return double.tryParse(toString()) ?? defaultValue;
    }
  }
}

extension TableCellNodeAttributesExtension on Node {
  /// Returns this cell's contribution to its column's width for layout
  /// calculations.
  ///
  /// Prefers [TableCellBlockKeys.colWeight] × [TableDefaults.colWidth] over
  /// the legacy [TableCellBlockKeys.width] for consistent weight-based
  /// layouts.
  double get cellWidth {
    assert(type == TableCellBlockKeys.type);
    final weight = attributes[TableCellBlockKeys.colWeight]?.toDouble();
    if (weight != null) return weight * TableDefaults.colWidth;
    return attributes[TableCellBlockKeys.width]?.toDouble() ??
        TableDefaults.colWidth;
  }

  double get cellHeight {
    assert(type == TableCellBlockKeys.type);
    return attributes[TableCellBlockKeys.height]?.toDouble() ??
        TableDefaults.rowHeight;
  }

  double get colHeight {
    assert(type == TableBlockKeys.type);
    return attributes[TableBlockKeys.colsHeight]?.toDouble() ??
        TableDefaults.rowHeight;
  }
}
