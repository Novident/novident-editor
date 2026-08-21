import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

Future<void> onPerformAction(
  TextInputAction action,
  EditorState editorState,
) async {
  print('onPerformAction: $action');
  assert(() {
    NovidentEditorLog.input.debug('onPerformAction: $action');
    return true;
  }());
}
