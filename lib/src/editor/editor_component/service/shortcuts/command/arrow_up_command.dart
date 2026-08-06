import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

import 'move_hooks.dart';

final List<CommandShortcutEvent> arrowUpKeys = [
  moveCursorUpCommand,
  moveCursorTopSelectCommand,
  moveCursorTopCommand,
  moveCursorUpSelectCommand,
];

/// Arrow up key events.
///
/// - support
///   - desktop
///   - web
///

// arrow up key
// move the cursor upward vertically
final CommandShortcutEvent moveCursorUpCommand = CommandShortcutEvent(
  key: 'move the cursor upward',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorUp,
  command: 'arrow up',
  handler: _moveCursorUpCommandHandler,
);

CommandShortcutEventHandler _moveCursorUpCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  Position? upPosition;
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
        delta: node.delta,
      );
      upPosition = renderer.onVerticalMove(ctx);
    }
  }
  upPosition ??= selection.end.moveVertical(editorState);

  final from = selection.end;
  if (upPosition != null) {
    final hookResult = tryMoveHook(
      renderer: renderer,
      editorState: editorState,
      fromPosition: from,
      toPosition: upPosition!,
      direction: MoveDirection.up,
    );
    if (hookResult == null) return KeyEventResult.handled;
    upPosition = hookResult;
  }

  editorState.updateSelectionWithReason(
    upPosition == null ? null : Selection.collapsed(upPosition),
    reason: SelectionUpdateReason.uiEvent,
  );

  if (upPosition != null) {
    moveCompletedHook(
      renderer: renderer,
      editorState: editorState,
      fromPosition: from,
      toPosition: upPosition!,
      direction: MoveDirection.up,
    );
  }

  return KeyEventResult.handled;
};

/// arrow up + shift + ctrl or cmd
/// move the cursor to the topmost position of the document and select everything in between
final CommandShortcutEvent moveCursorTopSelectCommand = CommandShortcutEvent(
  key: 'move cursor to start of file and select all',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorTopSelect,
  command: 'ctrl+shift+arrow up',
  macOSCommand: 'cmd+shift+arrow up',
  handler: _moveCursorTopSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorTopSelectCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final result = editorState.getFirstSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.start(result.$1);
  editorState.scrollService?.jumpToTop();
  editorState.updateSelectionWithReason(
    selection.copyWith(end: position),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
};

/// arrow up + ctrl or cmd
/// move the cursor to the topmost position of the document
final CommandShortcutEvent moveCursorTopCommand = CommandShortcutEvent(
  key: 'move cursor to start of file',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorTop,
  command: 'ctrl+arrow up',
  macOSCommand: 'cmd+arrow up',
  handler: _moveCursorTopCommandHandler,
);

CommandShortcutEventHandler _moveCursorTopCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final result = editorState.getFirstSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.start(result.$1);
  editorState.scrollService?.jumpToTop();
  editorState.updateSelectionWithReason(
    Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// arrow up + ctrl or cmd
/// moves vertically down one line and selects everything between
final CommandShortcutEvent moveCursorUpSelectCommand = CommandShortcutEvent(
  key: 'move cursor up and select one line',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorUpSelect,
  command: 'shift+arrow up',
  macOSCommand: 'shift+arrow up',
  handler: _moveCursorUpSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorUpSelectCommandHandler = (editorState) {
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
        delta: node.delta,
      );
      end = renderer.onVerticalMove(ctx);
    }
  }
  end ??= selection.end.moveVertical(editorState);
  if (end == null) {
    return KeyEventResult.ignored;
  }

  final from = selection.end;
  final hookResult = tryMoveHook(
    renderer: renderer,
    editorState: editorState,
    fromPosition: from,
    toPosition: end!,
    direction: MoveDirection.up,
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
    toPosition: end!,
    direction: MoveDirection.up,
  );

  return KeyEventResult.handled;
};
