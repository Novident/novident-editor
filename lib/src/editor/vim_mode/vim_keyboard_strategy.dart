import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Vim keyboard strategy.
///
/// [VimModeController] owns the state (mode, pending commands,
/// configuration); this strategy translates that state into the
/// [KeyboardStrategy] contract:
/// - **Hardware** ([onKeyEvent]): dispatches vim commands. In normal mode
///   they match (`h`, `dd`, …) and return `handled`; in insert mode they
///   return `ignored` and the event falls through to the next strategy
///   (the WYSIWYG one with the standard commands). Equivalent to the
///   previous "vim events first" pattern.
/// - **IME**: outside insert mode the deltas are blocked (`swallowed` — the
///   engine does NOT apply the delta); in insert mode they are ignored and
///   the WYSIWYG strategy handles character shortcuts.
///
/// Typical usage (see also [vimKeyboardStrategies]):
///
/// ```dart
/// final vimController = VimModeController();
/// vimController.attach(editorState); // syncs selection→mode
///
/// NovidentEditor(
///   editorState: editorState,
///   keyboardStrategies: vimKeyboardStrategies(vimController),
/// );
/// ```
class VimStrategy extends KeyboardStrategy {
  VimStrategy(this.controller);

  final VimModeController controller;

  /// Like the historical `VimModeKeyboardInterceptor`: blocked outside
  /// insert mode (or when the emulation is disabled).
  bool get _blocked =>
      controller.enabled && controller.mode != VimMode.insert;

  @override
  KeyEventResult onKeyEvent(KeyEvent event, EditorState editorState) {
    for (final shortcutEvent in controller.commandShortcutEvents) {
      if (shortcutEvent.canRespondToRawKeyEvent(event)) {
        final result = shortcutEvent.handler(editorState);
        if (result != KeyEventResult.ignored) {
          return result;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Future<ImeDeltaResult> onInsert(
    TextEditingDeltaInsertion insertion,
    EditorState editorState,
  ) async =>
      _blocked ? ImeDeltaResult.swallowed : ImeDeltaResult.ignored;

  @override
  Future<ImeDeltaResult> onDelete(
    TextEditingDeltaDeletion deletion,
    EditorState editorState,
  ) async =>
      _blocked ? ImeDeltaResult.swallowed : ImeDeltaResult.ignored;

  @override
  Future<ImeDeltaResult> onReplace(
    TextEditingDeltaReplacement replacement,
    EditorState editorState,
  ) async =>
      _blocked ? ImeDeltaResult.swallowed : ImeDeltaResult.ignored;

  @override
  Future<ImeDeltaResult> onPerformAction(
    TextInputAction action,
    EditorState editorState,
  ) async =>
      _blocked ? ImeDeltaResult.swallowed : ImeDeltaResult.ignored;
}

/// Strategies for an editor with vim: vim first (precedence) and the
/// WYSIWYG one with the standard lists as fallback.
@visibleForTesting
List<KeyboardStrategy> vimKeyboardStrategies(
  VimModeController controller, {
  List<CommandShortcutEvent>? commandShortcutEvents,
  List<CharacterShortcutEvent>? characterShortcutEvents,
}) {
  return [
    VimStrategy(controller),
    DefaultEditorStrategy(
      commandShortcutEvents:
          commandShortcutEvents ?? standardCommandShortcutEvents,
      characterShortcutEvents:
          characterShortcutEvents ?? standardCharacterShortcutEvents,
    ),
  ];
}
