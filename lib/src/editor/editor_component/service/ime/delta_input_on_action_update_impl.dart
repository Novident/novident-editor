import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

Future<void> onPerformAction(
  TextInputAction action,
  EditorState editorState,
) async {
  NovidentEditorLog.input.debug('onPerformAction: $action');
}
