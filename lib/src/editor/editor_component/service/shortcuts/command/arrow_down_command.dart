import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

import 'move_hooks.dart';

final List<CommandShortcutEvent> arrowDownKeys = [
  moveCursorDownCommand,
  moveCursorBottomSelectCommand,
  moveCursorBottomCommand,
  moveCursorDownSelectCommand,
];

/// Arrow down key events.
///
/// - support
///   - desktop
///   - web
///

// arrow down key
// move the cursor downward vertically
final CommandShortcutEvent moveCursorDownCommand = CommandShortcutEvent(
  key: 'move the cursor downward',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorDown,
  command: 'arrow down',
  handler: _moveCursorDownCommandHandler,
);

CommandShortcutEventHandler _moveCursorDownCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  Position? downPosition;
  final renderer = editorState.selectionRenderer;
  if (renderer != null) {
    final node = editorState.getNodeAtPath(selection.end.path);
    final selectable = node?.selectable;
    final rp = selectable?.getRenderParagraph();
    if (node != null && selectable != null && rp != null) {
      final ctx = CursorMoveContext(
        node: node,
        currentOffset: selection.end.offset,
        caretLocalDx: selectable.getCaretLocalDx(selection.end.offset) ?? 0,
        textDirection: selectable.textDirection(),
        delegate: selectable,
        selection: selection,
        renderParagraph: rp,
        textShift: selectable.textShift,
        delta: node.delta,
        forward: true,
      );
      downPosition = renderer.onVerticalMove(ctx);
    }
  }
  downPosition ??= selection.end.moveVertical(editorState, upwards: false);

  final from = selection.end;
  if (downPosition != null) {
    final hookResult = tryMoveHook(
      renderer: renderer,
      editorState: editorState,
      fromPosition: from,
      toPosition: downPosition,
      direction: MoveDirection.down,
    );
    if (hookResult == null) return KeyEventResult.handled;
    downPosition = hookResult;
  }

  editorState.updateSelectionWithReason(
    downPosition == null ? null : Selection.collapsed(downPosition),
    reason: SelectionUpdateReason.uiEvent,
  );

  if (downPosition != null) {
    moveCompletedHook(
      renderer: renderer,
      editorState: editorState,
      fromPosition: from,
      toPosition: downPosition,
      direction: MoveDirection.down,
    );
  }

  return KeyEventResult.handled;
};

/// arrow down + shift + ctrl or cmd
/// move the cursor to the bottommost position of the document and select everything in between
CommandShortcutEvent moveCursorBottomSelectCommand = CommandShortcutEvent(
  key: 'move cursor to end of file and select all',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorBottomSelect,
  command: 'ctrl+shift+arrow down',
  macOSCommand: 'cmd+shift+arrow down',
  handler: _moveCursorBottomSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorBottomSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final result = editorState.getLastSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.end(result.$1);
  editorState.scrollService?.jumpToBottom();
  editorState.updateSelectionWithReason(
    selection.copyWith(end: position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// arrow down + ctrl or cmd
/// move the cursor to the bottommost position of the document
CommandShortcutEvent moveCursorBottomCommand = CommandShortcutEvent(
  key: 'move cursor to end of file',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorBottom,
  command: 'ctrl+arrow down',
  macOSCommand: 'cmd+arrow down',
  handler: _moveCursorBottomCommandHandler,
);

CommandShortcutEventHandler _moveCursorBottomCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final result = editorState.getLastSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.end(result.$1);
  editorState.scrollService?.jumpToBottom();
  editorState.updateSelectionWithReason(
    Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// arrow down + shift
/// moves vertically down one line and selects everything between
CommandShortcutEvent moveCursorDownSelectCommand = CommandShortcutEvent(
  key: 'move cursor down and select one line',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorDownSelect,
  command: 'shift+arrow down',
  macOSCommand: 'shift+arrow down',
  handler: _moveCursorDownSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorDownSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  Position? end;
  final renderer = editorState.selectionRenderer;
  if (renderer != null) {
    final node = editorState.getNodeAtPath(selection.end.path);
    final selectable = node?.selectable;
    final rp = selectable?.getRenderParagraph();
    if (node != null && selectable != null && rp != null) {
      final ctx = CursorMoveContext(
        node: node,
        currentOffset: selection.end.offset,
        caretLocalDx: selectable.getCaretLocalDx(selection.end.offset) ?? 0,
        textDirection: selectable.textDirection(),
        delegate: selectable,
        renderParagraph: rp,
        textShift: selectable.textShift,
        selection: selection,
        forward: true,
        delta: node.delta,
      );
      end = renderer.onVerticalMove(ctx);
    }
  }
  end ??= selection.end.moveVertical(editorState, upwards: false);
  if (end == null) {
    return KeyEventResult.ignored;
  }

  final from = selection.end;
  final hookResult = tryMoveHook(
    renderer: renderer,
    editorState: editorState,
    fromPosition: from,
    toPosition: end,
    direction: MoveDirection.down,
  );
  if (hookResult == null) return KeyEventResult.handled;
  end = hookResult;

  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );

  moveCompletedHook(
    renderer: renderer,
    editorState: editorState,
    fromPosition: from,
    toPosition: end,
    direction: MoveDirection.down,
  );

  return KeyEventResult.handled;
};
