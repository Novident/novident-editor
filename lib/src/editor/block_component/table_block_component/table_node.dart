import 'dart:math';

import 'package:collection/collection.dart';
import 'package:novident_editor/novident_editor.dart';

class TableNode {
  final Node node;
  final List<List<Node>> _cells = [];

  TableNode({
    required this.node,
    NovidentTableStyleDefinition? style,
  }) {
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

        _cells[i].add(
          newCellNode(
            node,
            cell,
            style ?? kDefaultTableStyle,
          ),
        );
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
    String? styleRef,
  }) {
    assert(cols.isNotEmpty, 'cols must not be empty');
    assert(cols[0].isNotEmpty, 'rows must not be empty');
    assert(
      cols.every((col) => col.length == cols[0].length),
      'all columns must have the same number of rows',
    );

    final node = Node(
      type: TableBlockKeys.type,
      attributes: {
        TableBlockKeys.colsLen: cols.length,
        TableBlockKeys.rowsLen: cols[0].length,
        blockComponentStyleRef: styleRef,
      },
    );

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
    String? styleRef,
  }) {
    assert(cols.isNotEmpty, 'cols must not be empty');
    assert(cols[0].isNotEmpty, 'rows must not be empty');
    assert(
      cols.every((col) => col.length == cols[0].length),
      'all columns must have the same number of rows',
    );

    final node = Node(
      type: TableBlockKeys.type,
      attributes: {
        TableBlockKeys.colsLen: cols.length,
        TableBlockKeys.rowsLen: cols[0].length,
        blockComponentStyleRef: styleRef,
      },
    );

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

  int get colsLen => _cells.length;

  int get rowsLen => _cells.isNotEmpty ? _cells[0].length : 0;

  int _heightVersion = 0;
  final List<double> _cachedRowHeights = [];
  int _cachedRowHeightsVersion = -1;
  NovidentTableStyleDefinition? _cachedRowHeightsStyle;

  double? _cachedColsHeight;
  int _cachedColsHeightVersion = -1;
  NovidentTableStyleDefinition? _cachedColsHeightStyle;

  void _invalidateHeightCache() {
    _heightVersion++;
  }

  /// Returns the height of [row].
  ///
  /// The height is read from every column of the row (the maximum wins), so
  /// a stale attribute in a single column can no longer shrink the vertical
  /// borders of the whole table. Results are cached until the next height
  /// synchronization via [updateRowHeight].
  double getRowHeight(int row, NovidentTableStyleDefinition style) {
    if (_cachedRowHeightsVersion == _heightVersion &&
        identical(_cachedRowHeightsStyle, style) &&
        row < _cachedRowHeights.length) {
      return _cachedRowHeights[row];
    }

    _cachedRowHeights.clear();
    for (var r = 0; r < rowsLen; r++) {
      double? h;
      for (final col in _cells) {
        final colHeight = double.tryParse(
          col[r].attributes[TableCellBlockKeys.height].toString(),
        );
        if (colHeight != null) {
          h = h == null ? colHeight : max(h, colHeight);
        }
      }
      _cachedRowHeights.add(h ?? style.rowDefaultHeight);
    }
    _cachedRowHeightsVersion = _heightVersion;
    _cachedRowHeightsStyle = style;
    return _cachedRowHeights[row];
  }

  double colsHeight(NovidentTableStyleDefinition style) {
    if (_cachedColsHeight != null &&
        _cachedColsHeightVersion == _heightVersion &&
        identical(_cachedColsHeightStyle, style)) {
      return _cachedColsHeight!;
    }

    double total = style.borderWidth;
    for (var r = 0; r < rowsLen; r++) {
      total += getRowHeight(r, style) + style.borderWidth;
    }
    _cachedColsHeight = total;
    _cachedColsHeightVersion = _heightVersion;
    _cachedColsHeightStyle = style;
    return total;
  }

  /// Returns the relative weight of column [col].
  ///
  /// Reads [TableCellBlockKeys.colWeight] from the first cell of the column.
  /// Falls back to [TableConfig.colDefaultWeight] (default 1.0) when the
  /// attribute is absent.
  double getColWeight(int col, NovidentTableStyleDefinition style) {
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

    return style.colDefaultWeight;
  }

  /// Returns the sum of all column weights for proportional distribution.
  double totalWeight(NovidentTableStyleDefinition style) =>
      List.generate(colsLen, (i) => i).fold<double>(
        0,
        (prev, i) =>
            prev +
            getColWeight(
              i,
              style,
            ),
      );

  /// Distributes [availableWidth] (pixels available for content) across
  /// columns according to their weights.
  ///
  /// Each column receives at least [TableConfig.colMinimumWidth] pixels.
  List<double> distributeColumnWidths(
    double availableWidth, {
    required NovidentTableStyleDefinition style,
    bool noBorder = false,
  }) {
    final totalBorders = noBorder ? 0.0 : style.borderWidth * (colsLen + 1);
    final usableWidth =
        (availableWidth - totalBorders).clamp(0, double.infinity);

    final weights = List.generate(
      colsLen,
      (col) => getColWeight(col, style),
    );
    final sumWeights = weights.fold<double>(
      0,
      (
        a,
        b,
      ) =>
          a + b,
    );

    if (sumWeights == 0) {
      return List.filled(
        colsLen,
        style.colMinimumWidth,
      );
    }

    // First pass: pure proportional — no clamping yet.
    final widths = List.generate(
      colsLen,
      (i) => weights[i] / sumWeights * usableWidth,
    );

    // Apply minimum width and iterate until the total fits.
    // When columns are clamped UP to colMinimumWidth, shrinking the
    // remaining columns may push them below minimum too — so we loop
    // until convergence (max 10 iterations to avoid infinite loops).
    for (var iter = 0; iter < 10; iter++) {
      // Clamp any column that is still below minimum.
      for (var i = 0; i < colsLen; i++) {
        if (widths[i] < style.colMinimumWidth) {
          widths[i] = style.colMinimumWidth;
        }
      }

      double totalUsed = widths.fold(
        0,
        (a, b) => a + b,
      );
      final diff = totalUsed - usableWidth;

      if (diff.abs() < 0.5) break; // converged

      if (diff > 0) {
        // Overflow — shrink columns that are above minimum.
        final shrinkable = <int>[];
        double shrinkableTotal = 0;
        for (var i = 0; i < colsLen; i++) {
          if (widths[i] > style.colMinimumWidth) {
            shrinkable.add(i);
            shrinkableTotal += widths[i];
          }
        }
        if (shrinkable.isEmpty) break; // all at min, can't shrink more
        for (final i in shrinkable) {
          widths[i] = (widths[i] - (widths[i] / shrinkableTotal) * diff)
              .clamp(style.colMinimumWidth, double.infinity);
        }
      } else {
        // Extra space — grow columns above minimum.
        final growable = <int>[];
        double growableTotal = 0;
        for (var i = 0; i < colsLen; i++) {
          if (widths[i] > style.colMinimumWidth) {
            growable.add(i);
            growableTotal += weights[i];
          }
        }
        if (growable.isEmpty) break;
        final extra = -diff; // positive
        for (final i in growable) {
          widths[i] += (weights[i] / growableTotal) * extra;
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
  double getColWidth(int col, NovidentTableStyleDefinition style) =>
      getColWeight(
        col,
        style,
      ) *
      TableDefaults.colWidth;

  /// Total intrinsic width in legacy pixel units. Prefer [totalWeight] for
  /// layout decisions.
  double tableWidth(NovidentTableStyleDefinition style) =>
      List.generate(colsLen, (idx) => idx).fold<double>(
        0,
        (prev, cur) =>
            prev +
            getColWidth(
              cur,
              style,
            ) +
            style.borderWidth,
      ) +
      style.borderWidth;

  /// Sets the weight of column [col] and updates all cells in that column.
  ///
  /// This is the replacement for the legacy [setColWidth]. When the user
  /// drags a column border, the new pixel width is converted to a weight
  /// relative to the available space.
  void setColWeight(
    int col,
    double weight, {
    NovidentTableStyleDefinition? style,
    Transaction? transaction,
    bool force = false,
  }) {
    final clamped = weight < 0.1 ? 0.1 : weight;
    if (getColWeight(col, style ?? kDefaultTableStyle) != clamped || force) {
      for (var i = 0; i < rowsLen; i++) {
        if (transaction != null) {
          transaction.updateNode(
            _cells[col][i],
            {TableCellBlockKeys.colWeight: clamped},
          );
        } else {
          _cells[col][i].updateAttributes({
            TableCellBlockKeys.colWeight: clamped,
          });
        }
        updateRowHeight(
          i,
          transaction: transaction,
          style: style,
        );
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
    NovidentTableStyleDefinition? style,
    Transaction? transaction,
    bool force = false,
  }) {
    setColWeight(
      col,
      w / (style?.colMinimumWidth ?? TableDefaults.colWidth),
      style: style,
      transaction: transaction,
      force: force,
    );
  }

  void updateRowHeight(
    int row, {
    NovidentTableStyleDefinition? style,
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
              (style?.cellVerticalPadding ?? 0),
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
      _invalidateHeightCache();
    }
  }
}

extension TableCellNavigation on TableNode {
  int get numRows {
    final lastCell = node.children.last;
    return (lastCell.attributes[TableCellBlockKeys.rowPosition] as int) + 1;
  }

  int get numCols => colsLen;

  Node? cellAt(int col, int row) {
    final r = numRows;
    final index = col * r + row;
    if (index >= 0 && index < node.children.length) {
      final cell = node.children[index];
      if (cell.attributes[TableCellBlockKeys.colPosition] == col &&
          cell.attributes[TableCellBlockKeys.rowPosition] == row) {
        return cell;
      }
    }
    return node.children.firstWhereOrNull(
      (c) =>
          c.attributes[TableCellBlockKeys.colPosition] == col &&
          c.attributes[TableCellBlockKeys.rowPosition] == row,
    );
  }

  Node? adjacentCellColumnMajor(int col, int row, bool upwards) {
    final nextRow = upwards ? row - 1 : row + 1;
    if (nextRow < 0 || nextRow >= numRows) return null;
    return cellAt(col, nextRow);
  }

  Node? adjacentCellRowMajor(int col, int row, {required bool forward}) {
    final flatIdx = row * numCols + col;
    final nextIdx = forward ? flatIdx + 1 : flatIdx - 1;
    if (nextIdx < 0 || nextIdx >= numCols * numRows) return null;
    final nextRow = nextIdx ~/ numCols;
    final nextCol = nextIdx % numCols;
    return cellAt(nextCol, nextRow);
  }
}

extension TableExitNavigation on TableNode {
  Node? nodeOutside(bool upwards) {
    if (upwards) {
      final prev = node.previous;
      if (prev == null) return null;
      var out = prev.lastChildWhere((n) => n.selectable != null);
      out ??= prev.selectable != null ? prev : null;
      return out;
    }
    final next = node.next;
    if (next == null) return null;
    return _firstMatch(next, (n) => n.selectable != null);
  }
}

Node? _firstMatch(Node node, bool Function(Node) test) {
  if (test(node)) return node;
  for (final child in node.children) {
    final found = _firstMatch(child, test);
    if (found != null) return found;
  }
  return null;
}
