import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

Position? _horizontalCellNavigate(
  EditorState editorState,
  Node cell, {
  required bool forwards,
  required bool atStart,
}) {
  final table = cell.parent;
  if (table?.type != TableBlockKeys.type) return null;
  final t = TableNode(node: table!);
  final col = cell.attributes[TableCellBlockKeys.colPosition] as int?;
  final row = cell.attributes[TableCellBlockKeys.rowPosition] as int?;
  if (col == null || row == null) return null;
  final nextCell = t.adjacentCellRowMajor(col, row, forward: forwards);
  if (nextCell != null &&
      nextCell.children.isNotEmpty &&
      nextCell.children.first.delta != null) {
    final child = nextCell.children.first;
    return Position(
      path: child.path,
      offset: atStart ? 0 : child.delta!.length,
    );
  }
  final outNode = t.nodeOutside(forwards);
  if (outNode == null) return null;
  final sel = outNode.selectable;
  if (sel == null) return null;
  return atStart ? sel.start() : sel.end();
}

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
    if (node == null) return null;

    final cellParent = node.parent;
    final insideCell =
        cellParent?.type == TableCellBlockKeys.type ? cellParent : null;

    if (forward && offset == 0) {
      if (insideCell != null) {
        return _horizontalCellNavigate(
          editorState, insideCell, forwards: false, atStart: false,
        );
      }
      final previousEnd = node.previous?.selectable?.end();
      if (previousEnd != null) return previousEnd;
      return null;
    } else if (!forward) {
      final end = node.selectable?.end();
      if (end != null && offset >= end.offset) {
        if (insideCell != null) {
          return _horizontalCellNavigate(
            editorState, insideCell, forwards: true, atStart: true,
          );
        }
        return node.next?.selectable?.start();
      }
    }

    switch (selectionRange) {
      case SelectionRange.character:
        final delta = node.delta;
        if (delta != null) {
          final newOffset =
              forward ? delta.prevRunePosition(offset) : delta.nextRunePosition(offset);
          if (newOffset == offset && insideCell != null) {
            return _horizontalCellNavigate(
              editorState, insideCell,
              forwards: forward,
              atStart: forward,
            );
          }
          return Position(path: path, offset: newOffset);
        }
        return Position(path: path, offset: offset);
      case SelectionRange.word:
        final delta = node.delta;
        if (delta != null) {
          final result = forward
              ? node.selectable?.getWordBoundaryInPosition(
                  Position(path: path, offset: delta.prevRunePosition(offset)),
                )
              : node.selectable?.getWordBoundaryInPosition(this);
          if (result != null) {
            final target = forward ? result.start : result.end;
            if (insideCell != null && target.offset == offset) {
              return _horizontalCellNavigate(
                editorState, insideCell,
                forwards: forward,
                atStart: forward,
              );
            }
            return target;
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

    // ── Fast path: intra-node using local coords (scroll-independent) ──
    final withinNode =
        nodeSelectable.moveVerticallyInText(this.offset, upwards);
    if (withinNode != null) return withinNode;

    // ── Fallback: pixel-based scan (tables, images, dividers, and nodes
    //    whose RenderParagraph is unavailable) ──
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

    // ── Pixel scan exhausted (or skipped) — use document tree ──
    // When the pixel scan found nothing, or when moveVerticallyInText
    // returned null (visual boundary), navigate to the adjacent node
    // via the document tree instead of guessing with padding math.

    final adjacent = upwards ? node.previous : node.next;
    if (adjacent != null) {
      final adjSelectable = adjacent.selectable;
      if (adjSelectable != null) {
        // Try to preserve the caret's visual column (dx) across nodes
        // using local→global→local coordinate transforms.
        final caretLocalDx = nodeSelectable.getCaretLocalDx(this.offset);
        if (caretLocalDx != null) {
          final dstRenderBox = adjacent.renderBox;
          if (dstRenderBox != null && dstRenderBox.hasSize) {
            final srcGlobal =
                nodeRenderBox.localToGlobal(Offset(caretLocalDx, 0));
            final dstLocal = dstRenderBox.globalToLocal(srcGlobal);
            final targetLocalY =
                upwards ? dstRenderBox.size.height : 0.0;
            final targetGlobal = dstRenderBox.localToGlobal(
              Offset(dstLocal.dx, targetLocalY),
            );
            final entry = textEntry(adjacent, !upwards);
            if (entry != null) return entry;
            final adjPos = adjSelectable.getPositionInOffset(targetGlobal);
            return adjPos;
          }
        }
        // Check non-text blocks (tables).
        final entry = textEntry(adjacent, !upwards);
        if (entry != null) return entry;
        // Fallback: clamp to destination node's valid range.
        final adjStart = adjSelectable.start();
        final adjEnd = adjSelectable.end();
        if (adjStart.path.equals(adjacent.path) &&
            adjEnd.path.equals(adjacent.path)) {
          final clampedOffset =
              this.offset.clamp(adjStart.offset, adjEnd.offset);
          return Position(path: adjacent.path, offset: clampedOffset);
        }
      }
    }

    // Check if we're inside a table cell — navigate to adjacent cell.
    final cellParent = node.parent;
    if (cellParent != null && cellParent.type == TableCellBlockKeys.type) {
      final table = cellParent.parent;
      if (table != null && table.type == TableBlockKeys.type) {
        final cellPos = navigateToCell(cellParent, table, upwards);
        if (cellPos != null) return cellPos;
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
        return Position(path: path, offset: length);
      }
    }

    return this;
  }
}
