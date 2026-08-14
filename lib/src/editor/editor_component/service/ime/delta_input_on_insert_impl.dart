import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> onInsert(
  TextEditingDeltaInsertion insertion,
  EditorState editorState,
) async {
  NovidentEditorLog.input.debug('onInsert: $insertion');

  var selection = editorState.selection;
  if (selection == null) {
    return;
  }

  if (!selection.isCollapsed) {
    await editorState.deleteSelection(selection);
  }

  selection = editorState.selection?.normalized;
  if (selection == null || !selection.isCollapsed) {
    return;
  }

  // IME
  // single line
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null) {
    return;
  }
  assert(node.delta != null);

  if (kDebugMode) {
    // verify the toggled keys are supported.
    assert(
      editorState.toggledStyle.keys.every(
        (element) => RichTextKeys.supportToggled.contains(element),
      ),
    );
  }

  final afterSelection = Selection(
    start: Position(
      path: node.path,
      offset: insertion.selection.baseOffset,
    ),
    end: Position(
      path: node.path,
      offset: insertion.selection.extentOffset,
    ),
  );

  final transaction = editorState.transaction
    ..insertText(
      node,
      selection.startIndex,
      insertion.textInserted,
      toggledAttributes: editorState.toggledStyle,
      sliceAttributes: editorState.sliceUpcomingAttributes,
    )
    ..afterSelection = afterSelection;
  await editorState.apply(transaction);
}
