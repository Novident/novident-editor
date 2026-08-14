import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/ime/character_shortcut_event_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Result of a strategy for an IME channel delta.
///
/// Three possible outcomes:
/// - [ignored]: not mine → the widget runs the fallback mechanics.
/// - [handled]: I handled it (e.g. a character shortcut executed) → the
///   widget skips the fallback and the delta IS applied to the engine.
/// - [swallowed]: I blocked it (e.g. vim normal mode) → the widget skips
///   the fallback and the delta is NOT applied to the engine.
enum ImeDeltaResult {
  ignored,
  handled,
  swallowed,
}

/// Keyboard interpretation policy.
///
/// The editor DELEGATES dispatch; it does not decide policy. Strategies are
/// consulted in order and the first one that does not return
/// `ignored`/`false` wins ("first to handle wins" semantics, like
/// CodeMirror's `keymap` facet).
///
/// There are two channels:
/// - **Hardware** ([onKeyEvent]): only `KeyDownEvent`/`KeyRepeatEvent`; the
///   owning widget filters the rest and the IME composition state.
/// - **IME** (the remaining methods): text input deltas, resolved through
///   [ImeDeltaResult].
abstract class KeyboardStrategy {
  /// Decides what to do with a physical keyboard [KeyEvent].
  ///
  /// Returns [KeyEventResult.ignored] to yield the event to the next
  /// strategy (or to the editor's normal flow).
  KeyEventResult onKeyEvent(KeyEvent event, EditorState editorState);

  /// IME channel — see [ImeDeltaResult].
  Future<ImeDeltaResult> onInsert(
    TextEditingDeltaInsertion insertion,
    EditorState editorState,
  ) async =>
      ImeDeltaResult.ignored;

  /// IME channel — see [ImeDeltaResult].
  Future<ImeDeltaResult> onReplace(
    TextEditingDeltaReplacement replacement,
    EditorState editorState,
  ) async =>
      ImeDeltaResult.ignored;

  /// IME channel — see [ImeDeltaResult].
  Future<ImeDeltaResult> onNonTextUpdate(
    TextEditingDeltaNonTextUpdate nonTextUpdate,
    EditorState editorState,
  ) async =>
      ImeDeltaResult.ignored;

  /// IME channel — see [ImeDeltaResult].
  Future<ImeDeltaResult> onDelete(
    TextEditingDeltaDeletion deletion,
    EditorState editorState,
  ) async =>
      ImeDeltaResult.ignored;

  /// IME channel — see [ImeDeltaResult].
  Future<ImeDeltaResult> onPerformAction(
    TextInputAction action,
    EditorState editorState,
  ) async =>
      ImeDeltaResult.ignored;

  /// IME channel — see [ImeDeltaResult].
  Future<ImeDeltaResult> onFloatingCursor(
    RawFloatingCursorPoint point,
    EditorState editorState,
  ) async =>
      ImeDeltaResult.ignored;
}

/// Consults [strategies] in order and returns the first result that is not
/// [KeyEventResult.ignored]. Returns [KeyEventResult.ignored] when no
/// strategy handles the event.
KeyEventResult dispatchKeyEvent(
  List<KeyboardStrategy> strategies,
  KeyEvent event,
  EditorState editorState,
) {
  for (final strategy in strategies) {
    final result = strategy.onKeyEvent(event, editorState);
    if (result != KeyEventResult.ignored) {
      return result;
    }
  }
  return KeyEventResult.ignored;
}

/// Default strategy (WYSIWYG mode): a flat list of [CommandShortcutEvent]
/// for the hardware channel and [CharacterShortcutEvent] for the IME
/// channel, with the same behavior as the historical
/// `KeyboardServiceWidget` dispatch.
///
/// Preserved semantics:
/// - `handled` / `skipRemainingHandlers` win and stop iteration.
/// - `ignored` from an event that DID match keeps trying the rest.
/// - precedence = list order (that is why vim, being first, wins).
class DefaultEditorStrategy extends KeyboardStrategy {
  DefaultEditorStrategy({
    required this.commandShortcutEvents,
    required this.characterShortcutEvents,
  });

  final List<CommandShortcutEvent> commandShortcutEvents;
  final List<CharacterShortcutEvent> characterShortcutEvents;

  @override
  KeyEventResult onKeyEvent(KeyEvent event, EditorState editorState) {
    for (final shortcutEvent in commandShortcutEvents) {
      // check if the shortcut event can respond to the raw key event
      if (shortcutEvent.canRespondToRawKeyEvent(event)) {
        final result = shortcutEvent.handler(editorState);
        if (result == KeyEventResult.handled) {
          NovidentEditorLog.keyboard.debug(
            'keyboard service - handled by command shortcut event: $shortcutEvent',
          );
          return KeyEventResult.handled;
        } else if (result == KeyEventResult.skipRemainingHandlers) {
          NovidentEditorLog.keyboard.debug(
            'keyboard service - skip by command shortcut event: $shortcutEvent',
          );
          return KeyEventResult.skipRemainingHandlers;
        }
        continue;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Future<ImeDeltaResult> onInsert(
    TextEditingDeltaInsertion insertion,
    EditorState editorState,
  ) async {
    // On mobile devices, the "/" is context-sensitive,which means it can't be
    // recognized as a standalone character. This requires special handling.
    final isMobileSlash =
        UniversalPlatform.isMobile && insertion.textInserted == '/';

    // In France, the backtick key is used to toggle a character style.
    // We should prevent the execution of character shortcut events when the
    // composing range is not collapsed.
    if (insertion.composing.isCollapsed || isMobileSlash) {
      // execute character shortcut events
      final execution = await executeCharacterShortcutEvent(
        editorState,
        insertion.textInserted,
        characterShortcutEvents,
      );

      if (execution) {
        editorState.sliceUpcomingAttributes = false;
        return ImeDeltaResult.handled;
      }
    }
    return ImeDeltaResult.ignored;
  }

  @override
  Future<ImeDeltaResult> onReplace(
    TextEditingDeltaReplacement replacement,
    EditorState editorState,
  ) async {
    // Single branch only: the multi branch (selection across nodes) is
    // orchestrated by the widget — it deletes the selection, converts to
    // an insertion and passes the result through [onInsert] to preserve
    // the historical order (delete → dispatch → insert).
    final selection = editorState.selection;
    if (selection == null || !selection.isSingle) {
      return ImeDeltaResult.ignored;
    }
    final execution = await executeCharacterShortcutEvent(
      editorState,
      replacement.replacementText,
      characterShortcutEvents,
    );
    return execution ? ImeDeltaResult.handled : ImeDeltaResult.ignored;
  }

  @override
  Future<ImeDeltaResult> onNonTextUpdate(
    TextEditingDeltaNonTextUpdate nonTextUpdate,
    EditorState editorState,
  ) async {
    final handled = await _checkIfBacktickPressed(editorState, nonTextUpdate);
    return handled ? ImeDeltaResult.handled : ImeDeltaResult.ignored;
  }
}

/// Handles the backtick (`` ` `` → code) formatting that arrives through
/// non-text updates on some platforms/keyboards. Moved from
/// `delta_input_on_non_text_update_impl.dart` (WYSIWYG policy).
Future<bool> _checkIfBacktickPressed(
  EditorState editorState,
  TextEditingDeltaNonTextUpdate nonTextUpdate,
) async {
  // if the composing range is not empty, it means the user is typing a text,
  // so we don't need to handle the backtick pressed event
  if (!nonTextUpdate.composing.isCollapsed) {
    return false;
  }

  // if the selection is not collapsed, it means the user is not typing a text,
  // so we need to handle the backtick pressed event
  if (!nonTextUpdate.selection.isCollapsed) {
    return false;
  }

  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    NovidentEditorLog.input.debug('selection is null or not collapsed');
    return false;
  }

  final node = editorState.getNodesInSelection(selection).firstOrNull;
  if (node == null) {
    NovidentEditorLog.input.debug('node is null');
    return false;
  }

  // get last character of the node
  final lastCharacter = node.delta?.toPlainText().characters.lastOrNull;
  if (lastCharacter != '`') {
    NovidentEditorLog.input.debug('last character is not backtick');
    return false;
  }

  // check if the text should be formatted
  final (shouldApplyFormat, _) = checkSingleCharacterFormatShouldBeApplied(
    editorState: editorState,
    // check before the last character
    selection: selection.shift(-1),
    character: '`',
    formatStyle: FormatStyleByWrappingWithSingleChar.code,
  );

  if (!shouldApplyFormat) {
    NovidentEditorLog.input.debug('should not apply format');
    return false;
  }

  final transaction = editorState.transaction;
  transaction.deleteText(node, node.delta!.toPlainText().length - 1, 1);
  await editorState.apply(transaction);

  // remove the last backtick, and try to format the text to code block
  final isFormatted = handleFormatByWrappingWithSingleCharacter(
    editorState: editorState,
    character: '`',
    formatStyle: FormatStyleByWrappingWithSingleChar.code,
  );

  if (!isFormatted) {
    NovidentEditorLog.input.debug('format failed');
    // revert the transaction
    editorState.undoManager.undo();
  } else {
    editorState.sliceUpcomingAttributes = false;
  }

  return true;
}
