import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZenModeConfiguration', () {
    test('copyWith overrides only the given fields', () {
      const configuration = ZenModeConfiguration();
      final copied = configuration.copyWith(
        enabled: false,
        unfocusedOpacity: 0.5,
      );

      expect(copied.enabled, false);
      expect(copied.unfocusedOpacity, 0.5);
      // untouched fields keep their values.
      expect(copied.ignoreTextColor, configuration.ignoreTextColor);
      expect(copied.ignoreHighlightColor, configuration.ignoreHighlightColor);
      expect(
        copied.ignoreBlockBackgroundColor,
        configuration.ignoreBlockBackgroundColor,
      );
      expect(copied.centerFocusedBlock, configuration.centerFocusedBlock);
      expect(copied.centerAlignment, configuration.centerAlignment);
      expect(copied.fadeDuration, configuration.fadeDuration);
      expect(copied.scrollDuration, configuration.scrollDuration);
    });

    test('equality is value based', () {
      const a = ZenModeConfiguration();
      const b = ZenModeConfiguration();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(unfocusedOpacity: 0.1), isNot(equals(b)));
    });
  });

  group('ZenModeBlockWrapper.isTopLevelNodeFocused', () {
    Document buildDocument() {
      final document = Document.blank();
      document.insert([
        0,
      ], [
        paragraphNode(text: 'first'),
        paragraphNode(
          text: 'second',
          children: [paragraphNode(text: 'nested child')],
        ),
        paragraphNode(text: 'third'),
      ]);
      return document;
    }

    test('a collapsed selection in a nested child focuses the ancestor', () {
      final document = buildDocument();
      final topLevel = document.root.children.toList();
      final selection = Selection.collapsed(Position(path: [1, 0]));

      expect(
        ZenModeBlockWrapper.isTopLevelNodeFocused(
          node: topLevel[1],
          selection: selection,
        ),
        true,
      );
      expect(
        ZenModeBlockWrapper.isTopLevelNodeFocused(
          node: topLevel[0],
          selection: selection,
        ),
        false,
      );
      expect(
        ZenModeBlockWrapper.isTopLevelNodeFocused(
          node: topLevel[2],
          selection: selection,
        ),
        false,
      );
    });

    test('a multi-block selection focuses the whole range', () {
      final document = buildDocument();
      final topLevel = document.root.children.toList();
      final selection = Selection(
        start: Position(path: [0]),
        end: Position(path: [2], offset: 3),
      );

      for (final node in topLevel) {
        expect(
          ZenModeBlockWrapper.isTopLevelNodeFocused(
            node: node,
            selection: selection,
          ),
          true,
        );
      }

      // a reversed (backward) selection behaves the same.
      final reversed = selection.reversed;
      for (final node in topLevel) {
        expect(
          ZenModeBlockWrapper.isTopLevelNodeFocused(
            node: node,
            selection: reversed,
          ),
          true,
        );
      }
    });

    test('a null selection focuses nothing', () {
      final document = buildDocument();
      expect(
        ZenModeBlockWrapper.isTopLevelNodeFocused(
          node: document.root.children.first,
          selection: null,
        ),
        false,
      );
    });
  });

  group('ZenModeController', () {
    test('attach chains and detach restores blockComponentDecorator', () {
      Decoration? marker(Node node, String colorString) =>
          const BoxDecoration();
      blockComponentDecorator = marker;

      final editorState = EditorState.blank(withInitialText: true);
      final controller = ZenModeController();
      controller.attach(editorState: editorState);

      expect(identical(blockComponentDecorator, marker), false);

      controller.dispose();
      expect(identical(blockComponentDecorator, marker), true);

      blockComponentDecorator = null;
      editorState.dispose();
    });
  });

  group('zen mode widgets', () {
    const pink = Color(0xFFE91E63);
    const yellow = Color(0xFFFFEB3B);
    const green = Color(0xFF4CAF50);
    const baseColor = Colors.black;

    Document buildDocument() {
      final document = Document.blank();
      document.insert([
        0,
      ], [
        paragraphNode(text: 'first paragraph'),
        paragraphNode(
          text: 'second paragraph',
          children: [paragraphNode(text: 'nested child')],
        ),
        paragraphNode(
          delta: Delta()
            ..insert('plain ')
            ..insert(
              'pink',
              attributes: {NovidentRichTextKeys.textColor: '0xFFE91E63'},
            )
            ..insert(' and ')
            ..insert(
              'marked',
              attributes: {NovidentRichTextKeys.backgroundColor: '0xFFFFEB3B'},
            ),
        ),
        paragraphNode(
          text: 'block with background',
          attributes: {blockComponentBackgroundColor: '0xFF4CAF50'},
        ),
      ]);
      return document;
    }

    Future<
        ({
          EditorState editorState,
          ZenModeController controller,
          EditorScrollController scrollController,
        })> pumpZenEditor(
      WidgetTester tester, {
      // centering is disabled by default to keep the tests focused on the
      // dimming/color behavior.
      ZenModeConfiguration configuration = const ZenModeConfiguration(
        centerFocusedBlock: false,
      ),
    }) async {
      await NovidentEditorLocalizations.load(const Locale('en'));

      final editorState = EditorState(document: buildDocument());
      final scrollController = EditorScrollController(
        editorState: editorState,
      );
      final controller = ZenModeController(configuration: configuration);
      controller.attach(
        editorState: editorState,
        scrollController: scrollController,
      );

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
              editorScrollController: scrollController,
              disableAutoScroll: controller.shouldDisableNativeAutoScroll,
              blockWrapper: controller.blockWrapper,
              editorStyle: EditorStyle.desktop(
                textStyleConfiguration: const TextStyleConfiguration(
                  text: TextStyle(fontSize: 16, color: baseColor),
                ),
                textSpanDecorator: controller.textSpanDecorator(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return (
        editorState: editorState,
        controller: controller,
        scrollController: scrollController,
      );
    }

    double opacityOfBlock(WidgetTester tester, int topLevelIndex) {
      final wrapperFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ZenModeBlockWrapper &&
            widget.node.path.length == 1 &&
            widget.node.path.first == topLevelIndex,
      );
      expect(wrapperFinder, findsOneWidget);
      final fade = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: wrapperFinder,
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      return fade.opacity;
    }

    TextSpan? findSpanWithText(WidgetTester tester, String text) {
      TextSpan? result;
      for (final richText
          in tester.widgetList<RichText>(find.byType(RichText))) {
        richText.text.visitChildren((span) {
          if (span is TextSpan && span.text == text) {
            result = span;
            return false;
          }
          return true;
        });
        if (result != null) {
          break;
        }
      }
      return result;
    }

    bool hasBlockBackground(WidgetTester tester, Color color) {
      return tester.widgetList<Container>(find.byType(Container)).any((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.color == color;
      });
    }

    testWidgets('dims the unfocused top-level blocks', (tester) async {
      final zen = await pumpZenEditor(tester);
      final unfocusedOpacity = zen.controller.value.unfocusedOpacity;

      // no selection: nothing is dimmed.
      for (var i = 0; i < 4; i++) {
        expect(opacityOfBlock(tester, i), 1.0);
      }

      // cursor inside the nested child of block 1: only block 1 is focused.
      zen.editorState.selection = Selection.collapsed(Position(path: [1, 0]));
      await tester.pumpAndSettle();

      expect(opacityOfBlock(tester, 0), unfocusedOpacity);
      expect(opacityOfBlock(tester, 1), 1.0);
      expect(opacityOfBlock(tester, 2), unfocusedOpacity);
      expect(opacityOfBlock(tester, 3), unfocusedOpacity);

      // moving to another block re-focuses it.
      zen.editorState.selection = Selection.collapsed(Position(path: [2]));
      await tester.pumpAndSettle();

      expect(opacityOfBlock(tester, 1), unfocusedOpacity);
      expect(opacityOfBlock(tester, 2), 1.0);

      zen.controller.dispose();
    });

    testWidgets('respects a custom unfocusedOpacity', (tester) async {
      final zen = await pumpZenEditor(
        tester,
        configuration: const ZenModeConfiguration(
          centerFocusedBlock: false,
          unfocusedOpacity: 0.1,
        ),
      );

      zen.editorState.selection = Selection.collapsed(Position(path: [0]));
      await tester.pumpAndSettle();

      expect(opacityOfBlock(tester, 0), 1.0);
      expect(opacityOfBlock(tester, 1), 0.1);

      zen.controller.dispose();
    });

    testWidgets('does not dim when zen mode is disabled', (tester) async {
      final zen = await pumpZenEditor(
        tester,
        configuration: const ZenModeConfiguration(
          enabled: false,
          centerFocusedBlock: false,
        ),
      );

      zen.editorState.selection = Selection.collapsed(Position(path: [0]));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(opacityOfBlock(tester, i), 1.0);
      }

      zen.controller.dispose();
    });

    testWidgets(
      'ignores font_color, bg_color and block bgColor while enabled '
      'and restores them when disabled',
      (tester) async {
        final zen = await pumpZenEditor(tester);

        // enabled: the colored spans are rendered with the base color and
        // without highlight, the block background is not painted.
        var pinkSpan = findSpanWithText(tester, 'pink');
        var markedSpan = findSpanWithText(tester, 'marked');
        expect(pinkSpan, isNotNull);
        expect(markedSpan, isNotNull);
        expect(pinkSpan!.style?.color, baseColor);
        expect(markedSpan!.style?.backgroundColor, Colors.transparent);
        expect(hasBlockBackground(tester, green), false);

        // the attributes are NOT removed from the document.
        final delta = zen.editorState.document.root.children
            .elementAt(2)
            .delta!
            .whereType<TextInsert>()
            .toList();
        expect(
          delta.any(
            (t) =>
                t.attributes?[NovidentRichTextKeys.textColor] == '0xFFE91E63',
          ),
          true,
        );

        // disabled at runtime: the original colors come back.
        zen.controller.value = zen.controller.value.copyWith(enabled: false);
        await tester.pumpAndSettle();

        pinkSpan = findSpanWithText(tester, 'pink');
        markedSpan = findSpanWithText(tester, 'marked');
        expect(pinkSpan!.style?.color, pink);
        expect(markedSpan!.style?.backgroundColor, yellow);
        expect(hasBlockBackground(tester, green), true);

        // and re-enabling neutralizes them again.
        zen.controller.value = zen.controller.value.copyWith(enabled: true);
        await tester.pumpAndSettle();

        pinkSpan = findSpanWithText(tester, 'pink');
        markedSpan = findSpanWithText(tester, 'marked');
        expect(pinkSpan!.style?.color, baseColor);
        expect(markedSpan!.style?.backgroundColor, Colors.transparent);
        expect(hasBlockBackground(tester, green), false);

        zen.controller.dispose();
      },
    );

    testWidgets(
      'keeps the colors when the ignore flags are turned off',
      (tester) async {
        final zen = await pumpZenEditor(
          tester,
          configuration: const ZenModeConfiguration(
            centerFocusedBlock: false,
            ignoreTextColor: false,
            ignoreHighlightColor: false,
            ignoreBlockBackgroundColor: false,
          ),
        );

        final pinkSpan = findSpanWithText(tester, 'pink');
        final markedSpan = findSpanWithText(tester, 'marked');
        expect(pinkSpan!.style?.color, pink);
        expect(markedSpan!.style?.backgroundColor, yellow);
        expect(hasBlockBackground(tester, green), true);

        zen.controller.dispose();
      },
    );
  });
}
