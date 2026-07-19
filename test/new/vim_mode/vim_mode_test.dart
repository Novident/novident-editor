import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/render/selection/cursor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VimModeConfiguration', () {
    test('resolves defaults and overrides', () {
      const configuration = VimModeConfiguration();
      expect(configuration.commandOf(VimCommand.moveLeft), 'h');
      expect(configuration.commandOf(VimCommand.enterNormalMode), 'escape');

      final remapped = configuration.rebind(VimCommand.moveLeft, 'a');
      expect(remapped.commandOf(VimCommand.moveLeft), 'a');
      // the other bindings keep their defaults.
      expect(remapped.commandOf(VimCommand.moveRight), 'l');
      // rebind is additive.
      final remappedTwice = remapped.rebind(VimCommand.moveRight, 'd');
      expect(remappedTwice.commandOf(VimCommand.moveLeft), 'a');
      expect(remappedTwice.commandOf(VimCommand.moveRight), 'd');
    });

    test('equality is value based', () {
      const a = VimModeConfiguration();
      const b = VimModeConfiguration();
      expect(a, b);
      expect(
        a.rebind(VimCommand.moveLeft, 'a'),
        isNot(
          equals(b),
        ),
      );
    });

    test('explicit overrides shadow the defaults of other commands', () {
      final configuration =
          const VimModeConfiguration().rebind(VimCommand.moveLeft, 'a');
      final resolved = configuration.keybindings;

      expect(resolved[VimCommand.moveLeft], 'a');
      // 'a' was the default of enterInsertModeAfter — now unbound.
      expect(resolved[VimCommand.enterInsertModeAfter], isEmpty);
      // unrelated commands keep their defaults.
      expect(resolved[VimCommand.moveRight], 'l');

      // multi-combo defaults only lose the shadowed combination.
      final multi = const VimModeConfiguration()
          .rebind(VimCommand.deleteUnderCursor, 'u,shift+x');
      expect(
        multi.keybindings[VimCommand.undo],
        isEmpty,
      );
      expect(
        multi.keybindings[VimCommand.deleteUnderCursor],
        'u,shift+x',
      );
    });
  });

  group('VimModeController', () {
    test('mode transitions notify listeners', () {
      final controller = VimModeController();
      expect(controller.mode, VimMode.normal);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.enterInsertMode();
      expect(controller.mode, VimMode.insert);
      controller.enterVisualMode();
      expect(controller.mode, VimMode.visual);
      controller.enterNormalMode();
      expect(controller.mode, VimMode.normal);
      // same mode: no extra notification.
      controller.enterNormalMode();
      expect(notified, 3);

      controller.dispose();
    });

    test('rebinding updates the cached shortcut events in place', () {
      final controller = VimModeController();
      final event = controller.commandShortcutEventOf(VimCommand.moveLeft)!;
      expect(event.command, 'h');

      controller.configuration =
          controller.configuration.rebind(VimCommand.moveLeft, 'a,arrow left');

      // same event instance, new binding.
      expect(
        identical(
          event,
          controller.commandShortcutEventOf(VimCommand.moveLeft)!,
        ),
        true,
      );
      expect(event.command, 'a,arrow left');

      controller.dispose();
    });

    test('disabling the emulation falls back to insert mode', () {
      final controller = VimModeController();
      expect(controller.mode, VimMode.normal);

      controller.toggleEnabled();
      expect(controller.enabled, false);
      expect(controller.mode, VimMode.insert);

      controller.dispose();
    });

    test('the IME interceptor blocks input outside of insert mode', () async {
      final controller = VimModeController();
      final editorState = EditorState.blank(withInitialText: true);
      const insertion = TextEditingDeltaInsertion(
        oldText: '',
        textInserted: 'a',
        insertionOffset: 0,
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange.empty,
      );

      // normal mode: blocked.
      expect(controller.mode, VimMode.normal);
      expect(
        await controller.keyboardInterceptor
            .interceptInsert(insertion, editorState, []),
        true,
      );

      // insert mode: allowed.
      controller.enterInsertMode();
      expect(
        await controller.keyboardInterceptor
            .interceptInsert(insertion, editorState, []),
        false,
      );

      // disabled: allowed even in normal mode.
      controller.configuration =
          controller.configuration.copyWith(enabled: false);
      expect(
        await controller.keyboardInterceptor
            .interceptInsert(insertion, editorState, []),
        false,
      );

      controller.dispose();
      editorState.dispose();
    });
  });

  group('vim mode key handling', () {
    Future<(EditorState, VimModeController)> pumpVimEditor(
      WidgetTester tester, {
      VimModeConfiguration configuration = const VimModeConfiguration(),
    }) async {
      await NovidentEditorLocalizations.load(const Locale('en'));

      final document = Document.blank()
        ..insert([
          0,
        ], [
          paragraphNode(text: 'alpha beta'),
          paragraphNode(text: 'second line'),
          paragraphNode(text: 'third line'),
        ]);
      final editorState = EditorState(document: document);
      final controller = VimModeController(configuration: configuration);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: NovidentEditor(
              editorState: editorState,
              commandShortcutEvents: [
                ...controller.commandShortcutEvents,
                ...standardCommandShortcutEvents,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.attach(editorState);

      // place the cursor and focus the editor.
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 2)),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();

      return (editorState, controller);
    }

    testWidgets('h/l move the caret in normal mode', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);
      expect(controller.mode, VimMode.normal);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.offset, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.offset, 3);

      controller.dispose();
    });

    testWidgets('vim keys are inactive in insert mode and when disabled',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      controller.enterInsertMode();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      // 'h' is not a motion in insert mode (and there's no IME in tests,
      // so nothing is typed either).
      expect(editorState.selection?.end.offset, 2);

      controller.enterNormalMode();
      controller.configuration =
          controller.configuration.copyWith(enabled: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.offset, 2);

      controller.dispose();
    });

    testWidgets('i enters insert mode, escape returns to normal',
        (tester) async {
      final (_, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.insert);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.normal);

      controller.dispose();
    });

    testWidgets('v enters visual mode and motions extend the selection',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.visual);

      // like vim, `v` immediately wraps the character under the caret.
      var selection = editorState.selection;
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, false);
      expect(selection.start.offset, 2);
      expect(selection.end.offset, 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();

      selection = editorState.selection;
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, false);
      expect(selection.start.offset, 2);
      expect(selection.end.offset, 5);

      // escape collapses the selection and returns to normal mode.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.normal);
      expect(editorState.selection?.isCollapsed, true);

      controller.dispose();
    });

    testWidgets('x deletes the character under the caret and u undoes it',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();
      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'alha beta',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pumpAndSettle();
      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'alpha beta',
      );

      controller.dispose();
    });

    testWidgets('dd cuts the whole line (single d only arms the operator)',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);
      expect(editorState.document.root.children.length, 3);

      // first press: the operator is armed, nothing is deleted.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(controller.pendingCommand, 'd');
      expect(editorState.document.root.children.length, 3);

      // second press: the line is removed.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(controller.pendingCommand, null);
      expect(editorState.document.root.children.length, 2);
      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'second line',
      );

      controller.dispose();
    });

    testWidgets('any other command disarms a pending dd', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(controller.pendingCommand, 'd');

      // a motion cancels the operator…
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      expect(controller.pendingCommand, null);

      // …so the next single d must not delete anything.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(editorState.document.root.children.length, 3);
      expect(controller.pendingCommand, 'd');

      // escape also disarms it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.pendingCommand, null);

      controller.dispose();
    });

    testWidgets('d cuts the selection in visual mode', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.visual);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();

      // 'pha' (offsets 2..5 — v wraps the caret character) was cut in a
      // single press.
      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'al beta',
      );
      expect(controller.mode, VimMode.normal);
      expect(editorState.document.root.children.length, 3);

      controller.dispose();
    });

    testWidgets('v wraps the character under the caret so d cuts it',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      // caret on 'p' (offset 2): v + d must delete exactly that character.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();

      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'alha beta',
      );
      expect(controller.mode, VimMode.normal);

      controller.dispose();
    });

    testWidgets('shift+v selects the whole current node', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // linewise visual: the whole node is selected.
      expect(controller.mode, VimMode.visual);
      final selection = editorState.selection;
      expect(selection, isNotNull);
      expect(selection!.start.path, [0]);
      expect(selection.start.offset, 0);
      expect(selection.end.path, [0]);
      expect(selection.end.offset, 'alpha beta'.length);

      // d cuts the whole line's text in one press.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        '',
      );
      expect(controller.mode, VimMode.normal);
      expect(editorState.document.root.children.length, 3);

      controller.dispose();
    });

    testWidgets('shift+v widens a charwise selection to full nodes',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      // charwise visual spanning into the second node.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.path, [1]);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      final selection = editorState.selection;
      expect(controller.mode, VimMode.visual);
      expect(selection!.start.path, [0]);
      expect(selection.start.offset, 0);
      expect(selection.end.path, [1]);
      expect(selection.end.offset, 'second line'.length);

      controller.dispose();
    });

    testWidgets('p replaces the selection in visual mode', (tester) async {
      NovidentClipboard.mockSetData(
        const NovidentClipboardData(text: 'XYZ'),
      );
      addTearDown(() => NovidentClipboard.mockSetData(null));

      final (editorState, controller) = await pumpVimEditor(tester);

      // select 'ph' (offsets 2..4) in visual mode.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.visual);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      // the selection (offsets 2..5) was replaced by the pasted text.
      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'alXYZ beta',
      );
      expect(controller.mode, VimMode.normal);

      controller.dispose();
    });

    testWidgets('ctrl+v replaces the selection in visual mode and exits visual',
        (tester) async {
      NovidentClipboard.mockSetData(
        const NovidentClipboardData(text: 'XYZ'),
      );
      addTearDown(() => NovidentClipboard.mockSetData(null));

      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.visual);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        editorState.document.root.children.first.delta!.toPlainText(),
        'alXYZ beta',
      );
      // the edit collapsed the selection through a transaction — like vim,
      // the editor drops back to normal mode.
      expect(controller.mode, VimMode.normal);

      controller.dispose();
    });

    testWidgets('o opens a line below and enters insert mode', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.pumpAndSettle();

      expect(editorState.document.root.children.length, 4);
      expect(
        editorState.document.root.children.elementAt(1).delta!.toPlainText(),
        '',
      );
      expect(controller.mode, VimMode.insert);
      expect(editorState.selection?.end.path, [1]);

      controller.dispose();
    });

    testWidgets('custom keybindings are honored at runtime', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      controller.configuration =
          controller.configuration.rebind(VimCommand.moveLeft, 'a');
      await tester.pumpAndSettle();

      // the old binding no longer moves the caret.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.offset, 2);

      // the new binding does.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.offset, 1);

      controller.dispose();
    });

    testWidgets('shift+g moves to the end of the document', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(editorState.selection?.end.path, [2]);
      expect(
        editorState.selection?.end.offset,
        'third line'.length,
      );

      controller.dispose();
    });

    testWidgets('{ and } move between blocks', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);
      expect(editorState.selection?.end.path, [0]);

      // } → next block
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.path, [1]);
      expect(editorState.selection?.end.offset, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.path, [2]);

      // { → previous block
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(editorState.selection?.end.path, [1]);
      expect(editorState.selection?.end.offset, 0);

      // in visual mode } extends the selection.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(editorState.selection?.isCollapsed, false);
      expect(editorState.selection?.end.path, [2]);

      controller.dispose();
    });

    testWidgets('mouse driven selections keep the mode in sync',
        (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);
      expect(controller.mode, VimMode.normal);

      // mouse drag → expanded selection with a ui event reason → visual.
      editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: 5),
        ),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.visual);

      // mouse click → collapsed selection → back to normal.
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 3)),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.normal);

      // transaction driven selections never switch the mode.
      editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: 5),
        ),
        reason: SelectionUpdateReason.transaction,
      );
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.normal);

      // the sync can be turned off.
      controller.configuration = controller.configuration.copyWith(
        syncModeWithSelection: false,
      );
      editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: 5),
        ),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();
      expect(controller.mode, VimMode.normal);

      controller.dispose();
    });

    testWidgets('word motions at the line edges do not throw', (tester) async {
      final (editorState, controller) = await pumpVimEditor(tester);

      // w with the caret at the very end of a line used to throw a
      // RangeError (the word boundary lives in the next node).
      editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(path: [0], offset: 'alpha beta'.length),
        ),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // b with the caret at the very beginning of a line: same class of
      // bug in the opposite direction.
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [1])),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      controller.dispose();
    });
  });

  group('vim cursor appearance', () {
    Future<(EditorState, VimModeController)> pumpVimEditorForCursor(
      WidgetTester tester, {
      VimModeConfiguration configuration = const VimModeConfiguration(),
    }) async {
      await NovidentEditorLocalizations.load(const Locale('en'));

      final document = Document.blank()
        ..insert([
          0,
        ], [
          paragraphNode(text: 'alpha beta'),
          paragraphNode(text: 'second line'),
        ]);
      final editorState = EditorState(document: document);
      final controller = VimModeController(configuration: configuration);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: NovidentEditor(
              editorState: editorState,
              commandShortcutEvents: [
                ...controller.commandShortcutEvents,
                ...standardCommandShortcutEvents,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.attach(editorState);

      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 2)),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();

      return (editorState, controller);
    }

    Finder caret() => find.byType(Cursor);

    Cursor caretWidget(WidgetTester tester) =>
        tester.widget<Cursor>(caret().first);

    testWidgets(
        'normal mode paints one native block caret, insert mode restores '
        'the thin caret', (tester) async {
      final (_, controller) = await pumpVimEditorForCursor(tester);

      // normal mode: a single native caret, widened into a steady block.
      expect(controller.mode, VimMode.normal);
      expect(caret(), findsOneWidget);
      var cursor = caretWidget(tester);
      expect(cursor.shouldBlink, false);
      final height = cursor.rect.height;
      expect(
        cursor.rect.width,
        greaterThanOrEqualTo(height * 0.4 - 0.001),
      );
      expect(
        cursor.rect.width,
        lessThanOrEqualTo(height * 1.0 + 0.001),
      );

      // insert mode: the caret goes back to the configured thin blinking
      // line — still a single cursor, never two.
      controller.enterInsertMode();
      await tester.pumpAndSettle();
      expect(caret(), findsOneWidget);
      cursor = caretWidget(tester);
      expect(cursor.shouldBlink, true);
      expect(cursor.rect.width, lessThan(5));

      controller.dispose();
    });

    testWidgets('the block width is clamped on whitespace', (tester) async {
      final (editorState, controller) = await pumpVimEditorForCursor(tester);

      // place the caret on the space of 'alpha beta' (offset 5): the
      // measured character width is tiny, so the minimum factor applies.
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 5)),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pumpAndSettle();

      final cursor = caretWidget(tester);
      expect(
        cursor.rect.width,
        greaterThanOrEqualTo(
          cursor.rect.height * 0.4 - 0.001,
        ),
      );

      controller.dispose();
    });

    testWidgets('visual mode paints the block at the selection head',
        (tester) async {
      final (editorState, controller) = await pumpVimEditorForCursor(tester);

      // block position in normal mode (caret on offset 2).
      final normalLeft = caretWidget(tester).rect.left;

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(controller.mode, VimMode.visual);
      // `v` wraps the character under the caret internally…
      expect(editorState.selection?.isCollapsed, false);
      expect(editorState.selection?.end.offset, 3);
      // …but the painted block does NOT move: the head renders at
      // `end - 1`, on the same character, exactly like vim.
      expect(caret(), findsOneWidget);
      expect(caretWidget(tester).rect.left, normalLeft);

      // motions move the painted head along the last selected character.
      final headBefore = caretWidget(tester).rect.left;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(caretWidget(tester).rect.left, greaterThan(headBefore));

      controller.dispose();
    });

    testWidgets('honors the configured cursor style', (tester) async {
      const customColor = Color(0xFF9C27B0);
      final (_, controller) = await pumpVimEditorForCursor(
        tester,
        configuration: const VimModeConfiguration(
          cursorStyle: VimCursorStyle(
            color: customColor,
            opacity: 1.0,
            blockWidth: 12,
            blink: true,
          ),
        ),
      );

      var cursor = caretWidget(tester);
      expect(cursor.rect.width, 12);
      expect(cursor.shouldBlink, true);
      expect(cursor.color.toARGB32(), customColor.toARGB32());

      // the style can be changed at runtime without rebuilding the editor.
      controller.configuration = controller.configuration.copyWith(
        cursorStyle: const VimCursorStyle(blockWidth: 20),
      );
      await tester.pumpAndSettle();
      cursor = caretWidget(tester);
      expect(cursor.rect.width, 20);
      expect(cursor.shouldBlink, false);

      controller.dispose();
    });

    testWidgets('disabled emulation keeps the default caret', (tester) async {
      final (_, controller) = await pumpVimEditorForCursor(
        tester,
        configuration: const VimModeConfiguration(enabled: false),
      );

      final cursor = caretWidget(tester);
      expect(cursor.shouldBlink, true);
      expect(cursor.rect.width, lessThan(5));

      controller.dispose();
    });
  });
}
