import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// A misspelled word found under a pointer position.
typedef MisspelledWord = ({
  Node node,
  String word,
  int start,
  int end,
});

/// Resolves the word under the current collapsed selection and returns it
/// when it is marked as misspelled (`proofState` in the node's delta).
///
/// The desktop selection service leaves the selection collapsed at the
/// exact click point before showing the context menu, so the selection is
/// the reliable source of the click position (the position passed to the
/// menu builder is offset on purpose for comfortable menu placement).
///
/// Returns null when the selection is not collapsed (a real selection is
/// active — the standard menu applies), the node has no text, or the word
/// under the caret is not marked.
MisspelledWord? findMisspelledWord({
  required EditorState editorState,
}) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    return null;
  }
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null) {
    return null;
  }
  final selectable = node.selectable;
  if (selectable == null) {
    return null;
  }
  final boundary = selectable.getWordBoundaryInPosition(selection.start);
  if (boundary == null) {
    return null;
  }
  final start = boundary.start.offset;
  final end = boundary.end.offset;
  if (start >= end) {
    return null;
  }
  final delta = node.delta;
  if (delta == null) {
    return null;
  }
  final slice = delta.slice(start, end);
  final marked = slice
      .whereType<TextInsert>()
      .any((insert) =>
          insert.attributes?[RichTextKeys.proofState] == proofStateError);
  if (!marked) {
    return null;
  }
  return (node: node, word: slice.toPlainText(), start: start, end: end);
}

/// Builds the context menu for a secondary click.
///
/// When the click lands exactly on a misspelled word it shows the checker's
/// suggestions, an "Add to dictionary" entry, and then [extraItems]
/// (standard cut/copy/paste by default). Otherwise it falls back to
/// [extraItems] alone.
Widget buildSpellCheckContextMenu({
  required BuildContext context,
  required Offset position,
  required EditorState editorState,
  required VoidCallback onPressed,
  required NovidentSpellChecker checker,
  List<ContextMenuItem> extraItems = const [],
}) {
  final standardItems = extraItems.isEmpty
      ? standardContextMenuItems.first
      : extraItems;

  final misspelled = findMisspelledWord(
    editorState: editorState,
  );
  if (misspelled == null) {
    return ContextMenu(
      position: position,
      editorState: editorState,
      items: [standardItems],
      onPressed: onPressed,
    );
  }

  final suggestions = checker.suggest(misspelled.word);
  final items = <List<ContextMenuItem>>[
    [
      for (final suggestion in suggestions)
        ContextMenuItem(
          getName: () => suggestion,
          onPressed: (editorState) {
            editorState.apply(
              editorState.transaction
                ..replaceText(
                  misspelled.node,
                  misspelled.start,
                  misspelled.end - misspelled.start,
                  suggestion,
                ),
            );
          },
        ),
      if (suggestions.isEmpty)
        ContextMenuItem(
          getName: () => 'No suggestions',
          onPressed: (_) {},
        ),
      ContextMenuItem(
        getName: () => 'Add to dictionary',
        onPressed: (editorState) {
          checker.addWord(misspelled.word);
          // The word is now valid: re-analyze the node to clear its mark.
          editorState.spellCheckService?.requestAnalysis(misspelled.node);
        },
      ),
    ],
    if (standardItems.isNotEmpty) standardItems,
  ];

  return ContextMenu(
    position: position,
    editorState: editorState,
    items: items,
    onPressed: onPressed,
  );
}
