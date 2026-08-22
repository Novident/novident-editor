import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../test_helper.dart';
import '../util/document_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EditorScrollController> pumpEditor(
    WidgetTester tester,
    EditorState editorState,
    TypewriterScrollController typewriter,
  ) async {
    final scrollController = EditorScrollController(editorState: editorState);
    typewriter.attach(
      editorState: editorState,
      scrollController: scrollController,
    );
    await tester.buildAndPump(
      NovidentEditor(
        editorState: editorState,
        editorScrollController: scrollController,
        disableAutoScroll: typewriter.shouldDisableNativeAutoScroll,
      ),
    );
    return scrollController;
  }

  testWidgets('centers the focused block when it changes', (tester) async {
    final editorState = EditorState(document: Document.blank());
    for (var i = 0; i < 60; i++) {
      editorState.document.addParagraph(initialText: 'paragraph $i');
    }
    editorState.typewriter = const TypewriterScrollConfig();
    final typewriter = TypewriterScrollController();
    final scrollController =
        await pumpEditor(tester, editorState, typewriter);

    // moving to a far block must scroll the editor to center it.
    await editorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: [30])),
    );
    await tester.pumpAndSettle();

    expect(scrollController.offsetNotifier.value, greaterThan(0));

    typewriter.detach();
  });

  testWidgets('scrolls to keep the caret inside the dead-zone box', (
    tester,
  ) async {
    // a single tall block (many wrapped lines) so the caret can move far
    // below the visible area while staying in the same top-level block.
    final editorState = EditorState(document: Document.blank());
    editorState.document.addParagraph(
      initialText: List.filled(2000, 'word').join(' '),
    );
    editorState.typewriter = const TypewriterScrollConfig();
    final typewriter = TypewriterScrollController();
    final scrollController =
        await pumpEditor(tester, editorState, typewriter);

    // center the block at its start.
    await editorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: [0])),
    );
    await tester.pumpAndSettle();
    final offsetAfterCenter = scrollController.offsetNotifier.value;

    // move the caret to the end of the block (far below the box) — the
    // editor must scroll down to bring it back inside the dead-zone box.
    final node = editorState.document.root.children.first;
    final length = node.delta?.toPlainText().length ?? 0;
    await editorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: [0], offset: length)),
    );
    await tester.pumpAndSettle();

    expect(
      scrollController.offsetNotifier.value,
      greaterThan(offsetAfterCenter),
    );

    typewriter.detach();
  });

  testWidgets(
    'keeps the caret inside the box while moving vertically through a '
    'long paragraph',
    (tester) async {
      // several paragraphs, one of them very long so it covers the viewport.
      // The long paragraph sits far enough down that centering it is possible
      // (the scroll offset can be positive).
      final editorState = EditorState(document: Document.blank());
      for (var i = 0; i < 20; i++) {
        editorState.document.addParagraph(initialText: 'intro paragraph $i');
      }
      editorState.document.addParagraph(
        initialText: List.filled(2000, 'word').join(' '),
      );
      editorState.document.addParagraph(initialText: 'outro paragraph');
      editorState.typewriter = const TypewriterScrollConfig();
      final typewriter = TypewriterScrollController();
      await pumpEditor(tester, editorState, typewriter);

      // select the long paragraph (block change → center it).
      const longIndex = 20;
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [longIndex])),
      );
      await tester.pumpAndSettle();

      final scrollableState = editorState.scrollableState;
      expect(scrollableState, isNotNull);
      final viewportHeight = scrollableState!.position.viewportDimension;
      final margin = editorState.typewriter.keepInViewTopMargin;
      final bottomMargin = editorState.typewriter.keepInViewBottomMargin;

      final longNode = editorState.document.root.children.elementAt(longIndex);
      final length = longNode.delta?.toPlainText().length ?? 0;
      expect(length, greaterThan(0));

      // move the caret vertically through the paragraph's lines and assert it
      // never leaves the dead-zone box (unless the editor is already at the
      // max scroll extent, i.e. the caret is on the last visible line).
      for (var offset = 0; offset <= length; offset += 1000) {
        await editorState.updateSelectionWithReason(
          Selection.collapsed(
            Position(path: [longIndex], offset: offset.clamp(0, length)),
          ),
        );
        await tester.pumpAndSettle();

        final rects = editorState.selectionRects();
        expect(rects, isNotEmpty, reason: 'caret rect at offset $offset');
        final caret = rects.reduce((a, b) => a.expandToInclude(b));
        final deltaToOrigin = scrollableState.deltaToScrollOrigin;
        final top = caret.top - deltaToOrigin.dy;
        final bottom = caret.bottom - deltaToOrigin.dy;

        // the caret must always be visible.
        expect(top, greaterThanOrEqualTo(0), reason: 'top at offset $offset');
        expect(
          bottom,
          lessThanOrEqualTo(viewportHeight),
          reason: 'bottom at offset $offset',
        );

        final withinBox =
            top >= margin && bottom <= viewportHeight - bottomMargin;
        final atMaxScroll =
            scrollableState.position.pixels >=
            scrollableState.position.maxScrollExtent - 1;
        expect(
          withinBox || atMaxScroll,
          isTrue,
          reason: 'caret left the box at offset $offset '
              '(top=$top, bottom=$bottom, viewport=$viewportHeight, '
              'margin=$margin, bottomMargin=$bottomMargin)',
        );
      }

      typewriter.detach();
    },
  );
}