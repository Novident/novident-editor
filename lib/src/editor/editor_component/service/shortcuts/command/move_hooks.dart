import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../selection_renderer.dart';
import '../selection_contexts.dart';
import '../move_types.dart';

/// Consults [renderer.onTryMove] before applying a cursor movement.
///
/// Returns the position that should be applied, or `null` when the
/// renderer cancelled the move.
Position? tryMoveHook({
  required SelectionRenderer? renderer,
  required EditorState editorState,
  required Position fromPosition,
  required Position toPosition,
  required MoveDirection direction,
}) {
  if (renderer == null) return toPosition;

  final currentNode = editorState.getNodeAtPath(fromPosition.path);
  if (currentNode == null) return toPosition;

  final crossesBlock = !currentNode.path.equals(toPosition.path);
  final targetNode =
      crossesBlock ? editorState.getNodeAtPath(toPosition.path) : currentNode;
  if (targetNode == null) return toPosition;

  final currentSelectable = currentNode.selectable;
  final currentRect = currentSelectable?.getCursorRectInPosition(fromPosition);
  if (currentSelectable == null || currentRect == null) return toPosition;

  final targetSelectable = crossesBlock ? targetNode.selectable : currentSelectable;
  final targetRect = targetSelectable?.getCursorRectInPosition(toPosition);
  if (targetRect == null) return toPosition;

  final ctx = MoveAttemptContext(
    currentNode: currentNode,
    currentPosition: fromPosition,
    currentCursorRect: currentRect,
    textDirection: currentSelectable.textDirection(),
    currentDelegate: currentSelectable,
    targetNode: targetNode,
    targetPosition: toPosition,
    targetCursorRect: targetRect,
    targetDelegate: targetSelectable,
    direction: direction,
    crossesBlockBoundary: crossesBlock,
  );

  final intention = renderer.onTryMove(ctx);
  if (intention == null) return toPosition;

  return intention.target;
}

/// Notifies [renderer.onMoveCompleted] after a cursor movement succeeded.
void moveCompletedHook({
  required SelectionRenderer? renderer,
  required EditorState editorState,
  required Position fromPosition,
  required Position toPosition,
  required MoveDirection direction,
}) {
  if (renderer == null) return;

  final node = editorState.getNodeAtPath(toPosition.path);
  if (node != null) {
    renderer.onMoveCompleted(MoveCompletedContext(
      node: node,
      fromPosition: fromPosition,
      toPosition: toPosition,
      direction: direction,
    ));
  }
}
