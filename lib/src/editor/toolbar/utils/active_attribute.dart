import 'dart:math';

import 'package:novident_editor/novident_editor.dart';

/// Resolves the value of the rich-text attribute [key] that is effective for
/// [selection], or `null` when the attribute is not applied.
///
/// Collapsed-aware — mirrors how `fontSize`/`fontFamily` behave:
///  1. A pending toggle (`editorState.toggledStyle`) wins when present, so the
///     toolbar reflects the "about to type" state immediately.
///  2. Otherwise the previous character's attributes are inspected (offset - 1),
///     so placing the cursor inside already-formatted text highlights the
///     corresponding button.
///
/// For expanded selections it returns the value only when every covered
/// character carries the attribute (same `allSatisfyInSelection` semantics the
/// legacy toolbar items used).
///
/// Callers interpret the result: format toggles compare against `true`, color
/// items treat a non-null value as "active".
Object? activeAttributeValue(
  EditorState editorState,
  Selection selection,
  String key,
) {
  if (!selection.isCollapsed) {
    final nodes = editorState.getNodesInSelection(selection);
    Object? value;
    final applied = nodes.allSatisfyInSelection(selection, (delta) {
      if (delta.isEmpty) return false;
      return delta.everyAttributes((attributes) {
        if (attributes.containsKey(key)) {
          value = attributes[key];
          return true;
        }
        return false;
      });
    });
    return applied ? value : null;
  }

  // Collapsed: a pending toggle is the source of truth for the next typed char.
  if (editorState.toggledStyle.containsKey(key)) {
    return editorState.toggledStyle[key];
  }

  // Collapsed: inspect the previous character.
  final previous = selection.copyWith(
    start: selection.start.copyWith(
      offset: max(selection.startIndex - 1, 0),
    ),
  );
  if (previous.isCollapsed) return null; // offset 0: no previous character.

  final nodes = editorState.getNodesInSelection(previous);
  Object? value;
  final applied = nodes.allSatisfyInSelection(previous, (delta) {
    if (delta.isEmpty) return false;
    return delta.everyAttributes((attributes) {
      if (attributes.containsKey(key)) {
        value = attributes[key];
        return true;
      }
      return false;
    });
  });
  return applied ? value : null;
}
