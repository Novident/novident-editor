import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util/document_util.dart';

TextEditingDeltaInsertion _insertion(
  String text, {
  TextRange composing = TextRange.empty,
}) {
  return TextEditingDeltaInsertion(
    oldText: ' a',
    textInserted: text,
    insertionOffset: 1,
    selection: const TextSelection.collapsed(offset: 2),
    composing: composing,
  );
}

TextEditingDeltaReplacement _replacement(String text) {
  return TextEditingDeltaReplacement(
    oldText: ' a',
    replacementText: text,
    replacedRange: const TextSelection.collapsed(offset: 1),
    selection: const TextSelection.collapsed(offset: 2),
    composing: TextRange.empty,
  );
}

TextEditingDeltaNonTextUpdate _nonTextUpdate() {
  return TextEditingDeltaNonTextUpdate(
    oldText: 'abc',
    selection: const TextSelection.collapsed(offset: 3),
    composing: TextRange.empty,
  );
}

CharacterShortcutEvent _char(
  String character,
  Future<bool> Function(EditorState) handler,
) {
  return CharacterShortcutEvent(
    key: 'test',
    character: character,
    handler: handler,
  );
}

class _StubStrategy extends KeyboardStrategy {
  @override
  KeyEventResult onKeyEvent(KeyEvent event, EditorState editorState) =>
      KeyEventResult.ignored;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WysiwygStrategy IME channel', () {
    testWidgets('onInsert dispatches matching character and returns true',
        (tester) async {
      final calls = <String>[];
      final strategy = DefaultEditorStrategy(
        commandShortcutEvents: const [],
        characterShortcutEvents: [
          _char('*', (state) async {
            calls.add('asterisk');
            return true;
          }),
        ],
      );
      final state = EditorState.blank();
      state.sliceUpcomingAttributes = true;

      final result = await strategy.onInsert(_insertion('*'), state);

      expect(result, ImeDeltaResult.handled);
      expect(calls, ['asterisk']);
      expect(state.sliceUpcomingAttributes, false);
    });

    testWidgets('onInsert skips dispatch while composing', (tester) async {
      final calls = <String>[];
      final strategy = DefaultEditorStrategy(
        commandShortcutEvents: const [],
        characterShortcutEvents: [
          _char('*', (state) async {
            calls.add('asterisk');
            return true;
          }),
        ],
      );
      final state = EditorState.blank();
      state.sliceUpcomingAttributes = true;

      final result = await strategy.onInsert(
        _insertion('*', composing: const TextRange(start: 0, end: 1)),
        state,
      );

      expect(result, ImeDeltaResult.ignored);
      expect(calls, isEmpty);
      expect(state.sliceUpcomingAttributes, true);
    });

    testWidgets('onInsert without match returns false and keeps flags',
        (tester) async {
      final calls = <String>[];
      final strategy = DefaultEditorStrategy(
        commandShortcutEvents: const [],
        characterShortcutEvents: [
          _char('*', (state) async {
            calls.add('asterisk');
            return true;
          }),
        ],
      );
      final state = EditorState.blank();
      state.sliceUpcomingAttributes = true;

      final result = await strategy.onInsert(_insertion('b'), state);

      expect(result, ImeDeltaResult.ignored);
      expect(calls, isEmpty);
      expect(state.sliceUpcomingAttributes, true);
    });

    testWidgets('onReplace single dispatches on replacementText',
        (tester) async {
      final calls = <String>[];
      final strategy = DefaultEditorStrategy(
        commandShortcutEvents: const [],
        characterShortcutEvents: [
          _char('*', (state) async {
            calls.add('asterisk');
            return true;
          }),
        ],
      );
      final state = EditorState.blank();
      state.selection = Selection.single(path: [0], startOffset: 1);

      final result = await strategy.onReplace(_replacement('*'), state);

      expect(result, ImeDeltaResult.handled);
      expect(calls, ['asterisk']);
    });

    testWidgets('onReplace multi returns false without mutating selection',
        (tester) async {
      final strategy = DefaultEditorStrategy(
        commandShortcutEvents: const [],
        characterShortcutEvents: [
          _char('*', (state) async => true),
        ],
      );
      final state = EditorState.blank();
      state.document.addParagraphs(2);
      final selection = Selection(
        start: Position(path: [0]),
        end: Position(path: [1]),
      );
      state.selection = selection;

      final result = await strategy.onReplace(_replacement('*'), state);

      expect(result, ImeDeltaResult.ignored);
      // the strategy does not mutate: the widget orchestrates delete → onInsert
      expect(state.selection, selection);
      expect(state.selection!.isSingle, false);
    });

    testWidgets(
        'onNonTextUpdate returns false when last char is not a backtick',
        (tester) async {
      final strategy = DefaultEditorStrategy(
        commandShortcutEvents: const [],
        characterShortcutEvents: const [],
      );
      final state = EditorState.blank();
      state.document.addParagraph(initialText: 'abc');
      state.selection = Selection.single(path: [1], startOffset: 3);

      final result = await strategy.onNonTextUpdate(_nonTextUpdate(), state);

      expect(result, ImeDeltaResult.ignored);
    });

    testWidgets('IME defaults are no-op', (tester) async {
      final strategy = _StubStrategy();
      final state = EditorState.blank();

      expect(
        await strategy.onInsert(_insertion('a'), state),
        ImeDeltaResult.ignored,
      );
      expect(
        await strategy.onReplace(_replacement('a'), state),
        ImeDeltaResult.ignored,
      );
      expect(
        await strategy.onNonTextUpdate(_nonTextUpdate(), state),
        ImeDeltaResult.ignored,
      );
      expect(
        await strategy.onPerformAction(TextInputAction.done, state),
        ImeDeltaResult.ignored,
      );
    });
  });
}
