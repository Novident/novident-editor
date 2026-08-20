import 'package:collection/collection.dart';
import 'package:novident_editor/novident_editor.dart';

class TableActions {
  const TableActions._();

  static Future<void> add(
    Node node,
    int position,
    EditorState editorState,
    TableDirection dir,
    NovidentTableStyleDefinition style,
  ) async {
    if (dir == TableDirection.col) {
      _addCol(node, position, editorState, style);
    } else {
      await _addRow(node, position, editorState, style);
    }
  }

  static void delete(
    Node node,
    int position,
    EditorState editorState,
    TableDirection dir,
  ) {
    if (dir == TableDirection.col) {
      _deleteCol(node, position, editorState);
    } else {
      _deleteRow(node, position, editorState);
    }
  }

  static Future<void> duplicate(
    Node node,
    int position,
    EditorState editorState,
    TableDirection dir,
  ) async {
    if (dir == TableDirection.col) {
      _duplicateCol(node, position, editorState);
    } else {
      await _duplicateRow(node, position, editorState);
    }
  }

  static void clear(
    Node node,
    int position,
    EditorState editorState,
    TableDirection dir,
  ) {
    if (dir == TableDirection.col) {
      _clearCol(node, position, editorState);
    } else {
      _clearRow(node, position, editorState);
    }
  }

  static void setBgColor(
    Node node,
    int position,
    EditorState editorState,
    String? color,
    TableDirection dir,
  ) {
    if (dir == TableDirection.col) {
      _setColBgColor(node, position, editorState, color);
    } else {
      _setRowBgColor(node, position, editorState, color);
    }
  }

  /// Overrides [TableStyle.enableHorizontalScroll] for a single table.
  ///
  /// Pass `enable: null` to remove the override and fall back to the style
  /// value. The override is stored in the
  /// [TableBlockKeys.enableHorizontalScroll] attribute, so it is persisted
  /// with the document.
  static void setEnableHorizontalScroll(
    Node node,
    EditorState editorState, {
    required bool? enable,
  }) {
    assert(node.type == TableBlockKeys.type);

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      TableBlockKeys.enableHorizontalScroll: enable,
    });
    transaction.afterSelection = transaction.beforeSelection;
    editorState.apply(transaction);
  }

  /// Overrides [TableStyle.borderColor] for a single table.
  ///
  /// [color] is a hex color string (e.g. `0xFF9C27B0`); pass `null` to
  /// remove the override and fall back to the style value. The override is
  /// stored in the [TableBlockKeys.borderColor] attribute, so it is
  /// persisted with the document.
  static void setBorderColor(
    Node node,
    EditorState editorState, {
    required String? color,
  }) {
    assert(node.type == TableBlockKeys.type);

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      TableBlockKeys.borderColor: color,
    });
    transaction.afterSelection = transaction.beforeSelection;
    editorState.apply(transaction);
  }

  /// Overrides the border width of a single table.
  ///
  /// Pass `width: null` to remove the override and fall back to
  /// [TableStyle.borderWidth]. The value is stored in the
  /// [TableBlockKeys.borderWidth] attribute (the same attribute used by
  /// `TableConfig`), so it is persisted with the document and the grid
  /// geometry (row heights, column widths) is recomputed accordingly.
  static void setBorderWidth(
    Node node,
    EditorState editorState, {
    required double? width,
  }) {
    assert(node.type == TableBlockKeys.type);
    assert(width == null || width >= 0);

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      TableBlockKeys.borderWidth: width,
    });
    transaction.afterSelection = transaction.beforeSelection;
    editorState.apply(transaction);
  }
}

void _addCol(
  Node tableNode,
  int position,
  EditorState editorState,
  NovidentTableStyleDefinition style,
) {
  assert(position >= 0);

  final transaction = editorState.transaction;

  final List<Node> cellNodes = [];
  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen],
      colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  final table = TableNode(node: tableNode);

  if (position != colsLen) {
    for (var i = position; i < colsLen; i++) {
      for (var j = 0; j < rowsLen; j++) {
        final node = table.getCell(i, j);
        transaction.updateNode(node, {TableCellBlockKeys.colPosition: i + 1});
      }
    }
  }

  for (var i = 0; i < rowsLen; i++) {
    final node = Node(
      type: TableCellBlockKeys.type,
      attributes: {
        TableCellBlockKeys.colPosition: position,
        TableCellBlockKeys.rowPosition: i,
      },
    );
    node.insert(paragraphNode());
    final firstCellInRow = table.getCell(0, i);
    if (firstCellInRow.attributes
        .containsKey(TableCellBlockKeys.rowBackgroundColor)) {
      node.updateAttributes({
        TableCellBlockKeys.rowBackgroundColor:
            firstCellInRow.attributes[TableCellBlockKeys.rowBackgroundColor],
      });
    }

    cellNodes.add(
      newCellNode(
        tableNode,
        node,
        style,
      ),
    );
  }

  late Path insertPath;
  if (position == 0) {
    insertPath = table.getCell(0, 0).path;
  } else {
    insertPath = table.getCell(position - 1, rowsLen - 1).path.next;
  }
  // TODO: @CatHood0 this calls notifyListener rowsLen+1 times. isn't there a better
  // way?
  transaction.insertNodes(insertPath, cellNodes);
  transaction.updateNode(tableNode, {TableBlockKeys.colsLen: colsLen + 1});

  editorState.apply(transaction, withUpdateSelection: false);
}

Future<void> _addRow(
  Node tableNode,
  int position,
  EditorState editorState,
  NovidentTableStyleDefinition style,
) async {
  assert(position >= 0);

  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen];
  final int colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  final table = TableNode(node: tableNode);

  // generate new table cell nodes & update node attributes
  for (var i = 0; i < colsLen; i++) {
    final firstCellInCol = table.getCell(i, 0);
    final colBgColor =
        firstCellInCol.attributes[TableCellBlockKeys.colBackgroundColor];
    final containsColBgColor = colBgColor != null;

    final node = Node(
      type: TableCellBlockKeys.type,
      attributes: {
        TableCellBlockKeys.colPosition: i,
        TableCellBlockKeys.rowPosition: position,
        if (containsColBgColor)
          TableCellBlockKeys.colBackgroundColor: colBgColor,
      },
      children: [paragraphNode()],
    );

    late Path insertPath;
    if (position == 0) {
      insertPath = firstCellInCol.path;
    } else {
      final cellInPrevRow = table.getCell(i, position - 1);
      insertPath = cellInPrevRow.path.next;
    }

    final transaction = editorState.transaction;

    if (position != rowsLen) {
      for (var j = position; j < rowsLen; j++) {
        final cellNode = table.getCell(i, j);
        transaction.updateNode(
          cellNode,
          {
            TableCellBlockKeys.rowPosition: j + 1,
          },
        );
      }
    }

    transaction.insertNode(insertPath, node);

    await editorState.apply(transaction, withUpdateSelection: false);
  }

  final transaction = editorState.transaction;

  // update the row length
  transaction.updateNode(tableNode, {
    TableBlockKeys.rowsLen: rowsLen + 1,
  });

  await editorState.apply(transaction, withUpdateSelection: false);
}

void _deleteCol(Node tableNode, int col, EditorState editorState) {
  final transaction = editorState.transaction;

  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen],
      colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  if (colsLen == 1) {
    if (editorState.document.root.children.length == 1) {
      final emptyParagraph = paragraphNode();
      transaction.insertNode(tableNode.path, emptyParagraph);
    }
    transaction.deleteNode(tableNode);
    tableNode.dispose();
  } else {
    final table = TableNode(node: tableNode);
    final List<Node> nodes = [];
    for (var i = 0; i < rowsLen; i++) {
      nodes.add(table.getCell(col, i));
    }
    transaction.deleteNodes(nodes);

    _updateCellPositions(tableNode, editorState, col + 1, 0, -1, 0);

    transaction.updateNode(tableNode, {TableBlockKeys.colsLen: colsLen - 1});
  }

  editorState.apply(transaction, withUpdateSelection: false);
}

void _deleteRow(Node tableNode, int row, EditorState editorState) {
  final transaction = editorState.transaction;

  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen],
      colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  if (rowsLen == 1) {
    if (editorState.document.root.children.length == 1) {
      final emptyParagraph = paragraphNode();
      transaction.insertNode(tableNode.path, emptyParagraph);
    }
    transaction.deleteNode(tableNode);
    tableNode.dispose();
  } else {
    final table = TableNode(node: tableNode);
    final List<Node> nodes = [];
    for (var i = 0; i < colsLen; i++) {
      nodes.add(table.getCell(i, row));
    }
    transaction.deleteNodes(nodes);

    _updateCellPositions(tableNode, editorState, 0, row + 1, 0, -1);

    transaction.updateNode(tableNode, {TableBlockKeys.rowsLen: rowsLen - 1});
  }

  editorState.apply(transaction, withUpdateSelection: false);
}

void _duplicateCol(Node tableNode, int col, EditorState editorState) {
  final transaction = editorState.transaction;

  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen],
      colsLen = tableNode.attributes[TableBlockKeys.colsLen];
  final table = TableNode(node: tableNode);
  final List<Node> nodes = [];
  for (var i = 0; i < rowsLen; i++) {
    final node = table.getCell(col, i);
    nodes.add(
      node.copyWith(
        attributes: {
          ...node.attributes,
          TableCellBlockKeys.colPosition: col + 1,
          TableCellBlockKeys.rowPosition: i,
        },
      ),
    );
  }
  transaction.insertNodes(
    table.getCell(col, rowsLen - 1).path.next,
    nodes,
  );

  _updateCellPositions(tableNode, editorState, col + 1, 0, 1, 0);

  transaction.updateNode(tableNode, {TableBlockKeys.colsLen: colsLen + 1});

  editorState.apply(transaction, withUpdateSelection: false);
}

Future<void> _duplicateRow(
    Node tableNode, int row, EditorState editorState,) async {
  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen];
  final int colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  // Built while the table is still in a valid state: the copy must be
  // inserted BEFORE the rows below are shifted, otherwise there is a
  // transient gap at row+1 that invalidates the TableNode.
  final table = TableNode(node: tableNode);
  for (var i = 0; i < colsLen; i++) {
    final cell = table.getCell(i, row);
    final transaction = editorState.transaction;

    // Shift the rows below `row` down by one.
    for (var j = row + 1; j < rowsLen; j++) {
      final cellNode = table.getCell(i, j);
      transaction.updateNode(
        cellNode,
        {TableCellBlockKeys.rowPosition: j + 1},
      );
    }

    // Insert the copy right after the original cell.
    transaction.insertNode(
      cell.path.next,
      cell.copyWith(
        attributes: {
          ...cell.attributes,
          TableCellBlockKeys.rowPosition: row + 1,
          TableCellBlockKeys.colPosition: i,
        },
      ),
    );

    await editorState.apply(transaction, withUpdateSelection: false);
  }

  final transaction = editorState.transaction;
  transaction.updateNode(tableNode, {TableBlockKeys.rowsLen: rowsLen + 1});
  await editorState.apply(transaction, withUpdateSelection: false);
}

void _setColBgColor(
  Node tableNode,
  int col,
  EditorState editorState,
  String? color,
) {
  final transaction = editorState.transaction;

  final rowslen = tableNode.attributes[TableBlockKeys.rowsLen];
  final table = TableNode(node: tableNode);
  for (var i = 0; i < rowslen; i++) {
    final node = table.getCell(col, i);
    transaction.updateNode(
      node,
      {TableCellBlockKeys.colBackgroundColor: color},
    );
  }

  editorState.apply(transaction, withUpdateSelection: false);
}

void _setRowBgColor(
  Node tableNode,
  int row,
  EditorState editorState,
  String? color,
) {
  final transaction = editorState.transaction;

  final colsLen = tableNode.attributes[TableBlockKeys.colsLen];
  final table = TableNode(node: tableNode);
  for (var i = 0; i < colsLen; i++) {
    final node = table.getCell(i, row);
    transaction.updateNode(
      node,
      {TableCellBlockKeys.rowBackgroundColor: color},
    );
  }

  editorState.apply(transaction, withUpdateSelection: false);
}

void _clearCol(
  Node tableNode,
  int col,
  EditorState editorState,
) {
  final transaction = editorState.transaction;

  final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen];
  final table = TableNode(node: tableNode);
  for (var i = 0; i < rowsLen; i++) {
    final node = table.getCell(col, i);
    transaction.insertNode(
      node.children.first.path,
      paragraphNode(text: ''),
    );
  }

  editorState.apply(transaction, withUpdateSelection: false);
}

void _clearRow(
  Node tableNode,
  int row,
  EditorState editorState,
) {
  final transaction = editorState.transaction;

  final colsLen = tableNode.attributes[TableBlockKeys.colsLen];
  final table = TableNode(node: tableNode);
  for (var i = 0; i < colsLen; i++) {
    final node = table.getCell(i, row);
    transaction.insertNode(
      node.children.first.path,
      paragraphNode(text: ''),
    );
  }

  editorState.apply(transaction, withUpdateSelection: false);
}

Node newCellNode(
  Node tableNode,
  Node cell,
  NovidentTableStyleDefinition style,
) {
  final row = cell.attributes[TableCellBlockKeys.rowPosition] as int;
  final col = cell.attributes[TableCellBlockKeys.colPosition] as int;
  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen];
  final int colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  if (!cell.attributes.containsKey(TableCellBlockKeys.height)) {
    double nodeHeight = style.rowDefaultHeight;
    if (row < rowsLen) {
      final firstCellInRow = tableNode.children.firstWhereOrNull(
        (n) =>
            n.attributes[TableCellBlockKeys.colPosition] == 0 &&
            n.attributes[TableCellBlockKeys.rowPosition] == row,
      );
      if (firstCellInRow != null) {
        nodeHeight = double.tryParse(
              firstCellInRow.attributes[TableCellBlockKeys.height].toString(),
            ) ??
            nodeHeight;
      }
    }
    cell.updateAttributes({
      TableCellBlockKeys.height: nodeHeight,
    });
  }

  if (!cell.attributes.containsKey(TableCellBlockKeys.colWeight)) {
    double nodeWeight = style.colDefaultWeight;
    if (col < colsLen) {
      final firstCellInCol = tableNode.children.firstWhereOrNull(
        (n) =>
            n.attributes[TableCellBlockKeys.colPosition] == col &&
            n.attributes[TableCellBlockKeys.rowPosition] == 0,
      );
      if (firstCellInCol != null) {
        nodeWeight = double.tryParse(
              firstCellInCol.attributes[TableCellBlockKeys.colWeight]
                  .toString(),
            ) ??
            nodeWeight;
      }
    }
    cell.updateAttributes({
      TableCellBlockKeys.colWeight: nodeWeight,
    });
  }

  return cell;
}

void _updateCellPositions(
  Node tableNode,
  EditorState editorState,
  int fromCol,
  int fromRow,
  int addToCol,
  int addToRow,
) {
  final transaction = editorState.transaction;

  final int rowsLen = tableNode.attributes[TableBlockKeys.rowsLen],
      colsLen = tableNode.attributes[TableBlockKeys.colsLen];

  final table = TableNode(node: tableNode);

  for (var i = fromCol; i < colsLen; i++) {
    for (var j = fromRow; j < rowsLen; j++) {
      transaction.updateNode(table.getCell(i, j), {
        TableCellBlockKeys.colPosition: i + addToCol,
        TableCellBlockKeys.rowPosition: j + addToRow,
      });
    }
  }

  editorState.apply(transaction, withUpdateSelection: false);
}
