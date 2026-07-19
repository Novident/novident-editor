import 'package:novident_editor/src/editor_state.dart';
import 'package:flutter/material.dart';

typedef ShortcutEventHandler = KeyEventResult Function(
  EditorState editorState,
  KeyEvent? event,
);
