import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

typedef VimHandler = KeyEventResult Function(
  EditorState editorState,
  VimModeController controller,
);

CommandShortcutEvent event(
  VimCommand command, {
  required VimHandler onNormal,
  required VimModeController controller,
  VimHandler? onVisual,
  VimHandler? onInsert,
}) {
  final String? name = controller.configuration.commandOf(command);
  final String rawBinding = controller.configuration.keybindings[command] ?? '';
  return CommandShortcutEvent(
    key: 'vim mode: ${name ?? 'command code ${command.code}'}',
    getDescription: () => 'Vim mode: $name',
    command: rawBinding,
    handler: (editorState) {
      if (!controller.enabled) {
        return KeyEventResult.ignored;
      }
      if (command.mode != null &&
          command.mode != controller.mode &&
          command.restrictToDefinedMode) {
        return KeyEventResult.ignored;
      }
      if (command.rawCommand != null && command.rawCommand!.length > 1) {
        controller.setPendingCommand(rawBinding, command.rawCommand);
        if (controller.mode == command.mode &&
            command.rawCommand != null &&
            controller.needsRepeatKeyAgain(
              command,
              rawBinding,
              command.rawCommand!,
            )) {
          return KeyEventResult.handled;
        }
        controller.setPendingCommand(null, null);
      }
      switch (controller.mode) {
        case VimMode.insert:
          return onInsert?.call(editorState, controller) ??
              KeyEventResult.ignored;
        case VimMode.normal:
          return onNormal(editorState, controller);
        case VimMode.visual:
          return (onVisual ?? onNormal)(editorState, controller);
      }
    },
  );
}

// delegates to an existing command shortcut handler.
VimHandler delegate(CommandShortcutEvent target) => (
      EditorState editorState,
      VimModeController _,
    ) =>
        target.handler(
          editorState,
        );
