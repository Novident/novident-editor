import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Full integration: user opens editor with a custom font provider, sees
/// toolbar items, selects text, changes font size and font family, and
/// verifies both toolbar display and document delta.
void main() {
  group('Editor + toolbar — full font workflow', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets(
        'user opens editor, selects text, changes font size via toolbar',
        (WidgetTester tester) async {
      // 1 — Create document with text and editor state.
      final doc = Document.blank();
      final delta = Delta()..insert('Hello World');
      doc.insert([
        0,
      ], [
        Node(
          type: 'paragraph',
          attributes: {
            blockComponentDelta: delta.toJson(),
          },
        ),
      ]);
      final editorState = EditorState(document: doc);
      addTearDown(() => editorState.dispose());

      // 2 — Build editor + static toolbar together.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                NovidentStaticToolbar(
                  items: [buildFontSizeItem()],
                  editorState: editorState,
                  showWhenNoSelection: true,
                ),
                Expanded(
                  child: NovidentEditor(editorState: editorState),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3 — No selection yet → button shows default size 12.
      expect(find.text('12'), findsOneWidget);

      // 4 — Set selection on "World".
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 6, endOffset: 11),
      );
      await tester.pumpAndSettle();

      // 5 — Open font-size dropdown.
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // 6 — Select size 14 (close to default, definitely visible).
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      // 7 — Verify delta: "World" now has font_size: 14.
      final node = editorState.getNodeAtPath([0]);
      final sel = editorState.selection!;
      var hasSize = false;
      editorState.getNodesInSelection(sel).allSatisfyInSelection(
            sel,
            (d) => d.everyAttributes((attr) {
              if (attr[RichTextKeys.fontSize] == 14.0) {
                hasSize = true;
                return false;
              }
              return true;
            }),
          );
      expect(hasSize, isTrue);

      // 8 — Toolbar now shows 14 as the effective size.
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets(
        'user selects text, applies custom font family, toolbar reflects it',
        (WidgetTester tester) async {
      final doc = Document.blank();
      final delta = Delta()..insert('Hello');
      doc.insert([
        0,
      ], [
        Node(
          type: 'paragraph',
          attributes: {
            blockComponentDelta: delta.toJson(),
          },
        ),
      ]);
      final editorState = EditorState(document: doc);
      addTearDown(() => editorState.dispose());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                NovidentStaticToolbar(
                  items: [
                    buildFontFamilyItem(
                      fontFamilies: ['Arial', 'Georgia', 'Verdana'],
                    ),
                  ],
                  editorState: editorState,
                  showWhenNoSelection: true,
                ),
                Expanded(
                  child: NovidentEditor(editorState: editorState),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No selection → shows provider default (platform default font).
      expect(find.text(getDefaultFont()), findsOneWidget);

      // Select text and apply Georgia via delta.
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      editorState.formatDelta(editorState.selection!, {
        RichTextKeys.fontFamily: 'Georgia',
      });
      // Re-select to refresh.
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();

      // Toolbar button now shows Georgia.
      expect(find.text('Georgia'), findsOneWidget);

      // Open dropdown → Georgia should be selected.
      await tester.tap(find.text('Georgia'));
      await tester.pumpAndSettle();

      // The menu shows available fonts.
      expect(find.text('Arial'), findsOneWidget);
      expect(find.text('Verdana'), findsOneWidget);
    });

    testWidgets('toolbar items remain visible after clearing selection',
        (WidgetTester tester) async {
      final doc = Document.blank();
      final delta = Delta()..insert('Hello');
      doc.insert([
        0,
      ], [
        Node(
          type: 'paragraph',
          attributes: {
            blockComponentDelta: delta.toJson(),
          },
        ),
      ]);
      final editorState = EditorState(document: doc);
      addTearDown(() => editorState.dispose());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                NovidentStaticToolbar(
                  items: [buildFontSizeItem(), buildFontFamilyItem()],
                  editorState: editorState,
                  showWhenNoSelection: true,
                ),
                Expanded(
                  child: NovidentEditor(editorState: editorState),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both items visible with defaults.
      expect(find.text('12'), findsOneWidget);
      expect(find.text(getDefaultFont()), findsOneWidget);

      // Select text → apply font size 24.
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      editorState.formatDelta(editorState.selection!, {
        RichTextKeys.fontSize: 24.0,
      });
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();

      expect(find.text('24'), findsOneWidget);

      // Clear selection.
      editorState.updateSelectionWithReason(null);
      await tester.pumpAndSettle();

      // Items still visible (flag on), showing cached values.
      expect(find.text('24'), findsOneWidget); // cached font size
      expect(find.text(getDefaultFont()),
          findsOneWidget,); // font family never changed
    });
  });
}
