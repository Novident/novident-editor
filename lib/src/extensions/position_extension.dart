import 'dart:math' as math;

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

enum SelectionRange {
  character,
  word,
}

extension PositionExtension on Position {
  Position? moveHorizontal(
    EditorState editorState, {
    bool forward = true,
    SelectionRange selectionRange = SelectionRange.character,
  }) {
    final node = editorState.document.nodeAtPath(path);
    if (node == null) {
      return null;
    }

    if (forward && offset == 0) {
      final previousEnd = node.previous?.selectable?.end();
      if (previousEnd != null) {
        return previousEnd;
      }
      return null;
    } else if (!forward) {
      final end = node.selectable?.end();
      if (end != null && offset >= end.offset) {
        return node.next?.selectable?.start();
      }
    }

    switch (selectionRange) {
      case SelectionRange.character:
        final delta = node.delta;
        if (delta != null) {
          return Position(
            path: path,
            offset: forward
                ? delta.prevRunePosition(offset)
                : delta.nextRunePosition(offset),
          );
        }

        return Position(path: path, offset: offset);
      case SelectionRange.word:
        final delta = node.delta;
        if (delta != null) {
          final result = forward
              ? node.selectable?.getWordBoundaryInPosition(
                  Position(
                    path: path,
                    offset: delta.prevRunePosition(offset),
                  ),
                )
              : node.selectable?.getWordBoundaryInPosition(this);
          if (result != null) {
            return forward ? result.start : result.end;
          }
        }

        return Position(path: path, offset: offset);
    }
  }

  Position? moveVertical(
    EditorState editorState, {
    bool upwards = true,
  }) {
    /// Returns a text position inside [node] when [node] is a non-text
    /// block (e.g. a table). Falls back to [node]'s selectable start/end
    /// when the block has no text children.
    Position? textEntry(Node node, bool atStart) {
      if (node.type == TableBlockKeys.type && node.children.isNotEmpty) {
        final cell = atStart ? node.children.first : node.children.last;
        if (cell.children.isNotEmpty && cell.children.first.delta != null) {
          final child = cell.children.first;
          return Position(
            path: child.path,
            offset: atStart ? 0 : child.delta!.length,
          );
        }
      }
       return null;
    }



    /// Navigate to the cell at (sameCol, nextRow). Delegates to
    /// [TableCellNavigation.adjacentCellColumnMajor].
    Position? navigateToCell(Node cell, Node table, bool upwards) {
      final t = TableNode(node: table);
      final col =
          cell.attributes[TableCellBlockKeys.colPosition] as int?;
      final row =
          cell.attributes[TableCellBlockKeys.rowPosition] as int?;
      if (col == null || row == null) return null;
      final nextCell = t.adjacentCellColumnMajor(col, row, upwards);
      if (nextCell == null ||
          nextCell.children.isEmpty ||
          nextCell.children.first.delta == null) {
        return null;
      }
      final child = nextCell.children.first;
      return Position(
        path: child.path,
        offset: upwards ? child.delta!.length : 0,
      );
    }

    /// Navigate out of the table to the adjacent block. Delegates to
    /// [TableExitNavigation.nodeOutside].
    Position? navigateOutOfTable(Node table, bool upwards, bool atStart) {
      final t = TableNode(node: table);
      final outNode = t.nodeOutside(upwards);
      if (outNode == null) return null;
      final entry = textEntry(outNode, atStart);
      if (entry != null) return entry;
      final sel = outNode.selectable!;
      return Position(
        path: outNode.path,
        offset: atStart ? sel.start().offset : sel.end().offset,
      );
    }

    final node = editorState.document.nodeAtPath(path);
    final nodeRenderBox = node?.renderBox;
    final nodeSelectable = node?.selectable;
    if (node == null || nodeRenderBox == null || nodeSelectable == null) {
      return this;
    }

    final editorSelection = editorState.selection;
    final rects = editorState.selectionRects();
    if (rects.isEmpty || editorSelection == null) {
      return null;
    }

    final Rect caretRect = rects.reduce((current, next) {
      if (editorSelection.isBackward) {
        return current.bottom > next.bottom ? current : next;
      }
      return current.top <= next.top ? current : next;
    });

    // The offset of outermost part of the caret.
    // Either the top if moving upwards, or the bottom if moving downwards.
    final Offset caretOffset = editorSelection.isBackward
        ? upwards
            ? caretRect.topRight
            : caretRect.bottomRight
        : upwards
            ? caretRect.topLeft
            : caretRect.bottomLeft;

    final nodeConfig = editorState.service.rendererService
        .blockComponentBuilder(node.type)
        ?.configuration;
    if (nodeConfig == null) {
      assert(nodeConfig != null, 'Block Configuration should not be null');
      return this;
    }

    final padding = nodeConfig.padding(node);
    final nodeRect = nodeSelectable.getBlockRect();
    final nodeHeight = nodeRect.height;
    final textHeight = nodeHeight - padding.vertical;
    final caretHeight = caretRect.height;

    // Minimum (acceptable) font size
    // Consider augmenting this value to increase performance.
    const double minFontSize = 1.0;

    // If the current node is not multiline, this will be ~= 0
    // so the loop will be skipped.
    final remainingMultilineHeight = (textHeight - caretHeight);

    // Linearly search for a new position.
    // It's acceptable to use a linear search because the starting point is
    // the most outer part of the caret, so:
    // - If the current node is multine:
    //   - If the caret is NOT in the first/last line: at the first iteration
    //      the cycle a new position (of the previous/next multiline's line)
    //      will be found, practically ignoring the complexity of the cycle.
    //   - If the caret is in the first/last line: this is the worst case
    //      scenario, but only if the padding choosen by the user is very
    //      large. (padding >= (multiline's textHeight - caretHeight) / 3
    //      can start to be considered large. Note that in an average bad case
    //      scenario the position will be found in 10/12 ms instead of 1/2 ms)
    // - If the current node is not multiline: the cycle will be completely
    //   skipped because `remainingMultilineHeight` would be 0.
    Offset newOffset = caretOffset;
    Position? newPosition;
    for (double y = minFontSize;
        y < remainingMultilineHeight + minFontSize;
        y += minFontSize) {
      newOffset = caretOffset.translate(0, upwards ? -y : y);

      newPosition =
          editorState.service.selectionService.getPositionInOffset(newOffset);

      if (newPosition != null && newPosition != this) {
        final currentCell = node.parent;

        // Fast path: same cell — no tree lookup needed.
        //   For paragraphs inside a cell, newPosition.path is [tableIdx, cellIdx, 0]
        //   and node.parent.path is [tableIdx, cellIdx].
        if (currentCell != null &&
            currentCell.type == TableCellBlockKeys.type &&
            currentCell.path.equals(newPosition.path.parent)) {
          return newPosition;
        }

        // Not in a table cell — no table-specific guards needed.
        if (currentCell?.type != TableCellBlockKeys.type) {
          final hitNode =
              editorState.document.nodeAtPath(newPosition.path);
          if (hitNode != null) {
            final entry = textEntry(hitNode, !upwards);
            if (entry != null) return entry;
          }
          return newPosition;
        }

        // Inside a table cell, different cell — need full lookup.
        final hitNode =
            editorState.document.nodeAtPath(newPosition.path);

        // Route through proper vertical navigation when both nodes
        // are inside table cells — the pixel search may wrap columns.
        if (hitNode?.parent?.type == TableCellBlockKeys.type) {
          final table = currentCell!.parent;
          if (table != null) {
            final cellPos = navigateToCell(currentCell, table, upwards);
            if (cellPos != null) return cellPos;
          }
        }
        // If we're inside a table cell and the pixel search hit the table
        // itself instead of another cell, navigate within or out.
        if (hitNode?.type == TableBlockKeys.type) {
          final tableNode = currentCell!.parent!;
          // Try adjacent row first — we may just be between cells.
          final cellPos = navigateToCell(currentCell, tableNode, upwards);
          if (cellPos != null) return cellPos;
          // At the edge — navigate out.
          final outPos = navigateOutOfTable(tableNode, upwards, !upwards);
          if (outPos != null) return outPos;
        }
        // Navigate into non-text blocks (tables) instead of selecting
        // the block itself at offset 0/1 (which has no visible cursor).
        if (hitNode != null) {
          final entry = textEntry(hitNode, !upwards);
          if (entry != null) return entry;
        }
        return newPosition;
      }
    }

    // If a new position has not been found, it means that the current node
    // is not multiline (or the caret is in the last line of a multiline and
    // the bottom padding is very large).
    // In this case, we can manually skip to the previous/next node position
    // by translating the new offset by the padding slice to skip.
    // Note that the padding slice to skip can exceed the node's bounds.

    // The skip is calculated as the sum of:
    // - the top/bottom padding of the current node to skip to the edge of
    //    the node content rect
    // - the top/bottom editorStyle's padding to skip the current node's
    //    padding
    // - the bottom/top editorStyle's padding to skip the previous/next node's
    //    padding

    // Note that editorStyle's top and bottom padding does not change by the
    // node, so we can shorten the calculation by using the editorStyle's
    // vertical padding.
    final globalVerticalPadding = editorState.editorStyle.padding.vertical;

    final maxSkip = upwards
        ? padding.top + globalVerticalPadding
        : padding.bottom + globalVerticalPadding;

    // Translate the new offset by the padding slice to skip.
    newOffset = newOffset.translate(0, upwards ? -maxSkip : maxSkip);

    // Determine node's global position.
    final nodeHeightOffset = nodeRenderBox.localToGlobal(Offset(0, nodeHeight));

    // Clamp the new offset to the node's bounds.
    newOffset = Offset(
      newOffset.dx,
      math.min(newOffset.dy, nodeHeightOffset.dy),
    );

    newPosition =
        editorState.service.selectionService.getPositionInOffset(newOffset);

    if (newPosition != null && newPosition != this) {
      // The pixel-based search correctly identified the destination node,
      // but the character offset may be wrong when the source and target
      // nodes have different font sizes (e.g. heading → paragraph).
      // Use the current character offset clamped to the destination node's
      // range — same logic as the fallback_neighbour path below.
      if (!newPosition.path.equals(path)) {
        final destNode = editorState.document.nodeAtPath(newPosition.path);
        if (destNode != null) {
          // If both source and destination are inside table cells,
          // route through proper vertical navigation (same column,
          // adjacent row) instead of accepting the pixel position.
          final srcCell = node.parent;
          if (srcCell != null &&
              srcCell.type == TableCellBlockKeys.type &&
              destNode.parent?.type == TableCellBlockKeys.type &&
              !identical(srcCell, destNode.parent)) {
            final srcTable = srcCell.parent;
            if (srcTable != null) {
              final cellPos = navigateToCell(srcCell, srcTable, upwards);
              if (cellPos != null) return cellPos;
            }
          }
          // If we're inside a table cell and the skip found the table
          // itself (not another cell), navigate within or out.
          if (srcCell != null &&
              srcCell.type == TableCellBlockKeys.type &&
              destNode.type == TableBlockKeys.type) {
            final tableNode = srcCell.parent!;
            // Try adjacent row first.
            final cellPos = navigateToCell(srcCell, tableNode, upwards);
            if (cellPos != null) return cellPos;
            // At the edge — navigate out.
            final outPos = navigateOutOfTable(tableNode, upwards, !upwards);
            if (outPos != null) return outPos;
          }

          final entry = textEntry(destNode, upwards);
          if (entry != null) return entry;
        }
        final destSelectable = destNode?.selectable;
        if (destSelectable != null) {
          final clampedOffset = editorSelection.end.offset.clamp(
            destSelectable.start().offset,
            destSelectable.end().offset,
          );
          return Position(path: newPosition.path, offset: clampedOffset);
        }
      }
      return newPosition;
    }

    // If a new position has not been found, it means that the current node
    // is not visible on the screen. It seems happens only if upwards is true (?)
    // In this case, we can manually get the previous/next node position.
    int offset = editorSelection.end.offset;
    final Path nodePath = editorSelection.end.path;
    Path neighbourPath = upwards ? nodePath.previous : nodePath.next;
    if (neighbourPath.equals(nodePath)) {
      final last = neighbourPath.removeLast();
      neighbourPath = upwards ? neighbourPath : (neighbourPath..add(last + 1));
    }
    if (neighbourPath.isNotEmpty && !neighbourPath.equals(nodePath)) {
      final neighbour = editorState.document.nodeAtPath(neighbourPath);
      if (neighbour != null) {
        final entry = textEntry(neighbour, upwards);
        if (entry != null) return entry;
      }
      final selectable = neighbour?.selectable;
      if (selectable != null) {
        offset = offset.clamp(
          selectable.start().offset,
          selectable.end().offset,
        );
        return Position(path: neighbourPath, offset: offset);
      }
    }

    // Check if we're inside a table cell — navigate to adjacent cell.
    final cellParent = node.parent;
    if (cellParent != null && cellParent.type == TableCellBlockKeys.type) {
      final table = cellParent.parent;
      if (table != null && table.type == TableBlockKeys.type) {
        // Try adjacent row first.
        final cellPos = navigateToCell(cellParent, table, upwards);
        if (cellPos != null) return cellPos;
        // At the edge — navigate out.
        // downwards = true when going down (entering next block at start).
        final outPos = navigateOutOfTable(table, upwards, !upwards);
        if (outPos != null) return outPos;
      }
    }

    final delta = node.delta;
    if (delta != null) {
      if (upwards) {
        return Position(path: path, offset: 0);
      } else {
        final length = delta.length;
        // move the cursor to the end of the node
        return Position(path: path, offset: length);
      }
    }

    return this;
  }
}
