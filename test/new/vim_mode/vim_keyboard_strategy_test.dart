import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final escapeEvent = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.escape,
    logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero,
  );

  final hEvent = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyH,
    logicalKey: LogicalKeyboardKey.keyH,
    character: 'h',
    timeStamp: Duration.zero,
  );

  const insertion = TextEditingDeltaInsertion(
    oldText: '',
    textInserted: 'a',
    insertionOffset: 0,
    selection: TextSelection.collapsed(offset: 1),
    composing: TextRange.empty,
  );

  group('VimStrategy onKeyEvent', () {
    testWidgets('handles vim commands in normal mode', (tester) async {
      final controller = VimModeController();
      final strategy = VimStrategy(controller);
      expect(controller.mode, VimMode.normal);

      // escape in normal mode → handled (unconditional onNormal).
      expect(
        strategy.onKeyEvent(escapeEvent, EditorState.blank()),
        KeyEventResult.handled,
      );

      controller.dispose();
    });

    testWidgets('falls through when the vim handler does not handle',
        (tester) async {
      final controller = VimModeController();
      final strategy = VimStrategy(controller);

      // 'h' (moveLeft) in normal mode without a selection → the handler
      // delegates to the standard command, which returns ignored → the
      // strategy yields the event to the chain.
      expect(
        strategy.onKeyEvent(hEvent, EditorState.blank()),
        KeyEventResult.ignored,
      );

      controller.dispose();
    });

    testWidgets('is ignored in insert mode', (tester) async {
      final controller = VimModeController();
      final strategy = VimStrategy(controller);
      controller.enterInsertMode();

      // 'h' is restricted to normal mode → ignored in insert.
      expect(
        strategy.onKeyEvent(hEvent, EditorState.blank()),
        KeyEventResult.ignored,
      );

      controller.dispose();
    });
  });

  group('VimStrategy IME channel', () {
    testWidgets('blocks input outside of insert mode', (tester) async {
      final controller = VimModeController();
      final strategy = VimStrategy(controller);
      final editorState = EditorState.blank();

      // normal mode: blocked.
      expect(controller.mode, VimMode.normal);
      expect(
        await strategy.onInsert(insertion, editorState),
        ImeDeltaResult.swallowed,
      );

      // insert mode: allowed.
      controller.enterInsertMode();
      expect(
        await strategy.onInsert(insertion, editorState),
        ImeDeltaResult.ignored,
      );

      // disabled: allowed even in normal mode.
      controller.configuration =
          controller.configuration.copyWith(enabled: false);
      expect(
        await strategy.onInsert(insertion, editorState),
        ImeDeltaResult.ignored,
      );

      controller.dispose();
      editorState.dispose();
    });

    testWidgets('does not block non-text updates or floating cursor',
        (tester) async {
      final controller = VimModeController();
      final strategy = VimStrategy(controller);
      final editorState = EditorState.blank();

      const nonTextUpdate = TextEditingDeltaNonTextUpdate(
        oldText: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );

      expect(
        await strategy.onNonTextUpdate(nonTextUpdate, editorState),
        ImeDeltaResult.ignored,
      );

      controller.dispose();
      editorState.dispose();
    });
  });

  group('vimKeyboardStrategies', () {
    testWidgets('returns vim first, then wysiwyg with standard lists',
        (tester) async {
      final controller = VimModeController();

      final strategies = vimKeyboardStrategies(controller);

      expect(strategies, hasLength(2));
      expect(strategies.first, isA<VimStrategy>());
      expect(strategies.last, isA<DefaultEditorStrategy>());

      controller.dispose();
    });
  });
}
