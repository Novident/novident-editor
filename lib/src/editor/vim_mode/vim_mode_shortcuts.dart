import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

/// Builds one [CommandShortcutEvent] per [VimCommand], bound to the
/// keybindings of the controller's configuration.
///
/// Prepend the returned events to the standard list so they take precedence:
///
/// ```dart
/// NovidentEditor(
///   commandShortcutEvents: [
///     ...vimController.commandShortcutEvents,
///     ...standardCommandShortcutEvents,
///   ],
/// );
/// ```
///
/// Every handler is a no-op (returns `KeyEventResult.ignored`) while the
/// vim emulation is disabled or the editor is in [VimMode.insert], so the
/// standard shortcuts and typing keep working.
Map<VimCommand, CommandShortcutEvent> buildVimModeCommandShortcutEvents(
  VimModeController controller,
) {
  return <VimCommand, CommandShortcutEvent>{
    VimCommand.enterNormalMode: event(
      VimCommand.enterNormalMode,
      controller: controller,
      // in normal mode `escape` is a handled no-op, so the built-in
      // exitEditing command doesn't clear the selection.
      onNormal: (editorState, controller) {
        controller.enterNormalMode(editorState: editorState);
        return KeyEventResult.handled;
      },
      onInsert: (editorState, controller) {
        controller.enterNormalMode(editorState: editorState);
        return KeyEventResult.handled;
      },
    ),
    VimCommand.enterInsertMode: event(
      VimCommand.enterInsertMode,
      controller: controller,
      onNormal: (editorState, controller) {
        controller.enterInsertMode();
        return KeyEventResult.handled;
      },
      onVisual: (editorState, controller) {
        _collapseSelection(editorState, atStart: true);
        controller.enterInsertMode();
        return KeyEventResult.handled;
      },
    ),
    VimCommand.enterInsertModeAfter: event(
      VimCommand.enterInsertModeAfter,
      controller: controller,
      onNormal: (editorState, controller) {
        moveCursorRightCommand.handler(editorState);
        controller.enterInsertMode();
        return KeyEventResult.handled;
      },
    ),
    VimCommand.enterInsertModeLineStart: event(
      VimCommand.enterInsertModeLineStart,
      controller: controller,
      onNormal: (editorState, controller) {
        moveCursorToBeginCommand.handler(editorState);
        controller.enterInsertMode();
        return KeyEventResult.handled;
      },
    ),
    VimCommand.enterInsertModeLineEnd: event(
      VimCommand.enterInsertModeLineEnd,
      controller: controller,
      onNormal: (editorState, controller) {
        moveCursorToEndCommand.handler(editorState);
        controller.enterInsertMode();
        return KeyEventResult.handled;
      },
    ),
    VimCommand.openLineBelow: event(
      VimCommand.openLineBelow,
      controller: controller,
      onNormal: (editorState, controller) =>
          _openLine(editorState, controller, below: true),
    ),
    VimCommand.openLineAbove: event(
      VimCommand.openLineAbove,
      controller: controller,
      onNormal: (editorState, controller) =>
          _openLine(editorState, controller, below: false),
    ),
    VimCommand.enterVisualMode: event(
      VimCommand.enterVisualMode,
      controller: controller,
      onNormal: (editorState, controller) {
        controller.enterVisualMode(editorState: editorState);
        return KeyEventResult.handled;
      },
      onVisual: (editorState, controller) {
        controller.enterNormalMode(editorState: editorState);
        return KeyEventResult.handled;
      },
    ),
    VimCommand.enterVisualLineMode: event(
      VimCommand.enterVisualLineMode,
      controller: controller,
      // vim's `V`: select the whole current node; from charwise visual it
      // widens the selection to full-node boundaries.
      onNormal: (editorState, controller) {
        controller.enterVisualLineMode(editorState: editorState);
        return KeyEventResult.handled;
      },
      onVisual: (editorState, controller) {
        controller.enterVisualLineMode(editorState: editorState);
        return KeyEventResult.handled;
      },
    ),
    VimCommand.moveLeft: event(
      VimCommand.moveLeft,
      controller: controller,
      onNormal: delegate(moveCursorLeftCommand),
      onVisual: delegate(moveCursorLeftSelectCommand),
    ),
    VimCommand.moveDown: event(
      VimCommand.moveDown,
      controller: controller,
      onNormal: delegate(moveCursorDownCommand),
      onVisual: delegate(moveCursorDownSelectCommand),
    ),
    VimCommand.moveUp: event(
      VimCommand.moveUp,
      controller: controller,
      onNormal: delegate(moveCursorUpCommand),
      onVisual: delegate(moveCursorUpSelectCommand),
    ),
    VimCommand.moveRight: event(
      VimCommand.moveRight,
      controller: controller,
      onNormal: delegate(moveCursorRightCommand),
      onVisual: delegate(moveCursorRightSelectCommand),
    ),
    VimCommand.moveWordForward: event(
      VimCommand.moveWordForward,
      controller: controller,
      onNormal: delegate(moveCursorToRightWordCommand),
      onVisual: delegate(moveCursorRightWordSelectCommand),
    ),
    VimCommand.moveWordBackward: event(
      VimCommand.moveWordBackward,
      controller: controller,
      onNormal: delegate(moveCursorToLeftWordCommand),
      onVisual: delegate(moveCursorLeftWordSelectCommand),
    ),
    VimCommand.moveLineStart: event(
      VimCommand.moveLineStart,
      controller: controller,
      onNormal: delegate(moveCursorToBeginCommand),
      onVisual: delegate(moveCursorBeginSelectCommand),
    ),
    VimCommand.moveLineEnd: event(
      VimCommand.moveLineEnd,
      controller: controller,
      onNormal: delegate(moveCursorToEndCommand),
      onVisual: delegate(moveCursorEndSelectCommand),
    ),
    VimCommand.moveDocumentStart: event(
      VimCommand.moveDocumentStart,
      controller: controller,
      onNormal: delegate(moveCursorTopCommand),
      onVisual: delegate(moveCursorTopSelectCommand),
    ),
    VimCommand.moveDocumentEnd: event(
      VimCommand.moveDocumentEnd,
      controller: controller,
      onNormal: delegate(moveCursorBottomCommand),
      onVisual: delegate(moveCursorBottomSelectCommand),
    ),
    VimCommand.moveBlockPrevious: event(
      VimCommand.moveBlockPrevious,
      controller: controller,
      onNormal: (editorState, controller) =>
          _moveBlock(editorState, forward: false, extendSelection: false),
      onVisual: (editorState, controller) =>
          _moveBlock(editorState, forward: false, extendSelection: true),
    ),
    VimCommand.moveBlockNext: event(
      VimCommand.moveBlockNext,
      controller: controller,
      onNormal: (editorState, controller) =>
          _moveBlock(editorState, forward: true, extendSelection: false),
      onVisual: (editorState, controller) =>
          _moveBlock(editorState, forward: true, extendSelection: true),
    ),
    VimCommand.pageUp: event(
      VimCommand.pageUp,
      controller: controller,
      onNormal: delegate(pageUpCommand),
    ),
    VimCommand.pageDown: event(
      VimCommand.pageDown,
      controller: controller,
      onNormal: delegate(pageDownCommand),
    ),
    VimCommand.deleteUnderCursor: event(
      VimCommand.deleteUnderCursor,
      controller: controller,
      onNormal: delegate(deleteCommand),
      onVisual: _cutSelectionAndExitVisual,
    ),
    VimCommand.deleteLine: event(
      VimCommand.deleteLine,
      controller: controller,
      // vim's `d` operator: the first press arms it, the second (`dd`)
      // cuts the current line.
      onNormal: (editorState, controller) {
        if (controller.pendingCommand == 'd') {
          controller.setPendingCommand(null);
          return _cutLine(editorState, controller);
        }
        controller.setPendingCommand('d');
        return KeyEventResult.handled;
      },
      onVisual: _cutSelectionAndExitVisual,
    ),
    VimCommand.yank: event(
      VimCommand.yank,
      controller: controller,
      // v1: yank is only effective in visual mode.
      onNormal: (_, __) => KeyEventResult.ignored,
      onVisual: (editorState, controller) {
        final result = copyCommand.handler(editorState);
        controller.enterNormalMode(editorState: editorState);
        return result == KeyEventResult.ignored
            ? KeyEventResult.handled
            : result;
      },
    ),
    VimCommand.paste: event(
      VimCommand.paste,
      controller: controller,
      onNormal: delegate(pasteCommand),
      onVisual: (editorState, controller) {
        final result = pasteCommand.handler(editorState);
        // the paste reads the selection asynchronously (after the clipboard
        // is fetched) and replaces it — don't collapse it here, the paste
        // transaction sets the final caret position itself.
        controller.enterNormalMode(collapseSelection: false);
        return result;
      },
    ),
    VimCommand.undo: event(
      VimCommand.undo,
      controller: controller,
      onNormal: delegate(undoCommand),
    ),
    VimCommand.redo: event(
      VimCommand.redo,
      controller: controller,
      onNormal: delegate(redoCommand),
    ),
  };
}

void _collapseSelection(EditorState editorState, {bool atStart = false}) {
  final selection = editorState.selection;
  if (selection == null || selection.isCollapsed) {
    return;
  }
  editorState.updateSelectionWithReason(
    selection.normalized.collapse(atStart: atStart),
    reason: SelectionUpdateReason.uiEvent,
  );
}

KeyEventResult _openLine(
  EditorState editorState,
  VimModeController controller, {
  required bool below,
}) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final path = below ? selection.end.path.next : selection.end.path;
  final transaction = editorState.transaction
    ..insertNode(path, paragraphNode())
    ..afterSelection = Selection.collapsed(Position(path: path));
  editorState.apply(transaction);
  controller.enterInsertMode();
  return KeyEventResult.handled;
}

KeyEventResult _cutLine(
  EditorState editorState,
  VimModeController controller,
) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final node = editorState.getNodeAtPath(selection.end.path);
  if (node == null || node.parent == null) {
    return KeyEventResult.ignored;
  }

  // vim's `dd` yanks the line before removing it. With a collapsed
  // selection, the built-in copy handler copies the whole node.
  handleCopy(editorState);

  final transaction = editorState.transaction..deleteNode(node);

  // keep a valid cursor position after the deletion.
  if (node.next != null) {
    transaction.afterSelection = Selection.collapsed(
      Position(path: node.path),
    );
  } else if (node.previous != null) {
    transaction.afterSelection = Selection.collapsed(
      Position(
        path: node.path.previous,
        offset: node.previous?.delta?.length ?? 0,
      ),
    );
  } else {
    // last node of its parent: keep the document editable with an empty
    // paragraph in place.
    transaction.insertNode(node.path, paragraphNode());
    transaction.afterSelection = Selection.collapsed(
      Position(path: node.path),
    );
  }

  editorState.apply(transaction);
  return KeyEventResult.handled;
}

KeyEventResult _cutSelectionAndExitVisual(
  EditorState editorState,
  VimModeController controller,
) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  if (!selection.isCollapsed) {
    // copies the selection to the clipboard and deletes it.
    handleCut(editorState);
  }
  controller.enterNormalMode();
  return KeyEventResult.handled;
}

KeyEventResult _moveBlock(
  EditorState editorState, {
  required bool forward,
  required bool extendSelection,
}) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final root = editorState.document.root;
  if (root.children.isEmpty) {
    return KeyEventResult.ignored;
  }

  final currentIndex =
      selection.end.path.isEmpty ? 0 : selection.end.path.first;
  final lastIndex = root.children.length - 1;

  // scan in the requested direction for the first block that contains text.
  Node? target;
  var index = (currentIndex + (forward ? 1 : -1)).clamp(0, lastIndex);
  while (index >= 0 && index <= lastIndex) {
    final candidate = _firstTextNode(root.children.elementAt(index));
    if (candidate != null) {
      target = candidate;
      break;
    }
    index += forward ? 1 : -1;
  }
  if (target == null) {
    return KeyEventResult.handled;
  }

  final position = Position(path: target.path);
  editorState.updateSelectionWithReason(
    extendSelection
        ? selection.copyWith(end: position)
        : Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
}

Node? _firstTextNode(Node node) {
  if (node.delta != null) {
    return node;
  }
  for (final child in node.children) {
    final result = _firstTextNode(child);
    if (result != null) {
      return result;
    }
  }
  return null;
}
