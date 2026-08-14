import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';

/// Pure mechanics of the single-node replace.
///
/// Character shortcut dispatch lives in `WysiwygStrategy.onReplace` and the
/// multi-node branch is orchestrated by the widget (deletes the selection,
/// converts to an insertion and passes it through `onInsert`).
Future<void> onReplace(
  TextEditingDeltaReplacement replacement,
  EditorState editorState,
) async {
  NovidentEditorLog.input.debug('onReplace: $replacement');

  final selection = editorState.selection;
  if (selection == null || !selection.isSingle) {
    return;
  }

  if (PlatformExtension.isIOS) {
    // remove the trailing '\n' when pressing the return key
    if (replacement.replacementText.endsWith('\n')) {
      replacement = TextEditingDeltaReplacement(
        oldText: replacement.oldText,
        replacementText: replacement.replacementText
            .substring(0, replacement.replacementText.length - 1),
        replacedRange: replacement.replacedRange,
        selection: replacement.selection,
        composing: replacement.composing,
      );
    }
  }

  final node = editorState.getNodesInSelection(selection).first;
  final transaction = editorState.transaction;
  final start = replacement.replacedRange.start;
  final length = replacement.replacedRange.end - start;
  final afterSelection = Selection(
    start: Position(
      path: node.path,
      offset: replacement.selection.baseOffset,
    ),
    end: Position(
      path: node.path,
      offset: replacement.selection.extentOffset,
    ),
  );
  transaction
    ..replaceText(node, start, length, replacement.replacementText)
    ..afterSelection = afterSelection;
  await editorState.apply(transaction);
}
