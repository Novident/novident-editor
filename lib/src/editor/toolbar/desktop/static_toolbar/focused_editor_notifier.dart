import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Tracks the [EditorState] of the currently focused editor.
///
/// Editors register their [EditorState] when they gain focus and clear it
/// when they lose focus. A static toolbar listens to this notifier to show
/// formatting options for the active editor.
class FocusedEditorNotifier extends ValueNotifier<EditorState?> {
  FocusedEditorNotifier() : super(null);
}
