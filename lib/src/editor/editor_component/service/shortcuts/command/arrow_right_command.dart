import 'dart:math';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

final List<CommandShortcutEvent> arrowRightKeys = [
  moveCursorRightCommand,
  moveCursorToEndCommand,
  moveCursorToRightWordCommand,
  moveCursorRightSelectCommand,
  moveCursorEndSelectCommand,
  moveCursorRightWordSelectCommand,
];

/// Arrow right key events.
///
/// - support
///   - desktop
///   - web
///

// arrow right key
// move the cursor backward one character
final CommandShortcutEvent moveCursorRightCommand = CommandShortcutEvent(
  key: 'move the cursor forward one character',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorRight,
  command: 'arrow right',
  handler: _arrowRightCommandHandler,
);

CommandShortcutEventHandler _arrowRightCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  if (isRTL(editorState)) {
    editorState.moveCursorForward(SelectionMoveRange.character);
  } else {
    editorState.moveCursorBackward(SelectionMoveRange.character);
  }
  return KeyEventResult.handled;
};

// arrow right key + ctrl or command
// move the cursor to the end of the block
final CommandShortcutEvent moveCursorToEndCommand = CommandShortcutEvent(
  key: 'move the cursor to the end of line',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorLineEnd,
  command: 'end',
  macOSCommand: 'cmd+arrow right',
  handler: _moveCursorToEndCommandHandler,
);

CommandShortcutEventHandler _moveCursorToEndCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  if (isRTL(editorState)) {
    editorState.moveCursorForward(SelectionMoveRange.line);
  } else {
    editorState.moveCursorBackward(SelectionMoveRange.line);
  }
  return KeyEventResult.handled;
};

// arrow right key + alt
// move the cursor to the right word
final CommandShortcutEvent moveCursorToRightWordCommand = CommandShortcutEvent(
  key: 'move the cursor to the right word',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorWordRight,
  command: 'ctrl+arrow right',
  macOSCommand: 'alt+arrow right',
  handler: _moveCursorToRightWordCommandHandler,
);

CommandShortcutEventHandler _moveCursorToRightWordCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final node = editorState.getNodeAtPath(selection.end.path);
  final delta = node?.delta;

  if (node == null || delta == null) {
    return KeyEventResult.ignored;
  }

  if (isRTL(editorState)) {
    final startOfWord = selection.end.moveHorizontal(
      editorState,
      selectionRange: SelectionRange.word,
    );
    if (startOfWord == null) {
      return KeyEventResult.ignored;
    }
    // the word boundary may live in another node (e.g. when the cursor sits
    // at the edge of the line); in that case the offsets are not comparable
    // within this node's text, so skip the whitespace check.
    if (startOfWord.path.equals(selection.end.path)) {
      final selectedWord = _safeSubstring(
        delta.toPlainText(),
        startOfWord.offset,
        selection.end.offset,
      );
      // check if the selected word is whitespace
      if (selectedWord.trim().isEmpty) {
        editorState.moveCursorForward(SelectionMoveRange.word);
      }
    }
    editorState.moveCursorForward(SelectionMoveRange.word);
  } else {
    final endOfWord = selection.end.moveHorizontal(
      editorState,
      forward: false,
      selectionRange: SelectionRange.word,
    );
    if (endOfWord == null) {
      return KeyEventResult.handled;
    }
    // the word boundary may live in another node (e.g. when the cursor sits
    // at the end of the line); in that case the offsets are not comparable
    // within this node's text, so skip the whitespace check.
    if (endOfWord.path.equals(selection.end.path)) {
      final selectedWord = _safeSubstring(
        delta.toPlainText(),
        selection.end.offset,
        endOfWord.offset,
      );
      // check if the selected word is whitespace
      if (selectedWord.trim().isEmpty) {
        editorState.moveCursorBackward(SelectionMoveRange.word);
      }
    }
    editorState.moveCursorBackward(SelectionMoveRange.word);
  }
  return KeyEventResult.handled;
};

/// Returns the substring between [a] and [b] regardless of their order,
/// clamping both to the bounds of [text].
String _safeSubstring(String text, int a, int b) {
  final start = max(0, min(text.length, min(a, b)));
  final end = max(0, min(text.length, max(a, b)));
  return text.substring(start, end);
}

// arrow right key + alt + shift
final CommandShortcutEvent moveCursorRightWordSelectCommand =
    CommandShortcutEvent(
  key: 'move the cursor to select the right word',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorWordRightSelect,
  command: 'ctrl+shift+arrow right',
  macOSCommand: 'alt+shift+arrow right',
  handler: _moveCursorRightWordSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorRightWordSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  var forward = false;
  if (isRTL(editorState)) {
    forward = true;
  }
  final end = selection.end.moveHorizontal(
    editorState,
    selectionRange: SelectionRange.word,
    forward: forward,
  );
  if (end == null) {
    return KeyEventResult.ignored;
  }
  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
};

// arrow right key + shift
// selects only one character
final CommandShortcutEvent moveCursorRightSelectCommand = CommandShortcutEvent(
  key: 'move the cursor right select',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorRightSelect,
  command: 'shift+arrow right',
  handler: _moveCursorRightSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorRightSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  var forward = false;
  if (isRTL(editorState)) {
    forward = true;
  }
  final end = selection.end.moveHorizontal(editorState, forward: forward);
  if (end == null) {
    return KeyEventResult.ignored;
  }
  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
};

// arrow right key + shift + ctrl or cmd
final CommandShortcutEvent moveCursorEndSelectCommand = CommandShortcutEvent(
  key: 'move cursor to select till end of line',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorLineEndSelect,
  command: 'shift+end',
  macOSCommand: 'cmd+shift+arrow right',
  handler: _moveCursorEndSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorEndSelectCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final nodes = editorState.getNodesInSelection(selection);
  if (nodes.isEmpty) {
    return KeyEventResult.ignored;
  }
  var end = selection.end;
  final position = isRTL(editorState)
      ? nodes.last.selectable?.start()
      : nodes.last.selectable?.end();
  if (position != null) {
    end = position;
  }
  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
};
