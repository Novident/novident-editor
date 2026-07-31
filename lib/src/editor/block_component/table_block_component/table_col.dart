import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCol extends StatefulWidget {
  const TableCol({
    super.key,
    required this.tableNode,
    required this.editorState,
    required this.colIdx,
    required this.colWidth,
    this.tableStyleDef,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final int colIdx;
  final EditorState editorState;
  final TableNode tableNode;

  /// Pre-calculated width in pixels (from
  /// [TableNode.distributeColumnWidths]).
  final double colWidth;

  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu of the column handler.
  final List<TableActionMenuItem>? actionMenuItems;

  /// Resolved [NovidentTableStyleDefinition] for this table.
  final NovidentTableStyleDefinition? tableStyleDef;

  @override
  State<TableCol> createState() => _TableColState();
}

class _TableColState extends State<TableCol> {
  Map<String, VoidCallback> listeners = <String, VoidCallback>{};

  final Set<int> _pendingRowUpdates = {};
  bool _updateScheduled = false;

  /// Rows currently being synchronized. Acts as a re-entry guard: when
  /// [_applyRowHeightSync] triggers [editorState.apply], the resulting
  /// [notifyListeners] on cell nodes would otherwise re-fire listeners
  /// and schedule another sync for the same row — causing a sync→apply→
  /// notify→sync loop.
  final Set<int> _syncingRows = {};

  /// Tracks the row count from the previous build to detect structural
  /// changes (add/remove rows via undo, redo, or UI actions) that require
  /// a full height re-sync.
  int _lastRowsLen = -1;

  /// Ensures the initial height sync runs exactly once after the first
  /// layout pass, when paragraph rects are known.
  bool _initialSyncDone = false;

  /// Schedules a batched row-height synchronization after the current frame.
  ///
  /// Called from [build] (on initial render and structural changes) and from
  /// node listeners (when cell content changes). Multiple calls within the
  /// same frame are coalesced into a single post-frame callback.
  ///
  /// [setState] is only called when [updateRowHeight] actually modified any
  /// cell attributes — this avoids the infinite build→sync→build loop.
  void _scheduleRowUpdate(int row) {
    // Skip if this row is already being synchronized — prevents the
    // sync→apply→notifyListeners→sync feedback loop.
    if (_syncingRows.contains(row)) {
      return;
    }
    _pendingRowUpdates.add(row);
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      final rows = Set<int>.from(_pendingRowUpdates);
      _pendingRowUpdates.clear();
      var anythingChanged = false;
      for (final r in rows) {
        if (r >= widget.tableNode.rowsLen) continue;
        if (_applyRowHeightSync(r)) {
          anythingChanged = true;
        }
      }
      if (anythingChanged) {
        setState(() {});
      }
    });
  }

  /// Synchronizes the height of [row] across all columns.
  ///
  /// Returns `true` if any cell attributes were modified, `false` if heights
  /// were already consistent (no-op).
  bool _applyRowHeightSync(int row) {
    _syncingRows.add(row);
    try {
      final transaction = widget.editorState.transaction;
      widget.tableNode.updateRowHeight(
        row,
        style: widget.tableStyleDef ?? kDefaultTableStyle,
        editorState: widget.editorState,
        transaction: transaction,
      );
      if (transaction.operations.isNotEmpty) {
        transaction.afterSelection = transaction.beforeSelection;
        widget.editorState.apply(transaction);
        return true;
      }
      return false;
    } finally {
      _syncingRows.remove(row);
    }
  }

  @override
  void dispose() {
    for (final entry in listeners.entries) {
      for (var c = 0; c < widget.tableNode.colsLen; c++) {
        for (var r = 0; r < widget.tableNode.rowsLen; r++) {
          final cell = widget.tableNode.getCell(c, r);
          if (cell.id == entry.key) {
            cell.removeListener(entry.value);
          }
          if (cell.children.isNotEmpty && cell.children.first.id == entry.key) {
            cell.children.first.removeListener(entry.value);
          }
        }
      }
    }
    listeners.clear();
    super.dispose();
  }

  int get colIdx => widget.colIdx;

  @override
  Widget build(BuildContext context) {
    final style = widget.tableStyleDef ?? kDefaultTableStyle;
    final noBorder = style.noBorder;
    final effective = style.effectiveBorder;

    final borderColor = noBorder
        ? null
        : context.select((Node n) {
              final value = n.attributes[TableBlockKeys.borderColor];
              return value is String ? value.tryToColor() : null;
            }) ??
            effective.left.color;

    final double colsHeight = widget.tableNode.colsHeight(style);

    final borderWidth = noBorder
        ? 0.0
        : (widget.tableNode.node.attributes[TableBlockKeys.borderWidth]
                as double?) ??
            style.verticalBorderWidth;

    List<Widget> children = [];

    if (widget.colIdx == 0 && !noBorder && borderColor != null) {
      children.add(
        TableColBorder(
          resizable: false,
          tableNode: widget.tableNode,
          editorState: widget.editorState,
          colIdx: widget.colIdx,
          borderColor: borderColor,
          colsHeight: colsHeight,
          borderWidth: borderWidth,
          tableStyleDef: style,
          borderHoverColor:
              widget.tableStyleDef?.borderHoverColor ?? Colors.transparent,
        ),
      );
    }

    children.addAll(
      [
        SizedBox(
          width: widget.colWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildCells(context),
          ),
        ),
        if (!noBorder && borderColor != null)
          TableColBorder(
            resizable: widget.colIdx + 1 < widget.tableNode.colsLen,
            tableNode: widget.tableNode,
            editorState: widget.editorState,
            colIdx: widget.colIdx,
            currentColWidth: widget.colWidth,
            colsHeight: colsHeight,
            borderWidth: borderWidth,
            tableStyleDef: style,
            borderColor: borderColor,
            borderHoverColor: widget.tableStyleDef?.borderHoverColor,
          ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _buildCells(BuildContext context) {
    final style = widget.tableStyleDef ?? kDefaultTableStyle;
    final noBorder = style.noBorder;
    final rowsLen = widget.tableNode.rowsLen;
    final List<Widget> cells = [];

    final borderWidth = noBorder
        ? 0.0
        : (widget.tableNode.node.attributes[TableBlockKeys.borderWidth]
                as double?) ??
            style.horizontalBorderWidth;

    final cellBorder = noBorder
        ? const SizedBox.shrink()
        : Container(
            height: borderWidth,
            color: style.effectiveBorder.top.color,
          );

    // Schedule height sync from build only when:
    // 1. First render — paragraph rects are unknown until after layout.
    // 2. Structural change — rows added/removed (undo, redo, UI).
    //
    // Content changes (typing, paste) are handled by node listeners
    // registered via addListener(). Cell-level undo/redo triggers
    // notifyListeners on the paragraph node (via updateAttributes),
    // which our listeners catch.
    final rowsLenChanged = rowsLen != _lastRowsLen;
    if (!_initialSyncDone || rowsLenChanged) {
      _initialSyncDone = true;
      _lastRowsLen = rowsLen;
      for (var r = 0; r < rowsLen; r++) {
        _scheduleRowUpdate(r);
      }
    }

    for (var r = 0; r < rowsLen; r++) {
      final node = widget.tableNode.getCell(widget.colIdx, r);
      final cellColor = _cellBackgroundColor(r, style);
      addListener(node, r);
      addListener(node.children.first, r);

      cells.addAll([
        if (cellColor != null)
          ColoredBox(
            color: cellColor,
            child: widget.editorState.renderer.build(context, node),
          )
        else
          widget.editorState.renderer.build(context, node),
        cellBorder,
      ]);
    }

    final topBorder = noBorder ? const SizedBox.shrink() : cellBorder;
    return [
      topBorder,
      ...cells,
    ];
  }

  /// Returns the background color for row [r] based on the table style.
  Color? _cellBackgroundColor(int r, NovidentTableStyleDefinition? style) {
    if (style == null) return null;

    // Header rows take priority.
    if (r < style.headerRowCount) {
      return style.headerStyle?.backgroundColor;
    }
    // Footer rows.
    final footerStart = widget.tableNode.rowsLen - style.footerRowCount;
    if (r >= footerStart) {
      return style.footerStyle?.backgroundColor;
    }
    // Zebra striping.
    if (r.isEven && style.evenRowColor != null) return style.evenRowColor;
    if (r.isOdd && style.oddRowColor != null) return style.oddRowColor;

    return null;
  }

  void addListener(Node node, int row) {
    if (listeners.containsKey(node.id)) {
      return;
    }

    listeners[node.id] = () => _scheduleRowUpdate(row);
    node.addListener(listeners[node.id]!);
  }
}
