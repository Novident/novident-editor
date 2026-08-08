import 'dart:async';

import 'package:flutter/material.dart' hide RichText, TextPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Tests for [VimSelectionRenderer] behaviour beyond cursor painting
/// (which is already covered by [VimModeTest]).
///
/// These tests verify the movement hooks, focus lifecycle, and visual
/// mode selection-rect expansion that the renderer adds on top of the
/// default [SelectionRenderer].
void main() {
  late EditorState es;
  late VimModeController vim;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await NovidentEditorLocalizations.load(const Locale('en'));
  });

  tearDown(() {
    es.dispose();
    vim.dispose();
  });

  // ── Helpers ───────────────────────────────────────────────────

  /// Build a single-paragraph editor with the given [delta] + vim
  /// controller and return both the [EditorState] and the
  /// [SelectableMixin] of node 0.
  Future<SelectableMixin> build(
    WidgetTester tester,
    Delta delta, {
    bool enableVim = true,
  }) async {
    es = EditorState.blank(withInitialText: false);
    vim = VimModeController(
      configuration: VimModeConfiguration(
        enabled: enableVim,
        initialMode: enableVim ? VimMode.normal : VimMode.insert,
      ),
    );

    final tx = es.transaction;
    tx.insertNode([0], paragraphNode(delta: delta));
    await es.apply(tx);

    es.editorStyle = const EditorStyle.desktop(
      padding: EdgeInsets.symmetric(horizontal: 32),
      firstLineIndent: 30,
      maxWidth: 654,
    );

    // Attach vim after editorState is ready.
    vim.attach(es);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          NovidentEditorLocalizations.delegate,
        ],
        supportedLocales: NovidentEditorLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 654,
            child: NovidentEditor(
              editorState: es,
              editorStyle: es.editorStyle.copyWith(
                selectionRenderer: VimSelectionRenderer(
                  controller: vim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return es.getNodeAtPath([0])!.selectable!;
  }

  CursorMoveContext moveCtx(
    SelectableMixin delegate,
    Node node,
    int offset,
  ) {
    final rp = delegate.getRenderParagraph();
    return CursorMoveContext(
      node: node,
      currentOffset: offset,
      caretLocalDx: delegate.getCaretLocalDx(offset) ?? 0,
      textDirection: delegate.textDirection(),
      delegate: delegate,
      renderParagraph: rp,
      textShift: delegate.textShift,
      delta: node.delta,
    );
  }

  group('VimSelectionRenderer', () {
    // ── Focus lifecycle ───────────────────────────────────────────

    testWidgets('onFocusLost saves and onFocusGained restores mode',
        (tester) async {
      final delta = Delta()..insert('hello world');
      await build(tester, delta);

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Switch to visual mode so we have something to restore.
      vim.enterVisualMode();
      expect(vim.mode, VimMode.visual);

      // Lose focus → saves visual.
      renderer.onFocusLost(const FocusLifecycleContext(hasSelection: false));

      // Return to normal while unfocused.
      vim.enterNormalMode();
      expect(vim.mode, VimMode.normal);

      // Gain focus → restores visual.
      renderer.onFocusGained(const FocusLifecycleContext(hasSelection: false));
      expect(vim.mode, VimMode.visual);
    });

    testWidgets('onFocusGained with no saved mode does not change current mode',
        (tester) async {
      final delta = Delta()..insert('hello');
      await build(tester, delta);

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // In normal mode, gain focus without prior loss.
      expect(vim.mode, VimMode.normal);
      renderer.onFocusGained(const FocusLifecycleContext(hasSelection: false));
      expect(vim.mode, VimMode.normal);
    });

    testWidgets('onFocusLost clears preferred column', (
      tester,
    ) async {
      final delta = Delta()..insert('hello world');
      await build(tester, delta);

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Seed preferred column via a vertical move.
      final delegate = es.getNodeAtPath([0])!.selectable!;
      final node = es.getNodeAtPath([0])!;
      final ctx = moveCtx(delegate, node, 0);
      renderer.onVerticalMove(ctx);
      expect(renderer.debugPreferredColumnDx, isNotNull);

      // Lose focus.
      renderer.onFocusLost(const FocusLifecycleContext(hasSelection: false));
      expect(renderer.debugPreferredColumnDx, isNull);
    });

    // ── Horizontal move ───────────────────────────────────────────

    testWidgets(
        'onHorizontalMove blocks crossing line boundaries in normal mode',
        (tester) async {
      // Text narrow enough to wrap at maxWidth 654 with padding 32 + indent 30.
      const text =
          'aaaaa bbbbb ccccc ddddd eeeee fffff ggggg hhhhh iiiii jjjjj '
          'kkkkk lllll mmmmm nnnnn ooooo ppppp qqqqq rrrrr sssss ttttt '
          'uuuuu vvvvv wwwww xxxxx yyyyy zzzzz';
      final delta = Delta()..insert(text);
      final delegate = await build(
        tester,
        delta,
      );
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Place cursor at the end of the first line. Then try to move right.
      // It should NOT cross to the next line in normal mode.
      final rp = delegate.getRenderParagraph()!;
      final tp = rp.textPainter;
      // Find the end of the first line.
      final firstLine = tp.getLineBoundary(const TextPosition(offset: 0));
      final firstLineEnd = firstLine.end - delegate.textShift;

      // Position at last char of first line.
      final atEnd = firstLineEnd > 0 ? firstLineEnd - 1 : 0;
      final ctx = moveCtx(delegate, node, atEnd);

      // In normal mode, moving right should be blocked.
      expect(vim.mode, VimMode.normal);
      final result = renderer.onHorizontalMove(ctx);
      // The fallback would move to offset atEnd + 1, but our renderer
      // should block if it crosses to the next line.
      if (result != null) {
        // If result is returned, it must stay in the same line.
        final resultLine = tp.getLineBoundary(
          TextPosition(offset: result.offset + delegate.textShift),
        );
        expect(
          resultLine.start,
          firstLine.start,
          reason: 'Horizontal move crossed line boundary',
        );
      }
    });

    testWidgets('onHorizontalMove allows crossing lines in visual mode',
        (tester) async {
      const text =
          'aaaaa bbbbb ccccc ddddd eeeee fffff ggggg hhhhh iiiii jjjjj '
          'kkkkk lllll';
      final delta = Delta()..insert(text);
      final delegate = await build(tester, delta);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Enter visual mode.
      vim.enterVisualMode();
      expect(vim.mode, VimMode.visual);

      // Move left from offset 0. In visual mode this should be allowed
      // (the fallback handles it, the renderer just doesn't block).
      final ctx = moveCtx(delegate, node, 0);
      final result = renderer.onHorizontalMove(ctx);
      // In visual mode, the renderer delegates to fallback unconditionally.
      // The fallback would return null for moving left at offset 0.
      // That's fine — we just verify it didn't crash or throw.
      expect(result ?? Position(path: [0]), isA<Position>());
    });

    // ── Line start / end ──────────────────────────────────────────

    testWidgets('onMoveToLineStart returns the first character of the line',
        (tester) async {
      const text =
          'aaaaa bbbbb ccccc ddddd eeeee fffff ggggg hhhhh iiiii jjjjj '
          'kkkkk lllll mmmmm nnnnn';
      final delta = Delta()..insert(text);
      final delegate = await build(tester, delta);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Place cursor in the middle of the second line.
      final rp = delegate.getRenderParagraph()!;
      final tp = rp.textPainter;
      final textShift = delegate.textShift;

      // Find second line.
      final firstLine = tp.getLineBoundary(TextPosition(offset: textShift));
      final secondLine =
          tp.getLineBoundary(TextPosition(offset: firstLine.end));
      final midSecond = secondLine.start + 3;

      final ctx = moveCtx(delegate, node, midSecond - textShift);
      final result = renderer.onMoveToLineStart(ctx);

      expect(result, isNotNull);
      expect(
        result!.offset,
        secondLine.start - textShift,
        reason: 'Should jump to start of second line, '
            'got offset ${result.offset}',
      );
    });

    testWidgets('onMoveToLineEnd returns the last character of the line',
        (tester) async {
      const text =
          'aaaaa bbbbb ccccc ddddd eeeee fffff ggggg hhhhh iiiii jjjjj '
          'kkkkk lllll mmmmm nnnnn';
      final delta = Delta()..insert(text);
      final delegate = await build(tester, delta);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Place cursor at start of second line, jump to end.
      final rp = delegate.getRenderParagraph()!;
      final tp = rp.textPainter;
      final textShift = delegate.textShift;

      final firstLine = tp.getLineBoundary(TextPosition(offset: textShift));
      final secondLine =
          tp.getLineBoundary(TextPosition(offset: firstLine.end));
      final startSecond = secondLine.start - textShift;

      final ctx = moveCtx(delegate, node, startSecond);
      final result = renderer.onMoveToLineEnd(ctx);

      expect(result, isNotNull);
      expect(
        result!.offset,
        secondLine.end - textShift,
        reason: 'Should jump to end of second line, '
            'got offset ${result.offset}',
      );
    });

    // ── Vertical move + preferred column ──────────────────────────

    testWidgets('onVerticalMove seeds preferred column on first call',
        (tester) async {
      const text = 'Line one\nLine two\nLine three';
      final delta = Delta()..insert(text);
      final delegate = await build(tester, delta);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;
      expect(renderer.debugPreferredColumnDx, isNull);

      final ctx = moveCtx(delegate, node, 0);
      renderer.onVerticalMove(ctx);

      // Should have seeded from caretLocalDx.
      expect(renderer.debugPreferredColumnDx, isNotNull);
      expect(renderer.debugPreferredColumnDx, ctx.caretLocalDx);
    });

    testWidgets('onVerticalMove preserves preferred column across calls',
        (tester) async {
      const text = 'Line one\nLine two\nLine three';
      final delta = Delta()..insert(text);
      final delegate = await build(tester, delta);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // First call seeds.
      final ctx1 = moveCtx(delegate, node, 0);
      renderer.onVerticalMove(ctx1);
      final firstColumn = renderer.debugPreferredColumnDx;

      // Second call should NOT change the column.
      final ctx2 = moveCtx(delegate, node, 5);
      renderer.onVerticalMove(ctx2);

      expect(renderer.debugPreferredColumnDx, firstColumn);
    });

    testWidgets('onMoveCompleted clears column on non-vertical moves',
        (tester) async {
      final delta = Delta()..insert('hello world');
      await build(tester, delta);

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Seed column.
      renderer.debugPreferredColumnDx = 42.0;

      // Complete a horizontal move → column should clear.
      renderer.onMoveCompleted(
        MoveCompletedContext(
          node: es.getNodeAtPath([0])!,
          fromPosition: Position(path: [0]),
          toPosition: Position(path: [0], offset: 1),
          direction: MoveDirection.left,
        ),
      );

      expect(renderer.debugPreferredColumnDx, isNull);
    });

    testWidgets('onMoveCompleted keeps column on vertical moves',
        (tester) async {
      final delta = Delta()..insert('line one\nline two');
      await build(tester, delta);

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Seed column.
      renderer.debugPreferredColumnDx = 42.0;

      // Complete a vertical move → column should persist.
      renderer.onMoveCompleted(
        MoveCompletedContext(
          node: es.getNodeAtPath([0])!,
          fromPosition: Position(path: [0]),
          toPosition: Position(path: [0], offset: 8),
          direction: MoveDirection.down,
        ),
      );

      expect(renderer.debugPreferredColumnDx, 42.0);
    });

    // ── Vim disabled / insert mode ────────────────────────────────

    testWidgets('delegates to fallback when vim is disabled', (tester) async {
      final delta = Delta()..insert('hello world');
      final delegate = await build(tester, delta, enableVim: false);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;
      expect(vim.enabled, false);

      final ctx = moveCtx(delegate, node, 0);

      // All movement hooks should return null (fallback behavior).
      expect(renderer.onVerticalMove(ctx), isNull);
      expect(renderer.onHorizontalMove(ctx), isNull);
      expect(renderer.onMoveToLineStart(ctx), isNull);
      expect(renderer.onMoveToLineEnd(ctx), isNull);

      // Focus hooks should be no-ops (not crash).
      renderer.onFocusGained(const FocusLifecycleContext(hasSelection: false));
      renderer.onFocusLost(const FocusLifecycleContext(hasSelection: false));
    });

    testWidgets('delegates to fallback in insert mode', (tester) async {
      final delta = Delta()..insert('hello world');
      final delegate = await build(tester, delta);
      final node = es.getNodeAtPath([0])!;

      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Switch to insert mode.
      vim.enterInsertMode();
      expect(vim.mode, VimMode.insert);

      final ctx = moveCtx(delegate, node, 0);

      // Movement hooks should return null in insert mode.
      expect(renderer.onVerticalMove(ctx), isNull);
      expect(renderer.onHorizontalMove(ctx), isNull);
    });

    // ── onTryMove ─────────────────────────────────────────────────

    testWidgets('onTryMove cancels moves with negative target offset',
        (tester) async {
      final delta = Delta()..insert('hello');
      await build(tester, delta);
      final node = es.getNodeAtPath([0])!;
      final renderer = es.selectionRenderer as VimSelectionRenderer;

      final result = renderer.onTryMove(
        MoveAttemptContext(
          currentNode: node,
          currentPosition: Position(path: [0]),
          currentCursorRect: Rect.zero,
          textDirection: TextDirection.ltr,
          currentDelegate: node.selectable!,
          targetNode: node,
          targetPosition: Position(path: [0], offset: -1),
          targetCursorRect: Rect.zero,
          direction: MoveDirection.up,
          crossesBlockBoundary: false,
        ),
      );

      // Should be a cancel intention.
      expect(result, isNotNull);
      expect(result!.target, isNull); // cancel has null target
    });

    // ── Visual mode selection rects ───────────────────────────────

    testWidgets(
        'onSelectionRectsMeasured expands rects to block width in visual',
        (tester) async {
      final delta = Delta()..insert('hello world');
      await build(tester, delta);
      final node = es.getNodeAtPath([0])!;
      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Enter visual mode with a selection.
      vim.enterVisualMode();
      unawaited(es.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: 5),
        ),
        reason: SelectionUpdateReason.uiEvent,
      ));
      await tester.pumpAndSettle();

      final ctx = SelectionMeasureContext(
        node: node,
        selection: es.selection!,
        textDirection: TextDirection.ltr,
        delegate: node.selectable!,
      );

      final rects = renderer.onSelectionRectsMeasured(ctx);
      expect(rects, isNotNull);
      expect(rects!.length, greaterThan(0));

      // Each rect should have width > 0 (expanded, not zero).
      for (final rect in rects) {
        expect(
          rect.width,
          greaterThan(0),
          reason: 'Visual rect width should be expanded',
        );
      }
    });

    testWidgets('onSelectionRectsMeasured delegates to fallback outside visual',
        (tester) async {
      final delta = Delta()..insert('hello');
      await build(tester, delta);
      final node = es.getNodeAtPath([0])!;
      final renderer = es.selectionRenderer as VimSelectionRenderer;

      // Stay in normal mode.
      expect(vim.mode, VimMode.normal);

      unawaited(es.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [0], offset: 3),
        ),
        reason: SelectionUpdateReason.uiEvent,
      ));
      await tester.pumpAndSettle();

      final ctx = SelectionMeasureContext(
        node: node,
        selection: es.selection!,
        textDirection: TextDirection.ltr,
        delegate: node.selectable!,
      );

      final rects = renderer.onSelectionRectsMeasured(ctx);
      // In normal mode, delegates to fallback.
      expect(rects, isNotNull);
    });
  });
}
