import 'dart:math';

import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_config.dart';

class TableNode {
  final TableConfig _config;

  final Node node;
  final List<List<Node>> _cells = [];

  TableNode({
    required this.node,
  }) : _config = TableConfig.fromJson(node.attributes) {
    if (node.type != TableBlockKeys.type) {
      NovidentEditorLog.editor.debug('TableNode: node is not a table');
      return;
    }

    final attributes = node.attributes;
    final colsLen = attributes[TableBlockKeys.colsLen];
    final rowsLen = attributes[TableBlockKeys.rowsLen];

    if (colsLen == null ||
        rowsLen == null ||
        colsLen is! int ||
        rowsLen is! int) {
      NovidentEditorLog.editor.debug(
        'TableNode: colsLen or rowsLen is not an integer or null',
      );
      return;
    }

    if (node.children.length != colsLen * rowsLen) {
      NovidentEditorLog.editor.debug(
        'TableNode: the number of children is not equal to the number of cells',
      );
      return;
    }

    // every cell should has rowPosition and colPosition to indicate its position in the table
    for (final child in node.children) {
      if (!child.attributes.containsKey(TableCellBlockKeys.rowPosition) ||
          !child.attributes.containsKey(TableCellBlockKeys.colPosition)) {
        NovidentEditorLog.editor
            .debug('TableNode: cell has no rowPosition or colPosition');
        return;
      }
    }

    for (var i = 0; i < colsLen; i++) {
      _cells.add([]);
      for (var j = 0; j < rowsLen; j++) {
        final cell = node.children
            .where(
              (n) =>
                  n.attributes[TableCellBlockKeys.colPosition] == i &&
                  n.attributes[TableCellBlockKeys.rowPosition] == j,
            )
            .firstOrNull;

        if (cell == null) {
          NovidentEditorLog.editor.debug('TableNode: cell is empty');
          _cells.clear();
          return;
        }

        _cells[i].add(newCellNode(node, cell));
      }
    }
  }

  factory TableNode.fromJson(Map<String, Object> json) {
    return TableNode(node: Node.fromJson(json));
  }

  /// Creates a [TableNode] from a grid of plain strings.
  ///
  /// Each cell is automatically wrapped in a [paragraphNode]. For full control
  /// over cell content (headings, styled text, nested blocks), use [fromNodes]
  /// instead.
  ///
  /// The outer list represents **columns** (column-major order). Each inner
  /// list contains the rows for that column. The first sublist is the first
  /// column rendered on the left.
  ///
  /// Example (renders as a 2×2 table with Name/Elara on the left column):
  /// ```dart
  /// final table = TableNode.fromList([
  ///   ['Name', 'Elara'],   // ← column 0
  ///   ['Role', 'Mage'],    // ← column 1
  /// ]);
  /// // | Name | Role  |
  /// // | Elara| Mage  |
  /// ```
  static TableNode fromList(
    List<List<String>> cols, {
    TableConfig? config,
  }) {
    assert(cols.isNotEmpty, 'cols must not be empty');
    assert(cols[0].isNotEmpty, 'rows must not be empty');
    assert(
      cols.every((col) => col.length == cols[0].length),
      'all columns must have the same number of rows',
    );

    config = config ?? TableConfig();

    final tableAttrs = <String, Object>{
      TableBlockKeys.colsLen: cols.length,
      TableBlockKeys.rowsLen: cols[0].length,
      ...config.toJson(),
    };

    final node = Node(type: TableBlockKeys.type, attributes: tableAttrs);

    for (var c = 0; c < cols.length; c++) {
      for (var r = 0; r < cols[0].length; r++) {
        final cell = Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.colPosition: c,
            TableCellBlockKeys.rowPosition: r,
          },
        );
        cell.insert(paragraphNode(text: cols[c][r]));
        node.insert(cell);
      }
    }

    return TableNode(node: node);
  }

  /// Creates a [TableNode] from a grid of [Node]s.
  ///
  /// Unlike [fromList], this accepts any node type as cell content —
  /// [headingNode], styled [paragraphNode]s, or custom block components.
  ///
  /// The outer list represents **columns** (column-major order). Each inner
  /// list contains the rows for that column.
  ///
  /// For per-cell attributes (width, background colors), wrap the content
  /// with [tableCellNode] before passing it. When a node is already a cell
  /// wrapper (`type == 'table/cell'`), its attributes are preserved and only
  /// `colPosition`/`rowPosition` are overridden.
  ///
  /// Example (renders as a 2×2 table with a heading on the top-left):
  /// ```dart
  /// final table = TableNode.fromNodes([
  ///   [headingNode(level: 3, text: 'Name'), paragraphNode(text: 'Elara')], // col 0
  ///   [paragraphNode(text: 'Role'),          paragraphNode(text: 'Mage')],  // col 1
  /// ]);
  /// // | Name (h3) | Role  |
  /// // | Elara      | Mage  |
  /// ```
  static TableNode fromNodes(
    List<List<Node>> cols, {
    TableConfig? config,
  }) {
    assert(cols.isNotEmpty, 'cols must not be empty');
    assert(cols[0].isNotEmpty, 'rows must not be empty');
    assert(
      cols.every((col) => col.length == cols[0].length),
      'all columns must have the same number of rows',
    );

    config = config ?? TableConfig();

    final tableAttrs = <String, Object>{
      TableBlockKeys.colsLen: cols.length,
      TableBlockKeys.rowsLen: cols[0].length,
      ...config.toJson(),
    };

    final node = Node(type: TableBlockKeys.type, attributes: tableAttrs);

    for (var c = 0; c < cols.length; c++) {
      for (var r = 0; r < cols[0].length; r++) {
        final content = cols[c][r];

        final Node cell;
        if (content.type == TableCellBlockKeys.type) {
          // Already a cell wrapper (e.g. from tableCellNode) — keep its
          // attributes (width, background, etc.) but override positions.
          cell = content.copyWith(
            attributes: {
              ...content.attributes,
              TableCellBlockKeys.colPosition: c,
              TableCellBlockKeys.rowPosition: r,
            },
          );
        } else {
          // Raw content node — wrap in a fresh cell.
          cell = Node(
            type: TableCellBlockKeys.type,
            attributes: {
              TableCellBlockKeys.colPosition: c,
              TableCellBlockKeys.rowPosition: r,
            },
          );
          cell.insert(content);
        }

        node.insert(cell);
      }
    }

    return TableNode(node: node);
  }

  Node getCell(int col, row) => _cells[col][row];

  TableConfig get config => _config;

  int get colsLen => _cells.length;

  int get rowsLen => _cells.isNotEmpty ? _cells[0].length : 0;

  /// Returns the height of [row].
  ///
  /// The height is read from every column of the row (the maximum wins), so
  /// a stale attribute in a single column can no longer shrink the vertical
  /// borders of the whole table.
  double getRowHeight(int row) {
    double? height;
    for (final col in _cells) {
      final colHeight = double.tryParse(
        col[row].attributes[TableCellBlockKeys.height].toString(),
      );
      if (colHeight != null) {
        height = height == null ? colHeight : max(height, colHeight);
      }
    }
    return height ?? _config.rowDefaultHeight;
  }

  double get colsHeight =>
      List.generate(rowsLen, (idx) => idx).fold<double>(
        0,
        (prev, cur) => prev + getRowHeight(cur) + _config.borderWidth,
      ) +
      _config.borderWidth;

  /// Returns the relative weight of column [col].
  ///
  /// Reads [TableCellBlockKeys.colWeight] from the first cell of the column.
  /// Falls back to [TableConfig.colDefaultWeight] (default 1.0) when the
  /// attribute is absent.
  double getColWeight(int col) {
    final weight = double.tryParse(
      _cells[col][0].attributes[TableCellBlockKeys.colWeight].toString(),
    );
    if (weight != null) return weight;

    // Migration path: legacy documents may only have pixel width.
    // Convert to a proportional weight.
    final width = double.tryParse(
      _cells[col][0].attributes[TableCellBlockKeys.width].toString(),
    );
    if (width != null) return width / TableDefaults.colWidth;

    return _config.colDefaultWeight;
  }

  /// Returns the sum of all column weights for proportional distribution.
  double get totalWeight =>
      List.generate(colsLen, (i) => i).fold<double>(
        0,
        (prev, i) => prev + getColWeight(i),
      );

  /// Distributes [availableWidth] (pixels available for content) across
  /// columns according to their weights.
  ///
  /// Each column receives at least [TableConfig.colMinimumWidth] pixels.
  List<double> distributeColumnWidths(double availableWidth) {
    final totalBorders = _config.borderWidth * (colsLen + 1);
    final usableWidth = (availableWidth - totalBorders).clamp(0, double.infinity);

    final weights = List.generate(colsLen, getColWeight);
    final sumWeights = weights.fold<double>(0, (a, b) => a + b);

    if (sumWeights == 0) {
      return List.filled(colsLen, _config.colMinimumWidth);
    }

    // First pass: proportional distribution
    final widths = List.generate(colsLen, (i) {
      return (weights[i] / sumWeights * usableWidth)
          .clamp(_config.colMinimumWidth, double.infinity);
    });

    // Reclaim excess from clamped-down columns and redistribute
    double totalUsed = widths.fold(0, (a, b) => a + b);
    if (totalUsed < usableWidth) {
      final unclampedSum = weights
          .asMap()
          .entries
          .where((e) => widths[e.key] > _config.colMinimumWidth)
          .fold<double>(0, (a, e) => a + weights[e.key]);

      if (unclampedSum > 0) {
        final extra = usableWidth - totalUsed;
        for (var i = 0; i < colsLen; i++) {
          if (widths[i] > _config.colMinimumWidth) {
            widths[i] += (weights[i] / unclampedSum) * extra;
          }
        }
      }
    }

    return widths;
  }

  /// Legacy pixel-width accessor. Delegates to the weight system; the
  /// actual rendered width depends on available space (see
  /// [distributeColumnWidths]).
  ///
  /// Returns the weight scaled by [TableDefaults.colWidth] for backward
  /// compatibility with code that expects a pixel value.
  double getColWidth(int col) =>
      getColWeight(col) * TableDefaults.colWidth;

  /// Total intrinsic width in legacy pixel units. Prefer [totalWeight] for
  /// layout decisions.
  double get tableWidth =>
      List.generate(colsLen, (idx) => idx).fold<double>(
        0,
        (prev, cur) => prev + getColWidth(cur) + _config.borderWidth,
      ) +
      _config.borderWidth;

  /// Sets the weight of column [col] and updates all cells in that column.
  ///
  /// This is the replacement for the legacy [setColWidth]. When the user
  /// drags a column border, the new pixel width is converted to a weight
  /// relative to the available space.
  void setColWeight(
    int col,
    double weight, {
    Transaction? transaction,
    bool force = false,
  }) {
    final clamped = weight < 0.1 ? 0.1 : weight;
    if (getColWeight(col) != clamped || force) {
      for (var i = 0; i < rowsLen; i++) {
        if (transaction != null) {
          transaction.updateNode(
            _cells[col][i],
            {TableCellBlockKeys.colWeight: clamped},
          );
        } else {
          _cells[col][i]
              .updateAttributes({TableCellBlockKeys.colWeight: clamped});
        }
        updateRowHeight(i, transaction: transaction);
      }
      if (transaction != null) {
        transaction.updateNode(node, node.attributes);
      } else {
        node.updateAttributes(node.attributes);
      }
    }
  }

  /// Legacy pixel-width setter. Converts the pixel value to a weight and
  /// delegates to [setColWeight].
  void setColWidth(
    int col,
    double w, {
    Transaction? transaction,
    bool force = false,
  }) {
    setColWeight(col, w / TableDefaults.colWidth,
        transaction: transaction, force: force);
  }

  void updateRowHeight(
    int row, {
    EditorState? editorState,
    Transaction? transaction,
  }) {
    // The extra space matches the default vertical padding of the paragraph
    // inside the cell. It is configurable through
    // `TableStyle.cellVerticalPadding` (see `TableDefaults.cellVerticalPadding`).
    double maxHeight = _cells
        .map<double>(
          (c) =>
              c[row].children.first.rect.height +
              TableDefaults.cellVerticalPadding,
        )
        .reduce(max);

    // Compare against every column — checking only the first one can skip
    // the synchronization when column 0 is already up to date but the other
    // columns are stale (partial transactions, undo/redo, collab).
    final heightsNeedSync = _cells.any(
      (c) => c[row].attributes[TableCellBlockKeys.height] != maxHeight,
    );

    if (heightsNeedSync && !maxHeight.isNaN) {
      for (int i = 0; i < colsLen; i++) {
        final currHeight = _cells[i][row].attributes[TableCellBlockKeys.height];
        if (currHeight == maxHeight) {
          continue;
        }

        if (transaction != null) {
          transaction.updateNode(
            _cells[i][row],
            {TableCellBlockKeys.height: maxHeight},
          );
        } else {
          _cells[i][row].updateAttributes(
            {TableCellBlockKeys.height: maxHeight},
          );
        }
      }
    }

    if (node.attributes[TableBlockKeys.colsHeight] != colsHeight &&
        !colsHeight.isNaN) {
      if (transaction != null) {
        transaction.updateNode(node, {TableBlockKeys.colsHeight: colsHeight});
        if (editorState != null && editorState.editable != true) {
          node.updateAttributes({TableBlockKeys.colsHeight: colsHeight});
        }
      } else {
        node.updateAttributes({TableBlockKeys.colsHeight: colsHeight});
      }
    }
  }
}
