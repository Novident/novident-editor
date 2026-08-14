import 'package:novident_editor/novident_editor.dart';

Future<bool> executeCharacterShortcutEvent(
  EditorState editorState,
  String? character,
  List<CharacterShortcutEvent> characterShortcutEvents,
) async {
  // if the character is a space + enter, we should execute the enter event
  if (character == ' \n') {
    character = '\n';
  }

  if (character == null || character.length != 1) {
    return false;
  }

  for (final shortcutEvent in characterShortcutEvents) {
    final regExp = shortcutEvent.regExp;
    if (regExp != null && regExp.hasMatch(character)) {
      // RegExp match: `handlerWithCharacter` takes priority; when missing,
      // `handler` is used. It is never re-evaluated by the `==` branch (the
      // previous path could run the handler twice when `handlerWithCharacter`
      // returned `false`).
      final handled = shortcutEvent.handlerWithCharacter != null
          ? await shortcutEvent.executeWithCharacter(editorState, character)
          : await shortcutEvent.handler(editorState);
      if (handled) {
        NovidentEditorLog.input.debug(
          'keyboard service - handled by character shortcut event: $shortcutEvent',
        );
        return true;
      }
      continue;
    }
    if (shortcutEvent.character == character &&
        await shortcutEvent.handler(editorState)) {
      NovidentEditorLog.input.debug(
        'keyboard service - handled by character shortcut event: $shortcutEvent',
      );
      return true;
    }
  }

  return false;
}
