import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/testable_editor.dart';

final _keyAEvent = KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: LogicalKeyboardKey.keyA,
  character: 'a',
  timeStamp: Duration.zero,
);

final _keyBEvent = KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyB,
  logicalKey: LogicalKeyboardKey.keyB,
  character: 'b',
  timeStamp: Duration.zero,
);

CommandShortcutEvent _command(
  String command,
  CommandShortcutEventHandler handler,
) {
  return CommandShortcutEvent(
    key: 'test',
    command: command,
    getDescription: () => 'test',
    handler: handler,
  );
}

DefaultEditorStrategy _defaultStrategy(List<CommandShortcutEvent> commands) =>
    DefaultEditorStrategy(
      commandShortcutEvents: commands,
      characterShortcutEvents: const [],
    );

class _StubStrategy extends KeyboardStrategy {
  _StubStrategy(this.handler);

  final KeyEventResult Function(KeyEvent event, EditorState editorState)
      handler;

  final List<KeyEvent> seenEvents = [];

  @override
  KeyEventResult onKeyEvent(KeyEvent event, EditorState editorState) {
    seenEvents.add(event);
    return handler(event, editorState);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WysiwygStrategy', () {
    testWidgets('dispatches to the matching event and propagates the result',
        (tester) async {
      final strategy = _defaultStrategy([
        _command('a', (state) => KeyEventResult.handled),
      ]);

      expect(
        strategy.onKeyEvent(_keyAEvent, EditorState.blank()),
        KeyEventResult.handled,
      );
    });

    testWidgets(
        'propagates skipRemainingHandlers from the matching event and stops',
        (tester) async {
      final strategy = _defaultStrategy([
        _command('a', (state) => KeyEventResult.skipRemainingHandlers),
        _command('a', (state) => KeyEventResult.handled),
      ]);

      expect(
        strategy.onKeyEvent(_keyAEvent, EditorState.blank()),
        KeyEventResult.skipRemainingHandlers,
      );
    });

    testWidgets('first event in the list wins (precedence by order)',
        (tester) async {
      final calls = <String>[];
      final strategy = _defaultStrategy([
        _command('a', (state) {
          calls.add('first');
          return KeyEventResult.handled;
        }),
        _command('a', (state) {
          calls.add('second');
          return KeyEventResult.handled;
        }),
      ]);

      expect(
        strategy.onKeyEvent(_keyAEvent, EditorState.blank()),
        KeyEventResult.handled,
      );
      expect(calls, ['first']);
    });

    testWidgets('ignored from a matched event falls through to the next event',
        (tester) async {
      final calls = <String>[];
      final strategy = _defaultStrategy([
        _command('a', (state) {
          calls.add('first');
          return KeyEventResult.ignored;
        }),
        _command('a', (state) {
          calls.add('second');
          return KeyEventResult.handled;
        }),
      ]);

      expect(
        strategy.onKeyEvent(_keyAEvent, EditorState.blank()),
        KeyEventResult.handled,
      );
      expect(calls, ['first', 'second']);
    });

    testWidgets('returns ignored when nothing matches', (tester) async {
      final strategy = _defaultStrategy([
        _command('a', (state) => KeyEventResult.handled),
      ]);

      expect(
        strategy.onKeyEvent(_keyBEvent, EditorState.blank()),
        KeyEventResult.ignored,
      );
    });

    testWidgets('empty list returns ignored', (tester) async {
      final strategy = _defaultStrategy(const []);

      expect(
        strategy.onKeyEvent(_keyAEvent, EditorState.blank()),
        KeyEventResult.ignored,
      );
    });
  });

  group('dispatchKeyEvent', () {
    testWidgets('ignored falls through to the next strategy', (tester) async {
      final first = _StubStrategy(
        (event, state) => KeyEventResult.ignored,
      );
      final second = _StubStrategy(
        (event, state) => KeyEventResult.handled,
      );

      expect(
        dispatchKeyEvent(
          [first, second],
          _keyAEvent,
          EditorState.blank(),
        ),
        KeyEventResult.handled,
      );
      expect(first.seenEvents, hasLength(1));
      expect(second.seenEvents, hasLength(1));
    });

    testWidgets('handled stops the chain', (tester) async {
      final first = _StubStrategy(
        (event, state) => KeyEventResult.handled,
      );
      final second = _StubStrategy(
        (event, state) => KeyEventResult.handled,
      );

      expect(
        dispatchKeyEvent(
          [first, second],
          _keyAEvent,
          EditorState.blank(),
        ),
        KeyEventResult.handled,
      );
      expect(first.seenEvents, hasLength(1));
      expect(second.seenEvents, isEmpty);
    });

    testWidgets('skipRemainingHandlers stops the chain', (tester) async {
      final first = _StubStrategy(
        (event, state) => KeyEventResult.skipRemainingHandlers,
      );
      final second = _StubStrategy(
        (event, state) => KeyEventResult.handled,
      );

      expect(
        dispatchKeyEvent(
          [first, second],
          _keyAEvent,
          EditorState.blank(),
        ),
        KeyEventResult.skipRemainingHandlers,
      );
      expect(second.seenEvents, isEmpty);
    });

    testWidgets('empty chain returns ignored', (tester) async {
      expect(
        dispatchKeyEvent(const [], _keyAEvent, EditorState.blank()),
        KeyEventResult.ignored,
      );
    });
  });

  group('KeyboardServiceWidget integration', () {
    testWidgets('injected keyboardStrategies replace the default strategy',
        (tester) async {
      final seenKeys = <LogicalKeyboardKey>[];
      final strategy = _StubStrategy((event, state) {
        seenKeys.add(event.logicalKey);
        return KeyEventResult.ignored;
      });

      final editor = tester.editor..addParagraph(initialText: 'abc');
      await editor.startTesting(keyboardStrategies: [strategy]);

      await editor.updateSelection(
        Selection.single(path: [0], startOffset: 0),
      );

      // arrowRight is ignored by the injected strategy and the default
      // strategy is NOT in the chain → the cursor does not move.
      await editor.pressKey(key: LogicalKeyboardKey.arrowRight);

      expect(editor.selection!.start.offset, 0);
      expect(seenKeys, contains(LogicalKeyboardKey.arrowRight));

      await editor.dispose();
    });
  });
}
