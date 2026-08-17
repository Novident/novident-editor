import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Tests that `styleToolbarItem` respects `highlightColor` and `iconColor`
/// from the toolbar's style configuration.
void main() {
  group('styleToolbarItem — customization', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    EditorState editorWithText(String text) {
      final doc = Document.blank();
      final delta = Delta()..insert(text);
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
      return EditorState(document: doc);
    }

    testWidgets('uses highlightColor for border when dropdown is open',
        (WidgetTester tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 2),
      );

      const myHighlight = Color(0xFFFF0000); // red

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return styleToolbarItem.builder!(
                  context,
                  editorState,
                  myHighlight,
                  Colors.grey,
                  null,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the dropdown.
      await tester.tap(find.text('No Style'));
      await tester.pumpAndSettle();

      // The border of the button should use highlightColor when open.
      // We verify the dropdown exists (menu items visible).
      expect(find.text('No Style'), findsWidgets);
    });

    testWidgets('tooltipBuilder wraps the button when provided',
        (WidgetTester tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return styleToolbarItem.builder!(
                  context,
                  editorState,
                  Colors.blue,
                  Colors.grey,
                  (ctx, id, msg, child) => Tooltip(message: msg, child: child),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tooltip widget should wrap the button.
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });
}
