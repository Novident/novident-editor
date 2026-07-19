import 'dart:math';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

final List<CommandShortcutEvent> arrowLeftKeys = [
  moveCursorLeftCommand,
  moveCursorToBeginCommand,
  moveCursorToLeftWordCommand,
  moveCursorLeftSelectCommand,
  moveCursorBeginSelectCommand,
  moveCursorLeftWordSelectCommand,
];

/// Arrow left key events.
///
/// - support
///   - desktop
///   - web
///

// arrow left key
// move the cursor forward one character
final CommandShortcutEvent moveCursorLeftCommand = CommandShortcutEvent(
  key: 'move the cursor backward one character',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorLeft,
  command: 'arrow left',
  handler: _arrowLeftCommandHandler,
);

CommandShortcutEventHandler _arrowLeftCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  if (isRTL(editorState)) {
    editorState.moveCursorBackward(SelectionMoveRange.character);
  } else {
    editorState.moveCursorForward(SelectionMoveRange.character);
  }
  return KeyEventResult.handled;
};

// arrow left key + ctrl or command
// move the cursor to the beginning of the block
final CommandShortcutEvent moveCursorToBeginCommand = CommandShortcutEvent(
  key: 'move the cursor at the start of line',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorLineStart,
  command: 'home',
  macOSCommand: 'cmd+arrow left',
  handler: _moveCursorToBeginCommandHandler,
);

CommandShortcutEventHandler _moveCursorToBeginCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  if (isRTL(editorState)) {
    editorState.moveCursorBackward(SelectionMoveRange.line);
  } else {
    editorState.moveCursorForward(SelectionMoveRange.line);
  }
  return KeyEventResult.handled;
};

// arrow left key + alt
// move the cursor to the left word
final CommandShortcutEvent moveCursorToLeftWordCommand = CommandShortcutEvent(
  key: 'move the cursor to the left word',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorWordLeft,
  command: 'ctrl+arrow left',
  macOSCommand: 'alt+arrow left',
  handler: _moveCursorToLeftWordCommandHandler,
);

CommandShortcutEventHandler _moveCursorToLeftWordCommandHandler =
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
    final endOfWord = selection.end.moveHorizontal(
      editorState,
      forward: false,
      selectionRange: SelectionRange.word,
    );
    if (endOfWord == null) {
      return KeyEventResult.handled;
    }
    // the word boundary may live in another node (e.g. when the cursor sits
    // at the edge of the line); in that case the offsets are not comparable
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
  } else {
    final startOfWord = selection.end.moveHorizontal(
      editorState,
      selectionRange: SelectionRange.word,
    );
    if (startOfWord == null) {
      return KeyEventResult.handled;
    }
    // the word boundary may live in another node (e.g. when the cursor sits
    // at the beginning of the line); in that case the offsets are not
    // comparable within this node's text, so skip the whitespace check.
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

// arrow left key + alt + shift
final CommandShortcutEvent moveCursorLeftWordSelectCommand =
    CommandShortcutEvent(
  key: 'move the cursor to select the left word',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorWordLeftSelect,
  command: 'ctrl+shift+arrow left',
  macOSCommand: 'alt+shift+arrow left',
  handler: _moveCursorLeftWordSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorLeftWordSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  var forward = true;
  if (isRTL(editorState)) {
    forward = false;
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

// arrow left key + shift
// selects only one character
final CommandShortcutEvent moveCursorLeftSelectCommand = CommandShortcutEvent(
  key: 'move the cursor left select',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorLeftSelect,
  command: 'shift+arrow left',
  handler: _moveCursorLeftSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorLeftSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  var forward = true;
  if (isRTL(editorState)) {
    forward = false;
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

//
final CommandShortcutEvent moveCursorBeginSelectCommand = CommandShortcutEvent(
  key: 'move cursor to select till start of line',
  getDescription: () => NovidentEditorL10n.current.cmdMoveCursorLineStartSelect,
  command: 'shift+home',
  macOSCommand: 'cmd+shift+arrow left',
  handler: _moveCursorBeginSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorBeginSelectCommandHandler =
    (editorState) {
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
      ? nodes.last.selectable?.end()
      : nodes.last.selectable?.start();
  if (position != null) {
    end = position;
  }
  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
};

bool isRTL(EditorState editorState) {
  if (editorState.selection != null) {
    final node = editorState.getNodeAtPath(editorState.selection!.end.path);
    return node?.selectable?.textDirection() == TextDirection.rtl;
  }
  return false;
}
